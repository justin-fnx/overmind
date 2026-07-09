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

## 보안 — 외부 노출 표면 (2026-07-01 검토)

전체 검토·잔여 조치: `../docs/n8n-external-exposure-review.md`.

- **공개 웹훅(`n8n-webhook.bomapp.co.kr/webhook/*`)은 crown-jewel 표면**(뚫리면 Notion/GitLab/ES/Slack 자산 유출). 새 워크플로우 트리거를 공개 웹훅으로 둘 땐 반드시 인증(headerAuth)·서명검증을 건다.
- **워크플로우끼리의 내부 호출은 공개 웹훅 금지.** `executeWorkflow`(일반) / `toolWorkflow`(에이전트 툴)로 인프로세스 호출한다. 과거 `wf-dispatch`·`wf3-handoff`·`figma-vision`이 공개 무인증 웹훅으로 서로를 호출하던 것을 2026-07-01 전부 `executeWorkflowTrigger` 서브워크플로우로 전환해 엔드포인트를 제거했다.
  - **⚠️ 폴링 디스패처의 `waitForSubWorkflow` 함정(2026-07-06 수정): WF-Watch(2분 폴링)의 `WF3 호출`을 `waitForSubWorkflow:true`(동기 대기)로 두면, 멱등 가드(`status 갱신` pending→dispatched)가 느린 WF3(LLM 에이전트, 3~5분) 완료 후에야 실행된다.** 그 사이 2분 폴링이 겹쳐 발화해 같은 단계를 반복 디스패치(디자인 완료→FE 태스크 3중 생성; WF3 실행 24637/24641/24647 이 2분 간격 겹침으로 확인). 전환 이전 httpRequest fire-and-forget 는 즉시 반환→가드 즉시 플립이라 레이스가 없었다. **해결: WF-Watch `WF3 호출` = `waitForSubWorkflow:false`(pass-through 즉시 반환 → `status 갱신` 이 폴링 내 ~1s 에 가드 플립, `$('디스패치 판정').item` 페어링도 보존).** 폴링으로 서브WF를 fan-out 하는 디스패처는 **가드를 서브WF 대기 전에 커밋**해야 한다.
  - **executeWorkflowTrigger 전환 시 하위 노드 입력 읽기 점검(2026-07-06 수정):** 웹훅→executeWorkflowTrigger 전환 후에도 하위 Code 노드가 옛 `$json.body.X`(webhook 형태)를 읽으면 값이 전부 `undefined`. WF3 `착수 컨텍스트`가 `$('WF3 시작').json.body||{}` 로 `qa` 를 읽어 전환 후 **기획 Q&A 가 착수 게이트에 빈값으로 전달**되던 것을 `body||top-level` 폴백으로 수정. (`스테이지·페르소나 결정`은 이미 `$json.body||$json` 방어코드가 있어 pageId 등은 정상이었음.)
- 현재 외부 POST 표면 = `ai-review-request`(WF1, headerAuth) · `overmind-slack-interactions`(WF2, Slack) · `botmap-slack-events`(봇맵, Slack). **Slack 2종은 서명검증(HMAC+리플레이) 적용됨**(웹훅 rawBody→`서명 준비`→`Slack HMAC`(Crypto, 크레덴셜 `Slack Signing Secret`=`hmacSecret:{{$env.SLACK_SIGNING_SECRET}}`)→`서명 판정`; 위조 드롭 라이브 검증). ⚠️ Code 노드는 crypto 차단 → HMAC은 Crypto 노드+crypto 크레덴셜로만.
  - **⚠️ raw body 함정(2026-07-06 수정): 이 n8n 인스턴스는 `application/x-www-form-urlencoded` 바디(=Slack 인터랙티브 버튼/모달 페이로드)를 `$json.body` 로 파싱해버리고 `rawBody`/binary 를 비운다.** 그래서 WF2 `서명 준비`가 `wh.binary.data.data` 에서 raw 를 읽으면 항상 `''` → basestring 이 `v0:{ts}:` → HMAC 이 **정상·위조 무관 전부 불일치 → 드롭**(버튼 무반응). 초기 "위조 드롭" 검증이 통과처럼 보인 건 전부 드롭했기 때문(정상 경로 미검증). **해결: `서명 준비`가 `body.payload` 에서 원본 폼 바디를 복원한다 — `raw='payload='+slackForm(body.payload)`, 여기서 `slackForm`=RFC3986 percent-encoding + 공백 `+` + `!'()*`도 escape(= 표준 form-urlencoded/`encodeURIComponent` 아님).** 실패 실행 exec 24710 의 payload 로 복원 바이트가 `content-length`(3645)와 byte-exact 일치 검증. `서명 준비` 는 자기검증용으로 `rawLen`/`contentLength` 를 출력(둘이 같아야 HMAC 성공). **botmap 은 `application/json` 이벤트라 이 함정과 무관(정상 동작).**
- 에디터/REST(`n8n.bomapp.co.kr`)는 공개 IP에 Host 헤더로 도달 가능 → nginx에서 VPN/사무실 CIDR로 폐쇄 권고(인프라).

## (재)검토 트리거 — Notion 버튼 → 인증 웹훅 + WF-Reset

기획 검토는 **TASK DB(`fd91ec8d…`)의 `🔁 AI 검토 요청` 버튼(button 타입)** 클릭으로 발화한다(최초 검토·재검토 동일). 폴링 없음.

- **트리거 = 웹훅(폴링 폐지)**: WF1 트리거는 `scheduleTrigger`가 아니라 **Webhook 노드 `검토 요청 수신`**.
  공개 URL `https://n8n-webhook.bomapp.co.kr/webhook/ai-review-request` (POST).
- **인증(필수, 비용 폭탄 방지)**: 웹훅 노드 `authentication: headerAuth` + 크레덴셜 **`Notion Webhook Token`(`httpHeaderAuth`, id `xuAMs5mpZiSnoXgI`)** — 헤더 `X-Webhook-Token`. 토큰 없거나 틀리면 **403 + 실행 미생성**(게이트=Bedrock 호출 0). Notion 버튼의 "웹훅 보내기" 동작에 **커스텀 헤더 `X-Webhook-Token: <시크릿>`** 을 넣어야 통과(시크릿 값은 n8n 크레덴셜에만 저장, git 미보관).
- **page id 전달**: Notion 버튼 웹훅 페이로드는 `body.data`에 클릭한 행의 **전체 페이지 객체**(`body.data.id` = 페이지 UUID, `body.data.properties.*`)를 POST. WF1은 `검토 요청 수신` 다음 노드 **`리뷰대기 태스크 조회`(notion databasePage **get** by `body.data.id`, simple:false)** 로 단건 조회 → 출력 shape가 기존 폴링과 동일해 하위 노드(claim·게이트 등) 무수정 재사용.
- **WF1 흐름**: 검토 요청 수신(webhook) → 리뷰대기 태스크 조회(get by id) → 검토 착수 기록(`🤖 AI 게이트=미검토`) → **재검토 리셋(executeWorkflow 동기) → 게이트**.
- **WF-Reset(`40VRRfs2eAoTlsYH`, active 필수)** — claim 직후 호출, 이전 검토 흔적 멱등 정리(흔적 없으면 no-op):
  1. `stage_pipeline`(`16uFko9jgm6gFs0T`)의 각 `subtask_page_id` Notion 카드 → **아카이브**(`archived:true`; status에 '취소' 옵션 없어 아카이브로 대체). 진행 중 서브태스크 자동 취소·아카이브.
  2. `stage_pipeline`(parent_page_id) / `gate_threads`(`Kc7JZEVYgheNzZKo`, page_id) / `enrich_log`(`KZccSviFYvgYA9e4`, parent_page_id) 행 삭제.
  3. 부모 카드 `🤖 정리된 브리프/맥락 점수/미결 질문/스누즈 횟수/다음 점검 시각` 초기화(AI 게이트는 WF1이 관리).
  - **멱등 함정**: `deleteRows` 0건 매칭 시 0 items → 체인 끊김 → 3개 delete 모두 `alwaysOutputData:true` + `단계 행 삭제` 다중출력은 `단일화2`(Limit 1)로 수축해 항상 `부모 필드 초기화`까지 도달.
- **Notion 버튼 설정(UI, 1회)**: `🔁 AI 검토 요청` 버튼 → 동작 "웹훅 보내기" → URL 위 공개 URL, 커스텀 헤더 `X-Webhook-Token` 추가. (Notion 버튼 동작은 API로 설정 불가 → UI에서만.)

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
- 현재 연결: Notion account(`b03vHUApw6s0O5jS`) / Botmap slackApi(`bjozecrw9OnFT8Lf`) / Figma account(`Rg6fKjWcdHHj0e1O`) / AWS (IAM) account(`GftVHJqfxQshQZ4P`) / **Notion Webhook Token(`httpHeaderAuth`, `xuAMs5mpZiSnoXgI`) — WF1 `검토 요청 수신` 웹훅 인증(헤더 `X-Webhook-Token`); 토큰 값은 n8n 크레덴셜에만 저장**.
- push 는 이 참조를 보존하므로 재연결 불필요.

## 게이트 LLM · 프롬프트 캐싱 · 핵심카드 주입 (2026-07-09)

- **게이트 모델 = AWS Bedrock `global.anthropic.claude-opus-4-8`** (커뮤니티 노드 `n8n-nodes-bedrock-advanced.lmChatAwsBedrockAdvanced`, inference profile). 적용: **WF1 맥락 게이트 · WF3 착수준비 게이트 · WF-Enrich 풍부화**. (WF2 재평가·WF-Dispatch 단계계획은 0툴 단일콜이라 Sonnet 4.6 유지.)
  - ⚠️ **Opus 4.8은 `temperature`·`top_p` 가 deprecated** → 값(0.2 등)을 보내면 `ValidationException`(`temperature`=1 만 허용, 모델이 무시). **모델 노드 options 에서 temperature 제거**(미지정=드롭). 라이브 검증 시 실제로 아무 에러 없이 동작.
  - 캐싱: `enablePromptCaching`+`cacheSystemPrompt`+`cacheTools`(TTL 5m). **Opus 최소 캐시 임계 = 4,096 토큰**(Sonnet 1,024) — 캐시 프리픽스가 이보다 작으면 캐시 미발생.
- **WF1 핵심카드 = 2단계 select→cache** (Context Hub '핵심' 카드 본문을 전량 주입하지 않는다):
  1. `카드 메뉴 구성` — 핵심카드 **인덱스**(주제/영역/직무/id)만 생성(+디테일 메뉴).
  2. `핵심 선택`(Basic LLM Chain, **Sonnet 4.6**) — 태스크에 맞는 핵심카드 id 를 **모델이 선택**(id만 줄단위 출력).
  3. `선택 ID 분리`(코드, id 파싱·코어 id 교집합·0건이면 전체 폴백) → `선택 본문 읽기`(executeWorkflow → `wf-notion-read`, **카드별 mode=each**) — **선택된 카드 본문만** fetch(표 포함).
  4. `선택 컨텍스트 합치기` → `selectedCoreContext` 를 게이트 systemMessage 프리픽스에 주입 → **`cacheSystemPrompt` 가 '선택 확정 후'의 이 프리픽스를 캐시**(내부 추론 루프에서 재사용 = "첫 캐시").
  - 게이트 systemMessage 는 **핵심 인덱스(coreMenu)** 도 함께 받아, 선택 외 카드가 필요하면 `Hub 카드 읽기` 툴로 id 를 추가 조회 가능(안전망).
  - 검증(exec 27194): 핵심 9카드 중 **6 선택** → 본문 fetch → `selectedCoreContext` 8.3K 주입 → 게이트 구조화 출력(sufficient/score 88/roles) 성공. CloudWatch `AWS/Bedrock`(opus-4-8) **CacheWrite 12,555 / CacheRead 12,555** = 선택 핵심카드 캐싱 확정.
  - 배경: 커뮤니티 노드의 `cacheConversationHistory` 는 체크포인트를 '태스크(human) 메시지' 뒤에 놓아 **단일 에이전트로는 툴로 읽은 카드가 캐시되지 않음** → 그래서 선택된 본문을 시스템 프리픽스에 넣어 `cacheSystemPrompt` 로 캐시하는 2단계 방식을 택함.
