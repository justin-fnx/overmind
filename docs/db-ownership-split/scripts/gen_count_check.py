#!/usr/bin/env python3
"""
프리로드 정합성 검증 — 소스(bomapp_member.old) vs 타깃(schema.new) 행수 대조.
불일치 테이블만 출력한다. 결과가 비어 있으면 전 테이블 행수 일치.

DMS 자체 validation 은 동일-인스턴스 + collation 조합에서 정체/Table error 가
잦다(실데이터 정상인데 대조만 실패). 따라서 행수 대조(+필요 시 pt-table-checksum)를
1차 검증으로 쓴다. CDC 가동 중이면 라이브 쓰기로 소폭 차이 가능 → 곧 수렴.

사용:  python3 gen_count_check.py --rename rename_map.tsv > count_check.sql
       mysql -h <host> -u root -p < count_check.sql
"""
import argparse


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--rename', required=True)
    ap.add_argument('--source-db', default='bomapp_member')
    a = ap.parse_args()
    rows = []
    for ln in open(a.rename):
        if ln.startswith('#') or not ln.strip(): continue
        p = ln.rstrip('\n').split('\t')
        if len(p) >= 3: rows.append((p[2], p[0], p[1]))  # schema, old, new
    sel = [f"  SELECT '{s}.{n}' t, (SELECT COUNT(*) FROM `{a.source_db}`.`{o}`) s, "
           f"(SELECT COUNT(*) FROM `{s}`.`{n}`) g" for s, o, n in rows]
    print("-- 프리로드 행수 대조: 불일치만 출력. 비어 있으면 전 테이블 일치.")
    print("SELECT * FROM (")
    print("\n  UNION ALL\n".join(sel))
    print(") x WHERE s <> g ORDER BY t;")


if __name__ == '__main__':
    main()
