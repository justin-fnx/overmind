# Runtime Verification — 직접 검증된 사실

> 본 문서는 **추정이 아니라 직접 검증된 사실** 만 기록한다. 각 항목은 검증 방법(SSM Run Command / AWS CLI / Terraform 코드 / ALB access log) 과 검증 일자를 명시한다.
> 추정·추측은 본 문서에서 제외한다. 추정은 [`architecture.md`](./architecture.md) 와 [`services/`](./services/) 의 본문에 caveat 와 함께 기재.

| 항목 | 값 |
|------|----|
| 1차 검증 일자 | 2026-05-07 |
| 2차 검증 일자 | 2026-05-19 (vkey 8080 connector / transkeyServlet 확정) |
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
| 1205 | bomapp | (Tomcat catalina bootstrap) | **bomapp-vkey** (별개 프로젝트 `Bomapp/transkey_servlet`, `bm.service=bomapp_key`) | **8080 ✓** (HTTP connector, transkeyServlet), 8005 shutdown, 65355 JMX | Tomcat 9.0.45 WAR (Spring Boot 아님) |
| 1428 | root | `bomapp_webview_server-0.1.0.jar` | **legacy-backend / bomapp_webview_server** | **7778** | SB 1.x (JDK 8) |
| 5953 | root | `bomapp-server-open-api.jar` | **next-backend / open-api** | **8105** | SB 3.4 |
| 10745 | root | `bomapp-server-bomapp-api.jar` | **next-backend / bomapp-api** | **8107** | SB 3.4 |
| 15890 | bomapp | `bomappmydata-0.0.1-SNAPSHOT.jar` | **bomapp_my_data** 프로젝트 | (host docker-proxy 11000 존재, 컨테이너 내 PID 매핑은 미확정) | SB 2.3 |
| 19422 | root | `bomapp-server-wings-api.jar` | **next-backend / wings-api** | **8102** | SB 3.4 |
| 32329 | bomapp | `bomapp_oauth-0.1.0.jar` | **별개 OAuth 프로젝트** = legacy `bomapp_api_server` 의 `security.server`(토큰발급) | **8888** (확정 — §10) — 단 **TG/LB 경로 없음** → 인바운드 도달 불가 | (jar 존재만 확인) |

### 2.5 운영상 함의

- **이미지 이름이 `next-backend-was` 라서 next-backend 로 단정하면 안 된다.** 컨테이너 내부에 여러 프로젝트의 jar 가 함께 떠 있는 공용 WAS 패턴.
- **`enable_execute_command = false`** + **awslogs 미설정** → 운영 가시성이 매우 낮음.
- 컨테이너 Up 3 years — 새 jar 배포는 ECS task 재시작이 아니라 컨테이너 안에서 jar 재기동으로 추정.

### 2.6 vkey (bomapp-vkey) 상세 (2026-05-19 추가)

> **⚠️ 2026-06-08 BV cutover 완료**: 본 섹션은 옛 PROD-BACK Tomcat WAR 운영 시점 (2026-05-19 SSM 검증) 의 기록. 현재는 독립 ECS service (`SVC-ECS-PROD-bomapp-vkey`, Spring Boot 2.7 + Java 17, m7g Graviton 3) 로 이전 완료. ALB priority 10 의 100% 트래픽이 새 TG `prod-bomapp-vkey-ip-8080` 로 전환됨. 옛 PID 1205 Tomcat WAR 은 옛 PROD-BACK 컨테이너 안에서 여전히 살아있으나 ALB 가 트래픽을 보내지 않음 (drain 후 비활성 예정). 현재 운영 정보는 [`docs/services/bomapp-vkey.md`](./services/bomapp-vkey.md) 참조.

PID 1205 (UID `bomapp`) 의 정체를 SSM 으로 추가 검증한 결과:

| 항목 | 값 |
|------|----|
| 프로세스 | `java -Dbm.service=bomapp_key -Dcatalina.base=/was/run/bomapp-vkey -Dcatalina.home=/was/run/bomapp-vkey org.apache.catalina.startup.Bootstrap start` |
| 런타임 | Tomcat **9.0.45** (Spring Boot 아님, WAR 배포) |
| listening | **8080** (HTTP connector), 8005 (shutdown), 65355 (JMX) |
| JVM 설정 | `-Xmx512m`, JVM 이름 `bomapp_key` |
| 응답 컨텐츠 | `curl 127.0.0.1:8080/` → HTTP 200, HTML 내 `/TouchEn/transkey/transkey.js` 및 `/transkeyServlet/decode` form |
| 기능 | 라온시큐어 **TouchEn 가상키보드 (transkey)** 의 서버측 복호화 서블릿 |
| 비즈니스 용도 | **보험금 청구 플로우에서 주민번호 입력용 가상키보드** (출처: 노션 "인프라" 페이지, 2025-10-15) |
| 소스 리포지토리 | [`bomapp-inc/transkey_servlet`](https://github.com/bomapp-inc/transkey_servlet) (조직 이전 후 정식 URL; 노션 등재 시점에는 `Bomapp/transkey_servlet` 표기). 2020-06-04 초기 커밋 1개, IntelliJ artifact 기반 WAR, `web/WEB-INF/lib/` 에 라온 jar 직접 포함 (Maven/Gradle 없음). 상세: [bomapp-vkey 서비스 문서](./services/bomapp-vkey.md) |
| 운영 형태 | "바이너리 파일 통으로 가지고 있어서 실행만 하면 됨" — 빌드 산출물(WAR) 직배포 (출처: 동일 노션 "인프라" 페이지) |
| 과거 위치 | `10.10.10.51` / `10.10.10.52` (2022 시점) → 2024-02-20 "PROD-ETC-API WAS 로 통합" 작업으로 `api-was2 (10.1.1.20)` 로 이전 = 현재 PROD-BACK `i-03f0178089f760c6f` 와 일치 (출처: 노션 작업기록) |
| 과거 도메인 | `cf-vkey.bomapp.co.kr` (CloudFront 경유, 2024-09 걷어냄) |
| 관련 abandoned PoC | [`bomapp-inc/bomapp-vkey`](https://github.com/bomapp-inc/bomapp-vkey) — 동일 개발자가 4분 뒤 만든 Spring Boot 포팅(`kr.co.bomapp:securekey:0.0.1-SNAPSHOT`, `POST /securekey`). 초기 커밋 1개 후 작업 없음. 운영 미배포. |
| 호스트 마운트 형태 (2026-05-19 SSM) | `/was/data/bomapp-vkey/vkey.tar` (126MB, 2023-04-04) + `restart.sh` (1019 B). 운영자가 vkey.tar 를 untar → `/was/run/bomapp-vkey/` 에 풀어서 가동하는 패턴. 2023-04-04 이후 갱신 없음. |
| Tomcat webapps 배포 형태 | `/was/run/bomapp-vkey/webapps/` 에 `ROOT/` 와 `secure_servlet/` 두 컨텍스트 deploy. 동일 WAR. 호출자가 `vkey.bomapp.co.kr/transkeyServlet` 와 `vkey.bomapp.co.kr/secure_servlet/transkeyServlet` 둘 다 사용 가능 (ALB log 분석으로 실 사용 path 결정 필요). |
| 운영 라이선스 (2026-05-19 SSM) | `transkey_license.ini` 의 `license.type=p` (Permanent 활성). `transkey__P_license/Server2048.pem` X.509 Subject = `C=KR, O=bomapp, CN=T=P&D=[*.bomapp.co.kr]`, Issuer = `RaonSecure Co., Ltd. Quality Assurance`, 유효기간 **2019-08-19 ~ 2049-08-11 (30년)**. SHA-256 fingerprint `3C:3D:40:4F:9A:77:57:A9...`. CA 인증서 `ca.crt` 도 RaonSecure self-signed root (2013-2043). 인증서 체인 `openssl verify` 통과, 개인키/인증서 modulus 일치 확인. `*.bomapp.co.kr` 와일드카드 → DEV/STG/PROD 도메인 모두 커버. **갱신 우려 사실상 없음.** |
| T 라이선스 (잔재) | `transkey__T_license/Server2048.pem` Subject = `O=HahaSavings, CN=T=T&D=[*]`, 만료 2021-09-16. `license.type=p` 모드라 미사용이지만 다른 회사 라이선스가 컨테이너에 잘못 들어 있는 상태. 새 빌드 시 T 디렉토리 제외 권장. |
| `domain.inf` (stale) | `localhost,10.0.0.72,*.raonsecure.com` — 실 인증서 CN(`*.bomapp.co.kr`) 과 불일치. 라이브러리 동작에 영향 미확정. 새 빌드 시 `*.bomapp.co.kr` 로 정정 권장. |
| `ExE2EKey_bomapp` 경로 미해결 | `config.ini` 의 `/Users/zard21/...` 절대경로가 컨테이너에 없음에도 가동 중 → `ExE2E block 모드` 실 호출 없는 것으로 추정. |

> 이로써 §7 의 다음 미검증 항목이 모두 해소됨: 구 §7.2 "vkey 의 실제 처리 jar", §7.4 출처 리포지토리(`bomapp-vkey`), §7.1 "두 번째 PROD-BACK 인스턴스 v6 의 jar 구성", 운영 라이선스 위치/도메인/유효기간.

---

## 3. 호스트 헤더 → 실제 jar 매핑 (검증)

다음 매핑은 (a) Terraform listener_rule + (b) AWS CLI describe-rules + (c) SSM 으로 확인한 활성 listening 프로세스를 모두 교차 검증한 결과.

| 호스트 (PROD) | listener / priority | TG | 컨테이너 포트 | listening jar | 프로젝트 |
|--------------|---------------------|----|:------------:|---------------|----------|
| `bapi.bomapp.co.kr` | ALB:443 priority 170 | prod-back-ecs-host-http-8107 | **8107** | `bomapp-server-bomapp-api.jar` (PID 10745) | next-backend / bomapp-api |
| `web.bomapp.co.kr` | ALB:443 priority 260 | prod-back-ecs-host-http-7778 | **7778** | `bomapp_webview_server-0.1.0.jar` (PID 1428) | legacy-backend / bomapp_webview_server |
| `wapi.bomapp.co.kr` | ALB:443 (priority 미기재, 별도 rule) | (8102 TG) | **8102** | `bomapp-server-wings-api.jar` (PID 19422) | next-backend / wings-api |
| `oapi.bomapp.co.kr` 외 | (priority 별도) | (8105 TG로 추정) | **8105** | `bomapp-server-open-api.jar` (PID 5953) | next-backend / open-api |
| `vkey.bomapp.co.kr` | ALB:443 priority 10 | **prod-bomapp-vkey-ip-8080 (100%, 2026-06-08 cutover)**. 옛 prod-back-ecs-host-http-8080 은 weight 0 drain. priority 4 (X-Canary=office) / 5 (사무실 IP) 도 같은 새 TG. | **8080** | **`bomapp-vkey` Spring Boot 2.7 + embedded Tomcat 9 (Java 17, m7g Graviton arm64)** — `TranskeyDecodeController` + Raon `TranskeyServlet`. | [`bomapp-inc/bomapp-vkey`](https://github.com/bomapp-inc/bomapp-vkey) — 보험금 청구 플로우의 주민번호 입력용 |
| `api.bomapp.co.kr` (✱ 정리됨) | ALB:443 priority 160 | (정리 전: 8107) | — (현재 410 fixed-response) | — | — |
| `my-data-cbt.bomapp.co.kr` (✱ 정리됨) | 동일 priority 160 host header | — (현재 410 fixed-response) | — | — | — |

**(✱)** 사용자가 2026-05-07 에 listener rule 을 fixed-response 410 으로 정리. 본 문서의 "현재" 매핑은 정리 후 상태.

### 3.1 미사용 도메인 폐기 (2026-06-01, BOM-99) — `mapi`/`mapi1`/`mapi2`/`wapi1`/`wapi2`

PROD-ALB 의 아래 5개 도메인에 대응하는 **리스너 룰 + 타깃그룹 + Route53 CNAME 15개를 완전 삭제**(2026-05-07 의 fixed-response 410 방식과 달리 코드/리소스 전체 제거). `terraform apply -target`(정확히 15개) → `0 added, 0 changed, 15 destroyed`. state serial 2200→2216.

| 폐기 도메인 | 30일 외부 요청 | 대상 TG | 폐기 사유 |
|------------|:---:|--------|----------|
| `mapi` / `mapi1` / `mapi2` | **0** | `mydata-api[-1/-2]-http-8080` (등록 타깃 0개) | 외부 진입 경로 비기능화. 실 마이데이터는 내부 `int-mapi`(**4,563,564건/30일**) + `magent`(4,571,999건)로 정상 — mydata-api 서비스 자체는 운영 유지 |
| `wapi1` / `wapi2` | **각 1** | `prod-back-ecs-host-1/2-http-8102` | wings-api 인스턴스별 재기동 훅(`GET /open/server/restart/wings-api-prod`, 2026-05-12 사내 IP curl). 활성 `wapi`(2,455,077건/30일)는 신규 IP-target TG 이관 완료 → 구 8102 per-instance 경로 폐기, 재기동은 표준 ECS 배포로 대체 |

> **측정 방법 교정 (중요)**: 본 폐기 판단은 ALB 액세스 로그를 **요청-URL authority** 기준으로 재집계해 확정했다. 초기 집계가 쓴 `domain_name`(SNI) 필드는 **HTTP/2 connection coalescing** 시 실제 요청 `:authority` 와 달라져 오귀속된다(예: 활성 `wapi` SNI 2,992,209건 vs authority 2,455,077건 — 약 53.7만건이 다른 호스트의 coalesced 요청). 또한 Glue 테이블 `alb_logs_v2`/`internal_alb_logs_v2` 는 **SerDe 미스매치로 모든 컬럼이 NULL** 이고 파티션 프로젝션이 없어 30일 중 다수 일자가 미등록 상태였다 → 신뢰 불가. 재측정은 **raw 테이블(`alb_raw`/`int_alb_raw`)** 에 파티션을 수동 등록(`ALTER TABLE ... ADD PARTITION`)한 뒤 `regexp_extract(line,'https?://([^:/ ]+)',1)` 로 authority 를 파싱해 수행했다. (Athena workgroup `primary`, 출력 `s3://bomapp-athena-results/elb-results/`.)

---

## 4. 7일 ALB Access Log 분석 (2026-04-30 ~ 2026-05-06)

검증 방법: `aws s3 sync` 로 7일치 PROD-ALB access log 다운로드 (542MB / 3,794 파일), `awk -F'"' '$8=="<host>"'` 로 정확 매칭.

### 4.1 도메인별 트래픽 (PROD-ALB 도달 기준)

| 호스트 | 7일 합계 | 정상 응답 (2xx/3xx) | 봇/스캐너 비율 |
|--------|--------:|------------------:|--------------:|
| `api.bomapp.co.kr` | 725 | 0 (2xx) | ~98% (.php/wp-*) |
| `my-data-cbt.bomapp.co.kr` | 3 | 0 (모두 401) | 0% (정상 path 이지만 인증 실패) |
| `web.bomapp.co.kr` | 2,608 | 483 (200 + 303) | ~80% (wp-login/wp-admin) |

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

1. ~~**두 번째 PROD-BACK 인스턴스 (`i-09e36b30bad90990d`)** 의 docker ps / 활성 jar 구성. v5 와 v6 가 다른 jar 셋을 가질 가능성 있음.~~ — **2026-05-19 해소.** SSM 검증 결과 `i-09e36b30bad90990d` 의 `/was/data` 에는 `bomapp-vkey`, `bomapp-mydata-prod`, `bomapp-webview-prod` 가 **없고** `bomapp-api`, `wings-api`, `open-api`, `bomapp-oauth`, `legacy-bomapp-api`, `saas-api`, `bomapp-redmin` + `integrate_svc_info.json` (다른 인스턴스에는 없음) 으로 구성. 즉 **v5(i-03f0178089f760c6f) 와 v6(i-09e36b30bad90990d) 가 서로 다른 jar 셋을 운영하며, vkey/mydata/webview 는 v5 단일 인스턴스 의존 → SPOF 확인됨**. 새 ECS service 신설 시 desired_count ≥ 2 권장.
2. ~~**bomapp_my_data 의 listening 포트** — host docker-proxy 11000 존재 + PID 15890 활성 자바 프로세스(`bomappmydata-0.0.1-SNAPSHOT.jar`) 가 있지만, 컨테이너 내 netstat 결과에 11000 의 PID 매핑이 표시되지 않음.~~ — **2026-06-04 해소(§10).** `prod-back-ecs-host-2-http-11000` TG(i-03f0178089f760c6f:11000 healthy) ← prod-alb:5443 default ← prod-nlb:5443 ← `auth.bomapp.co.kr`. 실 트래픽 `POST /v2/mgmts/{consents,agreements}` 가 `bomapp_my_data` 리포의 `ManagementController`/`AgreementController` 핸들러와 정확히 일치 → 11000 = bomapp_my_data 확정.
3. **`bomapp-oauth`, `saas-api`** 의 출처 리포지토리 — `services.yaml` 에 등재되지 않은 별개 프로젝트들. 소스 위치 미확인. (`bomapp-vkey` 는 2026-05-19 노션 "BM 운영 구성 / Git Repository" 조회로 [`Bomapp/transkey_servlet`](https://github.com/Bomapp/transkey_servlet) 확정).
4. ~~**bomapp_oauth jar 의 활성 여부 불일치**~~ — **2026-06-04 기능적 해소(§10).** oauth=8888, 유일한 코드상 호출자는 legacy `bomapp_api_server`(자체가 비활성). **TG/LB 경로 0 + 액세스로그·CloudWatch 트래픽 0 + 노션상 2024-02 "미사용 확인 기동중지"** → 기능적 死(재기동된 PID는 좀비). 단 *JVM 의 현재(2026-06-04) 생존 여부* 와 *localhost:8888 내부 커넥션 유무* 는 컨테이너 introspection(SSM docker exec) 필요 — 미수행(권한 보류).
5. **PROD-NLB / NLB access log** 의 listener별 트래픽 분포 — NLB log 는 host header 정보가 없어 도메인별 분리 어려움.
6. **PROD-BACK 의 27개 portMapping 중 실 사용 포트는 8개 미만** — 나머지(8101, 8104, 8106, 8201~8207, 8888, 9200, 9300, 14000 등)는 host docker-proxy 만 있고 컨테이너 내 listening 없음. 사용 종료 또는 일부 인스턴스에만 떠있을 가능성.
7. **HTTP/2 connection coalescing 으로 web 도메인에 multiplex 된 bapi 호출 209건의 처리 위치** — bapi 의 정식 라우팅(8107 TG → bomapp-api) 와 동일하다고 추정되지만 ALB 가 multiplex 시 실제로 어느 TG 로 routing 하는지는 별도 검증 필요.

---

## 8. 사용자 운영 액션 기록

| 일자 | 액션 | 대상 | 결과 |
|------|------|------|------|
| 2026-05-07 | listener rule fixed-response 410 적용 | `api.bomapp.co.kr`, `my-data-cbt.bomapp.co.kr` (PROD-ALB:443 priority 160) | 사용자 직접 적용 완료. 추후 추이 모니터링 예정. |
| 2026-06-01 | sapi 도메인 전 리소스 제거 (infra MR) | `sapi.bomapp.co.kr` 라우팅(443/3001 룰·route53) + 8103 TG + ALB/NLB 3001 리스너 체인 + SG 3001 ingress | dead 재검증 후 제거 (상세 §8.1). MR [!20](https://gitlab.bomapp.co.kr/bomapp/infra/-/merge_requests/20) |

### 8.1 sapi.bomapp.co.kr 제거 경위 (2026-06-01)

- **제거 사유 (dead 재검증)**: 6/1·5/31 PROD-ALB access log 에서 SNI=`sapi.bomapp.co.kr` 요청 **0건** (동일 로그 대조군 `bapi` 255,722 / `oapi` 28,001 / `web` 123건은 정상 집계 → 누락이 아니라 실제 무트래픽). 8103 TG 타겟 2/2 `unhealthy`, 최근 30일 `HTTPCode_Target_2XX` 0건(백엔드 무응답). 기존 7일 로그(4/30~5/6)도 0건.
- **구조적 근거**: `prod_alb_https_3001` 리스너가 sapi 전용(룰 1개 + default_action 모두 dead 8103 TG)이고, `prod_nlb_tcp_3001`→ALB:3001 체인도 sapi 전용 → 체인을 통째로 제거.
- **제거 리소스(8)**: `prod_alb_https_443_rule_11`, `prod_alb_https_3001_rule_0`, `bomapp_co_kr_sapi_cname`(route53), `prod_alb_https_3001`(리스너), `prod_back_ecs_host_http_8103`(TG), `prod_nlb_tcp_3001`(리스너), `prod_nlb_to_alb_3001`(TG), `prod_alb_ingress_0`(SG 3001 ingress).
- **범위 제외(유지)**: `az.bomapp.co.kr`/`dev-az`/`stg-az`(별도 `*_8080` 서비스, dead 미검증), `prod_front_esc_host_http_3001`(open/apps/bomapp.im 프론트가 443으로 사용) — sapi와 무관.
- **적용 결과 (2026-06-01)**: MR [!20](https://gitlab.bomapp.co.kr/bomapp/infra/-/merge_requests/20) 머지 후 로컬 state로 `terraform apply -target`(8개) 실행 → **8 destroyed**. 검증: state·AWS에서 8개 삭제 확인, prod-alb 리스너 3001 제거(80/443/3002/5443 유지), `oapi`(8105) 등 타 도메인 무영향. (ALB:3001 리스너는 NLB→ALB TG deregister 전파 지연으로 1회 재시도 후 삭제.)

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

---

## 10. `auth.bomapp.co.kr` ↔ `bomapp_oauth` ↔ `bomapp_my_data` 관계 (2026-06-04 검증)

> **⚠️ 2026-06 갱신**: `bomapp_my_data` 는 이후 BOM-113 으로 현대화(SB 2.3→3.4.5/Java 11→21/jjwt 0.12)되고 BOM-121 으로 리네임됨 — repo `bomapp_my_data`→**`mydata-mgmts-api`**, 패키지 `kr.co.bomapp.auth.bomappmydata`→`kr.co.bomapp.mydata.mgmts`, artifact `bomappmydata`→`mydata-mgmts-api`. **단 PROD 미컷오버** — 아래 §10 본문의 리포·패키지·jar 명(`bomappmydata-0.0.1-SNAPSHOT.jar`)은 **2026-06-04 검증 시점의 실측(구 코드)** 으로 그대로 둔다.

> 검증 방법: 라이브 AWS(`describe-rules`/`describe-target-groups`/`describe-target-health` — **TF 아닌 콘솔 상태 직접**), CloudWatch `RequestCountPerTarget`, ALB access log grep, 노션 작업기록, 로컬 리포 코드 grep. PROD-BACK 은 손으로 jar 를 띄우고 리스너도 콘솔 직접수정 가능한 패턴이므로 TF 만으로 판단하지 않음.

### 10.1 결론 (한 줄)

이름이 헷갈리지만 **세 개는 서로 다른 실체**다. `auth.bomapp.co.kr` 의 백엔드는 **`bomapp_my_data`(11000)** 이고, **`bomapp_oauth`(8888)** 는 이와 무관한 **이미 폐기된 legacy 토큰서버**다.

### 10.2 `auth.bomapp.co.kr` → `bomapp_my_data` (11000, 활성·규제필수)

| 항목 | 값 |
|------|----|
| 라우팅 | `auth.bomapp.co.kr` (route53 CNAME) → **prod-nlb** → NLB:5443 → ALB:5443 **default**(호스트룰 없음) → TG `prod-back-ecs-host-2-http-11000` → `i-03f0178089f760c6f:11000` (healthy) |
| 실행 jar | `bomappmydata-0.0.1-SNAPSHOT.jar` (PID 15890, UID `bomapp`, SB 2.3) |
| 코드베이스 | **`github.com/bomapp-inc/bomapp_my_data`** (로컬 `../bomapp_my_data`), 패키지 `kr.co.bomapp.auth.bomappmydata` — 패키지명의 `.auth.` 가 도메인과 직결 |
| 실 트래픽 (ALB log) | `POST /v2/mgmts/consents`(151) + `POST /v2/mgmts/agreements`(61) → 핸들러 `ManagementController`/`AgreementController` 와 정확 일치. 나머지(`/.git/config`,`/.env`,`/actuator/env` 등)는 5443 노출면에 대한 스캐너 노이즈 |
| CloudWatch | 11000 TG `RequestCountPerTarget` 14일 **2091** (~150/일, 생존) |
| 호출자 IP | `210.216.219.20`(외부 마이데이터 표준 동의관리 API), `43.201.10.95`(AWS 서울 내부) |
| 역할 | **금융 마이데이터 표준 동의·관리(mgmts) API 수신 서버**. OAuth 토큰발급(`ManagementService.issueOAuthToken`)을 **자체 구현**. 외부 의존: `my-data.management.org-url=https://api.mydatacenter.or.kr:7443`(종합포털) + Redis(`10.10.10.71`). 일부 경로는 `NextMyDataApiClient` 로 next-backend 에 위임("이관 중") |
| 이관 상태 | **미이관.** 사용자 인지("mydata 전부 신규/prod-mydata-agent 로 이관")는 **수집·게이트웨이(mydata-agent/mydata-api)** 한정. 표준 mgmts 수신면은 DigiCert EV 인증서(auth 5443 구간)에 묶인 채 PROD-BACK 11000 에 잔존 |

### 10.3 `bomapp_oauth` (8888, 기능적 死)

| 근거 | 내용 |
|------|------|
| 포트 | **8888** — 노션 "prod api oauth/vkey 참조 변경"(`oauth:8888`, `vkey:8080`) + legacy `bomapp_api_server/application-*.properties` 의 `security.server.access-token-url=http://10.1.1.20:8888/oauth/token` (`10.1.1.20`=api-was2=현 PROD-BACK) |
| 원래 역할 | legacy `bomapp_api_server`(legacy-backend api) 가 호출하던 **사내 OAuth 토큰 발급 "security server"** |
| 폐기 기록 | 노션 "PROD-ETC-API WAS로 통합"(2024-02-13~20, Completed): oAuth "api was2로 이전 완료 + **미사용 확인되어 기동 중지**" |
| 인바운드 도달성 | **0.** 8888 에 대응하는 TG 가 라이브 AWS 어디에도 없음(`oauth`/`auth` TG 검색 빈 결과). prod-alb:443/5443 어떤 호스트룰도 8888 로 forward 안 함 |
| 트래픽 | ALB access log 전체에서 `:8888`/`bomapp_oauth` 경로 **0건**. 시스템 내 유일한 "oauth" 트래픽은 `oapi.bomapp.co.kr/api/external/v1/oauth-token`(=next-backend **open-api** 제휴 토큰발급, 무관) |
| 코드상 호출자 | legacy `bomapp_api_server` 단 하나 — 그 앱 자체가 §2.3 에서 **비활성(死)**. `bomapp_my_data` 는 8888 을 호출하지 않음(자체 OAuth 구현) |
| 현재 상태 | 2026-05-07 PID 32329 활성은 호스트/컨테이너 재기동 시 restart 스크립트의 **좀비 재기동**으로 판단. **기능적으로 死, 안전한 폐기 후보** |
| 잔여 미검증 | JVM 의 현재 생존 + `localhost:8888` ESTABLISHED 커넥션 유무(내부 호출자 0 확인) → SSM docker-exec 필요(권한 보류) |

### 10.4 'oauth' 네이밍 함정 (주의)

`bomapp_oauth` 라는 이름 때문에 `auth.bomapp.co.kr` 의 백엔드로 오인하기 쉬우나 **아님**. auth 도메인은 `bomapp_my_data` 가 서빙하고, `bomapp_my_data` 의 OAuth 는 마이데이터 표준 토큰 엔드포인트를 자체 구현한 별개 코드다. `bomapp_oauth` 는 그 어디에도 연결돼 있지 않다.
