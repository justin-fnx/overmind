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
    wf1-context-gate.json   # WF1 · 기획 맥락 게이트   (id Y74XMZpTEUejToOQ)
    wf2-listener.json       # WF2 · Slack 리스너/재평가 (id 3LyKi5A20HoPrP0p)
    wf-snooze.json          # WF-Snooze · 스누즈 재질문 (id PpZ7nC12PWWet4DB)
```

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
