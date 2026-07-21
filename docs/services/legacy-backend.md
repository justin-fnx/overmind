# legacy-backend (동결, 유지보수만)

> 보맵 초기(2018년) 모놀리스 백엔드. **API 부분은 `next-backend / bomapp-api` 로 이관 완료**. 현재는 `redmin` (운영자 어드민)과 `webview_server` (앱 인앱 웹뷰 / 약관 정적 파일) 만 잔존하여 프로덕션 유지만 한다. redmin 의 장기 대체 대상은 별도 GitLab 리포 [`bomapp-console`](./bomapp-console.md) 이다.

| 항목 | 값 |
|------|----|
| 경로 | `../legacy-backend` |
| 리포 | `github.com/bomapp/legacy-backend` (추정) |
| 언어/플랫폼 | Java 1.8 / Spring Boot 1.5.14 / Maven |
| 패키징 | WAR |
| 첫 커밋 | 2018-07-09 |
| 최신 커밋 | 2024-08-19 |
| 총 커밋 수 | 7,583 |
| 최근 6개월 | 0 커밋 |
| 활동 상태 | **동결** (2024-08 이후 활동 없음, 신규 개발 금지) |
| 주요 브랜치 | `master`(HEAD), `dev`, `byeol-dev`, `byeol-prod`, `deploy/legacy/*` |

---

## 1. 책임 (현재)

- **`bomapp_webview_server`** — **✅ PROD-Cluster 신규 ECS 이관·전면 컷오버 완료 (2026-06-10, BOM-137/138/139/154)**. `web.bomapp.co.kr` 전체 트래픽이 public **`prod-nlb`(고정IP 15.164.25.64) → target-type=alb → `prod-alb`** :443 prio 260 → 신규 TG `prod-bomapp-webview-ip-8080` (독립 ECS, SB1.5/Java8, 8080, DB datasource·mysql-connector 8.0.28). 구 PROD-BACK 공용 WAS :7778 (PID 1428) 은 롤백용 잔존. 보맵 앱이 약관/정책/공지/콘텐츠/이벤트 + 정적 자산(JS/CSS) 호출. (과거 운영 형태: PROD-BACK :7778, [검증](../runtime-verification.md#24-활성-java-프로세스--포트-매핑-검증))
  - ⚠️ **[2026-07-21 발견] master 브랜치는 위 BOM-138 하드닝을 결여함 — 배포 landmine.** prod 가동 이미지(`20260610-c32d5c0`, rev 8, 8080 리슨)는 **미머지 브랜치 `feat/bom-138-redmin-webview-8080-ecs`** 에서 빌드됨. 그 브랜치의 하드닝(webview/redmin **포트 8080 통일**, `application-prod.properties` **평문 AWS 키 제거→ECS secret 주입**, **devtools prod 제외**, datasource·mysql-connector 정비)이 **master 에 머지된 적 없음**. 반면 master 는 그 이전 base 라 `application-prod.properties` 가 `server.port=7778` + **평문 AWS 키**(담당팀 인지) + `spring.devtools.livereload.enabled=true`. overlay `ops/ecs/bomapp-webview/overlays/prod/.env` 도 `CONTAINER_PORT=7778`(→ PR #1313 로 8080 임시 정합) 이었음. **master 에서 webview 를 그대로 빌드·배포하면 앱이 7778 로 리슨해 8080 TG 헬스체크 실패 → 서킷브레이커 자동 롤백**(rev 8 유지, 무중단). BOM-399 컷오버 배포(run 29757731570)가 이 때문에 실패. 근본 해결 = `feat/bom-138-redmin-webview-8080-ecs` 의 webview 변경을 master 에 반영.
    - **[✅ 해소 완료 2026-07-21] PR #1314**(`fix/bom-138-reconcile-into-master` → master, merge `e61b705`): `feat/bom-138-redmin-webview-8080-ecs` 를 master 로 **충돌 0 병합**(BOM-399 Java 3파일과 disjoint). server.port=7778 제거→8080, 평문 AWS키 제거→ECS secret, devtools 제외, overlay CONTAINER_PORT=8080, `task-definition-datasource.json` 추가. **머지+배포 완료**: build-and-deploy run 29795832822 성공 → **TD rev 10**(image `20260721-e61b705`, containerPort 8080) 가동 2/2. 기능검증(배포 후): `/policy/v1/terms-of-service/latest` 303, `/privacy-policy` 303, `/nice/skt/agree-personal` 303, `/my-data-integration-authorization-terms` 200 → **새 스키마(`bomapp.policy`·`mydata.org`) 읽기 정상**(member-service 계정에 bomapp/mydata SELECT grant 완료). 임시 PR #1313 은 대체 close. PR #1310(원 BOM-138)은 머지된 적 없음(티켓만 Done·아카이브). ⚠️ `/policy/v1/main`(약관목록 뷰, `findByPolicyGroup` native 그룹쿼리)은 배포 전후 모두 500 — **이번 변경과 무관한 기존 버그**, 별도 확인 필요.
    - **⚠️ webview 컷오버 지연 시 영향(부분 장애)**: `Policy`(→`bomapp.policy`)·`MyDataOrg`(→`mydata.org`, 리네임) 를 쓰는 **`PolicyController` 약관/동의 화면 ~50종**(서비스이용약관·개인정보·여행/펫보험·통신사 본인인증 SKT/KT/LGU+·건강검진·신용·마이데이터 연동·통합인증 동의 등)이 DB 테이블 이동 후 조회 실패. TG 헬스체크는 `/css/common.css`(정적)라 **서비스는 green으로 보이나 동의 기능이 죽는 silent 부분 장애** → 신규 가입·마이데이터 연동 등 동의 필요 플로우 차단. 정합 3요소(테이블 이동 + webview DB계정 bomapp/mydata SELECT grant + PR #1312·#1314 배포)가 모두 맞아야 정상.
- **`bomapp_redmin`** — 운영자 어드민(**내부 전용**). **✅ 2026-06-10 신규 ECS 컷오버 완료** (BOM-137/138/157): `redmin.bomapp.co.kr` 은 **`prod-internal-alb`(internal)** 로 해석 → :443 **prio 20** host 룰 → 신규 TG `prod-bomapp-redmin-ip-8080` (독립 ECS, 8080, DB·mysql-connector 8.0.28). NEWTG RequestCount 양수로 라우팅 확정. 로그인=2FA(userId+userPw BCrypt → Google OTP). 구 경로 = internal-alb :443 **default** → `prod-back-ecs-1-http-7575`(i-09e36b30bad90990d:7575), 롤백용 잔존. ⚠ 최초 public `prod-alb`(prio 40 휴면 룰)에 잘못 걸었다 교정 — **redmin 은 internal ALB 가 실경로** (cf. webview 는 public `prod-nlb→prod-alb`)
- **`bomapp_api_server`** — 노션상 "이전 완료" 진술. 단 `/was/data/legacy-bomapp-api-prod` 디렉토리 잔존 (ps 비활성). 완전 제거 미확정
- **`bomapp_api_server_common`** — 공통 라이브러리 (위 모듈들이 의존)

---

## 2. 모듈 구조

```
legacy-backend/
├── bomapp_api_server/          # 메인 API 서버 — 폐지됨 (next-backend 로 이전)
├── bomapp_api_server_common/   # 공통 라이브러리 (잔존)
├── bomapp_webview_server/      # 앱 웹뷰 서버 (잔존)
└── bomapp_redmin/              # 운영자 어드민 (잔존)
```

---

## 3. 배포 / 도메인

### 3.1 ECS / 호스트

| 환경 | 클러스터/호스트 | 비고 |
|------|----------------|------|
| PROD | **PROD-BACK** (t3.xlarge × 2) | ECS service `prod-next-backend-was-v5/v6`. **단일 컨테이너 `next-backend-was:1.1` 가 호스트 `/was/data` 마운트로 12개 디렉토리 / 7개 활성 jar 를 수동 운영하는 공용 WAS 패턴**. legacy-backend 의 `bomapp_webview_server-0.1.0.jar` (PID 1428, port 7778) 가 SSM 검증으로 활성 확인됨. 컨테이너 27개 portMapping 중 실 listening 은 8개 미만 ([검증 상세](../runtime-verification.md#2-prod-back-클러스터-운영-실체-ssm-검증)) |
| STG | `next-stg-back` (10.1.1.149) | 직접 호스트 (Route53 고정). legacy 잔존 영역 한정 — `STG-Cluster` 내 `SVC-ECS-STG-legacy-bomapp-api`, `SVC-ECS-STG-bomapp-redmin`, `SVC-ECS-STG-bomapp-webview` 도 같이 가동 중 |
| DEV | `DEV-Cluster` 의 `SVC-ECS-DEV-legacy-bomapp-api`, `SVC-ECS-DEV-bomapp-redmin`, `SVC-ECS-DEV-bomapp-webview` | 과거 `NEXT-DEV` 클러스터(`dev-az.bomapp.co.kr`) 는 폐기됨. 2026-05-19 재검증 |

### 3.2 도메인 (legacy-backend 잔존 영역)

| 도메인 | 환경 | 컨테이너 포트 | 검증된 jar / 상태 |
|--------|------|:---:|------|
| `web.bomapp.co.kr` | PROD | 7778 | **`bomapp_webview_server-0.1.0.jar` 활성 (PID 1428)** ✓ — 보맵 앱 인앱 웹뷰 정상 호출 |
| `redmin.bomapp.co.kr` | PROD | 7575 | `bomapp-redmin-prod` 디렉토리 존재. 검증 인스턴스에서 ps 비활성 |
| `dev-rapi.bomapp.co.kr` | DEV | — | redmin (DEV) |
| `vkey.bomapp.co.kr` | PROD | 8080 | **별개 프로젝트** [`bomapp-inc/transkey_servlet`](https://github.com/bomapp-inc/transkey_servlet) (Tomcat 9.0.45 WAR, `bm.service=bomapp_key`, PID 1205) ✓ — legacy-backend 가 아님. 라온시큐어 TouchEn 가상키보드 복호화 서블릿, 청구 플로우 주민번호 입력용. PROD-BACK 공용 WAS 컨테이너에 같이 떠 있어서 표에 함께 기재. [상세 서비스 문서](./bomapp-vkey.md) |
| `f.bomapp.co.kr` | PROD | — | webview_server / 정적 파일 (CloudFront 경유 추정) |
| `az.bomappworks.com` | PROD | 3001 (frontend ALB) | legacy az frontend |
| ~~`api-was1.bomapp.co.kr`~~ `(10.1.1.10)` | PROD | — | 레거시 직접 호스트 (ECS 외) — **DNS 제거 2026-07-03** |
| ~~`api-was2.bomapp.co.kr`~~ `(10.1.1.20)` | PROD | — | 레거시 직접 호스트 — **DNS 제거**; IP=현 PROD-BACK 존치(oauth/vkey config가 raw IP 참조) |
| ~~`mapi-was1.bomapp.co.kr`~~ `(10.1.1.17)` | PROD | — | 레거시 mydata-api 직접 호스트 — **DNS 제거** |
| ~~`mapi-was2.bomapp.co.kr`~~ `(10.1.1.194)` | PROD | — | 레거시 mydata-api 직접 호스트 — **DNS 제거** |
| `batch-was.bomapp.co.kr` `(10.1.1.116)` | PROD | — | 레거시 batch 직접 호스트 (DNS 존치) |

> 직접 호스트 도메인은 ECS 가 아닌 EC2 인스턴스에 직접 떠 있으며, Route53 A 레코드로 IP 매핑되어 있다. 정리(이관) 대상.
> **2026-07-03 갱신**: 미사용 vanity DNS `api-was1/2`·`mapi-was1/2`·`front-was` A 레코드 제거(infra MR!67, 실사용 검증 후). **IP/EC2 서버 자체는 존치** — 라이브 마이데이터 내부 경로는 `int-mapi.bomapp.co.kr`(NLB), 라이브 vkey/oauth는 `10.1.1.20` raw IP 참조로 계속 동작.

---

## 4. 기술 스택

| 영역 | 값 |
|------|----|
| 프레임워크 | Spring Boot 1.5.14 (RELEASE, **EOL 2017-08**) |
| 언어 | Java 1.8 (**EOL 2030년 OpenJDK 무료 지원 종료 임박**) |
| 빌드 | Maven (3개 pom.xml) |
| DB | MySQL |
| 캐시 | Redis (Jedis) |
| 검색 | Elasticsearch 7.12 |
| 패키징 | WAR (서블릿 컨테이너 별도 필요 가능성) |
| 의존성 | 로컬 lib 디렉토리에 jar 보관 — 빌드 시 누락 주의 |

테스트는 `pom.xml` 에서 `maven.test.skip=true` 로 기본 비활성화. 변경 시 명시적으로 `-Dmaven.test.skip=false`.

---

## 5. 외부 연동 (히스토리)

레거시 시기에 통합한 외부 시스템 (현재는 next-backend 로 다수 이관됨):

- 보험사: G&NET, AZ, From Age, 나이스 인증
- 마이데이터: 종합포털, 보험사 마이데이터 채널
- 결제/문서: Coocon, Manos
- 알림: InfoBank (SMS/카카오톡)

---

## 6. 의존 관계 (잔존 모듈 기준)

```
운영자 ──▶ redmin.bomapp.co.kr ──▶ legacy-backend/bomapp_redmin (PROD-BACK ECS)
                                       │
                                       ├──▶ Aurora MySQL
                                       ├──▶ Redis
                                       └──▶ mydata-mgmts-api (legacy mydata 호출)

보맵 앱 (인앱 웹뷰) ──▶ f.bomapp.co.kr ──▶ webview_server (정적 약관)
```

---

## 7. 운영

| 항목 | 내용 |
|------|------|
| Dockerfile | (확인 필요 — PROD-BACK 에 컨테이너로 떠 있음) |
| CI/CD | 수동 배포 (`deploy/legacy/*` 브랜치 패턴) |
| 빌드 | `mvn package` → WAR |
| 로깅 | **awslogs 미설정** (PROD-BACK v7/v8 — ECS 감사 P0) |
| Circuit Breaker | **disabled** (PROD-BACK — P1) |
| 보안 | SSH 포트 2208 노출 (P0) |
| Container Insights | disabled |

---

## 8. 히스토리 마일스톤

| 시기 | 변경 |
|------|------|
| 2018-07 | 보맵 초기 백엔드 시스템 구축 (모놀리식) |
| 2018~2021 | 핵심 기능 개발 (보험, 채팅, 결제, 마이데이터 초기) |
| 2021~2023 | 보험사 API 연동 확대 (G&NET, AZ, From Age, NICE) |
| 2022-03 | next-backend 신규 리포 시작 (병행 운영) |
| 2023~2024 | 마이데이터 테이블 구조 변경 및 마이그레이션 |
| 2024-08-19 | (코드 마지막 커밋) `my_data_insurance_transaction` 테이블 최신화 |
| 2024-08 이후 | 코드 변경 없음. **단 PROD 운영은 계속됨** — `bomapp_webview_server-0.1.0.jar` 가 PROD-BACK :7778 에서 활성. 보맵 앱 webview 호출 7일 합계 정상 응답 483건 (404 봇 제외) |

---

## 9. 알려진 이슈 / 마이그레이션 상태

| 항목 | 상태 |
|------|------|
| `bomapp_api_server` → `next-backend / bomapp-api` | 노션상 "완료" 진술. 단 `/was/data/legacy-bomapp-api-prod` 디렉토리 잔존(ps 비활성), 완전 제거 미확정 |
| `bomapp_redmin` 이전 | **✅ 완료 — 2026-06-10 신규 ECS 컷오버** (BOM-157). **`prod-internal-alb` :443 prio 20**(redmin 은 internal ALB 가 실경로) → `prod-bomapp-redmin-ip-8080`. NEWTG RequestCount 양수로 라우팅 확정. 계정 시드(2FA)·로그인 기능 테스트는 사용자 진행. 구 default→:7575 롤백용. (최초 prod-alb 오설정 교정) |
| `bomapp_redmin` 장기 대체 | **진행 중** — 신규 [`bomapp-console`](./bomapp-console.md) 이 redmin 대체 내부 운영 콘솔 역할. Terraform/manifest 계약은 console 기준으로 정리되었지만 실제 AWS service apply/deploy는 아직 미완료 |
| **`bomapp_webview_server` 이전** | **✅ 완료 — 2026-06-10 신규 ECS 전면 컷오버** (BOM-137/138/139/154). `web.bomapp.co.kr` → `prod-bomapp-webview-ip-8080`. 사무실 카나리가 공지 상세 네이티브 브릿지 버그(`window.bomapp.webNoticeDetail`↔`androidNative.openWithNaviBar`, BOM-154) 잡아 수정. 정적 자산 S3+CloudFront 분리는 미적용(이미지 베이킹 유지). 구 :7778 롤백용 잔존 ([근거](../runtime-verification.md#5-legacy-backend--bomapp_webview_server-코드상-endpoint-검증)) |
| **PROD-BACK 자가구동 프로세스** | **✅ 2026-06-11 라이브 read-only SSM 감사 — 없음.** 실행 java 앱 전부 `spring.profiles.active=prod`(`cron`/`my-data-cron`/`open-api-cron` 0, `bomapp_api_server` 미실행). 실행 = 롤백 stub(redmin/webview/open-api/bomapp-api/wings/구mydata jar) + dead `bomapp_oauth`(8888 좀비)뿐, 이들 `@Scheduled`=0 → **인바운드 없이 도는 배치 없음** |
| **`mydata-mgmts-api`(auth:11000) 이관** | **✅ 완료 — 2026-06-11 신규 ECS 100% 컷오버** (별도 서비스, [mydata-mgmts-api.md](./mydata-mgmts-api.md)). 구 PROD-BACK 11000 jar 는 롤백 stub |
| 직접 호스트(`api-was1/2`, `mapi-was1/2`, `batch-was`, `front-was`, `next-stg-back`) | 정리(폐기) 대상. ✅ **`api-was1/2`·`mapi-was1/2`·`front-was` DNS A 레코드 제거 완료(2026-07-03, infra MR!67)** — 실사용 검증 후, IP/EC2 서버는 존치. ⚠ **`batch-was`(10.1.1.116)** = 레거시 `@Scheduled` 배치(규제 mydata 지원004 주간전송·휴면 알림톡·토큰재발급 1s)의 거처 추정 → **DNS·서버 존치**, decommission 시 라이브 여부 + next-backend 중복실행 별도 검증 |
| Spring Boot 1.5 / Java 1.8 보안 | **EOL** — 잔존 모듈도 결국 이관 또는 재작성 필요 |
| awslogs / SSH 22 / Circuit Breaker | ECS 감사 P0~P1 (PROD-BACK 대상) |

---

## 10. 작업 시 주의사항

- **신규 기능 추가 금지** — `next-backend` 또는 별도 신규 서비스에서 작업
- 보안 패치만 한정적으로 (CVE 발견 시 우선 검토)
- 변경 시 `maven.test.skip=false` 로 테스트 명시
- 로컬 lib 디렉토리 누락 확인 필수

---

## 11. 관련 문서

- [`../architecture.md`](../architecture.md)
- [`./next-backend.md`](./next-backend.md) — 이관 완료 대상
- [`./bomapp-console.md`](./bomapp-console.md) — redmin 장기 대체 신규 내부 운영 콘솔
- [`./mydata-mgmts-api.md`](./mydata-mgmts-api.md) — redmin 이 직접 호출하는 레거시 마이데이터
- 노션: `legacy-backend`, `BOMAPP 인프라 구조(HQ/AWS)`
