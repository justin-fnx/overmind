# bomapp-batch 저빈도 대량 잡 → ECS 예약 태스크 이관 설계

> 상태: 제안(Proposal) / 작성일 2026-07-13
> 대상 서비스: `next-backend` (`bomapp-server/bomapp-batch`), `infra` (Terraform)
> 관련 Linear: 에픽 [BOM-393](https://linear.app/bomapp/issue/BOM-393) (하위 BOM-394·395·396·397) + 별도 [BOM-398](https://linear.app/bomapp/issue/BOM-398) "domain-rds 외부 의존성 분리"

---

## 1. 배경과 문제

`bomapp-batch`는 인앱 스케줄러(`@Scheduled` + `ThreadPoolTaskScheduler`)로 **40개 활성 잡**을 도는 ECS 서비스다. 현재 구성:

- `desired_count = 1` (전 환경) — 중복 실행 방지를 위한 싱글턴.
- 배포 전략 `minimumHealthyPercent=0 / maximumPercent=100` → **기존 태스크를 먼저 0으로 죽인 뒤 새 태스크를 띄운다**(stop-the-world).
- `SchedulerConfig`에 graceful shutdown 장치 **없음**(`waitForTasksToCompleteOnShutdown`/`awaitTerminationSeconds` 미설정, yml에 `server.shutdown: graceful` 없음) → 종료 시 돌던 잡을 기다리지 않고 인터럽트/`SIGKILL`.

이 구조에서 배포가 어려운 이유는 **독립된 두 문제**가 얽혀서다:

| 축 | 문제 | 원인 |
|---|---|---|
| **A. 스케줄러 레벨** | 2개도 안 되고(중복) 0개도 안 됨(공백·미스파이어) | 인앱 싱글턴 + `min=0/max=100` |
| **B. 잡 레벨** | 실행 중이던 잡이 배포 시 `SIGKILL`로 **중간 절단** | graceful shutdown 부재 + 무거운 잡이 종료 유예(30~120s)를 초과 |

특히 축 B는 **truncate→재삽입 / deleteAll→재적재 / 전 회원 인메모리 집계** 류 잡에서 데이터를 깨뜨린다.

### 해결 원칙 — 잡 성격별로 다른 처방

- **짧고 멱등한 큐/상태 폴러(초·분 단위)**: 중간에 끊겨도 다음에 재집힌다. 인앱에 남기면 됨. (축 A만 관리, 필요 시 옵션-3 분산락은 후속.)
- **무겁고 저빈도(일·월·년)인 대량 잡**: 배포가 잡을 죽이면 안 된다 → **ECS 예약 태스크(EventBridge → RunTask)로 이관**. 배포는 태스크 정의만 바꾸고, 이미 도는 RunTask 컨테이너는 건드리지 않으므로 **"배포 = 잡 죽이기" 등식이 끊긴다.**

---

## 2. 잡 분류

### 인앱 잔류 (이관 불가/불필요) — 약 6~10개

| 잡 | 주기 | 성격 |
|---|---|---|
| `AlimtalkTask.sendAlimTalkMessage` | `fixedRate 2.5s` | 알림톡 큐 드레인(콜드스타트 > 주기, 이관 불가) |
| `InsuranceGuaranteeQueueTask.taskDoInsuranceGuaranteeRequest` | `fixedDelay 1s` | 보장분석 요청 큐 드레인(이관 불가) |
| `AlimtalkTask.saveTodayMemberOnQueue` / `saveRemainMemberOnQueue` | `60s` | 알림톡 큐 적재 producer(위 소비자와 한 몸) |
| `InsurerSendFailTask.taskSendAlimTalkFailClaim1Minute` | 매분 | 청구 실패 상태전이(멱등, 중단 무해) |
| `HealthConnectionTimeoutTask.deleteExpiredHealthConnectionData` | `60s` | 만료 헬스커넥션 건별 정리(멱등) |
| `MonitoringTask` 4종 | 매시·10분 | 경량 read 모니터링(이관 실익 적음) |
| `PlannerNotificationTask.taskSendReservationMember` | 매분 | 시간창 발송(락 필요) |

### 이관 대상 (저빈도 대량) — 약 28개

일/월/년 cron으로 전량 순회·집계·대량 발송하는 잡 전부. 주요:

- `ReportTask.makeStatistics` (월말 07:00, 전 회원 인메모리 집계) — **최고위험**
- `GnnetHospitals.taskGnnetHospitals` (매일 03:00, `truncate`→재삽입) — **고위험**
- `BomappNotificationTask.taskSavePushTarget` (매일 00:05, `deleteAll`→재적재) — **고위험**
- `AzPremiumReport`(22:00), `AzPlannerLinkTask`(23:30), `ConsultationTask`(03:00), `ChannelTalkTask`(00:30), `ExtendChatBotSendTask`×2(13:00), `NotificationTrackTask.sendCustomAttributes2`(연 1회), `BomappNotificationTask.taskDeleteExpiredNotifications`(01:00), `InsuranceGuaranteeTask`×2(00:00/05:00), `OpenTask`×2(05:00/05:30), `PlannerNotificationTask` 일배치 ×14(08:00~09:01)

> 참고: `PlannerNotificationTask` 만기동의 푸시 **10개가 09:01에 동시 발화** + 09:00 생일건과 겹침. 이관 시 EventBridge에서 시차 분산·잡별 사이징으로 정리.

---

## 3. 목표 아키텍처 — "1 이미지 / N task-def / N schedule"

```
┌─ 상시 ECS Service (desired=1) ─────────────┐   ← 인앱 잔류 폴러만 실행
│  bomapp-batch 이미지 (service 모드)         │
│  @EnableScheduling → 잔류 폴러(초·분)       │
└─────────────────────────────────────────────┘
        ▲ 동일 이미지 (빌드 1개)
        │
┌─ EventBridge Scheduler (KST) ─────────────┐
│  잡별 schedule N개 (기존 cron 시각 유지)    │
│    └─▶ ecs:RunTask (잡별 task-def)          │
│           bomapp-batch 이미지 (task 모드)   │  ← BATCH_TASK=REPORT_STATISTICS
│           web-application-type=none         │
│           잡 1개 실행 → SpringApplication.exit()
│           잡별 cpu/mem, 잡별 task IAM role  │
│    + 재시도 정책 + DLQ(SQS)                 │
└─────────────────────────────────────────────┘
```

### 왜 "잡마다 전용 이미지"가 아니라 "이미지 1개 + task-def N개"인가

- 28개 잡 로직이 전부 **`bomapp-domain-rds`(god 모듈)** 를 재사용한다. 이 모듈은 14개 `bomapp-external-*` Feign + web + security + iText(PDF) + jxls(Excel) + OTP + NICE를 통째로 끌어온다.
- 따라서 "잡마다 이미지"를 해도 **서로 거의 똑같이 뚱뚱한 이미지 28벌 복제** + 빌드 타깃 28개가 될 뿐, 슬림해지지 않는다. (진짜 슬림화는 domain-rds 분해가 선행 — 별도 티켓/트랙.)
- 반면 **task definition 단위**로 나누면 이미지 복제 없이도 원하는 독립성을 얻는다:
  - **리소스 격리**: `ReportTask`엔 메모리 크게, 모니터링엔 작게 — task-def별 cpu/mem.
  - **권한 최소화(보안)**: report task-def엔 Slack+S3만, AZ task-def엔 AZ 시크릿만 — task IAM role 분리.
  - **빌드 단일화**: CVE·베이스 이미지 갱신 1회.
- **미래 호환**: 나중에 domain-rds가 분해되면 개별 task-def를 전용 슬림 이미지로 하나씩 갈아끼우면 된다(스케줄 배선 불변).

---

## 4. 앱 변경 (`next-backend` / `bomapp-batch`)

### 4.1 이미지 이중 모드 (핵심)

`BomappBatchApplication` 부팅 시 환경변수 `BATCH_TASK` 유무로 분기:

- **service 모드** (`BATCH_TASK` 미설정): 기존과 동일 — 인앱 스케줄러로 잔류 폴러 실행. 하위호환.
- **task 모드** (`BATCH_TASK=<잡키>` 설정):
  - `spring.main.web-application-type=none` (Tomcat 미기동)
  - `@EnableScheduling` 비활성 (인앱 스케줄러 안 뜸)
  - 잡 러너 레지스트리에서 `<잡키>` → 해당 `BatchJob` 조회 → `run()` 1회 실행
  - 성공 시 `SpringApplication.exit(ctx, () -> 0)`, 실패 시 non-zero 종료코드(RunTask 실패로 관측 → 재시도/DLQ)
  - 미지의 잡키면 즉시 non-zero exit + 에러 로그

### 4.2 잡 러너 레지스트리

```
interface BatchJob { String key(); void run(); }
// 이관 잡마다 BatchJob 구현 → 기존 도메인 서비스 메서드를 그대로 호출
// Map<String, BatchJob> 로 주입, BATCH_TASK 로 lookup
```

- 이관 잡의 기존 `@Scheduled` 메서드는 **로직을 도메인 서비스로 남기고**, 스케줄 트리거만 제거(§4.4 컷오버) → `BatchJob.run()`이 동일 서비스 메서드를 호출.

### 4.3 웹/시큐리티 배제 + graceful shutdown

- `internal-security`의 `@EnableWebSecurity SecurityConfig`를 `@Profile("!task")`(또는 조건부 제외)로 task 모드에서 배제.
- (service 모드용) `SchedulerConfig`에 `setWaitForTasksToCompleteOnShutdown(true)`, `setAwaitTerminationSeconds(N)` + yml `spring.lifecycle.timeout-per-shutdown-phase` 추가 → 잔류 폴러가 종료 시 인터럽트 대신 마무리.
- `MonitoringTask`의 `@PostConstruct`+`@Scheduled` 이중부착 정리.

### 4.4 컷오버 스위치 (이중 실행 방지)

- 이관 대상 각 잡의 인앱 `@Scheduled`를 `@ConditionalOnProperty(name="batch.inapp.<잡키>.enabled", matchIfMissing=true)`로 가드(기본 활성 = 무변경).
- 컷오버 = **프로퍼티(SSM/env)로 인앱 잡 비활성 + 해당 EventBridge 스케줄 활성**을, 실행 시각이 겹치지 않는 창에서 전환 → 이중 실행/공백 없음.
- 안정화 확인 후 인앱 `@Scheduled` 코드 최종 제거(정리 커밋).

### 4.5 위험 3종 원자화

배포뿐 아니라 spot/OOM kill에도 데이터가 깨지지 않도록:

- `GnnetHospitals`: `truncate`→재삽입을 **swap table**(새 테이블 적재 후 원자적 RENAME) 또는 단일 트랜잭션으로. 중단 시 기존 데이터 보존.
- `BomappNotificationTask.taskSavePushTarget`: `deleteAll`→재적재 원자화(swap 또는 트랜잭션).
- `ReportTask.makeStatistics`: 중단 시 **부분 통계 미커밋** 또는 재실행 안전 보장(멱등 upsert).

---

## 5. 인프라 변경 (`infra` / Terraform)

- 이관 잡별 **ECS task definition**: 동일 이미지, `BATCH_TASK` env 주입, 잡별 `cpu`/`memory`.
- 잡별 **EventBridge Scheduler** (`aws_scheduler_schedule`, **타임존 KST** — 기존 cron 시각 그대로): 타깃 = `ecs:RunTask`(FARGATE/EC2 capacity, 네트워크 구성).
  - (대안: 클래식 ECS 예약 태스크 = CloudWatch Events 규칙. 단 크론 UTC 고정이라 KST 환산 필요 → EventBridge Scheduler 권장.)
- 잡별 **task IAM role 최소권한**.
- 실패 시 **재시도 정책 + DLQ(SQS)**.
- `infra/CLAUDE.md` 규정 준수: `terraform plan` destroy 0, `prevent_destroy` 유지, `-target` 적용.
- dev 클러스터 먼저 적용 → 수동 RunTask로 잡 1개 성공 종료 확인.

---

## 6. 롤아웃 순서

1. **앱 기반 (Sub 1)**: 이중 모드 + 잡 러너 + 웹/시큐리티 배제 + graceful shutdown. 배포해도 service 모드는 기존과 동일(무변경).
2. **인프라 (Sub 2, dev)**: task-def + 스케줄 + role + DLQ. 스케줄은 **비활성(disabled)** 상태로 생성. 수동 RunTask로 검증.
3. **원자화 (Sub 3)**: 위험 3종. (Sub 1과 병렬 가능.)
4. **컷오버 (Sub 4)**: 잡별로 인앱 비활성 + 스케줄 활성. **dev→stg→prod** 순, 각 환경 24h 관찰(이관 잡 1회↑ 정상 + 인앱 미실행 로그). 안정화 후 인앱 `@Scheduled` 제거.

---

## 7. 리스크 & 완화

| 리스크 | 완화 |
|---|---|
| JVM 콜드스타트(15~40s) | 이관 잡은 전부 일/월/년 → 무해 |
| 이미지 크기(domain-rds 뚱뚱) | 수용. 진짜 슬림화는 domain-rds 분해(별도 트랙) |
| KST/UTC 혼동 | EventBridge Scheduler 타임존 사용 |
| 오버랩(긴 잡+다음 발화) | 저빈도라 희박. 필요 시 잡별 Redisson 락(이미 의존성 有) |
| 미스파이어(스케줄러 공백) | EventBridge는 관리형 HA — 인앱 대비 오히려 개선 |
| 컷오버 중 이중 실행 | `@ConditionalOnProperty` + 스케줄 disabled 생성 + 무겹침 창 전환 |

---

## 8. 범위 밖(후속)

- **domain-rds 외부 의존성 분리** — 별도 Linear 티켓(리팩토링). 이 이관을 블로킹하지 않음.
- **잔류 인앱 폴러 HA(옵션 3, ShedLock/분산락 + 롤링 배포)** — 필요 시 별도 검토.
