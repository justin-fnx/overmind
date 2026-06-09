# 카카오페이 ↔ 보맵 ↔ 에즈(AZ) 연동 명세 및 WebView 연동 방식

> 🛑 **초판(2026-06-01, 보맵 측 코드만 분석).** 이후 GitLab az-was 정본 분석으로 일부 흐름 방향·az-was 역할 서술이 정정됨.
> 최신·정본: [`kakaopay-az-bomapp-flow.md`](./kakaopay-az-bomapp-flow.md), [`services/az-was.md`](./services/az-was.md).
> 핵심 정정: 상담 흐름은 **카카오페이 → 에즈(az-was) → 보맵**(az-was 가 허브). "azlife.kr 이 상담 허브"라는 한때의 추론은 폐기됨. WebView 절은 본 초판에만 있다.

> 외부 보안/컴플라이언스 질문지에 대한 답변서. `next-backend`(Spring Boot 3.4), `next-frontend`(Vue 3), 보조로 `infra`(Terraform)·`mydata-mgmts-api`(레거시)를 코드 레벨로 분석하여 작성했다.
> 모든 사실 주장은 실제 소스 파일을 읽어 검증했으며 `파일경로:라인` 형태로 근거를 표기한다. 코드에서 확인되지 않은 항목은 "미확인"으로 명시한다.
>
> ⚠️ **용어/구도 정정 (필수 선이해)**
> - **"에즈" = AZ = 에즈금융서비스**(보험 GA·설계사 조직). 코드 전반에서 `AZ`로 표기된다.
> - 질문지 전제와 달리 **카카오페이↔보맵 직접 API 호출은 거의 없다.** 데이터는 ① 보맵→`az-was`(`az.bomapp.co.kr`)로 카카오페이 회원정보 조회, ② 보맵↔AZ전산(`cs.azlife.kr`/`az.azlife.kr`)로 상담 송수신, ③ 보맵이 카카오페이 보장분석 리포트 **URL을 생성만** 하여 AZ에 전달 — 세 경로로 흐른다.
>
> 작성일: 2026-06-01

---

## 0. 통신 구도 한눈에

| 구간 | 모듈 | PROD 대상 | 통신/인증 실체 |
|---|---|---|---|
| 보맵 → AZ전산 (상담 신청/취소/채널변경) | `bomapp-external/az` | `https://cs.azlife.kr` | Feign POST, **요청 필드 AES 암호화** (키=Secrets Manager) |
| AZ전산 → 보맵 (조직/권한/설계사 동기화) | `bomapp-external/az` (V2) | `https://az.azlife.kr` | Feign GET, **응답 AES 복호화** (키=소스 하드코딩 ⚠) |
| 보맵 ↔ az-was (카카오페이 회원/설문 조회) | `bomapp-external/az-managed` | `https://az.bomapp.co.kr` | Feign GET/POST, **JSON 평문 PII** |
| az-was/AZ → 보맵 (상담 콜백/배정) | chat-api·wings-api `/external/**` | 보맵 ALB | **무인증 또는 공유키 헤더 / AES payload** |
| 보맵 → 카카오페이 | (URL 생성만) | `insurance-partners.kakaopay.com/insurance-analysis` | HTTP 호출 없음, webView URL 문자열 생성 |

> 핵심: 카카오페이 회원 PII는 보맵→az-was 경유 조회, 상담 신청/배정은 보맵↔AZ전산·az-was↔보맵 역호출로 처리. 보맵→카카오페이는 보장분석 리포트 **URL 문자열 생성**만 한다(`KakaoPayInsuranceReportUrlMaker.java:20-26`).

---

# 1) API 연동 명세서

## 1-1. 송수신 API 스펙 (엔드포인트 / 인증 / 요청·응답 / 에러코드)

### ① 엔드포인트

**az-was/AZ → 보맵 (inbound, 보맵이 노출)**

| 앱 | 메서드·경로 | 핸들러 | 근거 |
|---|---|---|---|
| chat-api | `POST /external/consultations/kakaopay` (상담신청) | `PlannerAzController.applyConsultation` | `PlannerAzController.java:25-26` |
| chat-api | `PUT /external/consultations/kakaopay` (3자동의 만료/취소) | `expireConsultation` | `PlannerAzController.java:38-39` |
| chat-api | `POST /external/additional-info/status-changes` (설문 콜백) | `AdditionalInfoNotificationController` | `AdditionalInfoNotificationController.java:22-26` |
| wings-api | `POST /external/assign-consultant` (에즈 상담사 배정) | `ConsultationExternalController.assignConsultant` | `ConsultationExternalController.java:102-103` |
| wings-api | `POST /external/consultation/update/status` (상태 변경) | `updateStatus` | `ConsultationExternalController.java:59-60` |

**보맵 → AZ전산 (outbound, base `${az.url}`)** — `AzExternalClient.java:7-24`
- `POST /api/service/bomappCounselProc` (상담 등록)
- `POST /api/service/bomappCounselModifingProc` (취소 + 채널변경 공용, `statusType`으로 분기)
- V2 (base `${az.url-v2}`): `POST /api/service/bomapp/month_report`, `GET /api/service/bomapp/group|/type|/user` (조직/권한/설계사) — `AzExternalClientV2.java:17-35`

**보맵 → az-was (base `${az-managed.service.url}` = `https://az.bomapp.co.kr`)** — `AzManagedInterface.java`
- `GET /api/v1/kakaopay-members` (회원조회 + userKey 갱신) `:111-117`
- `POST /api/v1/kakaopay-members/list` (memberIds 리스트 조회) `:131-134`
- `GET /api/v1/kakaopay-members/list/name?name=` `:160-163`, `/list/phone?phoneNumber=` `:169-172`
- `GET /api/v1/kakaopay-members/consultations/{consultationUuid}` `:140-144`, `/members/{userKey}` `:150-154`
- `GET/POST /api/v1/planners/surveys...` (설문 토큰/상태) `:22-94`

**보맵 → 카카오페이** — 직접 HTTP 호출 없음. `KakaoPayInsuranceReportUrlMaker.java:20-26`가
`https://insurance-partners.kakaopay.com/insurance-analysis/{consultationUuid}?client_id={client_id}` 문자열만 생성 → AZ 상담요청의 `webViewUrl` 필드로 전달(`ConsultationApplyAzPortRequest.java:73`).

### ② 인증 방식 — 표준 토큰/HMAC이 아니라 **"공유 AES 키 payload 암복호화"가 지배적**

| 구간 | 인증 실체 | 근거 |
|---|---|---|
| 보맵→AZ전산 (outbound) | 요청 DTO 전 필드 `AES/CBC/PKCS5Padding`+Base64. 키/IV = **AWS Secrets Manager `bomapp/{env}/external-az`** | `AzCryptoProperties.java:7-13`, `application-external-az-prod.yml:3-10`, `AzExternalService.java:23` |
| AZ전산→보맵 (inbound 복호화) | `GaSecretKey`의 **하드코딩 키**로 응답 복호화 | `AzDecryptionAndDtoMappingService.java:74-82,17,77` |
| az-was→보맵 배정/상태 (`/external/assign-consultant`, `/update/status`) | Spring Security `permitAll()` (무인증). payload 필드만 AES 복호화 | `WingsAuthorizeRequests.java:44-45`, `ConsultationAssignConsultantUpdateRequest.java:62-64` |
| 설문 콜백 (`/external/additional-info`) | 헤더 `x-client-id`+`x-api-key` 공유 시크릿 단순 비교(`Objects.equals`) | `AdditionalInfoNotificationController.java:25-26`, `AdditionalInfoClientValidator.java:11-20` |
| 보맵→az-was survey | `Authorization` 헤더 plannerToken passthrough + `Customer-Type` 헤더 | `AzManagedInterface.java:25,36`, `AzManagedFeignClientConfig.java:37-45` |
| 보맵→az-was kakaopay-members | 인증 없이 path/query 호출 | `AzManagedInterface.java:111-172` |

> ⚠️ **[High] 동일 AES 키/IV가 소스에 하드코딩** — `mAvxjfTJVUAOYVyqPSAYZt9Eyz9zbyqK` / IV `kIPe81iCEukbMRfW` 가 `AZSecretKey.java:9-10`, `AzSecretKey.java:10-11`, `GaSecretKey.java:11-12`, 게다가 `BomappCrypto.java:64-73` 주석에까지 평문 노출. outbound만 Secrets Manager로 분리되고 inbound는 하드코딩이라 일관성도 결여.

### ③ 요청 / 응답 필드 (핵심 DTO)

- **보맵→AZ 상담신청** `AzConsultationApplyRequest.java:11-22` — `userName, userBirth, gender(M/F), phone, userKey, worksUrl, provideDate(신청+30일), dbType(P/KAKAO_PAY), tm(yyyy-MM-dd HH:mm:ss), contactType(TEL/CHAT), openClientName(카카오페이는 null), webViewUrl` (전 필드 AES)
- **보맵→AZ 취소/채널변경** `AzConsultationCancelRequest.java:11-16` — `userKey, dbType, statusType(C/TEL/CHAT), tm`
- **az-was→보맵 회원조회 응답** `KakaoPayMemberFindClientResponse.java:5-10` — `memberName, birthDate, telMobile, gender, afterMemberId(Long), consultationUuid`
- **az-was→보맵 리스트 응답** `KakaoPayMemberListGetResponse.java:16-24` — `memberId, name, nameMasked, phoneNumber, birthDate, gender, isMydataUser, memberAge, insuranceAge`
- **az-was→보맵 상담 inbound** `PlannerConsultationApplyApiRequest.java:9-14` — `consultationUuid, memberId(Long), memberName, requestDate(LocalDate)`
- **에즈→보맵 배정 inbound (AES 암호문)** `ConsultationAssignConsultantUpdateRequest.java:21-41` — `userKey, dbType, procType(ASSIGN/REASSIGN/CANCEL/REASSIGN_CHAT), managerKey(에즈 사번)`

### ④ 에러 코드

- AZ전산은 **실패도 HTTP 200**, body `code`로 구분. `AzResponse{code("code"), message("err")}` + `isSuccess()` = `code=="00"` (`AzResponse.java:9-11,18,26-28`).
- 코드표 (`bomapp-external/az/.../docs/external-az.md:115-126`): `80`=DBTYPE, `91`=NAME, `92`=BIRTH, `93`=GENDER, `94`=PHONE, `95`=KEY, `96`=URL, `97`=DATE, `98`=복호화 실패, `99`=요청시각 1분 초과. (대부분 복호화/검증 실패 계열)
- 현재 동작: 실패 시 throw 안 하고 `log.warn`만 (`AzExternalService.warnIfFailed:84-88`). 후속 PR에서 `AzException` 전환 예정.
- 예외 체계: `AzException(code,msg)` `AzException.java:10-18`, `AzErrorDecoder`(4xx/5xx 파싱) `:22-44`, `AzManagedErrorDecoder`(400/404→`ResponseStatusException`) `:14-38`.
- inbound 가드: `updateStatus`에 `dbType=KAKAO_PAY` 유입 시 `UnsupportedOperationException` (`ConsultationExternalController.java:84-87`).

---

## 1-2. 데이터 항목별 정의서 (필드 / 타입 / 길이 / 필수 / 암호화)

> **핵심 결론**
> 1. 카카오페이 고객 PII(이름·전화·생년월일)는 **보맵 DB에 저장되지 않는다.** az-was에서 매번 조회만 하고, 보맵 테이블엔 ID/UUID/상태만 영속한다.
> 2. **주민번호(SSN/RRN)·CI·DI는 이 데이터 체인에 존재하지 않는다**(kakaopay/az/az-managed 모듈 grep 0건).
> 3. 앱 레벨 암호화 구간은 **보맵↔AZ전산 2개뿐**이고, 보맵↔az-was 구간은 **평문 PII**다.

### 보맵 → AZ전산 아웃바운드 (`AzConsultationApplyRequest`) — 전송 직전 AES, Bean Validation 없음

| 필드 | 타입 | 길이/제약 | 필수 | 암호화 | 근거 |
|---|---|---|---|---|---|
| userName | String | 미지정 | 검증없음 | **AES** | `AzConsultationApplyRequest.java:11,25` |
| userBirth | String | 미지정 | 검증없음 | **AES** | `:12,26` |
| gender | String | M/F | 검증없음 | **AES** | `:13,27` |
| phone | String | 미지정 | 검증없음 | **AES** | `:14,28` |
| userKey(=kakaoPayMemberId) | String | 미지정 | 검증없음 | **AES** | `:15,29` |
| worksUrl | String | 미지정(현재 dummy) | 검증없음 | **AES** | `:16,30` |
| provideDate | String | yyyy-MM-dd(신청+30일) | 검증없음 | **AES** | `:17,31` |
| dbType | String | P / KAKAO_PAY | 검증없음 | **AES** | `:18,32` |
| tm | String | yyyy-MM-dd HH:mm:ss | 검증없음 | **AES** | `:19,33` |
| contactType | String | TEL/CHAT | 검증없음 | **AES** | `:20,34` |
| webViewUrl | String | 미지정 | 검증없음 | **AES** | `:22,36` |

> 호출 측에서 평문으로 빌더에 주입 후 전송 직전에만 AES 적용(`AzExternalService.java:23`) → 메모리/스택/로그상 평문 구간 존재. DTO에 `@NotNull/@Size/@Column` 없음 → 길이/필수는 코드상 미확인(AZ 규격서는 사내 외부 문서).

### 보맵 ↔ az-was (`az-managed`) — 앱 레벨 암호화 없음, **평문 PII**

| 필드 | 타입 | 암호화 | 근거 |
|---|---|---|---|
| memberName / name | String | **평문** | `KakaoPayMemberFindClientResponse.java:5`, `KakaoPayMemberListGetResponse.java:17` |
| telMobile / phoneNumber | String | **평문** | `:7`, `:19` |
| birthDate | String | **평문** | `:6`, `:20` |
| gender | String | **평문** | `:8`, `:21` |
| 이름·전화 조회 파라미터 | RequestParam | **평문(쿼리스트링)** | `AzManagedInterface.java:160-172` |

### 보맵 내부 영속(JPA) — PII 컬럼 없음

| 테이블 | 저장 컬럼 | 길이/제약 | PII | 근거 |
|---|---|---|---|---|
| `kakaopay_consultation` | consultationUuid, status, *_at | uuid varchar(255) UNIQUE | 없음 | `KakaoPayConsultation.java:25-73` / `db-schema.sql:3123-3145` |
| `kakaopay_planner_member` | kakaoPayMemberId, plannerId, contactType, isBookmark | — | 없음 | `KakaoPayPlannerMember.java:25-42` / `db-schema.sql:3109-3120` |
| `kako_kakaopay_member` | kakaoUserKey, kakaopayMemberId | varchar(255) NOT NULL | 식별키만(평문) | `KakaoPayUserKey.java:18-22` |
| `kakaopay_chat_message` | message(text), serialNumber | text NULL | 채팅 자유서식(평문) | `KakaoPayChatMessage.java:37-44` |
| `kakaopay_chat_memo` | content | varchar(500) NOT NULL | 자유서식(평문) | `KakaoPayChatMemo.java:14-28` |

### 암호화 인프라

| 구성요소 | 방식 | 키 출처 | 적용 | 근거 |
|---|---|---|---|---|
| `BomappCrypto.aesEncryption/Decryption` | AES/CBC/PKCS5Padding + Base64 | 호출자 주입 | 저수준 공통 함수 | `BomappCrypto.java:40-93` |
| `AzCryptoProperties` | 위 함수 래핑 | **AWS Secrets Manager** `bomapp/{env}/external-az` | 보맵→AZ 아웃바운드 | `AzCryptoProperties.java:14-21` |
| `AzDecryptionAndDtoMappingService` | `BomappCrypto.aesDecryption` | **하드코딩** `GaSecretKey` | AZ→보맵 인바운드 복호화 | `AzDecryptionAndDtoMappingService.java:74-82` |
| Feign `Logger.Level.FULL` | 본문 전체 로깅 | — | az / az-managed | `AzManagedFeignClientConfig.java:16`, `AzFeignClientConfig.java:16` |

> [Medium] AES-CBC + 고정 IV + 인증태그(GCM) 부재 → 동일 평문→동일 암호문, 변조 탐지 불가(`BomappCrypto.java:40-57`).

---

## 1-3. 인증·세션 처리 플로우 (PIN/OTP / 토큰 만료)

### PIN (간편비밀번호) — **해시 저장**

- 회원: `passwordEncoder.encode(pin)` → `pin_hash` 저장(`MemberPinService.java:54`, `MemberPin.java:31`). 숫자 검증(`:148-152`). **5회 실패 시 잠금 + pinHash 삭제**(`MemberPin.java:25,89-93`), 성공 시 실패카운트 리셋(`:78-81`).
- 설계사: 6자리 + 동일숫자 3연속 금지 정규식(`Pin.java:14,39-58`). 5회 실패 시 `resetPin()`(`AuthService.java:86-92`).

### OTP

- **SMS 인증번호**: 6자리 난수, **Redis 평문, TTL 3분**(`RedisService.java:18-26`, `LIMIT_TIME=180`). 검증 실패 시 `AuthNumberNotMatchException`(`:28-32`). ⚠️ **[High] 시도횟수 제한·재발급 제한 없음** → brute-force 무방비.
- **Google OTP(Padmin)**: ⚠️ 단위 버그 — `plusSeconds(OTP_VALID_MINUTES=30)`로 의도(30분)와 달리 **실제 30초** 적용(`GoogleOtpUtil.java:25,91`). 스킵 플래그 하드코딩 `false`(`AuthMngService.java:22-26`).

### 토큰(JWT) 만료 정책 — 구체값

| 토큰 | 알고리즘 | PROD access | PROD refresh | 근거 |
|---|---|---|---|---|
| 일반 JWT(`auth.jwt`) | HS512 | **60분** | **30일**(43200분) | `application-jwt-prod.yml:11-12` |
| 레거시 API JWT | HS256 식별 | 60분 | **365일** | `application-jwt-prod.yml:17-18` |
| **AZ-Managed JWT**(카카오페이/에즈 설문) | HS512 | create 1440분(24h)/update 30분 | **항상 null(access 전용)** | `application-jwt-prod.yml:25-29`, `JwtGenerator.java:135,206` |
| 마이데이터 기관 OAuth | (기관 표준) | 기관 expiresIn 기반(파싱 실패 시 90일) | — | `MyDataMemberToken.java:92-99` |
| 레거시 `mydata-mgmts-api` 관리토큰 | RS512 | **1년 고정** | — | `ManagementService.java:84` |

- 시크릿: `aws-secretsmanager:bomapp/{env}/jwt`(`application-jwt-prod.yml:3`). 채널별 3개 시크릿 분리(`JwtSecretProperties` / `JwtLegacyAPISecretProperties` / `JwtSecretAzManagedProperties`).
- 세션: Spring Security STATELESS(`SecurityConfig.java:55-56`) + bomapp-api는 `member_login_session`(MySQL) 영속 세션. `(member_id, client_instance_id)` UNIQUE → 디바이스당 1세션, 재로그인 시 sessionKey 교체로 직전 토큰 무효화(`MemberLoginSession.java:27-28,93-104`). 명시적 블랙리스트 없음.
- 로그아웃: `POST /api/member/v1/logout` → 세션행 삭제(`MemberLoginSessionService.java:98-108`).
- ⚠️ **[High] 레거시 마이데이터 토큰 검증 우회** — Authorization 헤더 부재 시 검증 스킵(`ManagementTokenValidationAspect.java:33-36`).

---

# 2) WebView 연동 방식 상세

> **중요**: 보맵은 보장분석 결과 WebView를 **자기 앱 안에서 띄우지 않는다.**
> - ⓐ 카카오페이용 리포트 URL은 보맵이 **생성→AZ에 전달**하고 `insurance-partners.kakaopay.com`이 호스팅한다.
> - ⓑ 보맵 앱 자체 보장분석은 WebView가 아니라 **네이티브 Vue 컴포넌트 렌더링**이다.
> - ⓒ WebView인 것은 open-web의 **제3자 제공동의 화면**(`/:vendorId/consent`)뿐이다.

## 2-1. 보장분석 WebView 호출 규격

### 호출 URL

- **카카오페이 리포트**: `https://insurance-partners.kakaopay.com/insurance-analysis/{consultationUuid}?client_id={client_id}` (`KakaoPayInsuranceReportUrlMaker.java:20-26`, base-url `application-domain-rds-prod.yml:101-104`). 설계사 앱은 이를 **외부 브라우저**로 연다(`ChatMemberInfo.vue:44-49` → `native.openByWebBrowser` `native.ts:206-213`).
- **open-web 동의 WebView**: `/:vendorId/consent` (`open-web/src/router.ts:62-66`), 제공받는 자="에즈금융서비스"(`consent/index.vue:37`).
- 보맵 자체 보장분석 결과를 WebView URL로 띄우는 경로: **없음/미확인**(네이티브 컴포넌트로 렌더, `planner-mobile/router.ts:165`, `planner-desktop/router.ts:80`).

### 파라미터

| WebView | 위치 | 파라미터 | 의미 | 근거 |
|---|---|---|---|---|
| 카카오페이 리포트 | path | `consultationUuid` | 카카오페이 상담 UUID(보맵 DB 저장) | `KakaoPayInsuranceReportUrlMaker.java:20-26` |
| 카카오페이 리포트 | query | `client_id` | 카카오페이 파트너 client id(`@Value("${kakaopay.client-id}")`, Secrets Manager) | `:14`, `application-domain-rds-prod.yml:102` |
| open-web consent | path/query | `vendorId`, `uid`, `transaction_no` | 제휴사 식별/거래번호 | `consent/index.vue:86,93-106` |

### 세션 전달 방식

- 카카오페이 리포트 WebView: **보맵은 토큰을 싣지 않는다.** URL에 `consultationUuid`+`client_id`만. 인증은 카카오페이/AZ 도메인 책임(보맵 범위 밖). 설계사 앱도 토큰 주입 없이 외부 브라우저로 전달.
- AZ-Managed JWT(claim `userId/userName/plannerId/surveyCode/companyCode`)는 보장분석 진입용이 아니라 **설문(카드/계좌/알릴의무) 저장 API용 Authorization 토큰**(`JwtGenerator.java:128-262`, `AzManagedInterface.saveAzManagedToken:33-37`).
- 네이티브 브리지(`native.ts:19-39`)에 **보장분석용 토큰 주입 코드 없음**(외부링크/PIN 생체/공유 용도로 한정).

```
[카카오페이 리포트]
 보맵 백엔드: consultationUuid → KakaoPayInsuranceReportUrlMaker → insurance-analysis URL 생성
   → AzPortRequest.webViewUrl 로 AZ 전송 (AZ가 자기 WebView로 로드, 인증은 카카오페이/AZ 책임)
   → 동시에 externalInsuranceLink 로 설계사 앱에 노출 → native.openByWebBrowser() 외부 브라우저 (토큰 없음)
```

### 보장분석 데이터 API (WebView가 아닌 제휴 백엔드 API)

- `POST /v4/guarantees` (`GuaranteeController.java:37-54`) — 인증 `@AuthenticationOpenClientId` + `openAuthService.checkClientMember`(`:45`). 요청 `GuaranteeApiRequest`(transaction_no, uid, birth, name, gender, mobile_number, insurance_list[], insured_list[]).
- `POST /api/external/v1/insurance/guarantee-analysis` (`OpenV3Controller.java:63-95`) — 인증 `@OpenV3TokenRequired` AOP(클레임 `CLIENT_PK/CLIENT_ID`, `OpenV3TokenRequiredAspect.java:33-66`).

## 2-2. IP 화이트리스트 적용 대상 및 운영 방식

### 애플리케이션 레벨 — **차단용 allowlist 없음**

- IP 관련 코드는 전부 (a) 카나리 라우팅(`OfficeCanaryRequestInterceptor.java:57-71` — `X-Canary` 헤더 추가만), (b) 로깅(`FindRequestIPAspect.java:46-65`)용. **요청 거부 로직 없음.**
- 외부 연동 `/external/consultations/kakaopay`(chat-api), wings `/external/consultation/update/status`·`/external/assign-consultant`는 **`permitAll()` 무인증**(`ChatApiAuthorizeRequests.java:56`, `WingsAuthorizeRequests.java:44-45`).

### 인프라 레벨 (infra/terraform)

- **WAF/IPSet: 없음**(`wafv2`/`ip_set`/`web_acl` grep 0건).
- **DEV ALB**: 파트너별 강한 allowlist — AZ(`pl-0162db740163bace5`), infobank `211.233.70.226/32`, SK/ShinhanCard(`10.129.81.131/32`)/KB prefix-list, dev-az-was `3.36.29.62/32` (`security_groups.tf:643-751`).
- ⚠️ **[High] PROD ALB: 443/80 ingress = `0.0.0.0/0` 전체 공개**(`security_groups.tf:903-943`). → PROD의 무인증 외부 연동 엔드포인트가 인터넷 전체에서 도달 가능.
- PROD-BACK 호스트 SG에는 AZ/HQ prefix allowlist 존재(`security_groups.tf:227-261`)하나 prod-alb 경로와 별개.
- ALB 리스너 `source_ip` 조건은 2건뿐이며 모두 카나리 분기용(사무실 `14.52.60.172/32`, `listener_rules.tf:606-609,1033-1036`) — 차단 아님.

### 운영 방식

- 파트너 IP는 **AWS Managed Prefix List**(`pl-...`)로 관리(예: `pl-0162db740163bace5`=AZ가 dev_alb·prod_back_ecs_host 양쪽 참조), prefix list 갱신으로 일괄 반영. prefix list 정의 자체는 TF에 없어 콘솔/별도 관리 추정.
- 공유 시크릿(`az.client-id`/`az.api-key`, `kakaopay.client-id`)은 yml 빈 값 + 런타임 Secrets Manager/env 주입(`application-domain-rds-prod.yml:97-104`). 단 env 누락 시 `Objects.equals(null, header)`로 검증이 무력화될 위험.

## 2-3. WebView 데이터 비저장 정책 — 확인 가능 근거

### 프론트 비저장 근거

- bomapp-web 보장분석: **persist 미사용**, 매 진입 시 API fresh fetch(`AnalyzePageV2.vue:643,676`). 저장 매체는 전부 **sessionStorage**(탭/웹뷰 종료 시 자동 폐기) — raw PII 미저장.
  - 단, `guaranteeRankingData`(보장 카테고리/순위 요약)는 sessionStorage에 일시 저장(`useGuaranteeRankingStore.ts:13`) → "완전 비저장"은 아님(세션 내 보관, 종료 시 폐기).
- open-web consent: sessionStorage에 `uid`/`transaction_no`(PII 아님)만(`consent/index.vue:97-106`). localStorage/IndexedDB/쿠키 미사용.
- ⚠️ **[Medium]** planner-mobile은 고객 이름을 **localStorage 영속 저장**(`GeneralInsurance1st.vue:60`, `DentalInsurance1st.vue:68` 등) — 설계사 단말 한정 예외(고객 보장분석 WebView 아님).
- 캐시방지: 리포트 다운로드 응답 `CacheControl.noCache()`(`ReportDownloadController.java:95`). 보장분석 페이지에 `no-store` 헤더는 미발견.

### 백엔드 로그 정책 — 비노출 핵심 근거

- 모든 외부 Feign이 `Logger.Level.FULL`이나, **PROD/STG logback이 `feign.slf4j.Slf4jLogger`·`kr.co.bomapp.external`을 INFO로 강제 다운그레이드** → **PROD에서 AZ/카카오페이 연동 바디(PII) 로깅이 차단됨**(`mydata-api/logback-spring.xml:241-255`; chat-api/wings-api/open-api/bomapp-api 동일 패턴). **"WebView 데이터 비저장/로그 비노출"의 가장 강력한 근거.**
  - 단 DEV/local은 DEBUG(`mydata-api/logback-spring.xml:199-203`) → dev 환경에서는 외부 연동 바디 평문 로깅 [Medium].
- 마스킹 유틸 존재(`DataMaskingUtils.java:12-24` 휴대폰/토큰 마스킹)하나 자동 적용(logback converter) 아님.
- ⚠️ **[High] `x-api-key`(공유 시크릿) 평문 INFO 로깅** — `AdditionalInfoNotificationController.java:29-30`, `AdditionalInfoNotificationService.java:42`. 이 logger는 prod INFO 출력 대상이라 ES `logs-prod-chat-api`에 인증키가 평문 적재됨.

### 로그 보관/수집

- Fluent Bit DAEMON → fluentd 드라이버(tag) → 앱별 ES 인덱스 `logs-{env}-{app}`(`infra/terraform/ecs_log_daemon.tf:67-196`). ES API 키는 Secrets Manager(`shared/firelens/es-api-key-header`, `:329-330`).
- PROD에서는 위 logback INFO 강제로 외부 연동 바디(PII)가 ES에 남지 않으나, 위 [High] 이슈로 `chat-api` 인덱스에는 `x-api-key`/상담 식별자가 적재됨.

---

## 3. 명세서 제출 전 검토 권고 — 부수 발견 보안 이슈

조사 중 발견된 항목으로, 외부 제출 전 내부 검토/시정을 권한다.

| 심각도 | 이슈 | 위치 |
|---|---|---|
| High | AES 키/IV 소스 하드코딩(inbound) | `GaSecretKey.java:11-12`, `AzSecretKey.java:10-11`, `BomappCrypto.java:64-73` |
| High | PROD ALB `0.0.0.0/0` + 무인증 `/external/**` 엔드포인트 | `security_groups.tf:903-943`, `WingsAuthorizeRequests.java:44-45` |
| High | `x-api-key` 평문 로깅(PROD→ES 적재) | `AdditionalInfoNotificationController.java:29-30`, `AdditionalInfoNotificationService.java:42` |
| High | SMS OTP brute-force 무방비(시도제한 없음) | `RedisService.java:28-32` |
| High | 레거시 마이데이터 토큰 검증 우회 | `ManagementTokenValidationAspect.java:33-36` |
| Medium | az-managed 평문 PII(이름/전화) 쿼리스트링 전송 + dev FULL 로깅 | `AzManagedInterface.java:160-172` |
| Medium | Google OTP 유효시간 단위 버그(30분→30초) | `GoogleOtpUtil.java:25,91` |
| Medium | planner-mobile 고객 이름 localStorage 영속 저장 | `GeneralInsurance1st.vue:60` 등 |

---

## 4. 미확인 항목 (지어내지 않음)

- 아웃바운드 AZ DTO·az-managed DTO의 **필드 길이·필수 제약**: Bean Validation·DB 제약이 없어 코드상 미확인(AZ 규격서는 사내 별도 문서, 리포 외부).
- 카카오페이 `insurance-analysis` 도메인 **내부 인증 방식**: 카카오페이/AZ 책임, 보맵 코드 범위 밖.
- planner 앱 **보장분석 상세 조회 전용 API 경로**: 미특정.
- `az-managed.service.url`의 실제 호스트/프로토콜(HTTPS 여부): 외부 시크릿/환경설정 영역으로 미확인.

---

## 부록. 근거 파일 경로 (절대경로)

- `next-backend/bomapp-domain/rds/src/main/java/kr/co/bomapp/domain/rds/kakaopay/report/KakaoPayInsuranceReportUrlMaker.java`
- `next-backend/bomapp-domain/rds/src/main/resources/application-domain-rds-prod.yml`
- `next-backend/bomapp-external/az/src/main/java/kr/co/bomapp/external/az/` (AzExternalClient·AzExternalService·AzConsultation*Request·AzResponse·AzException·docs/external-az.md)
- `next-backend/bomapp-external/az-managed/src/main/java/kr/co/bomapp/external/managed/` (AzManagedInterface·dto/·service/KakaoPayMemberFind*Response)
- `next-backend/bomapp-domain/rds/src/main/java/kr/co/bomapp/domain/rds/external/az/decrytion/` (AzDecryptionAndDtoMappingService·dto)
- `next-backend/bomapp-internal/jwt/src/main/java/kr/co/bomapp/internal/jwt/JwtGenerator.java`, `bomapp-internal/jwt/src/main/resources/application-jwt-prod.yml`
- `next-backend/bomapp-server/{chat-api,wings-api,open-api}/.../controller/` (PlannerAzController·ConsultationExternalController·AdditionalInfoNotificationController·GuaranteeController·OpenV3Controller)
- `next-frontend/open-web/src/router.ts`, `src/pages/consent/index.vue`
- `next-frontend/planner-mobile/src/tools/native.ts`, `src/global.d.ts`, `src/components/chat/member/ChatMemberInfo.vue`
- `next-frontend/bomapp-web/src/.../AnalyzePageV2.vue`, `useGuaranteeRankingStore.ts`
- `infra/terraform/security_groups.tf`, `listener_rules.tf`, `ecs_log_daemon.tf`
