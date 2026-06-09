# mydata-agent

> 마이데이터 게이트웨이. 외부 마이데이터 기관(보험사·은행·통신사 등)과의 mTLS 통신을 담당하며, next-backend 의 `mydata-api` 로부터 호출되어 보험 정보를 수집·조회한다. WebFlux 기반 비동기 처리.

| 항목 | 값 |
|------|----|
| 경로 | `../mydata-agent` |
| 리포 | `github.com/bomapp/mydata-agent` (추정) |
| 언어/플랫폼 | Java 17 / Spring Boot 3.0.6 / Spring WebFlux (Reactive) |
| 빌드 | Gradle |
| 첫 커밋 | 2023-05-11 |
| 최신 커밋 | 2025-05-28 |
| 총 커밋 수 | 41 |
| 최근 6개월 | 0 커밋 |
| 활동 상태 | **유지보수 모드** (안정 운영) |
| 주요 브랜치 | `prod`(HEAD), `stg`, `feat/mydata-api-system-token` |

---

## 1. 책임

- **마이데이터 기관 mTLS 통신 게이트웨이**
- HTTP 요청/응답 프록시 (mydata-api ↔ 마이데이터 기관)
- 클라이언트 인증서 기반 인증 (mTLS)
- 토큰 시스템 (`feat/mydata-api-system-token` 브랜치 단서)

내부 모듈로 만들지 않고 별도 서비스로 분리한 이유: **mTLS 클라이언트 인증서를 안전하게 관리**하고 외부 기관과의 보안 통신을 한 곳에서 통제하기 위함(추정).

---

## 2. 배포 / 환경

### 2.1 ECS

| 환경 | 클러스터 | 타입 | 리소스 | 노드 수 |
|------|---------|------|--------|---------|
| PROD | `PROD-MYDATA-AGENT-240523-ARM` | **Fargate** (awsvpc) | CPU 1024 / Memory 2048 / **ARM64** | 2 (autoscaling min=2/max=10) |
| DEV/STG | (ECS 서비스 미발견) | — | — | — |

> Fargate ARM64 + awslogs + 오토스케일링 적용된 **모범 사례** 중 하나로 ECS 감사 리포트(2026-04-06)에서 평가됨.

### 2.2 도메인

| 환경 | 외부 도메인 | 내부 도메인 | 진입 |
|------|-----------|------------|------|
| DEV | 없음 | `dev-magent.bomapp.co.kr` | (미구성) |
| STG | 없음 | `stg-magent.bomapp.co.kr` | (Internal-ALB 추정) |
| PROD | 없음 | `magent.bomapp.co.kr` | PROD-Internal-ALB:8080 → :8080 |

**모든 환경에서 외부 노출 없음** — VPC 내부에서 mydata-api 만 호출.

---

## 3. 엔드포인트

| Method | Path | 설명 |
|--------|------|------|
| GET | `/` | 헬스 체크 |
| POST | `/{path}` | 마이데이터 API GET 프록시 (path 가 그대로 마이데이터 기관 URL 로 전달) |
| POST | `/post/{path}` | 마이데이터 API POST 프록시 |
| POST | `/auth/post/{path}` | 인증 필수 POST 프록시 |

> 엔드포인트가 단순 프록시 패턴이며, 실제 마이데이터 기관 URL 매핑/라우팅은 `mydata-api` 측에서 결정한다고 추정.

---

## 4. 기술 스택

| 영역 | 라이브러리 | 버전 |
|------|----------|------|
| 프레임워크 | Spring Boot | 3.0.6 |
| 웹 | Spring WebFlux (Reactive) | — |
| 언어 | Java | 17 |
| 코드 생성 | Lombok | — |
| Async | Reactor | (WebFlux 의존) |

매우 가벼운 스택. DB·캐시·메시징 없음. WebClient 와 mTLS 키스토어가 핵심.

---

## 5. 의존 관계

```
next-backend / mydata-api
        │ (REST, Internal-ALB)
        ▼
 magent.bomapp.co.kr
        │
        ▼
   mydata-agent (ECS Fargate)
        │ (HTTPS + mTLS, WebClient)
        ▼
 외부 마이데이터 기관 (보험·은행·통신사)
```

---

## 6. 보안 / 인증서 관리

- **mTLS 클라이언트 인증서**: jks 키스토어 파일 경로가 `application.yml` 에 하드코딩 → 배포 환경마다 정확한 경로 보장 필요
- **인증서 정기 갱신**: 2025-05-28 커밋 메시지 "[anchor: agent] 인증서 갱신" — 인증서 만료 주기에 맞춰 수동 갱신
- 단일 `application.yml` 에 모든 환경 프로파일 포함

> **잠재 위험**: 인증서 파일 경로가 배포 패키지에 포함될 경우 시크릿 노출 가능. AWS Secrets Manager 또는 Parameter Store 로 분리 권장.

---

## 7. 히스토리 마일스톤

| 시기 | 변경 |
|------|------|
| 2023-05 | mTLS 기반 마이데이터 에이전트 초기 구축 (`MyDataWebClient`) |
| 2023~2024 | 마이데이터 기관 통신 안정화 (소수 변경, 안정 운영) |
| 2025-05 | 인증서 갱신 (운영 유지) |
| 2025 이후 | 활동 없음 (안정 운영 모드) |

총 41 커밋으로 매우 작은 코드베이스. 비즈니스 로직이 거의 없는 순수 프록시.

---

## 8. 운영

| 항목 | 내용 |
|------|------|
| Dockerfile | (미확인) — Fargate 에 배포되므로 컨테이너 이미지가 ECR 에 존재할 것 |
| CI/CD | GitHub Actions 폴더 미발견 (수동 배포 추정) |
| 로깅 | awslogs (Fargate 모범 사례) |
| 헬스체크 | `GET /` |
| 오토스케일링 | min=2, max=10 |
| 환경 분리 | 단일 application.yml 의 프로파일 분기 |
| 포트 (참고) | STG=8008, 기타 환경별 확인 필요 |

---

## 9. 알려진 이슈 / 개선 권고

- **인증서 경로 하드코딩**: jks 파일 경로가 application.yml 에 명시 → Secrets Manager 분리 검토
- **DEV/STG ECS 미구성**: PROD 만 ECS 배포되어 있어 비프로덕션 환경에서의 통합 테스트가 어려울 수 있음
- **next-backend 의 mydata-api 와 클러스터 통합 가능성**: 둘 다 ARM 기반이며 단순 프록시인 mydata-agent 를 mydata-api 에 흡수하는 방안이 ECS 감사에서 언급됨

---

## 10. 관련 문서

- [`../architecture.md`](../architecture.md)
- [`./next-backend.md`](./next-backend.md) — 호출자(mydata-api)
- [`./mydata-mgmts-api.md`](./mydata-mgmts-api.md) — 함께 마이데이터 계층 구성
- 노션: `마이데이터 정책 정의서`, `[마이데이터] 2.0`, `API 설계 (마데 알림톡)`
