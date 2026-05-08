# bomapp_my_data (레거시)

> 레거시 마이데이터 인증/동의 관리 서비스. 사용자의 마이데이터 토큰 발급/갱신/폐기 및 동의 정보를 관리한다. 차세대 `next-backend / mydata-api` 로 단계적 이관 진행 중.

| 항목 | 값 |
|------|----|
| 경로 | `../bomapp_my_data` |
| 리포 | `github.com/bomapp/bomapp_my_data` (추정) |
| 언어/플랫폼 | Java 11 / Spring Boot 2.3.4 / Spring Cloud Hoxton.SR8 |
| 빌드 | Maven |
| 첫 커밋 | 2021-11-26 |
| 최신 커밋 | 2025-10-22 |
| 총 커밋 수 | 80 |
| 최근 6개월 | 0 커밋 |
| 활동 상태 | **유지보수 (이관 중)** |
| 주요 브랜치 | `master`(HEAD), `develop`, `feat/whee/mydata/statistics`, `feat/hyoj/제휴고객-분리작업` |

---

## 1. 책임

- **마이데이터 종합포털 ↔ 보맵** 간 정보 동의 및 조회
- **마이데이터 OAuth 토큰** 발급/갱신/폐기
- **동의(Consent) / 약정(Agreement) / 관리(Management)** 데이터 관리
- **제휴 고객 분리** (기업 고객 vs 개인 고객 — `feat/hyoj/제휴고객-분리작업` 브랜치)
- 마이데이터 통계 (`feat/whee/mydata/statistics`)

> 노션 정책 문서에 따르면 **레드민(legacy-backend)은 여전히 이 서비스를 호출**하지만, 보맵 앱은 이미 `next-backend / mydata-api` 를 호출. 두 경로의 데이터가 일치하지 않는 백로그 존재.

---

## 2. 배포 / 환경

### 2.1 ECS

**검증된 운영 형태** ([SSM 결과](../runtime-verification.md#24-활성-java-프로세스--포트-매핑-검증)):
- `PROD-BACK` 클러스터의 공용 WAS 컨테이너(`next-backend-was:1.1`) 안에 jar 형태로 수동 배포되어 운영
- 디렉토리: `/was/data/bomapp-mydata-prod/`
- jar: `bomappmydata-0.0.1-SNAPSHOT.jar`
- 활성 PID: 15890 (UID `bomapp`, `--spring.profiles.active=prod`)
- 시작 옵션: `--spring.config.location=/was/run/bomapp-mydata-prod/data/application-prod.properties`

Terraform 의 `aws_ecs_service` / `aws_ecs_task_definition` 에 `bomapp_my_data` 별도 정의는 **없음**. PROD-BACK 컨테이너 안에서 사람이 jar 를 띄운 상태.

### 2.2 도메인 / 포트

| 환경 | 포트 (코드 기본) |
|------|------|
| develop / product | 11000 |
| staging | 15000 |

PROD 컨테이너 내부 listening: PID 15890 활성 + 호스트 docker-proxy 11000 존재. 단 컨테이너 내부 netstat 결과에서 11000 의 PID 매핑은 직접 표시되지 않음 — 11000 listening 의 주체가 bomapp_my_data 일 가능성이 높지만 **컨테이너 내부 netstat 출력으로는 단정 어려움** (검증 한계).

도메인 매핑은 PROD-ALB listener 5443 → backend-was-v2 (port 11000) 단서가 있으나 **5443 으로 가는 host header rule 매칭은 별도 확인 필요**.

---

## 3. 엔드포인트

| Method | Path | 설명 |
|--------|------|------|
| GET | `/healthy` | 헬스 체크 |
| POST | `/v2/mgmts/consents` | 동의 정보 조회 |
| POST | `/v2/mgmts/consents/revoke` | 동의 철회 |
| POST | `/v2/mgmts/agreements` | 약정 정보 조회 |
| POST | `/v2/mgmts/agreements/detail` | 약정 상세 조회 |
| POST | `/mgmts/oauth/2.0/token` | OAuth 토큰 발급 |
| GET | `/v2/mgmts/req-statistics` | 통계 조회 |

API 패턴: `/v2/mgmts/*` (mgmts = 종합포털 인터페이스 추정), `/mgmts/oauth/2.0/*`.

---

## 4. 기술 스택

| 영역 | 라이브러리 | 버전 |
|------|----------|------|
| 프레임워크 | Spring Boot | 2.3.4 |
| 클라우드 | Spring Cloud | Hoxton.SR8 |
| 언어 | Java | 11 |
| ORM | Spring Data JPA | (Boot 관리) |
| 캐시 | Spring Data Redis (Jedis) | — |
| HTTP 클라이언트 | OpenFeign | (Hoxton) |
| 인증 | jjwt | 0.11.2 |
| DB | MySQL (JDBC) | — |
| 템플릿 | Thymeleaf | — |
| 빌드 | Maven (`pom.xml`) | — |

> **EOL 임박**: Spring Boot 2.3 / Java 11 모두 OSS 지원 종료. 보안 패치 부재 — 이관이 늦어질수록 위험 증가.

---

## 5. 의존 관계

```
보맵 앱  ──▶ next-backend / mydata-api  ──▶ bomapp_my_data (현재)
                                       └──▶ mydata-agent (마이데이터 기관 통신)

legacy-backend / redmin  ──▶ bomapp_my_data (직접, 이관 안 됨)

bomapp_my_data ──▶ 마이데이터 종합포털 (OpenFeign)
                ──▶ Aurora MySQL
                ──▶ Redis
```

---

## 6. 외부 연동

- **마이데이터 종합포털** — 동의/조회 (OpenFeign HTTP)
- **next-backend / mydata-api** — 결과 전달 / 의존 호출

---

## 7. 운영

| 항목 | 내용 |
|------|------|
| Dockerfile | 없음 — 추정: jar 직접 배포 또는 ECS 별도 빌드 |
| CI/CD | 수동 배포 (GitHub Actions/GitLab CI 폴더 미확인, 활동 부족) |
| 빌드 산출물 | `pom.xml` 기반 Maven jar |
| 로깅 | (확인 필요) |
| 헬스체크 | `GET /healthy` |
| 환경 설정 | `application.properties` 환경별 분리 |
| Thymeleaf 템플릿 | OAuth 동의 화면 등에 사용 추정 |

---

## 8. 히스토리 마일스톤

| 시기 | 변경 |
|------|------|
| 2021-11 | 마이데이터 관리 서비스 초기 구축 |
| 2023~2024 | 동의/조회/통계 기능 개발 |
| 2024~2025 | 종합포털 API URL 변경 (stg ↔ prod 전환), 제휴 고객 분리 작업 |
| 2025-10-22 | (마지막) 지원 API 마이데이터 url 변경 |
| 2025-10 이후 | 활동 없음 (이관 진행 — `next-backend/mydata-api` 가 신규 진입점) |

---

## 9. 알려진 이슈 / 마이그레이션 상태

- **EOL 의존성**: SB 2.3 / Java 11 — 이관 우선순위 높음
- **이중 운영**: legacy-backend redmin 이 이 서비스를 직접 호출 → 보맵 앱(next-backend) 경로와 데이터 불일치 가능
- **신규 기능 금지**: 이관 대상이므로 신규 기능 추가는 `next-backend/mydata-api` 에서 수행
- **Terraform 미관리**: ECS 정의가 코드에 없음
- **도메인 매핑 명확하지 않음**: PROD-ALB listener 5443 의 backend-was-v2 와의 연관 검증 필요

---

## 10. 관련 문서

- [`../architecture.md`](../architecture.md)
- [`./next-backend.md`](./next-backend.md) — 이관 대상(mydata-api)
- [`./mydata-agent.md`](./mydata-agent.md) — 함께 마이데이터 계층 구성
- [`./legacy-backend.md`](./legacy-backend.md) — redmin 이 이 서비스를 직접 호출
- 노션: `마이데이터 정책 정의서`, `[마이데이터] 2.0`, `API 설계 (마데 알림톡)`
