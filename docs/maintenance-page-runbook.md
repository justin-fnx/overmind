# 점검중(Maintenance) 페이지 — 구성과 활성화 Runbook

> **정본.** prod 웹 표면에 "현재 서비스 점검 중 입니다" 페이지를 띄우고 내리는 절차.
> 최초 구축: BOM-399 DB 오너십 분리 컷오버(infra **MR !85**, 2026-07-20). **2026-07-21 00시 컷오버 창에서 ON→OFF 실전 검증 완료.** function 은 재사용을 위해 상시 존치한다.

## 1. 구성 형태 (Architecture)

```
사용자 → CloudFront 엣지 → [prod-maintenance-page function: 즉시 503 + 인라인 HTML] ✂️
                             (viewer-request 훅 = 캐시 조회·S3 오리진보다 앞 — 여기서 종료)
```

- **본체 = CloudFront Function 1개** `prod-maintenance-page` (runtime `cloudfront-js-2.0`).
  - 소스 정본: infra `terraform/modules/prod/templates/maintenance-page.js.tftpl`
  - TF 리소스: infra `terraform/modules/prod/cloudfront.tf` `aws_cloudfront_function.maintenance_page_prod`
- **점검 HTML 은 function 코드 안에 문자열로 내장** — HTML/CSS/일러스트 SVG 전량 인라인(~4.2KB, 한도 10KB). S3 업로드·외부 에셋·폰트 로드 0건(시스템 폰트 폴백). 응답은 엣지 메모리에서 직접 생성되고 **캐시를 타지 않는다**(생성 응답 + `no-store`) → invalidation 불필요, 해제 즉시 원복.
- **응답**: `503 Service Unavailable` + `retry-after: 7200` + `cache-control: no-store` + `noindex` 메타 → 일시 점검 시그널(SEO 디인덱싱 없음).
- **디자인**: Figma `플래너_점검 안내` (file `L3uNtfAOu2EyAjZ5fR3epg`, node `1:6343`). 로컬 미리보기 사본: `docs/db-ownership-split/maintenance-page-preview.html`.
- **토글 메커니즘**: `static_site_prod` 배포들(dplanner/planner/padmin/console/apps/web)의 default behavior 에 `dynamic "function_association"` — **`prod_maintenance_sites` var 에 키가 포함된 배포만** viewer-request 로 연결된다. 평시 기본값 `[]`/`""` = 미연결·plan 무변경.
  - 점검 시간 문구는 `prod_maintenance_schedule_text` var 로 templatefile 주입(빈 값 = 줄 생략). 값 변경 = function 자동 재publish(같은 apply 에 포함).

### 커버리지 (⚠️ 중요)

| 표면 | 커버 | 비고 |
|---|---|---|
| 플래너 웹 `planner`/`dplanner.bomapp.co.kr` | ✅ CF 토글 | 07-21 실전 검증 |
| **보맵 웹 — 실접근 도메인 `web-2z9w75bv.bomapp.co.kr` · `bomapp.im`** | ✅ CF 토글 (`"web"` 키) | 두 도메인 모두 `static_site_prod["web"]` 배포의 alias(CF 엣지 IP 실측 확인). **07-21 실전 노출 확인.** |
| `padmin`/`console`/`apps` | ✅ 가능 | 키만 추가 |
| 네이티브 앱(보맵/플래너 앱) 화면 | ✅ 노출 확인(07-21) | 보맵/플래너 앱 모두 점검화면 정상 노출(앱 내 웹 화면이 CF 도메인 로드 경로로 추정). 단 **API 레벨 write 차단**까지 필요하면 bapi/chat/wapi ALB fixed-response 는 별도 |
| dev/stg | ➖ 미구현 | prod 모듈 전용. 필요 시 동일 패턴을 dev/stg static site 에 복제 |

> **⚠️ 검증 함정 — `web.bomapp.co.kr` 호스트로 테스트하지 말 것.** 이 호스트는 Route53 `bomapp_co_kr_web_cname` = **CNAME → prod-nlb**(비-CF 별개 경로, 평시 루트 404)라서 CF 토글의 효과가 보이지 않는다. 07-21 창에서 이 호스트로 검증하다 `"web"` 키가 무효과라고 **오판**했었고, 실제로는 실접근 도메인(web-2z9w75bv/bomapp.im)에서 정상 노출 중이었다(사용자 확인으로 정정). **검증은 반드시 `web-2z9w75bv.bomapp.co.kr` 또는 `bomapp.im` 으로.**

## 2. 활성화 (ON)

전제: VPN 연결(GitLab state 백엔드), infra 클론 `terraform/` 에서 `set -a; source .env; set +a` + `export TF_VAR_es_api_key="$(cat ~/.bomapp-secrets/es_tf_template_key)"`.

```bash
terraform plan -out=maintenance_on.tfplan \
  -target='module.prod.aws_cloudfront_function.maintenance_page_prod' \
  -target='module.prod.aws_cloudfront_distribution.static_site_prod' \
  -var 'prod_maintenance_sites=["planner","dplanner"]' \
  -var 'prod_maintenance_schedule_text=점검 시간 : YYYY년 M월 D일 오전 0시 - 오전 1시'
# 예상 diff: function 1 change(문구 주입) + 대상 배포 N개 in-place(+ shared ACM 태그 메타 무해 rider). destroy/replace 0 확인 후:
terraform apply maintenance_on.tfplan
```

- **반드시 `-target`** — blanket plan 엔 무관 드리프트(다수 destroy 포함)가 섞여 있다.
- 전파: apply 후 CloudFront 배포 업데이트 수 분(배포별 상이).
- 검증: `curl -sI https://planner.bomapp.co.kr/` → `HTTP/2 503` + 본문에 "점검 중 입니다" / 비대상 도메인 200 유지.

## 3. 해제 (OFF)

`-var` 두 개를 빼고 동일 `-target` plan/apply (기본값 `[]` 복귀 = 연결 해제, function 은 존치):

```bash
terraform plan -out=maintenance_off.tfplan \
  -target='module.prod.aws_cloudfront_function.maintenance_page_prod' \
  -target='module.prod.aws_cloudfront_distribution.static_site_prod'
terraform apply maintenance_off.tfplan
```

- 검증: 대상 도메인 200 복귀. 캐시 미경유 설계라 별도 invalidation 불필요.

## 4. 문구·디자인 변경

- **점검 시간 문구**: ON 커맨드의 `-var prod_maintenance_schedule_text` 값만 교체(함수 재publish 자동).
- **페이지 본문/디자인**: `maintenance-page.js.tftpl` 편집 → MR → apply. **총 function 코드 10KB 한도** 주의(현재 ~4.2KB). 미리보기는 tftpl 에서 백틱 사이 HTML 을 추출해 `${schedule_text}` 치환 후 브라우저로 열면 됨(기존 사본: `docs/db-ownership-split/maintenance-page-preview.html`).

## 5. 이력·함정

- **2026-07-21 컷오버 창 실전**: ON(1 added/3 changed/0 destroyed) → **보맵 웹/앱·플래너 웹/앱 전부 점검화면 정상 노출**(web/planner/dplanner 3키 모두 유효), OFF → 200 복귀. 당시 `web.bomapp.co.kr` 호스트로 검증하는 바람에 "web 무효과"로 일시 오판 → 실접근 도메인(web-2z9w75bv/bomapp.im) 기준으로 정정(위 검증 함정 참조).
- ACM 태그 메타데이터 변경이 -target 의존성으로 plan 에 동반될 수 있음 — 속성 변경 0 이면 무해(재발급 아님).
- `glab mr merge`·prod apply 는 permission classifier 에 막힐 수 있음 → saved plan 을 사용자에게 넘기거나 개별 승인.
- 관련 문서: 컷오버 적용 사례 = `docs/db-ownership-split/cutover-runbook.md` §2.5/§3.1/§3.8 · 카탈로그 = `services.yaml` infra notes.
