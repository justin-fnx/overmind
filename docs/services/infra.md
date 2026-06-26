# infra

> BOMAPP AWS 인프라 IaC. Terraform 으로 ECS 기반 멀티서비스 환경(DEV/STG/PROD)을 관리한다.

| 항목 | 값 |
|------|----|
| 경로 | `../infra` |
| 리포 | `gitlab.bomapp.co.kr/bomapp/infra` (project id 34, default `main`) |
| 도구 | Terraform 1.5.7 / AWS Provider 5.100.0 |
| 첫 커밋 | 2026-04-10 |
| main 커밋(2026-06-24 조회) | `da065e2` (2026-06-24, `msc/bom-221-console-rename` merge / infra MR !55) |
| 총 커밋 수 | 50 |
| 활동 상태 | 활발 (수동 인프라 → Terraform 코드화 진행 중) |

---

## 1. 책임

- **AWS 리소스 IaC**: ECS, ALB/NLB, ElastiCache, ECR, Route53, ACM, CloudFront, IAM
- **환경 분리**: DEV / STG / PROD 클러스터 및 네트워크 구성 관리
- **운영 안전 장치**: 핵심 리소스에 `prevent_destroy`, ECS exec 활성화, Capacity Provider 정책
- **점진적 코드화**: 기존 수동/CloudFormation 혼재 자산을 import 기반으로 Terraform 으로 끌어오는 중

---

## 2. 디렉토리 구조

```
infra/
├── CLAUDE.md                       # 작업 규정 (destroy 금지, import 절차)
├── all_schemas.sql                 # DB 스키마 스냅샷
├── ecs-audit-report-20260406.md   # 2026-04 ECS 감사 리포트 (P0~P3 이슈)
├── rds-migration-plan-r6g.md      # RDS r6g 이행 계획
├── service-discovery-plan.md      # CloudMap / Service Connect 도입 계획
├── docs/
│   └── network-diagram.md         # 네트워크 1차 다이어그램
└── terraform/                    # ⬇ 환경별 모듈 구조 (MR !36 머지 + 적용 완료)
    ├── provider.tf  variables.tf
    ├── main.tf                    # module "shared"/"prod"/"stg"/"dev" 선언 + cross-module 배선
    │                              # (moved_*.tf 는 state mv 실현 후 제거됨 — 커밋 7eb31e5)
    ├── backend.tf                 # 빈 http backend (로컬 state 관행 — 로컬에선 제거하고 사용)
    ├── ecs_cross_env.tf           # env-spanning for_each (next_backend ECS 서비스/nb LT·ASG·CP/log-daemon)
    ├── iam_task_roles.tf          # env-spanning IAM task role/policy/attachment (9앱×3환경)
    ├── iam_cicd.tf                # github/gitlab OIDC deploy glue
    ├── security_group_rules_cross_env.tf   # 4개 cross-env SG rule (prod↔stg)
    ├── secrets.tf                 # external_mydata_auth_jks (stg/prod)
    ├── route53_records.tf         # 82개 cross-cutting 레코드 (shared zone + 여러 env LB/CF 참조)
    ├── terraform.tfstate          # 로컬 state (S3 backend 전환 예정)
    └── modules/
        ├── shared/                # 전역+네트워킹: vpc/subnet, ecr, acm, iam(전역), oidc,
        │                          #   route53 zone, cloudwatch, ES 인덱스 템플릿, silson static
        ├── prod/                  # prod 환경: SG, LB, listener/rule, TG(LB 단위 파일 분리),
        │                          #   elasticache, cluster, route53 records, S3/CF, IAM, secrets
        ├── stg/                   # stg 환경 (동일 구성)
        └── dev/                   # dev 환경 (동일 구성)
```

> **모듈 구조 (2026-06, MR !36 머지 + 적용 완료)**: 작업단위로 난립하던 `.tf` 를 **환경 디렉토리(모듈) → 인프라 종류별 파일** 로 재구성. 단일 root module(698 resource blocks / 995 instances) 을 `modules/{shared,dev,stg,prod}` + cross-cutting root 로 분리하되 **drift 불변**(`1 to add, 44 to change, 17 to destroy` 동일 + moved 통지 671건)을 검증.
> - **2026-06-11 적용 완료**: MR !36 머지(2209dee) 후 ① `terraform state mv` 566건으로 모듈 주소 이동 실현(AWS 무변경) → moved 블록 제거(7eb31e5), ② 드리프트 정리 코드 4커밋(cert·LB·webview/vkey·dev/stg 용량 large 복귀·폐기 리소스·mgmts 카나리 라이브값), ③ `-target` 점진 apply: **shared(4 chg) → dev(12 chg/5 destroy) → stg(8/5) → prod(13/5)**. prod 폐기분 = chat-redis 3 + 구 mydata-agent ns 1 + 고아 chat-api SG 1. prod task-def 6건은 가동 리비전 보호 위해 `state rm`(deregister 회피).
> - **잔여 드리프트 = 5 benign update**: `planner_card_ssr`(az_rebalancing+deploy% — 공유 ASG 용량 고려해 보수적 보류) + dev-wings grace 300→600 + webview stickiness(비활성, cosmetic) + route53 ttl 300→60 ×2(검증 토큰 값 불변). 생성·삭제·교체 0.
> - 의존: env/root → `shared` (acyclic). 환경 간 결합(prod 리스너룰→stg TG, stg subnet→prod VPC)은 root 가 변수로 중개.
> - root 잔류 = env 를 가로지르는 `for_each` 리소스·cross-env SG rule·CI/CD IAM·cross-cutting route53 (shared 로 옮기면 순환참조).
> - Target Group 은 한 파일 비대화 방지를 위해 **LB 단위 파일**로 분리(`target_groups_alb/nlb/internal_alb.tf`).

---

## 3. 작업 규정 (요약)

`infra/CLAUDE.md` 에 정의된 절대 규칙:

1. **Import 시**: `terraform state show` 출력을 기반으로 모든 속성을 코드에 반영. ForceNew 누락 = 운영 리소스 destroy 위험.
2. **Plan 검토**: `Plan: X to add, Y to change, Z to destroy` — **Z 가 0 이 아니면 절대 apply 금지**. replace(`-/+`) 도 destroy 와 동급으로 취급.
3. **Apply**: `-target` 으로 최소 범위부터 DEV → STG → PROD 순서. 무조건 `terraform apply` 금지.
4. **Lifecycle 보호**: ElastiCache RG, ECS Cluster/Service, ALB/NLB, ASG 에 `lifecycle { prevent_destroy = true }` 필수. 임시 해제도 금지.
5. **드리프트 방지**: 기본값에 의존 금지, AWS 실제 값을 명시적으로 코드화.

### 알려진 사고 사례
- ElastiCache `transit_encryption_mode` 누락 → destroy 시도 (prevent_destroy 가 차단)
- `sg-0fffa87cab285956a` 삭제된 SG 가 chat LT 에 잔존 (수정 완료)

---

## 4. 관리 리소스

### 4.1 ECS
13개 클러스터, [`architecture.md`](../architecture.md#7-ecs-클러스터--capacity-provider) 참조.

| 명명 규칙 | 패턴 | 예 |
|----------|------|-----|
| Cluster | `[ENV]-Cluster` | `DEV-Cluster` |
| Launch Template | `LT-ECS-[ENV]` | `LT-ECS-DEV` |
| Auto Scaling Group | `ASG-ECS-[ENV]` | `ASG-ECS-DEV` |
| Capacity Provider | `CP-ECS-[ENV]` | `CP-ECS-DEV` |
| Service | `SVC-ECS-[ENV]-[앱]` | `SVC-ECS-PROD-bomapp-api` |
| Task Definition | `TD-ECS-[ENV]-[앱]` | `TD-ECS-DEV-bomapp-api` (CI 가 등록) |
| Task Role | `[env]-[앱]-task-role` | `dev-bomapp-api-task-role` |

### 4.2 로드밸런서
5개 LB, 1개 인증서(`bomapp_multi_wildcard` ACM). [architecture §3.2](../architecture.md#32-로드밸런서-카탈로그) 참조.

### 4.3 Route53
2개 hosted zone (`bomapp.co.kr`, `bomapp.im`), 150+ 레코드. 환경 prefix(`dev-`/`stg-`/없음=PROD)로 분기.

### 4.4 ElastiCache (Redis)
- ~~`prod-chat-redis`: cache.r7g.large × 3, Multi-AZ, TLS + KMS 암호화, Redis 7.1~~ → **2026-06-11 폐기 완료**. ElastiCache 클러스터(수동 삭제) + Terraform 리소스(subnet group / SG `prod-chat-redis` / ingress rule `prod_chat_redis_from_prod_ecs_task`) destroy 적용. chat-api 는 공용 Redis(Serverless) 사용으로 정리됨. 고아 SG `SG-ECS-PROD-chat-api`(미부착)도 함께 제거.
- 추가 공용 Redis (Serverless 엔드포인트 TLS, next-backend Redisson 사용) — 일부는 Terraform 외 관리

### 4.5 CloudFront / S3
정적 프론트엔드 6개 앱(DEV/STG 분리), OAC 적용. PROD 정적 리소스(`cloudfront.bomapp.co.kr`, `market.bomapp.co.kr`, `image.planner.bomapp.co.kr` 등)는 별도 distribution.

BOM-209/221 기준 `bomapp-console` frontend S3+CloudFront(`dev-console.bomapp.co.kr`, `console.bomapp.co.kr`)와 backend ECS/ALB 리소스(`SVC-ECS-{ENV}-bomapp-console`, `dev-console-api`, `console-api`)가 Terraform 코드에 준비되어 있다. 실제 AWS service apply 와 앱 배포는 아직 완료되지 않았다.

---

## 5. 네트워크

### 5.1 VPC
- DEV: `vpc-00a0692c94e2d9340` (10.90.0.0/16)
- PROD/STG 공유: `vpc-0c1947d3152076528` (10.1.0.0/16)

### 5.2 NAT
- DEV: `NGW-dev-vpc` (`nat-0e48567177d6f87e3`)
- STG/PROD: PROD VPC 내 공용 NAT

### 5.3 VGW 연동 대역
| 대역 | 용도 |
|------|------|
| `172.16.100.0/24` | 온프레미스 (HQ — GitLab/모니터링) |
| `192.168.100.0/24` | HQ 사내망 |
| `192.168.200.0/24` | VDI |
| `10.0.77.0/24` | SSL VPN |

### 5.4 Security Group 패턴
- 인스턴스 outbound 용 별도 SG: `SG-[ENV]-ECS-outbound` (443/tcp 0.0.0.0/0)
- 태스크 간 통신: `SG-[ENV]-ECS-task` (같은 SG 모든 포트)
- inline ingress/egress 대신 `aws_vpc_security_group_ingress_rule` 개별 리소스 사용 (drift 방지)

---

## 6. 알려진 이슈 (ECS 감사 리포트 2026-04-06 발췌)

### P0
- PROD 4개 태스크 awslogs 미설정 (장애 대응 불가)
- 6개 태스크 SSH 포트 22 외부 노출

### P1
- PROD 7개 서비스 헬스체크 미설정
- `backend-was v7/8`, `mydata-api` IAM Role 누락
- PROD-BACK / PROD-FRONT-NEXT Circuit Breaker disabled
- chat-api 이미지 태그 `latest`

### P2~P3
- 오토스케일링 5개 서비스 누락
- Container Insights 3개 클러스터 미활성
- 클러스터 통합 13 → 6 권장
- 유휴 EC2 7대 (월 $167)
- 미사용 Target Group 25개

### Terraform 미관리
RDS, MSK, S3 일부, WAF, VPC 라우팅 테이블, NAT Gateway, IGW, 일부 ACM, CloudFront 일부.

---

## 7. 운영

| 항목 | 내용 |
|------|------|
| Backend | 로컬 `terraform.tfstate` (S3 backend 전환 예정) |
| Apply 방식 | 수동 `terraform apply -target=...` (CI 자동 apply 없음) |
| 변경 절차 | plan → 검토 → -target apply → AWS 콘솔 확인 |
| 로깅 | CloudWatch (일부 누락, 위 P0 참조) |
| 모니터링 | 온프레미스 Grafana/Prometheus/Elastic + AWS Container Insights (일부) |

---

## 8. 히스토리 마일스톤

- **2026-04-10** Terraform IaC 프로젝트 초기화 (수동/CloudFormation 자산을 import 기반으로 끌어오기 시작)
- **2026-04** ECS 클러스터·서비스, ALB/NLB, ElastiCache, ECR, Route53 import
- **2026-04-06** ECS 감사 리포트 작성 (P0~P3 이슈 명세화)
- **2026-05-06** 미사용 Target Group 29개 정리, ASG 정상화
- **2026-06-23~24** bomapp-console 인프라 계약 정리(BOM-209/221): backend ECR/IAM/Secrets/log/SG/TG/listener/Route53/ECS service + frontend S3/CloudFront 코드 준비. 실제 AWS service apply/deploy 미완료

---

## 9. 작업 시 주의사항

- `terraform.tfstate*`, `tfplan*` 파일은 민감 정보 포함 가능 → 로그/리포트에 절대 포함하지 않음
- DEV → STG → PROD 순서 고수
- `prevent_destroy` 해제 금지
- `aws:cloudformation:*` 태그는 Terraform 으로 관리 불가 (코드에서 제외)
- `ASG.desired_capacity` 직접 변경 금지 (ECS Capacity Provider 가 관리; `ignore_changes = [desired_capacity]`)

---

## 10. 관련 문서

- [`../architecture.md`](../architecture.md) — 전체 시스템 도식
- `../../infra/CLAUDE.md` — 작업 규정 원본
- `../../infra/ecs-audit-report-20260406.md` — 감사 결과
- `../../infra/service-discovery-plan.md`
- `../../infra/rds-migration-plan-r6g.md`
- 노션: `BOMAPP 인프라 구조(HQ/AWS)`, `AWS ECS 구성 점검 리포트`, `Terraform 초기 셋업 및 기존 AWS 인프라 연동 준비`
