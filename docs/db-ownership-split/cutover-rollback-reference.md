# DB 오너십 분리 컷오버 — 롤백 기준 (2026-07-20 추출)

rc/db-ownership-split → prod 병합 후, **컷오버 배포 직전 현재 running 중인** ECS 태스크 정의 리비전 + 앱 이미지 태그.
롤백 시 서비스를 아래 태스크 정의 리비전으로 되돌린다.

## 클러스터: `PROD-Cluster` (ap-northeast-2)

| 앱 | 서비스 | 롤백 대상 TaskDef | 앱 이미지 태그 | running |
|---|---|---|---|---|
| bomapp-api | SVC-ECS-PROD-bomapp-api | **TD-ECS-PROD-bomapp-api:74** | `bomapp-api:20260720-352dbc4b` | 2 |
| chat-api | SVC-ECS-PROD-chat-api | **TD-ECS-PROD-chat-api:34** | `chat-api:20260720-7c893459` | 2 |
| mydata-api | SVC-ECS-PROD-mydata-api | **TD-ECS-PROD-mydata-api:17** | `mydata-api:20260714-9fe2b549` (+secrets-init 사이드카) | 2 |
| mydata-batch | SVC-ECS-PROD-mydata-batch | **TD-ECS-PROD-mydata-batch:8** | `mydata-batch:20260710-4876186a` (+secrets-init 사이드카) | 1 |
| open-api | SVC-ECS-PROD-open-api | **TD-ECS-PROD-open-api:8** | `open-api:20260716-4fbddc35` | 2 |
| bomapp-batch | SVC-ECS-PROD-bomapp-batch | **TD-ECS-PROD-bomapp-batch:22** | `bomapp-batch:20260714-a25cf502` | 1 |
| statics-batch | SVC-ECS-PROD-statics-batch | **TD-ECS-PROD-statics-batch:5** | `statics-batch:20260609-802d07a` | 1 |
| wings-api | SVC-ECS-PROD-wings-api | **TD-ECS-PROD-wings-api:46** | `wings-api:20260720-7c893459` | 2 |
| mydata-mgmts-api | SVC-ECS-PROD-mydata-mgmts-api | **TD-ECS-PROD-mydata-mgmts-api:8** | `mydata-mgmts-api:20260615-724a5d0` (+secrets-init 사이드카) | — |

> recipient-extractor(messaging 오너)는 prod ECS 서비스에 아직 없음 — 컷오버 배포 대상 여부 별도 확인 필요.

## 롤백 방법 (앱별)
```bash
aws ecs update-service --region ap-northeast-2 --cluster PROD-Cluster \
  --service SVC-ECS-PROD-<app> \
  --task-definition TD-ECS-PROD-<app>:<위 리비전> \
  --force-new-deployment
```
- 위 태스크 정의 리비전은 **이전 앱 이미지 + 이전 datasource URL/설정**을 그대로 참조하므로, 서비스를 그 리비전으로 되돌리면 코드·설정 모두 컷오버 이전 상태로 복귀.
- **데이터 롤백은 별도**: 컷오버로 앱이 신규 스키마에 write를 시작했다면, 롤백 시 그 write분 처리(신규 스키마→bomapp_member 역동기 or 무시)는 데이터 정책에 따라 판단.
- 배치(batch)는 스케줄/수동 실행이라 running=1도 정상.
