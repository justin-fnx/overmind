# mydata-mgmts-api

> 금융 마이데이터 표준 **'지원 API(mgmts)' 수신 서버**. 보맵이 마이데이터사업자(정보수신자)로서 `auth.bomapp.co.kr` 에 노출하며, 종합포털(`api.mydatacenter.or.kr`)이 동의·전송요구(`/v2/mgmts/*`) 표준 API를 호출한다. 마이데이터 OAuth 토큰(RS512) 발급·동의 관리를 표준 스펙대로 자체 구현. **규제필수.**
>
> **구 이름 `bomapp_my_data`** (BOM-121, 2026-06 리네임). **BOM-113 현대화 완료**(SB 3.4.5 / Java 21 / jakarta / jjwt 0.12). **✅ 2026-06-11 PROD 신규 ECS 100% 컷오버 완료**(빌드 `20260611-9e0b726`, taskDef `:7`).

| 항목 | 값 |
|------|----|
| 경로 | `../mydata-mgmts-api` |
| 리포 | `github.com/bomapp-inc/mydata-mgmts-api` (구 `bomapp_my_data`, GitHub 구 URL 리디렉션) |
| 언어/플랫폼 | **Java 21 / Spring Boot 3.4.5 / Spring Cloud 2024.0** (BOM-115; 구 Java 11 / SB 2.3.4 / Hoxton) |
| Java 패키지 | `kr.co.bomapp.mydata.mgmts` (구 `kr.co.bomapp.auth.bomappmydata`) |
| artifact | `mydata-mgmts-api` (구 `bomappmydata`) |
| 빌드 | Maven (+ Dockerfile temurin-21) |
| feature_base_branch | `master` |
| 활동 상태 | **현대화 완료 · ECS 컨테이너화 · ✅ PROD 신규 ECS 100% 컷오버 완료(2026-06-11)** |

---

## 1. 책임

- 마이데이터 **종합포털 ↔ 보맵** 표준 동의·전송요구 수신 (`/v2/mgmts/consents`·`/agreements`)
- 마이데이터 **OAuth 토큰**(RS512 자체 서명) 발급
- 동의(Consent) / 약정(Agreement) / 관리(Management) 데이터 관리
- 일부 경로는 `next-backend/mydata-api` 로 위임 (OpenFeign `NextMyDataApiClient`)

> legacy-backend(redmin) 이 이 서비스를 직접 호출하는 백로그 존재 — next-backend 경로와 데이터 정합 확인 필요.

---

## 2. 배포 / 환경

### 2.1 현재 PROD (신규 ECS, ✅ 2026-06-11 100% 컷오버 완료)

검증: [runtime-verification.md §10](../runtime-verification.md)
- 라우팅: `auth.bomapp.co.kr` → prod-nlb:5443 → prod-alb:5443 **prio-100 host 룰(host=auth)** → TG `prod-mydata-mgmts-api-ip-8080`(신규 100%) → ECS `PROD-Cluster / SVC-ECS-PROD-mydata-mgmts-api`(taskDef `:7`, 2 태스크 healthy)
- 빌드 `20260611-9e0b726`, 컨테이너 **8080**, 프로파일 `prod`, secrets-init(JWT 2키, BOM-131), DESIRED 2 / CPU_RESERVATION soft
- 컷오버 절차(2026-06-11): source-ip 핀(사무실 `14.52.60.172`→신규 100%)으로 검증 → weighted 카나리 **25%→50%→100%** 단계 증량 → 핀 제거. 각 단계 genuine consents/agreements **2xx** 확인, ERROR/5xx 0.
- **롤백 경로**: 구 jar(`bomappmydata-0.0.1-SNAPSHOT.jar`, PROD-BACK `i-03f…:11000`)는 `prio-100 weight 0` + `:5443 default` 로 잔존(stub, 무트래픽). 장기 0 확인 후 제거.
- ~150 req/일. **규제필수 — EV 인증서(5443) 구간.**

### 2.2 빌드/배포 파이프라인 (BOM-114)

- `.github/workflows`: `build-and-deploy.yml`(env 입력 필수, 기본값 없음) → `build.yml`(Jib→ECR, 태그 `YYYYMMDD-shortsha`) → `ecs-deploy.yml`(task def 등록 + `update-service`, circuit breaker rollback, min100/max200 **무중단 롤링**)
- prod overlay `ops/ecs/mydata-mgmts-api/overlays/prod/.env`: CLUSTER `PROD-Cluster`, SERVICE `SVC-ECS-PROD-mydata-mgmts-api`, TASK_FAMILY `TD-ECS-PROD-mydata-mgmts-api`, 포트 8080, JWT secrets-init(BOM-131), APM enabled(BOM-142). 레거시 `deploy/*`(SSH/S3) = DEPRECATED
- 배포: `gh workflow run build-and-deploy.yml --ref master -f environment=prod` (ref 명시 권장)
- ⚠ 2026-06-11 컷오버 시 ALB 룰/가중치를 **aws-cli로 직접 변경 = Terraform drift**. infra 반영 필요(반드시 `-target`, blanket apply 금지)

---

## 3. 엔드포인트 (표준 mgmts)

| Method | Path | 설명 |
|--------|------|------|
| GET | `/healthy` | 헬스 체크 |
| POST | `/v2/mgmts/consents` | 동의 정보(지원-103) |
| POST | `/v2/mgmts/consents/revoke` | 동의 철회 |
| POST | `/v2/mgmts/agreements` | 전송요구/약정(지원-105) |
| POST | `/v2/mgmts/agreements/detail` | 약정 상세 |
| GET | `/v2/mgmts/req-statistics` | 통계(지원-104) |
| POST | `/mgmts/oauth/2.0/token` | OAuth 토큰 발급 |

> **계약 불변**: 표준 요청·응답 JSON·RS512 토큰은 외부 종합포털 연동 계약 → 변경 금지. (BOM-116 에서 deprecated `/v1/mgmts/*` 및 이관완료 `OpenApiController`(`/api/external/v1/*`) 제거.)

---

## 4. 기술 스택 (BOM-115 후)

| 영역 | 라이브러리 | 버전 |
|------|----------|------|
| 프레임워크 | Spring Boot | **3.4.5** |
| 클라우드 | Spring Cloud | **2024.0** |
| 언어 | Java | **21** |
| ORM | Spring Data JPA (jakarta.persistence) | (Boot 관리) |
| 캐시 | Spring Data Redis (Jedis) | (Boot 관리, `spring.data.redis.*`) |
| HTTP 클라이언트 | OpenFeign | (2024.0) |
| 인증 | jjwt | **0.12.6** (RS512) |
| DB | MySQL (`mysql-connector-j`) | (Boot 관리) |
| 템플릿 | Thymeleaf | (Boot 관리) |
| 빌드/이미지 | Maven / Dockerfile(temurin-21) | — |

---

## 5. 의존 관계

```
보맵 앱 ──▶ next-backend/mydata-api ──▶ mydata-mgmts-api
                                    └──▶ mydata-agent (마이데이터 기관 통신)

종합포털(api.mydatacenter.or.kr:7443) ──▶ mydata-mgmts-api (/v2/mgmts/*, 표준 수신)
legacy-backend(redmin) ──▶ mydata-mgmts-api (직접, 미이관)

mydata-mgmts-api ──▶ 종합포털(OpenFeign) / next-backend(NextMyDataApiClient) / MySQL / Redis(10.10.10.71)
```

---

## 6. 운영

| 항목 | 내용 |
|------|------|
| Dockerfile | ✅ BOM-114 (temurin-21 멀티스테이지, ARM64, nonroot) |
| CI/CD | ✅ GitHub Actions build→ECR→ECS (BOM-114). 레거시 `deploy/*`(수동 SSH/S3) = DEPRECATED |
| 테스트 | `mvn test` 4통과/1스킵(`SlackApiClientTest` @Disabled 실 웹훅). 로컬 JDK 없음 → docker `maven:3.9-eclipse-temurin-21` |
| 관측성 | ES 로그 `logs-prod-mydata-mgmts-api`(데이터스트림, **가동중**) + Elastic APM(prod overlay `ELASTIC_APM_ENABLED=true`, BOM-142). BOM-119 후속 |
| 헬스체크 | `GET /healthy` |
| 보안 | clientSecret/토큰 로그 마스킹(BOM-116), nonroot 컨테이너 |

---

## 7. 모더나이제이션 이력 (BOM-113)

| 티켓 | 내용 | 상태 |
|------|------|------|
| BOM-116 | 죽은코드 제거 + 보안(clientSecret 마스킹, OpenApiController/v1 제거, servicese→services) | ✅ 머지 |
| BOM-115 | SB 2.3→3.4.5 / Java 11→21 / jakarta / jjwt 0.12 (RS512 토큰 바이트 동등 검증) | ✅ 머지 |
| BOM-114 | 컨테이너화(Dockerfile/CI/ops overlays, 8080, dev/stg/prod) — 앱 산출물 | ✅ 머지 (infra 컷오버 미완) |
| BOM-121 | 풀 리네임(repo/패키지/artifact → mydata-mgmts-api) | ✅ Phase 1 머지 · Phase 2 repo 리네임 완료 |
| BOM-119 | ES 로깅 + Elastic APM | ⏸ Backlog |

---

## 8. 알려진 이슈 / 남은 작업

- ✅ **PROD 컷오버 완료(2026-06-11)**: 신규 ECS 100%. 남은 정리 = ① ALB 룰/가중치 **Terraform 반영**(aws-cli 변경분, `-target`), ② 구 11000 롤백 stub 제거(장기 무트래픽 확인 후).
- ✅ **agreements NPE fix (PR #18)**: `AgreementService.getAgreement` 에서 upstream `provConsentCnt=null` 을 `int` 로 언박싱 → NPE (카나리 검증 트래픽이 PROD에서 발견). null→0 가드 + 단위테스트. 빌드 `20260611-9e0b726` 에 포함.
- 🟡 **HikariCP stale-connection WARN**: idle 후 `max-lifetime` 이 DB `wait_timeout` 보다 길어 풀 커넥션이 stale → borrow 시 검증/폐기(self-healing, **요청 실패 0**). `spring.datasource.hikari.max-lifetime` 단축 권고(비차단).
- **이중 운영**: legacy-backend(redmin) 직접 호출 ↔ next-backend 경로 데이터 정합.
- **테스트**: agreements null 케이스 단위테스트 추가(PR #18). consents/revoke 등 표준 계약 회귀 테스트는 여전히 얕음.

---

## 9. 관련 문서

- [`../runtime-verification.md`](../runtime-verification.md) §10 — `auth.bomapp.co.kr` 라우팅/트래픽 검증
- [`../architecture.md`](../architecture.md)
- [`./next-backend.md`](./next-backend.md) — mydata-api(위임/호출 대상)
- [`./mydata-agent.md`](./mydata-agent.md) — 마이데이터 수집 게이트웨이
- [`./legacy-backend.md`](./legacy-backend.md) — redmin 직접 호출
- 노션: 마이데이터 정책 정의서, [마이데이터] 2.0
