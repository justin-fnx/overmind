# DB 오너십 분리 — 무중단 이관 runbook (DMS 프리로드 + CDC-only)

> next-backend 다수 앱이 오너십 경계 없이 공유하던 단일 `bomapp_member` 스키마를
> **서비스별 논리 스키마 5종**으로 분리하고, 비오너는 내부 API로만 접근하도록 만드는
> 초석 작업. 이 문서는 **데이터 이관**(DMS) 절차와 이번 세션에서 얻은 교훈, 그리고
> **PROD 구축 runbook**을 담는다. 스키마/코드/Flyway 측면은 next-backend
> `docs/schema-drift-and-cleanup.md`·`docs/db-ownership-split-migration.md`(rc 브랜치) 참조.

## 0. 스키마 할당 (오너십 경계)

| 논리 스키마 | 오너 서비스(모듈) | 테이블 수 | 비고 |
|---|---|---|---|
| `chat` | chat-api | 53 | rename 48 (chat_/kakaopay_chat_ 접두사 제거, deployed_/kakaopay_ 유지) |
| `mydata` | mydata-api | 46 | rename 46 (my_data_/log_my_data_ 접두사 제거) |
| `planner` | wings-api | 34 | rename 30 (w_ 접두사 제거, planner_/recommend_amount_ 유지) |
| `messaging` | recipient-extractor(messaging) | 9 | rename 0 (접두사 없음) |
| `bomapp` | bomapp-api | 55 | rename 0 (db_core→`bomapp` 명명, 접두사 없음) |
| **(잔류)** `bomapp_member` | — | 나머지 | 경계 모호 케이스 + reference + **member/PII(향후 별도 member 서비스, Tier S 보수적 리뷰)** 전부 현행 유지, 하나씩 처리 |

- **합계 이관 대상 197 테이블.** 스키마=서비스 원칙 → 잉여 서비스 접두사 제거(rename).
- rename 맵 정본 = infra `terraform/dms_temp.tf`의 `local.dms_dev_schema_rename_map`.
  사본 = `docs/db-ownership-split/rename_map.tsv` (old<TAB>new<TAB>schema, 197행).
- **member/PII 는 이관 대상에 미포함** — 향후 별도 `member` 서비스로 분리, 민감정보라
  Tier S(보수적) 코드리뷰. open 도 정체 불명확 → 잔류.

## 1. 이관 방식: 왜 "프리로드 + CDC-only" 인가

같은 Aurora 인스턴스 내부에서 `bomapp_member` → 신규 스키마로 옮기되 **앱 무중단**이 목표.
RENAME/뷰는 불가(즉시 앱 파손, write 걸림) → **실시간 싱크(CDC)** 필요.

- **당초 계획**: DMS full-load-and-cdc 5개(스키마당 1태스크) 동시.
- **문제**: 소형 dev Aurora가 5개 동시 full-load 커넥션을 못 버팀 →
  `ODBC general error ... RECOVERABLE`. MaxFullLoadSubTasks 8→2 로도 blip.
- **전환**: **프리로드**(수동 `INSERT..SELECT` 초기 스냅샷) + **DMS CDC-only**
  (스냅샷 직전 binlog 위치부터 변경만). full-load 커넥션 폭주 회피 + 비용↓.
  → 이 방식이 **prod 이관 절차의 정본**이며 dev 는 그 리허설이다.

## 2. ⚠️ 핵심 함정 (이번 세션의 실증 교훈)

### 2-1. Aurora 는 FTWRL·GTID 를 막는다
- `FLUSH TABLES WITH READ LOCK` → **root 조차 `ERROR 1045 Access denied`** (RDS는
  RELOAD 권한을 root/master에도 안 줌; `mysqldump --master-data` 실패 이유와 동일).
- `gtid_mode` 파라미터 부재 + `enforce_gtid_consistency=None` → **GTID OFF**(켜려면 리부트).
- **해법**: `START TRANSACTION WITH CONSISTENT SNAPSHOT` 로 무잠금 일관 스냅샷.
  root 는 REPLICATION CLIENT 권한이 있어 `SHOW MASTER STATUS` 는 됨 →
  **스냅샷 직전에 위치 캡처** → 거기서부터 CDC = 최악의 경우 미세 중복만(유실 없음).

### 2-2. 스키마 드리프트는 실재하며 양방향이다
V1 타깃 DDL을 옛 스냅샷(dev_schema.sql, 6/22) 기준으로 만들면 현행 소스와 어긋난다.
- **소스-앞섬**(6 테이블): 현행에만 있는 신규 컬럼 — `bizgo_image_url`×3(chat, Bizgo 전환),
  `segment_id`/`segment_revision`/`canceled_at`/`canceled_by`(messaging×2, BOM-285 세그먼트),
  `notice_id`(planner.notification). → `SELECT *` 시 컬럼 수 초과로 abort(ERROR 1136).
- **타깃-앞섬**(1 테이블): `chat.view_state` — V1엔 있고 소스엔 없는 5컬럼. → `SELECT` 시
  Unknown column(ERROR 1054).
- **해법(프리로드)**: `SELECT *` 금지 → **소스∩타깃 교집합 컬럼만 명시** INSERT.
  소스-only는 무시, 타깃-only는 빈 채. (`gen_preload.py` 가 자동 처리)
- **🔴 PROD 필수**: prod V1 은 반드시 **현행 prod 스키마 덤프 기준**으로 재생성 →
  드리프트 0 → 교집합=전체 → **무손실**. dev는 리허설이라 교집합으로 넘겼지만
  prod에서 교집합에 의존하면 위 신규 컬럼 데이터가 유실된다.

### 2-3. 생성 컬럼(GENERATED)은 INSERT에서 제외
- `mydata.insurance_general_transaction`·`mydata.insurance_transaction`의
  `payment_no_numeric` = `GENERATED ALWAYS AS (...) VIRTUAL` → INSERT 대상 아님
  (타깃이 자동 계산). 넣으면 `ERROR 3105`. `gen_preload.py` 가 DDL에서 감지·제외.
  DMS CDC도 생성컬럼은 타깃에서 자동 계산하므로 동일하게 무해.

### 2-4. DMS CdcStartPosition (MySQL) = `<binlog_file>:<position>`
- 예: `mysql-bin-changelog.000038:45339874`. **타임존 무관**이라 `CdcStartTime`(시각)보다
  안전. Aurora `NOW()` 타임존이 UTC가 아니면 CdcStartTime이 미래로 잡혀 **CDC가 늦게
  시작=유실** 위험. → 항상 **위치** 사용.

### 2-5. 실행 이력이 있는 DMS 태스크는 위치 재지정 시 "재생성" 필요
- `modify + start-replication` → `InvalidParameterCombination: valid only for tasks
  running for the first time`. `resume-processing`은 새 위치 무시(마지막 체크포인트).
- **해법**: TF `-replace` 로 destroy+create → 새 태스크 = 첫 시작 → cdc_start_position 반영.
  모듈이 `migration_type`/`cdc_start_position`/`start_replication_task` 를 변수화(MR!79).

### 2-6. 🔴 DMS 유저는 `awsdms_control` 권한이 필수 (누락 시 태스크 FATAL)
- DMS는 타깃에 **제어/검증 메타데이터 DB `awsdms_control`**(체크포인트·예외·validation
  상태)을 만들어 쓴다. 유저에게 타깃 스키마 권한만 주고 `awsdms_control` 을 빠뜨리면:
  ```
  [TARGET_APPLY] E: NativeError: 1044 Access denied for user '<dms>'@'%' to database 'awsdms_control'
  ```
  → CDC apply 실패 → **9회 재시도 후 태스크 FATAL** → 대시보드 활성 0.
- **이것이 validation 이 "정체/Not enabled/Table error" 로 보이는 진짜 원인**이었다
  (동일-인스턴스 collation 이 아님 — dev 실증으로 정정). awsdms_control 권한 부여 후
  validation 이 정상 진행(Validated/Pending/Mismatched 로 이동).
- **해법(소스·타깃 공통 유저 GRANT 에 반드시 포함)**:
  ```sql
  GRANT ALL PRIVILEGES ON `awsdms_control`.* TO '<dms_user>'@'%'; FLUSH PRIVILEGES;
  ```
  (없으면 유저가 awsdms_control DB 자체를 생성 못 함 → 1044.)
- **잔여 함정**: 특정 테이블(예 `chat.ban_word`, 한글 varchar)은 `ValidationFailedRecords=0`
  인데도 "Table error" 가 남을 수 있다(validation-레이어, 실데이터 복제는 정상). 1개
  수준이면 무시 가능. 1차 검증은 **행수 대조**(`gen_count_check.py`)+pt-table-checksum,
  DMS validation 은 보조.
- **재시작 후 일시적 Mismatch**: 태스크가 실패해 있던 구간의 source 변경분을 CDC 가
  뒤늦게 재생하는 동안 validation 이 잠시 Mismatch 로 보이다 CDCLatency→0 되며 수렴한다
  (데이터 문제 아님).

### 2-7. 네트워킹 (지난 사고 교훈)
- **SM VPC 엔드포인트 금지**: `private_dns_enabled=true` 가 VPC 전역 DNS를 가로채
  **dev 앱 전체의 Secrets Manager 접근을 끊는 사고**를 냄. 엔드포인트 제거.
- **해법**: DMS replication instance를 **NAT-egress 서브넷**(dev was-a
  `subnet-0f303cbf277c2d579` / was-b `subnet-07761b99500c396f3`)에 두고 DMS SG
  `443→0.0.0.0/0` egress 로 SM/CloudWatch 도달. `create_secretsmanager_vpc_endpoint=false`.
- 구 DB 서브넷(SBN-dev-db-*)은 격리/IGW라 인터넷 egress 불가 → DMS엔 부적합.

### 2-8. TF 운영 함정
- **fetch ≠ pull**: MR 머지 후 반드시 `git pull`로 워킹트리에 반영 후 plan(안 하면 DMS
  자원이 plan에 안 보이고 남의 드리프트만 보임).
- **`-target=module.dev_dms`** 로 타 팀 드리프트와 격리. saved plan 리뷰 후 apply.
- **apply는 백그라운드**: foreground Bash 2분 타임아웃 → 고아 DMS 태스크 발생.
- **`-auto-approve`는 classifier가 차단**(수동 드리프트 후 blind apply). saved-plan apply만.
- source 엔드포인트 `database_name '' -> 'bomapp_member'` in-place diff는 드리프트 정정(무해).

## 3. dev 리허설 결과 (2026-07-09 완료)

| 단계 | 결과 |
|---|---|
| 논리 스키마 5종 생성 + V1 Flyway 적용(오너 모듈별, 로컬) | ✅ |
| 테이블 rename 반영(V1 재생성 + DMS table-rename transformation) | ✅ MR 반영 |
| 프리로드(교집합+생성컬럼 제외, 197 테이블) | ✅ 성공 |
| binlog 위치 캡처(무FTWRL/GTID) | ✅ `mysql-bin-changelog.000038:45339874` |
| DMS 5태스크 → CDC-only 전환(TF, `-replace`) | ✅ infra MR!79 머지·apply(5 add/1 chg/5 destroy) |
| 5태스크 CDC 기동 | ✅ 전부 `cdc`+`running`, 실패 0 |
| 행수 대조 검증 | `~/dms_count_check.sql` (결과 비면 완전 일치) |

## 4. 🚀 PROD 구축 runbook

> dev와 동일 모듈(`modules/shared/dms`) 재사용. **저트래픽 새벽창** 권장.

### P0. 데이터량 측정 → 방식 결정
```sql
SELECT table_name, table_rows, ROUND(data_length/1048576) AS data_mb
FROM information_schema.tables WHERE table_schema='bomapp_member'
ORDER BY data_length DESC LIMIT 30;
```
- 복사 <30~60분 예상 → **프리로드(단일 일관 스냅샷)** + CDC-only (dev와 동일, 최저비용).
- 대용량(수시간) → 거대 트랜잭션 회피: **적정크기 DMS full-load**(병렬·청크·재개, DMS가
  일관성 처리) 또는 테이블별 프리로드 + 단일 이른 CdcStartTime.

### P1. prod 스키마 + V1 (드리프트 0)
1. prod `bomapp_member` 스키마 덤프: `mysqldump --no-data`.
2. **V1 = 현행 prod 스키마 기준 재생성**(§2-2 필수). `scripts/gen_target_ddl.py` 재사용
   (AUTO_INCREMENT 카운터 제거, 셋 간 FK 절단). rename 맵은 `rename_map.tsv` 그대로.
3. prod 논리 스키마 5종 생성 + V1 적용(오너 모듈 Flyway, CI 또는 로컬).
4. binlog 활성(ROW/FULL) 확인.

### P2. prod DMS 인스턴스화 (TF)
- `dms_temp.tf` 에 prod 블록 추가(dev 블록 대칭): `module "prod_dms"` `count = var.dms_prod_enabled ? 1 : 0`.
  - `env="prod"`, prod VPC/서브넷(**NAT-egress**, §2-7), prod Aurora SG/엔드포인트,
    prod DMS 전용 시크릿 ARN(username/password/host/port 포맷).
  - `create_secretsmanager_vpc_endpoint=false` (prod에 SM 엔드포인트 있으면 재사용,
    없으면 NAT egress; **절대 private_dns 엔드포인트 새로 만들지 말 것**).
  - `replication_instance_class` prod 데이터량에 맞게(dev=dms.t3.medium), `multi_az=true` 권장.
  - Tier S: source/target 엔드포인트 `ssl_mode=require`.
  - **prod Aurora 본체엔 `prevent_destroy` 유지**(모듈은 SG ingress 룰만 추가, 본체 미소유).
- `terraform plan -target=module.prod_dms` → destroy 0 확인 → saved plan → apply(백그라운드).
- **prod apply/exec/MR머지는 classifier 개별 승인** 대상.

### P3. 프리로드 (새벽창)
1. src_cols 덤프(§gen_preload 헤더) → `gen_preload.py --ddl-dir <prod renamed> --src-cols
   <prod src_cols> --rename rename_map.tsv` → `preload.sql`.
   - **드리프트 0 이면** 교집합=전체, 생성컬럼만 제외 → 무손실.
2. `mysql -h <prod-writer> -u <admin> -p < preload.sql` (한 세션).
3. 출력의 `SHOW MASTER STATUS` File:Position 기록 → CdcStartPosition.

> ⚠️ **커넥션 예산(1040 Too many connections)**: full-load는 태스크당
> MaxFullLoadSubTasks(기본 8)×5태스크=~40 로드 커넥션 + validation(ThreadCount 5×5)
> + 앱 커넥션이 겹친다. 소형 Aurora는 초과로 제일 무거운 태스크(mydata 46테이블)부터
> RECOVERABLE 실패(dev 실증). prod: ①태스크 **스태거드 시작**(전부 동시 X) ②prod
> `max_connections` 헤드룸 사전 확인 ③부족 시 MaxFullLoadSubTasks 하향.
>
> 🔴 **writer CPU 포화(prod 카나리 실측)**: mydata 단독 full-load(subtasks=8)만으로
> **writer CPU 11%→99% 포화**(ReadIOPS 8→1500, ReadLat은 4ms로 버팀). 병목=CPU.
> STOP하면 회복(부작용=타깃 부분데이터, 재실행 reload로 덮음). **prod 대형 full-load는:
> ①반드시 새벽 저트래픽 ②MaxFullLoadSubTasks 8→4/2 하향 ③대형(mydata/bomapp) 순차
> (하나로도 CPU 포화 → 동시 금지) ④CloudWatch CPU/ReadLatency 감시.** 경량 스키마
> (chat/planner/messaging ~10GB)는 업무시간에도 무해(카나리로 5pass 확인).
>
> 🔴 **타깃 FK 제약 → CDC 1216 실패 (필수 선반영)**: 타깃 스키마에 FK가 있으면
> (chat 9/mydata 16/bomapp 4/planner 2) CDC 적용이 부모-자식 순서를 못 지켜
> `NativeError 1216 (foreign key constraint fails)`로 태스크 FATAL(prod chat 실증).
> **full-load는 벌크라 통과하고 CDC 전환 후에야 터진다**(초기엔 안 보임). 해법 = 타깃
> 엔드포인트 `extra_connection_attributes="initstmt=SET FOREIGN_KEY_CHECKS=0"`
> (소스가 무결성 보장 → 안전; infra MR!82). 엔드포인트 modify는 시크릿 인증 보존되나
> (test-connection 확인) 돌던 태스크는 **재시작해야 반영**. messaging(FK 0)만 무관.
>
> 🔴 **생성 컬럼(GENERATED) → CDC 3105 (필수 선반영)**: `payment_no_numeric`
> (mydata insurance_general_transaction·insurance_transaction, GENERATED ALWAYS AS
> …VIRTUAL) 처럼 생성 컬럼이 있으면 **full-load는 자동 제외해 통과하지만 CDC는
> binlog 기반 INSERT에 포함**→`NativeError 3105 (value specified for generated column
> not allowed)`→FATAL. **한 테이블 3105가 태스크 전체를 stall**(다른 테이블 로드까지
> 멈춤 — mydata가 46GB 대형 테이블 앞에서 멈춘 게 실은 이 3105 루프였음). 해법 = 태스크
> table-mappings에 `rule-action: remove-column`(object-locator=소스명, column-name=
> 생성컬럼) → modify-replication-task → resume-processing(45개 재적재 없이 이어감).
> ⚠️ module 매핑생성은 컬럼 메타가 없어 자동으로 못 넣음 → 현재는 CLI 수정(teardown이
> destroy하므로 OK; 태스크 재생성 시 유실 주의). **FK 1216과 함께 "full-load 통과·CDC
> 폭발" 쌍둥이 함정** — 반드시 CDC 전환 전 두 설정을 선반영.

### P4. DMS → CDC-only 전환 + 시작
- `module "prod_dms"` 에 `migration_type="cdc"` + `cdc_start_position="<file>:<pos>"` +
  `start_replication_task=true`.
- `terraform plan -target=module.prod_dms -replace='module.prod_dms[0].aws_dms_replication_task.schema["<각 스키마>"]'`
  (5개) → apply.
- 5태스크 `cdc`+`running` 확인.

### P5. 검증
- 행수 대조: `gen_count_check.py --rename rename_map.tsv` → prod에서 실행(결과 비면 일치).
- (선택) pt-table-checksum 로 컬럼 레벨 무결성.
- CDC 라이브 스모크: 소스에 테스트 행 INSERT → 타깃 수 초 내 반영 확인 → 삭제(삭제도 전파).

### P6. 컷오버(별도 단계) → teardown
- **✅ prod 컷오버 완료(2026-07-21, BOM-399/BOM-423).** 절차·실행 결과 정본 = `docs/db-ownership-split/cutover-runbook.md`. teardown(`dms_prod_enabled=false`)은 롤백 윈도우 유지 후 **별도 승인**으로 실행(§4 사후).
- **프리로드 ≠ 컷오버.** 컷오버 = 앱 datasource 를 신규 스키마로 전환(오너=write, 비오너=내부 API).
  CDC가 그 사이를 계속 따라잡으므로 새벽 프리로드와 다른 시점이어도 됨. single-writer flip.
- 컷오버·검증 후: `dms_prod_enabled=false` apply → **DMS 임시자원 전량 teardown**(토글 한 방;
  prevent_destroy 없음, aurora 임시 ingress 룰도 딸려 제거). CDC 창은 짧게(비용·undo·복제 노출↓).

## 5. 비용 / teardown

- dev DMS(dms.t3.medium 단일 AZ + 50GiB) ≈ **$1.9/day**. 검증 끝나면 `dms_dev_enabled=false`.
- teardown = 토글 flip 후 apply. prevent_destroy 미부여(임시자원 원칙).
- **overmind 리모트 오염 점검**(절대규칙 12): 세션 종료 전 `git remote -v` = origin·gitlab 둘뿐.

## 6. 산출물 / 스크립트 (이 디렉토리)

- `db-ownership-split/rename_map.tsv` — rename 맵 197행(정본=infra dms_temp.tf).
- `db-ownership-split/scripts/gen_target_ddl.py` — 타깃 V1 DDL 생성(카운터 제거·FK 절단).
- `db-ownership-split/scripts/gen_preload.py` — 프리로드 생성(교집합+생성컬럼 제외).
- `db-ownership-split/scripts/gen_count_check.py` — 행수 대조 검증 SQL 생성.
- `db-ownership-split/dev_preload.sql`, `count_check.sql` — dev 실행본(홈 백업 `~/dms_*.sql`).
- dev 타깃 DDL `renamed_*.sql` = 세션 스크래치패드(홈 백업 `~/rename_map_draft.tsv`, `~/src_cols.tsv`).
