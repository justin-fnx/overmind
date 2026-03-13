# Project Overmind: Microservices Orchestration Layer

## 1. Project Overview

**Overmind**은 분산된 마이크로서비스 환경에서 발생하는 Cross-cutting Concerns(여러 서비스에 걸친 변경 사항)을 중앙에서 조율하고 관리하는 **AI 기반의 오케스트레이션 에이전트**다.

### Core Problem

- 마이크로서비스(Git Repo)별로 파편화된 개발 세션은 시스템 전체를 관통하는 피쳐 개발이나 버그 수정 시 **맥락(Context)을 유지하기 어려움**.
- Linear 이슈와 실제 코드 변경 작업 간의 연결 고리가 느슨함.
- 서비스 간 의존 관계가 암묵적이어서, 한쪽의 변경이 다른 서비스에 미치는 영향을 사전에 파악하기 힘듦.

### Solution

- **Overmind (Team Leader):** 전체 시스템의 카탈로그와 의존성을 이해하는 중앙 관제 에이전트. 직접 코드를 수정하지 않고, 분석과 위임만 수행.
- **Worker Teammates:** 특정 리포지토리에서 격리된 환경으로 실행되는 하위 에이전트. 실제 코드 수정, 테스트, PR 생성을 담당.
- **MCP Integration:** Linear(이슈 트래킹)과 GitHub(코드 변경)를 양방향으로 동기화하여 작업의 전 과정을 추적 가능하게 함.

---

## 2. System Architecture

### 2.1. Claude Code Agent Teams 기반

Claude Code의 **Agent Teams** 기능이 Overmind에 필요한 핵심 인프라를 제공한다.

| Overmind 요구사항 | Agent Teams 제공 |
|-------------------|-----------------|
| Supervisor-Worker 패턴 | Leader-Teammate 구조 |
| Worker 격리 (리포별 컨텍스트) | 각 Teammate = 독립 Claude Code 인스턴스 |
| MCP 도구 접근 (Linear, GitHub) | 모든 Teammate이 MCP 서버 자동 로드 |
| 코드 편집/테스트/PR | Claude Code의 전체 편집 능력 내장 |
| Task 관리 + 의존성 | 공유 Task List + 자동 의존성 관리 |
| Human-in-the-loop | Plan Approval 모드 내장 |
| 병렬 실행 | 독립 Teammate 동시 실행 |
| Worker 간 통신 | 직접 메시징 (message / broadcast) |

**∴ Overmind는 커스텀 애플리케이션이 아니라, `CLAUDE.md` + `Service Catalog` + `MCP 설정`으로 Claude Code 세션을 Overmind Supervisor로 변환하는 구조.**

### 2.2. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      User / Trigger                          │
│                (Linear Ticket ID / CLI 명령)                  │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Overmind (Claude Code Team Leader)               │
│              [Delegation Mode 활성화]                          │
│                                                               │
│  Loaded Context:                                              │
│  ┌────────────────┐ ┌────────────────┐ ┌──────────────────┐  │
│  │   CLAUDE.md    │ │ services.yaml  │ │   Linear MCP     │  │
│  │ (행동 규칙)     │ │ (서비스 카탈로그) │ │ (이슈 트래킹)     │  │
│  └────────────────┘ └────────────────┘ └──────────────────┘  │
│                                                               │
│  Workflow:                                                    │
│  Analyze → Plan → Delegate → Verify & Review → Finalize      │
│                                                               │
└───────────┬────────────┬────────────┬────────────────────────┘
            │            │            │
    ┌───────▼──┐  ┌──────▼───┐  ┌────▼─────┐
    │Teammate A│  │Teammate B│  │Teammate C│
    │user-svc  │  │order-svc │  │pay-svc   │
    │          │  │          │  │          │
    │ Context: │  │ Context: │  │ Context: │
    │ CLAUDE.md│  │ CLAUDE.md│  │ CLAUDE.md│
    │ MCP svrs │  │ MCP svrs │  │ MCP svrs │
    └────┬─────┘  └────┬─────┘  └────┬─────┘
         │             │             │
         ▼             ▼             ▼
    [Git Repo A]  [Git Repo B]  [Git Repo C]
```

### 2.3. The Overmind (Team Leader)

- **Mode:** Delegation Mode (코드를 직접 수정하지 않고, 조율 전용 도구만 사용).
- **Available Tools:** Teammate 생성, 메시징, 종료, Task 관리.
- **Loaded Context:** `CLAUDE.md`(행동 규칙) + `services.yaml`(서비스 카탈로그) + Linear MCP.
- **Responsibilities:**
  1. Linear 이슈 분석 및 요구사항 구조화.
  2. `services.yaml`을 참조하여 영향받는 서비스 식별.
  3. 서비스 간 의존 관계를 고려한 Task 생성 (의존성 포함).
  4. Linear 하위 이슈 생성 시 **인수 조건(Acceptance Criteria)을 반드시 명시**.
  5. Teammate 생성 및 작업 할당.
  6. Teammate 완료 보고 시 **인수 조건 대비 검증** 수행.
  7. 검증 통과 후 **PR 리뷰** 실행.
  8. 최종 결과 취합 및 Linear 리포팅.

### 2.4. The Workers (Teammates)

- **Role:** 각각 독립적인 Claude Code 인스턴스로 실행.
- **Isolation:** 할당된 리포지토리 디렉토리에서만 작업. 다른 Teammate의 작업 공간에 접근 불가.
- **Context:** `CLAUDE.md` + MCP 서버를 자동으로 로드. Leader의 대화 기록은 상속하지 않음 — 생성 프롬프트에 필요한 컨텍스트를 명시적으로 전달.
- **Responsibilities:**
  1. 할당된 리포지토리에서 피쳐 브랜치 생성.
  2. Leader가 전달한 Spec을 기반으로 코드 수정.
  3. 테스트/린트 실행 및 결과 보고.
  4. PR 생성 및 Diff 요약을 Leader에게 메시지로 보고.
- **Execution Model:**
  - 의존 관계가 없는 Task의 Teammate들은 **동시 실행**.
  - 의존 관계가 있는 경우, Task List의 의존성이 자동으로 해소된 후 다음 Teammate이 해당 Task를 claim.

### 2.5. Communication Flow

```
Leader → Teammate:  생성 프롬프트 (작업 지시 + 필요한 컨텍스트)
Teammate → Leader:  완료 보고 (PR 링크, 변경 사항 요약, 에러 발생 시 상세)
Leader → Teammate:  인수 조건 미충족 시 보완 지시
Teammate → Teammate:  직접 메시징 (선행 Worker의 변경 사항을 후행 Worker에 전달)
Leader → All:       broadcast (전체 계획 변경, 긴급 중단 등)
```

### 2.6. MCP Integration

| Tool | 용도 | 사용 주체 |
|------|------|-----------|
| **Linear MCP** | 이슈 조회, 하위 이슈 생성(인수 조건 포함), 댓글 작성, 상태 업데이트 | Leader (주), Teammate (읽기) |
| **GitHub MCP** | 브랜치 관리, 파일 읽기/쓰기, PR 생성, **PR 리뷰** | Leader (리뷰), Teammate (PR 생성) |
| **Shell** | 테스트 실행, 빌드, Lint | Teammate |

모든 MCP 서버는 프로젝트의 `.claude/settings.json`에 설정하며, Leader와 모든 Teammate이 동일하게 로드한다.

---

## 3. Key Data Structures

### 3.1. Service Catalog (`services.yaml`)

시스템 내 모든 마이크로서비스의 메타데이터 정의. Leader가 영향 분석 및 작업 계획 수립에 사용.

```yaml
services:
  - name: "order-service"
    repo_url: "github.com/org/order-service"
    path: "./services/order"
    description: "주문 처리 및 결제 상태 관리"
    tech_stack: ["go", "grpc", "postgres"]
    critical_paths:
      - path: "src/domain/orders"
        description: "주문 기능 (생성, 취소, 상태 변경)"
      - path: "src/domain/payment"
        description: "결제 상태 관리 및 PG 연동 인터페이스"
      - path: "api/proto/v1"
        description: "gRPC API 정의 (외부 서비스 계약)"
    dependencies:
      - service: "payment-service"
        type: "sync"           # sync | async | data-only
        interface: "grpc"      # grpc | rest | event | db
        contract: "api/proto/v1/payment.proto"
      - service: "user-service"
        type: "sync"
        interface: "grpc"
        contract: "api/proto/v1/user.proto"
    test_command: "make test"
    lint_command: "make lint"

  - name: "payment-service"
    repo_url: "github.com/org/payment-service"
    path: "./services/payment"
    description: "PG사 연동 및 결제 승인"
    tech_stack: ["node", "typescript", "redis"]
    critical_paths:
      - path: "src/handlers"
        description: "결제 요청 핸들러 (승인, 취소, 환불)"
      - path: "src/providers"
        description: "PG사별 어댑터 (토스, 나이스 등)"
    dependencies: []
    test_command: "npm test"
    lint_command: "npm run lint"

  - name: "user-service"
    repo_url: "github.com/org/user-service"
    path: "./services/user"
    description: "사용자 인증 및 프로필 관리"
    tech_stack: ["go", "grpc", "postgres"]
    critical_paths:
      - path: "src/domain/user"
        description: "사용자 도메인 (가입, 인증, 프로필)"
      - path: "src/domain/auth"
        description: "인증/인가 로직 (JWT, 세션)"
      - path: "api/proto/v1"
        description: "gRPC API 정의 (외부 서비스 계약)"
    dependencies: []
    test_command: "make test"
    lint_command: "make lint"
```

**주요 필드 설명:**
- `critical_paths[].path` / `description`: 디렉토리 경로와 해당 경로가 담당하는 기능을 함께 명시. Leader가 어떤 경로가 영향받는지 판단하고, Teammate이 코드 탐색 시 우선순위를 정하는 데 활용.
- `dependencies.type` / `interface` / `contract`: 서비스 간 연결 방식과 계약(Contract) 파일 위치를 명시. Leader가 변경 전파 경로를 파악하는 핵심 정보.
- `test_command` / `lint_command`: Teammate이 코드 수정 후 자동으로 검증 단계를 실행.

### 3.2. CLAUDE.md (Leader 행동 규칙)

Agent Teams에서는 프로그래밍 코드 대신 `CLAUDE.md`가 에이전트의 행동을 정의한다. 이것이 Overmind의 "소스 코드"에 해당.

```markdown
# Overmind: Microservices Orchestration Leader

## Role
당신은 마이크로서비스 시스템의 오케스트레이션 리더다. 코드를 직접 수정하지 않는다.
분석, 계획 수립, 작업 위임, 검증, 결과 취합만 수행한다.

## Workflow

### 1. Analyze
- Linear 이슈를 읽고 요구사항을 구조화한다.
- `services.yaml`을 읽어 Service Catalog를 로드한다.
- 변경이 필요한 서비스를 식별하고, 서비스 간 dependency를 확인한다.

### 2. Plan
- 영향받는 각 서비스에 대해 Task를 생성한다.
- dependency가 있는 Task에는 blockedBy를 설정한다.
- Linear에 하위 이슈를 생성한다.
  - **반드시 인수 조건(Acceptance Criteria)을 명시한다.**
  - 인수 조건은 검증 가능하고 구체적이어야 한다.
  - 예시:
    - "User ID 필드가 UUID v7 형식으로 생성된다"
    - "user.proto의 id 필드 타입이 string이다"
    - "기존 단위 테스트가 모두 통과한다"
    - "UUID 형식 검증 테스트가 추가되어 있다"
- 계획을 요약하여 사용자 승인을 요청한다.

### 3. Delegate
- 각 Task에 대해 Teammate을 생성한다.
- Teammate 생성 프롬프트에 반드시 포함할 것:
  - 작업 대상 리포지토리 경로
  - 구체적인 수정 사항 (무엇을, 어디서, 왜)
  - 해당 Linear 하위 이슈의 인수 조건 전문
  - 선행 작업의 변경 산출물 (있을 경우)
  - test_command, lint_command
  - "Plan approval을 요구한다" (복잡한 변경일 경우)
- Teammate이 완료될 때까지 기다린다. 직접 구현을 시작하지 않는다.

### 4. Verify & Review
Teammate이 완료를 보고하면 다음 두 단계를 순서대로 수행한다:

#### 4a. 인수 조건 검증
- 해당 Linear 하위 이슈의 인수 조건을 다시 읽는다.
- Teammate의 보고 내용(변경 사항 요약, 테스트 결과)과 인수 조건을 하나씩 대조한다.
- 모든 인수 조건이 충족되었는지 확인한다.
- 미충족 항목이 있으면:
  - 구체적으로 어떤 조건이 미충족인지 Teammate에게 메시지로 전달.
  - Teammate이 보완 작업을 완료할 때까지 대기.
  - 보완 완료 후 다시 검증 반복.

#### 4b. PR 리뷰
- 인수 조건이 모두 충족되면, Teammate이 생성한 PR을 리뷰한다.
- 리뷰 관점:
  - 코드 품질 및 스타일 일관성
  - 변경 범위가 요구사항에 부합하는지 (과도한 변경 없는지)
  - 보안 취약점 여부
  - 서비스 간 계약(Contract) 호환성
- 리뷰 결과를 PR 코멘트로 작성한다.
- 수정이 필요하면 Teammate에게 피드백 전달 후 재작업 대기.

### 5. Finalize
- 모든 Task의 인수 조건 충족 및 PR 리뷰 완료 확인.
- Linear 메인 티켓에 결과 코멘트 작성 (PR 링크 목록 + 인수 조건 충족 요약).
- Teammate 종료 및 팀 정리.

## Rules
- Delegation Mode를 사용한다 (코드 직접 수정 금지).
- Teammate이 완료될 때까지 기다린다. 직접 구현을 시작하지 않는다.
- Teammate 생성 시 충분한 컨텍스트를 프롬프트에 포함한다.
- 동일 파일을 여러 Teammate이 편집하지 않도록 작업을 분리한다.
- Linear 하위 이슈에는 반드시 인수 조건을 작성한다.
- Teammate 완료 보고를 받으면 반드시 인수 조건 검증 → PR 리뷰 순서를 따른다.
```

### 3.3. Task Structure (Agent Teams 내장)

Agent Teams의 Task List로 실행 계획을 관리한다.

```
Task 1: [user-service] ID 생성 로직 UUID 변경
  - status: pending → in_progress → completed
  - owner: teammate-A

Task 2: [order-service] User ID FK 타입 변경
  - status: pending (blocked)
  - blockedBy: [Task 1]
  - owner: (unassigned → teammate-B가 자동 claim)
```

---

## 4. Operational Workflow

### 4.1. Scenario: "User ID 체계를 UUID로 변경"

```
[1] Trigger
    └→ 사용자가 Overmind Leader에게 Linear 티켓 ID 전달
       "LIN-142 작업을 진행해줘. 에이전트 팀을 구성해서 처리해."

[2] Analyze (Leader)
    ├→ Linear MCP로 LIN-142 내용 조회
    ├→ services.yaml 로드
    └→ 영향 분석:
       ├ user-service: ID 생성 로직이 있으므로 변경 필요
       │  └ critical_path: "src/domain/user" (사용자 도메인)
       ├ order-service: user_id FK 참조하므로 변경 필요
       │  └ critical_path: "src/domain/orders" (주문 기능)
       └ dependency: order-service → user-service (proto contract)
         ∴ user-service 선행

[3] Plan (Leader → Linear + Task List)
    ├→ Linear에 하위 이슈 2개 생성 (인수 조건 포함):
    │   ├ Sub-1: [user-service] ID 생성 로직 UUID 변경 및 Proto 수정
    │   │  인수 조건:
    │   │  - [ ] User ID가 UUID v7 형식으로 생성된다
    │   │  - [ ] user.proto의 id 필드 타입이 string이다
    │   │  - [ ] 기존 단위 테스트가 모두 통과한다
    │   │  - [ ] UUID 형식 검증 테스트가 추가되어 있다
    │   │
    │   └ Sub-2: [order-service] User ID FK 타입 변경 (blocked by Sub-1)
    │      인수 조건:
    │      - [ ] user_id 컬럼 타입이 string(UUID)이다
    │      - [ ] 변경된 user.proto를 정상적으로 import한다
    │      - [ ] 기존 단위 테스트가 모두 통과한다
    │
    ├→ Agent Teams Task List에 2개 Task 생성 (blockedBy 설정)
    └→ 사용자에게 계획 요약 보고, 승인 요청

[4] Approval Gate
    └→ 사용자 승인

[5] Spawn Teammate A (Leader → user-service)
    Leader가 다음 프롬프트로 Teammate 생성:
    ┌──────────────────────────────────────────────────────────┐
    │ "당신은 user-service 전담 개발자다.                        │
    │  작업 디렉토리: ./services/user                           │
    │  수정 내용: User ID 생성 로직을 auto-increment에서          │
    │  UUID v7으로 변경. user.proto의 id 필드를 string으로 변경.  │
    │  critical_paths:                                          │
    │    - src/domain/user (사용자 도메인)                       │
    │    - api/proto/v1 (gRPC API 정의)                         │
    │                                                           │
    │  인수 조건:                                                │
    │  1. User ID가 UUID v7 형식으로 생성된다                     │
    │  2. user.proto의 id 필드 타입이 string이다                  │
    │  3. 기존 단위 테스트가 모두 통과한다                         │
    │  4. UUID 형식 검증 테스트가 추가되어 있다                    │
    │                                                           │
    │  완료 후: make test && make lint 실행.                     │
    │  PR을 생성하고, 변경된 user.proto 내용을 리더에게 보고.       │
    │  Plan approval을 요구한다."                                │
    └──────────────────────────────────────────────────────────┘

[6] Teammate A 실행
    ├→ (Plan 모드) 계획 수립 → Leader 승인
    ├→ feat/uuid-migration 브랜치 생성
    ├→ user.proto, ID 생성 로직 수정
    ├→ make test && make lint 실행
    ├→ PR 생성
    └→ Leader에게 메시지: "완료. PR: [link]. 변경된 proto: ..."

[7] Verify & Review — Task 1 (Leader)
    ├→ 인수 조건 검증:
    │   ├ ✅ UUID v7 형식 생성 — Teammate 보고에서 확인
    │   ├ ✅ user.proto id 필드 string — diff에서 확인
    │   ├ ✅ 기존 테스트 통과 — test 결과에서 확인
    │   └ ✅ UUID 검증 테스트 추가 — diff에서 확인
    ├→ PR 리뷰:
    │   ├ 코드 품질 확인
    │   ├ 변경 범위 적절성 확인
    │   └ PR에 리뷰 코멘트 작성
    └→ Task 1 완료 → Task 2 unblock

[8] Spawn Teammate B (Leader → order-service)
    Leader가 Teammate A의 보고 내용을 포함하여 Teammate B 생성:
    ┌──────────────────────────────────────────────────────────┐
    │ "당신은 order-service 전담 개발자다.                       │
    │  작업 디렉토리: ./services/order                          │
    │  선행 변경 사항: user.proto의 id 필드가 int64에서 string    │
    │  (UUID v7)으로 변경됨. 변경된 proto:                       │
    │  [변경된 user.proto 내용 전문]                              │
    │  수정 내용: user_id FK 타입을 int에서 string으로 변경.       │
    │  관련 import 및 타입 캐스팅 수정.                           │
    │  critical_paths:                                          │
    │    - src/domain/orders (주문 기능)                         │
    │    - api/proto/v1 (gRPC API 정의)                         │
    │                                                           │
    │  인수 조건:                                                │
    │  1. user_id 컬럼 타입이 string(UUID)이다                   │
    │  2. 변경된 user.proto를 정상적으로 import한다               │
    │  3. 기존 단위 테스트가 모두 통과한다                         │
    │                                                           │
    │  완료 후: make test && make lint 실행.                     │
    │  PR을 생성하고 결과를 리더에게 보고."                        │
    └──────────────────────────────────────────────────────────┘

[9] Teammate B 실행
    ├→ feat/uuid-migration 브랜치 생성
    ├→ FK 타입 변경, import 수정
    ├→ make test && make lint 실행
    └→ PR 생성 → Leader에게 보고

[10] Verify & Review — Task 2 (Leader)
     ├→ 인수 조건 검증:
     │   ├ ✅ user_id 컬럼 타입 string — diff에서 확인
     │   ├ ✅ user.proto import 정상 — 빌드 성공에서 확인
     │   └ ✅ 기존 테스트 통과 — test 결과에서 확인
     ├→ PR 리뷰:
     │   ├ 코드 품질 확인
     │   ├ 서비스 간 계약 호환성 확인
     │   └ PR에 리뷰 코멘트 작성
     └→ Task 2 완료

[11] Finalize (Leader)
     ├→ 모든 Task 인수 조건 충족 + PR 리뷰 완료 확인
     ├→ Linear LIN-142에 코멘트:
     │   "2개 서비스 수정 완료. 인수 조건 모두 충족.
     │    - user-service: PR #45 (ID → UUID v7) ✅ reviewed
     │    - order-service: PR #78 (FK 타입 변경) ✅ reviewed
     │    리뷰 부탁드립니다."
     ├→ LIN-142 상태 → In Review
     ├→ Teammate 종료 요청
     └→ 팀 정리
```

### 4.2. Failure Handling

| 실패 유형 | 대응 |
|-----------|------|
| Teammate 테스트 실패 | Leader가 에러 로그를 확인하고 해당 Teammate에게 메시지로 수정 지시 |
| Teammate Lint 실패 | Teammate이 자체적으로 수정 시도 (Claude Code 내장 능력) |
| 인수 조건 미충족 | Leader가 미충족 항목을 구체적으로 Teammate에게 전달, 보완 작업 지시 |
| PR 리뷰에서 문제 발견 | Leader가 리뷰 코멘트와 함께 Teammate에게 수정 요청 |
| Teammate이 구조적 문제로 중단 | Leader가 Linear에 코멘트로 에스컬레이션, 해당 Task를 failed로 마킹 |
| 선행 Task 실패 | 후행 Task는 blockedBy로 자동 차단 유지. Leader가 사용자에게 보고 |
| Teammate 응답 없음 | Leader가 직접 메시지로 확인. 필요 시 종료 후 대체 Teammate 생성 |

---

## 5. Implementation Roadmap

커스텀 코드 대신 **설정 파일과 프롬프트 엔지니어링**이 핵심.

### Phase 1: Foundation (Week 1)

**목표:** Service Catalog + CLAUDE.md 기반으로 Leader가 동작하는 것을 확인.

- [ ] 프로젝트 디렉토리 구조 셋업
- [ ] `services.yaml` 스키마 정의 및 샘플 데이터 작성
- [ ] `CLAUDE.md` 작성 (Leader 행동 규칙)
- [ ] `.claude/settings.json` 설정 (Agent Teams 활성화, MCP 서버 등록)
- [ ] 테스트 리포지토리 2~3개 준비 (간단한 Go/Node 서비스)
- [ ] Mock 실행: Leader에게 "services.yaml을 읽고 영향 분석해봐"로 동작 확인

### Phase 2: Linear Integration (Week 2)

**목표:** Linear 이슈 → 분석 → 인수 조건 포함 하위 이슈 생성까지의 흐름 검증.

- [ ] Linear MCP 설정 및 연동 확인
- [ ] CLAUDE.md에 Linear 워크플로우 규칙 추가 (인수 조건 필수 작성 규칙 포함)
- [ ] 실제 Linear 이슈로 end-to-end 테스트:
  - 이슈 읽기 → 영향 분석 → 인수 조건 포함 하위 이슈 생성 → 계획 보고

### Phase 3: Agent Team Execution (Week 3-4)

**목표:** Leader가 Teammate을 생성하여 실제 코드 수정 + PR 생성 + 검증까지 수행.

- [ ] Teammate 생성 프롬프트 템플릿 최적화
- [ ] Plan Approval 모드 테스트 (Teammate이 계획 먼저 세우고 Leader 승인)
- [ ] 단일 서비스 수정 시나리오 검증
- [ ] 다중 서비스 수정 시나리오 검증 (의존 관계 포함)
- [ ] 인수 조건 검증 흐름 테스트 (충족 / 미충족 → 보완 지시)
- [ ] Leader PR 리뷰 흐름 테스트
- [ ] Failure 시나리오 테스트 (테스트 실패, 구조적 문제)

### Phase 4: Hardening (Week 5-6)

**목표:** 프롬프트 안정성과 운영 가시성 확보.

- [ ] CLAUDE.md 규칙 반복 개선 (엣지 케이스 처리)
- [ ] 실행 결과 로깅 (Linear 코멘트에 상세 기록)
- [ ] 비용 모니터링: 실행당 토큰 사용량 트래킹
- [ ] Delegation Mode 안정화 (Leader가 직접 코드를 건드리지 않도록)
- [ ] CLI wrapper 스크립트: `./overmind.sh <ticket-id>` 형태의 편의 진입점

---

## 6. Tech Stack

| 영역 | 선택 | 근거 |
|------|------|------|
| **Orchestration** | Claude Code Agent Teams | Leader-Teammate, Task 관리, 병렬 실행, Human-in-the-loop이 내장. 별도 프레임워크 없이 동작. |
| **Agent Runtime** | Claude Code CLI | 각 Teammate이 독립 Claude Code 인스턴스. 코드 편집, 셸, Git, MCP 도구 내장. |
| **LLM** | Claude Sonnet 4.5 (Teammate), Claude Opus 4.6 (Leader) | Leader에는 추론 능력이 우수한 Opus, Teammate에는 속도와 비용 효율이 좋은 Sonnet. |
| **MCP** | Linear MCP, GitHub MCP | 이슈 트래킹과 코드 관리를 에이전트 도구로 노출. |
| **Config** | YAML (catalog) + CLAUDE.md (행동 규칙) + .env (secrets) | 별도 코드 없이 설정 파일만으로 시스템 구성. |
| **Display** | tmux 분할 창 모드 (권장) | 각 Teammate의 작업 진행 상황을 실시간으로 확인 가능. |

---

## 7. Key Design Decisions & Trade-offs

### 7.1. Agent Teams 설계 근거

**선택 이유:**
- Overmind가 필요로 하는 핵심 인프라(Worker 격리, Task 관리, 병렬 실행, Human-in-the-loop)가 내장.
- 커스텀 코드 대신 `CLAUDE.md`와 `services.yaml`만으로 동작하여 구현 비용이 낮음.
- 각 Teammate이 Claude Code의 전체 능력(코드 편집, 셸, Git, MCP)을 그대로 사용. 별도 tool 구현 불필요.
- Teammate 간 직접 메시징으로 별도의 상태 관리 레이어 불필요.

**알려진 제약:**
- **실험적 기능:** Agent Teams는 아직 experimental. 세션 재개 불가, 중첩 팀 불가 등 제약 존재.
- **자연어 의존:** 조건부 라우팅이나 상태 관리를 코드로 정밀하게 제어할 수 없음. CLAUDE.md의 자연어 규칙에 의존.
- **구조화된 상태 부재:** 타입 안전한 상태 전달 대신 자연어 메시지 기반. 정보 손실 가능성 있음.
- **비용:** 각 Teammate이 독립 Claude 인스턴스이므로 토큰 사용량이 높을 수 있음.

### 7.2. Leader가 코드를 수정하지 않는 이유

- Delegation Mode를 활성화하여 Leader를 조율 전용으로 제한.
- Leader가 코드를 직접 건드리면 Teammate과 작업 충돌이 발생하거나 컨텍스트 윈도우가 포화됨.
- 역할 분리가 명확할수록 실패 시 해당 Teammate만 재시도하면 되므로 복구가 간단.

### 7.3. 컨텍스트 전달 전략

Teammate은 Leader의 대화 기록을 상속하지 않으므로, 생성 프롬프트에 필요한 모든 컨텍스트를 명시적으로 포함해야 한다. 이것은 제약이 아니라 장점:
- 각 Teammate의 컨텍스트가 최소한으로 유지되어 토큰 효율적.
- 서비스 간 불필요한 내부 구현 세부사항이 전파되지 않음 (마이크로서비스 원칙과 일치).
- 선행 작업의 결과는 **인터페이스 변경 사항**(Proto, API 스키마)만 전달.

### 7.4. 인수 조건 기반 검증

Teammate의 "완료" 보고를 그대로 신뢰하지 않는다. Leader가 Linear 하위 이슈의 인수 조건을 기준으로 이중 검증하는 이유:
- LLM은 작업 완료를 낙관적으로 보고하는 경향이 있음. 인수 조건이라는 객관적 기준으로 검증.
- 인수 조건은 이슈 생성 시점에 정의되므로, 작업 도중 범위가 흐려지는 것을 방지.
- 인수 조건 미충족 시 구체적인 피드백을 Teammate에게 전달할 수 있어 보완 작업이 정확해짐.

### 7.5. Leader의 자동 PR 리뷰

인수 조건 검증 이후 Leader가 PR을 직접 리뷰하는 이유:
- Teammate은 자신이 작성한 코드의 문제를 스스로 발견하기 어려움 (자기 검증의 한계).
- Leader는 전체 시스템 맥락을 가지고 있으므로, 개별 PR이 다른 서비스에 미치는 영향을 판단할 수 있음.
- 사람의 최종 리뷰 전에 자동화된 1차 리뷰로 품질을 높이고, 사람의 리뷰 부담을 줄임.
- PR 리뷰 코멘트가 GitHub에 기록되어 변경 이력의 일부로 남음.

### 7.6. Human-in-the-loop 전략

두 단계의 승인 게이트:
1. **Leader 레벨:** 사용자가 전체 실행 계획을 승인.
2. **Teammate 레벨:** 복잡한 변경 시 Plan Approval 모드를 적용하여 Leader가 Teammate의 계획을 승인.

이후 신뢰도가 쌓이면 단순 작업(린트 수정, 의존성 업데이트 등)에 대해 자동 승인 도입 가능.

---

## 8. Risks & Mitigations

| 리스크 | 영향 | 완화 방안 |
|--------|------|-----------|
| Agent Teams 실험적 기능 불안정 | 세션 중단, 작업 유실 | Linear에 중간 결과를 지속적으로 기록. 각 Teammate의 PR은 독립적이므로 부분 성과 보존. |
| LLM 환각으로 인한 잘못된 코드 수정 | 서비스 장애 | 인수 조건 검증 + Leader PR 리뷰 + 사람의 최종 리뷰로 3중 안전망. |
| Teammate 생성 프롬프트 부족 | 잘못된 방향의 코드 수정 | 프롬프트 템플릿 표준화. Plan Approval로 사전 검증. |
| 인수 조건 부정확/불충분 | 검증 무의미화 | Leader가 인수 조건 작성 시 구체적이고 검증 가능한 형태를 강제 (CLAUDE.md 규칙). |
| Leader PR 리뷰 품질 | 잘못된 코드 통과 | Leader 리뷰는 1차 필터. 사람의 최종 리뷰를 생략하지 않음. |
| 동일 파일 편집 충돌 | 덮어쓰기, 코드 손실 | 작업 분리 원칙 준수 (CLAUDE.md에 명시). 서비스별 Teammate 할당. |
| Service Catalog 정보 부정확 | 잘못된 영향 분석 | Catalog를 코드와 함께 버전 관리. 정기적 검증. |
| 토큰 비용 폭발 | 예산 초과 | 실행당 비용 트래킹. Teammate 수 제한. Sonnet 모델 우선 사용. |
| Leader가 Delegation Mode를 벗어남 | 작업 충돌 | CLAUDE.md에 규칙 명시. |

---

## 9. Prerequisites & Setup

Overmind를 실행하기 위한 사전 요구사항:

```bash
# 1. Claude Code CLI 설치 (최신 버전)
# https://code.claude.com/docs/installation

# 2. Agent Teams 활성화
# .claude/settings.json에 추가:
# { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }

# 3. tmux 설치 (분할 창 모드용, 선택)
brew install tmux

# 4. MCP 서버 설정
# .claude/settings.json에 Linear MCP, GitHub MCP 설정

# 5. 실행
claude --teammate-mode tmux
# 또는 iTerm2 사용 시 자동 감지
```

---

## 10. Future Considerations (Scope 밖, 참고용)

- **Custom CLI Wrapper:** `overmind run <ticket-id>` 명령으로 Claude Code 세션을 자동 시작하고, services.yaml 로드, Agent Teams 설정을 자동화하는 쉘 스크립트 또는 Python CLI.
- **자동 롤백:** 배포 후 모니터링 메트릭 이상 시 자동 revert PR 생성.
- **학습 루프:** 과거 성공/실패 패턴을 메모리에 저장하여 계획 수립 정확도 향상.
- **Slack/Discord 알림:** 실행 상태를 팀 채널에 실시간 보고.
- **배포 파이프라인 연동:** PR 머지 후 자동 배포 트리거 (ArgoCD, GitHub Actions).
