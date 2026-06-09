# 카카오페이 ↔ 에즈(az-was) ↔ 보맵 통합 연동 명세

> 카카오페이 보험상담 3자 연동의 API·데이터·인증·플로우를 코드 근거로 정리한 통합 명세.
> 분석 리포: `next-backend`(보맵), `az-was`(**GitLab 정본** `gitlab.bomapp.co.kr/bomapp/az-was`, HEAD 5049413), `infra`(Terraform).
> 모든 사실 주장은 실제 소스 기준이며 `파일:라인`으로 근거를 표기. WebView 연동은 본 문서 범위 외.
> 최종 갱신: 2026-06-04 (GitLab 정본 기준 전면 재작성)

> ⚠️ **핵심 구도**
> - 흐름은 **카카오페이 → 에즈(az-was) → 보맵**. "에즈"의 상담 허브는 **az-was**(`az.bomapp.co.kr`)다.
> - `az-was` 정본은 **GitLab**. GitHub `bomapp-inc/az-was`는 카카오페이 모듈이 빠진 **구버전 미러(사용 금지)**.
> - `azlife.kr`(`cs.azlife.kr`/`az.azlife.kr`)은 **별개의 AZ 전산**(설계사 조직·실적·배정)으로, 카카오페이 상담 인입 허브가 아니다. 본 문서에서는 보조 채널로만 다룬다.

---

## 0. 구도 요약

| 채널 | 구간 | 프로토콜 | 인증 |
|---|---|---|---|
| ① az-was → 카카오페이 | 상담 PII 조회 / 취소 polling | REST(Feign) | `Authorization: PARTNER_KEY` |
| ② az-was → 보맵(chat-api) | 상담 신청/만료 통보 | REST(Feign) | ⚠ PARTNER_KEY 오부착 |
| ③ 보맵 → az-was | 회원 PII 역조회 | REST(Feign) | 무인증 |
| ④ az-was → 보맵 | 설문 상태 콜백 | REST(Feign) | `x-client-id`/`x-api-key` |
| ⑤ 보맵 ↔ az-was | 설문 요청/응답 | REST(Feign) | Planner/Survey JWT |
| (별개) 보맵 ↔ AZ전산(azlife) | 상담 등록·설계사 배정·실적 | REST(Feign) | AES payload 암복호 |

> 핵심: 카카오페이는 az-was로 **push하지 않는다**(az-was가 pull/polling). 보맵↔az-was 교환은 **전부 HTTP**(공유-DB는 §5 참조).

---

## 1. API 연동 명세 (엔드포인트 / 인증 / 요청·응답 / 에러)

### 1-1. az-was ↔ 카카오페이

| 방향 | 엔드포인트 | 용도 | 인증 | 요청/응답 | 근거 |
|---|---|---|---|---|---|
| az-was→카카오 | `POST {kakaopay.url}/api/v2/consults/{uuid}` | 상담 상세(고객 PII) 조회 | `Authorization: PARTNER_KEY ${KAKAOPAY_PARTNER_KEY}` | req `client_id` / res `uuid,name,phone_number,birthday,gender,channel_code,channel_name,request_date,expire_date,purposes[{question,answer}],has_support_user_detail,is_mydata_user` | `KakaoPayFeignClient.java:22-25`, `KakaoPayFeignConfig.java:36-40`, `ConsultationInfoFindClientResponse.java:15-29` |
| az-was→카카오 | `POST {kakaopay.url}/api/v1/consults/canceled` | 제3자동의 해지 uuid 목록(1분 polling) | 동일 | req `client_id,canceled_date` / res `canceled_date,canceled_consults[{uuid}]` | `KakaoPayFeignClient.java:27-29`, `ConsultationExpireScheduler.java:26-46` |

- 인증은 **단일 정적 헤더** `PARTNER_KEY` — 서명/HMAC/타임스탬프 없음. `client_id`는 헤더가 아닌 body 필드(`KakaoPayExternalAdapter.java:29`).
- 카카오 응답은 **평문 PII**로 수신 → az-was가 자체 암호화 저장(§2-2). `KakaoPayKmsDecryptor`(RSAES_OAEP)는 정의만 있고 호출 0건 = **dead code**.
- Feign 타임아웃 connect 3s/read 5s, **Logger.Level.FULL**(`KakaoPayFeignConfig.java:25-49`).

### 1-2. az-was ↔ 보맵

| 방향 | 엔드포인트 | 용도 | 인증 | 필드 | 근거 |
|---|---|---|---|---|---|
| az-was→보맵 | `POST {chat.url}/external/consultations/kakaopay` | 상담 신청 통보 | ⚠ `Authorization: PARTNER_KEY`(오부착) | `consultationUuid,memberId,requestDate` | `PlannerFeignClient.java:19-20`, `PlannerExternalAdaptor.java:18-21` |
| az-was→보맵 | `PUT {chat.url}/external/consultations/kakaopay` | 상담 만료/취소 통보 | ⚠ 동일 | `kakaoPayMemberId,reasonType,userKey` | `PlannerFeignClient.java:22-23` |
| az-was→보맵 | `POST {chat.url}/external/additional-info/status-changes` | 설문 상태변경 알림 | `x-client-id=az-server` + `x-api-key` | `plannerId,memberId,surveyName,status,company` | `ChatAdditionalInfoClient.java:8-16`, `ChatFeignConfig.java:24-36` |
| 보맵→az-was | `GET /api/v1/kakaopay-members` (+`/list`, `/list/name`, `/list/phone`, `/consultations/{uuid}`, `/members/{userKey}`, `/{id}/restore`) | 회원 PII 조회/병합/복원 | **무인증** | res `memberName,birthDate,telMobile,gender,afterMemberId,consultationUuid`(복호화 평문) | `MemberController.java:23-107` |
| 보맵→az-was | `DELETE /consultations/{consultationUuid}` | 관리자 철회→개인정보 삭제 | **무인증** | path `consultationUuid` | `ConsultationController.java:29-33` |
| 보맵→az-was | `/api/v1/planners/surveys*`, `/api/v1/bomapp/*` | 설문 요청/상태, 상담종료 정리 | Planner/Survey JWT 또는 무인증 | — | `PlannerController.java:38`, `BomappController.java` |

- 보맵 수신부: chat-api `PlannerAzController`(②), wings-api `ConsultationExternalController`, `AdditionalInfoNotificationController`(④). 보맵 pull 주체: `bomapp-external/az-managed` `AzManagedInterface`(③).
- ⚠ **[Critical]** `PlannerFeignClient`가 `KakaoPayFeignConfig`를 재사용 → ② 호출에 카카오용 `PARTNER_KEY` 헤더가 붙고 보맵이 기대하는 `x-client-id/x-api-key`가 누락(`PlannerFeignClient.java:15`).

### 1-3. (별개) 보맵 ↔ AZ전산(azlife.kr) — 설계사 배정/실적

> 카카오페이 인입과 다른 별도 채널. 보맵 `bomapp-external/az` 모듈. 소스는 AZ 내부(미보유), 보맵 측 계약만 관측.

| 방향 | 엔드포인트 | 용도 | 근거 |
|---|---|---|---|
| 보맵→azlife | `POST {az.url=cs.azlife.kr}/api/service/bomappCounselProc` | 상담 등록 | `AzExternalClient.java:17-18` |
| 보맵→azlife | `POST .../bomappCounselModifingProc` | 취소/채널변경 | `AzExternalClient.java:23-24` |
| 보맵→azlife V2 | `{az.url-v2=az.azlife.kr}/api/service/bomapp/{group,type,user,month_report}` | 조직/권한/설계사/실적 | `AzExternalClientV2.java:17-35` |
| azlife→보맵 | `POST /external/assign-consultant`, `/external/consultation/update/status` | 상담사 배정/상태 | `ConsultationExternalController.java:59-103` |

- 인증: 요청 필드 전체 **AES/CBC/PKCS5Padding** 암호화. 아웃바운드 키=Secrets Manager(`AzCryptoProperties`), 인바운드 복호화 키=**하드코딩 `GaSecretKey`**(`AzDecryptionAndDtoMappingService.java:74-82`) [High].

### 1-4. 에러 체계

- **az-was**: 전역 예외처리기(`@ControllerAdvice`) 없음. 도메인 예외는 `IllegalArgumentException`/`IllegalStateException`(→500) 또는 `ResponseStatusException`. `server.error.include-message/stacktrace=always`로 상세 노출(`application.yml:24-30`).
- **AZ전산(azlife)**: 실패도 HTTP 200, body `code`로 판별(`AzResponse.isSuccess()`=`code=="00"`). 코드표 `91`=NAME `92`=BIRTH `93`=GENDER `94`=PHONE `95`=KEY `98`=복호화실패 `99`=시각초과(`external-az.md:115-126`).

---

## 2. 데이터 항목별 정의서 (필드 / 타입 / 암호화)

### 2-1. 카카오페이 → az-was 수신 필드 (평문)
`ConsultationInfoFindClientResponse`(`:15-29`): `uuid, name, phone_number, birthday, gender, channel_code, channel_name, request_date, expire_date, purposes[{question,answer}], has_support_user_detail, is_mydata_user` — 카카오로부터 **평문** 수신.

### 2-2. az-was 저장 — `KakaoPayMember` (@Table `kakaopay_member`)

| 필드 | 컬럼 | 타입 | 암호화 | 근거 |
|---|---|---|---|---|
| 이름(마스킹) | name_masked | String | 마스킹(홍*동) | `KakaoPayMember.java:26-27` |
| 이름(해시) | name_hash | String | SHA-512 앞30자(검색용) | `:29-30` |
| 이름(암호문) | name_enc | String | **KMS 봉투암호화 BME1(AES/GCM)** | `:32-33` |
| 전화(마스킹/해시/암호문) | tel_mobile_masked/_hash/_enc | String | 마스킹 / SHA-512 / **BME1** | `:39-46` |
| 생년월일 | birth_sun / birth_sang | varchar(8) | **평문** | `BirthDate.java:17-21` |
| 성별 | gender | char(1) F/M | 평문 | `:35-37` |
| userKey | user_key | String | 평문 | `:23-24` |
| 상담 UUID | current_consultation_uuid | String | 평문 | `:57-58` |
| 마이데이터여부 | is_mydata_user | Boolean | 평문 | `:60-61` |

- **주민번호/CI/DI: 컬럼 없음 = 미저장.**
- 이름·전화는 **평문 저장 안 함**(마스킹+해시+BME1 3형태). 조회 시 `MemberPrivateInfoTool.decrypt`로 복호화해 응답.
- `@Convert` 미사용 — 서비스계층 수동 암복호. 동의 만료/철회 시 PII 전부 null 파기(`KakaoPayMember.java:162-194`).
- `KakaoPayAgreementHistory`(@Table `Kakaopay_agreement_history`): PII 없음. `expire_date, withdraw_at, expired_at, consultation_uuid, request_date`.

### 2-3. 보맵 → az-was 회원조회 응답 (HTTP, 복호화 평문)
`MemberNameFindApiResponse`: `memberName, birthDate, telMobile, gender, afterMemberId, consultationUuid`. `MemberListGetApiResponse.members[]`: `memberId, name, nameMasked, phoneNumber, birthDate, gender, isMydataUser, memberAge, insuranceAge` (`MemberController` + DTO).
→ 보맵은 PII를 저장하지 않고 az-was에서 **그때그때 조회**.

### 2-4. (별개) 보맵 → AZ전산 상담 DTO — `AzConsultationApplyRequest` (AES 전송)
`userName, userBirth, gender, phone, userKey, worksUrl, provideDate, dbType(P/KAKAO_PAY), tm, contactType(TEL/CHAT), webViewUrl` — 전 필드 AES(`AzConsultationApplyRequest.java:11-22`). Bean Validation 없음 → 길이/필수 미확인.

### 2-5. 보맵 DB `kakaopay_*` (비PII)
`kakaopay_consultation`(uuid/status/*_at), `kako_kakaopay_member`(userKey↔memberId 매핑), `kakaopay_planner_member`(plannerId/contactType) — **PII 컬럼 없음**, 전부 보맵 JPA가 INSERT(`KakaoPayConsultation.java` 등).

### 2-6. 암호화 인프라 정리

| 구성 | 방식 | 키 출처 | 적용 |
|---|---|---|---|
| az-was `AwsKmsService`(BME1) | **AES/GCM** + KMS 데이터키 봉투암호화 | KMS(env 자격) | az-was 회원 PII(name_enc/tel_mobile_enc) |
| 보맵 `BomappCrypto`(AzCrypto) | AES/CBC/PKCS5 | **Secrets Manager** | 보맵→AZ전산 아웃바운드 |
| 보맵 `GaSecretKey` | AES/CBC/PKCS5 | **하드코딩** [High] | AZ전산→보맵 인바운드 복호화 |

---

## 3. 인증·세션 처리 (PIN/OTP/토큰)

### 3-1. 채널별 인증 요약

| 채널 | 인증 수단 | 비고 |
|---|---|---|
| az-was → 카카오페이 | `Authorization: PARTNER_KEY <키>` | 정적 헤더, 서명 없음 |
| az-was → 보맵(설문콜백) | `x-client-id=az-server` + `x-api-key` | 공유 시크릿 단순 비교 |
| az-was → 보맵(상담②) | ⚠ PARTNER_KEY(오부착) | [Critical] |
| 보맵 → az-was(회원/상담) | **무인증** | `/api/v1/kakaopay-members*`, `/consultations/*` |
| 보맵 ↔ az-was(설문) | Planner/Survey JWT | §3-2 |

### 3-2. az-was JWT — 서명검증 생략 [Critical]
- 3종 시크릿(`JWT_SECRET`/`JWT_SURVEY_SECRET`/`JWT_LEGACY_SECRET`, env). Survey/Planner 토큰 claim `userId/plannerId/surveyCode/companyCode/userName`.
- ⚠ `JwtTokenProvider.validateToken`이 **exp(만료)만 검사하고 HMAC 서명을 검증하지 않음**("백오피스 호환" 주석) → 위조 토큰 통과 [Critical].
- **설문 JWT 브리지**: 보맵 `JwtGenerator`의 AZ-Managed JWT를 az-was가 그대로 소비(서명 미검증).

### 3-3. 보맵 토큰 만료 정책

| 토큰 | PROD access | PROD refresh | 근거 |
|---|---|---|---|
| 일반 JWT(HS512) | 60분 | 30일 | `application-jwt-prod.yml:11-12` |
| 레거시 API JWT | 60분 | 365일 | `:17-18` |
| AZ-Managed JWT(설문) | create 24h/update 30m | 항상 null(access 전용) | `JwtGenerator.java:135` |
| 레거시 마이데이터 관리토큰(RS512) | 1년 고정 | — | `ManagementService.java:84` |

- 세션: Spring Security STATELESS + bomapp-api `member_login_session`(MySQL), `(member_id,client_instance_id)` UNIQUE로 디바이스당 1세션.

### 3-4. PIN / OTP (보맵 회원 로그인 — 참고)
- **PIN**: 해시 저장(`pin_hash`), 5회 실패 시 잠금+삭제(`MemberPin.java:25,89-93`).
- **SMS OTP**: 6자리, Redis 평문 TTL 3분. ⚠ **시도횟수 제한 없음 → brute-force 무방비**(`RedisService.java:28-32`).
- **Google OTP(Padmin)**: ⚠ 단위 버그로 유효시간 의도 30분 → 실제 30초(`GoogleOtpUtil.java:25,91`).

---

## 4. 3자 플로우 (정정본)

```
카카오페이
   │ (에즈 브릿지 웹뷰가 상담 트리거)
   ▼
에즈 az-was (az.bomapp.co.kr)
   │ ① POST /api/v2/consults/{uuid}  → 카카오에서 상담 PII pull (PARTNER_KEY)
   │    → 마스킹+해시+BME1 암호화 저장
   │ ② POST {chat}/external/consultations/kakaopay  → 보맵에 상담 신청 통보
보맵 ◀───────────────────────────────────────────────────┘
   │ ③ GET /api/v1/kakaopay-members*  → 회원 PII 역조회(무인증)
   │ ④ (보맵→AZ전산 azlife) bombappCounselProc → 설계사 배정 등록
   │ ⑤ azlife → 보맵 /external/assign-consultant, /update/status
   │ ⑥ (만료) az-was 1분 polling(카카오 canceled) / 매일 02:00 cron → 보맵 PUT 통보
   │ ⑦ (설문) az-was 상태변경 → 보맵 /external/additional-info/status-changes
```

1. 에즈 브릿지 웹뷰 → az-was `POST /consultations/kakaopay {consultationUuid}` (무인증)
2. az-was → 카카오 `POST /api/v2/consults/{uuid}` → 고객 PII 수신 → 암호화 저장
3. az-was → 보맵 `POST /external/consultations/kakaopay` 신청 통보
4. 보맵 → az-was `GET /api/v1/kakaopay-members*` 회원 PII 역조회
5. (배정) 보맵 → AZ전산(azlife) 상담 등록 → azlife → 보맵 배정/상태 통보
6. (만료/취소) az-was polling/cron → 보맵 `PUT` 통보
7. (철회) 보맵 → az-was `DELETE /consultations/{uuid}` → PII 삭제

---

## 5. 공유-DB 결론 & 리스크

### 5-1. 공유-DB 결론 — 앱 코드는 100% HTTP

- **az-was**: datasource 단 1개 = 자기 AZ DB. 보맵 DB로의 2nd datasource·스키마·catalog **전무**(`application.yml:11-15`).
- **next-backend**: AZ DB datasource·AZ 테이블·`az_db` 스키마 **0건**. master/slave 복제뿐.
- **`CustomerTableStatementInspector`**: 크로스-DB가 **아니라** `Customer-Type` 헤더(기본 BOMAPP / KAKAOPAY)에 따라 **같은 AZ DB 내에서** `user_response → kakaopay_user_response` 식 **테이블명만 치환**하는 단일-DB 멀티테넌시(`CustomerTableStatementInspector.java:15-26`).

> **결론**: 보맵↔az-was 교환은 앱 코드 기준 **전부 HTTP(Feign)**. 운영상 "DB 가운데 두고 교환"은 앱 코드가 아니라 **인프라 레벨**(에즈 DB·보맵 DB가 같은 VPC에 공존)에서 일어난다. 별도 인프라 점검에서 **열린 크로스-DB 방향은 `az-was → 보맵 DB`(write) 하나로 확인**(역방향=보맵 앱→에즈 DB는 차단)되었고, az-was를 보맵 DB에서 분리하기 위한 **전용 에즈 DB 이전이 진행 중**인 정황이 있다. 현재 시점 실태(공유 지속 vs 이전 완료)는 az-was 런타임 datasource 확인(SSM/DBA) 필요. *구체적 인프라 식별자(AWS 계정·호스트 IP·SG)는 보안상 본 문서에서 생략.*

### 5-2. 보안 리스크

| 심각도 | 이슈 | 근거 |
|---|---|---|
| Critical | `PlannerFeignClient`가 카카오용 PARTNER_KEY를 보맵 호출에 오부착 | `PlannerFeignClient.java:15` |
| Critical | az-was JWT 서명검증 생략(exp만 검사) | `JwtTokenProvider.validateToken` |
| High | `/api/v1/kakaopay-members*`(평문 PII)·`/consultations/*` 무인증 | `MemberController.java`, `JwtAuthenticationInterceptor.java:52-69` |
| High | Feign Logger.Level.FULL → PII·PARTNER_KEY·x-api-key 평문 로깅 | `KakaoPayFeignConfig.java:25` |
| High | AZ전산 인바운드 복호화 AES 키 하드코딩(GaSecretKey) | `AzDecryptionAndDtoMappingService.java:74-82` |
| High | SMS OTP brute-force 무방비 | `RedisService.java:28-32` |
| Medium | CORS `*`+allowCredentials, prod swagger/stacktrace 노출, KakaoPayKmsDecryptor dead code | `WebConfig.java:27-40`, `application.yml:24-30` |
| Low | insert_all.sh dev DB 평문 비번, 전역 예외처리기 부재 | — |

### 5-3. 미확인
1. **공유-DB 실재/방향**: 앱 코드엔 없음 → 인프라/DBA(Aurora 공유+GRANT) 런타임 확인 필요.
2. **카카오페이→az-was 인바운드**: 카카오 push 없음(pull). `/consultations/kakaopay` 호출자=에즈 브릿지 웹뷰(본 범위 외).
3. **azlife.kr 내부 규약**: 소스 미보유, 보맵 측 계약만 관측.

---

*근거 리포: `next-backend`(보맵), `az-was`(GitLab 정본), `infra`. 모든 인용은 해당 리포 소스 기준.*
