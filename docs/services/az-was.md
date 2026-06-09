# az-was

> 에즈금융서비스(AZ) 측 WAS. **카카오페이 보험상담 연동 허브 + 추가정보(설문) 수집** 서버. 카카오페이로부터 상담 고객정보를 받아(pull) 보맵 chat-api 로 상담 신청/만료를 통보하고, 보맵이 회원 PII 를 역조회하는 중계 지점이다. `Customer-Type` 헤더 기반 멀티테넌시(보맵/카카오페이)로 단일 DB 안에서 테이블을 분리한다.

| 항목 | 값 |
|------|----|
| 경로 | `../az-was` |
| 리포 | **GitLab 정본** `gitlab.bomapp.co.kr/bomapp/az-was` (HEAD `5049413`) |
| ⚠ 미러 | GitHub `bomapp-inc/az-was` 존재하나 **카카오페이 모듈(`com.az.kakaopay.*`)이 빠진 구버전** — 분석/작업 금지 |
| 언어/플랫폼 | Java 21 / Spring Boot 3.2.5 / Spring Cloud 2023 (OpenFeign) |
| 빌드 | Gradle (단일 모듈) · `./gradlew test` |
| 도메인 | `az.bomapp.co.kr` (도메인은 bomapp.co.kr 이나 **AZ 운영 인프라**) |
| 패키지 | `com.az.kakaopay.consultation.*` (카카오 헥사고날) + `com.az.az_was.*` (설문/공통) |
| 주요 브랜치 | `main`(HEAD) · `develop` · `staging` (현재 동일 커밋, 통합 브랜치 컨벤션 미확정) |
| 활동 상태 | **활발** (최근 카카오페이 member/fixture 작업) |
| feature_base | `main` (추정 — `staging` 가능성, 팀 확인 필요) |

---

## 1. 책임

- **카카오페이 상담 인입 허브**: 에즈 브릿지 웹뷰가 상담을 트리거하면 az-was 가 카카오페이 API 로 고객 상담정보(PII)를 조회하고, 보맵 chat-api 로 상담 신청/만료를 통보한다.
- **카카오페이 회원 PII 저장소**: 이름·전화번호를 KMS 암호화 + 마스킹 + 해시로 보관. 보맵은 저장하지 않고 az-was 에서 그때그때 조회.
- **추가정보(설문) 수집**: 설계사(보맵)가 고객에게 카드·계좌·알릴의무 설문을 요청하면 응답을 받아 저장하고, 상태변경을 보맵으로 콜백.
- **멀티테넌시**: `Customer-Type` 헤더(기본 `bomapp` / `kakaopay`)로 단일 DB 내 설문 테이블을 prefix 분리(`user_response` ↔ `kakaopay_user_response`).

> ⚠ azlife.kr(`cs.azlife.kr`/`az.azlife.kr`)은 **별개의 AZ 전산**(설계사 조직·실적·배정)으로 카카오페이 상담 허브가 아니다. az-was 와 혼동 금지.

---

## 2. 배포 / 환경

### 2.1 EC2 직접배포 (Jenkins) — ECS 아님

| 환경 | 서버 | 사설 IP | 인스턴스 | 무중단 |
|------|------|--------|---------|--------|
| PROD-A | `prod-az-was-a` | `10.1.13.11` | `i-0db1ee1ae31b04124` | ALB(`TG-AZ-http-8080`) deregister→배포→register 롤링 |
| PROD-B | `prod-az-was-b` | `10.1.14.11` | `i-0019f8f67cd16e4f4` | A→B 순차 |
| STG | `stg-az-was` | `10.1.13.10` | — | 단일 서버 graceful |
| DEV | `dev-az-was` | `10.90.110.10` | — | 단일 서버 |

- **포트 8080** (yml 미지정, Spring 기본 + 배포/헬스체크 8080 확정).
- 배포: Jenkins 파라미터(`ENVIRONMENT`=dev/stg/prod) → `./gradlew clean build` → scp + ssh `nohup java -jar`. **Docker/ECS·`.gitlab-ci.yml` 없음.** drain 엔드포인트 `POST /internal/drain` + graceful shutdown 120s.
- 두 PROD 서버 모두 **SSM 관리** (`prod-az-was-a/b`, ping Online — 2026-06-04 확인).

### 2.2 az-was-batch (ECS, 별개 컴포넌트)

- `TD-ECS-PROD-az-was-batch` (ECR `az-was-batch`, 로그 `/ecs/PROD-az-was-batch`).
- **DB 없음** — `AZ_WAS_INTERNAL_BASE_URL=https://az.bomapp.co.kr` + `AZ_WAS_INTERNAL_TOKEN` 으로 az-was 본체를 치는 **cron 트리거**(상담 만료 polling 등). ETL 아님.

---

## 3. 엔드포인트 (호출 방향별)

### 3.1 카카오페이 → az-was (인바운드)
| Method | Path | 설명 |
|--------|------|------|
| POST | `/consultations/kakaopay` | 상담 신청 접수(에즈 브릿지 웹뷰 트리거). 무인증 |
| DELETE | `/consultations/{consultationUuid}` | 개인정보 삭제(철회). 무인증 |

### 3.2 az-was → 카카오페이 (아웃바운드 Feign, `${kakaopay.url}`)
| Method | Path | 설명 |
|--------|------|------|
| POST | `/api/v2/consults/{uuid}` | 상담 상세(고객 PII) 조회 |
| POST | `/api/v1/consults/canceled` | 제3자동의 해지 상담 목록(1분 polling) |

> 인증 `Authorization: PARTNER_KEY {키}` 정적 헤더. 카카오는 az-was 로 push 안 함(pull/polling). 응답은 평문 PII 수신.

### 3.3 az-was → 보맵 (아웃바운드 Feign, `${external.chat.url}`)
| Method | Path | 설명 |
|--------|------|------|
| POST | `/external/consultations/kakaopay` | 상담 신청 통보 |
| PUT | `/external/consultations/kakaopay` | 상담 만료/취소 통보 |
| POST | `/external/additional-info/status-changes` | 설문 상태변경 콜백 (`x-client-id=az-server`/`x-api-key`) |

### 3.4 보맵 → az-was (인바운드)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/v1/kakaopay-members` (+`/list`,`/list/name`,`/list/phone`,`/consultations/{uuid}`,`/members/{userKey}`,`/{id}/restore`) | 회원 PII 조회/병합/복원. **무인증** |
| 다수 | `/api/v1/planners/surveys*`, `/api/v1/surveys*`, `/api/v1/bomapp/*` | 설문 요청/응답/상태 (Planner/Survey JWT, `@RequireCustomerType`) |
| POST | `/api/v1/auths/tokens/{planners,surveys}` | 토큰 발급 |

> 상세 필드 스키마(타입/길이/암호화)는 [`../kakaopay-az-bomapp-flow.md`](../kakaopay-az-bomapp-flow.md) 및 외부 공유본 `notion-partner-az-external-api.md` 참조.

---

## 4. 기술 스택

| 영역 | 라이브러리 | 비고 |
|------|----------|------|
| 프레임워크 | Spring Boot 3.2.5 / Java 21 | |
| 외부 통신 | Spring Cloud OpenFeign (2023.0.6) | 카카오/보맵 Feign |
| 영속 | Spring Data JPA + MySQL (`mysql-connector-j`) | **단일 datasource**, ddl-auto=update, show-sql=true |
| 암호화 | AWS KMS/STS SDK v1 (1.12.261) | 봉투암호화 BME1 (AES-256-GCM) |
| 인증 | jjwt 0.12.3 (HS512) | Survey/Planner/Legacy 3종 시크릿 |
| 멀티테넌시 | Hibernate `StatementInspector` | `CustomerTableStatementInspector` |
| 관측 | Micrometer Tracing (brave), springdoc-openapi 2.5.0 | |
| 설정 | spring-dotenv (.env) | dev/stg yml 은 .gitignore(개발팀 제공) |

---

## 5. 의존 관계

```
카카오페이 (보험 파트너)
   ▲  │ ① 상담 PII pull (POST /api/v2/consults/{uuid}, PARTNER_KEY)
   │  ▼
에즈 az-was (az.bomapp.co.kr, EC2 2대)
   │  ② 상담 신청/만료 통보 → 보맵 chat-api (/external/consultations/kakaopay)
   │  ③ ◀ 보맵이 회원 PII 역조회 (/api/v1/kakaopay-members*)
   ▼
보맵 next-backend (chat-api / wings-api, bomapp-external/az-managed)
   └ (별개) bomapp-external/az → AZ 전산 azlife.kr (설계사 배정/실적)
```

- 전부 **HTTP(Feign)**. 단, 인프라 레벨에서 az-was 가 보맵 DB 에 직접 쓰는 경로가 있음(§7).

---

## 6. 데이터 / PII / 암호화

**카카오페이 회원 PII 의 실제 저장소** = `KakaoPayMember` (@Table `kakaopay_member`).

| 항목 | 저장 형태 |
|------|----------|
| 이름 | 마스킹(`name_masked`) + SHA-512 앞30자 해시(`name_hash`) + **KMS 봉투암호화 BME1**(`name_enc`) 3중 |
| 전화 | 동일 3중(`tel_mobile_masked/_hash/_enc`) |
| 생년월일 | `birth_sun`/`birth_sang` varchar(8) 평문 |
| 성별 | char(1) `M`/`F` 평문 |
| 주민번호·CI·DI | **컬럼 없음 = 미저장** |

- KMS = `AwsKmsService` 봉투암호화(`BME1:` + AES/GCM, KMS wrap 데이터키). `@Convert` 미사용(서비스계층 수동). 동의 만료/철회 시 PII 전부 null 파기.
- 멀티테넌시: `CustomerTableStatementInspector` 가 `Customer-Type=KAKAOPAY` 일 때 설문 5개 테이블(`user_response`/`user_response_group`/`user_response_group_history`/`user_consent`/`survey_tokens`)을 `kakaopay_*` 로 prefix 치환. `kakaopay_member` 등은 치환 대상 아님.

---

## 7. 공유-DB (인프라 레벨) — az-was → 보맵 DB write

앱 코드는 az-was↔보맵 전부 HTTP 이지만, **인프라 레벨에서 az-was 가 보맵 DB 에 직접 기록**하는 경로가 존재한다(개발팀 확인 + AWS SG 실측).

- **방향 확정(2026-06-04 AWS 실측)**: 보맵 `bomapp-prod` 의 `prod-db` SG 가 prod VPC 전체(`10.1.0.0/16`)에 3306 개방 → az-was EC2(10.1.13.11/14.11) 가 보맵 DB 접근 가능. 반대로 에즈 `prod-az-db` 의 `SG-PROD-AZ-DB` 는 az-was 호스트 /32 만 허용 → **보맵 앱은 에즈 DB 접근 불가.** 즉 **열린 크로스-DB 방향 = `az-was → 보맵 DB`(write) 하나.**
- **이전 진행 중**: 전용 `prod-az-db`(2025-08 신설)·`dev-az-db`(2025-07) 로 az-was 를 보맵 DB 에서 분리하는 마이그레이션 정황.
- **미해결**: az-was 가 *현재* `DB_HOST` 로 보맵-prod 를 쓰는지 vs 이미 prod-az-db 로 이전했는지는 prod 호스트 datasource 직접 확인 필요(SSM read 가 자동 권한 분류기에 차단됨 — 명시 승인 필요).
- 상세 검증: [`../runtime-verification.md §11`](../runtime-verification.md#11-az-was--보맵-공유-db-방향-2026-06-04-검증)

---

## 8. 알려진 보안 이슈

| 심각도 | 이슈 |
|--------|------|
| Critical | `PlannerFeignClient` 가 `KakaoPayFeignConfig` 재사용 → 보맵 호출에 `x-client-id/x-api-key` 대신 카카오용 `PARTNER_KEY` 헤더 오부착 |
| Critical | `JwtTokenProvider.validateToken` 이 exp 만 검사하고 **HMAC 서명 미검증**("백오피스 호환" 주석) → 위조 토큰 통과 |
| High | `/api/v1/kakaopay-members*`(평문 PII)·`/consultations/*`·`/api/v1/test/*` 무인증 |
| High | Feign `Logger.Level.FULL` → PII·`PARTNER_KEY`·`x-api-key` 평문 로깅 |
| Medium | CORS `allowedOriginPatterns "*"` + `allowCredentials(true)`, prod swagger/stacktrace 노출, `KakaoPayKmsDecryptor`(RSAES_OAEP) dead code |
| Low | `insert_all.sh` 에 dev DB 평문 비밀번호 하드코딩, 전역 예외처리기 부재 |

---

## 9. 관련 문서

- [`../kakaopay-az-bomapp-flow.md`](../kakaopay-az-bomapp-flow.md) — 카카오페이↔에즈↔보맵 3자 통신 규약/플로우 (정본)
- [`../runtime-verification.md §11`](../runtime-verification.md) — 공유-DB 방향 AWS 실측
- [`./next-backend.md`](./next-backend.md) — 보맵 측(chat-api/wings-api, bomapp-external/az·az-managed)
- 외부 공유본(제휴사 치환): Notion `제휴업체-에즈-보맵 API 연동 명세 (외부 공유용)`
