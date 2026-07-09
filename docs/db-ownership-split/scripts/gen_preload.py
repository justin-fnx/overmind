#!/usr/bin/env python3
"""
DB 오너십 분리 프리로드(INSERT..SELECT) 생성기.

bomapp_member(소스) → 신규 논리 스키마(chat/mydata/planner/messaging/bomapp)로
초기 스냅샷을 심는 SQL을 생성한다. DMS full-load 대신 프리로드하고, 이후
DMS는 CDC-only 로 스냅샷 직전 binlog 위치부터 변경만 따라잡는다.

핵심 드리프트 대응 (이번 세션의 교훈):
  1) SELECT * 금지 → 소스∩타깃 "교집합 컬럼"만 명시.
     - V1이 옛 스키마 스냅샷 기반이면 현행 소스와 양방향으로 어긋난다.
     - 소스에만 있는 신규 컬럼 → 무시. 타깃에만 있는 컬럼 → 빈 채로 둠.
  2) 생성 컬럼(GENERATED ALWAYS AS ...) 제외 → 타깃이 자동 계산(INSERT 금지).
  3) Aurora는 FTWRL/GTID 불가 → START TRANSACTION WITH CONSISTENT SNAPSHOT +
     스냅샷 "직전" SHOW MASTER STATUS 위치 캡처(= 중복-safe, 유실 없음).

입력:
  --ddl-dir   renamed_<schema>.sql (타깃 CREATE TABLE, rename 반영) 디렉토리
  --src-cols  현행 소스 컬럼 덤프 TSV (table<TAB>column, mysql 배치는 리터럴 \\t 이스케이프)
              생성:  mysql ... -N -e "SELECT CONCAT(table_name,0x09,column_name) \
                     FROM information_schema.columns WHERE table_schema='bomapp_member' \
                     ORDER BY table_name, ordinal_position" > src_cols.tsv
  --rename    rename_map.tsv  (old<TAB>new<TAB>schema, 197행)
  --source-db 소스 스키마명 (기본 bomapp_member)

⚠️ PROD 에서는 V1(타깃 DDL)을 반드시 "현행 prod 스키마 덤프" 기준으로 재생성해
   드리프트를 0으로 만든 뒤 이 스크립트를 돌린다(그러면 교집합=전체, 무손실).
"""
import argparse, re, os


def load_target_cols(ddl_dir, schemas):
    """renamed_<schema>.sql 에서 테이블별 컬럼 목록 + 생성컬럼 집합 추출."""
    GEN = re.compile(r'GENERATED ALWAYS| AS \(')
    cols, gens = {}, {}
    for s in schemas:
        path = os.path.join(ddl_dir, f'renamed_{s}.sql')
        cols[s], gens[s] = {}, {}
        cur = None
        for ln in open(path, encoding='utf-8', errors='ignore'):
            ln = ln.rstrip('\n')
            m = re.match(r'^CREATE TABLE `([^`]+)` \($', ln)
            if m:
                cur = m.group(1); cols[s][cur] = []; gens[s][cur] = set(); continue
            if cur:
                if ln.startswith(') ENGINE'):
                    cur = None; continue
                cm = re.match(r'^\s*`([^`]+)`\s', ln)  # 컬럼 라인(백틱 시작; KEY/CONSTRAINT 제외)
                if cm:
                    c = cm.group(1); cols[s][cur].append(c)
                    if GEN.search(ln): gens[s][cur].add(c)
    return cols, gens


def load_src_cols(path):
    src = {}
    for ln in open(path, encoding='utf-8', errors='ignore'):
        ln = ln.rstrip('\n')
        if not ln: continue
        parts = ln.split('\\t')          # mysql 배치 리터럴 이스케이프
        if len(parts) == 2:
            src.setdefault(parts[0], []).append(parts[1])
    return {t: set(cs) for t, cs in src.items()}


def load_rename(path):
    rows = []
    for ln in open(path, encoding='utf-8'):
        if ln.startswith('#') or not ln.strip(): continue
        p = ln.rstrip('\n').split('\t')
        if len(p) >= 3: rows.append((p[2], p[0], p[1]))  # schema, old, new
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ddl-dir', required=True)
    ap.add_argument('--src-cols', required=True)
    ap.add_argument('--rename', required=True)
    ap.add_argument('--source-db', default='bomapp_member')
    ap.add_argument('-o', '--out', default='preload.sql')
    a = ap.parse_args()

    rows = load_rename(a.rename)
    schemas = sorted({s for s, _, _ in rows})
    tcols, gens = load_target_cols(a.ddl_dir, schemas)
    srcset = load_src_cols(a.src_cols)

    out = ["-- DB 오너십 분리 프리로드 (교집합 컬럼 + 생성컬럼 제외; Aurora 무잠금 스냅샷)",
           "-- ⚠️ 한 mysql 세션 통째로. 첫 에러 시 전체 트랜잭션 롤백 → 해당 테이블 고치고 재실행.",
           "SET FOREIGN_KEY_CHECKS=0;",
           "SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;", "",
           "-- [A] 타깃 비우기 (재실행 안전)"]
    for s, o, n in rows:
        out.append(f"DELETE FROM `{s}`.`{n}`;")
    out += ["", "-- [B] CDC 시작점 (스냅샷 직전 = 중복-safe, no-loss)",
            "SELECT NOW(6) AS cdc_start_time;   -- 참고(타임존 주의)",
            "SHOW MASTER STATUS;                -- ★ <binlog_file>:<position> = DMS CdcStartPosition",
            "START TRANSACTION WITH CONSISTENT SNAPSHOT;", "", "-- [C] 교집합 복사(생성컬럼 제외)"]
    drift_t, drift_s, excluded = {}, {}, []
    for s, o, n in rows:
        tc = tcols[s].get(n, []); sc = srcset.get(o)
        if sc is None:
            continue
        g = gens[s].get(n, set())
        inter = [c for c in tc if c in sc and c not in g]
        to = [c for c in tc if c not in sc]               # 타깃-only(빈 채)
        so = [c for c in sc if c not in set(tc)]           # 소스-only(무시)
        dr = [c for c in tc if c in g and c in sc]          # 제외한 생성컬럼
        if to: drift_t[f"{s}.{n}"] = to
        if so: drift_s[f"{s}.{n}(<-{o})"] = so
        if dr: excluded.append((f"{s}.{n}", dr))
        cl = ", ".join(f"`{c}`" for c in inter)
        out.append(f"INSERT INTO `{s}`.`{n}` ({cl}) SELECT {cl} FROM `{a.source_db}`.`{o}`;")
    out.append("COMMIT;")
    open(a.out, 'w').write("\n".join(out) + "\n")

    print(f"생성: {a.out} — INSERT {len(rows)}개")
    if excluded:  print("제외 생성컬럼:", excluded)
    if drift_t:   print(f"드리프트(타깃-only, 빈 채): {drift_t}")
    if drift_s:   print(f"드리프트(소스-only, 무시): {drift_s}")
    if not (drift_t or drift_s):
        print("드리프트 없음 (타깃=소스). PROD 목표 상태.")


if __name__ == '__main__':
    main()
