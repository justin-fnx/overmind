# n8n 워크플로우 형상관리 (사내 기획 자동화 — BOM-175)

`n8n.bomapp.co.kr` 의 워크플로우 정의를 **overmind 안에서 정본(source of truth)으로 관리**한다.
매번 API로 읽어 재구성하다 발생하던 편집 실수(모델 id 오기·서브노드 평면화·옵션 누락 등)를 없애기 위함이다.

## 왜 REST API 왕복인가

- n8n MCP의 `update_workflow` 는 **SDK 코드에서 워크플로우를 재생성** → 노드 크레덴셜이 `newCredential()` 이름 매칭(비결정적)으로 처리되어 **14개 노드 크레덴셜이 드롭/재연결** 강요.
- n8n **공개 REST API** 의 `GET/PUT /api/v1/workflows/{id}` 는 노드의 `credentials`(id+name 참조, 시크릿 아님)를 **그대로 왕복** → 파라미터만 고쳐 PUT 하면 크레덴셜·배선 무손상.
- 따라서 정본 JSON 을 git 에 두고, `sync.sh` 로 pull(내려받기)/push(올리기) 한다.

## 구조

```
n8n/
  README.md
  .env.example      # N8N_API_URL / N8N_API_KEY 양식 (실제 .env 는 gitignore)
  sync.sh           # pull/push 도구 (curl + jq)
  workflows/
    wf1-context-gate.json   # WF1 · 기획 맥락 게이트       (id Y74XMZpTEUejToOQ)
    wf2-listener.json       # WF2 · Slack 리스너/재평가     (id 3LyKi5A20HoPrP0p)
    wf-snooze.json          # WF-Snooze · 스누즈 재질문      (id PpZ7nC12PWWet4DB)
    wf-dispatch.json        # WF-Dispatch · 단계 디스패처    (id 0KSWtN1SPermSuFw)
    wf3-handoff.json        # WF3 · 단계 실행/서브태스크 생성 (id m6YGNNCEP5RI3SSF)
    wf-watch.json           # WF-Watch · 단계 완료 감시      (id Nivu3hdSDVlL5LrR)
    wf-enrich.json          # WF-Enrich · 완주 후 Hub upsert (id bPNVUvuHpaograNX)
    wf-cleanup.json         # WF-Cleanup · dedup 테이블 정리 (id LHLd2RloEwRUkWuS)
    wf-notion-read.json     # 서브WF · Notion 전문 읽기(표)  (id QHVMJ3uFEwlzumw3)
    figma-vision.json       # 서브WF · Figma 비전           (id YN6uIteF2X5BAo85)
    wf-reset.json           # WF-Reset · 기획 재검토 리셋    (id 40VRRfs2eAoTlsYH)
```

## 재검토(재실행) 트리거 — 체크박스 + WF-Reset

기획 검토는 **TASK DB(`fd91ec8d…`)의 `🔁 검토 요청` 체크박스**로 발화한다(최초 검토·재검토 동일).
과거의 "상태=리뷰대기 자동 폴링"은 폐지 — 명시적 클릭만 게이트를 돌린다.

- **WF1 트리거 필터**: `타입=기획 AND 🔁 검토 요청=true`. claim 시 체크박스를 즉시 해제(재포착·러너웨이 방지)하고 `🤖 AI 게이트=미검토` 기록.
- **WF1 → 재검토 리셋(executeWorkflow, 동기) → 게이트**: claim 직후 **WF-Reset**(`40VRRfs2eAoTlsYH`)을 호출해 이전 검토 흔적을 멱등 정리한 뒤 게이트를 돈다. 흔적이 없으면(최초 검토) no-op.
- **WF-Reset이 정리하는 흔적**(대상 page_id 기준):
  1. `stage_pipeline`(`16uFko9jgm6gFs0T`)의 각 `subtask_page_id` Notion 카드 → **아카이브**(`archived:true`, 상태값 `취소`는 status에 옵션이 없어 아카이브로 대체). 사용자 결정: 진행 중 서브태스크는 자동 취소·아카이브.
  2. `stage_pipeline` 행 삭제(parent_page_id) / `gate_threads`(`Kc7JZEVYgheNzZKo`) 행 삭제(page_id) / `enrich_log`(`KZccSviFYvgYA9e4`) 행 삭제(parent_page_id).
  3. 부모 카드 `🤖 정리된 브리프/맥락 점수/미결 질문/스누즈 횟수/다음 점검 시각` 초기화(AI 게이트는 WF1이 미검토로 관리하므로 건드리지 않음).
- **멱등성 함정**: dataTable `deleteRows`는 매칭 0건이면 0 items를 내보내 체인이 끊긴다 → 3개 delete 노드 모두 `alwaysOutputData:true`, `단계 행 삭제` 다중출력은 `단일화2`(Limit 1)로 수축해 항상 `부모 필드 초기화`까지 도달.
- (선택) 더 예쁜 UI는 Notion **Button** 프로퍼티를 만들어 동작=`🔁 검토 요청` 체크로 설정하면 됨(Notion API는 Button 생성 미지원 → 체크박스가 기계 플래그).

## 사용

```bash
cp .env.example .env      # N8N_API_URL, N8N_API_KEY 채우기 (gitignored)
./sync.sh pull            # 전체 워크플로우를 workflows/*.json 로 내려받기
./sync.sh pull wf1-context-gate
# JSON 편집 후
./sync.sh push wf1-context-gate   # 정본 JSON 을 n8n 에 반영 (크레덴셜 보존)
```

편집 워크플로우: **항상 `pull` 로 시작 → JSON 수정 → `push` → git commit.** n8n UI 에서 직접 고쳤다면 먼저 `pull` 해서 정본을 동기화한 뒤 커밋한다.

## 크레덴셜

- JSON 안의 `credentials` 는 **id+name 참조만**(시크릿 값 없음) — n8n 인스턴스에 실제 크레덴셜이 존재해야 동작.
- 현재 연결: Notion account(`b03vHUApw6s0O5jS`) / Botmap slackApi(`bjozecrw9OnFT8Lf`) / Figma account(`Rg6fKjWcdHHj0e1O`) / AWS (IAM) account(`GftVHJqfxQshQZ4P`).
- push 는 이 참조를 보존하므로 재연결 불필요.

## 현재 상태 / 미반영 작업

- **WF1 게이트 LLM = AWS Bedrock Amazon Nova Pro** 로 전환 중(구 Gemini, 503 회피).
  - IAM: 사용자 `n8n-bedrock-invoke` + Nova 호출 전용 정책 (infra TF, MR !46 머지 완료).
  - **모델 노드 설정 수정 필요** — `workflows/wf1-context-gate.json` 의 `AWS Bedrock Chat Model` 노드:
    `modelSource: "inferenceProfile"`, `model: "apac.amazon.nova-pro-v1:0"`,
    `options.temperature: 0.2`, `options.maxTokensToSample: 4000`.
    (on-demand `amazon.nova-pro-v1:0` 직접 호출은 미지원 → inference profile 필수.)
  - 적용: 위 JSON 수정 → `./sync.sh push wf1-context-gate` → n8n 에서 publish.
