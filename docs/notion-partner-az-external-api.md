# 제휴업체 ↔ 에즈 ↔ 보맵 API 연동 명세 (외부 공유용)

> 제휴업체 보험상담 연동의 시스템 간 API 계약을 **호출 방향별**로 정리한 문서.
> 범위: 엔드포인트 목록 · 요청/응답 필드(타입·길이·보호 방식) · 통신 보안 모델 · 토큰 만료 정책.
> 전 구간 HTTPS(TLS) 적용. 표의 "보호" 열은 해당 필드의 저장/표현 형태를 의미한다.
> 작성일: 2026-06-08

---

## 1. 통신 보안 모델

세 시스템은 성격이 다른 두 구간으로 연결된다.

| 구간 | 망 노출 | 인증 방식 | 전송 |
|---|---|---|---|
| 제휴업체 ↔ 에즈 | 공인 인터넷 | `PARTNER_KEY` (파트너 인증 키) | TLS |
| 에즈 ↔ 보맵 | **내부 폐쇄망(사설 VPC)** | 망 분리(대부분 무인증) · 설문 콜백만 공유키 | TLS |

- **제휴업체 ↔ 에즈** — 공인 인터넷 구간. 모든 요청은 제휴업체가 발급한 `PARTNER_KEY` 헤더로 인증하고 TLS로 암호화 전송한다.
- **에즈 ↔ 보맵** — 두 시스템은 **동일한 내부 폐쇄망(사설 VPC)** 안에서만 통신하며, 공인 인터넷에서는 직접 도달할 수 없다. 회원 조회·상담 통보 등 내부 구간 API는 별도 토큰 인증 없이도 **네트워크 격리(망 분리)** 로 보호된다. 즉 이 구간의 보안은 애플리케이션 토큰이 아니라 **망 경계**가 담보한다. (설문 상태 콜백 1종만 추가로 공유키를 사용.)
- **개인정보 보호(저장 시)** — 에즈가 보관하는 회원 **이름·전화번호는 평문으로 저장하지 않고** KMS 봉투암호화(AES-256-GCM) + 마스킹 + 단방향 해시(검색용)로 다중 저장한다. **주민등록번호·CI·DI는 수집·저장하지 않는다.**

---

## 2. 호출 방향별 엔드포인트 명세

### 2-1. 제휴업체 → 에즈

| 메서드 | 경로 | 용도 |
|---|---|---|
| POST | `/consultations/partner` | 상담 신청 접수(트리거) |

**요청 본문**

| 필드 | 타입 | 길이 | 보호 | 필수 |
|---|---|---|---|---|
| consultationUuid | String | 가변 | 평문(TLS) | 필수 |

**응답** — 본문 없음 (HTTP 201 Created)

### 2-2. 에즈 → 제휴업체

> 헤더 `Authorization: PARTNER_KEY {키}`. JSON 키는 **snake_case**. 에즈가 제휴업체로 고객정보를 조회(pull)한다.

| 메서드 | 경로 | 용도 |
|---|---|---|
| POST | `/api/v2/consults/{uuid}` | 상담 상세(고객정보) 조회 |
| POST | `/api/v1/consults/canceled` | 제3자동의 해지 상담 목록 조회 |

**POST `/api/v2/consults/{uuid}` — 요청**

| 필드 | 위치 | 타입 | 보호 | 필수 |
|---|---|---|---|---|
| uuid | path | String | 평문(TLS) | 필수 |
| client_id | body | String | 평문(TLS) | 필수 |

**POST `/api/v2/consults/{uuid}` — 응답**

| 필드(JSON) | 타입 | 길이 | 보호 | 비고 |
|---|---|---|---|---|
| uuid | String | 가변 | 평문 | 상담 식별자 |
| name | String | 가변 | TLS 수신 → **에즈 저장 시 KMS 암호화** | 고객명(PII) |
| phone_number | String | 가변 | TLS 수신 → **에즈 저장 시 KMS 암호화** | 휴대폰(PII) |
| birthday | String | 8 (`yyyyMMdd`) | 평문 | 생년월일 |
| gender | String | 1 (`M`/`F`) | 평문 | 성별 |
| channel_code | String | 가변 | 평문 | 유입 채널 코드 |
| channel_name | String | 가변 | 평문 | 유입 채널명 |
| request_date | Date | `yyyy-MM-dd` | 평문 | 신청일 |
| expire_date | Date | `yyyy-MM-dd` | 평문 | 동의 만료일 |
| purposes | List\<{question, answer}\> | — | 평문 | 동의 항목(질문/응답) |
| has_support_user_detail | Boolean | — | 평문 | 상세정보 지원 여부 |
| is_mydata_user | Boolean | — | 평문 | 마이데이터 가입자 여부 |

**POST `/api/v1/consults/canceled` — 요청**

| 필드(JSON) | 타입 | 보호 | 필수 |
|---|---|---|---|
| client_id | String | 평문(TLS) | 필수 |
| canceled_date | Date(`yyyy-MM-dd`) | 평문(TLS) | 필수 |

**POST `/api/v1/consults/canceled` — 응답**

| 필드(JSON) | 타입 | 보호 |
|---|---|---|
| canceled_date | Date | 평문 |
| canceled_consults | List\<{uuid}\> | 평문 |

### 2-3. 에즈 → 보맵 (폐쇄망)

> JSON 키는 **camelCase**. 상담 통보 2종은 망 분리로 보호(무인증), 설문 콜백만 공유키 헤더 사용.

| 메서드 | 경로 | 용도 | 인증 |
|---|---|---|---|
| POST | `/external/consultations/partner` | 상담 신청 통보 | 망 분리(무인증) |
| PUT | `/external/consultations/partner` | 상담 만료/취소 통보 | 망 분리(무인증) |
| POST | `/external/additional-info/status-changes` | 설문(추가정보) 상태변경 통보 | 공유키 `x-client-id` / `x-api-key` |

**POST `/external/consultations/partner` — 요청**

| 필드 | 타입 | 길이 | 보호 | 필수 |
|---|---|---|---|---|
| consultationUuid | String | 가변 | 평문(폐쇄망) | 필수 |
| memberId | Long | — | 평문(폐쇄망) | 필수 |
| requestDate | Date(`yyyy-MM-dd`) | — | 평문(폐쇄망) | 필수 |

**PUT `/external/consultations/partner` — 요청**

| 필드 | 타입 | 길이 | 보호 | 필수 |
|---|---|---|---|---|
| partnerMemberId | Long | — | 평문(폐쇄망) | 필수 |
| reasonType | String | 가변 | 평문(폐쇄망) | 필수 |
| userKey | String | 가변 | 평문(폐쇄망) | 필수 |

**POST `/external/additional-info/status-changes` — 요청**

| 필드 | 타입 | 길이 | 보호 | 필수 |
|---|---|---|---|---|
| plannerId | Long | — | 평문(폐쇄망) | 필수 |
| memberId | Long | — | 평문(폐쇄망) | 필수 |
| surveyName | String | 가변 | 평문(폐쇄망) | 필수 |
| status | String | 가변 | 평문(폐쇄망) | 필수 |
| company | String | 가변 | 평문(폐쇄망) | 필수 |

세 엔드포인트 모두 **응답 본문 없음**.

### 2-4. 보맵 → 에즈 (폐쇄망)

> JSON 키는 **camelCase**. 전 구간 폐쇄망 내부 통신(무인증). 응답의 이름·전화번호는 에즈가 저장한 암호문을 복호화한 **평문**으로 반환된다(폐쇄망 한정).

| 메서드 | 경로 | 용도 |
|---|---|---|
| GET | `/api/v1/partner-members?userKey&consultationUuid[&memberId]` | 회원 조회·매핑·userKey 갱신 |
| GET | `/api/v1/partner-members/consultations/{consultationUuid}` | 상담 UUID로 회원 조회 |
| GET | `/api/v1/partner-members/members/{userKey}` | userKey로 회원 조회 |
| POST | `/api/v1/partner-members/list` | memberId 목록으로 다건 조회 |
| GET | `/api/v1/partner-members/list/name?name=` | 이름으로 검색 |
| GET | `/api/v1/partner-members/list/phone?phoneNumber=` | 전화번호로 검색 |
| PUT | `/api/v1/partner-members/{memberId}/restore?consultationUuid[&userKey]` | 개인정보 복원 |
| DELETE | `/consultations/{consultationUuid}` | 개인정보 삭제(철회) |

**쿼리/패스 파라미터**

| 파라미터 | 타입 | 길이 | 필수 | 보호 |
|---|---|---|---|---|
| userKey | String | 가변 | 필수(restore는 선택) | 평문(폐쇄망) |
| consultationUuid | String | 가변 | 필수 | 평문(폐쇄망) |
| memberId | Long | — | 선택/필수(엔드포인트별) | 평문(폐쇄망) |
| name | String | 가변 | 필수(검색) | 평문 → 서버 내부 해시 변환 후 조회 |
| phoneNumber | String | 가변 | 필수(검색) | 평문 → 서버 내부 해시 변환 후 조회 |

**`POST /api/v1/partner-members/list` — 요청**

| 필드 | 타입 | 길이 | 보호 | 필수 |
|---|---|---|---|---|
| memberIds | List\<Long\> | — | 평문(폐쇄망) | 필수 |

**응답 A — 단건 조회(GET 3종 공통)**

| 필드 | 타입 | 길이 | 보호 |
|---|---|---|---|
| memberName | String | 가변 | 평문 응답 (저장 형태는 KMS 암호화) |
| birthDate | String | 10 (`yyyy-MM-dd`) | 평문 |
| telMobile | String | 가변 | 평문 응답 (저장 형태는 KMS 암호화) |
| gender | String | 1 (`M`/`F`) | 평문 |
| afterMemberId | Long | — | 평문 |
| consultationUuid | String | 가변 | 평문 |

**응답 B — 목록 조회(`/list`, `/list/name`, `/list/phone` 공통)** — `members` 배열의 항목:

| 필드 | 타입 | 길이 | 보호 |
|---|---|---|---|
| memberId | Long | — | 평문 |
| name | String | 가변 | 평문 응답 (저장 형태는 KMS 암호화) |
| nameMasked | String | 가변 | **마스킹** (예: 홍*동) |
| phoneNumber | String | 가변 | 평문 응답 (저장 형태는 KMS 암호화) |
| birthDate | String | 10 (`yyyy-MM-dd`) | 평문 |
| gender | String | 1 (`M`/`F`) | 평문 |
| isMydataUser | Boolean | — | 평문 |
| memberAge | Integer | — | 평문 (만나이) |
| insuranceAge | Integer | — | 평문 (보험나이) |

`PUT .../restore`, `DELETE /consultations/{uuid}` 는 **응답 본문 없음**.

---

## 3. 토큰 만료 정책

| 자격 | 적용 구간 | 발급·관리 | 만료 정책 |
|---|---|---|---|
| `PARTNER_KEY` | 제휴업체 ↔ 에즈 | 제휴업체 발급 | 정적 키 — 애플리케이션 레벨 만료 없음. 키 회전은 제휴업체 정책에 따름. 환경변수로 주입. |
| `x-client-id` / `x-api-key` | 에즈 → 보맵 (설문 콜백) | 보맵·에즈 공유 | 정적 공유 시크릿 — 환경(dev/stg/prod)별 분리, 수동 회전. |
| 설문 연동 JWT (AZ-Managed) | 추가정보(설문) 토큰 발급 | 보맵 발급 (HS512 서명) | **생성용 access 24시간 / 갱신용 access 30분**. refresh 토큰 미발급(1회성 단기 토큰). |

- 핵심 제휴업체 **회원·상담 연동(§2-1, §2-4)은 폐쇄망 보호**로 별도 토큰을 사용하지 않는다.
- 설문(추가정보) 연동에 한해 단기 JWT를 사용하며, refresh를 발급하지 않아 토큰 수명이 짧게 유지된다.

---

## 부록. 개인정보(PII) 보호 요약

- **전송**: 전 구간 TLS. 외부(제휴업체) 구간은 `PARTNER_KEY` 인증, 내부(에즈↔보맵) 구간은 폐쇄망 격리.
- **저장 암호화**: 이름·전화번호 → KMS 봉투암호화(AES-256-GCM). 평문 미저장.
- **마스킹**: 목록 응답의 `nameMasked`(예: 홍*동).
- **검색**: 평문 입력을 단방향 해시(SHA-512)로 변환 후 매칭(평문/암호문은 인덱싱하지 않음).
- **미수집**: 주민등록번호·CI·DI 미수집·미저장.
- **파기**: 동의 만료·철회 시(`PUT .../restore` 반대 흐름, `DELETE /consultations/{uuid}`) 이름·전화·생년월일·성별을 즉시 삭제(null 처리).
