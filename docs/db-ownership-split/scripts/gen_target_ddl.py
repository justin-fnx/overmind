#!/usr/bin/env python3
"""
dev_schema.sql(mysqldump --no-data)에서 특정 논리 스키마로 이전할 타깃 테이블 DDL을 생성.
- AUTO_INCREMENT=n 제거 (카운터는 컷오버 시 별도 세팅)
- 타깃 세트 '밖' 테이블을 참조하는 FOREIGN KEY(크로스-스키마) 자동 절단
- 세트 '안'을 참조하는 intra-schema FK는 유지
- 스키마 한정 이름(`schema`.`tbl`)으로 출력, 재실행 가능하도록 DROP TABLE IF EXISTS 포함(신규 빈 스키마 전제)
사용: gen_target_ddl.py <dev_schema.sql> <schema_name> <table_list_file>
"""
import sys, re

src, schema, listfile = sys.argv[1], sys.argv[2], sys.argv[3]
want = set()
for line in open(listfile):
    t = line.strip()
    if t and not t.startswith('#'):
        want.add(t)

text = open(src, encoding='utf-8').read()
lines = text.splitlines()

# CREATE TABLE 블록 추출
blocks = {}
i = 0
cre = re.compile(r'^CREATE TABLE `([^`]+)` \($')
while i < len(lines):
    m = cre.match(lines[i])
    if m:
        name = m.group(1)
        j = i + 1
        body = []
        while j < len(lines) and not lines[j].startswith(') ENGINE'):
            body.append(lines[j]); j += 1
        footer = lines[j] if j < len(lines) else ') ENGINE=InnoDB;'
        blocks[name] = (body, footer)
        i = j + 1
    else:
        i += 1

fk_re = re.compile(r'FOREIGN KEY .* REFERENCES `([^`]+)`')
missing = [t for t in want if t not in blocks]
out = []
out.append(f"-- 타깃 스키마: `{schema}`  (dev_schema.sql 기반 자동생성)")
out.append(f"-- 테이블 {len([t for t in want if t in blocks])}개 / AUTO_INCREMENT 제거 / 세트밖 참조 FK 절단")
out.append(f"USE `{schema}`;")
out.append("SET FOREIGN_KEY_CHECKS=0;")
out.append("")
severed = []
for name in sorted(want):
    if name not in blocks:
        continue
    body, footer = blocks[name]
    kept = []
    for ln in body:
        fk = fk_re.search(ln)
        if fk and fk.group(1) not in want:
            severed.append(f"{name} -> {fk.group(1)}")
            continue  # 크로스-스키마 FK 절단
        kept.append(ln.rstrip())
    # 후행 콤마 정규화: 각 inner 라인의 끝 콤마 제거 후 재결합
    norm = [re.sub(r',\s*$', '', ln) for ln in kept if ln.strip()]
    footer = re.sub(r'\s*AUTO_INCREMENT=\d+', '', footer)
    out.append(f"DROP TABLE IF EXISTS `{name}`;")
    out.append(f"CREATE TABLE `{name}` (")
    out.append(",\n".join(norm))
    out.append(footer)
    out.append("")
out.append("SET FOREIGN_KEY_CHECKS=1;")

open(f"{sys.argv[4]}", "w", encoding='utf-8').write("\n".join(out))
print(f"생성 완료: {sys.argv[4]}")
print(f"포함 테이블: {len([t for t in want if t in blocks])}  누락(소스에 없음): {missing if missing else '없음'}")
print(f"절단된 크로스-스키마 FK: {severed if severed else '없음'}")
