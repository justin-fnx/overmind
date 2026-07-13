# bomapp-console

> 보맵 내부 운영자를 위한 Bomapp Console. 레거시 `legacy-backend/bomapp_redmin` 을 대체하는 방향의 독립 GitLab 리포이며, `next-frontend` 의 `planner-admin` 과는 별개 서비스다.
> 최신 근거: BOM-221 기준 프로젝트/인프라 명칭이 `bomapp-console` / `bomapp/console` 로 정리되었다. Terraform/manifest 계약은 console 기준이지만 실제 AWS service apply 와 앱 배포는 아직 완료되지 않았다.

---

## 1. 기본 정보

| 항목 | 값 |
|------|----|
| 리포 | `gitlab.bomapp.co.kr/bomapp/console` |
| 로컬 경로 | `../bomapp-console` |
| 기본 브랜치 | `main` |
| 기술 스택 | Bun 1.3 / Turborepo / TypeScript / Next.js 16 / React 19 / NestJS 11 / Prisma 6 |
| 구성 | `apps/frontend`(Next.js admin UI) + `apps/backend`(NestJS Admin BFF) + `packages/*` 공유 타입/상수/함수 |
| 목적 | redmin 대체 내부 운영 콘솔. 멤버 조회, 지표, 알림톡, 앱리뷰, opt-out, 감사 로그, 관리자 계정 관리 |

> `AGENTS.md` 는 pnpm/Node 기준으로 stale 이다. 현재 기준은 `CLAUDE.md`와 `README.md`이며 모든 명령은 Bun을 사용한다.

---

## 2. 아키텍처 규칙

Console backend 는 범용 API가 아니라 **thin Admin BFF** 다. 데이터 소유권에 따라 접근 방식이 갈린다.

| Tier | 데이터 소유자 | 접근 방식 |
|------|---------------|-----------|
| T1 | console-owned (관리자 계정, 감사 로그) | Prisma 직접 read/write |
| T2 | app-owned read (회원 등) | Prisma 직접 read-only. 단, owner admin API 가 제공되는 조회는 BFF 에서 proxy |
| T3 | app-owned write (알림톡, 리뷰, opt-out 등) | 소유 서비스의 admin API 로 proxy. 직접 write 금지 |

중요 규칙: next-backend 등 앱 소유 데이터에 write 가 필요하면 Console DB 직접 변경이 아니라 owner API 를 먼저 만든 뒤 proxy 한다. 조회라도 owner admin API 가 이미 제공되는 기능은 직접 DB 집계로 되돌리지 않고 BFF proxy 로 연결한다. upstream API 가 없으면 화면/로직은 stub 으로 두고 나중에 연결한다.

---

## 3. 주요 경로

| 경로 | 설명 |
|------|------|
| `apps/frontend/src/app` | Next.js App Router route entry. 페이지는 얇게 두고 feature view 를 렌더링 |
| `apps/frontend/src/features` | 화면별 실제 구현. api → hooks(TanStack Query) → components 구조 |
| `apps/frontend/src/lib/api-base.ts` | BFF API base 결정. `NEXT_PUBLIC_API_BASE` 기반 static export 대응 |
| `apps/backend/src` | NestJS BFF 모듈. auth/member/metrics/alimtalk/review/opt-out/audit/admin/prisma/common |
| `apps/backend/prisma/schema.prisma` | Prisma schema. 변경 후 `bun --filter backend prisma:generate` 필수 |
| `packages/interfaces/src` | FE/BE 공유 API contract 타입 |
| `manifests` | ECS task/service 템플릿과 dev/prod deploy overlay |
| `.gitlab-ci.yml` | 수동 GitLab CI/CD |

---

## 4. 런타임 / 도메인

| 환경 | Frontend | Backend BFF | ECS |
|------|----------|-------------|-----|
| DEV | `https://dev-console.bomapp.co.kr` | `https://dev-console-api.bomapp.co.kr/api` | `DEV-Cluster / SVC-ECS-DEV-bomapp-console` 예정 |
| PROD | `https://console.bomapp.co.kr` | `https://console-api.bomapp.co.kr/api` | `PROD-Cluster / SVC-ECS-PROD-bomapp-console` 예정 |

- 위 도메인/ECS 값은 Terraform/manifest 계약 기준이다. 실제 AWS service apply 와 앱 배포는 아직 완료되지 않았다.
- Frontend: 정적 빌드 산출물 → S3 bucket(`dev-console.bomapp.co.kr`, `console.bomapp.co.kr`) → CloudFront(S3 REST + OAC). dev=`EXVTDDY5HF0A0`(d352raw7nesp6f.cloudfront.net), prod=`E1UJFJ3465PW03`(d10jh0u9sgdq6q.cloudfront.net). 딥링크는 S3 403/404 → `custom_error_response`로 `/index.html`(200) SPA 폴백 → 클라이언트 라우터가 처리.
  - **BOM-385/387: Vite + TanStack Router SPA 전환 (2026-07-10)**: 콘솔이 Next.js static export → Vite+TanStack Router **SPA**로 전환(BOM-385, dev·prod 배포·검증 완료)되면서, static export 서브라우트를 객체 경로로 재작성하던 CloudFront Function이 불필요해졌다. **BOM-387(infra MR !81, 2026-07-10 apply 완료)** 로 `aws_cloudfront_function.next_static_route_rewrite_{dev,prod}` 함수 리소스 + console distribution의 `dynamic function_association` + `static_sites_*` locals의 `next_static_routes` 플래그를 **전부 제거(디커미션)**. 이제 딥링크는 SPA 폴백(403/404→`/index.html`)만으로 처리한다. apply 순서 = distribution 먼저 갱신(association 제거·CF 배포 대기) → 함수 삭제(반대 순서면 `FunctionInUse` 409). 검증: dev·prod 콘솔 루트 200 + 딥링크(`/alimtalk/templates`, `/members`) 200(text/html, `x-cache: Error from cloudfront` = SPA 폴백 정상). 함수 2개 AWS에서 `NoSuchFunctionExists` 확인.
  - **(이력) BOM-327(2026-07-07~07-10)**: static export(`trailingSlash`) 시절 서브라우트 폴백 문제를 위 route-rewrite 함수(`/`→`index.html`, 무확장 세그먼트→`/index.html`, 동적 상세 라우트→`__static_export_placeholder__` 치환)로 해결했었다. SPA 전환(BOM-385)으로 근거 소멸 → BOM-387로 제거됨.
- Backend: ECS EC2 launch type, ARM64, container port `4000`, task family `TD-ECS-{ENV}-bomapp-console`, desired `1` 예정.
- Health check: backend `GET /health`, frontend `GET /healthz`.
- Backend global prefix: `/api` (`/health`는 prefix 제외).
- Session: `express-session` + Redis store. Redis 미설정 시 local/in-memory fallback 가능.

---

## 5. 배포

BOM-209/221 기준 배포 설계다. Terraform/manifest 는 console 명칭으로 정리되었지만, AWS service apply 와 앱 배포는 아직 미완료로 본다.

| 항목 | 값 |
|------|----|
| Pipeline target | `build`, `deploy`, `build-and-deploy`, `pr-check`, `runner-probe` |
| Environment | `dev`, `prod` |
| Backend image | `044488971141.dkr.ecr.ap-northeast-2.amazonaws.com/bomapp-console-backend:{YYYYMMDD}-{shortsha}` |
| Frontend artifact | `frontend-out/` → S3 sync + CloudFront invalidation |
| Rollback | `PIPELINE_TARGET=deploy` + 과거 immutable `IMAGE_TAG` 입력 |

최초 배포 bootstrap:

1. infra에서 ECS service 비의존 리소스(ECR/IAM/Secret metadata/log/SG/TG/listener/Route53/S3/CloudFront)를 먼저 apply.
2. Secrets Manager `bomapp/{dev,prod}/console` JSON 값을 채움.
3. console GitLab pipeline에서 `PIPELINE_TARGET=build-and-deploy` 실행. ECS service가 없으면 task definition `:1`만 등록하고 정상 종료.
4. infra에서 ECS service 리소스 apply. 이 시점에 `TD-ECS-<ENV>-bomapp-console:1` 이 있어야 함.
5. 같은 `IMAGE_TAG`로 `PIPELINE_TARGET=deploy`를 다시 실행해 service update.

적용 전 확인:

- CloudFront 인증서가 `dev-console.bomapp.co.kr`, `console.bomapp.co.kr`를 커버하는지 확인.
- ALB HTTPS 인증서가 `dev-console-api.bomapp.co.kr`, `console-api.bomapp.co.kr`를 커버하는지 확인.
- ECR repository 는 immutable 이므로 같은 `{YYYYMMDD}-{shortsha}` 재빌드는 실패한다.

---

## 6. Secrets

Secrets Manager IDs:

- `bomapp/dev/console`
- `bomapp/prod/console`

필수 JSON keys:

- `DATABASE_URL`
- `BACKOFFICE_SESSION_SECRET`
- `BACKOFFICE_REDIS_HOST`
- `BACKOFFICE_REDIS_PORT`
- `BACKOFFICE_REDIS_PASSWORD`
- `BACKOFFICE_REDIS_TLS`
- `BOMAPP_OPS_ADMIN_TOKEN`
- `ALIMTALK_DASHBOARD_TOKEN`

DB/Redis 값은 next-backend dev/prod 환경 Secret 값을 기준으로 복사 또는 매핑한다. 이 리포의 manifest 에는 key 이름만 있어야 하며 민감값은 커밋하지 않는다.

---

## 7. 의존성

| 대상 | 관계 | 설명 |
|------|------|------|
| infra | 배포/호스팅 | ECR/IAM/Secrets metadata/log/SG/TG/listener/Route53/frontend S3+CloudFront/ECS service 를 Terraform 코드로 소유할 예정. 실제 AWS service apply/deploy 미완료 |
| next-backend / bomapp-api | sync REST | `BOMAPP_OPS_ADMIN_BASE_URL` 로 Bomapp-owned admin API proxy. 지표 화면은 `GET /admin/bomapp-ops/metrics/engagement` 를 호출하며 `X-Bomapp-Ops-Token` / `BOMAPP_OPS_ADMIN_TOKEN` 계약을 사용 |
| next-backend / wings-api | sync REST | `BACKOFFICE_WINGS_BASE_URL` 로 wings/admin 기능 proxy. Wings 쪽 legacy admin 경로와 분리 |
| Aurora MySQL | database | Prisma read/write. console-owned 와 app-owned read-only 접근 구분 필요 |
| ElastiCache Redis | session store | `express-session` Redis store |

---

## 8. 검증 명령

기본 검증 목록:

```bash
bun install --frozen-lockfile
bun run typecheck
bun run lint
bun run test
bun run build
ruby -e 'require "yaml"; YAML.load_file(".gitlab-ci.yml"); puts "ok"'
```

배포 템플릿/이미지 검증:

```bash
# manifest render 산출물이 있으면 jq empty 로 JSON 문법 검증
jq empty rendered-task-definition.dev.json
jq empty rendered-task-definition.prod.json

# backend/frontend 이미지 빌드 검증
docker build -f Dockerfile.backend -t bomapp-console-backend:verify-review .
docker build -f Dockerfile.frontend -t bomapp-console-frontend:verify-review .
```

---

## 9. 주의 / 미검증

- AWS service apply 와 앱 배포는 아직 완료되지 않았다. 작업 전 Terraform main, GitLab pipeline, 실제 ECS/S3/CloudFront 상태를 다시 확인한다.
- BOM-209 시점의 backoffice 명칭 문서나 MR 설명이 남아 있을 수 있다. 신규 작업은 BOM-221 이후 console 명칭과 `bomapp/{dev,prod}/console` Secret 기준으로 진행한다.
- STG overlay는 현재 manifest 기준 없음. DEV/PROD만 배포 대상이다.
- desired count 는 현재 Terraform/manifest 계획 기준 `1`이다. 내부 운영 콘솔이라도 가용성 요구가 올라가면 desired count ≥ 2와 Redis/session 영향 검토가 필요하다.
- redmin 은 2026-06-10 신규 ECS 컷오버 완료 상태로 여전히 롤백 stub/운영 흔적이 남아 있다. Console 기능이 redmin을 완전히 대체했는지는 기능별 확인이 필요하다.
