---
name: notion-design-to-figma
description: >-
  BOMAPP(보맵) 디자인 태스크를 노션 작업지시서로부터 읽어 Figma에 온브랜드 화면/시안으로 구현할 때 사용한다.
  트리거: 노션 디자인 태스크(타입=디자인)·작업 정의서 URL이 주어지고 목표가 Figma 화면 제작일 때.
  포함: 노션 Context Hub + 연결 태스크 선독, BDS 디자인 시스템 + 화면취합(마스터) 그라운딩,
  코드-퍼스트(HTML→헤드리스 렌더→Figma 업로드) 고품질 워크플로우, 실제 보맵 3D 에셋 재사용/Bedrock SD3.5
  온브랜드 일러스트 생성, 버전별 페이지 분리 포팅. (상세 IDs는 메모리 reference_bomapp_bds_figma_design 와 동기화)
---

# 노션 작업지시서 → Figma 구현 (BOMAPP 디자인 자동화)

보맵 디자인 태스크를 **무에서 그리지 말고**, 노션 컨텍스트 + 실제 보맵 디자인 시스템/화면에 그라운딩해
**코드-퍼스트**로 고품질 시안을 만들고 Figma에 비교 가능하게 포팅한다.

> 핵심 교훈: Claude는 Figma 플러그인 API로 "박스를 그리는" 비주얼 craft가 약하다. 대신 **HTML/CSS 코드(강점) →
> 헤드리스 Chrome 렌더 → Figma 이미지 업로드** 경로가 압도적으로 품질이 높다. 또 Figma MCP 환경엔 **Pretendard가
> 없어** 네이티브로 그리면 폰트가 Noto로 회귀해 품질이 깎인다(코드 경로는 웹폰트로 실제 Pretendard 사용).

---

## STEP 0 — 브리프 & 컨텍스트 선독 (필수)

1. **태스크 본문**: `notion-fetch` 로 작업지시서 페이지를 읽는다. 화면 수·섹션·요구사항·결정사항을 구조화한다.
2. **🧭 Context Hub (특히 중요)** — 보맵 컨텍스트 DB. 디자인 착수 전 반드시 관련 카드를 읽는다.
   - 데이터베이스 `3a6975952ad54380bc580901e079a7f7` · 데이터소스 `collection://531d75b2-2f67-4aaf-be80-fc88822feef5`
   - (SQL 쿼리는 Business 플랜 필요 → 안 되면 `notion-search` 또는 카드 직접 fetch)
   - **디자인 시스템 카드** `380673e8-5b34-81c1` — BDS 현황·Figma 파일·"화면취합 노드를 화면 참조로 쓰라"는 지침.
   - **디자인 토큰(실값) 카드** `380673e8-5b34-819b` (원본 '네이밍 규칙 정리' `36d673e85b3480be82ced8295ce1bc98`).
   - **컴포넌트 카탈로그 카드** `380673e8-5b34-81d0`.
3. **연결 태스크**: 태스크의 `관계된 ✅ TASK` 등 링크된 이슈를 fetch 해 선행/후행 맥락을 확보한다.

---

## STEP 1 — 보맵 디자인 시스템 & 실제 화면 그라운딩 (필수)

- **BDS Figma 파일 = `3Ifh58l7EWLXapWRys0vjf`** (컴포넌트·토큰·화면 단일 파일, 나는 보통 viewer).
  - **화면취합 노드 `11095-53827`** = 5탭(보험/분석/건강/청구/마이) **릴리즈 화면 전부** → 디자인의 시각 언어(카드/그림자/여백/색) 레퍼런스로 사용. (마스터 파일 `geKEI7Ubnfe4BnMmjntCu3` 은 커버/인덱스만 — 실 콘텐츠 아님.)
  - **토큰 실측**: `get_variable_defs` 를 BDS 컴포넌트 노드에 호출해 정확한 값 확보.
    - primary `#3c7ae5` · status/lack `#ff3d3d` · status/excess `#913dff` · text `#1f1f1f` · gray 50 `#cccccc`/40 `#dddddd`/30 `#eeeeee` · radius 8·12 · 타입 = **Pretendard** (Title2_B 18/24, body 16/24·14/20, caption 12/16, letterSpacing -0.4).
  - **참조 실화면(get_screenshot)** — 작업과 가까운 화면을 떠서 패턴을 베낀다:
    보장비교(또래평균) `10893:18736` ga_detail · 상담유도 팝업 `10971:28205` · 건강검진 `10970:8758` · 보험홈 `10893:15078` · 생체나이 `10911:7589` · 건강편지 `10971:21144`.

---

## STEP 2 — 코드-퍼스트로 고품질 빌드 (메인 작업)

1. 화면을 **HTML/CSS**로 작성. `proto/` 폴더 사용. 토큰을 CSS 변수로, 타입은 **실제 Pretendard 웹폰트**:
   `https://cdn.jsdelivr.net/gh/orioncactus/pretendard/dist/web/static/pretendard.min.css`
2. 카드 그림자·그라데이션·둥근 모서리·정교한 **SVG 차트**(상태 컬러밴드·콜아웃 마커 등)로 깊이를 준다.
3. **렌더(픽셀 검증)** — Playwright는 브라우저 버전 불일치로 자주 실패. 설치된 Chrome 헤드리스 사용:
   ```bash
   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu \
     --hide-scrollbars --force-device-scale-factor=2 --virtual-time-budget=3500 \
     --window-size=375,H --screenshot=out.png "file://$PWD/screen.html"
   # 여러 화면 한 파일이면 ?s=N 쿼리+인라인 JS로 1개만 보이게 해 개별 렌더
   ```
4. 스크린샷을 `Read`로 보며 반복 수정. (375pt 폭, body 패딩/가운데정렬이 뷰포트 넘기면 우측 클리핑됨 주의.)

---

## STEP 3 — 일러스트 (필요할 때) — 실제 에셋 우선, 부족분만 생성

**보맵 일러스트 = 2 레지스터** (참조 파일 `jXlsVCov66VwcdWHpWbZgq` BOMAPP_운영디자인):
- **① 소프트 3D**(클레이모피즘·글로시·Pixar 톤) = **앱 내 카드·팝업**. 예 우리아이 상담팝업 `13096-10984`, 생체나이 3D장기, 3D방패.
  - 배경 그라데이션 `#FFEEA8→#FFD489`, 오브젝트 액센트 `#FFB61A→#FF801F`, 흰 십자 방패.
- **② 플랫 2D**(셀셰이딩) = **마케팅 배너**. 예 `12522-85140`. 브랜드블루 배경 `#3C7AE5`, 캐릭터 네이비머리 `#2B3A67`·민트의상 `#35C07A`·피치피부, 컨페티.

**순서:**
1. **실제 보맵 에셋 재사용이 1순위**(가장 온브랜드·무료). `get_design_context` 를 일러스트 노드에 호출 → 응답의 asset URL이 **투명 PNG**(예: 3D 방패) → 그대로 합성.
2. **없는 모티프만 생성** — Bedrock(us-west-2):
   - 활성: `stability.sd3-5-large-v1:0`, 최고품질 `stability.stable-image-ultra-v1:1`. ⚠️ Nova Canvas·Titan = **LEGACY(invoke 거부)**, 상위버전 없음. 배경제거 모델은 on-demand 미지원.
   ```bash
   aws bedrock-runtime invoke-model --region us-west-2 \
     --model-id stability.stable-image-ultra-v1:1 --cli-binary-format raw-in-base64-out \
     --body fileb://req.json out.json
   # req.json = {prompt, negative_prompt, aspect_ratio, output_format:"png", seed, mode:"text-to-image"}
   # 응답 .images[0] = base64
   ```
   - 프롬프트 = **레지스터 명시**('soft 3D render claymorphism Pixar style' / 'flat 2D vector cell-shading') + **정확한 hex 박기** + 'no text'. ⚠️ 그냥 'flat vector'만 쓰면 오프브랜드(초기 실패 교훈).
3. 앱 내 화면 = 소프트 3D 권장, 마케팅 = 플랫.

---

## STEP 4 — Figma 포팅 (버전별 페이지 분리 = 비교 가능하게)

- **기존 작업물은 절대 수정 금지.** 새 작업은 **새 페이지**(v1/v2/v3 …)로 분리해 나란히 비교.
- 새 파일이 필요하면 `create_new_file`, planKey = **BOMAPP `team::915416689671091979`**(Dev 시트; justin의 팀=view 불가).
- 렌더 PNG를 `upload_assets`(count=N) → 반환 submitUrl에 **multipart `file` 필드로 POST**(파일명=레이어명) → `placedOnNodeId` 확보.
- `use_figma` 로 새 페이지 생성 후 업로드 프레임을 그 페이지로 옮기고 **이미지 정비율로 resize**(예 375×H, 보통 380×850)·정렬·라벨.
- `use_figma` 함정: 환경에 Pretendard 없음(네이티브 텍스트는 Noto Sans KR), ≤~12노드/콜(초과 시 타임아웃·원자적 롤백), `textAutoResize`는 'WIDTH' 없음('WIDTH_AND_HEIGHT'/'HEIGHT'), 색은 0–1 범위.
- Figma 산출물은 **렌더 이미지**(편집 불가)임을 명시 — **편집 원본은 HTML 프로토타입**. 네이티브 벡터 재작성은 Pretendard 회귀로 품질↓ → 권장 안 함.

---

## STEP 5 — 마무리

- 변경/조사 결과를 **서비스 문서·`services.yaml`** 및 **Context Hub** 에 반영(이 스킬 자체가 그 산출물).
- 관련 노션 태스크 상태를 처리 상황에 맞게 갱신하되, **n8n 기획 자동화 트리거(🔁 검토/웹훅)에 영향 줄 수 있는 상태 필드는 임의 변경 금지** — 링크 코멘트 위주.
- **확정 필요 결정사항**(문안·데이터·표현 방식 등)은 목록으로 기획에 에스컬레이션.

---

## 빠른 체크리스트
- [ ] 노션 태스크 + Context Hub 디자인 카드 3종 읽음
- [ ] BDS 토큰 실측 + 화면취합/참조 실화면 확인
- [ ] 코드-퍼스트(실제 Pretendard·그림자·SVG) → 헤드리스 Chrome 렌더 검증
- [ ] 일러스트는 실제 보맵 3D 에셋 재사용 우선, 부족분만 Bedrock SD3.5(레지스터+hex 프롬프트)
- [ ] 새 페이지로 분리 포팅(기존 보존), 편집 원본=HTML 명시
- [ ] 결정사항 에스컬레이션 + 문서/Hub 반영
