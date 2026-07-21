# legacy-backend(webview) 폐기 분석 — Phase 0 트래픽 실측

> 목적: legacy-backend 에 유일하게 남은 `bomapp_webview_server`(web.bomapp.co.kr) 를 폐기하기 위한 근거로,
> 실제 살아있는 엔드포인트를 LB 로그로 식별한다. (사용자 요청: 약관/정책은 bomapp-console 관리+API 로 이관,
> 외부 리다이렉트는 엣지로 대체, 나머지는 이관/폐기 판정.)

## 방법
- 소스: prod-alb 액세스 로그 `elb_logs.alb_raw`(raw `line`, 수동 파티션) — `s3://bomapp-access-logs/prod-alb/...`.
- 창: **2026-01-01 ~ 07-21 (YTD, ~6.7개월)**. (alb_raw 는 Hive 레이아웃이 아니라 MSCK REPAIR 불가 → 일자 파티션을 `ALTER TABLE ADD PARTITION` 으로 명시 등록. S3 로그는 2023년치까지 보존.)
- 필터: `line LIKE '%web.bomapp.co.kr%'` + webview 소유 prefix(`/policy /notice /faq /play /market /payment /contract`)만. 봇 스캔(`.php`, `/wp-*`, `.env`, `.git` 등)·타호스트 쿼리스트링 오탐 제외.
- ⚠️ `/api/member`, `/my-insurance`, `/insurance-claim`, `/front-version`, `/planner-members`, `/members`, `/api/nice`, `/api/mydata-*` 등은 **webview 소스에 매핑 0** → webview 소유 아님(다른 호스트 오탐). webview 컨트롤러 = 10개(api/v1) + api/v2/PolicyController.

## 카테고리 롤업 (2026 YTD)

| 카테고리 | total | ok | 4xx | 5xx | 판정 |
|---|--:|--:|--:|--:|---|
| /policy | 7193 | 6544 | 277 | 372 | 지배적·LIVE |
| /notice | 3311 | 2634 | 466 | 211 | LIVE(오류율 높음, main 342 4xx) |
| /play | 610 | 431 | 88 | 91 | LIVE(오류율 높음) |
| /contract | 42 | 0 | 6 | 36 | **100% 실패(깨짐)** |
| /market | 30 | 18 | 7 | 5 | 저volume 실거래 |
| /payment | 20 | 20 | 0 | 0 | 저volume, 정상 |
| /faq | 17 | 17 | 0 | 0 | 저volume, 정상 |

## policy 상세 (52개 중 31개 트래픽 있음, 21개 0)

**고volume(=console 관리+API 이관 1순위, S3 정적):** privacy-policy/latest(2964), policy-code/{id}(1760), terms-of-service/latest(1495), member-marketing/latest(683) — policy 트래픽의 ~93%.

**에피소딕이지만 LIVE(폐기 불가, 이관/보존):** nice 통신사 본인인증 동의 15종(skt·kt·lgt × personal/unique-id/use-carrier/use-service/mvno, 각 1~30) → **외부 `cert.vno.co.kr` 리다이렉트**(엣지 리다이렉트로 대체 가능). collection-use-personal-info(24), my-data-transmission(7), planner/family-third-parties(3/3), my-data-integration-authorization-terms(≈5), my-data-privacy-collection(1), pet/agree-pet-insurance(1), health-checkup(1), credit(1), medical-history(1). policy **v2** = latest/code/{id}(3, 미미).

**🔴 6.7개월 트래픽 0 (폐기 후보 — 제품/법무 확인 후):**
- travel/* 5종: collection-user-personal-info, inquiry-person-info, provision-person-info, unique-identification-info, consent-consignment-person-info
- pet/* 7종: agree-group-insurance, agree-collection-use-personal-info, agree-inquiry-person-info, agree-provision-person-info, consent-consignment-person-info, provision-third-parties-partner, provision-third-parties-samsung
- certificate-register-mobile, family-health-checkup, guarantee-analysis-survey, insurance-car
- terms-of-service-credit, privacy-policy-credit
- my-data-integration-authorization-consignment, -privacy, my-data-privacy-provision

## 🔴 호출되는데 깨진 엔드포인트 (고치거나 드롭 판정)
- `/contract/v1/{id}/member/{id}` — 36건 **100% 5xx**
- `/policy/v1/main` — 14건 **100% 5xx** (약관목록 뷰 `findByPolicyGroup` native)
- `/notice/v1/main` — 1302건 중 342 4xx + 122 5xx(오류율 ~36%)
- `/play/v1/event/{id}` — 420건 중 70 4xx + 90 5xx
- `/market/v1/heungkuk-gibs-insurance/subscribe` — 대부분 5xx (Chubb travel subscribe 는 7/9 정상)

## 이관/폐기 분류 (계획 입력)
1. **console 관리+API 이관(사용자 제안, 1순위)**: policy 고volume 4종(privacy/terms/policy-code/member-marketing) — S3 정적 HTML → console 버전관리 + (리다이렉트 계약 유지)페이지/콘텐츠 API.
2. **엣지 리다이렉트로 대체**: nice/* 15종(외부 cert.vno.co.kr). web.bomapp.co.kr 경로 보존(출시앱 하드코딩).
3. **이관 대상(실사용)**: notice(3311), play(610) → next-backend/console API.
4. **폐기 후보(0 트래픽, 제품/법무 확인)**: 위 21개 policy + 저volume 미사용.
5. **제품 결정 필요(저volume 실거래)**: market(Chubb 여행보험·흥국 GIBS), payment.
6. **깨진 채 호출(원인규명)**: contract/v1, policy/v1/main, notice/main, play/event.
7. **잔존 live 경로 façade화 → legacy-backend ECS 폐기** + PROD-BACK 잔재 정리.

## 남은 확인 항목
- 소비자(앱 화면·출시 버전) 매핑: 각 경로를 어떤 앱 화면/버전이 호출하는지(경로 보존 필요기간 산정).
- 21개 0-트래픽 policy: 제품 존폐·법적 게시의무 확인 후 드롭.
- contract/v1·policy/v1/main 500 원인(ES `logs-prod-bomapp-webview`).

---

## Phase 1 — 폐기 실행 계획 (Phase 0 실측 기반)

> 목표: `web.bomapp.co.kr` 실 트래픽을 흡수하는 **잔존 live 경로를 이관/대체**한 뒤 legacy-backend(webview) ECS 를 façade화 → **폐기**. 참고: BOM-399 컷오버로 webview 는 이미 새 스키마(`bomapp.policy`·`mydata.org`) read-only 정합 완료 = 의존 테이블 policy/org **2개뿐**(PR #1312/#1314). 즉 폐기의 데이터 결합도는 이미 최소.

### 워크스트림 (분류 → 액션)

| WS | 대상 (Phase 0 실측) | 액션 | 비고 |
|----|------|------|------|
| **W1** | policy 고volume 4종 — privacy-policy/latest·terms-of-service/latest·policy-code/{id}·member-marketing/latest (policy 트래픽 ~93%) | **console 관리+API 이관** (S3 정적 + 버전관리, 리다이렉트 계약 유지) | bomapp-console SPA 전환(BOM-385/387)과 정렬. 1순위. |
| **W2** | nice 통신사 본인인증 15종 (skt·kt·lgt × personal/unique-id/…) | **엣지 리다이렉트** (CF Function/ALB redirect → 외부 `cert.vno.co.kr`) | web.bomapp.co.kr 경로 보존(출시앱 하드코딩). legacy 로직 불요. |
| **W3** | notice(3311)·play(610) — 실사용 동적 | **next-backend/console API 이관** | 컨트롤러+DB 접근 차세대 이관. |
| **W4** | contract/v1(100% 5xx)·policy/v1/main(100% 5xx)·notice/main(~36% err)·play/event·market heungkuk subscribe | **원인규명 → 수정 or 폐기 판정** | ES `logs-prod-bomapp-webview` 스택트레이스 확보. |
| **W5** | 0-트래픽 21종(travel/pet/credit 계열 등) + 저volume 미사용 | **폐기** | 🔴 **제품·법무 게이트 필수**(법적 게시의무 확인 후 드롭). |
| **W6** | market(Chubb 여행/흥국 GIBS)·payment 저volume 실거래 | **제품 존폐 결정** | 🔴 제품 게이트. |
| **W7** | W1~W6 완료 후 잔존 façade | **legacy-backend(webview) ECS 디커미션** + PROD-BACK 잔재 정리 | web.bomapp.co.kr(prod-nlb→prod-alb prio260 TG) 라우팅 회수. |

### 🔴 인간 게이트 (Leader 결정 불가 — 에스컬레이션 대상)
- **21개 0-트래픽 policy**의 법적 게시의무/제품 존폐 (법무·제품팀).
- **market/payment** 저volume 실거래 존폐 (제품팀).
- **소비자 경로 하드코딩 매핑** → 경로 보존 필요기간 산정 (앱팀; 출시 버전별).

### 다음 실행 스텝 (Leader 진행 가능 — 게이트 무관)
1. **W4 500 원인규명**: ES `logs-prod-bomapp-webview` 로 `contract/v1`·`policy/v1/main`(findByPolicyGroup native 그룹쿼리) 스택트레이스 확보 → 수정 vs 폐기 판정. (policy/v1/main 은 BOM-399 컷오버 전후 모두 500 = 기존 버그, 컷오버 무관 확인됨.)
2. **소비자 매핑**: webview 컨트롤러 경로 ↔ 네이티브/웹 호출부 grep (next-frontend·앱 리포). 경로 보존 필요기간 산정 입력.
3. **W1/W2 티켓화**: 폐기 에픽 + 워크스트림 서브이슈(인수조건 명시). ⚠️ 워크스페이스 Linear 이슈 한도 확인 후(과거 free 한도 초과 이력).

> 상태: Phase 0(트래픽 실측) 완료 → Phase 1 계획 수립. 실행 착수는 W4 원인규명 + 소비자 매핑(Leader) 및 제품/법무 게이트(W5/W6) 해소 후.
