# BOMAPP 마이데이터 플랫폼 — 4종 서비스 통합 가이드

> `mydata-api` · `mydata-agent` · `mydata-batch` · `mydata-mgmts-api` 네 서비스가 보맵의 금융 마이데이터 사업자(정보수신자) 역할을 어떻게 분담하는지, 그리고 어떻게 유기적으로 동작하는지 정리한다.
>
> 검증 출처: services.yaml + 각 리포 코드 + `docs/services/mydata-agent.md` / `mydata-mgmts-api.md` / `next-backend.md` + `docs/runtime-verification.md §10`. 2026-06-09 작성.

---

## 1. 4종 서비스 책임 매트릭스

| 서비스 | 위치 | 책임 (한 줄) | 인바운드 | 아웃바운드 |
|---|---|---|---|---|
| **mydata-api** | next-backend `bomapp-server/mydata-api` | 보맵 앱(웹·모바일)이 호출하는 **마이데이터 오케스트레이션 API** | 보맵 클라이언트 / mydata-batch / 외부 callback | 통합인증기관(NAVER/KAKAO), 종합포털, mydata-agent, mydata-mgmts-api(일부) |
| **mydata-agent** | 별도 리포 `mydata-agent` | 외부 마이데이터 기관(보험사·은행)과의 **mTLS 통신 프록시** | mydata-api (Internal-ALB, 평문 HTTP) | 외부 마이데이터 기관 (HTTPS + mTLS) |
| **mydata-batch** | next-backend `bomapp-server/mydata-batch` | **정기 백그라운드 작업** — refresh 토큰 재발급, 정보 갱신, 통계, 알림 | cron (자체) | mydata-api (`int-mapi:8080` OpenFeign), 종합포털 |
| **mydata-mgmts-api** | 별도 리포 `mydata-mgmts-api` (구 `bomapp_my_data`) | 마이데이터 **종합포털이 보맵에 들어오는 표준 mgmts API 수신** + OAuth 토큰 발급 | 종합포털 (`auth.bomapp.co.kr:5443`, mTLS) | (prod) 자체 처리 / (dev) next-backend mydata-api 일부 위임 |

핵심 분리 원칙:
- **mTLS 키스토어를 가진 서비스** = 3종 (mydata-agent, mydata-api, mydata-mgmts-api). 모두 **동일한 `auth.bomapp.co.kr` cert 공유** (`bomapp/{env}/external-mydata/auth-jks` SM 시크릿).
- **mydata-batch는 보통 mydata-api를 통해 간접 호출** (Bearer 토큰 + JKS는 mydata-api 측 사용).

---

## 2. 서비스 그래프

```mermaid
flowchart LR
  subgraph User[사용자 / 클라이언트]
    User_App[보맵 모바일/웹]
  end

  subgraph Ext_Auth[통합인증기관 (외부)]
    NAVER[mydata.ekyc.naver.com]
    KAKAO[mydata-cert.kakao.com]
  end

  subgraph Portal[종합포털 (외부)]
    KCB[api.mydatacenter.or.kr:7443<br/>한국신용정보원]
  end

  subgraph Orgs[정보제공자 (외부)]
    InsOrgs[보험사·은행·통신사<br/>마이데이터 기관]
  end

  subgraph Inbound[보맵 인바운드면]
    ALB5443[prod-alb:5443<br/>auth.bomapp.co.kr]
    Mgmts[mydata-mgmts-api]
  end

  subgraph Backend[next-backend ECS]
    MAPI[mydata-api]
    MBATCH[mydata-batch]
  end

  subgraph Gateway[Internal]
    MAGENT[mydata-agent<br/>magent.bomapp.co.kr:8080]
  end

  User_App -->|REST| MAPI
  MAPI -->|HTTPS + mTLS<br/>Bearer + JKS| NAVER
  MAPI -->|HTTPS + mTLS<br/>Bearer + JKS| KAKAO
  MAPI -->|HTTPS + mTLS<br/>지원-001/002/...| KCB
  MAPI -->|평문 HTTP<br/>POST /post, /auth/post| MAGENT
  MAGENT -->|HTTPS + mTLS<br/>auth.bomapp.co.kr cert| InsOrgs

  KCB -.->|mTLS 5443<br/>표준 mgmts API| ALB5443
  ALB5443 -.-> Mgmts
  Mgmts -.->|일부 (dev 한정)<br/>OpenFeign 위임| MAPI

  MBATCH -->|OpenFeign<br/>int-mapi:8080| MAPI
  MBATCH -.->|일부 직접 호출| KCB
```

---

## 3. 데이터 흐름 4가지 (Flow)

### Flow A — 사용자 인증 (정보주체 → 통합인증기관 → 토큰 발급)

```
사용자(보맵 앱)
  │  /api/my-data/v2/integration-authorization/* (POST)
  ▼
mydata-api (MyDataIntegrateControllerV2)
  │  MyDataIntegratePrivateCaSignClient
  │  Bearer access_token + mTLS 클라이언트 인증서(JKS)
  ▼
통합인증기관 (NAVER / KAKAO)  ← 102 sign_request
  │
  ▼
사용자 카카오톡/네이버 앱에서 서명 완료
  │
  ▼
mydata-api (MyDataIntegrate002CallbackControllerV2)  ← 103 sign_result
  │  → 토큰 저장(RDS), 동의 정보 기록
  ▼
사용자에게 결과 반환
```

**핵심 클라이언트** (next-backend 코드 위치):
- `bomapp-external/mydata/src/main/java/kr/co/bomapp/external/mydata/auth/MyDataIntegratePrivateCaSignClient.java`
- 엔드포인트:
  - `POST https://mydata.ekyc.naver.com/v1/ca/sign_request` (NAVER 102, request-103=`sign_result`)
  - `POST https://mydata-cert.kakao.com/v1/ca/sign_request` (KAKAO 102, 동일)

### Flow B — 정보 수집 (mydata-api → mydata-agent → 외부 기관)

```
보맵 앱 / 배치
  │  /api/mydata/v1/list-information 등 (POST)
  ▼
mydata-api (MyDataInsuranceListController 등)
  │  WebClient (평문 HTTP, ${mydata.agent.domain})
  ▼
mydata-agent (POST /post 또는 /auth/post)
  │  myDataWebClient (WebFlux + mTLS, auth.bomapp.co.kr JKS)
  │  request의 path 헤더가 외부 기관 URL로 사용됨
  ▼
외부 마이데이터 기관 (보험사·은행 등)
  │
  ▼
응답은 다시 mydata-api callback URL로 (비동기 callback pattern):
  /api/mydata/v1/list-callback 등
```

**핵심 사실**:
- `mydata-agent`는 **단순 프록시** — `MyDataGatewayController`가 `/get`, `/post`, `/auth/post` 3개 핸들러만 가지고 헤더(`MyDataClientRequestHeader`)에 들어온 외부 기관 URL로 그대로 위임.
- **인증서는 agent 측에서 제시** — mydata-api는 평문으로 agent에 위임, agent가 외부 기관에 mTLS로 출구를 잡음.
- 비동기 callback 패턴: 정보 수집은 대형 응답이라 직접 응답 X, callback URL로 통보.

### Flow C — 종합포털 → 보맵 (수신, 표준 mgmts)

```
종합포털 (api.mydatacenter.or.kr:7443)
  │  HTTPS + mTLS
  │  POST /v2/mgmts/consents · /v2/mgmts/agreements 등
  ▼
Route53 alias → prod-nlb:5443 → prod-alb:5443 (default cert) → TG `prod-back-ecs-host-2-http-11000`
  ▼
[현재 PROD] PROD-BACK 공용 WAS 컨테이너 내 jar `bomappmydata-0.0.1-SNAPSHOT.jar` (PID 15890, port 11000) — 구 jar(미컷오버)
  │
  ├──────────────── prod: 자체 처리 (NextMyDataApiClient URL 빈 값 = 위임 없음)
  └──────────────── dev: NextMyDataApiClient → next-backend mydata-api 위임
                      (지원-105/106/107/108)
```

**핵심 사실**:
- `mydata-mgmts-api/src/main/resources/application-product.properties` 에 `bomapp.api.url=` (**빈 값**). 즉 **PROD에서는 next-backend로 위임하지 않고 mgmts-api가 자체 처리**.
- BOM-113 현대화는 코드 완료(Java 21/SB 3.4.5)지만 PROD는 미컷오버 → 여전히 구 jar.
- ~150 req/일 (2026-06 측정). 규제필수, 임의 중단 금지.

### Flow D — 보맵 → 종합포털 (송신, 사업자 지원 API)

```
mydata-api / mydata-batch
  │  WebClient (mTLS, auth.bomapp.co.kr JKS)
  │  MyDataSupportClient
  ▼
종합포털 (api.mydatacenter.or.kr:7443)
  │
  ├─ POST /mgmts/oauth/2.0/token         (지원-001, 접근토큰)
  ├─ GET  /v2/mgmts/orgs                  (지원-002, 기관정보)
  ├─ POST /v2/mgmts/agreements            (전송요구)
  ├─ POST /v2/mgmts/agreements/detail     (상세)
  ├─ POST /v2/mgmts/agreements/revoke     (철회)
  └─ POST /v2/mgmts/consents/revoke       (동의 철회)
```

**핵심 클라이언트**:
- `bomapp-external/mydata/src/main/java/kr/co/bomapp/external/mydata/support/MyDataSupportClient.java`
- WebClient 빈은 `MyDataWebClientConfig` — **`@Profile("my-data")`** 조건. mydata-api/batch가 `my-data` 프로파일 켜져야 활성화.

---

## 4. mydata-batch cron 잡 10종

| 잡 | 주기 | 책임 |
|---|---|---|
| `MyDataDetailQueueTask` | `fixedDelay = 1s` | 정보 상세 수집 큐 폴링 → mydata-api 호출 트리거 |
| `MyDataTokenDeleteTask` | `fixedDelay = 1s` | 만료 토큰 정리 |
| `MyDataInsuranceScheduledTask` | `fixedDelay = 10s` | 보험 정보 스케줄 처리 |
| `MyDataRefreshTokenReissueTask` | `fixedDelay = 1m` | refresh_token 재발급 (만료 임박 토큰) |
| `MyDataRevokeTask` | `fixedDelay = 1m` | 동의 철회 후속 처리 |
| `MyDataOrgTask` | `cron 0 0/30 * * * *` (30분) | 기관정보 갱신 (지원-002) |
| `MyDataListDeleteTask` | `cron 0 0 0 * * *` (매일 00:00) | 정보 리스트 정리 |
| `MyDataSignUpTask` | `cron 0 0 0 * * *` (매일 00:00) | 가입 통계 |
| `MyDataStatisticsTask` | `cron 0 30 1 * * *` (매일 01:30) | 일일 통계 집계 → 종합포털 지원-104 |
| `MyDataNotifyTask` | `cron 0 0 16 * * *` (매일 16:00) | 만기/갱신 알림 (알림톡 모수) |

스케줄러: `SchedulerConfig` — `ThreadPoolTaskScheduler` poolSize=10.

> mydata-batch는 ECS 일반 서비스로 desired=1 (PROD-Cluster) 가동. 짧은 주기 잡(1초)은 큐 폴링 패턴이며 작업이 없으면 idle.

---

## 5. mTLS 클라이언트 인증서 공유 — `auth.bomapp.co.kr`

3개 서비스가 **동일한 EV 클라이언트 인증서**(`auth.bomapp.co.kr`)를 사용해 외부 기관과 mTLS 통신한다:

| 호출자 | 호출 방향 | 외부 대상 | 인증서 위치 |
|---|---|---|---|
| **mydata-agent** | OUT | 정보제공자(보험사·은행) | `/etc/ssl/keystore/keystore.jks` (secrets-init이 SM에서 풀어둠) |
| **mydata-api** | OUT | 통합인증기관(NAVER/KAKAO), 종합포털 | `/was/env/client-cert/auth.bomapp.co.kr_*.jks` (secrets-init이 SM에서 풀어둠) |
| **mydata-batch** | OUT | 종합포털 일부 호출 (지원-104 통계 등) | mydata-api와 동일 |
| **mydata-mgmts-api** | IN | 종합포털이 들어오는 mTLS (`5443`) | (prod) prod-alb에 ACM imported cert / (신규) JKS 동일 |

**SM 시크릿 통합**:
- 바이너리(JKS): `bomapp/{env}/external-mydata/auth-jks` (SecretBinary)
- 비번 3종(JSON): `bomapp/{env}/external-mydata` (SecretString)
  - `mydata.ssl.key-store-password`
  - `mydata.ssl.key-password` (mydata-agent yml에는 평문 하드코딩 잔존 — BOM-132 PR #11 머지 대기)
  - `mydata.ssl.trust-store-password`

**파일명 환경변수**:
- `MYDATA_CLIENT_CERT_FILENAME` (현재 `auth.bomapp.co.kr_20260610.jks`, BOM-130 PR #432에서 `_20261220.jks`로 리네임)
- mount path `/was/env/client-cert/` (mydata-api/batch). mydata-agent는 고정 `keystore.jks`.

별개 키 (인증서 갱신과 무관, 헷갈리기 쉬움):
- `bomapp/{env}/external-mydata/my-data-rsa-private-key-pem` / `…-public-key-pem` — **종합포털 JWT 서명 RSA 키쌍** (RS512). mydata-api만 사용.

---

## 6. 인터넷 도메인 / 내부 라우팅 종합

| 용도 | 도메인 / 경로 | 비고 |
|---|---|---|
| 종합포털 인바운드 수신 (mTLS) | `auth.bomapp.co.kr:5443` | route53 → prod-nlb → prod-alb default → TG 11000 → mydata-mgmts-api 구 jar |
| mydata-api 내부 (next-backend) | `int-mapi.bomapp.co.kr:8080` | prod-internal-alb. mydata-batch가 OpenFeign으로 호출 |
| mydata-agent 내부 | `magent.bomapp.co.kr:8080` | prod-internal-alb. mydata-api가 평문 HTTP로 호출 |
| 종합포털 (외부) | `https://api.mydatacenter.or.kr:7443` | 송수신 양방향 |
| NAVER 통합인증 | `https://mydata.ekyc.naver.com` | 102/103 (sign_request/sign_result) |
| KAKAO 통합인증 | `https://mydata-cert.kakao.com` | 102/103 |

`mydata-mgmts-api/NextMyDataApiClient.url = http://stg-int-mapi.bomapp.co.kr:8080` — **소스 코드 어노테이션에 하드코딩**. dev/stg에선 OK이나 prod는 `bomapp.api.url=` 빈 값으로 위임 자체가 비활성. (BOM-113 현대화 후 정리 대상.)

---

## 7. mydata-api 컨트롤러 카탈로그

| 도메인 | 컨트롤러 | 핵심 path |
|---|---|---|
| 통합인증 | `MyDataIntegrateController(V2)`, `MyDataIntegrate002CallbackController(V2)` | `/api/my-data/v1,v2/integration-authorization/*` |
| 기관 조회 | `MyDataLinkageController(V2)`, `MyDataOrgController` | `/api/mydata-linkage/v1/org/*` |
| 지원/표준 mgmts (mydata-api 측) | `MyDataSupportController`, `MyDataStatisticsController`, `ConsentsController`, `AgreementsController` | `/v3/mgmts/*`, `/v3/mgmts/signup/*` |
| 보험 정보 수집 | `MyDataInsuranceListController`, `MyDataInsuranceListCallbackController`, `MyDataInsuredListCallbackController` | `/api/mydata/v1/list-information`, callback 경로 |
| 보험 상세 | `MyDataDetailManualController`, `MyDataInsuranceDetailCallbackController`, `MyDataDetailQueueCreateController` | `/api/mydata/v1/detail-information` |
| 트랜잭션 | `MyDataTransactionController` | `/api/mydata/v1/transaction-information` |
| 토큰 갱신 | `MyDataRefreshController` | refresh 관련 |
| 헬스 | `HealthyController` | `/healthy` |

---

## 8. 현재 운영 상태 / 컷오버 미완

| 항목 | 상태 |
|---|---|
| mydata-api PROD | ECS PROD-Cluster + PROD-MYDATA-API-240522-ARM (이중) — 트래픽 분배 미검증 |
| mydata-agent PROD | ECS PROD-MYDATA-AGENT-240523-ARM (Fargate ARM64) running 2 |
| mydata-batch PROD | PROD-Cluster running 1 |
| mydata-mgmts-api PROD | **구 jar (`bomappmydata-0.0.1-SNAPSHOT.jar`, PID 15890, port 11000)** — 미컷오버. BOM-113 현대화 코드는 머지됨 |
| 인바운드 mTLS (`5443`) | prod-alb default cert = `auth.bomapp.co.kr_20260610` (6/10 만기) — **인증서 갱신 BOM-129 진행 중** |

---

## 9. 관련 문서

- [`./mydata-agent.md`](./mydata-agent.md) — mydata-agent 단독 페이지
- [`./mydata-mgmts-api.md`](./mydata-mgmts-api.md) — 종합포털 수신 서버 단독 페이지
- [`./next-backend.md`](./next-backend.md) — mydata-api / mydata-batch 포함 9개 next-backend 앱
- [`../runtime-verification.md`](../runtime-verification.md) §10 — `auth.bomapp.co.kr` 라우팅 라이브 검증
- [`../architecture.md`](../architecture.md) — 전체 서비스 그래프

## 10. 메모

- 2026-06-09 작성. 이번 cert 갱신(BOM-129) 작업 중 4종 서비스 호출 관계를 명확히 정리.
- 발견 사실: **NextMyDataApiClient URL은 prod에서 빈 값** = prod 위임 비활성. dev/stg에서만 mgmts-api가 next-backend로 위임.
- 발견 사실: **mydata-api가 mydata-agent를 호출할 때는 평문 HTTP**. mTLS는 agent → 외부 기관 구간에만 적용.
- 발견 사실: **mydata-api 자체도 mTLS 클라이언트** (통합인증기관·종합포털 호출 시). mydata-agent와 동일 JKS 공유.
