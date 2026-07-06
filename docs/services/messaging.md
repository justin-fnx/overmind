# messaging — 통합 메시징 서비스

> 신규 독립 서비스 (2026-07-04~05 에픽 완료). 정본: `gitlab.bomapp.co.kr/bomapp/messaging` (project id 42, default `main`).
> 상세 설계·WBS·인수조건: 리포 내 `docs/PLAN.md` (Linear 워크스페이스 한도 초과로 티켓 대체 문서).

| 항목 | 값 |
|------|----|
| 경로 | `../messaging` |
| 리포 | `gitlab.bomapp.co.kr/bomapp/messaging` (id 42, GitLab 정본) |
| 언어/플랫폼 | Java 21 / Spring Boot 3.4 / Gradle / Jib(distroless, ARM64) / Flyway |
| 패키지 | `kr.co.bomapp.messaging` |
| feature_base_branch | `main` |
| ECR | `messaging-api` |
| 활동 상태 | **에픽 완료, dev ECS healthy (2026-07-05)** · 잔여 핸드오프 4건 (아래 §8 참조) |

---

## 1. 개요 및 결정 레코드

알림톡 / SMS / 앱푸시 / 이메일 4채널 + **상담톡(CSTALK)** 의 발송(Delivery) 기능을 신규 독립 서비스로 통합한다.
"수신자 + 템플릿키 + 파라미터"를 받아 발송을 책임지는 **정책 있는 파이프**.
**타깃팅(모수추출·Composable SpecProvider·BOM-285 audience)은 next-backend 잔류** — messaging의 클라이언트.

| # | 결정 | 내용 |
|---|------|------|
| 1 | 형태 | 완전 별도 리포 — Java 21 / Spring Boot 3.4 / Gradle / Jib |
| 2 | 스코프 | **발송만 분리** — 모수추출·BOM-285 audience는 next-backend 잔류 |
| 3 | legacy 이관 | 전부 **후속 에픽** (이메일 채널은 어댑터·API까지만 준비) |
| 4 | 부가 범위 | 옵트아웃·야간제한 **관찰모드** + Braze users/track 이전 + MSK 상태 이벤트 발행 포함 |
| 5 | DB | 기존 Aurora 클러스터에 **신규 논리 DB `messaging`** + 전용 계정/GRANT. Flyway로 이 DB만 관리 |

### WBS 작업 상태 (2026-07-05 기준)

| ID | 작업 | MR | 상태 |
|----|------|----|------|
| MSG-A | 사전 확인 조사 3건 (Bizgo 템플릿 API / 상담톡 인바운드 실경로 / Braze open 이벤트) | !1 | **완료** |
| MSG-B | 리포 부트스트랩 (Gradle 스켈레톤·health·Jib·CI·Flyway·docker-compose·README·CLAUDE.md) | !2 | **완료** |
| MSG-C | 코어 도메인 + 접수 API (엔티티·멱등·조회·상태머신·서비스 토큰 인증) | !3 | **완료** |
| MSG-D | 알림톡+SMS 어댑터 이식 (Bizgo-first + legacy supersms, 벤더 라우터, 템플릿 Mode A/B, 큐 워커, fallback) | !4 | **완료** |
| MSG-E | 웹훅 수신 + 상태 이벤트 (Bizgo 리포트 서명검증·READ 수집·MSK 발행) | !8 | **완료** |
| MSG-F | 푸시(Braze) 어댑터 (campaign/canvas trigger + users/track) | !6 | **완료** |
| MSG-G | 상담톡(CSTALK) 채널 (outbound + 인바운드 웹훅 수신→포워딩) | !9 | **완료** |
| MSG-H | 이메일 어댑터 (Works SMTP, 발신계정 설정화) | !7 | **완료** |
| MSG-I | 정책 엔진 관찰모드 (옵트아웃·야간 21~08 광고성 검사 → 위반 로깅만) | !5 | **완료** |
| MSG-J | infra Terraform — dev 리소스 (ECR/SG/TG/int-alb 룰/ECS/SM 메타 + dev 논리DB·계정) | !68 (infra) | **인프라 완료** — 핸드오프 잔여 |

---

## 2. 아키텍처

```
[호출자: next-backend 앱들, (후속) legacy, chat-api]
        │  POST /internal/v1/messages(/batch)   ← 내부 ALB(int-msg) + 서비스 토큰
        ▼
┌─ messaging-api (ECS — 현재 DEV-Cluster만 배포, stg/prod는 TF 코드만) ─────────┐
│                                                                               │
│  접수(멱등) → 템플릿 검증(Mode A/B) → 정책검사(관찰모드)                       │
│      → DB 큐(message_queue) → 워커(SKIP LOCKED) → 채널 어댑터                 │
│                                                                               │
│  어댑터:                                                                       │
│    AlimtalkSenderPort  ← AlimtalkVendorRouter(Bizgo% / Legacy 해시버킷)       │
│    SmsSenderPort       (Bizgo omni / supersms 전환기 한시 병행)               │
│    PushSenderPort      (Braze campaign/canvas trigger)                        │
│    CstalkSenderPort    (outbound 발신프로필 bomapp/kakaopay 2종)               │
│    EmailSenderPort     (Naver Works SMTP smtp.worksmobile.com:465 SSL)        │
│                                                                               │
│  웹훅 수신면:                                                                  │
│    /external/webhooks/bizgo/report   ← Bizgo 리포트(HMAC 서명검증)            │
│    /external/webhooks/cstalk/*       ← 상담톡 인바운드 4종 → 포워딩           │
│                                                                               │
│  상태 이벤트: append-only message_delivery_event + MSK messaging.status.changed │
└───────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 상태머신 다이어그램

```
ACCEPTED
    │
    ▼
ENQUEUED
    │  (워커 클레임 → 벤더 호출)
    ▼
 SENT (벤더 접수)
    ├──────────────────────────────────────┐
    │  Bizgo 리포트 웹훅                    │
    ▼                                      │
DELIVERED (단말 도달)        FAILED         │
    │                        (사유코드)     │
    ▼                                      │
 READ (읽음)           FALLBACK_SENT ──────┘
                         (대체 SMS)
                           │
                           ▼
                       DELIVERED → READ
                           │
                           └→ FAILED
```

- **역행 전이 거부**: 상태 머신이 낮은 순서 번호로의 전이를 단위 테스트로 검증
- **READ 순서 역전 처리**: DELIVERED보다 READ가 먼저 도착하면 DELIVERED 함의 체인 자동 삽입 (MSG-E)
- **stale PROCESSING 회수**: `locked_by/at` 기록 + 5분 초과 시 재시도 잡

### 2.2 알림톡 벤더 라우터 (`AlimtalkVendorRouter`)

- **percentage 해시버킷**: 0~99 버킷을 `bizgo_percentage`(설정값) 기준 분기. 0이면 전량 Legacy.
- **activeTemplates 모드**: 특정 템플릿키 목록에 대해서만 Bizgo 사용 (단계적 전환용)
- **shadow 모드 (stg 검증 전용)**: 게이트 통과 발송을 Legacy 실발송 + Bizgo 비동기 그림자 발송으로 이중 송출해 오프라인 diff 검증 — **수신자가 두 번 받으므로 prod에서 shadowEnabled=true면 부팅 실패(fail-fast 코드 가드)**
- **fallback_policy**: `message_template.fallback_policy` JSON에 따라 알림톡 실패 시 Bizgo omni [AT,SMS] messageFlow 체인 1회 발송. FALLBACK_SENT 판정은 Bizgo 리포트 웹훅 몫.

### 2.3 큐 워커

- `FOR UPDATE SKIP LOCKED` — 다중 인스턴스 안전 소비 (2 인스턴스 동시 소비 시 중복 발송 0)
- **지원 채널 한정 클레임**: 채널→디스패처 레지스트리 5채널 매핑
- **지수 백오프 재시도**: 30s → 2m → 10m (attempt_count 기반)
- **fast-path (IMMEDIATE)**: `priority=10` 큐 아이템 생성 (인증 SMS 등 지연 민감, 큐 우회 배선은 후속)

---

## 3. API 계약 상세

### 3.1 공통

| 항목 | 값 |
|------|----|
| 베이스 URL | `https://int-msg.bomapp.co.kr/internal/v1` |
| 인증 | `Authorization: Bearer <service-token>` — 모든 `/internal/**` 필수 |
| 멱등성 | 단건: `Idempotency-Key` 헤더 필수 (없으면 400). 배치: 항목별 `idempotencyKey` 필수 |
| Content-Type | `application/json` |

에러 응답 형식:
```json
{ "code": "VALIDATION_ERROR", "message": "에러 설명 (한국어)" }
```

| 코드 | HTTP | 설명 |
|------|------|------|
| `UNAUTHORIZED` | 401 | 서비스 토큰 없음/불일치 |
| `VALIDATION_ERROR` | 400 | 필드 오류·미승인 템플릿·변수 누락 등 |
| `BATCH_TOO_LARGE` | 400 | 배치 한도(`messaging.batch.max-size`, 기본 1000) 초과 |
| `NOT_FOUND` | 404 | 메시지 없음 |
| `INTERNAL_ERROR` | 500 | 서버 오류 |

### 3.2 엔드포인트 목록

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/internal/v1/messages` | 단건 접수 |
| POST | `/internal/v1/messages/batch` | 대량 접수 (최대 1000건) |
| GET | `/internal/v1/messages/{id}` | 상태 + 이벤트 타임라인 |
| GET | `/internal/v1/messages?refKey=` | 도메인 참조키 벌크 조회 (페이징) |
| POST | `/internal/v1/push/track` | Braze users/track 사용자 속성 배치 업데이트 |
| POST | `/external/webhooks/bizgo/report` | Bizgo 리포트 웹훅 (HMAC 서명검증 필수) |
| POST | `/external/webhooks/cstalk/message` | 상담톡 사용자 메시지 수신 |
| POST | `/external/webhooks/cstalk/reference` | 상담톡 채팅방 열기 |
| POST | `/external/webhooks/cstalk/expired_session` | 상담톡 세션 만료 |
| POST | `/external/webhooks/cstalk/result` | 상담톡 발송 결과 콜백 |
| GET | `/health` | 헬스체크 (인증 불필요) |

### 3.3 단건 접수 — `POST /internal/v1/messages`

**Mode A** (templateKey 사용):

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `channel` | enum | ✅ | `ALIMTALK\|SMS\|PUSH\|CSTALK\|EMAIL` |
| `templateKey` | string | ✅(A) | 내부 템플릿 키 (APPROVED 상태 필요) |
| `to` | string | ✅ | 수신자 식별자 (전화번호·이메일·디바이스토큰) |
| `variables` | object | 조건부 | 템플릿 필수 변수 누락 시 400 |
| `refKey` | string | — | 호출자 도메인 참조 키 (주문번호·회원번호 등) |
| `adFlag` | boolean | — | 광고성 여부 (기본: false) |
| `deliveryMode` | enum | — | `QUEUED`(기본)\|`IMMEDIATE` |

**Mode B** (renderedBody 패스스루, 전환기 기존 SpecProvider 무개편 이관용):

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `channel` | enum | ✅ | |
| `vendorTemplateCode` | string | ✅(B) | 벤더 템플릿 코드 (카카오 등록 코드) |
| `renderedBody` | string | ✅(B) | 도메인이 렌더한 완성 본문 |
| `to` | string | ✅ | |

응답: 신규=202, 멱등 중복=200 (`duplicate: true`)

### 3.4 멱등성 처리

- `Idempotency-Key` 헤더 → `message.idempotency_key` UNIQUE 제약
- 중복 접수 시 별도 Bean(`MessageAcceptExecutor`) + unique 제약 catch → 동일 `messageId` 반환 (DB 쓰기 0)
- 배치: 항목별 `idempotencyKey` 필수. 누락 항목만 실패, 전체 롤백 없음.

### 3.5 조회 응답 — `GET /internal/v1/messages/{id}`

- `toAddressMasked`: 항상 마스킹된 값 반환 (원문 반환 절대 금지)
- `timeline`: `message_delivery_event` append-only 로그 전체. `vendor`, `vendorMsgKey`, `occurredAt` 포함.

### 3.6 Braze track — `POST /internal/v1/push/track`

- Braze users/track API 래퍼. `attributes` 배열 필수 (빈 배열→400)
- 어댑터 내부에서 75건 단위 청킹 처리 (Braze API 제한)
- 응답: `{ "accepted": <건수> }` (Braze 처리 건수와 다를 수 있음)

---

## 4. 데이터 모델 (논리 DB `messaging`)

### 4.1 테이블 목록

| 테이블 | 역할 | 파티셔닝 |
|--------|------|----------|
| `message` | 접수 원장 — 채널·템플릿·수신자·상태 | 없음 (멱등 unique 충돌로 비파티셔닝; 보존 배치는 후속) |
| `message_delivery_event` | 상태 이벤트 append-only 로그 | **월별 RANGE 파티셔닝 적용 (MSG-K, V8, MR !10 머지)** |
| `message_template` | 템플릿 레지스트리 (§5 참조) | 없음 |
| `message_queue` | 발송 대기 큐 (SKIP LOCKED 소비) | 없음 |
| `cstalk_inbound_log` | 상담톡 인바운드 웹훅 로그 (PII 마스킹 저장) | **월별 RANGE 파티셔닝 적용 (MSG-K, V8, MR !10 머지)** |

### 4.2 `message` — 접수 원장

주요 컬럼:
- `idempotency_key VARCHAR(128)` — UNIQUE KEY, 멱등 핵심
- `channel VARCHAR(16)` — 채널 enum
- `template_key VARCHAR(128)` — 내부 논리 키 (Mode A)
- `vendor_template_code VARCHAR(256)` — 벤더 템플릿 코드 (Mode B, V2 추가)
- `rendered_body TEXT` — 도메인 렌더 본문 (Mode B, V2 추가)
- `to_address VARCHAR(512)` — **AES-256-GCM 암호화** (V2에서 VARCHAR(256)→512 변경, 키=env `MESSAGING_CRYPTO_KEY`)
- `variables JSON` — 템플릿 치환 변수
- `ref_key VARCHAR(256)` — 호출자 도메인 참조 키 (벌크 조회 인덱스)
- `ad_flag TINYINT(1)` — 광고성 여부
- `delivery_mode VARCHAR(16)` — `QUEUED`|`IMMEDIATE` (V2 추가)
- `caller VARCHAR(64)` — 호출 서비스 식별자 (토큰 인증 해석, V2 추가)
- `status VARCHAR(32)` — 현재 상태
- `created_at / updated_at DATETIME(6)` — UTC 통일

인덱스: `uq_message_idempotency_key`, `idx_message_ref_key`, `idx_message_channel_status`, `idx_message_created_at`

### 4.3 `message_delivery_event` — 상태 이벤트 로그

append-only. 상태 역행 추적 불가능(설계적 보장).

주요 컬럼:
- `message_id BIGINT` — message.id 참조
- `event_type VARCHAR(32)` — ACCEPTED|ENQUEUED|SENT|DELIVERED|READ|FAILED|FALLBACK_SENT
- `vendor_msg_key VARCHAR(256)` — 벤더 발급 메시지 상관 키
- `vendor VARCHAR(32)` — BIZGO|SUPERSMS|BRAZE|NAVER_WORKS
- `error_code / error_message` — 실패 시 벤더 응답
- `raw_payload JSON` — 벤더 원본 페이로드
- `occurred_at DATETIME(6)` — UTC

인덱스: `idx_mde_message_id`, `idx_mde_vendor_msg_key`, `idx_mde_occurred_at`, `idx_mde_msg_event(message_id, event_type)` (V4 추가, 웹훅 멱등 확인)

> **파티셔닝 (MSG-K 완료, V8·MR !10 머지)**: `message_delivery_event`와 `cstalk_inbound_log`는 `occurred_at`/`received_at` 기준 월별 RANGE 파티셔닝 적용 완료(복합 PK, 2026-07~2027-06+pMAX, 롤링 자동화는 후속). `message`는 `idempotency_key` UNIQUE 제약이 파티셔닝과 충돌하므로 비파티셔닝 유지 + 보존 배치는 후속.

### 4.4 `message_template` — 템플릿 레지스트리

| 컬럼 | 설명 |
|------|------|
| `template_key` | 내부 논리 키 (UNIQUE) |
| `channel / vendor` | 채널·벤더 (ALIMTALK/BIZGO 등) |
| `vendor_template_code` | 카카오 등록 템플릿코드 |
| `sender_key` | 발신프로필 (브랜드별 복수 가능) |
| `body_pattern / variables_schema` | 등록 원문 + `#{변수}` 스키마 |
| `buttons / emphasize_type` | 카카오 부가 요소 |
| `vendor_subtype` | PUSH 채널 Braze 구분: `CAMPAIGN`\|`CANVAS` (V5 추가) |
| `fallback_policy` | 대체발송 정책 JSON |
| `status` | `PENDING`\|`APPROVED`\|`REJECTED`\|`DEPRECATED` — **APPROVED만 발송 허용** |

### 4.5 `message_queue` — 발송 대기 큐

| 컬럼 | 설명 |
|------|------|
| `message_id` | message.id 참조 |
| `priority INT` | 낮을수록 우선 처리 (기본 100, IMMEDIATE=10) |
| `scheduled_at` | 발송 예정 시각 |
| `locked_by / locked_at` | 처리 인스턴스 마킹 (5분 초과 시 stale 회수) |
| `status` | `WAITING`\|`PROCESSING`\|`DONE`\|`FAILED` |
| `attempt_count` | 시도 횟수 (지수 백오프 재시도 기준) |

### 4.6 `cstalk_inbound_log` — 상담톡 인바운드 로그 (V6)

- **PII 마스킹 저장**: `message` 타입 웹훅에서 `contents/attachment` 필드 제거 후 `raw_payload` 저장
- 포워딩(chat-api relay)은 원본 페이로드 그대로 — 마스킹은 저장 전용
- `result/reference/expired_session` 타입: 대화 원문 없는 메타 페이로드 → 원본 저장
- 보존기간 가이드라인: 30일 (보안팀 최종 확인 필요, 현재 무기한)
- `ref`: 발송 시 sendRef 매칭용 (messaging messageId 기반)

### 4.7 Flyway 마이그레이션 이력

| 버전 | 파일 | 내용 |
|------|------|------|
| V1 | `V1__init.sql` | 4개 테이블 초기 스키마 (message/event/template/queue) |
| V2 | `V2__core_domain.sql` | Mode B 필드·delivery_mode·caller·to_address 암호화 전환 |
| V4 | `V4__webhook_report_index.sql` | message_delivery_event 복합 인덱스 추가 (웹훅 상관 조회) |
| V5 | `V5__push_vendor_subtype.sql` | message_template.vendor_subtype (PUSH Braze 구분) |
| V6 | `V6__cstalk_inbound_log.sql` | cstalk_inbound_log 테이블 신설 |

---

## 5. 채널·벤더 매트릭스

| 채널 | 1차 벤더 | 전환기 병행 | SENT | DELIVERED | READ | 비고 |
|------|----------|------------|------|-----------|------|------|
| ALIMTALK | Bizgo omni | supersms (Legacy, 해시버킷) | ✅ | ✅ | ✅ | Bizgo 리포트 웹훅 (MSG-E) |
| SMS | Bizgo omni | supersms (Legacy) | ✅ | ✅ | — | 배달 확인만 |
| CSTALK | Bizgo omni | — | ✅ | ✅ | ✅ | outbound 2종(bomapp/kakaopay); 인바운드 4종 웹훅 (MSG-G) |
| PUSH | Braze | — | ✅ | ❌ | ❌ | Currents(유료 계약) 필요 시 DELIVERED/READ 추가 가능 (MSG-A 확인) |
| EMAIL | Naver Works SMTP | — | ✅ | ❌ | ❌ | smtp.worksmobile.com:465 SSL; 배달 콜백 미제공 (MSG-H) |

### Bizgo omni fallback 체인

`message_template.fallback_policy` JSON 정의 → 알림톡 실패 시 Bizgo omni [AT, SMS] messageFlow 1회 체인 발송.
FALLBACK_SENT 판정은 Bizgo 리포트 웹훅이 담당. 식별 필드(msgType/serviceType) 실측 확정은 후속 확인 항목.

### 상담톡 인바운드 경로 (MSG-A 조사 결과)

- **Bizgo v3 (신규)**: `POST /cstalk/message|reference|expired_session|result` — senderKey → channelId 변환
- **Legacy (PROD 현재)**: `POST /message|reference|expired_session|result` — `channelId`(pf_id) 직접 수신
- **현재**: PROD 상담톡 인바운드는 전량 **legacy chat-api**가 수신 중. 컷오버 시 Bizgo 콘솔에서 웹훅 URL을 messaging으로 전환 필요.
- **서명**: 현재 무서명 permit-all. Bizgo cstalk 인바운드 서명 옵션 벤더 확인 후속 필요.

### Braze 푸시 open 이벤트 (MSG-A 조사 결과)

- DELIVERED·READ 모두 **Braze Currents**(유료 애드온) 전용 실시간 스트리밍 필요
- 비-Currents에서 확실한 상태: Braze trigger API 접수 성공(= `SENT`, `dispatch_id` 확보)까지
- 장기: Currents 계약 후 `/internal/v1/webhook/braze/currents` 엔드포인트 추가 → `dispatch_id`/`external_user_id`로 상관관계 조회 → READ 이벤트 append

---

## 6. MSK / Kafka 상태 이벤트

### 6.1 토픽 정보

| 항목 | 값 |
|------|----|
| 토픽 | `messaging.status.changed` |
| 파티션 키 | `messageId` (String) — 동일 메시지 이벤트가 동일 파티션에 순서 보장 |
| 직렬화 | JSON (타입 헤더 없음: `spring.json.add.type.headers=false`) |
| **현재 발행** | 웹훅 유래 전이: DELIVERED, READ, FAILED, FALLBACK_SENT |
| **후속 (전 전이 통합)** | ACCEPTED→ENQUEUED→SENT 통합 발행 (MSG-E AIDEV-NOTE 예약) |

### 6.2 페이로드 스키마

```json
{
  "messageId": 12345,
  "refKey": "ORDER-20260704-001",
  "caller": "bomapp-api",
  "channel": "ALIMTALK",
  "prevStatus": "SENT",
  "newStatus": "DELIVERED",
  "occurredAt": "2026-07-04T10:00:05.123456",
  "vendorMsgKey": "BIZGO-MSG-20260704-98765"
}
```

### 6.3 환경별 브로커

| 환경 | 브로커 |
|------|--------|
| dev | **Confluent Cloud** (MSK 아님 — chat-api dev와 동일 SASL 엔드포인트) |
| stg / prod | **AWS MSK** |

> **dev SM `KAFKA_BOOTSTRAP_SERVERS`**: placeholder → 실 Confluent Cloud 엔드포인트 교체 필요 (핸드오프 잔여 ②)

### 6.4 소비자

"읽지 않으면 N시간 후 타채널 재발송" 같은 도메인 로직은 **호출자 도메인**이 구독해 구현.
컷오버 시 배선: next-backend(bomapp-api 등) → `messaging.status.changed` 토픽 구독.

### 6.5 발행 실패 처리

- 발행 실패 = 로그만 처리. 웹훅 응답 실패 없음.
- 재발행(retry) 메커니즘: dead-letter DB 테이블 저장 + 별도 재처리 워커 (후속 예약).

---

## 7. 보안

### 7.1 PII 암호화 (to_address)

- **알고리즘**: AES-256-GCM (AEAD — 기밀성 + 무결성 동시 제공)
- **키 길이**: 256비트 (32바이트)
- **IV**: 128비트 SecureRandom, 매 암호화마다 신규 생성 (재사용 공격 차단)
- **저장 형식**: Base64(IV[12B] || 암호문 || Auth Tag[16B]) — VARCHAR(512)
- **구현체**: `AesGcmCrypto.java` + JPA `ToAddressConverter.java`

| 환경 | 키 출처 | 미설정 시 |
|------|---------|-----------|
| local | 내장 기본키 (더미, 코드 하드코딩) | 기본키 자동 적용 |
| dev / stg / prod | AWS SM → ECS 태스크 env `MESSAGING_CRYPTO_KEY` | **기동 즉시 fail-fast** |

> 키 로테이션 (향후): 현재 단일 키. 향후 암호문 prefix에 `v{N}:` 버전 태그 추가 → 점진적 로테이션 (후속 에픽).

### 7.2 조회 마스킹 (`ToAddressMasker`)

API 응답 `toAddressMasked`: 원문 반환 절대 금지.

| 유형 | 규칙 | 예시 |
|------|------|------|
| 전화번호 (10~11자리) | 앞 3 + `****` + 마지막 4 | `010****5678` |
| 이메일 (@ 포함) | 앞 2 + `****` + 도메인 전체 | `us****@bomapp.co.kr` |
| 기타 (디바이스 토큰) | 앞 4 + `****` + 마지막 4 | `devi****1234` |
| 8자 이하 | `****` | — |

### 7.3 웹훅 서명 검증 (Bizgo 리포트)

- HMAC + timestamp fail-closed
- 위조 요청 → 403 드롭
- 중복 리포트 → 멱등 처리 (동일 message_id + event_type 존재 체크)
- 패턴: next-backend `BizgoWebhookSignatureVerifier` 이식 (MSG-A 조사 근거)

### 7.4 서비스 토큰 인증

- 모든 `/internal/**` 엔드포인트: `Authorization: Bearer <service-token>`
- 호출자별 정적 서비스 토큰 설정 (`messaging.auth.tokens.<caller>`)
- 토큰 없음/불일치 → 401

### 7.5 상담톡 PII (cstalk_inbound_log)

- `message` 타입: `CstalkMessagePayloadMasker`로 `contents/attachment` 필드 제거 후 저장
- 포워딩은 원본 페이로드 그대로 relay
- `result/reference/expired_session` 타입: 메타 페이로드만, 원본 저장 허용

### 7.6 이메일 발신계정 (MSG-H)

| 논리 키 | 계정 | 용도 |
|---------|------|------|
| `partner` | admin@bomapppartner.co.kr | 가입증명 v1 (삼성화재 반려견) |
| `biz` | service@bomappbiz.co.kr | 마켓 v2 (보맵파트너 가입증명) |
| `help` | helpsend@bomapp.co.kr | CS 답변 (기본 발신자) |

실 계정값은 `MESSAGING_EMAIL_{PARTNER|BIZ|HELP}_{USERNAME|PASSWORD}` 환경변수 또는 SM 참조. 하드코딩 금지.

### 7.7 정책 엔진 (관찰모드)

- **야간 (KST 21:00~08:00) + `adFlag=true`**: 위반 로그 기록 + Micrometer 카운터만. **차단 없음 (관찰모드)**
- **옵트아웃 훅**: 원천 연동 인터페이스만 구현, 실 연동은 후속
- **강제 모드**: 설정 `messaging.policy.enforce=true` 시 400 차단 (기본 off)

---

## 8. 배포·운영

### 8.1 dev 환경 현황 (2026-07-05 기준)

| 항목 | 값 |
|------|----|
| ECS 서비스 | `SVC-ECS-DEV-messaging-api` (DEV-Cluster) |
| 상태 | healthy |
| 타깃 그룹 | `dev-messaging-api-ip-8080` |
| 내부 도메인 | `dev-int-msg.bomapp.co.kr` (dev-alb prio 230) |
| 현재 이미지 | MSG-C 시점 (`20260704-6537505`) — **Flyway 비활성 상태** |
| infra MR | !68 (머지 완료) |

> ⚠️ **현재 이미지는 MSG-C 시점 + Flyway 비활성 상태**. DB 생성 후 최신 이미지(5채널 MSG-D~I) 재배포 필요.

### 8.2 잔여 핸드오프 (사용자/리더, 범위 내 미완)

| # | 작업 | 방법 |
|---|------|------|
| ① | **dev 논리 DB 생성** | `infra/docs/messaging-dev-db-setup.sql` 실행 (비밀번호=SM `MESSAGING_DB_PASSWORD` 값) → 이후 Flyway 재활성 task-def + 최신 이미지 재배포 |
| ② | **SM `KAFKA_BOOTSTRAP_SERVERS`** | placeholder → dev Confluent Cloud 엔드포인트 교체 (BOM-74; chat-api dev와 동일 SASL 값) |
| ③ | **log-daemon 재기동 승인** | → `logs-dev-messaging-api` ES 수집 확인 |
| ④ | **이메일 SMTP 시크릿 등록** | `MESSAGING_EMAIL_{PARTNER|BIZ|HELP}_*` SM 등록 + task-def 주입 (실사용은 legacy 이관 에픽) |

### 8.3 GitLab CI 구성

- 파이프라인: `pr-check`(build+test) → Jib ECR push → ECS deploy
- 러너: `ref_protected` (feature/* 브랜치 보호 설정 완료 — push/merge=developer)
- 이미지: 경량 `amazoncorretto` (GitLab CI 디스크 제약)
- ECR 직접 push (GitLab → ECR; OIDC 불가→정적 배포 키)
- 배포 태그: `YYYYMMDD-shortsha`

### 8.4 재배포 절차

```bash
# 핸드오프 ① 완료 후
gh workflow run build-and-deploy.yml --ref main -f environment=dev
# 또는 GitLab CI 직접 트리거
glab api "projects/42/pipeline" --method POST --field ref=main
```

---

## 9. 범위 외·후속 확인 항목

### 9.1 별도 승인 필요 (에픽 범위 외)

- **컷오버**: 콜백 ALB 룰 전환, next-backend 벤더 코드 제거, 큐 소비 단일화
- **호출자 전환**: next-backend·legacy-backend → messaging API 전환 코드
- **stg/prod Terraform apply** (코드 준비 완료, apply만 별도 승인)
- **legacy 이관 에픽** (이메일 실가동, 레거시 채널 전환)

### 9.2 후속 확인 항목

| 항목 | 상태 |
|------|------|
| FALLBACK_SENT 리포트 식별 필드(msgType/serviceType) Bizgo 실측 확정 | 미확인 |
| cstalk 인바운드 서명 옵션 벤더 확인 | 미확인 |
| Braze Currents 계약 여부 (READ/DELIVERED) | 미확인 |
| 옵트아웃 원천 연동 방식 결정 | 후속 |
| MSK 발행 dead-letter 재처리 구현 | 후속 |
| `message_delivery_event`·`cstalk_inbound_log` 파티셔닝 (MSG-K MR) | 진행 중 |
| message 보존 기간 정책 (개인정보처리방침·법무 컨펌) | 후속 |
| Braze `dispatch_id` ↔ `message.id` 매핑 테이블 설계 | 후속 |
| Bizgo 템플릿 자동 동기화 (lastModified 폴링 배치) | 후속 |

---

## 10. 참조

- 리포 `docs/PLAN.md` — 전체 설계·WBS·인수조건
- 리포 `docs/api.md` — API 명세 상세
- 리포 `docs/events.md` — MSK 이벤트 스키마
- 리포 `docs/security-to-address.md` — PII 암호화 설계
- 리포 `docs/research/msg-a-findings.md` — 사전 조사 결과 (Bizgo/CSTALK/Braze)
- overmind `services.yaml` — 서비스 카탈로그
- overmind `docs/architecture.md` — 전체 아키텍처
