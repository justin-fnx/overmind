# bomapp-backoffice

> 보맵 내부 운영자를 위한 신규 백오피스. 레거시 `legacy-backend/bomapp_redmin` 을 대체하는 방향의 독립 GitLab 리포이며, `next-frontend` 의 `planner-admin` 과는 별개 서비스다.
> 최신 근거: GitLab `bomapp/backoffice` project id 36, default `main`, MR !7 `[BOM-209] 백오피스 GitLab 배포 파이프라인 추가` head `5d848bef` (2026-06-23 17:14 KST 조회 기준 open, pipeline 693 failed).

---

## 1. 기본 정보

| 항목 | 값 |
|------|----|
| 리포 | `gitlab.bomapp.co.kr/bomapp/backoffice` |
| 로컬 경로 | `../bomapp-backoffice` |
| 기본 브랜치 | `main` |
| 기술 스택 | Bun 1.3 / Turborepo / TypeScript / Next.js 16 / React 19 / NestJS 11 / Prisma 6 |
| 구성 | `apps/frontend`(Next.js admin UI) + `apps/backend`(NestJS Admin BFF) + `packages/*` 공유 타입/상수/함수 |
| 목적 | redmin 대체 내부 운영 콘솔. 멤버 조회, 지표, 알림톡, 앱리뷰, opt-out, 감사 로그, 관리자 계정 관리 |

> `AGENTS.md` 는 pnpm/Node 기준으로 stale 이다. 현재 기준은 `CLAUDE.md`와 `README.md`이며 모든 명령은 Bun을 사용한다.

---

## 2. 아키텍처 규칙

백오피스 backend 는 범용 API가 아니라 **thin Admin BFF** 다. 데이터 소유권에 따라 접근 방식이 갈린다.

| Tier | 데이터 소유자 | 접근 방식 |
|------|---------------|-----------|
| T1 | backoffice-owned (관리자 계정, 감사 로그) | Prisma 직접 read/write |
| T2 | app-owned read (회원, 지표 등) | Prisma 직접 read-only |
| T3 | app-owned write (알림톡, 리뷰, opt-out 등) | 소유 서비스의 admin API 로 proxy. 직접 write 금지 |

중요 규칙: next-backend 등 앱 소유 데이터에 write 가 필요하면 backoffice DB 직접 변경이 아니라 owner API 를 먼저 만든 뒤 proxy 한다. upstream API 가 없으면 화면/로직은 stub 으로 두고 나중에 연결한다.

---

## 3. 주요 경로

| 경로 | 설명 |
|------|------|
| `apps/frontend/src/app` | Next.js App Router route entry. 페이지는 얇게 두고 feature view 를 렌더링 |
| `apps/frontend/src/features` | 화면별 실제 구현. api → hooks(TanStack Query) → components 구조 |
| `apps/frontend/src/lib/api-base.ts` | BFF API base 결정. MR !7에서 `NEXT_PUBLIC_API_BASE` 기반 static export 대응 |
| `apps/backend/src` | NestJS BFF 모듈. auth/member/metrics/alimtalk/review/opt-out/audit/admin/prisma/common |
| `apps/backend/prisma/schema.prisma` | Prisma schema. 변경 후 `bun --filter backend prisma:generate` 필수 |
| `packages/interfaces/src` | FE/BE 공유 API contract 타입 |
| `manifests` | ECS task/service 템플릿과 dev/prod deploy overlay |
| `.gitlab-ci.yml` | MR !7에서 추가된 수동 GitLab CI/CD |

---

## 4. 런타임 / 도메인

| 환경 | Frontend | Backend BFF | ECS |
|------|----------|-------------|-----|
| DEV | `https://dev-admin.bomapp.co.kr` | `https://dev-admin-api.bomapp.co.kr/api` | `DEV-Cluster / SVC-ECS-DEV-bomapp-backoffice` |
| PROD | `https://admin.bomapp.co.kr` | `https://admin-api.bomapp.co.kr/api` | `PROD-Cluster / SVC-ECS-PROD-bomapp-backoffice` |

- Frontend: Next.js static export → S3 bucket(`dev-admin.bomapp.co.kr`, `admin.bomapp.co.kr`) → CloudFront.
- Backend: ECS EC2 launch type, ARM64, container port `4000`, task family `TD-ECS-{ENV}-bomapp-backoffice`, desired `1`.
- Health check: backend `GET /health`, frontend `GET /healthz`.
- Backend global prefix: `/api` (`/health`는 prefix 제외).
- Session: `express-session` + Redis store. Redis 미설정 시 local/in-memory fallback 가능.

---

## 5. 배포

MR !7은 next-backend 방식과 맞춘 수동 GitLab CI/CD를 추가하는 변경이다. 2026-06-23 17:14 KST 조회 기준 MR !7은 아직 main에 머지되지 않았고 head pipeline 693이 failed 상태라, 아래 스펙은 MR !7 기준의 배포 설계로 본다.

| 항목 | 값 |
|------|----|
| Pipeline target | `build`, `deploy`, `build-and-deploy`, `pr-check`, `runner-probe` |
| Environment | `dev`, `prod` |
| Backend image | `044488971141.dkr.ecr.ap-northeast-2.amazonaws.com/bomapp-backoffice-backend:{YYYYMMDD}-{shortsha}` |
| Frontend artifact | `frontend-out/` → S3 sync + CloudFront invalidation |
| Rollback | `PIPELINE_TARGET=deploy` + 과거 immutable `IMAGE_TAG` 입력 |

최초 배포 bootstrap:

1. infra에서 ECS service 비의존 리소스(ECR/IAM/Secret metadata/log/SG/TG/listener/Route53/S3/CloudFront)를 먼저 apply.
2. Secrets Manager `bomapp/{dev,prod}/backoffice` JSON 값을 채움.
3. backoffice GitLab pipeline에서 `PIPELINE_TARGET=build-and-deploy` 실행. ECS service가 없으면 task definition `:1`만 등록하고 정상 종료.
4. infra에서 ECS service 리소스 apply. 이 시점에 `TD-ECS-<ENV>-bomapp-backoffice:1` 이 있어야 함.
5. 같은 `IMAGE_TAG`로 `PIPELINE_TARGET=deploy`를 다시 실행해 service update.

적용 전 확인:

- CloudFront 인증서가 `dev-admin.bomapp.co.kr`, `admin.bomapp.co.kr`를 커버하는지 확인.
- ALB HTTPS 인증서가 `dev-admin-api.bomapp.co.kr`, `admin-api.bomapp.co.kr`를 커버하는지 확인.
- ECR repository 는 immutable 이므로 같은 `{YYYYMMDD}-{shortsha}` 재빌드는 실패한다.

---

## 6. Secrets

Secrets Manager IDs:

- `bomapp/dev/backoffice`
- `bomapp/prod/backoffice`

필수 JSON keys:

- `DATABASE_URL`
- `BACKOFFICE_SESSION_SECRET`
- `BACKOFFICE_REDIS_HOST`
- `BACKOFFICE_REDIS_PORT`
- `BACKOFFICE_REDIS_PASSWORD`
- `BACKOFFICE_REDIS_TLS`
- `ALIMTALK_DASHBOARD_TOKEN`

DB/Redis 값은 next-backend dev/prod 환경 Secret 값을 기준으로 복사 또는 매핑한다. 이 리포의 manifest 에는 key 이름만 있어야 하며 민감값은 커밋하지 않는다.

---

## 7. 의존성

| 대상 | 관계 | 설명 |
|------|------|------|
| infra | 배포/호스팅 | ECR/IAM/Secrets metadata/log/SG/TG/listener/Route53/frontend S3+CloudFront/ECS service 소유 |
| next-backend / bomapp-api | sync REST | `BACKOFFICE_ADMIN_BASE_URL` 로 admin 기능 proxy |
| next-backend / wings-api | sync REST | `BACKOFFICE_WINGS_BASE_URL` 로 wings/admin 기능 proxy |
| Aurora MySQL | database | Prisma read/write. backoffice-owned 와 app-owned read-only 접근 구분 필요 |
| ElastiCache Redis | session store | `express-session` Redis store |

---

## 8. 검증 명령

MR !7 검증 목록:

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
docker build -f Dockerfile.backend -t bomapp-backoffice-backend:verify-review .
docker build -f Dockerfile.frontend -t bomapp-backoffice-frontend:verify-review .
```

---

## 9. 주의 / 미검증

- MR !7 조회 시점(2026-06-23 17:14 KST)의 상태는 `opened`, head pipeline 693은 `failed`였다. MR 머지와 pipeline 성공, 실제 ECS/S3/CloudFront 배포 여부를 재확인해야 한다.
- backoffice 인프라 리소스는 infra MR !54(`msc/bom-209-backoffice-infra`)로 `bomapp/infra` main에 먼저 반영되었다. 앱 코드/배포 파이프라인 MR !7의 성공 여부와는 별도로 확인한다.
- STG overlay는 MR !7 기준 없음. DEV/PROD만 배포 대상이다.
- desired count 는 MR !7 기준 `1`이다. 내부 운영 콘솔이라도 가용성 요구가 올라가면 desired count ≥ 2와 Redis/session 영향 검토가 필요하다.
- redmin 은 2026-06-10 신규 ECS 컷오버 완료 상태로 여전히 롤백 stub/운영 흔적이 남아 있다. backoffice 기능이 redmin을 완전히 대체했는지는 기능별 확인이 필요하다.
