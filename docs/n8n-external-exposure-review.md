# n8n 외부 노출 표면 보안 검토 (2026-07-01)

사내 자동화 n8n(`n8n.bomapp.co.kr` 에디터 / `n8n-webhook.bomapp.co.kr` 웹훅)의 **인터넷 노출 표면**을 검토하고 보완한 기록.
n8n 인스턴스는 Linear/Notion/GitLab(PAT)/Elasticsearch(로그·메트릭)/Slack/AWS/Figma 크레덴셜을 보유 →
침해 시 보맵 디지털 자산 대부분이 한 번에 유출되는 **crown-jewel** 자산이다.

관련: [[project_n8n_planning_agent]], [[project_botmap_slack_agent]], 형상관리 `n8n/`.

## 노출 지도 (2026-07-01 실측)

| 호스트 | 공개 DNS | 공개 IP에서 실제 도달 | 보호 |
|---|---|---|---|
| `n8n.bomapp.co.kr` (에디터+REST API) | ❌ 미해소(split-horizon) | ✅ **도달됨** — `14.52.60.172`에 `Host: n8n.bomapp.co.kr` 헤더로 `/`(200, n8n SPA)·`/signin`(200)·`/rest/login`(401) | n8n 앱 로그인뿐 |
| `n8n-webhook.bomapp.co.kr` (웹훅) | ✅ `14.52.60.172` | ✅ `/webhook/*`만 | nginx/1.20.1 default-deny(그 외 403) |

- 리버스 프록시 = nginx/1.20.1. 웹훅 vhost는 `/`·`/rest/*`·`/api/*`·`/signin` 전부 403 → `/webhook/*`만 통과(정상).
- TLS = 와일드카드 `*.bomapp.co.kr`(GlobalSign AlphaSSL, ~2027-02). 양호.
- **에디터 vhost는 동일 공개 IP에서 인터넷에 응답**하며 소스 IP 제한이 없다. "내부 전용"은 공개 DNS에 이름이 없을 뿐(우회 가능한 obscurity).

## 웹훅 엔드포인트 인증 현황

검토 시점 6개 중 5개가 무인증(경로 추측 방지에만 의존)이었다. 그중 3개는 워크플로우끼리 호출하는 내부 체인.

| 워크플로우 | 경로 | 검토 전 | 조치 후 |
|---|---|---|---|
| WF1 맥락게이트 | `ai-review-request` | headerAuth `X-Webhook-Token` ✅ | 유지 |
| WF2 Slack 리스너 | `overmind-slack-interactions` | 무인증(Slack) | ✅ **Slack 서명검증 적용**(HMAC+리플레이) |
| 봇맵 에이전트 | `botmap-slack-events` | 무인증(Slack) | ✅ **Slack 서명검증 적용**(HMAC+리플레이) |
| WF-Dispatch | `wf-dispatch` | 무인증·**내부체인** | ✅ **엔드포인트 제거**(executeWorkflow) |
| WF3 핸드오프 | `wf3-handoff` | 무인증·**내부체인** | ✅ **엔드포인트 제거**(executeWorkflow) |
| Figma Vision | `figma-vision` | 무인증·**내부체인** | ✅ **엔드포인트 제거**(toolWorkflow) |

## 발견 (심각도순)

- **[Critical] 에디터/REST API 인터넷 노출.** 공개 IP+Host 헤더로 `/signin`·`/rest/login` 도달 → 크리덴셜 스터핑/브루트포스/인증우회 CVE 시도 가능. 성공 시 전 크레덴셜 추출. n8n 커뮤니티 에디션 = 단일 계정·기본 MFA/레이트리밋 없음.
- **[High] 내부 체인 3종 무인증 공개 트리거.** 임의 Notion 쓰기·Slack 발송·Bedrock 과금(데이터 오염 + 비용 DoS). → **조치 완료**(아래).
- **[High] Slack 웹훅(WF2·봇맵) 서명 미검증.** n8n generic Webhook은 `X-Slack-Signature`를 검증 안 함 → 경로만 알면 Slack 페이로드 위조. 특히 봇맵은 Linear/Notion/GitLab/ES read+write 에이전트 → **프롬프트 인젝션 → 데이터 탈취** + LLM 과금. → **조치 완료**(아래).
- **[Medium]** 경로=시크릿 의존·추측 용이 / `development` 환경 의심(SPA sentry meta) / 엣지 레이트리밋·WAF·소스 allowlist 부재.
- **[Low/Info]** 장수명 광범위 정적 토큰 집중(GitLab/ES/Notion/Linear/AWS), 로테이션 미문서화. AWS 키만 Bedrock invoke 전용으로 잘 좁혀짐(이 모델을 나머지에도). `n8n/.env`의 public-api 키도 워크스테이션 유출 시 전체 제어 경로.

## 조치 완료 (2026-07-01, 형상관리 커밋)

**내부 체인 3종을 인프로세스 호출로 전환해 공개 무인증 엔드포인트 3개를 인터넷에서 완전 제거.**

- WF2 `Dispatch 호출`: `httpRequest`(→`/webhook/wf-dispatch`) → `executeWorkflow`(WF-Dispatch `0KSWtN1SPermSuFw`)
- WF-Watch / WF-Dispatch `WF3 호출`: `httpRequest`(→`/webhook/wf3-handoff`) → `executeWorkflow`(WF3 `m6YGNNCEP5RI3SSF`)
- WF3 `Figma Vision`(에이전트 툴): `httpRequestTool`(→`/webhook/figma-vision`) → `toolWorkflow`(Figma-Vision `YN6uIteF2X5BAo85`)
- 대상 트리거 `webhook` → `executeWorkflowTrigger` (figma-vision/wf3-handoff/wf-dispatch)
- 호출자 `onError=continueRegularOutput`(기존 `neverError` fire-and-forget 내성 유지). figma-vision 입력 top-level 보정.

**검증**: 라이브 publish 후 외부 GET 프로빙 — 3경로 모두 n8n `"...is not registered"`(완전 제거). WF1/Slack 3경로는 `"not registered for GET"`(POST로 존재). 크레덴셜·ai_tool 7개 배선 보존. e2e 실파이프라인은 다음 실제 핸드오프 때 확인 예정(동일 executeWorkflow 패턴은 WF1→WF-Reset/Notion-Read에서 런타임 검증됨).

## 조치 완료 (2026-07-01) — Slack 웹훅 서명 검증 (WF2 + 봇맵)

n8n generic Webhook은 Slack 서명을 자동 검증하지 않으므로 수동 구현. **웹훅당 3노드 인라인 게이트**를 삽입했다:

`웹훅(rawBody:true)` → `서명 준비`(Code) → `Slack HMAC`(Crypto) → `서명 판정`(Code) → 기존 첫 노드

- **서명 준비**(Code): 웹훅 아이템에서 원본 바디를 `binary.data`(base64 디코드)로 획득, `x-slack-signature`/`x-slack-request-timestamp` 헤더 추출, `basestring=v0:{ts}:{rawBody}`, 신선도(`±300s`), `skip`(시크릿 비었으면 통과=페일오픈).
- **Slack HMAC**(Crypto 노드, action=hmac/SHA256/hex): 시크릿을 **암호화 Crypto 크레덴셜 `Slack Signing Secret`(id `T80aJ1PR0xCvm7kY`)** 에서 읽음. 그 크레덴셜의 `hmacSecret` 필드는 **표현식 `={{ $env.SLACK_SIGNING_SECRET }}`** — 사용자가 설정한 env 변수를 참조하되 **시크릿 값은 크레덴셜/코드/로그/LLM 어디에도 평문 노출 안 됨**.
- **서명 판정**(Code): `ok = skip || (fresh && 'v0='+computedHmac === sig)`. 불일치면 `return []`(다운스트림 차단), 일치면 **원본 웹훅 아이템을 그대로 통과**(다운스트림 `$json.body` 무손상).

**구현 중 확정한 인스턴스 제약(중요)**:
- n8n **Code 노드는 `require('crypto')`·전역 `crypto` 모두 차단**(`Module 'crypto' is disallowed`) → HMAC은 **Crypto 노드로만** 가능.
- 이 인스턴스 **Crypto 노드 HMAC secret은 파라미터가 아니라 `crypto` 타입 크레덴셜(`hmacSecret`)** 에서 옴 → 그래서 암호화 크레덴셜 사용(오히려 env-in-Code보다 안전). 크레덴셜 필드가 `$env` 표현식을 평가하므로 이미 설정된 env 변수 재사용.
- **`rawBody:true`는 `$json.body` 파싱을 유지**(임시 웹훅으로 실측: JSON→object, urlencoded→`{payload:…}`), 원본 바이트는 `binary.data`에 별도 보존 → 기존 파싱 노드 무손상.
- Code 노드에서 `Buffer`/`$env`/`Date.now()`는 사용 가능(실측).

**검증**: ①임시 웹훅으로 전체 판정 로직 self-test — 유효서명 통과·위조 드롭·리플레이(오래된 ts) 드롭 모두 확인(실 env 시크릿 사용, 값은 미노출). ②라이브 위조(무서명) POST → 양 워크플로우 실행(20381/20382)에서 `서명 판정` 출력 `[[]]`·`lastNodeExecuted=서명 판정` = **다운스트림(에이전트/재평가) 미도달로 드롭 확정**. ③**유효 경로(합법 Slack 1건 통과)는 사용자 실동작으로 최종 확인 예정**(리더는 유효 서명을 위조 불가).

## 잔여 권고 (미적용 — 호스트/인프라 필요)

### 1. [Critical] 에디터/REST 프록시 폐쇄 — 인프라팀/소유자
DNS가 아니라 **nginx에서** 막아야 한다(이 호스트는 infra TF 관리 밖 = IAM만 존재, 온프레 nginx).
- 에디터 vhost(`server_name n8n.bomapp.co.kr`)에 `allow <사무실/VPN CIDR>; deny all;` 또는 내부 인터페이스 바인딩.
- n8n 하드닝: 강력·고유 오너 비밀번호 + **내장 2FA(TOTP)** + 공개가입 비활성 + `N8N_SECURE_COOKIE=true` + `NODE_ENV=production` + 보안패치 구독.
- 외부 REST 불필요 시 `N8N_PUBLIC_API_DISABLED=true`(형상관리 sync는 VPN으로) 또는 IP 제한.
- 더 강하게: 정체성 인지 프록시(Cloudflare Access / oauth2-proxy / mTLS).

### 2. [Medium] 봇맵 blast radius 축소
GitLab PAT `read_api` 스코프화, ES 키 read-only 유지, Notion 통합 DB 한정, 호출 허용 채널/사용자 allowlist.

### 3. [Medium] 엣지/위생
nginx `limit_req` 레이트리밋(webhook), `ai-review-request`는 Notion 발신 대역 allowlist 고려. 전 토큰 최소권한+로테이션 일정 문서화. `N8N_ENCRYPTION_KEY` 백업·리포 미보관 확인. nginx/n8n 접근로그 → ES, 로그인 401/403·웹훅 4xx 급증 알림 룰.
