# legacy-backend (동결, 유지보수만)

> 보맵 초기(2018년) 모놀리스 백엔드. **API 부분은 `next-backend / bomapp-api` 로 이관 완료**. 현재는 `redmin` (운영자 어드민)과 `webview_server` (앱 인앱 웹뷰 / 약관 정적 파일) 만 잔존하여 프로덕션 유지만 한다.

| 항목 | 값 |
|------|----|
| 경로 | `../legacy-backend` |
| 리포 | `github.com/bomapp/legacy-backend` (추정) |
| 언어/플랫폼 | Java 1.8 / Spring Boot 1.5.14 / Maven |
| 패키징 | WAR |
| 첫 커밋 | 2018-07-09 |
| 최신 커밋 | 2024-08-19 |
| 총 커밋 수 | 7,583 |
| 최근 6개월 | 0 커밋 |
| 활동 상태 | **동결** (2024-08 이후 활동 없음, 신규 개발 금지) |
| 주요 브랜치 | `master`(HEAD), `dev`, `byeol-dev`, `byeol-prod`, `deploy/legacy/*` |

---

## 1. 책임 (현재)

- **`bomapp_webview_server`** — **활용 중 (검증)**. 보맵 안드로이드 앱이 `web.bomapp.co.kr` 으로 약관/정책/공지/콘텐츠/이벤트 + 정적 자산(JS/CSS) 을 호출. PROD-BACK 컨테이너 :7778 (PID 1428, `bomapp_webview_server-0.1.0.jar`) 에서 실행 중 ([검증](../runtime-verification.md#24-활성-java-프로세스--포트-매핑-검증))
- **`bomapp_redmin`** — 운영자 어드민. PROD-BACK `/was/data/bomapp-redmin-prod` 디렉토리 존재하나 검증한 인스턴스(`i-03f0178089f760c6f`)에서는 ps 비활성. 두 번째 인스턴스 미검증
- **`bomapp_api_server`** — 노션상 "이전 완료" 진술. 단 `/was/data/legacy-bomapp-api-prod` 디렉토리 잔존 (ps 비활성). 완전 제거 미확정
- **`bomapp_api_server_common`** — 공통 라이브러리 (위 모듈들이 의존)

---

## 2. 모듈 구조

```
legacy-backend/
├── bomapp_api_server/          # 메인 API 서버 — 폐지됨 (next-backend 로 이전)
├── bomapp_api_server_common/   # 공통 라이브러리 (잔존)
├── bomapp_webview_server/      # 앱 웹뷰 서버 (잔존)
└── bomapp_redmin/              # 운영자 어드민 (잔존)
```

---

## 3. 배포 / 도메인

### 3.1 ECS / 호스트

| 환경 | 클러스터/호스트 | 비고 |
|------|----------------|------|
| PROD | **PROD-BACK** (t3.xlarge × 2) | ECS service `prod-next-backend-was-v5/v6`. **단일 컨테이너 `next-backend-was:1.1` 가 호스트 `/was/data` 마운트로 12개 디렉토리 / 7개 활성 jar 를 수동 운영하는 공용 WAS 패턴**. legacy-backend 의 `bomapp_webview_server-0.1.0.jar` (PID 1428, port 7778) 가 SSM 검증으로 활성 확인됨. 컨테이너 27개 portMapping 중 실 listening 은 8개 미만 ([검증 상세](../runtime-verification.md#2-prod-back-클러스터-운영-실체-ssm-검증)) |
| STG | `next-stg-back` (10.1.1.149) | 직접 호스트 (Route53 고정) |
| DEV | NEXT-DEV 클러스터 (`dev-az.bomapp.co.kr`) | |

### 3.2 도메인 (legacy-backend 잔존 영역)

| 도메인 | 환경 | 컨테이너 포트 | 검증된 jar / 상태 |
|--------|------|:---:|------|
| `web.bomapp.co.kr` | PROD | 7778 | **`bomapp_webview_server-0.1.0.jar` 활성 (PID 1428)** ✓ — 보맵 앱 인앱 웹뷰 정상 호출 |
| `redmin.bomapp.co.kr` | PROD | 7575 | `bomapp-redmin-prod` 디렉토리 존재. 검증 인스턴스에서 ps 비활성 |
| `dev-rapi.bomapp.co.kr` | DEV | — | redmin (DEV) |
| `sapi.bomapp.co.kr` | PROD | 8103 | **dead routing (SSM 검증)** — 8103 listening 프로세스 없음, 7일 ALB log 0건 |
| `vkey.bomapp.co.kr` | PROD | 8080 | (vkey Tomcat connector 일 가능성, 미확정) |
| `f.bomapp.co.kr` | PROD | — | webview_server / 정적 파일 (CloudFront 경유 추정) |
| `az.bomappworks.com` | PROD | 3001 (frontend ALB) | legacy az frontend |
| `api-was1.bomapp.co.kr` `(10.1.1.10)` | PROD | — | 레거시 직접 호스트 (ECS 외) |
| `api-was2.bomapp.co.kr` `(10.1.1.20)` | PROD | — | 레거시 직접 호스트 |
| `mapi-was1.bomapp.co.kr` `(10.1.1.17)` | PROD | — | 레거시 mydata-api 직접 호스트 |
| `mapi-was2.bomapp.co.kr` `(10.1.1.194)` | PROD | — | 레거시 mydata-api 직접 호스트 |
| `batch-was.bomapp.co.kr` `(10.1.1.116)` | PROD | — | 레거시 batch 직접 호스트 |

> 직접 호스트 도메인은 ECS 가 아닌 EC2 인스턴스에 직접 떠 있으며, Route53 A 레코드로 IP 매핑되어 있다. 정리(이관) 대상.

---

## 4. 기술 스택

| 영역 | 값 |
|------|----|
| 프레임워크 | Spring Boot 1.5.14 (RELEASE, **EOL 2017-08**) |
| 언어 | Java 1.8 (**EOL 2030년 OpenJDK 무료 지원 종료 임박**) |
| 빌드 | Maven (3개 pom.xml) |
| DB | MySQL |
| 캐시 | Redis (Jedis) |
| 검색 | Elasticsearch 7.12 |
| 패키징 | WAR (서블릿 컨테이너 별도 필요 가능성) |
| 의존성 | 로컬 lib 디렉토리에 jar 보관 — 빌드 시 누락 주의 |

테스트는 `pom.xml` 에서 `maven.test.skip=true` 로 기본 비활성화. 변경 시 명시적으로 `-Dmaven.test.skip=false`.

---

## 5. 외부 연동 (히스토리)

레거시 시기에 통합한 외부 시스템 (현재는 next-backend 로 다수 이관됨):

- 보험사: G&NET, AZ, From Age, 나이스 인증
- 마이데이터: 종합포털, 보험사 마이데이터 채널
- 결제/문서: Coocon, Manos
- 알림: InfoBank (SMS/카카오톡)

---

## 6. 의존 관계 (잔존 모듈 기준)

```
운영자 ──▶ redmin.bomapp.co.kr ──▶ legacy-backend/bomapp_redmin (PROD-BACK ECS)
                                       │
                                       ├──▶ Aurora MySQL
                                       ├──▶ Redis
                                       └──▶ bomapp_my_data (legacy mydata 호출)

보맵 앱 (인앱 웹뷰) ──▶ f.bomapp.co.kr ──▶ webview_server (정적 약관)
```

---

## 7. 운영

| 항목 | 내용 |
|------|------|
| Dockerfile | (확인 필요 — PROD-BACK 에 컨테이너로 떠 있음) |
| CI/CD | 수동 배포 (`deploy/legacy/*` 브랜치 패턴) |
| 빌드 | `mvn package` → WAR |
| 로깅 | **awslogs 미설정** (PROD-BACK v7/v8 — ECS 감사 P0) |
| Circuit Breaker | **disabled** (PROD-BACK — P1) |
| 보안 | SSH 포트 2208 노출 (P0) |
| Container Insights | disabled |

---

## 8. 히스토리 마일스톤

| 시기 | 변경 |
|------|------|
| 2018-07 | 보맵 초기 백엔드 시스템 구축 (모놀리식) |
| 2018~2021 | 핵심 기능 개발 (보험, 채팅, 결제, 마이데이터 초기) |
| 2021~2023 | 보험사 API 연동 확대 (G&NET, AZ, From Age, NICE) |
| 2022-03 | next-backend 신규 리포 시작 (병행 운영) |
| 2023~2024 | 마이데이터 테이블 구조 변경 및 마이그레이션 |
| 2024-08-19 | (코드 마지막 커밋) `my_data_insurance_transaction` 테이블 최신화 |
| 2024-08 이후 | 코드 변경 없음. **단 PROD 운영은 계속됨** — `bomapp_webview_server-0.1.0.jar` 가 PROD-BACK :7778 에서 활성. 보맵 앱 webview 호출 7일 합계 정상 응답 483건 (404 봇 제외) |

---

## 9. 알려진 이슈 / 마이그레이션 상태

| 항목 | 상태 |
|------|------|
| `bomapp_api_server` → `next-backend / bomapp-api` | 노션상 "완료" 진술. 단 `/was/data/legacy-bomapp-api-prod` 디렉토리 잔존(ps 비활성), 완전 제거 미확정 |
| `bomapp_redmin` 이전 | 미완. ps 비활성이라 처리 흐름 검증 필요 |
| **`bomapp_webview_server` 이전** | **미완 + 활용 중**. 보맵 앱이 `web.bomapp.co.kr` 호출. 67개 endpoint 6개 controller 이전 + 정적 자산 S3+CloudFront 분리 필요 ([근거](../runtime-verification.md#5-legacy-backend--bomapp_webview_server-코드상-endpoint-검증)) |
| 직접 호스트(`api-was1/2`, `mapi-was1/2`, `batch-was`, `front-was`, `next-stg-back`) | 정리(폐기) 대상 |
| Spring Boot 1.5 / Java 1.8 보안 | **EOL** — 잔존 모듈도 결국 이관 또는 재작성 필요 |
| awslogs / SSH 22 / Circuit Breaker | ECS 감사 P0~P1 (PROD-BACK 대상) |

---

## 10. 작업 시 주의사항

- **신규 기능 추가 금지** — `next-backend` 또는 별도 신규 서비스에서 작업
- 보안 패치만 한정적으로 (CVE 발견 시 우선 검토)
- 변경 시 `maven.test.skip=false` 로 테스트 명시
- 로컬 lib 디렉토리 누락 확인 필수

---

## 11. 관련 문서

- [`../architecture.md`](../architecture.md)
- [`./next-backend.md`](./next-backend.md) — 이관 완료 대상
- [`./bomapp_my_data.md`](./bomapp_my_data.md) — redmin 이 직접 호출하는 레거시 마이데이터
- 노션: `legacy-backend`, `BOMAPP 인프라 구조(HQ/AWS)`
