---
name: design-to-figma
description: >-
  BOMAPP(보맵) 디자인 태스크를 노션 작업지시서로부터 읽어 Figma에 온브랜드 화면/시안으로 구현할 때 사용한다.
  트리거: 노션 디자인 태스크(타입=디자인)·작업 정의서 URL이 주어지고 목표가 Figma 화면 제작일 때.
  포함: 노션 Context Hub + 연결 태스크 선독, BDS 디자인 시스템 + 화면취합(마스터) 그라운딩,
  Figma 산출물은 항상 use_figma 네이티브 컴포넌트(프레임·텍스트·벡터·Component)로 구성(화면 전체 평면 이미지 업로드 금지),
  코드-퍼스트 HTML 렌더는 시각 레퍼런스 보조로만 사용, 실제 보맵 3D 에셋 재사용/Bedrock SD3.5
  온브랜드 일러스트 생성, 버전별 페이지 분리 포팅, **빌드 후 design-review 스킬로 검수·최종 수정**. (상세 IDs는 메모리 reference_bomapp_bds_figma_design 와 동기화)
---

# 노션 작업지시서 → Figma 구현 (BOMAPP 디자인 자동화)

보맵 디자인 태스크를 **무에서 그리지 말고**, 노션 컨텍스트 + 실제 보맵 디자인 시스템/화면에 그라운딩해
**Figma 네이티브 컴포넌트**(프레임·텍스트·벡터·Component)로 고품질 시안을 짓고, 버전별 페이지로 비교 가능하게 둔다.

> 🚩 **절대 원칙: Figma 산출물은 무조건 `use_figma` 네이티브 노드로 구성한다.** 화면을 렌더 이미지(PNG)로
> 업로드해 "평면 한 장"으로 만들지 않는다 — 그러면 편집·컴포넌트 분리·코드 역이관이 전부 막힌다(사용자 핵심 요구).
> 모든 요소는 개별 노드여야 하고, 반복 요소(CTA·pill·navbar·말풍선 등)는 **실제 Figma Component**로 만들어 인스턴스로 조립한다.
>
> 핵심 교훈: Claude의 Figma 네이티브 빌드도 **이펙트 스타일·SVG 벡터·auto-layout·상태 컬러밴드 차트**를 쓰면
> 코드-퍼스트 수준의 고품질을 낸다(TA-136 v4 입증). 단 Figma MCP 환경엔 **Pretendard가 없어** 미리보기 폰트는
> Noto Sans KR로 보인다 → 최종 Pretendard 스왑을 명시한다. HTML/CSS 렌더는 **레이아웃·색감을 빠르게 잡는 시각
> 레퍼런스 보조**로만 쓰고(STEP 2), Figma로는 그 결과를 네이티브로 재현한다 — 렌더 이미지를 그대로 올리지 않는다.

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

## STEP 2 — (선택) 코드-퍼스트 HTML = 시각 레퍼런스 보조

> ⚠️ 이 단계의 산출물(렌더 PNG)은 **Figma에 그대로 올리지 않는다.** 레이아웃·간격·색감을 빠르게 확정해서,
> STEP 4에서 네이티브로 재현할 때 베껴 그릴 **픽셀 레퍼런스**로만 쓴다. 화면이 단순하거나 급하면 생략 가능.

1. 화면을 **HTML/CSS**로 작성. `proto/` 폴더 사용. 토큰을 CSS 변수로, 타입은 **실제 Pretendard 웹폰트**:
   `https://cdn.jsdelivr.net/gh/orioncactus/pretendard/dist/web/static/pretendard.min.css`
2. 카드 그림자·둥근 모서리·정교한 **SVG 차트**(상태 컬러밴드·콜아웃 마커 등)로 깊이를 잡아 본다 — 그대로 STEP 4에서 네이티브로 옮긴다.
3. **렌더(픽셀 확인)** — Playwright는 브라우저 버전 불일치로 자주 실패. 설치된 Chrome 헤드리스 사용:
   ```bash
   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu \
     --hide-scrollbars --force-device-scale-factor=2 --virtual-time-budget=3500 \
     --window-size=375,H --screenshot=out.png "file://$PWD/screen.html"
   # 여러 화면 한 파일이면 ?s=N 쿼리+인라인 JS로 1개만 보이게 해 개별 렌더
   ```
4. 스크린샷을 `Read`로 보며 레퍼런스를 다듬는다. (375pt 폭, body 패딩/가운데정렬이 뷰포트 넘기면 우측 클리핑됨 주의.)

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

## STEP 4 — Figma 네이티브 컴포넌트로 빌드 (필수 · 유일한 산출 방식)

- 🚫 **화면 전체를 렌더 PNG로 업로드해 평면 이미지로 만들지 않는다.** 모든 화면은 `use_figma`로 **개별 노드**(프레임·텍스트·벡터)로 짓는다. (raster 일러스트만 예외 — 네이티브 프레임 안에 이미지로 끼워 넣음, 아래 참조.)
- **기존 작업물은 절대 수정 금지.** 새 작업은 **새 페이지**(v1/v2/v3/v4 …)로 분리해 나란히 비교.
- 새 파일이 필요하면 `create_new_file`, planKey = **BOMAPP `team::915416689671091979`**(Dev 시트; justin의 팀=view 불가).
- `use_figma` 호출 **전 반드시** `skill://figma/figma-use/SKILL.md`(필요 시 `figma-generate-design`)를 `ReadMcpResourceTool` 로 읽는다. 콜마다 `setCurrentPageAsync(<page id>)`로 페이지 컨텍스트 재설정. 색은 0–1 범위, 텍스트는 폰트 로드 후 수정.

**① 반복 요소 = 실제 Figma Component로 (필수)**

- CTA·status pill·navbar·카카오 말풍선·읽기전용 필드처럼 **2회 이상 쓰는 요소는 실제 Component로 만들고 인스턴스로 조립**한다. 기존 로컬 컴포넌트가 있으면(예 `CTA/Primary`·`Webview/NavBar`) `getNodeByIdAsync` 후 재사용.
- **승격→스왑 레시피**(이미 인라인으로 지은 화면을 컴포넌트화): ① 잘 만든 인라인 노드 1개를 `figma.createComponentFromNode(node)`로 **제자리 승격**(마스터) → ② 마스터를 화면 밖 **선반**(페이지 빈 영역, 예 화면 아래 y≈1100)으로 옮기고 → ③ 그 자리 + 다른 화면의 동일 인라인 노드를 **삭제하고 인스턴스로 교체**(`comp.createInstance()`, 위치 지정). auto-layout 행 안이면 `insertChild(idx, inst)`로 순서 유지.
- **컴포넌트 프로퍼티**(가변 텍스트/토글): `const key = comp.addComponentProperty('label','TEXT','기본값')`(반환 key 형식 `label#56:0`) → 대상 노드 `node.componentPropertyReferences = {characters: key}`(토글은 `'BOOLEAN'`+`{visible: key}`). 인스턴스는 `inst.setProperties({[key]: 값})`. ⚠️ characters를 바꾸는 프로퍼티는 **setProperties 전 해당 폰트 로드** 필수. (실제 적용: CTA=`label`+`showArrow`, NavBar=`title`, Pill=`label`.)
- **리치 텍스트(부분 색·볼드)는 프로퍼티로 안 됨** → 인스턴스의 텍스트 노드를 직접 `setRangeFontName`/`setRangeFills`로 오버라이드(예: 말풍선 본문 변수 강조; characters 교체 후 전체를 기본 폰트/색으로 normalize → 강조 구간만 재지정). 색만 다른 변형(pill 정상/주의)도 인스턴스 `fills` + 자식 텍스트 `fills` 오버라이드로 처리.
- 상태 변형이 많으면 variant(`combineAsVariants`)로 묶는다. 단순하면 단일 컴포넌트 + 프로퍼티/오버라이드로 충분.

**② 빌드 레시피 (코드-퍼스트 수준 품질을 네이티브로)**

- **배경(기기) 프레임 필수**: 각 화면 = 375px 폭 phone 프레임에 **앱 배경색을 채우고**(예 `#F3F5F8`, 카카오 `#B2C7D9`), `cornerRadius`(예 30) + **기기 그림자 이펙트 스타일**을 줘 흰 캔버스와 분명히 구분되게 한다. (배경을 비우면 콘텐츠가 떠 보임 — v4 초기 실수.)
- **최소 화면 높이 = 휴대폰 뷰포트 `375×812`**: 콘텐츠가 뷰포트보다 짧아도 phone 프레임 세로를 **최소 812로 늘려** 표준 폰 크기를 맞춘다(짧은 프레임·흰 여백 방치 금지). 스크롤이 필요한 화면만 812 이상 허용. ⚠️ **늘린 뒤 하단 고정 요소(CTA·trust·약관)는 새 바닥으로 다시 도킹**한다(예 `CTA.y≈H-98`, 보조문구 `≈H-34`) — 안 옮기면 화면 중앙에 떠버림. 확정/완료처럼 콘텐츠가 적은 화면은 콘텐츠 블록을 **세로 중앙 정렬**하면 보기 좋다. (배경이 색 채움이면 늘린 부분은 자동으로 채워짐 — 카카오 메시지 화면 등.)
- 그림자 = `createEffectStyle`(카드/CTA/기기) — **반환 styleId 끝에 콤마 포함**(`S:xxxx,`) → `setEffectStyleIdAsync`에 콤마째 전달.
- 아이콘 = `createNodeFromSvg`(back chevron·unlink·check 등 SVG 문자열 → 편집 가능 벡터).
- 컨테이너 = `figma.createAutoLayout`(pill·CTA·비교막대), 차트 = 솔리드 채움 + 상태 컬러밴드(rect opacity) + rounded 막대(`topLeftRadius/topRightRadius`) + 콜아웃 배지/마커.
- 큰 수치 정렬 = `counterAxisAlignItems:'BASELINE'`, 텍스트 부분강조 = `setRangeFills`+`setRangeFontName`.
- 폰트 = **Noto Sans KR**(Bold/Medium/Regular 확인됨; Pretendard 미설치 → 미리보기 Noto, **최종 Pretendard 스왑 명시**).
- **색 대비(WCAG AA)를 빌드 시 확보**(리뷰 상습 결함 선제 차단): 채도 높은 상태색 warn `#FF8A00`·safe `#12B886`은 **막대·아이콘 등 비텍스트 그래픽에만** 쓰고, **텍스트·수치·상태 라벨엔 darker 변형**(오렌지→`#C2410C`대, 그린→`#0E7C5A`대, 밝은 배경서 ≥4.5:1)을 쓴다. 회색 캡션은 `#8A94A6`(흰/연배경 ~2.8~3:1 미달) 대신 본문급은 `#3B4252`(ink2). 9px 같은 초소형 텍스트 금지(≥11~12). 상태는 **색 + 텍스트 라벨 이중 인코딩**. (검수 기준은 `design-review` 스킬.)
- **카드/컨테이너 내부 패딩**(16~20px 일관): plain frame에 자식을 **절대배치**하면 clip이 안 되므로 **프레임 height ≥ 마지막 자식의 `y+height` + 하단패딩(≈18)**을 반드시 보장한다(안 그러면 인사이트 박스 등이 카드 밖으로 삐져나옴 — v4 비교카드 실수). 콘텐츠가 가변이면 카드 자체를 `createAutoLayout` + `padding`으로 만들어 자동으로 hug되게 하는 게 안전.
- 빌드는 **화면당 ~6콜**로 쪼개 **≤10오브젝트/콜**(초과 시 타임아웃·원자적 롤백) + 중간 `get_screenshot`(URL→`curl`→`Read`)로 픽셀 검증. `textAutoResize`는 'WIDTH' 없음('WIDTH_AND_HEIGHT'/'HEIGHT').

> `upload_assets`(→ multipart `file` POST) 이미지 업로드는 **raster 일러스트를 네이티브 프레임 안에 끼워 넣을 때만** 쓴다(STEP 3 일러스트). **화면 전체를 렌더 PNG로 올리는 방식은 금지** — 편집·컴포넌트 분리가 막힌다.

---

## STEP 5 — 디자인 리뷰 & 최종 수정 (필수)

Figma 빌드가 끝나면 **반드시 `design-review` 스킬을 실행**해 검수받고 결과를 **최종 수정까지** 반영한다. 자체 "완성" 선언으로 끝내지 않는다.

1. **리뷰 실행**: `design-review` 스킬을 호출한다 — 이 스킬은 **빌더와 분리된 Opus 서브에이전트**로 (① 작업지시서 충실도 ② 이 빌드 스킬 준수도 ③ UX/UI 휴리스틱: WCAG 대비·타이포·여백·**카드 내부 패딩**·터치타겟·데이터시각화) 심각도 태그 보고서를 돌려준다. 리뷰어에게 **대상 Figma 파일 key·페이지·화면 노드 ID, 작업지시서 노션 ID, 이 스킬 경로, 고해상도 렌더 PNG**를 전달한다.
2. **최종 수정**: 보고서를 심각도순으로 처리한다.
   - **Critical / High = 반드시 수정**(예: WCAG 대비 미달인 핵심 정보, 카드 오버플로우, 지시서 핵심 누락).
   - **Medium = 가능한 한 수정**(대비·여백·일관성 등 명확한 결함은 대부분 수정).
   - **Low / Nit = 비용 대비 판단**(저비용이면 수정). **기획 확정이 필요한 항목은 수정하지 말고 에스컬레이션**(STEP 6).
   - 반복 요소를 Component로 만들었으면 **마스터 몇 곳만 고쳐 전 화면 반영**됨을 활용한다.
3. **재리뷰**: 수정한 항목(특히 대비·패딩)을 다시 확인한다. 판정이 **`만족`**(또는 High 0건의 **`조건부 만족`**)이 될 때까지 1~2회 반복.
4. 리뷰에서 드러난 **반복 교훈은 이 빌드 스킬·`design-review` 스킬·메모리에 역류**시킨다(예: 상태색 대비·카드 패딩처럼).

---

## STEP 6 — 마무리

- 변경/조사 결과를 **서비스 문서·`services.yaml`** 및 **Context Hub** 에 반영(이 스킬 자체가 그 산출물).
- 관련 노션 태스크 상태를 처리 상황에 맞게 갱신하되, **n8n 기획 자동화 트리거(🔁 검토/웹훅)에 영향 줄 수 있는 상태 필드는 임의 변경 금지** — 링크 코멘트 위주.
- 관련 노션 태스크의 `산출물` 필드에 생성한 피그마 파일 링크를 삽입
- **확정 필요 결정사항**(문안·데이터·표현 방식 등)은 목록으로 기획에 에스컬레이션.

---

## 빠른 체크리스트
- [ ] 노션 태스크 + Context Hub 디자인 카드 3종 읽음
- [ ] BDS 토큰 실측 + 화면취합/참조 실화면 확인
- [ ] (선택) 코드-퍼스트 HTML 렌더로 레이아웃·색감 레퍼런스 확보 (Figma엔 이미지로 올리지 않음)
- [ ] 일러스트는 실제 보맵 3D 에셋 재사용 우선, 부족분만 Bedrock SD3.5(레지스터+hex 프롬프트) — 네이티브 프레임 안 이미지로만
- [ ] **Figma는 네이티브 컴포넌트로만 빌드(화면 평면 이미지 금지)**: 배경(기기) 프레임 채움 + 최소높이 812 + 반복요소 Component화 + 카드 내부 패딩 + 새 페이지 분리(기존 보존) + Pretendard 스왑 명시
- [ ] **빌드 후 `design-review` 실행**(Opus 리뷰어) → Critical/High 수정 + 재리뷰까지
- [ ] 결정사항 에스컬레이션 + 문서/Hub 반영
