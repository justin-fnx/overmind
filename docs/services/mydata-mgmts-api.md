# mydata-mgmts-api

> 금융 마이데이터 표준 **'지원 API(mgmts)' 수신 서버**. 보맵이 마이데이터사업자(정보수신자)로서 `auth.bomapp.co.kr` 에 노출하며, 종합포털(`api.mydatacenter.or.kr`)이 동의·전송요구(`/v2/mgmts/*`) 표준 API를 호출한다. 마이데이터 OAuth 토큰(RS512) 발급·동의 관리를 표준 스펙대로 자체 구현. **규제필수.**
>
> **구 이름 `bomapp_my_data`** (BOM-121, 2026-06 리네임). **BOM-113 현대화 완료**(SB 3.4.5 / Java 21 / jakarta / jjwt 0.12) — 단 PROD 는 아직 구 jar(미컷오버).

| 항목 | 값 |
|------|----|
| 경로 | `../mydata-mgmts-api` |
| 리포 | `github.com/bomapp-inc/mydata-mgmts-api` (구 `bomapp_my_data`, GitHub 구 URL 리디렉션) |
| 언어/플랫폼 | **Java 21 / Spring Boot 3.4.5 / Spring Cloud 2024.0** (BOM-115; 구 Java 11 / SB 2.3.4 / Hoxton) |
| Java 패키지 | `kr.co.bomapp.mydata.mgmts` (구 `kr.co.bomapp.auth.bomappmydata`) |
| artifact | `mydata-mgmts-api` (구 `bomappmydata`) |
| 빌드 | Maven (+ Dockerfile temurin-21) |
| feature_base_branch | `master` |
| 활동 상태 | **현대화 완료(코드) · ECS 컨테이너화 산출물 준비 · PROD 미컷오버** |

---

## 1. 책임

- 마이데이터 **종합포털 ↔ 보맵** 표준 동의·전송요구 수신 (`/v2/mgmts/consents`·`/agreements`)
- 마이데이터 **OAuth 토큰**(RS512 자체 서명) 발급
- 동의(Consent) / 약정(Agreement) / 관리(Management) 데이터 관리
- 일부 경로는 `next-backend/mydata-api` 로 위임 (OpenFeign `NextMyDataApiClient`)

> legacy-backend(redmin) 이 이 서비스를 직접 호출하는 백로그 존재 — next-backend 경로와 데이터 정합 확인 필요.

---

## 2. 배포 / 환경

### 2.1 현재 PROD (구 jar, 미컷오버)

검증: [runtime-verification.md §10](../runtime-verification.md)
- 라우팅: `auth.bomapp.co.kr` → prod-nlb:5443 → prod-alb:5443 **default** → TG `prod-back-ecs-host-2-http-11000` → `i-03f0178089f760c6f:11000`
- `PROD-BACK` 공용 WAS 컨테이너(`next-backend-was:1.1`) 내 **수동 기동 jar**: PID 15890 `bomappmydata-0.0.1-SNAPSHOT.jar`(구 코드, UID `bomapp`)
- 호스트 디렉토리: `/was/data/bomapp-mydata-prod/`, 시작: `--spring.profiles.active=prod --spring.config.location=/was/run/bomapp-mydata-prod/data/application-prod.properties`
- ~150 req/일(2026-06). **규제필수 — 임의 중단 금지.**

### 2.2 신규 ECS (BOM-114 산출물, 미배포)

- `Dockerfile`(temurin-21 멀티스테이지, ARM64, nonroot), `.github/workflows`(build→ECR→ECS, `workflow_dispatch`), `ops/ecs/mydata-mgmts-api/overlays/{dev,stg,prod}`
- 컨테이너 포트 **8080**(전 환경), 프로파일 **dev/stg/prod**, prod `DESIRED_COUNT=2`·`CPU_RESERVATION` soft(TASK_CPU 하드캡 금지)
- 실제 ECR/ECS/TG/ALB 5443 컷오버(weighted/blue-green)는 **별도 infra 티켓**(미완)

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
| 관측성 | ES 로그(`logs-{env}-mydata-mgmts-api`) + Elastic APM = **BOM-119** (미완) |
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

- **PROD 미컷오버**: 코드는 현대화·컨테이너화됐으나 PROD 는 구 jar(11000)로 가동. 실제 ECS 전환 = infra 티켓(ECR/ECS/TG/ALB 5443 weighted/blue-green, EV 인증서 구간 유지).
- **이중 운영**: legacy-backend(redmin) 직접 호출 ↔ next-backend 경로 데이터 정합.
- **테스트 얕음**: 표준 mgmts 계약(consents/agreements) 단위/회귀 테스트 부재.

---

## 9. 관련 문서

- [`../runtime-verification.md`](../runtime-verification.md) §10 — `auth.bomapp.co.kr` 라우팅/트래픽 검증
- [`../architecture.md`](../architecture.md)
- [`./next-backend.md`](./next-backend.md) — mydata-api(위임/호출 대상)
- [`./mydata-agent.md`](./mydata-agent.md) — 마이데이터 수집 게이트웨이
- [`./legacy-backend.md`](./legacy-backend.md) — redmin 직접 호출
- 노션: 마이데이터 정책 정의서, [마이데이터] 2.0
