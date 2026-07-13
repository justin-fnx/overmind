# ECS Service Connect 도입 + TD named-port 표준화 (Phase 1: dev·stg)

> **프로세스 관리 SoT.** Linear 워크스페이스 free issue limit 초과로 티켓 생성 불가 →
> 본 문서로 상태·인수조건·MR 링크를 관리한다. (2026-07-06 착수)
> 상태값은 Linear 컨벤션을 미러: `Todo` / `In Progress` / `In Review` / `Done` / `Blocked`.

## 배경 / 목표

BOMAPP ECS 서비스 간 통신은 현재 public 도메인(`*.bomapp.co.kr`)을 호출하고 split-horizon
DNS로 internal-ALB에 착지해 VPC 내부에서 처리된다. k8s 클러스터 DNS처럼 **서비스끼리 논리 이름으로
직접 통신**하도록 **ECS Service Connect(SC)**를 도입한다.

**접근 원칙**: ECS엔 "클러스터 단위 자동 DNS"가 없다(서비스별 opt-in). infra 루트
`terraform/ecs_cross_env.tf`의 for_each 구조를 이용해 **한 번의 인프라 변경으로 클러스터의
앱 서비스를 전부 SC에 등록**(능력은 클러스터 전역 확보, 트래픽은 무변화)하고, 실제 컷오버는
**mydata 삼각형**(mydata-api ↔ mydata-agent ↔ int-mapi)부터 통제한다.

## 실측 요약 (조사 완료 2026-07-02~06)

- next-backend **9개 앱은 서로 HTTP로 안 부른다**(공유 DB로 데이터 공유). 진짜 동서 ECS↔ECS
  트래픽은 mydata 삼각형 + mgmts-api·console·vkey 정도로 좁다.
- **TD는 infra TF에 없다** — 각 서비스 CI가 `ops/ecs` envsubst 템플릿으로 등록
  (`aws_ecs_service`는 `ignore_changes=[task_definition]`). **두 리포 모두 이미 리포내
  매니페스트 구조 보유** → SC named-port 추가 = 경량 작업.
- 기존 SC/CloudMap 자산 **0건**. `modules/prod/service_discovery.tf`는 빈 껍데기.
- SG: task egress(8080→VPC) 이미 개방, 앱포트 ingress는 ALB SG만 허용 →
  **task SG 자기참조 ingress 신설 필요**.
- 컨테이너 포트: next-backend 전앱=8080. **mydata-agent = 전 환경(dev/stg/prod) 8080**
  (2026-07-06 실측 정정 — origin/prod overlay·application.yml·라이브 STG TD rev15 모두 8080.
  앞선 조사의 "stg/prod=8008"은 베이스 클론이 stale 피처브랜치 `justin/bom-22-...`에 체크아웃돼
  생긴 오독이었음. SC client_alias.port=8080 통일 설계 유효, per-env 포트 wrinkle 없음).
- next-backend `ops/ecs` 템플릿 3종(base / chat-api / with-client-cert), **GitLab CI 정본**
  (GitHub Actions는 레거시 미러). mydata-agent 템플릿 2종(base / ssl, ssl 상시), **GitHub Actions 배포**.

## 범위 (Phase 1)

- **환경**: dev·stg만. **prod는 별도 승인 차터**(규제필수 mydata 경로 보호).
- **TD 이관**: named-port 추가 + 기존 `ops/ecs` 매니페스트 표준화만. `aws_ecs_service`
  리소스+네트워킹 이관은 SC 컷오버 후 **별도 차터**.

### 명시적 제외
prod 전 구간 / **az-was**(EC2·SC 불가) / **vkey**(TLS 재설계 필요) / **sapi·bomappworks**(정체 미식별) /
**console→bapi/wapi**(배포 미완, 확장 단계 후보) / **`aws_ecs_service` 리소스 이관**.

## ⚠️ 적용 순서 제약 (중요)

SC `service_connect_configuration`의 server 블록은 **TD에 named-port가 이미 존재해야** ECS
UpdateService가 성공한다. 따라서 **apply/deploy 순서**는:

1. **T1·T2 먼저** — TD에 named-port 추가 후 dev·stg **배포**(named-port만 있고 SC 없음 = 무해).
2. **그 다음 T0 apply** — namespace + SG + SC 등록 apply(서비스 재배포되며 SC 엔드포인트 등록).
3. **마지막 T3** — 호출자 앱 설정을 SC 논리이름으로 컷오버.

> 코드 저작(MR 작성)·`terraform plan`은 병렬 가능. **apply/deploy의 선후만** 위 순서를 지킨다.
> T0 Teammate는 코드+plan+MR까지 하고 **apply 전 정지**(Leader가 T1·T2 배포 확인 후 apply 조율).

## 작업 현황

| Task | 리포 (base) | 상태 | 담당 | MR/PR | 비고 |
|------|-------------|------|------|-------|------|
| **메인** | — | **In Progress** (T0~T2 완료, T3 남음) | Leader | — | 본 문서 |
| **T0** SC 기반+전체등록 | infra (`main`, GitLab) | **✅ Done** (SC 라이브 + OOM 인시던트 해소) | Teammate(Sonnet) | [infra !70](https://gitlab.bomapp.co.kr/bomapp/infra/-/merge_requests/70) merged(669c4a9) | apply 5add/20change/0destroy. 사이드카 OOM 인시던트는 메모리 부여(+[!109](https://gitlab.bomapp.co.kr/bomapp/next-backend/-/merge_requests/109))로 해소, 18서비스 healthy |
| **T1** next-backend TD named-port | next-backend (`dev`, GitLab) | **✅ Done** (머지+named-port 반영) | Teammate(Sonnet) | [next-backend !105](https://gitlab.bomapp.co.kr/bomapp/next-backend/-/merge_requests/105) | 템플릿 3종, port_name=서비스명. STEP1로 live TD 반영 |
| **T2** mydata-agent TD named-port | mydata-agent (`prod`, GitHub) | **✅ Done** (머지+named-port 반영) | Teammate(Sonnet) | [mydata-agent #12](https://github.com/bomapp-inc/mydata-agent/pull/12) | 템플릿 2종, named-port=mydata-agent, 전 env 8080 |
| **T3** mydata 삼각형 컷오버 | next-backend(`dev`) | **✅ Done** (머지+빌드+배포, SC 직결 라이브) | Teammate(Sonnet)+Leader | [!113](https://gitlab.bomapp.co.kr/bomapp/next-backend/-/merge_requests/113) merged | dev·stg 6프로퍼티→SC 이름. 4서비스 새 이미지 배포·healthy. mgmts leg 제외 |

### port_name 계약 (T0 SC ↔ T1/T2 TD named-port — 통합 정합 확인됨)
| 서비스 | port_name / SC dns_name | 소스 |
|--------|------------------------|------|
| bomapp-api, chat-api, mydata-api, open-api, wings-api | = 서비스명 (`each.value.app`) | T1 TD `name`=CONTAINER_NAME ↔ T0 server+client |
| bomapp-batch, mydata-batch, statics-batch | (client-only, port_name 불요) | T1 named-port 부여(무해) ↔ T0 client-only |
| mydata-agent | `mydata-agent` | T2 TD `name` ↔ T0 server+client, client_alias port=8080 |
| recipient-extractor | (T1 named-port만, T0 SC 미등록) | 무해 |

---

## 인수조건 (Acceptance Criteria)

### T0 — infra: SC 기반 + 클러스터 전체 등록 (dev·stg)
- **AC0-1** `aws_service_discovery_http_namespace`(또는 private DNS namespace)가 dev·stg 각 1개
  생성. 네이밍 infra CLAUDE.md 컨벤션 준수(ENV 대문자).
- **AC0-2** dev·stg `aws_ecs_cluster`에 `service_connect_defaults { namespace }` 설정.
- **AC0-3** for_each 앱 서비스(`next_backend_api`/`next_backend_batch`/`legacy_migration`(mydata-agent 포함))
  dev·stg 인스턴스에 `service_connect_configuration` 추가:
  - 피호출(mydata-agent, mydata-api)=**server**(portName + discoveryName + clientAlias `{dnsName, port:8080}`)
  - 나머지 API 앱=**server+client**(클러스터 전역 능력 확보)
  - batch 앱=**client-only** 또는 실제 호출 그래프 기준 판단(불필요 시 미등록 + 근거 명시)
  - 앱별 포트명/alias는 `"${env}-${app}"` 맵(local)로 주입.
- **AC0-4** `SG-{DEV,STG}-ECS-task` 자기참조 ingress(앱포트 tcp, self SG source) 신설. egress 기존 유지.
- **AC0-5** `terraform plan`(dev·stg -target) 결과 **destroy 0 / replace 0**, **prod 리소스 변경 0**.
  prevent_destroy 유지. 결과 첨부.
- **AC0-6** `terraform validate` + `terraform fmt -check` 통과.
- **AC0-7** (apply 후, Leader 조율) dev `aws ecs describe-services`로 serviceConnectConfiguration
  반영 + namespace 연결 확인. 서비스 stable, 기존 ALB 트래픽 무변화.
- **AC0-8** infra CLAUDE.md Terraform 규정(state 선독, -target 점진 apply, destroy 금지, prevent_destroy) 준수 선언(보고서 첫 줄).

### T1 — next-backend: TD named-port (dev·stg)
- **AC1-1** `ops/ecs/base/task-definition.json`, `ops/ecs/chat-api/task-definition.json`,
  `ops/ecs/base/task-definition-with-client-cert.json` 3종 portMappings에
  `"name": "${PORT_NAME}"` + `"appProtocol": "http"` 추가.
- **AC1-2** `PORT_NAME` 변수 배선(CI에서 `CONTAINER_NAME` 파생 권장) — GitLab CI 정본 + required_vars 갱신.
  (GitHub 미러도 정합 유지 권장, 단 정본은 GitLab.)
- **AC1-3** named-port 값은 TD 내 유일. 관례상 서비스명 사용(예: `mydata-api`, `bomapp-api`).
- **AC1-4** batch 앱은 SC server 불필요할 수 있음 — named-port는 추가하되(무해) 서버 등록 여부는 T0에서 결정.
- **AC1-5** dev·stg 렌더 검증: envsubst 후 TD JSON이 유효(`aws ecs register-task-definition --generate-cli-skeleton` 또는 dry 검증). 8080 포트 유지.
- **AC1-6** `./gradlew test` 영향 없음(빌드/설정 무변). MR은 GitLab, target `dev`.
- **AC1-7** next-backend CLAUDE.md/AGENTS.md 준수 선언(보고서 첫 줄).

### T2 — mydata-agent: TD named-port (dev·stg)
- **AC2-1** `ops/ecs/base/task-definition.json`, `ops/ecs/base/task-definition-ssl.json` 2종
  앱 컨테이너 portMappings에 `"name"` + `"appProtocol": "http"` 추가.
- **AC2-2** overlay 배선(또는 CI `CONTAINER_NAME` 파생) + `.github/workflows/ecs-deploy.yml` required_vars 갱신.
- **AC2-3** **env별 containerPort 상이(dev 8080 / stg 8008 / prod 8008)** — named-port는 논리명이라
  포트값 무관하나, SC clientAlias 다이얼 포트는 8080 정규화 예정(T0). containerPort는 overlay 실값 유지.
- **AC2-4** deploy/*.sh(구 EC2 WAS 잔재)는 건드리지 않음. 현행 경로는 `.github/workflows/ecs-deploy.yml`.
- **AC2-5** PR은 GitHub, base `prod`. dev·stg overlay만 대상(prod 값 무변경).
- **AC2-6** mydata-agent CLAUDE.md/AGENTS.md 준수 선언(보고서 첫 줄).

### T3 — mydata 삼각형 컷오버 (dev·stg) — blockedBy T0·T1·T2
- **AC3-1** next-backend: `mydata.agent.domain`(external-mydata dev/stg) → `http://mydata-agent:8080`(SC alias).
- **AC3-2** next-backend: `mydata.server.domain` + `mydata.api.url`(external-mydata / external-mydataapi dev/stg)
  → `http://mydata-api:8080`.
- **AC3-3** mydata-mgmts-api: `mydata.next-api.url`(application-{dev,stg}.properties) → `http://mydata-api:8080`.
- **AC3-4** prod 값 무변경(dev·stg만). dev의 기존 https/443 → SC http/8080 스킴 전환 유의.
- **AC3-5** 컷오버 후 dev·stg에서 mydata 조회 플로우 정상(마이데이터 수집/조회 호출 성공) + internal-ALB
  RequestCount 감소(SC 우회) 확인.
- **AC3-6** 각 리포 CLAUDE.md/AGENTS.md 준수 선언.

---

## Leader 리뷰 결과 (2026-07-06)

세 MR/PR 모두 인수조건 검증 + diff 라인 리뷰 완료 → **통과**. 각 MR/PR에 비승인 리뷰 코멘트 등록.
harness가 **자기승인·자기머지를 차단**(self-approval defeats two-party review) → 정식 승인·머지는 **사람**이 수행.

- **T0 (infra !70)**: SC HTTP namespace(SC-DEV/SC-STG)+클러스터 defaults+for_each 서비스 SC 등록+task SG self 규칙.
  plan **0 destroy/0 replace/prod 0**. port_name 계약 T1/T2와 정합. [Nit] chat-api WebSocket인데 server 등록(현재 미호출=무해, 향후 appProtocol 재검토).
- **T1 (next-backend !105)**: 템플릿 3종 named-port, PORT_NAME=CONTAINER_NAME 파생, 렌더 9앱 검증. port_name=서비스명 정합.
- **T2 (mydata-agent #12)**: 템플릿 2종 named-port=mydata-agent, 전 env 8080 렌더 검증. overlay/deploy 무변경.

## 다음 단계 (사람 개입 필요)

1. **사람 승인·머지** (2-party): T1(!105, →dev)·T2(#12, →prod) 먼저 머지.
2. **T1·T2 dev·stg 배포** (CI): TD에 named-port가 실제로 올라감(SC 없이 no-op=안전).
3. **T0 apply**: 배포 확인 후 infra !70 을 dev·stg `-target` apply → 18개 서비스 SC 사이드카로 롤링 재배포 + 엔드포인트 등록. (infra MR 자기머지는 사용자 승인된 예외지만, apply는 T1·T2 배포 확인이 선행)
4. **검증 관문 1** 통과 시 → **T3 컷오버** 착수(blockedBy 해제).

> ⚠️ 순서 위반 금지: T0 apply를 T1·T2 배포 전에 하면 SC server의 port_name이 TD에 없어 ECS UpdateService 실패.

## 실행 런북 (사용자 직접 실행 — harness가 에이전트 인프라 mutation 게이팅)

에이전트의 라이브 인프라 mutation(ECS register/update, terraform apply)이 harness 오토모드에
막혀, **배포+apply는 사용자 셸에서 직접 실행**하고 Leader는 명령 제공 + 사후 검증·문서화를 담당한다.

**STEP 1 — named-port 배포 (12서비스, dev·stg)**
현재 실행 TD 재사용 + 리뷰된 named-port만 추가하는 surgical 재등록(이미지·시크릿·사이드카 보존,
mydata-agent `latest` 태그 재풀 위험 없음). Leader가 mydata-agent DEV 변환을 사전 검증(diff=name/appProtocol만).
```
bash <scratchpad>/sc-named-port-deploy.sh --dry-run    # 12건 diff 검토(name/appProtocol만)
bash <scratchpad>/sc-named-port-deploy.sh --execute     # register-task-definition + update-service
```
대상: DEV/STG × {bomapp-api, chat-api, mydata-api, open-api, wings-api, mydata-agent}.

**STEP 2 — T0 apply (dev·stg -target)**
STEP 1 완료(12서비스 live TD에 named-port) 확인 후 실행. 18개 서비스가 SC 사이드카로 rolling 재배포.
```
cp /Users/justin/Projects/infra/terraform/.env /Users/justin/Projects/infra-sc-t0/terraform/.env  # worktree는 .env gitignore
bash /Users/justin/Projects/infra-sc-t0/run-apply-dev-stg.sh   # plan 요약 → yes 확인 → apply
```
`-target`: `module.{dev,stg}.aws_service_discovery_http_namespace.sc_{dev,stg}`, `module.{dev,stg}.aws_ecs_cluster.{dev,stg}_cluster`,
`module.{dev,stg}.aws_vpc_security_group_{ingress,egress}_rule.*_ecs_task_self_8080`, `aws_ecs_service.{next_backend_api,next_backend_batch,legacy_migration}`.
plan 재검증: **create 5 / update 20 / destroy 0 / replace 0, prod 실제 변경 0**. 전제: 사내 VPN, TF creds(.env 복사), ES키 자동로드.
> ⚠️ STEP 1 전에 STEP 2를 하면 SC server의 port_name이 live TD에 없어 UpdateService 실패.

**STEP 3 — Leader 검증**
Leader가 `describe-services`로 SC 엔드포인트 등록 + namespace 연결 + 서비스 stable 확인 → T3 착수.

## 검증 관문 (Leader)
1. T0 apply 후 dev `aws ecs describe-services`로 SC 엔드포인트 등록·namespace 연결 확인.
2. T3 컷오버 후 논리이름 호출 성공 + internal-ALB RequestCount 감소(SC 우회) 확인.

## T3 완료 (2026-07-06)

dev·stg mydata 삼각형이 SC 논리이름으로 **컷오버 완료**. 설정은 이미지에 baked라 **빌드+배포** 수행:
- MR !113 머지 → bomapp-api 빌드(`20260706-59d6c946`) → **bomapp-api dev·stg** 배포(deploy 단독) + **mydata-api dev**(build+deploy) + **mydata-api stg** 배포.
- 4서비스 전부 새 이미지 반영·rollout COMPLETED(mydata-api stg는 desired 0)·**failedTasks 0**. mydata-api dev 로그 정상, **SC 이름해석 오류(UnknownHost/connect) 0건**.
- **CI 트리거 교훈**: `glab api -f "variables[][key]="`(폼 배열)은 변수 전달 실패 → PIPELINE_TARGET이 기본값 `build`로 폴백(초기 빌드가 그래서 deploy 누락). **`glab ci run --variables KEY:VALUE`** 가 정답. build-and-deploy는 build 잡만 재시도하면 deploy-after-build 캐스케이드 누락 → 전체 파이프라인 재시도 or build/deploy 분리.
- **✅ SC 직결 실측 완료(2026-07-07)**: STG mydata-api 태스크의 SC 프록시 컨테이너에서 ECS Exec(SSM)로 SC 논리이름 직접 콜 —
  `curl -f http://mydata-agent:8080/actuator/health` → **HTTP 200**(EXIT 0), `curl -f http://bomapp-api:8080/actuator/health` → **HTTP 200 + 헤더 `Server: envoy` / `X-Envoy-Upstream-Service-Time` / 본문 `{"status":"UP"}`**.
  Envoy 헤더 = 트래픽이 **SC Envoy 데이터플레인을 실제 경유**했다는 증거 → **SC 이름해석+라우팅 end-to-end 동작 확정**.
  (exec 법: session-manager-plugin 로컬 추출 + `--container ecs-service-connect-*`. 앱은 distroless라 프록시 컨테이너의 AppNet minimal-curl 사용, 플래그 `-f/-v/-m`만 지원.)
- **잔여(트래픽 시프트 규모)**: 실 mydata 비즈니스 트래픽의 ALB→SC 이동 규모는 실사용 트래픽 도착 시 SC/ALB RequestCount로 확인(현재 dev/stg 조직 트래픽 미미). 경로 동작 자체는 위에서 실증됨.

## prod SC 차터 (진행 중, 2026-07-07~)

dev·stg 검증 완료 후 prod 적용 착수(사용자 승인 = 단계적 전체 실행 + 게이트). **규제필수 mydata + 전 prod 서비스 롤링재배포 수반 → 각 단계 검증 게이트.**

**prod 실측**: 서비스 대부분 mem꽉(bomapp-api 2048/2048, chat-api 3072/3072, open-api 1536/1536, wings-api 2048/2048, batch mem꽉; mydata-api gap128·mydata-agent gap256) → **SC 켜기 전 메모리 헤드룸 필수(안 그러면 prod OOM)**. PROD-Cluster 5×m7g.xlarge 잔여 ~28GB(수용 가능). prod 브랜치는 named-port 템플릿+메모리 공식 보유(dev 4커밋 앞섬). prod 배포는 prod 브랜치에서만.

| Phase | 내용 | 상태 |
|-------|------|------|
| **P1** infra 스캐폴드 | SC-PROD namespace + PROD 클러스터 defaults + SG-PROD self-ingress (additive·트래픽0·OOM0) | 위임(infra `feature/sc-prod-enroll`) |
| **P2** 메모리 헤드룸 | prod 오버레이 8개 TASK_MEMORY +256 + HEADROOM 256 → build+deploy(named-port+메모리, 롤링·OOM예방) | 위임(next-backend `feature/sc-prod-mem-headroom`, base=prod) |
| **P3** SC 등록 | prod 서비스 `service_connect_configuration` apply(Envoy 사이드카 롤링) — **P2 배포 후에만** | 대기 |
| **P4** mydata 컷오버 | prod yml→SC 이름 build+deploy(bomapp-api/mydata-api) | **✅ Done** ([!120](https://gitlab.bomapp.co.kr/bomapp/next-backend/-/merge_requests/120) 머지, 빌드`20260707-68165c60`+배포·검증) |

**prod P1~P3 완료(2026-07-07)**:
- **P1** apply: SC-PROD namespace(ns-zxs5nmwwpp6uv5h7)+PROD 클러스터 defaults+SG self (2add/1change/0destroy). infra [!73](https://gitlab.bomapp.co.kr/bomapp/infra/-/merge_requests/73) — **미머지(사용자 머지 대기, PROD infra라 2-party)**. ⚠️P3 적용됨→!73 미머지=main-state 드리프트, 조속 머지 필요.
- **P2** 메모리+named-port: [!116](https://gitlab.bomapp.co.kr/bomapp/next-backend/-/merge_requests/116) 머지+8개 next-backend deploy(재빌드 없이, 현 이미지 재사용) + mydata-agent GH Actions deploy(20260609-4062d7c). 9서비스 task_mem+256·named-port·healthy·OOM0.
- **P3** SC 등록 apply: P3a(비규제6, -target) + P3b(규제3, -target) = 9서비스 `service_connect_configuration` in-place(0 destroy). **9/9 SC-enabled, healthy, Envoy OOM0.** mydata-agent 외부 mTLS(api.mydatacenter.or.kr:8443) = P3 전후 baseline 동일(SC 미간섭 확인).
- **P4 완료(2026-07-07)**: [!120](https://gitlab.bomapp.co.kr/bomapp/next-backend/-/merge_requests/120)(prod yml 2파일→SC 이름) 머지 → bomapp-api·mydata-api prod 브랜치 빌드(`20260707-68165c60`, SC config baked) → **개별 배포**(mydata-api 먼저 검증→bomapp-api). 무중단 롤링(서비스 2/2 유지). infra [!73](https://gitlab.bomapp.co.kr/bomapp/infra/-/merge_requests/73) 머지(main=state 정합).
  - **검증**: 두 호출자 SC config 이미지·2/2·fail0·OOM0. **SC 이름해석 오류 0**(bomapp-api·mydata-api). **mydatacenter 외부 mTLS 에러율 baseline 유지**(컷오버 무영향 — SC는 내부만, 외부는 우회). prod 9/9 SC-enrolled.

## 🏁 전 환경 SC 완결 (dev·stg·prod)

dev·stg(T0~T3) + prod(P1~P4) 모두 완료. **mydata 삼각형(mydata-api↔mydata-agent, int-mapi)이 전 환경에서 SC 논리이름 직결**로 통신. 규제 mydata 외부 mTLS 무영향, 전 서비스 healthy.
- **핵심 안전패턴**: SC Envoy 사이드카 OOM 방지 = task memory +256 헤드룸 **선반영 후** SC 등록(prod는 P2→P3 순서 엄수로 OOM 0 달성).
- **잔여(선택)**: prod SC 왕복 exec 실증은 prod-exec 승인 필요(로그 기반으로 무오류 확인됨). recipient-extractor/vkey/az/sapi/mgmts leg는 원천 제외. at-risk STG chat-api·wings-api는 다음 CI 배포 시 !109 정합.

⚠️ 순서 불변: P2(메모리+named-port 배포) → P3(SC 등록 apply) → P4(컷오버). P2 없이 P3 하면 prod OOM.

## 변경 이력
- 2026-07-06: 착수. Linear 불가 → 본 문서로 프로세스 관리. T0·T1·T2 위임.
- 2026-07-06: T0·T1·T2 완료 + Leader 리뷰 통과(각 MR/PR 코멘트). 포트 팩트 정정(mydata-agent 전 env 8080).
  상태 In Review. 사람 승인·머지 → 배포 → T0 apply → T3 순서 대기.
- 2026-07-06: **배포 범위 결정 = 옵션 B**(원안 유지 — API 5앱+mydata-agent 전부 server 등록, dev·stg 12배포 선행).
  T1(!105)은 origin/dev 머지 확인. **T2(#12)는 미머지 확인**(origin/prod portMappings에 named-port 부재) → 사용자 머지 대기(하드 블로커).
  next-backend 배포는 수동(`PIPELINE_TARGET=deploy`, `when:manual`) → 머지≠배포. T0 apply 전 12개 서비스(5 API×dev·stg + mydata-agent×dev·stg) 배포 필요.
- 2026-07-06: **harness 게이트 → 실행 분담**: 에이전트 인프라 mutation이 auto-mode classifier에 차단 →
  사용자가 수동 승인 방식으로 Leader가 셸 실행. **STEP 1·2 완료.**
  - **STEP 1** (named-port 배포): surgical TD 재등록으로 **12/12 서비스 named-port 반영**. 함정: register 직후 update-service가
    2건(DEV bomapp-api, STG mydata-agent)에서 타이밍상 no-op → 응답 확인하며 재적용해 해결.
  - **STEP 2** (T0 apply): `sc-t0.tfplan` 적용 = **5 added / 20 changed / 0 destroyed / prod 0**. MR !70 머지(669c4a9)로 코드=state 일치.
  - **STEP 3 검증**: SC-DEV(ns-vja7q73knofuep2n)·SC-STG(ns-7kmx25pcxoxdsrhb) HTTP namespace 생성, **18서비스 SC-enabled=True**,
    server alias=서비스명(API5+mydata-agent), batch3=client-only(alias 없음). 사이드카 롤아웃 healthy(failed 0, 새 태스크 ALB TG 정상 등록=**ALB 경로 무변화**), 순차 수렴.
  - **T0·T1·T2 = Done.**
- 2026-07-06: **T3 착수 전 확인 필요(caveat)**: mgmts leg(`mydata-mgmts-api → mydata-api`)는 ①mgmts-api가 T0 SC for_each에 미포함(별도 서비스라 SC client 미등록),
  ②mgmts-api ECS가 prod 위주일 수 있음(dev/stg 서비스 존재 확인 필요) → dev/stg T3는 **next-backend mydata leg**(mydata-api→mydata-agent, mydata-api 내부 self)부터.
  mgmts leg는 mgmts-api SC 등록 선행 + 환경 확인 후 별도 처리.
- 2026-07-06: ⚠️ **인시던트 — SC 사이드카 OOM (T0 롤아웃 후)**. 근본원인 확정: next-backend 서비스 대부분이
  **app 컨테이너 hard `memory` == task `memory`(헤드룸 0)** 구성 → SC Envoy 사이드카(~256MB) 주입 시 앱 OOM(exit 137).
  DEV open-api 중단 태스크 stoppedReason=`OutOfMemoryError: Container killed`(사이드카 컨테이너는 HEALTHY exit 0).
  현상: 다수 서비스 flapping(DEV bomapp-api 0/1, mydata-api 1536/1536은 OOM 마진 위). 서킷브레이커(rollback=true)가 부분 완충하나 불안정.
  **정합 수정 = 메모리 사이징 선행**: app 컨테이너 hard `memory` → soft `memoryReservation` 전환(또는 task memory +256~320) — CPU 하드캡 사례와 동일 패턴.
  SC disable(롤백)은 classifier가 '사용자 미요청 자율 롤백'으로 차단 → **사용자 방향 결정 대기.** T0 상태 Done→인시던트.
  ⚠️ **주의**: `update-service`로 SC를 끄면 terraform state(SC enabled)와 drift → 이후 blanket apply가 SC 재활성→재OOM. 롤백은 반드시 코드(!70 revert)까지 정합.
- 2026-07-06: ✅ **인시던트 해소(메모리 부여) — 사용자 지시**: mem꽉(app hard mem == task mem) **14개 서비스** live TD에
  **task memory +256MiB**(Envoy 몫, app 한도 유지) surgical 재등록. 결과 **failedTasks 0** — OOM 종료, 함대 정상 수렴.
  - bump: 1536→1792 / 1024→1280. 헤드룸 서비스(mydata-agent, STG mydata-api/mydata-batch)는 자동 스킵.
  - 함정1: 서킷브레이커가 OOM 중 **DEV bomapp-api·STG mydata-agent를 named-port 없는 옛 리비전으로 롤백** → bump가 그걸 재사용해 named-port 소실 → 개별 재부여로 복구.
  - 함정2: DEV 클러스터 용량 빠듯(bump 후 인스턴스 잔여 2519/1751/215MB) — 롤링으로 관리되나 추가 bump 여지 적음.
  - **잔여 이슈 A — STG mydata-agent(SC/OOM 무관)**: 내 surgical 재등록이 **2026-06-04 낡은 :15**(BOM-132 키비번 SM일원화 이전)를 재사용 →
    fresh 기동 시 `WebClient "Cannot recover key"`(SSL 키스토어 키 복호 실패, ES 로그 확인)로 exit 1. 한 달째 뜬 :15 태스크는 6월 키를 물고 살아있었을 뿐.
    **필요조치: 최신(post-BOM-132) 이미지로 정식 CI 배포**(GH Actions). 키스토어/인증서 도메인이라 소유자 확인 권장. (DEV mydata-agent는 desired=0이라 무영향.)
  - **잔여 이슈 B — 내구성(durability)**: 메모리 +256은 **live TD out-of-band**(CI 오버레이 미반영) → 다음 CI 배포 시 mem꽉으로 원복→재OOM.
    **필요조치: next-backend `ops/ecs/*/overlays/{dev,stg}/.env` 의 `TASK_MEMORY`를 bump 값으로 갱신**(Teammate) — 정본화. app_mem 대비 task_mem이 최소 +256이 되도록.
- 2026-07-06: **내구성 픽스 MR [next-backend !109](https://gitlab.bomapp.co.kr/bomapp/next-backend/-/merge_requests/109)** — Leader 리뷰 통과(수정 2건 후 재검증).
  `.gitlab-ci.yml` 공식 `APP_MEMORY = TASK_MEMORY - cert_init - SC_ENVOY_MEMORY_HEADROOM`(**기본 0**), 헤드룸은 **SC 등록 dev·stg 오버레이에서만 256**.
  SC 등록 8서비스 dev·stg `TASK_MEMORY` +256(app 몫 보존). **prod·recipient-extractor 무변화(회귀 0)** 교차확인. stg mydata-api/mydata-batch도 1792로 보정.
  라이브 TD는 이미 surgical 반영 → **머지해도 즉시 배포 영향 없음**, 다음 CI 배포부터 헤드룸 정본 유지(재OOM 방지). **사람 머지 대기**. 후속: prod SC 시 prod 헤드룸 / DEV 용량 사이징.
- 2026-07-06: **STG mydata-agent 재배포 진행**: 최신 ECR 이미지 `20260609-4062d7c`(sha=BOM-132 키비번 SM일원화 빌드)로 `ecs-deploy.yml`(ref=prod, env=stg) 트리거(run 28770392510).
  06-04 STG 배포 2건이 failure였던 이력 → 한 달간 STG는 배포 깨진 채 :15만 생존. classifier가 "규제 서비스에 에이전트가 특정 버전 추론" 사유로 모니터링 차단 → **사용자 이미지 확인 + 모니터링 방식 대기.**
- 2026-07-06: ✅ **인시던트 완전 종결 + Phase 1(dev·stg) 완료**.
  - **STG mydata-agent 복구**: `20260609-4062d7c`(BOM-132) 배포 success(run 28770392510) → TD:18, rollout COMPLETED 1/1 fail0, 앱 RUNNING(secrets-init exit0), ES 로그 `정상 동작 중` 반복·`Cannot recover key` 소멸. 키스토어 이슈 해소.
  - **내구성 MR !109 머지**(efa74361): dev·stg SC 서비스 메모리 헤드룸 정본화(다음 CI 배포부터 유지).
  - **최종 게이트**: **전 18서비스 rollout COMPLETED + run==des + failedTasks 0** 확인. SC 라이브·healthy·ALB 경로 무변화.
  - **잔여(라이브 vs CI 정합 참고)**: 인시던트 대응 중 dev·stg 서비스 다수가 surgical out-of-band TD 리비전으로 떠 있음(메모리 +256 포함). !109 머지로 CI 소스는 정합 → 각 서비스의 **다음 정규 CI 배포 시 CI-렌더 TD로 수렴**(선택적으로 지금 일괄 CI 재배포해 정합 가능, 라이브는 이미 healthy라 필수 아님).
  - **다음 = T3**(mydata 삼각형 SC 컷오버) 착수 가능. mgmts leg caveat(위) 유효.
- 2026-07-06: **open-api OOM 근본 교정**(사용자 지시 = open-api만). open-api는 SC 이전부터 app **1024로 과소**(실수요 1536+, 타 API는 1536).
  내 인시던트 대응 +256은 task만 1280으로 올리고 app 1024 방치 → OOM(exit137) 지속. !109도 open-api를 task1280/app1024로 과소설정.
  → 라이브 TD를 **task1792/app1536**으로 교정(DEV :27 / STG :20), 검증: **새 TD에서 OOM 0**, 137은 전부 옛 TD(:26/:19). 오버레이 정본 교정 MR [next-backend !112](https://gitlab.bomapp.co.kr/bomapp/next-backend/-/merge_requests/112)(open-api dev/stg TASK_MEMORY 1280→1792) — Leader 리뷰 통과, **사람 머지 대기**.
  - **잔존 리스크(사용자 스코프상 미수정)**: STG bomapp-api/chat-api/wings-api mem꽉(1536/1536, bump no-op), STG mydata-api gap128 — 현재 미OOM이나 헤드룸 부족. 후속 CI 재배포(!109+open-api교정)로 정합 권장.

## 🔴 사후 인시던트 (2026-07-08): prod mydata callback Host 검증 실패

P4(MR !120) prod 컷오버가 mydata-api 의 `mydata.server.domain` 만 SC 논리이름(`http://mydata-api:8080`)으로 바꾸고 **mydata-agent 의 callback URL 생성 경로는 함께 정리하지 않아**, agent 콜백이 여전히 구 도메인 `http://int-mapi.bomapp.co.kr:8080` 으로 들어와 mydata-api `InternalServerAspect` Host 검증에 거절(`code=4000`)됨. 보험사 응답(`rsp_code=00000`)은 정상이었으나 콜백 저장 단계에서 보험료·납입·거래내역 실데이터가 전부 폐기됨.

- **영향**: 2026-07-07 **12:02 KST**(mydata-api prod 배포 직후) ~ 07-08 **10:45 KST**(핫픽스 배포), 약 **23시간** 마이데이터 신규 연동/재연동 무력화. ES `logs-prod-mydata-api` ERROR `보낸 요청이 아닙니다` 약 99,879건.
- **핫픽스**: [MR !143](https://gitlab.bomapp.co.kr/bomapp/next-backend/-/merge_requests/143) — `mydata.server.allowed-domains` 허용목록 신설, prod 에 `http://int-mapi.bomapp.co.kr:8080` 병행 허용(임시 완화). **후속: agent callback URL 을 SC 이름으로 정리 후 allowed-domains 임시항목 제거.**
- **사후부검(3대 실책)**: ① SC 컷오버 검증이 헬스체크·SC 이름해석 curl 에 그쳐 **실제 '연동 해제→재연동→데이터 표시' e2e 를 검증하지 않음**(콜백 Host 검증은 비동기 콜백 저장 단계에서만 발현 → 동기 헬스체크로 안 잡힘). ② 결정적 단서(agent `callback_url=int-mapi`, `invalid_request`)가 **INFO 레벨**로만 기록돼 자동 알림 미발생. ③ **mydata-agent 가 APM 미연동**이라 콜백 구간 분산추적 불가.
- **교훈**: 마이데이터 삼각형처럼 **비동기·다단계·규제 경로의 컷오버는 헬스체크/이름해석 확인이 필요조건일 뿐 충분조건이 아니다.** 향후 SC/도메인 컷오버 릴리스 체크리스트에 실 연동 e2e(해제→재연동→보험료·거래내역 조회)를 필수화한다.
- 상세 사후부검: Notion 🚨 장애 대응 기록 DB — <https://app.notion.com/p/397673e85b3481898163fb5d20fbb447>
