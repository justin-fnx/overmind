-- ============================================================================
-- DB 오너십 분리 컷오버 — V1 스냅샷 이후 드리프트 타깃 스키마 반영 DDL
-- (BOM-399 / BOM-423, 2026-07-15 작성)
--
-- 배경: prod 타깃 5스키마는 Flyway 정본 V001(prod bomapp_member 덤프) 기준으로 생성됨.
--   V001 이후 신설된 테이블/컬럼은 타깃 스키마(CDC 복제본)에 없어 CDC로도 안 흐른다.
--   아래는 "V001에 없던 진짜 신규분"만 추림(V001 실재 대조 완료).
--
-- 대상: prod Aurora(bomapp-prod 클러스터) + dev. 사람이 dev→(stg=prod공유)→prod 순 수동 적용.
--   ⚠️ 적용 순서: (1) 아래 DDL 로 타깃 스키마에 구조 반영 → (2) infra MR!83(rename_map) apply 로
--   DMS 태스크에 신규 테이블 selection 추가 → (3) messaging·bomapp 태스크 -replace(신규 테이블 full-load)
--   → (4) 신규 컬럼은 아래 백필 참조.
-- ============================================================================

-- ── (A) 신규 테이블 2건 (CDC rename_map = MR!83 로 추가됨; 타깃에 구조 선생성 필요) ──────────

-- messaging.alimtalk_opt_out_member  (알림톡 수신거부, prod 라이브 c9609c4f2)
CREATE TABLE IF NOT EXISTS `messaging`.`alimtalk_opt_out_member` (
  `member_id`  bigint      NOT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='알림톡 수신거부 회원';

-- bomapp.alimtalk_template_registry  (BOM-318 콘솔 알림톡 템플릿 레지스트리)
-- ⚠️ 검증 필요(2026-07-20): 이 테이블은 prod bomapp_member 에 라이브지만 Flyway 단일정본
--   (e2e-schema/db/schema)에 마이그레이션이 없다(스키마관리 드리프트). 아래 구조는 rc 멀티스키마
--   baseline/엔티티 AlimtalkTemplateRegistry 에서 도출한 것 — DMS DO_NOTHING 은 컬럼 불일치 시
--   insert 실패하므로, 컷오버 전 운영자가 prod 에서 아래로 실구조를 확인해 일치시킬 것:
--     SHOW CREATE TABLE bomapp_member.alimtalk_template_registry;
--   (opt_out(V002)/컬럼(V005·V006)은 prod 정본과 대조 완료 — 일치 확인됨.)
CREATE TABLE IF NOT EXISTS `bomapp`.`alimtalk_template_registry` (
  `uid`               bigint       NOT NULL AUTO_INCREMENT,
  `sender_key`        varchar(40)  NOT NULL COMMENT '카카오 발신프로필 키(관측값)',
  `template_code`     varchar(30)  NOT NULL COMMENT '템플릿 코드',
  `name`              varchar(200) NOT NULL COMMENT '템플릿명',
  `content`           text         NOT NULL COMMENT '본문(변수 슬롯 #{...} 포함)',
  `buttons`           text                  COMMENT '버튼 목록(JSON, 최대 5개)',
  `category_code`     varchar(20)  DEFAULT NULL COMMENT '카카오 템플릿 카테고리 코드',
  `use_status`        varchar(10)  NOT NULL COMMENT 'BO 사용 상태(ACTIVE/INACTIVE)',
  `inspection_status` varchar(10)  NOT NULL COMMENT '카카오 검수 상태 관측값(REG/REQ/APR/REJ)',
  `synced_at`         datetime     DEFAULT NULL COMMENT '마지막 Bizgo 관측 성공 시각',
  `created_at`        datetime     NOT NULL,
  `updated_at`        datetime     NOT NULL,
  PRIMARY KEY (`uid`),
  UNIQUE KEY `uk_alimtalk_template_registry_code` (`template_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='BO 알림톡 템플릿 레지스트리(마지막 관측값)';

-- ── (B) 신규 컬럼 (V001에 없던 진짜 신규 = chat 스키마 2컬럼 × 각 2테이블) ───────────────────
--   ※ canceled_at/canceled_by/notice_id/bizgo_image_url 은 V001에 이미 존재 → 타깃에 있음, 추가 불필요.

-- V005: 채팅방 고객 읽음 워터마크 (chat_room/kakaopay_chat_room → chat.room/kakaopay_room)
ALTER TABLE `chat`.`room`          ADD COLUMN `last_customer_read_at` datetime(3) DEFAULT NULL COMMENT '고객이 플래너 메시지를 마지막으로 읽은 시각 (null: 아직 읽지 않음)';
ALTER TABLE `chat`.`kakaopay_room` ADD COLUMN `last_customer_read_at` datetime(3) DEFAULT NULL COMMENT '고객이 플래너 메시지를 마지막으로 읽은 시각 (null: 아직 읽지 않음)';

-- V006: 발송 결과 콜백 provider 발송 시각 (chat_message_result/kakaopay_chat_message_result → chat.message_result/kakaopay_message_result)
ALTER TABLE `chat`.`message_result`          ADD COLUMN `reported_at` datetime(3) DEFAULT NULL COMMENT '발송 결과 콜백의 provider 발송 시각 (null: 콜백 대기/레거시/인바운드)';
ALTER TABLE `chat`.`kakaopay_message_result` ADD COLUMN `reported_at` datetime(3) DEFAULT NULL COMMENT '발송 결과 콜백의 provider 발송 시각 (null: 콜백 대기/레거시/인바운드)';

-- ── (C) 데이터 백필 (컷오버 시, 같은 Aurora 내부 크로스 스키마) ──────────────────────────────
--   신규 테이블: DMS 태스크 -replace 로 full-load 되면 자동 백필. (또는 수동 INSERT..SELECT)
--   신규 컬럼(위 ALTER 후 기존 행 값): DMS는 태스크 start 이후 변경만 CDC 하므로 기존 값은 아래로 백필.
--     UPDATE `chat`.`room` t JOIN `bomapp_member`.`chat_room` s ON t.id = s.id
--       SET t.last_customer_read_at = s.last_customer_read_at;
--     UPDATE `chat`.`kakaopay_room` t JOIN `bomapp_member`.`kakaopay_chat_room` s ON t.id = s.id
--       SET t.last_customer_read_at = s.last_customer_read_at;
--     UPDATE `chat`.`message_result` t JOIN `bomapp_member`.`chat_message_result` s ON t.id = s.id
--       SET t.reported_at = s.reported_at;
--     UPDATE `chat`.`kakaopay_message_result` t JOIN `bomapp_member`.`kakaopay_chat_message_result` s ON t.id = s.id
--       SET t.reported_at = s.reported_at;
--   (조인 키는 각 테이블 PK 기준으로 확인 후 적용.)
