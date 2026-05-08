# Runtime Verification — 직접 검증된 사실

> 본 문서는 **추정이 아니라 직접 검증된 사실** 만 기록한다. 각 항목은 검증 방법(SSM Run Command / AWS CLI / Terraform 코드 / ALB access log) 과 검증 일자를 명시한다.
> 추정·추측은 본 문서에서 제외한다. 추정은 [`architecture.md`](./architecture.md) 와 [`services/`](./services/) 의 본문에 caveat 와 함께 기재.

| 항목 | 값 |
|------|----|
| 1차 검증 일자 | 2026-05-07 |
| 검증자 IAM | `arn:aws:iam::044488971141:user/justin` |
| 사용 도구 | aws CLI, SSM Run Command, gunzip+grep+awk on ALB access log |

---

## 1. AWS 인프라 식별자 (검증)

| 항목 | 값 | 검증 |
|------|----|------|
| AWS Account | `044488971141` | `aws sts get-caller-identity` |
| Region | `ap-northeast-2` | 동일 |
| PROD-NLB ARN | `arn:aws:elasticloadbalancing:ap-northeast-2:044488971141:loadbalancer/net/prod-nlb/e66c1e153f747071` | `aws elbv2 describe-load-balancers --names prod-nlb` |
| PROD-ALB ARN | `arn:aws:elasticloadbalancing:ap-northeast-2:044488971141:loadbalancer/app/prod-alb/43fec03835989c8c` | `aws elbv2 describe-load-balancers --names prod-alb` |
| PROD-NLB DNS | `prod-nlb-e66c1e153f747071.elb.ap-northeast-2.amazonaws.com` (`15.164.25.64`) | `dig +short` |
| ALB Access Log S3 | `s3://bomapp-access-logs/prod-alb/AWSLogs/044488971141/elasticloadbalancing/ap-northeast-2/{YYYY}/{MM}/{DD}/` | `aws s3 ls` |
| NLB Access Log S3 | `s3://bomapp-access-logs/prod-nlb/...` | 동일 |

### 1.1 PROD-NLB 라우팅 (`aws elbv2 describe-listeners` 결과)

```
Port 80    → TG prod-nlb-to-alb-80      (forward → PROD-ALB:80)
Port 443   → TG prod-nlb-to-alb-443     (forward → PROD-ALB:443)
Port 3001  → TG prod-nlb-to-alb-3001    (forward → PROD-ALB:3001)
Port 3002  → TG prod-nlb-to-alb-3002    (forward → PROD-ALB:3002)
Port 5443  → TG prod-nlb-to-alb-5443    (forward → PROD-ALB:5443)
```

**모든 NLB listener 가 ALB 로 forward.** NLB 를 통과한 모든 트래픽은 PROD-ALB access log 에 기록되어야 한다.

---

## 2. PROD-BACK 클러스터 운영 실체 (SSM 검증)

### 2.1 검증 범위
- **검증된 인스턴스**: `i-03f0178089f760c6f` (hostname `prod-back-ecs-host-2`) — 1대만
- **미검증 인스턴스**: `i-09e36b30bad90990d` — 동일 클러스터, 별도 검증 필요
- **ECS 서비스**: `prod-next-backend-was-v5`, `prod-next-backend-was-v6` (둘 다 task definition family `prod-next-backend-was`, 각각 :7, :8 revision)
- 검증 명령: `aws ssm send-command --document-name AWS-RunShellScript`

### 2.2 컨테이너 형태

```
컨테이너명: ecs-prod-next-backend-was-7-next-backend-was-...
이미지:    044488971141.dkr.ecr.ap-northeast-2.amazonaws.com/next-backend-was:1.1
상태:      Up 3 years
entrypoint: /bin/sh -c /root/docker_entrypoint.sh   (실제로는 sleep 3600 만 실행)
volume:    /was/data (host volume)  →  컨테이너 /was/data
```

**핵심 사실**: 컨테이너는 단일 Spring Boot 앱이 아니다. 호스트의 `/was/data` 디렉토리가 마운트되어 있고, **사람이 컨테이너 내부에서 여러 jar 를 직접 띄우는 공용 WAS 패턴**으로 운영 중이다 (entrypoint 가 jar 를 실행하지 않고 sleep 만 함).

### 2.3 `/was/data` 디렉토리 (12개 항목)

| 디렉토리 | 의미 | 활성 (ps 에서 보임) |
|---------|------|:------------------:|
| `bomapp-api-prod` | next-backend / bomapp-api | ✅ |
| `bomapp-mydata-prod` | bomapp_my_data 프로젝트 | ✅ |
| `bomapp-oauth-prod` | 별개 OAuth 프로젝트 | ✅ |
| `bomapp-redmin-prod` | legacy-backend / redmin | ❌ (비활성) |
| `bomapp-vkey` | 별개 (Tomcat WAR, `bm.service=bomapp_key`) | ✅ |
| `bomapp-webview-prod` | legacy-backend / webview server | ✅ |
| `legacy-bomapp-api-prod` | legacy-backend / api server | ❌ (비활성) |
| `open-api-prod` | next-backend / open-api | ✅ |
| `saas-api-prod` | 별개 SaaS API | ❌ (비활성) |
| `wings-api-prod` | next-backend / wings-api | ✅ |
| `report_data_info.pdf` | 단일 파일 (1.2MB) | — |

> 비활성 디렉토리는 `i-09e36b30bad90990d` 인스턴스에 활성으로 떠 있을 가능성이 있으나 **미검증**.

### 2.4 활성 Java 프로세스 → 포트 매핑 (검증)

| PID | UID | jar | 출처 프로젝트 | listening 포트 | Spring Boot ver |
|----:|-----|-----|--------------|:-------------:|----------------|
| 1205 | bomapp | (Tomcat catalina bootstrap) | **bomapp-vkey** (별개, `bm.service=bomapp_key`) | (8005 shutdown, 65355 JMX 외 connector 포트는 별도 확인 필요) | Tomcat WAR (Spring Boot 아님) |
| 1428 | root | `bomapp_webview_server-0.1.0.jar` | **legacy-backend / bomapp_webview_server** | **7778** | SB 1.x (JDK 8) |
| 5953 | root | `bomapp-server-open-api.jar` | **next-backend / open-api** | **8105** | SB 3.4 |
| 10745 | root | `bomapp-server-bomapp-api.jar` | **next-backend / bomapp-api** | **8107** | SB 3.4 |
| 15890 | bomapp | `bomappmydata-0.0.1-SNAPSHOT.jar` | **bomapp_my_data** 프로젝트 | (host docker-proxy 11000 존재, 컨테이너 내 PID 매핑은 미확정) | SB 2.3 |
| 19422 | root | `bomapp-server-wings-api.jar` | **next-backend / wings-api** | **8102** | SB 3.4 |
| 32329 | bomapp | `bomapp_oauth-0.1.0.jar` | **별개 OAuth 프로젝트** | (확인 미흡) | (확인 미흡) |

### 2.5 운영상 함의

- **이미지 이름이 `next-backend-was` 라서 next-backend 로 단정하면 안 된다.** 컨테이너 내부에 여러 프로젝트의 jar 가 함께 떠 있는 공용 WAS 패턴.
- **`enable_execute_command = false`** + **awslogs 미설정** → 운영 가시성이 매우 낮음.
- 컨테이너 Up 3 years — 새 jar 배포는 ECS task 재시작이 아니라 컨테이너 안에서 jar 재기동으로 추정.

---

## 3. 호스트 헤더 → 실제 jar 매핑 (검증)

다음 매핑은 (a) Terraform listener_rule + (b) AWS CLI describe-rules + (c) SSM 으로 확인한 활성 listening 프로세스를 모두 교차 검증한 결과.

| 호스트 (PROD) | listener / priority | TG | 컨테이너 포트 | listening jar | 프로젝트 |
|--------------|---------------------|----|:------------:|---------------|----------|
| `bapi.bomapp.co.kr` | ALB:443 priority 170 | prod-back-ecs-host-http-8107 | **8107** | `bomapp-server-bomapp-api.jar` (PID 10745) | next-backend / bomapp-api |
| `web.bomapp.co.kr` | ALB:443 priority 260 | prod-back-ecs-host-http-7778 | **7778** | `bomapp_webview_server-0.1.0.jar` (PID 1428) | legacy-backend / bomapp_webview_server |
| `wapi.bomapp.co.kr` | ALB:443 (priority 미기재, 별도 rule) | (8102 TG) | **8102** | `bomapp-server-wings-api.jar` (PID 19422) | next-backend / wings-api |
| `oapi.bomapp.co.kr` 외 | (priority 별도) | (8105 TG로 추정) | **8105** | `bomapp-server-open-api.jar` (PID 5953) | next-backend / open-api |
| `sapi.bomapp.co.kr` | ALB:443 priority 150 + ALB:3001 priority 1 | prod-back-ecs-host-http-8103 | **8103 — listening 프로세스 없음** | — | (no-op, 502 발생 예상) |
| `vkey.bomapp.co.kr` | ALB:443 priority 10 | prod-back-ecs-host-http-8080 | **8080** (호스트 docker-proxy 존재, 컨테이너 내 PID 미확정) | (vkey Tomcat 의 connector 일 가능성, 미확정) | 미확정 |
| `api.bomapp.co.kr` (✱ 정리됨) | ALB:443 priority 160 | (정리 전: 8107) | — (현재 410 fixed-response) | — | — |
| `my-data-cbt.bomapp.co.kr` (✱ 정리됨) | 동일 priority 160 host header | — (현재 410 fixed-response) | — | — | — |

**(✱)** 사용자가 2026-05-07 에 listener rule 을 fixed-response 410 으로 정리. 본 문서의 "현재" 매핑은 정리 후 상태.

---

## 4. 7일 ALB Access Log 분석 (2026-04-30 ~ 2026-05-06)

검증 방법: `aws s3 sync` 로 7일치 PROD-ALB access log 다운로드 (542MB / 3,794 파일), `awk -F'"' '$8=="<host>"'` 로 정확 매칭.

### 4.1 도메인별 트래픽 (PROD-ALB 도달 기준)

| 호스트 | 7일 합계 | 정상 응답 (2xx/3xx) | 봇/스캐너 비율 |
|--------|--------:|------------------:|--------------:|
| `sapi.bomapp.co.kr` | **0** | 0 | — |
| `api.bomapp.co.kr` | 725 | 0 (2xx) | ~98% (.php/wp-*) |
| `my-data-cbt.bomapp.co.kr` | 3 | 0 (모두 401) | 0% (정상 path 이지만 인증 실패) |
| `web.bomapp.co.kr` | 2,608 | 483 (200 + 303) | ~80% (wp-login/wp-admin) |

### 4.2 sapi.bomapp.co.kr 결론
- 7일 0건. PROD-ALB 까지 도달하는 sapi 도메인 트래픽이 없음.
- "sapi" 단순 키워드 매칭 4건은 모두 봇이 ALB IP 직접 호출로 path `/sapi/debug/...` (PHP SAPI 익스플로잇) 시도 — 도메인이 sapi 가 아님.
- 라우팅 자체는 살아있으나(8103 TG → 컨테이너 8103) **listening 프로세스 부재**.

### 4.3 api.bomapp.co.kr (정리 전) 7일 분포
- status: 712 401, 5 500, 4 403, 4 400 — **2xx 0건**
- path: 711건 (98%) `.php`, `/wp-*` 봇. 14건 (2%) bomapp-api 정의 path 또는 유사 path (`/api/member/v1/logout` 6건 + `/api/address/v1/local` 8건 — 후자는 next-backend 어디에도 핸들러 없음)
- Client IP top 5: 모두 Microsoft Azure / DigitalOcean 봇 인프라
- UA top: 639건 UA 없음, 326건 `python-requests/2.33.1`, 위장된 Chrome 다수
- 결론: **정상 비즈니스 트래픽 0건**. 2026-05-07 정리 적용.

### 4.4 my-data-cbt.bomapp.co.kr (정리 전) 7일 분포
- 합계 3건. 모두:
  - `POST /api/member/v1/logout`
  - `okhttp/4.9.1` (구 안드로이드 앱)
  - 한국 KT/SK 컨슈머 IP (`211.235.75.59`, `1.216.229.52`, `211.36.153.190`)
  - 모두 401
- 추정: CBT 시기 안드로이드 앱이 baseUrl 을 `my-data-cbt` 로 박은 채 잔존 — 종료 시 logout 만 호출.
- 결론: **dead 도메인**. 2026-05-07 정리 적용.

### 4.5 web.bomapp.co.kr 7일 분포 (활용 중)
- status: 2,106 (404 봇) / **427 (200 정상)** / 56 (303) / 9 (406) / 3 (502) / 7 (4xx)
- 라우팅: ALB:443 priority 260 → 8107 7778 → `bomapp_webview_server-0.1.0.jar` (legacy)
- **정상 호출 path** (코드의 핸들러와 매칭됨):
  - `/policy/v1/privacy-policy/latest` (44), `/policy-code/{01,02}` (16+23), `/terms-of-service/latest` (12) → `PolicyController`
  - `/notice/v1/list` (17) + `/notice/v1/{uid}` 25+ 개 다른 uid → `NoticeController`
  - `/play/v1/content/{160}` (5) → `PlayContentController`
  - `/play/v1/event/{57,119,201}` (4+1+2) → `PlayEventController`
  - 정적 자산: `/vendors/{mobile-detect,moment,vuejs,jquery,axios}.js`, `/js/amplitude.js`, `/css/{common,components/content,notice/detail,play/*}.css`
- **정상 클라이언트** (Galaxy S25/A54 + Android 16 + Chrome WebView): 보맵 안드로이드 앱
- **HTTP/2 connection coalescing 단서**: 같은 라인의 request URL 에 `bapi.bomapp.co.kr` 호출 209건이 multiplex (member, my-insurance, planner 등 정상 처리). 즉 web.bomapp.co.kr 는 모바일 앱의 1차 진입 connection 이기도 함.

---

## 5. legacy-backend / bomapp_webview_server 코드상 endpoint (검증)

검증 방법: `grep -rE '@(Get|Post|Put|Delete|Request)Mapping' --include='*.java'` on `/Users/justin/Projects/legacy-backend/bomapp_webview_server/src/main/java/`

74개 .java 파일, 패키지 `kr.co.bomapp.apps.webview_server.api.v1.controller`.

| 컨트롤러 | endpoint 수 | path prefix |
|---------|----:|-------------|
| **PolicyController** | 51 | `/policy/v1/...` (terms-of-service, privacy-policy, collection-use-personal-info, planner-third-parties, family-third-parties, certificate-register-mobile, member-marketing, policy-code/{code}, main, travel/* (5), pet/* (10), nice/{skt,kt,lgt}/{personal,unique-identification,use-carrier,use-service,mvno} (15), health-checkup, family-health-checkup, credit, insurance-car, medical-history, terms-of-service-credit, privacy-policy-credit) |
| **NoticeController** | 3 | `/notice/v1/{main,list,{uid}}` |
| **PlayContentController** | 3 | `/play/v1/content/{main,list,{uid}}` |
| **PlayEventController** | 3 | `/play/v1/event/{main,list,{uid}}` |
| **FaqController** | 3 | `/faq/v1/{main,list,{uid}}` |
| **HeungkukInsuranceController** | 4 | `/market/v1/heungkuk-gibs-insurance/{,payment,complete,subscribe}` |

**합계 67개 endpoint**.

### 5.1 7일 호출 패턴
- **PolicyController**: 51개 중 5개 path 활성 (단, 약관은 회원가입/동의 시점에만 호출되므로 7일 sample 부족 가능)
- **NoticeController**: list + 25+ 개의 uid 활성
- **PlayContentController**: uid `/160` 만 활성
- **PlayEventController**: uid `/57`, `/119`, `/201` 활성
- **FaqController**: 7일 호출 0건
- **HeungkukInsuranceController**: 7일 호출 0건

> FAQ / Heungkuk 의 dead 여부는 30일/90일 로그로 추가 검증 필요.

---

## 6. next-backend bomapp-api 의 정의된 path 와 외부 호출 일치 검증

- `/api/member/v1/logout` → `MemberController.@PostMapping("/v1/logout")` 코드에 존재 확인 (`grep` 검증)
- `/api/address/v1/local` → next-backend 전체 (`/Users/justin/Projects/next-backend`) grep 결과 핸들러 **없음**. 폐기 또는 미배포 endpoint.
- `PinVerificationFilter.java:95` 에 `if ("/api/member/v1/logout".equals(requestUri))` 분기 존재 — 인증 필터가 path 별 분기 로직을 가짐.

---

## 7. 검증되지 않은 / 한계 영역 (의도적 누락)

다음 항목은 본 문서의 검증 범위를 벗어나며, 다른 문서에서 추정으로만 다룸:

1. **두 번째 PROD-BACK 인스턴스 (`i-09e36b30bad90990d`)** 의 docker ps / 활성 jar 구성. v5 와 v6 가 다른 jar 셋을 가질 가능성 있음.
2. **vkey.bomapp.co.kr 의 실제 처리 jar** — 8080 의 호스트 docker-proxy 는 있지만 컨테이너 내 listen process 매핑이 안 됨. Tomcat 의 connector 일 가능성이 높음(추정).
3. **bomapp_my_data 의 listening 포트** — host docker-proxy 11000 존재 + PID 15890 활성 자바 프로세스(`bomappmydata-0.0.1-SNAPSHOT.jar`) 가 있지만, 컨테이너 내 netstat 결과에 11000 의 PID 매핑이 표시되지 않음.
4. **`bomapp-oauth`, `bomapp-vkey`, `saas-api`** 의 출처 리포지토리 — `services.yaml` 에 등재되지 않은 별개 프로젝트들. 소스 위치 미확인.
5. **PROD-NLB / NLB access log** 의 listener별 트래픽 분포 — NLB log 는 host header 정보가 없어 도메인별 분리 어려움.
6. **PROD-BACK 의 27개 portMapping 중 실 사용 포트는 8개 미만** — 나머지(8101, 8104, 8106, 8201~8207, 8888, 9200, 9300, 14000 등)는 host docker-proxy 만 있고 컨테이너 내 listening 없음. 사용 종료 또는 일부 인스턴스에만 떠있을 가능성.
7. **HTTP/2 connection coalescing 으로 web 도메인에 multiplex 된 bapi 호출 209건의 처리 위치** — bapi 의 정식 라우팅(8107 TG → bomapp-api) 와 동일하다고 추정되지만 ALB 가 multiplex 시 실제로 어느 TG 로 routing 하는지는 별도 검증 필요.

---

## 8. 사용자 운영 액션 기록 (2026-05-07)

| 일자 | 액션 | 대상 | 결과 |
|------|------|------|------|
| 2026-05-07 | listener rule fixed-response 410 적용 | `api.bomapp.co.kr`, `my-data-cbt.bomapp.co.kr` (PROD-ALB:443 priority 160) | 사용자 직접 적용 완료. 추후 추이 모니터링 예정. |

### 모니터링 방법 (재현 가능)

```bash
# 적용 후 D+1, D+7, D+30 시점에 실행
mkdir -p /tmp/alb-monitor/$DAY
aws s3 sync s3://bomapp-access-logs/prod-alb/AWSLogs/044488971141/elasticloadbalancing/ap-northeast-2/$(echo $DAY | tr - /)/ /tmp/alb-monitor/$DAY/ --quiet
for HOST in api.bomapp.co.kr my-data-cbt.bomapp.co.kr; do
  echo "=== $HOST $DAY ==="
  zgrep -ahF "\"$HOST\"" /tmp/alb-monitor/$DAY/*.log.gz | awk '{print $9}' | sort | uniq -c | sort -rn
done
```

---

## 9. 본 문서 갱신 정책

- 새로운 검증 결과는 (a) 검증 명령/방법, (b) 검증 일자, (c) 결과를 함께 본 문서에 추가한다.
- 추정·추측은 본 문서가 아니라 [`architecture.md`](./architecture.md), [`services/`](./services/) 본문에 caveat 와 함께 기재한다.
- 미검증 영역(§7)은 검증 후 §1~§6 으로 이동한다.
- listener rule / Route53 변경 등 운영 액션은 §8 에 시간순으로 누적한다.
