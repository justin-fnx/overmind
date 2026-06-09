# 카카오페이 ↔ 에즈(az-was) ↔ 보맵 — 3자 통신 규약 및 전체 플로우

> 카카오페이 보험상담 연동의 3자(카카오페이 · 에즈금융서비스 az-was · 보맵) 간 통신 규약을 코드 근거로 정리한 문서.
> 분석 리포: `next-backend`(보맵), **`az-was`(GitLab 정본 `gitlab.bomapp.co.kr/bomapp/az-was`, HEAD 5049413)**, `infra`.
> WebView 연동은 범위 외(별도 문서 참조).
>
> 작성일: 2026-06-04 · 최종 정정: GitLab 정본 기준 전면 재작성

---

## 0. 정정 이력 (중요 — 이전 추론 폐기)

이 문서의 초판은 **GitHub `bomapp-inc/az-was`(구버전 미러)** 를 분석해 "az-was는 설문 수집 전용이고 카카오페이 상담 허브는 AZ 전산(azlife.kr)" 이라고 추론했으나 **이는 오류였다.** GitHub 미러에는 카카오페이 모듈이 빠져 있었다.

**GitLab 정본**(`com.az.kakaopay.consultation.*` 헥사고날 모듈 포함)으로 확인된 사실:

| 시스템 | 도메인 | 실제 역할 | 소스 |
|---|---|---|---|
| **az-was** | `az.bomapp.co.kr` | **카카오페이 보험상담 연동 허브 + 추가정보(설문) 수집.** 카카오페이에서 상담 PII 수신 → 보맵으로 상담 신청/만료 통보. 회원 PII 저장소. | ✅ GitLab 정본 |
| **AZ 전산** | `cs.azlife.kr` / `az.azlife.kr` | 설계사 조직·권한·실적 동기화 + 상담 등록(bombappCounselProc). **상담 인입 허브 아님.** | ❌ AZ 내부(소스 미보유) |

→ **카카오페이 → 에즈(az-was) → 보맵이 맞다.** "에즈"는 az-was. azlife.kr 은 별개의 설계사 백오피스 전산이다.

> ⚠ GitHub `bomapp-inc/az-was` 는 카카오페이 모듈 누락 구버전 — 사용 금지. 정본은 GitLab.

---

## 1. 행위자와 전체 플로우 (전부 HTTP)

```
┌────────────┐                                   ┌──────────────────────────────────┐
│  카카오페이  │ ◀── ① az-was가 상담PII pull ───── │      에즈 az-was (az.bomapp.co.kr)  │
│ (보험파트너) │  POST /api/v2/consults/{uuid}     │  com.az.kakaopay.consultation.*    │
│            │ ◀── ⑤ 취소 polling(1분) ────────── │  - KakaoPayFeignClient (→카카오)    │
└────────────┘  POST /api/v1/consults/canceled   │  - MemberController (←보맵 pull)    │
      ▲                                           │  - PlannerFeignClient (→보맵)       │
      │ (에즈 브릿지 웹뷰가 상담 트리거)             │  - 단일 AZ DB + Customer-Type 테넌시 │
      │  POST /consultations/kakaopay             └──────────┬───────────────────────┘
      │                                                      │
      │                          ② 상담 신청 통보 (POST)      │ ③ 회원 PII 역조회 (GET)
      │                          ④ 상담 만료 통보 (PUT)        │ /api/v1/kakaopay-members*
      │                          /external/consultations/kakaopay
      ▼                                                      ▼
                              ┌──────────────────────────────────────────────┐
                              │                 보맵 (BOMAPP)                   │
                              │  chat-api  PlannerAzController (②④ 수신)         │
                              │  wings-api ConsultationExternalController       │
                              │  bomapp-external/az-managed (③ pull)            │
                              │  ─ 별개 ─ bomapp-external/az → AZ전산(azlife.kr) │
                              └──────────────────────────────────────────────┘
```

- 카카오페이는 az-was로 **push하지 않는다.** az-was가 상담 상세를 pull하고, 취소는 1분 주기 polling으로 가져온다.
- az-was↔보맵, az-was↔카카오페이 **모든 교환은 HTTP(Feign)**. DB 직접 공유는 양측 앱 코드에 없음(§4).
- azlife.kr(AZ 전산)은 보맵 `bomapp-external/az`가 별도로 통신하는 설계사 백오피스 — 본 카카오페이 플로우의 중계 허브가 아님.

---

## 2. 3자 통신 규약 (방향별)

### 2-1. az-was ↔ 카카오페이

| 방향 | 엔드포인트 | 용도 | 인증 | 주요 필드 | 근거 |
|---|---|---|---|---|---|
| az-was→카카오 | `POST {kakaopay.url}/api/v2/consults/{uuid}` | 상담 상세(고객 PII) 조회 | `Authorization: PARTNER_KEY ${KAKAOPAY_PARTNER_KEY}` | req `client_id`; res `uuid,name,phone_number,birthday,gender,channel_code,request_date,expire_date,purposes[],is_mydata_user` | `KakaoPayFeignClient.java:22-25`, `KakaoPayFeignConfig.java:36-40`, `ConsultationInfoFindClientResponse.java:15-29` |
| az-was→카카오 | `POST {kakaopay.url}/api/v1/consults/canceled` | 제3자동의 해지 uuid 목록 (1분 polling) | 동일 | req `client_id,canceled_date`; res `canceled_consults[{uuid}]` | `KakaoPayFeignClient.java:27-29`, `ConsultationExpireScheduler.java:26-46` |
| 카카오→az-was | (없음) | — | — | 카카오는 push하지 않음(pull/polling 구조) | `ConsultationController.java:17-21` 주석(호출자=에즈 브릿지 웹뷰) |

- 인증은 단일 정적 헤더 `PARTNER_KEY` — 서명/HMAC/타임스탬프 없음. `client_id`는 헤더가 아니라 body 필드.
- 카카오 응답은 **평문 PII**로 수신 → az-was가 자체 KMS 암호화 저장. (`KakaoPayKmsDecryptor`는 정의만 있고 호출 0건 = dead code)

### 2-2. az-was ↔ 보맵

| 방향 | 엔드포인트 | 용도 | 인증 | 필드 | 근거 |
|---|---|---|---|---|---|
| az-was→보맵 | `POST {chat.url}/external/consultations/kakaopay` | 상담 신청 통보 | ⚠ `Authorization: PARTNER_KEY`(오부착) | `consultationUuid,memberId,requestDate` | `PlannerFeignClient.java:19-20`, `PlannerExternalAdaptor.java:18-21` |
| az-was→보맵 | `PUT {chat.url}/external/consultations/kakaopay` | 상담 만료/취소 통보 | ⚠ 동일 | `kakaoPayMemberId,reasonType,userKey` | `PlannerFeignClient.java:22-23` |
| az-was→보맵 | `POST {chat.url}/external/additional-info/status-changes` | 설문 상태변경 알림 | `x-client-id=az-server` + `x-api-key` | `plannerId,memberId,surveyName,status,company` | `ChatAdditionalInfoClient.java:8-16`, `ChatFeignConfig.java:24-36` |
| 보맵→az-was | `GET /api/v1/kakaopay-members` (+`/list`,`/list/name`,`/list/phone`,`/consultations/{uuid}`,`/members/{userKey}`,`/{id}/restore`) | 회원 PII 조회/병합/복원 | **무인증** | res `memberName,birthDate,telMobile,gender,...`(복호화 평문) | `MemberController.java:23-107` |
| 보맵→az-was | `DELETE /consultations/{consultationUuid}` | 관리자 철회→개인정보 삭제 | **무인증** | path `consultationUuid` | `ConsultationController.java:29-33` |
| 보맵→az-was | `/api/v1/planners/surveys*`, `/api/v1/bomapp/*` | 설문 요청/상태, 상담종료 정리 | Planner/Survey JWT 또는 무인증 | — | `PlannerController.java:38`, `BomappController.java` |

- 보맵 측 수신: chat-api `PlannerAzController`(②④), wings-api `ConsultationExternalController`, `AdditionalInfoNotificationController`. 보맵 pull 주체: `bomapp-external/az-managed` `AzManagedInterface`.
- ⚠ **[Critical]** `PlannerFeignClient`가 `KakaoPayFeignConfig`를 재사용해 ②④ 호출에 카카오용 `PARTNER_KEY` 헤더가 붙고 보맵이 기대하는 `x-client-id/x-api-key`가 안 붙음 (`PlannerFeignClient.java:15`).

### 2-3. 시퀀스 (코드 근거)

1. 에즈 브릿지 웹뷰 → az-was `POST /consultations/kakaopay {consultationUuid}` (무인증)
2. az-was → 카카오 `POST /api/v2/consults/{uuid}` → 고객 PII 수신 → 마스킹/해시/BME1 암호화 저장
3. az-was → 보맵 `POST /external/consultations/kakaopay {consultationUuid,memberId,requestDate}` 신청 통보
4. 보맵 → az-was `GET /api/v1/kakaopay-members*` 로 회원 PII 역조회(필요 시)
5. (취소) az-was 스케줄러 1분 polling으로 카카오 해지 수신 → 내부 만료 → 보맵 `PUT` 통보 / (만기) 매일 02:00 cron
6. (철회) 보맵 → az-was `DELETE /consultations/{uuid}` → PII 삭제
7. (설문) az-was 내부 상태변경 → 보맵 `POST /external/additional-info/status-changes`

---

## 3. 데이터 저장 / PII (az-was)

- 카카오페이 회원 PII 의 **실제 저장소는 az-was** (`KakaoPayMember`, `@Table kakaopay_member`):
  - 이름·전화: **마스킹 + SHA-512 해시(앞 30자, 검색용) + KMS 봉투암호화(BME1 = AES/GCM)** 3형태 저장. 평문 저장 안 함.
  - 생년월일(`birth_sun`/`birth_sang`): **평문 varchar(8)**. 성별: 평문(F/M).
  - 주민번호/CI/DI: **컬럼 없음 = 미저장.**
  - 암호화는 `@Convert` 아닌 서비스계층 수동(`MemberPrivateInfoTool`/`AwsKmsService`). 동의 만료/철회 시 PII 전부 null 파기(`KakaoPayMember.java:162-194`).
- 보맵은 회원 PII를 저장하지 않고 az-was에서 HTTP로 조회만 한다(`kakao_kakaopay_member`엔 userKey↔memberId 매핑만).

---

## 4. 공유-DB 결론 — 앱 코드엔 없음, 전부 HTTP

운영상 "az-was와 wings-api가 DB를 가운데 두고 교환한다"는 가설을 코드로 검증한 결과:

- **az-was**: datasource **단 1개 = 자기 AZ DB**(`application.yml:11-15`). 보맵 DB로 가는 2nd datasource·스키마·catalog **전무**.
- **next-backend**: AZ DB로 가는 datasource·AZ 테이블 엔티티/네이티브쿼리·`az_db` 스키마 **0건**. master/slave 복제뿐.
- **`CustomerTableStatementInspector`의 정체**: 크로스-DB 라우터가 **아니라** `Customer-Type` 헤더(기본 BOMAPP / KAKAOPAY)에 따라 **같은 AZ DB 안에서** `user_response → kakaopay_user_response` 식 **테이블명만 치환**하는 단일-DB 멀티테넌시(`CustomerTableStatementInspector.java:15-26`).

> **결론(앱 코드): 보맵↔az-was 는 앱 코드 기준 100% HTTP(Feign).** 크로스-DB 접근 코드는 양측 어디에도 없다. DB-매개 교환은 애플리케이션이 아니라 **인프라/네트워크 레벨**에서 일어난다.
>
> **방향 확정(2026-06-04 AWS 실측)**: 보맵 `prod-db` SG가 prod VPC 전체(`10.1.0.0/16`)에 3306 개방 → az-was EC2(10.1.13.11/14.11)가 보맵 DB 접근 가능. 에즈 `SG-PROD-AZ-DB`는 az-was 호스트 /32만 허용 → 보맵 앱은 에즈 DB 불가. 즉 **열린 크로스-DB 방향 = `az-was → 보맵 DB`(write) 하나**(개발팀 진술과 일치). 전용 `prod-az-db`(2025-08 신설)로 분리 이전 진행 중. 현재 시점 실태(공유 지속 vs 이전 완료)만 미해결. 상세: [`runtime-verification.md §11`](./runtime-verification.md).

---

## 5. 주목 리스크

| 심각도 | 이슈 | 근거 |
|---|---|---|
| Critical | `PlannerFeignClient`가 카카오용 `PARTNER_KEY` 헤더를 보맵 호출에 오부착(x-client-id/x-api-key 누락) | `PlannerFeignClient.java:15`, `KakaoPayFeignConfig.java:36-40` |
| High | `/api/v1/kakaopay-members*`(평문 PII)·`/consultations/*`·`/api/v1/test/*` 무인증 | `JwtAuthenticationInterceptor.java:52-69`, `MemberController.java` |
| High | Feign `Logger.Level.FULL` → PII·PARTNER_KEY·x-api-key 평문 로깅 + error stacktrace/swagger 노출 | `KakaoPayFeignConfig.java:25`, `application.yml:24-30` |
| Medium | CORS `allowedOriginPatterns "*"` + `allowCredentials(true)` | `WebConfig.java:27-40` |
| Medium | `KakaoPayKmsDecryptor`(RSAES_OAEP) 정의만, 호출 0건 = dead code | `KakaoPayKmsDecryptor.java` |
| Low | 전역 예외처리기/표준 에러코드 부재(도메인 예외 대부분 500), insert_all.sh dev DB 평문 비번 | — |

---

## 6. 미확인 / 후속

1. **공유-DB 현재 실태**: 방향은 `az-was → 보맵 DB`(write)로 **확정**(2026-06-04 SG 실측). 앱 코드엔 없고 인프라 레벨. 현재도 공유 중인지(전용 `prod-az-db` 이전 완료 여부)만 az-was 런타임 `DB_HOST` 확인 필요.
2. **카카오페이 ↔ az-was 인바운드**: 카카오 push 없음(pull). `/consultations/kakaopay` 호출자="에즈 브릿지 웹뷰"(별도 프론트, 본 범위 외).
3. **feature_base_branch**: main/develop/staging 동일 커밋. 최신 머지가 staging이라 통합 브랜치 컨벤션 팀 확인 필요.
4. **azlife.kr(AZ 전산) 규약**: 소스 미보유. 보맵 `bomapp-external/az` 측 계약만 관측 가능(별도 분석).

---

## 부록. 근거 리포·경로

- **az-was**(`/Users/justin/Projects/az-was`, GitLab): `com/az/kakaopay/consultation/{presentation,application,domain,infrastructure}`, `infrastructure/external/kakao/{KakaoPayFeignClient,KakaoPayFeignConfig,KakaoPayExternalAdapter,KakaoPayKmsDecryptor}`, `infrastructure/external/planner/{PlannerFeignClient,PlannerExternalAdaptor}`, `presentation/controller/{ConsultationController,MemberController}`, `application/scheduler/ConsultationExpireScheduler`, `domain/model/{KakaoPayMember,KakaoPayAgreementHistory,BirthDate,Gender}`, `com/az/az_was/tenant/{CustomerTableStatementInspector,CustomerType,CustomerContext,CustomerTypeFilter}`, `com/az/az_was/external/planner/*`, `service/AwsKmsService.java`, `resources/application.yml`, `Jenkinsfile`, `deploy_prod.sh`.
- **next-backend**: `bomapp-server/chat-api/.../PlannerAzController.java`·`AdditionalInfoNotificationController.java`, `bomapp-server/wings-api/.../ConsultationExternalController.java`, `bomapp-external/az-managed/AzManagedInterface.java`, `bomapp-domain/rds/.../kakaopay/*`, `bomapp-external/az/*`(별개 azlife.kr).
- **infra**: `terraform/route53.tf`(az DB CNAME), `security_groups.tf`, `target_groups.tf`(TG-AZ-http-8080).
