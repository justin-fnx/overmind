# DB 오너십 분리 — 컷오버 실행 런북 (big-bang)

> 상위: BOM-399. 이 문서는 `bomapp_member` 단일 스키마 → 5개 소유 스키마(chat/mydata/planner/bomapp/messaging, + 잔류 bomapp_member) 로의 **앱 컷오버**를 단계별로 실행하는 절차다.
> **먼저 dev 에서 이 문서 그대로 리허설**한 뒤 stg/prod 에 적용한다. 각 단계는 체크박스로 소진하며, 실패 시 해당 단계의 **롤백**(§5)으로 즉시 복귀한다.

---

## ✅ 실행 결과 — prod 컷오버 성공·완료 (2026-07-21, 사용자 확인)

**2026-07-21 00시 창에서 big-bang 컷오버를 실행해 성공·완료했다**(팀 분담 배포, Leader 미개입 — 결과는 사용자 확인). 9앱이 각자 소유 스키마(chat/mydata/planner/bomapp/messaging + 잔류 bomapp_member)로 datasource flip + grant + 5스키마 CDC 중지 완료, 검증 통과 후 점검 페이지 OFF·서비스 정상 복귀.

- **§3.1 점검 ON / §3.8 OFF**: 실행 완료(saved plan `maintenance_on.tfplan`/`maintenance_off.tfplan`). 보맵 웹/앱·플래너 웹/앱 점검화면 정상 노출 → 종료 후 200 정상 복귀. (검증 함정: `web.bomapp.co.kr`는 CF 미경유 별개 경로 — 실접근 도메인 `web-2z9w75bv`/`bomapp.im`으로 검증. §2.5 참조.)
- **배포 사고 2건 (모두 복구 완료)**:
  1. **mydata-mgmts-api TD:9 부팅 실패** — 신규 IAM 롤(`prod-mydata-mgmts-api-task-role`)에 `bomapp/prod/datasource/mydata-*` 시크릿 read 권한 누락(implicitDeny) → `APPLICATION FAILED TO START`. **Leader 복구**: CLI put-role-policy + infra `modules/prod/iam.tf` reconcile(**MR!86**). (§2.3 IAM 갱신 항목의 실제 사고 사례.)
  2. **chat-api/bomapp-api SchemaAware 쿼리 SELECT 거부** — 레거시 공유 prod 유저(`stg-wapi-service`)에 새 스키마 grant 누락 → 런타임 크래시. **팀 처리**(시크릿 값이 아닌 grant 문제, §2.4).
- **레거시 webview**: PR #1312(policy/my_data_org catalog 한정) + PR #1314(BOM-138 하드닝 정합, TD rev10/8080) 머지·배포 완료. member-service 계정에 `bomapp`(policy)+`mydata`(org) SELECT grant 완료 → 새 스키마 읽기 정상.
- **남은 후속 = §4 사후 정리**: 집중 모니터링 + 롤백 윈도우 유지(`bomapp_member` 원본 + 정지 CDC 태스크 보존) → **안정 확인 후 별도 승인**으로 DMS teardown(`dms_prod_enabled=false`) + `bomapp_member` 중복(이관) 테이블 정리 + 구 datasource-* 시크릿 삭제.
- Linear: **BOM-399**(에픽)·**BOM-423**(물리 컷오버)·**BOM-400~408**(앱별 flip, big-bang 흡수) = Done.

> 아래 §2·§3 체크리스트는 **실행 절차 정본(재사용/롤백 참조)**으로 보존한다. 이번 창의 실제 진행은 위 요약이 정본.

---

## 0. 왜 big-bang인가 (불변식)
- 앱-스키마 의존 분석(9앱) 결과 **모든 스키마가 다중 writer 앱**을 가진다(planner=6앱, messaging=5앱, chat=3앱, bomapp/mydata 다수 write). → 한 스키마의 CDC를 멈추려면 **그 스키마에 write하는 앱 전부를 동시에** 신규로 전환해야 한다(split-brain 방지). **독립/부분 컷오버 불가 → 전 앱 동시 flip + 다운타임(점검) 필수.**
- 전환 = 신규 앱 이미지 배포(엔티티 `@Table(schema=)` = MR !197 + datasource import `datasource/{schema}` = MR !192, mydata-mgmts = PR #20) + 각 datasource 계정 grant + 5스키마 CDC 중지.
- **안전판**: 컷오버 윈도우 동안 `bomapp_member`(원본)에는 **write를 하지 않는다**(앱 정지/점검). 따라서 실패 시 `bomapp_member`는 무손상 → 이전 이미지로 되돌리면 즉시 복구.

## 1. 관련 아티팩트 (버전 고정)
- 코드: next-backend **MR !192**(datasource import), **MR !197**(엔티티 @Table schema), mydata-mgmts-api **PR #20**(reader/writer + datasource/mydata). → 컷오버 전 머지 + 이미지 빌드.
- 레거시(legacy-backend) 코드: **PR #1312**(bomapp-webview — `Policy`→`bomapp.policy`·`MyDataOrg`→`mydata.org` catalog 한정 + `PolicyRepository` native 2건 한정; read-only 2테이블). → **레거시 중 bomapp-webview만 컷오버 영향**(정밀추적 결론: `legacy-bomapp-api`·`redmin`·`planner-card-ssr` 은 대상 아님·이번에 재배포 안 함). ⚠️ 공유모듈(`bomapp_api_server_common`) 변경이라 실영향은 재배포되는 webview 한정. MySQL은 Hibernate NameQualifierSupport=CATALOG → `catalog=` 로 `catalog.table` 렌더(커스텀 dialect 불요).
- 시크릿: `bomapp/{env}/datasource/{chat,mydata,planner,bomapp,messaging}` (+ mydata-mgmts는 datasource/mydata 공유). 값=운영자 주입(placeholder 상태).
- 정본 맵: `docs/db-ownership-split/entity-schema-map.tsv` (엔티티→스키마·신규명).
- 스키마 정의: next-backend `V1__init_{schema}_schema.sql`(각 앱 resources).

---

## 2. 사전 준비 (T-N일, **무중단** — 점검 전에 미리)

### 2.1 코드/이미지
- [ ] MR !192 · MR !197 (→ `rc/db-ownership-split`) · PR #20 (→ `master`) 리뷰 최종 확인.
- [ ] (dev 리허설) 위 브랜치를 dev 배포 대상으로 빌드 → **신규 이미지 태그 확보**(전 앱 + mydata-mgmts). 태그 기록: `__________`.
- [ ] **이전(현행) 이미지 태그 백업**(롤백용). 앱별 현재 running 태그 기록: `__________`.
- [ ] **🔴 [필수·크리티컬] native/비정형 SQL 스키마 한정** — 엔티티 `@Table(schema=)` 는 JPA만 커버하고 **native SQL은 미커버**. 감사 결과 **깨질 SQL 108건**(구 테이블명·미지정; bomapp 59·mydata 15·chat/kakaopay 11·기타 8·planner 7·bomapp-api 8). 컷오버 전 **모든 native/JdbcTemplate/createNativeQuery 의 테이블 참조를 `schema.신규명` 으로 완전 한정**(migrated→schema.newname, 잔류→bomapp_member.name). → 별도 수정 완료가 컷오버 선결.
- [ ] **🔴 [필수·크리티컬] e2e 하네스 멀티스키마 이관** — e2e 는 Testcontainer + Flyway `V1__baseline.sql`(구 단일스키마·구명). 어노테이션+native 수정 후 **e2e 는 5스키마+개명 테이블 baseline/seed 로 이관**해야 CI 그린(안 하면 `chat.message` 미존재로 대량 실패). MR !197 검증 조건.
- [ ] 커넥션 default 스키마 = `bomapp_member` 권장(잔류/미한정 catch-all; 위 완전 한정 후엔 저위험).
- [ ] 미매핑 테이블(예 notice_member, cancer_category) 개별 확인(잔류 or 기존 버그).

### 2.2 스키마/데이터 (CDC)
- [ ] 대상 클러스터의 5개 신규 스키마 존재 + 테이블/컬럼 최신(V1 반영) 확인.
- [ ] **CDC 건강성**: 5개 DMS 태스크가 `running`(cdc)이고 **lag 정상**인지 확인. ⚠️ dev는 현재 chat/planner 태스크가 `failed` 이력 → **리허설 전 재기동/재싱크 필요**(안 그러면 stale 데이터로 컷오버됨).
- [ ] 신규 스키마 = `bomapp_member` 동등성 1차 확인(행수 대조 등, 창 전 baseline).

### 2.3 시크릿 값 주입 (운영자)
- [ ] `bomapp/{env}/datasource/{schema}` 5개에 값 주입: `write-url`/`read-url`(writer/reader 엔드포인트) + `username`/`password`.
  - **URL DB(default 스키마)**: 각 스키마명(예 `/chat`) 로 지정. (엔티티가 @Table(schema)로 한정되므로 default는 미한정/잔류 접근 대비 — 팀 규칙 확정: 홈 스키마 vs `/bomapp_member`.)
  - chat 시크릿은 `chat-username`/`chat-password` 키(chat-api DataSourceConfig 참조).
  - mydata-mgmts는 별도 없음 — `datasource/mydata` 공유(단, `spring.datasource.url` 불요 = reader/writer 사용).
- [ ] 값 형식 검증(파라미터 = 기존 동작 URL과 동일: autoReconnect/useUnicode/characterEncoding/serverTimezone/useSSL).
- [ ] **🔴 [필수] 앱별 ECS task role 의 시크릿 read IAM 갱신** — 앱이 `datasource/{schema}` 를 **Spring Cloud AWS 로 런타임 resolve**(ECS task-def secrets 아님)하므로, 각 앱의 **task role** 이 새 시크릿 ARN 에 `secretsmanager:GetSecretValue`(+`DescribeSecret`) 권한이 있어야 한다. 없으면 `spring.config.import`(non-optional) 실패 → **`APPLICATION FAILED TO START`**(로그엔 secret "does not exist" — 실은 IAM 거부). **특히 별도 IAM 롤을 가진 서비스**(예: GitHub 오리진 `mydata-mgmts-api` — `prod-mydata-mgmts-api-task-role`) 는 구 시크릿 ARN 에만 걸려 있어 누락되기 쉽다. **사고 사례(2026-07-21): mydata-mgmts-api TD:9 부팅실패 → 롤백** (infra `modules/prod/iam.tf` 의 role policy 에 `bomapp/prod/datasource/mydata-*` 추가로 해소, MR!86). 검증: `aws iam simulate-principal-policy --policy-source-arn <task-role> --action-names secretsmanager:GetSecretValue --resource-arns <새 시크릿 ARN>` = `allowed`.

### 2.4 DB 계정 grant (앱-스키마 매트릭스)
> 각 `datasource/{schema}` 커넥션 유저는 **그 커넥션을 쓰는 앱들이 접근하는 모든 스키마**에 grant 필요(크로스 스키마 write가 조밀 — 앱-스키마 분석 결과). 예: `datasource/bomapp`(bomapp-api/batch/statics/recipient/open) 유저는 bomapp + planner + chat + messaging + mydata + bomapp_member 에 grant 필요.
- [ ] `datasource/chat` 유저 grant: chat + planner(w_planner/notification/w_planner_member) + bomapp_member(member_view).
- [ ] `datasource/planner` 유저 grant: planner + chat + mydata + bomapp + messaging + bomapp_member (wings-api 광범위).
- [ ] `datasource/mydata` 유저 grant: mydata + planner + chat + bomapp_member (mydata-api/batch + mydata-mgmts: member/member_view=bomapp_member).
- [ ] `datasource/bomapp` 유저 grant: bomapp + planner + chat + messaging + mydata + bomapp_member.
- [ ] `datasource/messaging` 유저 grant: messaging + (recipient-extractor read: bomapp/mydata/planner/bomapp_member).
- [ ] **bomapp-webview(레거시, PROD-BACK 분리 7778) DB 계정 grant**: `bomapp`(policy) + `mydata`(org) **SELECT only**(read-only 앱). webview는 next-backend datasource 시크릿과 **별개인 레거시 계정** — 그 계정에 두 스키마 read 부여. PR #1312 배포 전제(미부여 시 webview 조회 실패).
- [ ] grant는 **컷오버 전 미리 적용해도 무해**(read/write 권한 부여일 뿐, 앱이 신규 이미지로 배포돼야 실제 사용). SELECT+INSERT/UPDATE/DELETE 최소권한 기준.
- [ ] grant 적용 스크립트 + **revoke(롤백) 스크립트** 준비.

### 2.5 점검 페이지 자산 (§3에서 켠다)
- [x] 점검중 HTML 준비(보맵/플래너 공용) — **✅ CF 쪽 완료(2026-07-20, infra MR !85)**: `prod-maintenance-page` CF Function(viewer-request 503 + 인라인 HTML, Figma 플래너_점검 안내 1:6343 시안). 정적 자산 업로드 불필요(전량 인라인, ~4.2KB). 미리보기: `docs/db-ownership-split/maintenance-page-preview.html`. **구성·활성화 절차 정본: `docs/maintenance-page-runbook.md`** (컷오버 이후 일반 점검에도 재사용).
- [ ] **적용 지점 매핑 확정**(환경별 LB/CF):
  - **보맵 웹**: **✅ CF 토글 커버 확인(07-21 실전, 정정)** — 실접근 도메인은 `web-2z9w75bv.bomapp.co.kr`·`bomapp.im`(둘 다 `static_site_prod["web"]` 배포 alias, CF 엣지 실측). `"web"` 키로 점검화면 정상 노출됐음. **⚠️ 검증 함정: `web.bomapp.co.kr` 호스트는 CNAME→prod-nlb(비-CF 별개 경로)라 이 호스트로 테스트하면 무효과로 오판**(07-21 실제 발생, 사용자 정정) — 검증은 실접근 도메인으로 할 것. 상세: `docs/maintenance-page-runbook.md`.
  - **보맵 앱**(네이티브 → bomapp-api / dev-bapi): 앱은 API로 동작 → **ALB listener 규칙 fixed-response(503 + 점검 JSON/HTML)** 로 API 차단. (앱이 503/점검코드를 점검화면으로 처리하는지 확인; 미처리면 최소한 write 차단 효과.) **⚠️ 미준비 — CF Function 은 웹만 커버.**
  - **플래너 웹**(planner/dplanner.bomapp.co.kr): **✅ CF Function 토글 준비 완료** (`"planner"`, `"dplanner"`).
  - **플래너 앱**(→ chat-api/wings-api/bomapp-api = dev-chat 등): 해당 API 호스트 ALB fixed-response. **⚠️ 미준비.**
  - chat WebSocket(chat-api): 연결 차단 규칙 포함. **⚠️ 미준비.**
  - (선택) padmin/console/apps CF 도 동일 토글로 커버 가능 — 대상 포함 여부만 결정.
- [ ] **현행 LB/CF 규칙 스냅샷 백업**(롤백용): ALB listener rules 원본 export. (CF 쪽은 TF 토글이라 별도 백업 불필요 — 기본값 `[]` 복귀 apply = 원복.)

### 2.6 커뮤니케이션/윈도우
- [ ] 점검 공지(사용자/설계사), 윈도우 시간 확정, 관계자 대기.
- [ ] 롤백 판단 기준·타임박스 정의(예: 검증 T+30분 내 실패 시 롤백).

---

## 3. 컷오버 윈도우 (**다운타임**)

### 3.1 점검 페이지 ON
- [ ] **CF(웹) ON** — infra 클론 `terraform/` 에서 (`.env` source + `TF_VAR_es_api_key` export 후):
  ```bash
  terraform apply \
    -target='module.prod.aws_cloudfront_function.maintenance_page_prod' \
    -target='module.prod.aws_cloudfront_distribution.static_site_prod' \
    -var 'prod_maintenance_sites=["web","planner","dplanner"]' \
    -var 'prod_maintenance_schedule_text=점검 시간 : 2026년 7월 21일 오전 0시 - 오전 1시'
  ```
  - dry-run 검증 완료(2026-07-20): function 1 add + web/planner/dplanner 3 in-place change (+ shared ACM 태그 메타데이터 무해 변경 1건 동반). destroy 0.
  - 반영 소요: apply 후 CloudFront 전파 수 분. 각 도메인 실제 접속으로 503 점검 페이지 확인.
  - **✅ 실행됨(2026-07-21 00시 창, saved plan `maintenance_on.tfplan`)**: apply 1 added/3 changed/0 destroyed. 검증 — planner·dplanner=503+점검HTML(문구·no-store·retry-after 확인), apps=200(비대상 무영향). **web 키도 유효 — 보맵 웹/앱·플래너 웹/앱 전부 점검화면 정상 노출(사용자 확인). 당시 `web.bomapp.co.kr` 호스트로 검증해 "무효과"로 일시 오판했으나 실접근 도메인은 web-2z9w75bv/bomapp.im(§2.5 검증 함정 참조, 07-21 정정).**
- [ ] **ALB(앱 API) ON** — bomapp-api/chat-api/wings-api 등 fixed-response 규칙 적용(§2.5 매핑, 별도 준비 필요).
- [ ] **보맵 웹·앱, 플래너 웹·앱 전부 점검중 노출** 확인(각 도메인 실제 접속 테스트).
- [ ] 롤백 지점 R1: 규칙 원복하면 즉시 서비스 재개(아래 §5).

### 3.2 write quiesce (원본 정지)
- [ ] 앱 트래픽 차단 확인 후, **앱 인스턴스 정지/스케일다운**(desired=0) 또는 write 완전 차단. 목적: `bomapp_member` 로의 신규 write 중단.
- [ ] 진행 중 트랜잭션/배치 종료 대기(특히 *-batch 앱).

### 3.3 CDC 최종 드레인
- [ ] 5개 DMS 태스크 **lag → 0**(CDCLatency 0, 소스=타깃 수렴) 확인. → 신규 스키마 = `bomapp_member` 최신 동일본.
- [ ] 행수/체크섬 최종 대조(창 전 baseline 대비 증분 반영 확인).

### 3.4 CDC 중지
- [ ] 5개 DMS 태스크 **stop**(정지, 삭제 아님). 신규 스키마 = 이제부터 앱이 단일 writer.
- [ ] (롤백 대비) 이 시점 신규 스키마 상태 = `bomapp_member` 동일본으로 고정.

### 3.5 grant 최종 적용/검증
- [ ] §2.4 grant가 적용됐는지 각 datasource 유저로 실제 접속 + 대상 스키마 테이블 SELECT/DML 권한 스모크.

### 3.6 신규 이미지 배포 (전 앱 **동시** flip)
- [ ] 전 next-backend 앱(bomapp-api·chat-api·mydata-api·mydata-batch·open-api·bomapp-batch·statics-batch·wings-api·recipient-extractor) + mydata-mgmts-api를 **신규 이미지 태그**로 배포(§2.1). desired 원복.
- [ ] 부팅 로그: `datasource/{schema}` 연결 URL 확인, DataSource 라우팅 정상, 스키마 조회 성공.

### 3.7 검증 (핵심)
- [ ] 헬스체크 전 앱 green.
- [ ] **신규 스키마 write 스모크**: 각 소유 스키마에 실제 write 발생(예: 채팅방 생성→chat, 상담신청→planner/chat/messaging, 마이데이터 조회 적재→mydata) → 해당 신규 스키마 테이블에 row 확인.
- [ ] **`bomapp_member` no-write 확인**: 컷오버 후 원본 스키마에 신규 write가 없는지(카운트 정지) 확인 = 앱이 신규 스키마로만 쓰는지.
- [ ] 크로스 스키마 read/write 경로 스모크(설계사 로그인·추가정보 알림·상담 배정 등 대표 흐름).
- [ ] 에러율/로그(ES) 정상.

### 3.8 점검 페이지 OFF
- [x] **✅ 실행됨(2026-07-21, saved plan `maintenance_off.tfplan`)**: apply 0 added/4 changed/0 destroyed(연결 해제 3 + function 문구 초기화). 검증 — planner·dplanner **200 정상 복귀**, web 404(평시 그대로), apps 200. **`prod-maintenance-page` function 은 재사용 위해 상시 존치**(사용자 지시) — 다음 점검 시 §3.1 커맨드 재사용.
- [ ] **CF(웹) OFF** — `-var` 두 개를 빼고 동일 -target apply (기본값 `[]` 복귀 = function 연결 해제):
  ```bash
  terraform apply \
    -target='module.prod.aws_cloudfront_function.maintenance_page_prod' \
    -target='module.prod.aws_cloudfront_distribution.static_site_prod'
  ```
  - viewer-request 고정 응답이라 캐시 미경유 — invalidation 불필요, 전파 완료 즉시 정상 서빙.
- [ ] **ALB(앱 API) OFF** — fixed-response 규칙 원복.
- [ ] 각 도메인 정상 응답 확인.
- [ ] 컷오버 완료 선언.

---

## 4. 사후 (안정화 & 정리)
- [ ] N시간/일 집중 모니터링(에러율·지연·DB 커넥션·CDC 정지 상태 유지).
- [ ] **롤백 윈도우 유지**: `bomapp_member`(원본) + 정지된 CDC 태스크를 **일정 기간 보존**(즉시 롤백 가능하도록). 이 기간 bomapp_member는 stale 되지만 롤백 안전판.
- [ ] 안정 확인 후(별도 승인): DMS teardown(`dms_{env}_enabled=false`) + `bomapp_member` 중복(이관된) 테이블 정리 + 구 datasource-* 시크릿 삭제.
- [ ] 문서/카탈로그 갱신(services.yaml·docs/services): 앱별 datasource=스키마, 오너십 상태 = 컷오버 완료.

---

## 5. 롤백 계획 (단계별 — 원칙: `bomapp_member` 무손상 → 이전 이미지 복귀)

> 컷오버 윈도우 중에는 `bomapp_member` 에 write가 없으므로(§3.2), **어느 단계에서 실패해도 이전 상태로 안전 복귀** 가능. 신규 스키마에 발생한 시험 write는 폐기(또는 무시)한다.

| 실패 시점 | 롤백 절차 |
|-----------|-----------|
| **R1** 점검 ON 후~write quiesce 전 | LB/CF 규칙 원복(§2.5 백업). 아무 것도 안 바뀜 → 즉시 정상. |
| **R2** CDC 드레인/중지 후, 배포 전 | DMS 태스크 재기동(running) → CDC 재개. 앱은 아직 구이미지/정지 → 재기동 시 `bomapp_member` 로 정상 동작. 점검 OFF. |
| **R3** 신규 이미지 배포/검증 실패 | ① 앱 정지 → ② **이전 이미지 태그로 재배포**(구 datasource=bomapp_member, 엔티티 미어노테이션) → ③ 헬스 확인 → ④ (원한다면 CDC 재기동) → ⑤ 점검 OFF. 신규 스키마의 시험 write는 폐기(다음 시도 전 재싱크). |
| **R4** 점검 OFF 후 지연 발견 | 재점검 ON → R3 절차 → 점검 OFF. (데이터: 컷오버 후 신규 스키마에 쌓인 실 write가 있으면 롤백 시 유실/불일치 → **점검 OFF 직후 집중 모니터링으로 조기 판단**, 실 트래픽 누적 전에 결정.) |

- [ ] 롤백 아티팩트 준비 확인: 이전 이미지 태그, 구 시크릿 값 백업, grant revoke 스크립트, LB/CF 규칙 백업, DMS 재기동 절차.
- [ ] **데이터 롤백 주의**: 점검 OFF(실서비스 재개) 이후 시간이 지나 신규 스키마에 실 write가 누적되면 단순 이미지 롤백만으로는 데이터 불일치. 따라서 **검증(§3.7)은 점검 OFF 전에 충분히** 하고, OFF 후 롤백 판단은 타임박스 내로 짧게.

---

## 6. dev 리허설 체크리스트 (이 문서대로 1회 완주)
- [ ] dev 클러스터/스키마/CDC 상태 확인(chat/planner 태스크 failed → 재기동·재싱크 선행).
- [ ] dev 시크릿 값 주입 + grant 적용.
- [ ] dev 신규 이미지 빌드(MR !192/!197/PR#20 반영).
- [ ] §3 전 과정 수행(점검 ON→quiesce→CDC drain/stop→배포→검증→점검 OFF).
- [ ] §5 롤백도 **1회 실제 연습**(R3 시나리오: 신규배포→롤백→구이미지 정상 확인)해 절차/시간 측정.
- [ ] 리허설에서 발견된 갭(호스트/LB 규칙/grant/default 스키마/네이티브쿼리 등)을 이 문서에 반영 후 stg/prod 적용.

> 리허설 산출물: 각 단계 소요시간, 실패/롤백 포인트, 미비 grant/규칙 목록. → prod 윈도우 산정 근거.
