#!/usr/bin/env python3
"""
스키마 덤프(mysqldump --no-data) + rename_map → 신규 논리 스키마 V1 DDL 생성 (통합 파이프라인).

이전에 gen_target_ddl.py(OLD명 추출) + 별도 rename 단계로 나뉘어 있던 것을 하나로 통합.
  1) 덤프에서 CREATE TABLE 블록 추출
  2) rename_map에 있으나 덤프에 없는 테이블 자동 제외 (환경 간 테이블셋 드리프트 대응)
  3) AUTO_INCREMENT=n 카운터 제거 (컷오버 시 별도 세팅)
  4) 크로스-스키마 FK 절단 (같은 타깃 스키마 안을 참조하는 intra FK만 유지)
  5) rename 적용: 테이블명 old→new + 유지된 FK의 REFERENCES old→new 재작성
  6) 스키마별 renamed_<schema>.sql + 통합 create_all.sql (CREATE DATABASE+USE+테이블) 출력

⚠️ 드리프트-0 원칙: 반드시 "현행 대상 환경 스키마 덤프"를 입력으로 준다
   (예: prod 이관 시 prod_schema.sql). 그러면 타깃=소스라 DMS full-load 무손실.

사용: gen_v1_from_schema.py --schema-sql prod_schema.sql --rename rename_map.tsv --out-dir OUT [--source-db bomapp_member]
"""
import argparse, re, os


def parse_blocks(path):
    lines = open(path, encoding='utf-8', errors='ignore').read().splitlines()
    blocks, i = {}, 0
    cre = re.compile(r'^CREATE TABLE `([^`]+)` \($')
    while i < len(lines):
        m = cre.match(lines[i])
        if m:
            name = m.group(1); j = i + 1; body = []
            while j < len(lines) and not lines[j].startswith(') ENGINE'):
                body.append(lines[j]); j += 1
            footer = lines[j] if j < len(lines) else ') ENGINE=InnoDB;'
            blocks[name] = (body, footer)
            i = j + 1
        else:
            i += 1
    return blocks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--schema-sql', required=True)
    ap.add_argument('--rename', required=True)
    ap.add_argument('--out-dir', required=True)
    ap.add_argument('--source-db', default='bomapp_member')
    ap.add_argument('--no-drop', action='store_true',
                    help="DROP TABLE 구문 제거 + CREATE TABLE IF NOT EXISTS (prod 안전; 절대 drop 안 함)")
    a = ap.parse_args()
    os.makedirs(a.out_dir, exist_ok=True)

    # schema -> {old: new}
    by_schema = {}
    for ln in open(a.rename):
        if ln.startswith('#') or not ln.strip():
            continue
        p = ln.rstrip('\n').split('\t')
        if len(p) >= 3:
            by_schema.setdefault(p[2], {})[p[0]] = p[1]

    blocks = parse_blocks(a.schema_sql)
    fk_line = re.compile(r'FOREIGN KEY .* REFERENCES `([^`]+)`')
    combined = ["-- 신규 논리 스키마 V1 (통합) — 현행 스키마 덤프 기준, 드리프트-0",
                "SET FOREIGN_KEY_CHECKS=0;", ""]
    summary = {}
    for schema, rmap in by_schema.items():
        want = {old for old in rmap if old in blocks}        # 덤프에 존재하는 것만
        missing = sorted(set(rmap) - want)
        per = [f"-- 타깃 스키마 `{schema}` — {len(want)} 테이블 (rename map {len(rmap)}개 중, 덤프 존재분)",
               f"CREATE DATABASE IF NOT EXISTS `{schema}` DEFAULT CHARACTER SET utf8mb4;",
               f"USE `{schema}`;", "SET FOREIGN_KEY_CHECKS=0;", ""]
        combined.append(f"CREATE DATABASE IF NOT EXISTS `{schema}` DEFAULT CHARACTER SET utf8mb4;")
        combined.append(f"USE `{schema}`;")
        severed = []
        for old in sorted(want):
            new = rmap[old]
            body, footer = blocks[old]
            kept = []
            for l in body:
                fk = fk_line.search(l)
                if fk:
                    ref = fk.group(1)
                    if ref not in want:                       # 크로스-스키마/세트밖 → 절단
                        severed.append(f"{new} -> {ref}")
                        continue
                    l = l.replace(f'REFERENCES `{ref}`', f'REFERENCES `{rmap[ref]}`')  # intra FK rename
                kept.append(l.rstrip())
            norm = [re.sub(r',\s*$', '', l) for l in kept if l.strip()]
            foot = re.sub(r'\s*AUTO_INCREMENT=\d+', '', footer)
            # --no-drop: DROP 구문 완전 제거 + CREATE TABLE IF NOT EXISTS (prod 안전:
            # 어떤 경우에도 drop 하지 않음; 재실행 시 기존 테이블은 건너뜀).
            create_kw = "CREATE TABLE IF NOT EXISTS" if a.no_drop else "CREATE TABLE"
            ddl = ([] if a.no_drop else [f"DROP TABLE IF EXISTS `{new}`;"]) + [
                f"{create_kw} `{new}` (", ",\n".join(norm), foot, ""]
            per += ddl
            combined += ddl
        per.append("SET FOREIGN_KEY_CHECKS=1;")
        open(os.path.join(a.out_dir, f"renamed_{schema}.sql"), 'w', encoding='utf-8').write("\n".join(per) + "\n")
        summary[schema] = (len(want), missing, severed)
    combined.append("SET FOREIGN_KEY_CHECKS=1;")
    open(os.path.join(a.out_dir, "create_all.sql"), 'w', encoding='utf-8').write("\n".join(combined) + "\n")

    print(f"출력: {a.out_dir}/renamed_<schema>.sql + create_all.sql")
    for s, (n, miss, sev) in summary.items():
        print(f"  {s}: {n} 테이블" + (f" | 덤프에 없어 제외 {len(miss)}: {miss}" if miss else "")
              + (f" | 절단 FK {len(sev)}" if sev else ""))


if __name__ == '__main__':
    main()
