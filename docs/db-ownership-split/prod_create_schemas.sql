-- 신규 논리 스키마 V1 (통합) — 현행 스키마 덤프 기준, 드리프트-0
SET FOREIGN_KEY_CHECKS=0;

CREATE DATABASE IF NOT EXISTS `chat` DEFAULT CHARACTER SET utf8mb4;
USE `chat`;
CREATE TABLE IF NOT EXISTS `ban_word` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '기본 키(PK)이며 자동 증가 설정',
  `word` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '금지어, 최대 길이 20자',
  `by_planner_id` bigint NOT NULL COMMENT '플래너 ID, NULL 허용 불가',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시간 자동 설정',
  PRIMARY KEY (`id`),
  CONSTRAINT `chk_word_length` CHECK ((char_length(`word`) <= 20))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='금지어 테이블';

CREATE TABLE IF NOT EXISTS `activation_history` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `by_planner_id` bigint NOT NULL,
  `is_enabled` tinyint(1) NOT NULL,
  `serial_number` varchar(50) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `customer_type` varchar(50) NOT NULL COMMENT '고객 종류',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `bot_template` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `image_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '이미지 URL',
  `bizgo_image_url` varchar(2083) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '비즈고 v3 /file/cstalk/image 등록 이미지 URL (null=미마이그레이션)',
  `parent_button_code` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '상위 버튼 코드',
  `message` text COLLATE utf8mb4_unicode_ci,
  `chat_bot_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '챗봇 유형',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '생성일시',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정일시',
  `scenario_order` int DEFAULT NULL COMMENT '시나리오 순서',
  `step` int DEFAULT NULL COMMENT '시나리오 단계',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='챗봇 템플릿 테이블';

CREATE TABLE IF NOT EXISTS `bot_template_button` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `chat_bot_template_id` bigint DEFAULT NULL COMMENT '참조하는 챗봇 템플릿 ID',
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '버튼명',
  `link` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '버튼 클릭 시 이동할 링크',
  `button_code` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '버튼 고유 코드',
  `button_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '버튼 유형',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일시',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정일시',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_button_code` (`button_code`),
  KEY `idx_template_id` (`chat_bot_template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='채봇 템플릿에 속하는 버튼 정보 테이블';

CREATE TABLE IF NOT EXISTS `button` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `button_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '버튼명',
  `button_link` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '버튼 링크(URL)',
  `chat_message_id` bigint NOT NULL COMMENT '연결된 채팅 메시지 ID',
  PRIMARY KEY (`id`),
  KEY `idx_chat_message_id` (`chat_message_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='채팅 메시지에 포함되는 버튼 정보 테이블';

CREATE TABLE IF NOT EXISTS `consultation_end_message` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '상담 종료 메시지 ID (Primary Key)',
  `by_planner_id` bigint NOT NULL COMMENT '상담 종료 메시지를 설정한 플래너 ID',
  `is_enabled` tinyint(1) NOT NULL COMMENT '자동 변경 활성 여부 (true: 활성, false: 비활성)',
  `message` text COLLATE utf8mb4_unicode_ci COMMENT '상담 종료 시 표시할 메시지',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '레코드 생성 시간',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='상담 종료 메시지 테이블';

CREATE TABLE IF NOT EXISTS `consultation_end_message_button` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '상담 종료 메시지 버튼 ID (Primary Key)',
  `button_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '버튼 이름',
  `button_link` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '버튼 링크',
  `chat_consultation_end_message_id` bigint NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '레코드 생성 시간',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='상담 종료 메시지 버튼 테이블';

CREATE TABLE IF NOT EXISTS `consultation_history` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `status` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '상담 상태',
  `finished_at` datetime DEFAULT NULL COMMENT '상담 종료 시각',
  `chat_room_id` bigint DEFAULT NULL COMMENT '연결된 채팅방 ID',
  `created_at` datetime DEFAULT NULL COMMENT '상담 생성 시각',
  `planner_id` bigint DEFAULT NULL COMMENT '담당 플래너 ID',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='채팅 상담 이력 테이블';

CREATE TABLE IF NOT EXISTS `file` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '파일명',
  `file_url` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '파일 다운로드/조회 URL',
  `chat_message_id` bigint NOT NULL COMMENT '연결된 채팅 메시지 ID',
  `size` bigint NOT NULL COMMENT '파일 크기(Byte)',
  PRIMARY KEY (`id`),
  KEY `idx_chat_message_id` (`chat_message_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='채팅 메시지에 첨부된 파일 정보 테이블';

CREATE TABLE IF NOT EXISTS `global_template` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '기본 키 (자동 증가)',
  `type` varchar(100) DEFAULT NULL,
  `message` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `image_url` varchar(1000) DEFAULT NULL,
  `file_url` varchar(1000) DEFAULT NULL,
  `file_name` varchar(1000) DEFAULT NULL,
  `file_size` bigint DEFAULT NULL COMMENT '파일 크기',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시간',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 시간',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `global_template_button` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '버튼 ID (기본 키)',
  `global_template_id` bigint NOT NULL COMMENT '연결된 채팅 템플릿 ID (외래 키 아님)',
  `name` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '버튼 이름 (최대 20자)',
  `link` varchar(2048) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '버튼 링크 (URL)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시간',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 시간',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='보맵의 채팅 템플릿의 버튼 테이블';

CREATE TABLE IF NOT EXISTS `image` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `image_url` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '이미지 URL',
  `internal_image_url` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `chat_message_id` bigint NOT NULL COMMENT '연결된 채팅 메시지 ID',
  PRIMARY KEY (`id`),
  KEY `idx_chat_message_id` (`chat_message_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='채팅 메시지에 첨부된 이미지 정보 테이블';

CREATE TABLE IF NOT EXISTS `member_tag` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '프라이머리 키',
  `tag_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '태그 이름',
  `created_at` datetime NOT NULL COMMENT '레코드 생성 일시',
  `planner_id` bigint DEFAULT NULL,
  `member_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='채팅 고객 태그 테이블';

CREATE TABLE IF NOT EXISTS `message` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '프라이머리 키',
  `is_read` tinyint(1) NOT NULL COMMENT '채팅메시지 읽음 여부',
  `chat_source` varchar(50) NOT NULL COMMENT '메시지 받는 주체 : SYSTEM(자동메시지), PLANNER(플래너), CUSTOMER(고객)',
  `chat_room_id` bigint NOT NULL COMMENT '채팅방 ID',
  `message` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `created_at` datetime NOT NULL COMMENT '생성일',
  `type` varchar(50) DEFAULT NULL COMMENT '채팅 메시지 타입',
  `disable_click` tinyint(1) DEFAULT '1' COMMENT '활성 여부 (true: 활성, false: 비활성)',
  `serial_number` varchar(256) DEFAULT NULL,
  `message_group_id` bigint DEFAULT NULL COMMENT '그룹 첫 번째 메시지의 id',
  `message_order` int NOT NULL DEFAULT '0' COMMENT '그룹 내 순서 (0부터)',
  PRIMARY KEY (`id`),
  KEY `fk_chat_room` (`chat_room_id`),
  KEY `idx_room_source_read` (`chat_room_id`,`chat_source`,`is_read`),
  KEY `idx_cm_room_created` (`chat_room_id`,`created_at` DESC),
  KEY `idx_cm_group_id` (`message_group_id`),
  KEY `idx_cm_room_group_order` (`chat_room_id`,`message_group_id` DESC,`message_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='채팅 메시지를 저장하는 테이블';

CREATE TABLE IF NOT EXISTS `message_result` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `request_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '요청 유형(메시지, 이미지, 파일 등)',
  `serial_number` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '메시지 전송 시 사용한 시리얼 번호',
  `code` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '응답 코드(성공/실패 코드)',
  `error_message` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '오류 메시지(실패 시)',
  `image_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '전송된 이미지 URL',
  `file_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '전송된 파일 URL',
  `file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '전송된 파일명',
  `file_size` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '전송된 파일 크기',
  `chat_message_id` bigint DEFAULT NULL COMMENT '연결된 보맵 채팅 메시지 ID',
  `infobank_msg_key` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT '인포뱅크(비즈고 v3) 발송 응답 provider message id (비즈고 msgKey). 응답 전/인바운드/레거시는 NULL',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_chat_message_result_serial_number` (`serial_number`),
  KEY `idx_cmr_chat_message_id` (`chat_message_id`),
  KEY `idx_chat_message_result_infobank_msg_key` (`infobank_msg_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='채팅 메시지 발송 결과 저장 테이블';

CREATE TABLE IF NOT EXISTS `room` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '프라이머리 키(PK)',
  `member_id` bigint DEFAULT NULL COMMENT '채팅방에 속한 회원 ID',
  `planner_id` bigint DEFAULT NULL COMMENT '채팅방 담당 플래너(설계사) ID',
  `created_at` datetime NOT NULL COMMENT '채팅방 생성일',
  `is_displayed` tinyint DEFAULT NULL COMMENT '채팅방 노출 여부(1: 노출, 0: 숨김)',
  `consultation_id` bigint DEFAULT NULL COMMENT '연결된 상담 ID',
  `chat_status` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '채팅 상태값',
  `updated_at` datetime DEFAULT NULL COMMENT '채팅방 수정시간',
  `pending_notification_type` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '미인입 상태에서 발송 대기 중인 알림 타입',
  `pending_notification_marked_at` datetime DEFAULT NULL COMMENT 'pending_notification_type 마킹 시각 (모니터링용)',
  PRIMARY KEY (`id`),
  KEY `idx_chat_room_planner_displayed_status` (`planner_id`,`is_displayed`,`chat_status`),
  KEY `idx_chat_room_consultation_id` (`consultation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='채팅방 정보를 저장하는 테이블';

CREATE TABLE IF NOT EXISTS `room_memo` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '채팅방메모 ID',
  `member_id` bigint NOT NULL COMMENT '사용자 ID',
  `type` varchar(16) NOT NULL COMMENT '종류',
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `created_at` datetime NOT NULL COMMENT '생성 시간',
  `updated_at` datetime NOT NULL COMMENT '수정 시간',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='채팅방 메모';

CREATE TABLE IF NOT EXISTS `status` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `status` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '채팅 상태값',
  `chat_room_id` bigint NOT NULL COMMENT '연결된 채팅방 ID',
  `created_at` datetime(6) NOT NULL COMMENT '채팅 상태 생성 시각',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='채팅방 상태 이력을 저장하는 테이블';

CREATE TABLE IF NOT EXISTS `template` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '기본 키 (자동 증가)',
  `question` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '질문 내용',
  `answer` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '답변 내용',
  `category_id` bigint NOT NULL COMMENT '카테고리 ID',
  `planner_id` bigint NOT NULL COMMENT '플래너 ID ',
  `planner_admin_id` bigint DEFAULT NULL COMMENT '플래너 관리자 ID ',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시간',
  `updated_at` datetime NOT NULL COMMENT '수정 시간',
  `is_favorite` tinyint NOT NULL COMMENT '즐겨찾기 여부',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='채팅 템플릿 테이블';

CREATE TABLE IF NOT EXISTS `template_button` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '버튼 ID (기본 키)',
  `button_name` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '버튼 이름 (최대 20자)',
  `button_link` text COLLATE utf8mb4_unicode_ci COMMENT '버튼 링크 (URL)',
  `button_type` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `chat_template_id` bigint NOT NULL COMMENT '연결된 채팅 템플릿 ID (외래 키 아님)',
  PRIMARY KEY (`id`),
  CONSTRAINT `chk_button_name_length` CHECK ((char_length(`button_name`) <= 20))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='채팅 템플릿 버튼 테이블';

CREATE TABLE IF NOT EXISTS `template_category` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '기본 키(PK)이며 자동 증가 설정',
  `category_name` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '카테고리명, 최대 길이 30자',
  `by_planner_id` bigint NOT NULL COMMENT '플래너 ID, NULL 허용 불가 및 0보다 커야 함',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시간 자동 설정',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정될 때마다 자동으로 갱신',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제 시간, NULL이면 삭제되지 않음',
  PRIMARY KEY (`id`),
  CONSTRAINT `chk_by_planner_id` CHECK ((`by_planner_id` > 0)),
  CONSTRAINT `chk_category_name_length` CHECK ((char_length(`category_name`) <= 30))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='채팅 템플릿 카테고리 테이블';

CREATE TABLE IF NOT EXISTS `template_favorite` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `chat_template_id` bigint NOT NULL,
  `planner_id` bigint NOT NULL,
  `favorite_rank` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ctf_template` (`chat_template_id`),
  UNIQUE KEY `uk_ctf_planner_rank` (`planner_id`,`favorite_rank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `template_image` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '채팅 템플릿 이미지 ID (기본 키)',
  `image_url` varchar(2083) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '이미지 URL',
  `bizgo_image_url` varchar(2083) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '비즈고 v3 /file/cstalk/image 등록 이미지 URL (null=미마이그레이션)',
  `chat_template_id` bigint NOT NULL COMMENT '연결된 채팅 템플릿 ID',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시간',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='채팅 템플릿 이미지 테이블';

CREATE TABLE IF NOT EXISTS `view_state` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `planner_id` bigint NOT NULL,
  `new_completed_chat_room_count` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_chat_view_state_planner_id` (`planner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `work_hour` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '근무 시간 ID (Primary Key)',
  `by_planner_id` bigint NOT NULL COMMENT '근무 시간을 설정한 플래너 ID',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '레코드 생성 시간',
  `work_week_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '근무 요일 유형 (예: 평일, 주말, 특정 요일)',
  `is_enabled` tinyint(1) DEFAULT NULL COMMENT '근무 시간 활성 여부 (1: 활성, 0: 비활성)',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='플래너 근무 시간 설정 테이블';

CREATE TABLE IF NOT EXISTS `work_hour_setting` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '근무 시간 설정 ID (Primary Key)',
  `chat_work_hour_id` bigint NOT NULL COMMENT '근무 시간 그룹 ID (FK, chat_work_hour 테이블 참조)',
  `work_time_type` enum('START_TIME','END_TIME') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '근무 시간 유형 (ENUM)',
  `time` time NOT NULL COMMENT '설정된 근무 시간',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '레코드 생성 시간',
  PRIMARY KEY (`id`),
  KEY `idx_chat_work_hour_setting_chat_work_hour_id` (`chat_work_hour_id`),
  CONSTRAINT `fk_chat_work_hour_setting_chat_work_hour` FOREIGN KEY (`chat_work_hour_id`) REFERENCES `work_hour` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='플래너 근무 시간 설정 테이블';

CREATE TABLE IF NOT EXISTS `kakao_kakaopay_member` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `kakao_user_key` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `kakaopay_member_id` bigint NOT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_kakao_user_key` (`kakao_user_key`),
  KEY `idx_kakaopay_member_id` (`kakaopay_member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `kakaopay_bot_template` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `image_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bizgo_image_url` varchar(2083) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '비즈고 v3 /file/cstalk/image 등록 이미지 URL (null=미마이그레이션)',
  `parent_button_code` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `message` text COLLATE utf8mb4_unicode_ci,
  `chat_bot_type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `scenario_order` int NOT NULL,
  `step` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_chat_bot_type` (`chat_bot_type`),
  KEY `idx_parent_button_code` (`parent_button_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `kakaopay_bot_template_button` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `chat_bot_template_id` bigint NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `link` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `button_code` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `button_type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_template_id` (`chat_bot_template_id`),
  KEY `idx_button_code` (`button_code`),
  KEY `idx_button_type` (`button_type`),
  CONSTRAINT `fk_chat_bot_template_button_template` FOREIGN KEY (`chat_bot_template_id`) REFERENCES `kakaopay_bot_template` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `kakaopay_button` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `button_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '버튼 표시 이름',
  `button_link` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '버튼 링크 URL',
  `chat_message_id` bigint NOT NULL COMMENT '연결된 카카오페이 채팅 메시지 ID',
  PRIMARY KEY (`id`),
  KEY `idx_chat_message_id` (`chat_message_id`),
  CONSTRAINT `fk_chat_button_message` FOREIGN KEY (`chat_message_id`) REFERENCES `kakaopay_message` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `kakaopay_consultation_history` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `chat_room_id` bigint NOT NULL COMMENT '카카오페이 채팅방 ID',
  `status` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '채팅 상담 상태',
  `planner_id` bigint DEFAULT NULL COMMENT '플래너 ID',
  `created_at` datetime NOT NULL COMMENT '상태 생성 시각',
  `finished_at` datetime DEFAULT NULL COMMENT '상담 종료 시각',
  PRIMARY KEY (`id`),
  KEY `idx_chat_room_id` (`chat_room_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_planner_id` (`planner_id`),
  CONSTRAINT `fk_chat_consultation_history_chat_room` FOREIGN KEY (`chat_room_id`) REFERENCES `kakaopay_room` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='카카오페이 채팅 상담 상태 이력';

CREATE TABLE IF NOT EXISTS `kakaopay_file` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `file_url` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '파일 URL',
  `file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '파일명',
  `size` bigint NOT NULL COMMENT '파일 크기',
  `chat_message_id` bigint NOT NULL COMMENT '연결된 카카오페이 채팅 메시지 ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_chat_message_id` (`chat_message_id`),
  CONSTRAINT `fk_chat_file_message` FOREIGN KEY (`chat_message_id`) REFERENCES `kakaopay_message` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `kakaopay_image` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `image_url` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '이미지 URL',
  `internal_image_url` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `chat_message_id` bigint NOT NULL COMMENT '연결된 카카오페이 채팅 메시지 ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_chat_message_id` (`chat_message_id`),
  CONSTRAINT `fk_chat_image_message` FOREIGN KEY (`chat_message_id`) REFERENCES `kakaopay_message` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `kakaopay_member_tag` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `tag_name` varchar(20) NOT NULL COMMENT '태그명 (1~20자)',
  `planner_id` bigint DEFAULT NULL COMMENT '플래너 ID',
  `kakaopay_member_id` bigint DEFAULT NULL COMMENT '카카오페이 회원 ID',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 일시',
  PRIMARY KEY (`id`),
  KEY `idx_member` (`kakaopay_member_id`),
  KEY `idx_planner` (`planner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='카카오페이 상담 회원 태그';

CREATE TABLE IF NOT EXISTS `kakaopay_memo` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `kakaopay_member_id` bigint NOT NULL COMMENT '카카오페이 회원 ID',
  `type` varchar(50) NOT NULL COMMENT '메모 타입',
  `content` varchar(500) NOT NULL COMMENT '내용(최대 500자)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 일시',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 일시',
  PRIMARY KEY (`id`),
  KEY `idx_member` (`kakaopay_member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='카카오페이 상담 메모';

CREATE TABLE IF NOT EXISTS `kakaopay_message` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `is_read` tinyint(1) NOT NULL COMMENT '읽음 여부',
  `chat_source` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '메시지 출처 (PLANNER / USER / BOT 등)',
  `chat_room_id` bigint NOT NULL COMMENT '채팅방 ID',
  `message` text COLLATE utf8mb4_unicode_ci COMMENT '메시지 본문',
  `type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '메시지 타입 (TEXT / IMAGE / FILE / CHAT_BOT / TEMPLATE / BUTTON)',
  `serial_number` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '외부 연동용 시리얼 번호',
  `disable_click` tinyint(1) DEFAULT '1' COMMENT '버튼 클릭 비활성화 여부',
  `created_at` datetime NOT NULL COMMENT '생성 시간',
  `created_by` bigint DEFAULT NULL COMMENT '생성자',
  `message_group_id` bigint DEFAULT NULL COMMENT '그룹 첫 번째 메시지의 id',
  `message_order` int NOT NULL DEFAULT '0' COMMENT '그룹 내 순서 (0부터)',
  PRIMARY KEY (`id`),
  KEY `idx_serial_number` (`serial_number`),
  KEY `idx_room_source_read` (`chat_room_id`,`chat_source`,`is_read`),
  KEY `idx_kcm_room_created` (`chat_room_id`,`created_at` DESC),
  KEY `idx_kpcm_group_id` (`message_group_id`),
  KEY `idx_kpcm_room_group_order` (`chat_room_id`,`message_group_id` DESC,`message_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `kakaopay_message_result` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `request_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '요청 타입 (TEXT / IMAGE / FILE 등)',
  `serial_number` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '메시지 시리얼 번호',
  `code` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '결과 코드 (900: user key 없음, 901: 전송 실패 등)',
  `error_message` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '에러 메시지',
  `image_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '이미지 URL',
  `file_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '파일 URL',
  `file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '파일 이름',
  `file_size` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '파일 사이즈',
  `chat_message_id` bigint DEFAULT NULL COMMENT '연결된 카카오페이 채팅 메시지 ID',
  `infobank_msg_key` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT '인포뱅크(비즈고 v3) 발송 응답 provider message id (비즈고 msgKey). 응답 전/인바운드/레거시는 NULL',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_kakaopay_chat_message_result_serial_number` (`serial_number`),
  KEY `fk_chat_message_result_message` (`chat_message_id`),
  KEY `idx_kakaopay_chat_message_result_infobank_msg_key` (`infobank_msg_key`),
  CONSTRAINT `fk_chat_message_result_message` FOREIGN KEY (`chat_message_id`) REFERENCES `kakaopay_message` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `kakaopay_room` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `kakaopay_member_id` bigint NOT NULL COMMENT '카카오페이 회원 ID',
  `planner_id` bigint DEFAULT NULL COMMENT '배정된 플래너 ID',
  `consultation_id` bigint DEFAULT NULL COMMENT '상담 ID (kakaopay_consultation.id)',
  `is_displayed` tinyint(1) NOT NULL DEFAULT '1' COMMENT '채팅방 노출 여부',
  `current_chat_status` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '현재 채팅 상태',
  `created_at` datetime NOT NULL COMMENT '생성 일시',
  `updated_at` datetime NOT NULL COMMENT '수정 일시',
  `pending_notification_type` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '미인입 상태에서 발송 대기 중인 알림 타입',
  `pending_notification_marked_at` datetime DEFAULT NULL COMMENT 'pending_notification_type 마킹 시각 (모니터링용)',
  PRIMARY KEY (`id`),
  KEY `idx_kp_chat_room_planner_displayed_status` (`planner_id`,`is_displayed`,`current_chat_status`),
  KEY `idx_kcr_member_id` (`kakaopay_member_id`),
  KEY `idx_kcr_consultation_id` (`consultation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='카카오페이 채팅방';

CREATE TABLE IF NOT EXISTS `kakaopay_room_status_history` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `chat_room_id` bigint NOT NULL COMMENT '카카오페이 채팅방 ID',
  `chat_status` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '채팅방 상태',
  `created_at` datetime NOT NULL COMMENT '상태 변경 시각',
  PRIMARY KEY (`id`),
  KEY `idx_chat_room_id` (`chat_room_id`),
  KEY `idx_chat_status` (`chat_status`),
  KEY `idx_created_at` (`created_at`),
  CONSTRAINT `fk_chat_room_status_history_chat_room` FOREIGN KEY (`chat_room_id`) REFERENCES `kakaopay_room` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='카카오페이 채팅방 상태 변경 이력';

CREATE TABLE IF NOT EXISTS `kakaopay_consultation` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `consultation_uuid` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '상담 UUID',
  `kakaopay_planner_member_id` bigint NOT NULL COMMENT '카카오페이 플래너 멤버 ID',
  `reserved_at` datetime DEFAULT NULL COMMENT '예약 일시',
  `reservation_method` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '예약 방식',
  `applied_at` datetime DEFAULT NULL COMMENT '상담 신청 일시',
  `status` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '상담 상태',
  `assigned_at` datetime DEFAULT NULL COMMENT '플래너 배정 일시',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제 일시',
  `deleted_by_id` bigint DEFAULT NULL COMMENT '삭제자 ID',
  `canceled_at` datetime DEFAULT NULL COMMENT '취소 일시',
  `canceled_by_id` bigint DEFAULT NULL COMMENT '취소자 ID',
  `created_at` datetime NOT NULL COMMENT '생성 일시',
  `updated_at` datetime NOT NULL COMMENT '수정 일시',
  `az_registered_at` datetime DEFAULT NULL COMMENT 'AZ 전산에 현재 등록되어 있는 시점 (cancel 성공 시 NULL). NULL = AZ 에 active row 없음',
  `az_contact_type` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'AZ 에 현재 등록된 채널 (TEL / CHAT). az_registered_at = NULL 이면 NULL',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_consultation_uuid` (`consultation_uuid`),
  KEY `idx_kc_pm_id_status_applied` (`kakaopay_planner_member_id`,`status`,`applied_at`),
  KEY `idx_kc_applied_pm` (`applied_at`,`kakaopay_planner_member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='카카오페이 상담';

CREATE TABLE IF NOT EXISTS `kakaopay_consultation_cancel_reason` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `kakaopay_planner_member_id` bigint NOT NULL COMMENT '플래너 멤버 ID',
  `reason_type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '취소 사유 ENUM 타입',
  `reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '취소 사유 상세 (ENUM에서 파생)',
  `created_at` datetime NOT NULL COMMENT '생성 시간',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_kakaopay_planner_member` (`kakaopay_planner_member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `kakaopay_consultation_status_history` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `consultation_id` bigint NOT NULL COMMENT '상담 ID',
  `consultation_status` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '상담 상태',
  `created_at` datetime NOT NULL COMMENT '생성 일시',
  PRIMARY KEY (`id`),
  KEY `idx_consultation_id` (`consultation_id`),
  CONSTRAINT `fk_consultation_history_consultation` FOREIGN KEY (`consultation_id`) REFERENCES `kakaopay_consultation` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='카카오페이 상담 상태 변경 이력';

CREATE DATABASE IF NOT EXISTS `mydata` DEFAULT CHARACTER SET utf8mb4;
USE `mydata`;
CREATE TABLE IF NOT EXISTS `log_alimtalk_send` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL,
  `stage` varchar(32) NOT NULL,
  `send_date` date NOT NULL,
  `status` varchar(16) NOT NULL,
  `snapshot` datetime DEFAULT NULL,
  `campaign` varchar(64) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_member_stage_snapshot` (`member_id`,`stage`,`snapshot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `log_api_request` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `org_code` varchar(10) DEFAULT NULL COMMENT '기관 코드',
  `api_code` varchar(60) DEFAULT NULL COMMENT '요청 API 코드',
  `transaction_id` varchar(30) DEFAULT NULL COMMENT '거래 번호',
  `api` varchar(128) DEFAULT NULL COMMENT '요청 API',
  `response_code` varchar(40) DEFAULT NULL COMMENT '요청 응답 코드',
  `response_message` varchar(1000) DEFAULT NULL COMMENT '응답 메세지(예. 성공, SIGN_001) (rsp_msg / error_description)',
  `api_type_header` varchar(20) DEFAULT NULL COMMENT '마이데이터 API 요청 구분 헤더 정보 scheduled: 정기적 전송, user-consent : 전송요구 직후, user-refresh: 로그인 또는 새로고침, user-search: 특정자산 거래내역 조회',
  `start_time` datetime DEFAULT NULL COMMENT '요청 시작 시간',
  `end_time` datetime DEFAULT NULL COMMENT '요청 종료 시간',
  `is_update` tinyint(1) DEFAULT NULL COMMENT '신규 / 변경 여부 true - 변경, false - 신규, null - 구분 안함',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  PRIMARY KEY (`id`),
  KEY `log_my_data_api_request_index_case1` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - api 요청 로그';

CREATE TABLE IF NOT EXISTS `log_api_request_v2` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `org_code` varchar(10) DEFAULT NULL COMMENT '기관 코드',
  `api_code` varchar(60) DEFAULT NULL COMMENT '요청 API 코드',
  `transaction_id` varchar(30) DEFAULT NULL COMMENT '거래 번호',
  `api` varchar(128) DEFAULT NULL COMMENT '요청 API',
  `reference_id` bigint DEFAULT NULL COMMENT '함께 기록이 필요한 정보 테이블 id (현-insurance_id, 향후 다른 것들도 추가될 수 있음) ',
  `reference_type` varchar(20) DEFAULT NULL COMMENT 'reference id 가 어디 id 인지 정보 (현 insurance 만 존재)',
  `status_code` int DEFAULT NULL COMMENT '응답 HTTP 코드',
  `response_code` varchar(40) DEFAULT NULL COMMENT '응답 코드(예. 40104, invalid_request 등) (rsp_code / error)',
  `response_message` varchar(1000) DEFAULT NULL COMMENT '응답 메세지(예. 성공, SIGN_001) (rsp_msg / error_description)',
  `response_detail` varchar(450) DEFAULT NULL COMMENT '응답 상세 설명 (예. 존재하지 않는 고객입니다)',
  `api_type_header` varchar(20) DEFAULT NULL COMMENT '마이데이터 API 요청 구분 헤더 정보 scheduled: 정기적 전송, user-consent : 전송요구 직후, user-refresh: 로그인 또는 새로고침, user-search: 특정자산 거래내역 조회',
  `start_time` datetime DEFAULT NULL COMMENT '요청 시작 시간',
  `end_time` datetime DEFAULT NULL COMMENT '요청 종료 시간',
  `is_update` tinyint(1) DEFAULT NULL COMMENT '신규 / 변경 여부 true - 변경, false - 신규, null - 구분 안함',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  PRIMARY KEY (`id`),
  KEY `log_my_data_api_request_v2_created_at_index` (`created_at`),
  KEY `log_my_data_api_request_v2_member_id_index` (`member_id`),
  KEY `log_my_data_api_request_v2_reference_id_index` (`reference_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - api 요청 로그';

CREATE TABLE IF NOT EXISTS `log_member_token_reissue` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL,
  `industry_code` varchar(10) NOT NULL,
  `org_code` varchar(10) NOT NULL,
  `attempt_date` char(8) NOT NULL,
  `success` tinyint(1) NOT NULL,
  `response_code` varchar(30) DEFAULT NULL,
  `error_code` varchar(30) DEFAULT NULL,
  `response_message` varchar(450) DEFAULT NULL,
  `error_description` varchar(450) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_member_org_date` (`member_id`,`industry_code`,`org_code`,`attempt_date`),
  KEY `idx_org_date` (`org_code`,`attempt_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `detail_request` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `industry_code` varchar(10) DEFAULT NULL COMMENT '업권 - bank : 은행, card : 카드, invest : 금융투자, insu : 보험, efin : 전자금융, capital : 할부금융, ginsu : 보증보험, telecom : 통신',
  `member_id` bigint DEFAULT NULL,
  `org_code` varchar(10) DEFAULT NULL COMMENT '업체 코드-기관 코드',
  `status_code` varchar(1) NOT NULL DEFAULT 'I' COMMENT '마이데이터 API 요청 상태 - I : 요청중, C : 완료, F : 실패',
  `retry_count` int NOT NULL DEFAULT '0' COMMENT '에러 상태(E, 10분 이상 R 상태였던 경우)인 리퀘스트를 재시도(I로 변경)한 횟수',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `completed_at` datetime DEFAULT NULL COMMENT '해당 요청의 완료된 시간',
  `api_type_header` varchar(20) DEFAULT NULL COMMENT '마이데이터 API 요청 구분 헤더 정보 scheduled: 정기적 전송, user-consent : 전송요구 직후, user-refresh: 로그인 또는 새로고침, user-search: 특정자산 거래내역 조회',
  PRIMARY KEY (`id`),
  UNIQUE KEY `my_data_detail_request_u_index_case1` (`member_id`,`industry_code`,`org_code`),
  KEY `my_data_detail_request_index_case2` (`org_code`),
  KEY `my_data_detail_request_index_case1` (`member_id`),
  KEY `my_data_detail_request_status_code_index` (`status_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 고객 업권 별 상세 조회 요청 정보';

CREATE TABLE IF NOT EXISTS `detail_request_queue` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `industry_code` varchar(10) DEFAULT NULL COMMENT '업권 - bank : 은행, card : 카드, invest : 금융투자, insu : 보험, efin : 전자금융, capital : 할부금융, ginsu : 보증보험, telecom : 통신',
  `member_id` bigint DEFAULT NULL,
  `org_code` varchar(10) DEFAULT NULL COMMENT '기관 코드',
  `request_id` bigint DEFAULT NULL COMMENT 'my_data_detail_request table id',
  `reference_id` bigint DEFAULT NULL COMMENT '기준 table id',
  `reference_type` varchar(20) DEFAULT NULL COMMENT 'reference_id 타입 정보',
  `api_code` varchar(60) DEFAULT NULL COMMENT '요청 API 코드',
  `api` varchar(128) DEFAULT NULL COMMENT '요청 API',
  `status_code` varchar(1) NOT NULL DEFAULT 'I' COMMENT '마이데이터 API 요청 상태 - I : 요청중, C : 완료, F : 실패',
  `search_timestamp` varchar(20) DEFAULT NULL COMMENT '조회 타임스탬프',
  `response_code` varchar(10) DEFAULT NULL COMMENT '요청 응답 코드',
  `response_message` varchar(450) DEFAULT NULL COMMENT '요청 응답 메세지',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `completed_at` datetime DEFAULT NULL COMMENT '해당 요청의 완료된 시간',
  `unknown_failed_at` datetime DEFAULT NULL COMMENT '원인불명 실패 발생 일시',
  PRIMARY KEY (`id`),
  UNIQUE KEY `my_data_detail_request_queue_u_index_case1` (`member_id`,`request_id`,`reference_id`,`api_code`),
  KEY `request_id` (`request_id`),
  KEY `my_data_detail_request_queue_index_case1` (`reference_id`,`reference_type`),
  CONSTRAINT `my_data_detail_request_queue_ibfk_1` FOREIGN KEY (`request_id`) REFERENCES `detail_request` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 고객 업권 별 상세 조회 요청 큐 정보';

CREATE TABLE IF NOT EXISTS `insurance` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `org_code` varchar(10) DEFAULT NULL COMMENT '기관 코드',
  `insurance_no` varchar(40) DEFAULT NULL COMMENT '증권 번호',
  `product_name` varchar(300) DEFAULT NULL COMMENT '상품명',
  `insurance_type_code` varchar(2) DEFAULT NULL COMMENT '보험 구분 코드 - 보맵',
  `insurance_status_code` varchar(2) DEFAULT NULL COMMENT '계약 상태 코드/ 02: 정상, 04: 실효, 05: 만기, 06: 소멸',
  `is_consent` tinyint(1) NOT NULL DEFAULT '1' COMMENT '전송요구 여부 - true: 요구, false: 미요구',
  `is_show` tinyint(1) NOT NULL DEFAULT '1' COMMENT '노출 여부 - true ; 노출, false: 미노출',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  `is_use` tinyint(1) NOT NULL DEFAULT '0',
  `is_insured` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `my_data_insurance_index_case1` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마아데이터 - 보험 정보';

CREATE TABLE IF NOT EXISTS `insurance_basic` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `insurance_id` bigint NOT NULL COMMENT 'my_data_insurance table id',
  `org_code` varchar(10) DEFAULT NULL COMMENT '기관 코드',
  `join_amount` varchar(20) DEFAULT NULL COMMENT '보험 가입 금액',
  `currency_code` varchar(3) DEFAULT NULL COMMENT '통화코드 - 통화코드값이 명시되어있지 않을 경우 KRW(원)',
  `issue_date` varchar(8) DEFAULT NULL COMMENT '계약체결일',
  `maturity_date` varchar(8) DEFAULT NULL COMMENT '만기일자',
  `is_renewal` tinyint(1) DEFAULT NULL COMMENT '갱신여부 - true: 갱신형, false: 비갱신형',
  `is_loanable` tinyint(1) DEFAULT NULL COMMENT '대출실행 가능 상품 여부 - true: 실행가능, false: 실행불가',
  `is_variable` tinyint(1) DEFAULT NULL COMMENT '변액보험 여부 - true: 변액보험, false: 아님',
  `is_universal` tinyint(1) DEFAULT NULL COMMENT '유니버셜 여부 - true: 유니버셜, false: 아님',
  `pension_start_date` varchar(8) DEFAULT NULL COMMENT '연금개시일',
  `pension_receipt_cycle` varchar(2) DEFAULT NULL COMMENT '연금수령주기 - 1M: 매월, 3M: 3개월, 6M: 6개월, 1Y: 연단위',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  UNIQUE KEY `my_data_insurance_basic_u_index_case1` (`insurance_id`),
  KEY `my_data_insurance_basic_index_case1` (`member_id`),
  KEY `my_data_insurance_basic_member_id_insurance_id_index` (`member_id`,`insurance_id`),
  CONSTRAINT `my_data_insurance_basic_ibfk_1` FOREIGN KEY (`insurance_id`) REFERENCES `insurance` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마아데이터 - 보험 기본 정보';

CREATE TABLE IF NOT EXISTS `insurance_car` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `org_code` varchar(10) DEFAULT NULL COMMENT '기관 코드',
  `insurance_id` bigint NOT NULL COMMENT 'my_data_insurance table id',
  `car_number` varchar(20) DEFAULT NULL COMMENT '자동차보험 가입 차량번호 (없을 시, 차대번호)',
  `car_insurance_type_code` varchar(2) DEFAULT NULL COMMENT '자동차보험 구분 코드',
  `car_name` varchar(60) DEFAULT NULL COMMENT '차량명',
  `start_date` varchar(8) DEFAULT NULL COMMENT '보험 시기',
  `end_date` varchar(8) DEFAULT NULL COMMENT '보험 종기',
  `contract_age` varchar(60) DEFAULT NULL COMMENT '연령특약',
  `contract_driver` varchar(60) DEFAULT NULL COMMENT '운전자한정특약',
  `is_own_damage_coverage` tinyint(1) DEFAULT NULL COMMENT '자기 차량 손해 가입 여부 - true: 가입, false: 미가입',
  `self_payment_rate_code` varchar(2) DEFAULT NULL COMMENT '자기부담금 코드 - 01: 20%, 02: 30%',
  `self_payment_amount` varchar(20) DEFAULT NULL COMMENT '자기부담금 금액',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  KEY `insurance_id` (`insurance_id`),
  KEY `my_data_insurance_car_index_case1` (`member_id`),
  CONSTRAINT `my_data_insurance_car_ibfk_1` FOREIGN KEY (`insurance_id`) REFERENCES `insurance` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 보험 자동차 보험 정보';

CREATE TABLE IF NOT EXISTS `insurance_car_transaction` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL,
  `org_code` varchar(10) NOT NULL COMMENT '기관 코드',
  `insurance_id` bigint NOT NULL COMMENT 'my_data_insurance table id',
  `car_id` bigint NOT NULL COMMENT 'my_data_insurance_car table id',
  `payment_ym` varchar(6) DEFAULT NULL COMMENT '납입 년월',
  `payment_no` varchar(4) DEFAULT NULL COMMENT '납입 회차',
  `payment_date` varchar(8) DEFAULT NULL COMMENT '납입 일자',
  `real_payment_amount` varchar(20) DEFAULT NULL COMMENT '실 납입 보험료',
  `transaction_no` varchar(64) DEFAULT NULL COMMENT '거래번호(없을 경우 미회신)',
  `total_amount` varchar(20) DEFAULT NULL COMMENT '자동차보험 보험료(총 보험료)',
  `payment_method_code` char(2) DEFAULT NULL COMMENT '납입 방법 코드 - 01: 지로, 02: 자동이체, 03: 직납, 04: 신용카드, 05: 급여공제, 06: 간편결제, 99: 기타',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  PRIMARY KEY (`id`),
  KEY `my_data_insurance_car_transaction_member_id` (`member_id`),
  KEY `my_data_insurance_car_transaction_insurance_id` (`insurance_id`),
  KEY `my_data_insurance_car_transaction_car_id` (`car_id`),
  KEY `my_data_insurance_car_transaction_car_id_payment_ym` (`car_id`,`payment_ym`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 보험 자동차 보험 거래내역 정보';

CREATE TABLE IF NOT EXISTS `insurance_contract` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `org_code` varchar(10) DEFAULT NULL COMMENT '기관 코드',
  `insurance_id` bigint NOT NULL COMMENT 'my_data_insurance table id',
  `basic_id` bigint NOT NULL COMMENT 'my_data_insurance_basic table id',
  `insured_id` bigint NOT NULL COMMENT 'my_data_insurance_insured table id',
  `name` varchar(300) DEFAULT NULL COMMENT '특약명',
  `status_code` varchar(2) DEFAULT NULL COMMENT '특약 상태 코드 - 02: 정상, 04: 실효, 05: 만기',
  `maturity_date` varchar(8) DEFAULT NULL COMMENT '특약 만기 일자',
  `join_amount` varchar(20) DEFAULT NULL COMMENT '특약 가입 금액',
  `currency_code` varchar(3) DEFAULT NULL COMMENT '통화코드',
  `is_required` tinyint(1) DEFAULT NULL COMMENT '특약의 유형 - true: 필수, false: 선택',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  KEY `basic_id` (`basic_id`),
  KEY `insurance_id` (`insurance_id`),
  KEY `insured_id` (`insured_id`),
  KEY `my_data_insurance_contract_index_case1` (`member_id`),
  KEY `my_data_insurance_contract_member_id_insurance_id_index` (`member_id`,`insurance_id`),
  CONSTRAINT `my_data_insurance_contract_ibfk_1` FOREIGN KEY (`insurance_id`) REFERENCES `insurance` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `my_data_insurance_contract_ibfk_2` FOREIGN KEY (`basic_id`) REFERENCES `insurance_basic` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `my_data_insurance_contract_ibfk_3` FOREIGN KEY (`insured_id`) REFERENCES `insurance_insured` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 보험 특약 정보';

CREATE TABLE IF NOT EXISTS `insurance_general_basic` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `insurance_id` bigint NOT NULL,
  `org_code` varchar(10) NOT NULL,
  `is_renewal` tinyint(1) DEFAULT '0' COMMENT '갱신여부',
  `issue_date` varchar(8) DEFAULT NULL COMMENT '계약체결일',
  `maturity_date` varchar(8) DEFAULT NULL COMMENT '만기일자',
  `join_amount` varchar(20) DEFAULT NULL COMMENT '보험가입금액',
  `currency_code` varchar(3) DEFAULT NULL COMMENT '통화코드',
  `contractor` varchar(255) DEFAULT NULL COMMENT '계약자명',
  `created_at` datetime NOT NULL COMMENT '생성일자',
  `updated_at` datetime DEFAULT NULL COMMENT '수정일자',
  PRIMARY KEY (`id`),
  KEY `my_data_insurance_general_basic_insurance_id_index` (`insurance_id`),
  KEY `my_data_insurance_general_basic_member_id_index` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 물/일반 보험 기본 정보';

CREATE TABLE IF NOT EXISTS `insurance_general_contract` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `org_code` varchar(10) NOT NULL,
  `insurance_id` bigint NOT NULL,
  `general_basic_id` bigint NOT NULL COMMENT '마이데이터 물/일반 보험 기본정보 FK',
  `general_insured_id` bigint NOT NULL COMMENT '마이데이터 물/일반 보험 피보험인 FK',
  `name` varchar(300) NOT NULL COMMENT '특약 명',
  `status_code` varchar(5) NOT NULL COMMENT '특약의 상태(코드)',
  `maturity_date` varchar(8) NOT NULL COMMENT '특약 만기 일자',
  `join_amount` varchar(20) NOT NULL COMMENT '특약가입금액',
  `currency_code` varchar(3) DEFAULT NULL COMMENT '통화코드',
  `is_required` tinyint(1) NOT NULL COMMENT '특약의 유형',
  `created_at` datetime NOT NULL COMMENT '생성 일자',
  `updated_at` datetime NOT NULL COMMENT '수정 일자',
  PRIMARY KEY (`id`),
  KEY `my_data_insurance_general_contract_general_basic_id_index` (`general_basic_id`),
  KEY `my_data_insurance_general_contract_general_insured_id_index` (`general_insured_id`),
  KEY `my_data_insurance_general_contract_insurance_id_index` (`insurance_id`),
  KEY `my_data_insurance_general_contract_member_id_index` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 물/일반 보험 특약 정보';

CREATE TABLE IF NOT EXISTS `insurance_general_insured` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `insurance_id` bigint NOT NULL,
  `general_basic_id` bigint NOT NULL COMMENT '물/일반 보험 기본정보 FK',
  `org_code` varchar(10) NOT NULL,
  `is_person` varchar(5) NOT NULL COMMENT '인/물 구분 코드',
  `prize_num` varchar(50) NOT NULL COMMENT '피보험인/물 번호',
  `prize_name` varchar(300) DEFAULT NULL COMMENT '피보험인/물 명',
  `is_primary` tinyint(1) DEFAULT NULL COMMENT '주피보험자 여부',
  `prize_addr` varchar(300) DEFAULT NULL COMMENT '소재지',
  `object_code` varchar(5) DEFAULT NULL COMMENT '물건 구분',
  `prize_code` varchar(5) DEFAULT NULL COMMENT '목적물 구분',
  `created_at` datetime NOT NULL COMMENT '생성 일자',
  `updated_at` datetime NOT NULL COMMENT '수정 일자',
  PRIMARY KEY (`id`),
  KEY `my_data_insurance_general_insured_general_basic_id_index` (`general_basic_id`),
  KEY `my_data_insurance_general_insured_insurance_id_index` (`insurance_id`),
  KEY `my_data_insurance_general_insured_member_id_index` (`member_id`),
  KEY `my_data_insurance_general_insured_prize_num_index` (`prize_num`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 물/일반 보험 피보험인';

CREATE TABLE IF NOT EXISTS `insurance_general_transaction` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL,
  `org_code` varchar(10) NOT NULL COMMENT '기관 코드',
  `insurance_id` bigint NOT NULL COMMENT 'my_data_insurance table id',
  `general_basic_id` bigint DEFAULT NULL COMMENT 'my_data_insurance_general_basic table id',
  `payment_ym` varchar(6) DEFAULT NULL COMMENT '납입 년월',
  `payment_no` varchar(4) DEFAULT NULL COMMENT '납입 회차',
  `payment_date` varchar(8) DEFAULT NULL COMMENT '납입 일자',
  `real_payment_amount` varchar(20) DEFAULT NULL COMMENT '실 납입 보혐료',
  `currency_code` varchar(4) DEFAULT NULL COMMENT '통화코드',
  `payment_method_code` char(2) DEFAULT NULL COMMENT '납입 방법 코드 - 01: 지로, 02: 자동이체, 03: 직납, 04: 신용카드, 05: 급여공제, 06: 간편결제 /99: 기타',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `payment_no_numeric` int unsigned GENERATED ALWAYS AS ((case when regexp_like(`payment_no`,_utf8mb3'^[0-9]+$') then cast(`payment_no` as unsigned) else NULL end)) VIRTUAL,
  PRIMARY KEY (`id`),
  KEY `my_data_insurance_general_transaction_insurance_id` (`insurance_id`),
  KEY `my_data_insurance_general_transaction_member_id` (`member_id`),
  KEY `my_data_insurance_general_transaction_general_basic_id` (`general_basic_id`),
  KEY `my_data_insurance_general_transaction_general_basic_payment_ym` (`general_basic_id`,`payment_ym`),
  KEY `idx_mdigt_insurance_id_payment_no_numeric` (`insurance_id`,`payment_no_numeric`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 물/일반 보험 거래내역 정보';

CREATE TABLE IF NOT EXISTS `insurance_insured` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `org_code` varchar(10) DEFAULT NULL COMMENT '기관 코드',
  `insurance_id` bigint NOT NULL COMMENT 'my_data_insurance table id',
  `basic_id` bigint NOT NULL COMMENT 'my_data_insurance_basic table id',
  `insured_no` varchar(10) DEFAULT NULL COMMENT '피보험자 순번',
  `name` varchar(50) DEFAULT NULL COMMENT '피보험자 명',
  `is_primary` tinyint(1) DEFAULT NULL COMMENT '주피보험자 여부',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  UNIQUE KEY `my_data_insurance_insured_u_index_case1` (`insurance_id`,`basic_id`,`insured_no`),
  KEY `basic_id` (`basic_id`),
  KEY `my_data_insurance_insured_index_case1` (`member_id`),
  CONSTRAINT `my_data_insurance_insured_ibfk_1` FOREIGN KEY (`insurance_id`) REFERENCES `insurance` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `my_data_insurance_insured_ibfk_2` FOREIGN KEY (`basic_id`) REFERENCES `insurance_basic` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마아데이터 - 보험 피보험자 정보';

CREATE TABLE IF NOT EXISTS `insurance_payment` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `org_code` varchar(10) DEFAULT NULL COMMENT '기관 코드',
  `insurance_id` bigint NOT NULL COMMENT 'my_data_insurance table id',
  `payment_period_code` varchar(2) DEFAULT NULL COMMENT '납입 기간 코드 - 01: 일시납, 02: 연납, 03: 세납',
  `payment_cycle_code` varchar(2) DEFAULT NULL COMMENT '납입 주기 코드 - 1M: 매월, 2M: 2개월납, 3M: 3개월, 6M: 6개월, 1Y: 연단위, 99: 일시납',
  `total_payment_count` varchar(20) DEFAULT NULL COMMENT '총 납입 횟수',
  `payment_org_code` varchar(10) DEFAULT NULL COMMENT '납입 기관 코드',
  `pay_account_num` varchar(30) DEFAULT NULL COMMENT '납입 계좌번호(자동이체)',
  `payment_day` varchar(2) DEFAULT NULL COMMENT '납입일',
  `payment_end_date` varchar(8) DEFAULT NULL COMMENT '납입 종료 일자',
  `payment_amount` varchar(20) DEFAULT NULL COMMENT '납입 보험료',
  `currency_code` varchar(4) DEFAULT NULL COMMENT '통화코드',
  `is_auto_payment` tinyint(1) DEFAULT NULL COMMENT '자동대출납입 신청 여부 - true:신청, false:미신청',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  UNIQUE KEY `my_data_insurance_payment_u_index_case1` (`insurance_id`),
  KEY `my_data_insurance_payment_index_case1` (`member_id`),
  KEY `my_data_insurance_payment_member_id_insurance_id_index` (`member_id`,`insurance_id`),
  CONSTRAINT `my_data_insurance_payment_ibfk_1` FOREIGN KEY (`insurance_id`) REFERENCES `insurance` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 보험 납입 정보';

CREATE TABLE IF NOT EXISTS `insurance_payment_average` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '기본 키',
  `age_group` varchar(255) NOT NULL COMMENT '연령대 (예: AGE_20, AGE_30 등)',
  `gender` varchar(255) NOT NULL COMMENT '성별 (예: F,M)',
  `average` bigint NOT NULL COMMENT '해당 연령대와 성별의 평균 보험료 지불 금액',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '레코드 생성 시간',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '레코드 수정 시간 (업데이트 시 자동 갱신)',
  `display_date` date DEFAULT NULL COMMENT '노출 일자',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `insurance_transaction` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL,
  `org_code` varchar(10) NOT NULL COMMENT '기관 코드',
  `insurance_id` bigint NOT NULL COMMENT 'my_data_insurance table id',
  `basic_id` bigint DEFAULT NULL COMMENT 'my_data_insurance_basic table id',
  `payment_ym` varchar(6) DEFAULT NULL COMMENT '납입 년월',
  `payment_no` varchar(4) DEFAULT NULL COMMENT '납입 회차',
  `payment_date` varchar(8) DEFAULT NULL COMMENT '납입 일자',
  `real_payment_amount` varchar(20) DEFAULT NULL COMMENT '실 납입 보혐료',
  `currency_code` varchar(4) DEFAULT NULL COMMENT '통화코드',
  `payment_method_code` char(2) DEFAULT NULL COMMENT '납입 방법 코드 - 01: 지로, 02: 자동이체, 03: 직납, 04: 신용카드, 05: 급여공제, 06: 간편결제 /99: 기타',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `payment_no_numeric` int unsigned GENERATED ALWAYS AS ((case when regexp_like(`payment_no`,_utf8mb3'^[0-9]+$') then cast(`payment_no` as unsigned) else NULL end)) VIRTUAL,
  PRIMARY KEY (`id`),
  KEY `my_data_insurance_transaction_insurance_id` (`insurance_id`),
  KEY `my_data_insurance_transaction_member_id` (`member_id`),
  KEY `my_data_insurance_transaction_basic_id` (`basic_id`),
  KEY `my_data_insurance_transaction_basic_id_payment_ym` (`basic_id`,`payment_ym`),
  KEY `idx_mdit_insurance_id_payment_no_numeric` (`insurance_id`,`payment_no_numeric`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 보험 거래내역 정보';

CREATE TABLE IF NOT EXISTS `insured_basic` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `insurance_id` bigint NOT NULL,
  `org_code` varchar(10) DEFAULT NULL,
  `join_amount` varchar(20) DEFAULT NULL,
  `currency_code` varchar(3) DEFAULT NULL,
  `issue_date` varchar(8) DEFAULT NULL,
  `maturity_date` varchar(8) DEFAULT NULL,
  `is_renewal` bit(1) DEFAULT NULL,
  `is_variable` bit(1) DEFAULT NULL,
  `is_universal` bit(1) DEFAULT NULL,
  `contractor` varchar(255) DEFAULT NULL,
  `is_primary` bit(1) DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uc_my_data_insured_basic_my_data_insured` (`insurance_id`),
  KEY `my_data_insured_basic_member_id_index` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `insured_contract` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `org_code` varchar(10) DEFAULT NULL,
  `insurance_id` bigint NOT NULL,
  `name` varchar(300) DEFAULT NULL,
  `status_code` varchar(2) DEFAULT NULL,
  `maturity_date` varchar(8) DEFAULT NULL,
  `join_amount` varchar(20) DEFAULT NULL,
  `currency_code` varchar(3) DEFAULT NULL,
  `is_required` bit(1) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `my_data_insured_contract_member_id_index` (`member_id`),
  KEY `my_data_insured_contract_my_data_insured_id_index` (`insurance_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `irp` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `industry_code` varchar(10) DEFAULT NULL COMMENT '업권 - bank : 은행, card : 카드, invest : 금융투자, insu : 보험, efin : 전자금융, capital : 할부금융, ginsu : 보증보험, telecom : 통신',
  `org_code` varchar(10) NOT NULL COMMENT '기관 코드',
  `product_name` varchar(300) DEFAULT NULL COMMENT '상품명',
  `account_no` varchar(20) DEFAULT NULL COMMENT '고객이 보유한 개인형 IRP 계좌번호',
  `is_consent` tinyint(1) NOT NULL DEFAULT '1' COMMENT '전송요구 여부 - true: 요구, false: 미요구',
  `is_show` tinyint(1) NOT NULL DEFAULT '1' COMMENT '노출 여부 - true ; 노출, false: 미노출',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  KEY `my_data_irp_index_case1` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 개인형 IRP 계좌 정보(보험, 은행, 금투 공통)';

CREATE TABLE IF NOT EXISTS `irp_basic` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `org_code` varchar(10) DEFAULT NULL COMMENT '기관 코드',
  `irp_id` bigint NOT NULL,
  `accumulated_amount` varchar(20) DEFAULT NULL COMMENT '적립 금액',
  `evaluation_amount` varchar(20) DEFAULT NULL COMMENT '계좌평가금액',
  `employer_amount` varchar(20) DEFAULT NULL COMMENT '사용자 부담금',
  `employee_amount` varchar(20) DEFAULT NULL COMMENT '가입자 부담금',
  `issue_date` varchar(8) DEFAULT NULL COMMENT '계좌 개설일',
  `first_deposit_date` varchar(8) DEFAULT NULL COMMENT '최초 입금 일자',
  `registration_date` varchar(8) DEFAULT NULL COMMENT '최초 제도 가입일',
  `pension_start_date` varchar(8) DEFAULT NULL COMMENT '연금개시시작(예정)일',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  UNIQUE KEY `my_data_irp_basic_u_index_case1` (`irp_id`),
  KEY `my_data_irp_basic_index_case1` (`member_id`),
  CONSTRAINT `my_data_irp_basic_ibfk_1` FOREIGN KEY (`irp_id`) REFERENCES `irp` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 개인형 IRP 계좌 기본 정보';

CREATE TABLE IF NOT EXISTS `irp_detail` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `org_code` varchar(10) DEFAULT NULL COMMENT '기관 코드',
  `irp_id` bigint NOT NULL,
  `irp_name` varchar(300) DEFAULT NULL COMMENT '개별운용상품명',
  `irp_no` varchar(64) DEFAULT NULL COMMENT '상품관리번호 (동일상품에 대해 여러 번 투 자한 경우 이를 구분하기 위한 식별값)',
  `irp_type_code` varchar(2) DEFAULT NULL COMMENT '상품 유형 코드 - 01: 원리금 보장(예금), 02: 원리금 비보장(펀드)',
  `evaluation_amount` varchar(20) DEFAULT NULL COMMENT '평가 금액',
  `investment_principal` varchar(20) DEFAULT NULL COMMENT '투자 원금',
  `fund_count` varchar(20) DEFAULT NULL COMMENT '보유좌수',
  `open_date` varchar(8) DEFAULT NULL COMMENT '개별상품 신규일(재예치일)',
  `maturity_date` varchar(8) DEFAULT NULL COMMENT '개발상품 만기일',
  `interest_rate` varchar(10) DEFAULT NULL COMMENT '약정 이자율',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  KEY `irp_id` (`irp_id`),
  KEY `my_data_irp_detail_index_case1` (`member_id`),
  CONSTRAINT `my_data_irp_detail_ibfk_1` FOREIGN KEY (`irp_id`) REFERENCES `irp` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 개인형 IRP 계좌 추가 정보';

CREATE TABLE IF NOT EXISTS `irp_transaction` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `org_code` varchar(10) DEFAULT NULL COMMENT '기관 코드',
  `irp_id` bigint NOT NULL,
  `transaction_ym` varchar(6) DEFAULT NULL COMMENT '거래 년월',
  `transaction_time` varchar(20) DEFAULT NULL COMMENT '거래일시',
  `transaction_no` varchar(64) DEFAULT NULL COMMENT '거래번호 (없을 경우 미회신)',
  `transaction_type_code` varchar(2) DEFAULT NULL COMMENT '거래 구분 코드 - 01: 입금, 02: 지급',
  `transaction_amount` varchar(20) DEFAULT NULL COMMENT '거래 금액',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  KEY `irp_id` (`irp_id`),
  KEY `my_data_irp_transaction_index_case2` (`irp_id`,`transaction_ym`),
  KEY `my_data_irp_transaction_index_case1` (`member_id`),
  CONSTRAINT `my_data_irp_transaction_ibfk_1` FOREIGN KEY (`irp_id`) REFERENCES `irp` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 개인형 IRP 계좌 거래내역 정보';

CREATE TABLE IF NOT EXISTS `linkage_count` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '기본 키',
  `age_group` varchar(255) NOT NULL COMMENT '연령대 (예: AGE_20, AGE_30등)',
  `gender` varchar(255) NOT NULL COMMENT '성별 (예: F, M)',
  `count` bigint NOT NULL COMMENT '해당 연령대와 성별에 대한 마이 데이터 링크 수',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '레코드 생성 시간',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '레코드 수정 시간 (업데이트 시 자동 갱신)',
  `display_date` date DEFAULT NULL COMMENT '노출 일자',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `management_statistics` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `stat_date` varchar(8) DEFAULT NULL COMMENT '통계일자',
  `type` varchar(1) DEFAULT NULL COMMENT '1- 정기적 전송, 2- 비정기적 전송(정보주체 개입), 3- 목록 전송',
  `is_sent` tinyint NOT NULL DEFAULT '0' COMMENT '마데 종합포털로 해당 통계가 전송되었는지 여부. 기본값 false',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  PRIMARY KEY (`id`),
  KEY `my_data_management_statistics_index_case1` (`stat_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 지원 통계 정보';

CREATE TABLE IF NOT EXISTS `management_statistics_org` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `s_id` bigint NOT NULL COMMENT 'my_data_management_statistics table id',
  `org_code` varchar(10) DEFAULT NULL COMMENT '마이데이터 기관 코드',
  `consent_new_count` varchar(20) DEFAULT NULL COMMENT '전송요구 신규/변경 수',
  `consent_revoke_count` varchar(20) DEFAULT NULL COMMENT '전송요구 철회 수',
  `consent_own_count` varchar(20) DEFAULT NULL COMMENT '전송요구 유효 수',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  PRIMARY KEY (`id`),
  KEY `my_data_management_statistics_org_index_case1` (`s_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 지원 통계 기관 정보';

CREATE TABLE IF NOT EXISTS `management_statistics_org_api` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `s_id` bigint NOT NULL COMMENT 'my_data_management_statistics table id',
  `s_org_id` bigint NOT NULL COMMENT 'my_data_management_statistics_org table id',
  `api_code` varchar(20) DEFAULT NULL COMMENT '마이데이터 API 구분 코드',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  PRIMARY KEY (`id`),
  KEY `my_data_management_statistics_org_api_index_case1` (`s_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 지원 통계 기관 API 정보';

CREATE TABLE IF NOT EXISTS `management_statistics_org_api_error_count` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `s_id` bigint NOT NULL COMMENT 'my_data_management_statistics table id',
  `s_org_id` bigint NOT NULL COMMENT 'my_data_management_statistics_org table id',
  `s_org_api_id` bigint NOT NULL COMMENT 'my_data_management_statistics_org_api table id',
  `s_time_slot_id` bigint NOT NULL COMMENT 'my_data_management_statistics_org_api_time_slot table id',
  `error_code` varchar(50) NOT NULL COMMENT '에러 응답 코드 - 지원-004 V2 규격',
  `error_count` int NOT NULL DEFAULT '0' COMMENT '에러 응답코드 별 응답 횟수',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  PRIMARY KEY (`id`),
  KEY `my_data_management_statistics_org_api_error_count_s_id_index` (`s_id`),
  KEY `statistics_org_api_error_count_s_time_slot_id_index` (`s_time_slot_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 지원 통계 에러 응답 횟수';

CREATE TABLE IF NOT EXISTS `management_statistics_org_api_time_slot` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `s_id` bigint NOT NULL COMMENT 'my_data_management_statistics table id',
  `s_org_id` bigint NOT NULL COMMENT 'my_data_management_statistics_org table id',
  `s_org_api_id` bigint NOT NULL COMMENT 'my_data_management_statistics_org_api table id',
  `time_slot` varchar(2) DEFAULT NULL COMMENT '시간대역 00- 09:00:00 ~ 17:59:59, 01-00대역 이외',
  `response_avg` varchar(20) DEFAULT NULL COMMENT '응답시간 평균값 (단위:ms)',
  `response_total` varchar(20) DEFAULT NULL COMMENT '응답시간 합계 (단위:ms)',
  `response_standard_deviation` varchar(20) DEFAULT NULL COMMENT '응답시간 표준편차 (단위:ms)',
  `success_api_count` varchar(20) DEFAULT NULL COMMENT '성공한 API 호출 횟수',
  `fail_api_count` varchar(20) DEFAULT NULL COMMENT '실패한 API 호출 횟수',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  PRIMARY KEY (`id`),
  KEY `my_data_management_statistics_org_api_time_slot_index_case1` (`s_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 지원 통계 시간대역 별 요청 정보';

CREATE TABLE IF NOT EXISTS `management_statistics_user_count` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `stat_date` date NOT NULL COMMENT '통계 기준 날짜',
  `register_user_count` int NOT NULL DEFAULT '0' COMMENT '마이데이터 서비스 가입자 수 (svr_usr_cnt)',
  `connect_user_count` int NOT NULL DEFAULT '0' COMMENT '전송요구 완료자 수 (trsms_dem_cnt)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  PRIMARY KEY (`id`),
  KEY `my_data_management_statistics_user_count_stat_date_index` (`stat_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 지원 통계 가입자 수';

CREATE TABLE IF NOT EXISTS `member_consents` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `industry_code` varchar(10) DEFAULT NULL COMMENT '업권 - bank : 은행, card : 카드, invest : 금융투자, insu : 보험, efin : 전자금융, capital : 할부금융, ginsu : 보증보험, telecom : 통신',
  `org_code` varchar(10) DEFAULT NULL COMMENT '업체 코드-기관 코드',
  `is_scheduled_request` tinyint(1) DEFAULT NULL COMMENT '정기적 전송을 요구하는지 여부 - true: 정기전송, false: 수동전송',
  `list_cycle` varchar(10) DEFAULT NULL COMMENT '기본정보의 정기적 전송 주기 - 규격 : 횟수/기준 (기준 - 월 m, 주 w, 일 d)',
  `detail_cycle` varchar(10) DEFAULT NULL COMMENT '추가정보의 정기적 전송 주기 - 규격 : 횟수/기준 (기준 - 월 m, 주 w, 일 d)',
  `request_end_date` varchar(8) DEFAULT NULL COMMENT '전송요구 종료 시점',
  `request_purpose` varchar(100) DEFAULT NULL COMMENT '전송을 요구하는 목적',
  `request_retention_period` varchar(8) DEFAULT NULL COMMENT '전송을 요구하는 개인신용정보의 보유기간',
  `next_scheduled_request_date` varchar(8) DEFAULT NULL COMMENT '정기적 전송을 요구 시 다음 요청 일',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  KEY `my_data_member_consents_index_case2` (`next_scheduled_request_date`),
  KEY `my_data_member_consents_index_case1` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 전송 요구 내역 정보';

CREATE TABLE IF NOT EXISTS `member_token` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `industry_code` varchar(10) DEFAULT NULL,
  `org_code` varchar(10) DEFAULT NULL COMMENT '업체 코드-기관 코드',
  `scope_type` varchar(500) DEFAULT NULL COMMENT '권한 구분',
  `request_type` char(1) DEFAULT NULL COMMENT '조회 구분',
  `token_type` varchar(6) DEFAULT NULL COMMENT '접근토큰 유형 - Bearer 고정값',
  `access_token` varchar(1500) DEFAULT NULL COMMENT '발급된 접근토큰',
  `access_token_maturity_time` varchar(20) DEFAULT NULL COMMENT '접근토큰 유효기간(단위: 초)',
  `access_token_maturity_at` datetime DEFAULT NULL COMMENT '접근 토큰 만기 시간',
  `refresh_token` varchar(1500) DEFAULT NULL COMMENT '접근토큰 갱신을 위한 토큰',
  `refresh_token_maturity_time` varchar(20) DEFAULT NULL COMMENT '리프레시 토큰 유효기간(단위: 초)',
  `refresh_token_maturity_at` datetime DEFAULT NULL COMMENT '리프레시 토큰 만기 시간',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  KEY `my_data_member_token_index_case3` (`refresh_token_maturity_at`),
  KEY `my_data_member_token_index_case2` (`access_token_maturity_at`),
  KEY `my_data_member_token_index_case1` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 접근 토큰 정보(전송 요구 내역 정보 포함)';

CREATE TABLE IF NOT EXISTS `member_token_duplicate` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `industry_code` varchar(10) DEFAULT NULL,
  `org_code` varchar(10) DEFAULT NULL COMMENT '업체 코드-기관 코드',
  `scope_type` varchar(500) DEFAULT NULL COMMENT '권한 구분',
  `request_type` char(1) DEFAULT NULL COMMENT '조회 구분',
  `token_type` varchar(6) DEFAULT NULL COMMENT '접근토큰 유형 - Bearer 고정값',
  `access_token` varchar(1500) DEFAULT NULL COMMENT '발급된 접근토큰',
  `access_token_maturity_time` varchar(20) DEFAULT NULL COMMENT '접근토큰 유효기간(단위: 초)',
  `access_token_maturity_at` datetime DEFAULT NULL COMMENT '접근 토큰 만기 시간',
  `refresh_token` varchar(1500) DEFAULT NULL COMMENT '접근토큰 갱신을 위한 토큰',
  `refresh_token_maturity_time` varchar(20) DEFAULT NULL COMMENT '리프레시 토큰 유효기간(단위: 초)',
  `refresh_token_maturity_at` datetime DEFAULT NULL COMMENT '리프레시 토큰 만기 시간',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  PRIMARY KEY (`id`),
  KEY `my_data_member_token_index_member_id` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 접근 토큰 중복 발생 파기 기록';

CREATE TABLE IF NOT EXISTS `member_token_refresh_fail` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `my_data_member_token_id` bigint NOT NULL,
  `member_id` bigint NOT NULL,
  `org_code` varchar(10) NOT NULL,
  `error_code` varchar(50) DEFAULT NULL,
  `error_description` varchar(255) DEFAULT NULL,
  `fail_count` int NOT NULL,
  `next_request_time` datetime NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `transaction_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `my_data_member_token_refresh_fail_my_data_member_token_id_index` (`my_data_member_token_id`),
  KEY `my_data_member_token_refresh_fail_org_code_index` (`org_code`),
  KEY `my_data_member_token_refresh_fail_error_code_index` (`error_code`),
  KEY `my_data_member_token_refresh_fail_next_request_time_index` (`next_request_time`),
  KEY `my_data_member_token_refresh_fail_created_at_time_index` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `org` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `op_type_code` varchar(2) DEFAULT NULL COMMENT '기관정보의 신규/수정/삭제 구분 - I : 신규, M : 수정, D : 삭제',
  `org_type_code` varchar(2) DEFAULT NULL COMMENT '기관구분 - 01 : 정보제공자 (API 자체구축), 02 : 정보제공자 (중계기관 이용), 03 : 마이데이터사업자, 04 : 중계기관, 05 : 통합인증기관(인증서 본인확인기관), 06 : 통합인증기관(전자서명인증사업자), 99 : 기타',
  `org_code` varchar(10) DEFAULT NULL COMMENT '기관 코드',
  `org_name` varchar(60) DEFAULT NULL COMMENT '기관명',
  `org_registration_no` varchar(20) DEFAULT NULL COMMENT '사업자등록번 (op_type=D인 경우 미회신)',
  `corporation_registration_no` varchar(20) DEFAULT NULL COMMENT '법인등록번호 (op_type=D인 경우 미회신)',
  `serial_no` varchar(20) DEFAULT NULL COMMENT 'TLS 인증서 시리얼넘버',
  `address` varchar(150) DEFAULT NULL COMMENT '주소',
  `domain` varchar(60) DEFAULT NULL COMMENT 'API서버 도메인명',
  `domain_ip` varchar(20) DEFAULT NULL COMMENT 'API서버 공인IP',
  `relay_org_code` varchar(20) DEFAULT NULL COMMENT '중계기관 기관코드',
  `industry_code` varchar(10) DEFAULT NULL COMMENT '업권 - bank : 은행, card : 카드, invest : 금융투자, insu : 보험, efin : 전자금융, capital : 할부금융, ginsu : 보증보험, telecom : 통신',
  `auth_type_code` varchar(2) DEFAULT NULL COMMENT '제공 인증방식 코드 - 01 : 통합인증만 제공, 03 : 개별인증/통합인증 모두 제공',
  `cert_issuer_dn` varchar(20) DEFAULT NULL COMMENT '통합인증기관 의 DN 값 (인증서 본인확인기관 DN의 o 값)',
  `cert_oid` varchar(300) DEFAULT NULL COMMENT '허용 통합인증서 OID',
  `bomapp_name` varchar(128) DEFAULT NULL COMMENT '보맵 보험사 명',
  `bomapp_code` varchar(3) DEFAULT NULL COMMENT '보맵 코드 정보',
  `logo_url` varchar(512) DEFAULT NULL COMMENT '로고 URL',
  `direct_logo_url` varchar(512) DEFAULT NULL COMMENT '다이렉트 로고 URL',
  `call_number` varchar(64) DEFAULT NULL COMMENT '대표 전화번호',
  `is_able` tinyint(1) DEFAULT '0' COMMENT '기관 사용 가능 여부 true- 가능, false- 불가능',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  `is_error` tinyint(1) NOT NULL DEFAULT '0' COMMENT '보험사 장애 유무 (true 문제 있음. 기본값 false)',
  PRIMARY KEY (`id`),
  KEY `my_data_org_index_case4` (`cert_issuer_dn`),
  KEY `my_data_org_index_case3` (`industry_code`),
  KEY `my_data_org_index_case2` (`org_type_code`),
  KEY `my_data_org_index_case1` (`org_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 기관정보';

CREATE TABLE IF NOT EXISTS `org_api` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `version_id` bigint DEFAULT NULL COMMENT 'my_data_org_api_version table id',
  `org_code` varchar(10) DEFAULT NULL COMMENT '업체 코드-기관 코드',
  `api_code` varchar(4) DEFAULT NULL COMMENT 'API 구분 코드',
  `api_uri` varchar(50) DEFAULT NULL COMMENT 'API 명',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `my_data_org_api_u_index_case1` (`org_code`,`api_code`),
  KEY `version_id` (`version_id`),
  CONSTRAINT `my_data_org_api_ibfk_1` FOREIGN KEY (`version_id`) REFERENCES `org_api_version` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='업권별 정보제공 API 정보';

CREATE TABLE IF NOT EXISTS `org_api_version` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `org_code` varchar(10) DEFAULT NULL COMMENT '업체 코드-기관 코드',
  `version` varchar(10) DEFAULT NULL COMMENT '현재 버전',
  `min_version` varchar(10) DEFAULT NULL COMMENT '호환가능 최소 버전',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `my_data_org_api_u_index_case1` (`org_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='업권별 정보제공 API 버전 정보';

CREATE TABLE IF NOT EXISTS `org_domain_ip` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `org_id` bigint NOT NULL COMMENT 'my_data_org_information table id',
  `ip` varchar(21) DEFAULT NULL COMMENT 'IP 및 PORT',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  KEY `org_id` (`org_id`),
  CONSTRAINT `my_data_org_domain_ip_ibfk_1` FOREIGN KEY (`org_id`) REFERENCES `org` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 기관 도메인 ip 정보';

CREATE TABLE IF NOT EXISTS `org_inspection_time` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `org_code` varchar(10) NOT NULL COMMENT '기관 코드',
  `start_time` datetime NOT NULL COMMENT '점검 시작 일시',
  `end_time` datetime NOT NULL COMMENT '점검 종료 일시',
  `created_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `my_data_org_inspection_time_start_time_end_time_index` (`start_time`,`end_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='기관 점검 일시 관리';

CREATE TABLE IF NOT EXISTS `org_ip` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `org_id` bigint NOT NULL COMMENT 'my_data_org_information table id',
  `ip` varchar(20) DEFAULT NULL COMMENT 'IP 및 PORT',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  KEY `org_id` (`org_id`),
  CONSTRAINT `my_data_org_ip_ibfk_1` FOREIGN KEY (`org_id`) REFERENCES `org` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 기관 IP 정보';

CREATE TABLE IF NOT EXISTS `org_schedule_time` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `org_id` bigint NOT NULL COMMENT 'my_data_org_information table id',
  `schedule_time` varchar(10) DEFAULT NULL COMMENT '가능 시간대 hhmm:hhmm',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  KEY `org_id` (`org_id`),
  CONSTRAINT `my_data_org_schedule_time_ibfk_1` FOREIGN KEY (`org_id`) REFERENCES `org` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 - 기관 정기적 전송 가능 시간대 정보';

CREATE TABLE IF NOT EXISTS `refresh_member` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL,
  `is_completed` tinyint(1) NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `my_data_refresh_member_created_at_index` (`created_at`),
  KEY `my_data_refresh_member_member_id_index` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 정기적 데이터 갱신 대상자 테이블';

CREATE TABLE IF NOT EXISTS `signup_org` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `member_id` bigint NOT NULL COMMENT '보맵 member 테이블의 uid',
  `org_code` varchar(50) NOT NULL COMMENT '마이데이터 사업자의 기관 코드',
  `org_name` varchar(100) DEFAULT NULL COMMENT '기관 이름',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '조회 날짜',
  `is_member` tinyint(1) DEFAULT NULL COMMENT '마이데이터 사업의 가입 여부, null인 경우 기관이 해당 정보를 제공하지 않음',
  PRIMARY KEY (`id`),
  UNIQUE KEY `member_id` (`member_id`,`org_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터사업자 서비스의 가입 현황을 저장하는 테이블';

CREATE TABLE IF NOT EXISTS `support_agreement_history` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `member_id` bigint NOT NULL COMMENT '회원 ID',
  `org_code` varchar(11) NOT NULL COMMENT '기관 코드',
  `service_name` varchar(300) DEFAULT NULL COMMENT '서비스명',
  `consent_name` varchar(300) DEFAULT NULL COMMENT '동의서명',
  `consent_dtime` varchar(20) DEFAULT NULL COMMENT '동의일시',
  `consent_rcv_name` varchar(500) DEFAULT NULL COMMENT '제공받는 자',
  `consent_purpose` varchar(3000) DEFAULT NULL COMMENT '제공받는 자의 이용 목적',
  `consent_asset` varchar(10000) DEFAULT NULL COMMENT '제공 항목',
  `consent_period` varchar(255) DEFAULT NULL COMMENT '보유 및 이용기간',
  `revoke_dtime` varchar(20) DEFAULT NULL COMMENT '철회 시간',
  `is_success` tinyint(1) NOT NULL COMMENT '성공 여부',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `prov_consent_num` varchar(50) DEFAULT NULL COMMENT '관리번호(기관코드 10 + 자율채번 40)',
  `prov_consent_status` varchar(2) DEFAULT NULL COMMENT '동의서 상태',
  `is_once` tinyint(1) DEFAULT NULL COMMENT '일회성 여부',
  `prov_consent_purpose_type` varchar(2) DEFAULT NULL COMMENT '제공받는 자의 이용목적 구분(코드)',
  `reward` varchar(2) DEFAULT NULL COMMENT '지급 대가 (00: 대가 없음, 01: 금전, 02: 정보)',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 지원 동의 내역';

CREATE DATABASE IF NOT EXISTS `planner` DEFAULT CHARACTER SET utf8mb4;
USE `planner`;
CREATE TABLE IF NOT EXISTS `planner_profile` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `planner_id` int NOT NULL COMMENT 'w_planner.id 1:1 (w_planner.id 가 INT signed)',
  `one_line_intro` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '한줄 소개 (20자, 띄어쓰기 포함)',
  `job_title` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'PlannerJobTitle enum',
  `office_name` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '사무실/지점명 (플래너 직접 입력)',
  `office_postcode` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '우편번호',
  `office_address` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '사무실 주소 (기본)',
  `office_address_detail` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '상세 주소',
  `business_mobile` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '명함용 휴대폰 (w_planner.mobile 과 분리)',
  `template_id` tinyint unsigned NOT NULL COMMENT '명함 디자인 템플릿 ID',
  `profile_image_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'BASIC / PRESET / CUSTOM',
  `profile_image_preset_id` tinyint unsigned DEFAULT NULL COMMENT 'PRESET 일 때만 (1 이상, 카탈로그는 FE 소유)',
  `profile_image_path` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'CUSTOM 일 때만 (S3 키)',
  `email` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fax` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `planner_introduction` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '플래너 소개 (500자)',
  `insurance_agent_registration_number` varchar(14) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '보험모집종사자 등록 번호 (14자리)',
  `instagram_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `naver_blog_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `youtube_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `threads_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `facebook_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tiktok_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `planner_code` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'referralCode 우선, 충돌 시 nanoid fallback, v1 immutable',
  `created_at` datetime NOT NULL,
  `created_by_id` bigint DEFAULT NULL,
  `updated_at` datetime NOT NULL,
  `updated_by_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_planner_profile_planner_id` (`planner_id`),
  UNIQUE KEY `uk_planner_profile_planner_code` (`planner_code`),
  CONSTRAINT `fk_planner_profile_planner` FOREIGN KEY (`planner_id`) REFERENCES `planner` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='플래너 마이페이지 / 명함 프로필 (신규, w_planner 와 분리)';

CREATE TABLE IF NOT EXISTS `planner_profile_featured_product` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `planner_profile_id` bigint NOT NULL,
  `product_code` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'MainForceProduct enum 값',
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_planner_profile_featured_product` (`planner_profile_id`,`product_code`),
  CONSTRAINT `fk_planner_profile_featured_product_profile` FOREIGN KEY (`planner_profile_id`) REFERENCES `planner_profile` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='플래너 마이페이지 주력 판매 상품 (1:N, w_planner_main_force_product 와 분리)';

CREATE TABLE IF NOT EXISTS `recommend_amount_member` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `planner_member_id` bigint NOT NULL,
  `guarantee_code` varchar(20) NOT NULL COMMENT '보장 코드',
  `amount` bigint NOT NULL DEFAULT '0' COMMENT '고객 맞춤 권장 금액',
  `deleted_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `ix_recommend_amount_member_planner_member_id_guarantee_code` (`planner_member_id`,`guarantee_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `recommend_amount_planner` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `planner_id` bigint NOT NULL COMMENT 'planner.id (플래너 본인)',
  `guarantee_code` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'GuaranteeCode.bomappCode (예: DT-HT-IT)',
  `amount` bigint NOT NULL COMMENT '플래너가 설정한 기본 권장 금액 (원)',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_rap_planner_guarantee` (`planner_id`,`guarantee_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='플래너 기본 권장 금액 템플릿 (PLA-47)';

CREATE TABLE IF NOT EXISTS `consultation` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `planner_member_id` bigint DEFAULT NULL,
  `applied_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reserved_at` datetime DEFAULT NULL,
  `reservation_method` varchar(100) DEFAULT NULL COMMENT '상담할 방법. 카톡, 전화, 화상, 방문',
  `insured_at` datetime DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'UNASSIGNED',
  `assigned_at` datetime DEFAULT NULL,
  `status_updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `is_finished` tinyint(1) DEFAULT '0' COMMENT '상담이 종료되었는지 여부.(인수거절, 청약 거절, 계약 완료) 기본값 false 0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by_id` bigint DEFAULT NULL COMMENT '보맵 관리자 or 설계사 account_id',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  `updated_by_id` bigint DEFAULT NULL,
  `deleted_by_id` bigint DEFAULT NULL,
  `canceled_at` datetime DEFAULT NULL COMMENT '상담 철회 시간',
  `canceled_by_id` bigint DEFAULT NULL,
  `chat_status` varchar(50) DEFAULT NULL COMMENT '채팅상담 상태',
  `az_registered_at` datetime DEFAULT NULL COMMENT 'AZ 전산에 현재 등록되어 있는 시점 (cancel 성공 시 NULL). NULL = AZ 에 active row 없음',
  `az_contact_type` varchar(10) DEFAULT NULL COMMENT 'AZ 에 현재 등록된 채널 (TEL / CHAT). az_registered_at = NULL 이면 NULL',
  PRIMARY KEY (`id`),
  KEY `idx_wc_pm_id_status_applied` (`planner_member_id`,`status`,`applied_at`),
  KEY `idx_wc_applied_pm` (`applied_at`,`planner_member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `consultation_allocation_history` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `corporation_code` varchar(64) NOT NULL,
  `planner_member_id` bigint NOT NULL,
  `action` varchar(10) NOT NULL COMMENT '신청/철회 구분',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `w_consultation_allocation_history_corporation_code_index` (`corporation_code`),
  KEY `w_consultation_allocation_history_created_at_index` (`created_at`),
  KEY `w_consultation_allocation_history_planner_member_id_index` (`planner_member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='상담 DB 배분 히스토리 저장(신청 및 배정 전 철회 건)';

CREATE TABLE IF NOT EXISTS `consultation_allocation_setting` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `corporation_code` varchar(64) NOT NULL,
  `monthly_max_count` bigint NOT NULL COMMENT '월별 최대 배분 제한수',
  `daily_max_count` bigint NOT NULL COMMENT '일별 최대 배분 제한수',
  `is_allocable` tinyint(1) NOT NULL COMMENT '상담 DB 배분 대상 회사인지 여부',
  `chat_daily_max_count` int DEFAULT '0',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `w_consultation_allocation_setting_corporation_code_index` (`corporation_code`),
  KEY `w_consultation_allocation_setting_created_at_index` (`created_at`),
  KEY `w_consultation_allocation_setting_is_allocable_index` (`is_allocable`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='상담 DB 배분 시 활용하는 설정값 저장';

CREATE TABLE IF NOT EXISTS `consultation_apply_history` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `planner_member_id` bigint NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `w_consultation_apply_history_created_at_index` (`created_at`),
  KEY `w_consultation_apply_history_planner_member_id_index` (`planner_member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='고객의 상담신청 히스토리 저장(고객이 상담신청 버튼을 누를 때마다 저장)';

CREATE TABLE IF NOT EXISTS `consultation_cancel_reason` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `planner_member_id` bigint NOT NULL,
  `reason_type` varchar(30) DEFAULT NULL,
  `reason` varchar(30) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `w_consultation_cancel_reason_created_at_index` (`created_at`),
  KEY `w_consultation_cancel_reason_planner_member_id_index` (`planner_member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='플래너 연결 끊기 사유 저장';

CREATE TABLE IF NOT EXISTS `consultation_status_history` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `consultation_id` bigint NOT NULL,
  `consultation_status` varchar(20) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by_id` bigint DEFAULT NULL COMMENT '상태 변경한 planner id',
  PRIMARY KEY (`id`),
  KEY `w_consultation_status_history_consultation_id_index` (`consultation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `corp_one_depth` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL COMMENT '이름',
  `corporation_code` varchar(255) NOT NULL COMMENT '회사 식별자',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '지점 생성 일시',
  `created_by_id` bigint DEFAULT '1',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '지점 수정 일시',
  `updated_by_id` bigint DEFAULT '1',
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `w_corp_one_depth_corporation_code_index` (`corporation_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `corp_organization` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `corporation_code` varchar(32) NOT NULL COMMENT '회사 식별키',
  `depth` int NOT NULL COMMENT '조직 뎁스',
  `parent_id` bigint DEFAULT NULL COMMENT '상위 조직 id',
  `ga_org_code` varchar(64) NOT NULL COMMENT '조직 코드(az 관리컬럼명 : cate)',
  `ga_org_name` varchar(32) NOT NULL COMMENT '조직 이름',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_parent_id` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='고객사의 조직 정보를 저장(since 25.01)';

CREATE TABLE IF NOT EXISTS `corp_three_depth` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL COMMENT '이름',
  `two_depth_id` bigint NOT NULL COMMENT '2depth 식별자',
  `old_department_id` bigint DEFAULT NULL COMMENT '마이그레이션 후 삭제 필요',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 일시',
  `created_by_id` bigint DEFAULT '1',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정 일시',
  `updated_by_id` bigint DEFAULT '1',
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `w_corp_three_depth_two_depth_id_index` (`two_depth_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `corp_two_depth` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL COMMENT '이름',
  `one_depth_id` bigint NOT NULL COMMENT '1depth 식별자',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 일시',
  `created_by_id` bigint DEFAULT '1',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정 일시',
  `updated_by_id` bigint DEFAULT '1',
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `w_corp_two_depth_one_depth_id_index` (`one_depth_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `corporation` (
  `code` varchar(255) NOT NULL,
  `id` int DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `logo` varchar(255) DEFAULT NULL,
  `tel` varchar(20) DEFAULT NULL,
  `planner_id` bigint DEFAULT NULL,
  `is_only_referral` tinyint(1) DEFAULT '0',
  `created_by_id` bigint DEFAULT '1',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by_id` bigint DEFAULT '1',
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by_id` bigint DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`code`),
  UNIQUE KEY `w_corporation_id_uindex` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `faq` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `category` varchar(128) DEFAULT NULL,
  `question` varchar(1024) NOT NULL,
  `answer` text NOT NULL,
  `is_show` tinyint NOT NULL DEFAULT '0',
  `view_count` bigint NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL,
  `created_by_id` int NOT NULL COMMENT '이 계정을 생성한 planner 아이디',
  `updated_at` datetime NOT NULL,
  `updated_by_id` int DEFAULT NULL COMMENT '이 계정을 수정한 planner id',
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by_id` int DEFAULT NULL COMMENT '이 계정을 삭제한 planner id',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `insurer` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL COMMENT '보험사 이름',
  `call_number` varchar(100) DEFAULT NULL COMMENT '콜센터 번호',
  `logo_url` varchar(255) DEFAULT NULL COMMENT '보험사 로고이미지 경로',
  `insurer_type` varchar(50) DEFAULT NULL COMMENT '보험사 구분 (손해:손해보험사, 생명:생명보험사)',
  `is_show` tinyint NOT NULL COMMENT '공개, 전시 여부 ',
  `view_count` int NOT NULL DEFAULT '0',
  `claim_summary` varchar(500) DEFAULT NULL COMMENT '보험청구 내용 요약 (보맵에서 직접 기입)',
  `claim_url` varchar(255) DEFAULT NULL COMMENT '보험 청구 바로가기 링크',
  `claim_doc_name` varchar(255) DEFAULT NULL COMMENT '청구서류 업로드시 이름',
  `claim_doc_url` varchar(255) DEFAULT NULL COMMENT '청구서류 저장경로',
  `claim_required_docs_name` varchar(255) DEFAULT NULL COMMENT '청구 필요자료파일 업로드시 이름',
  `claim_through_agency_doc_url` varchar(255) DEFAULT NULL COMMENT '청구대행 신청서 파일 경로',
  `claim_through_agency_doc_name` varchar(255) DEFAULT NULL COMMENT '청구대행 신청서류 업로드시 이름',
  `claim_required_docs_url` varchar(255) DEFAULT NULL,
  `variable_ins_disclosure_url` varchar(255) DEFAULT NULL COMMENT '변액보험 상품공시실 url',
  `ins_plan_disclosure_url` varchar(255) DEFAULT NULL COMMENT '보험 상품공시실 url',
  `created_by_id` int DEFAULT NULL COMMENT '생성 관리자 id (coco_planner)',
  `created_at` datetime DEFAULT NULL,
  `updated_by_id` int DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `deleted_by_id` int DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `dental_treatment_doc_name` varchar(256) DEFAULT NULL COMMENT '치과 치료 확인서 이미지 이름',
  `dental_treatment_doc_url` varchar(256) DEFAULT NULL COMMENT '치과 치료 확인서 이미지 경로',
  `org_code` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `insurer_archive` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `insurer_id` bigint DEFAULT NULL,
  `is_show` tinyint NOT NULL DEFAULT '0',
  `category` varchar(128) DEFAULT NULL COMMENT '소식지, 인수기준, 영업 자료',
  `title` varchar(256) DEFAULT NULL,
  `content` text,
  `youtube_url` varchar(256) DEFAULT NULL,
  `content_image_pc_path` varchar(256) DEFAULT NULL,
  `content_image_pc_original_name` varchar(128) DEFAULT NULL,
  `content_image_mobile_path` varchar(256) DEFAULT NULL,
  `content_image_mobile_original_name` varchar(256) DEFAULT NULL,
  `attachment_path_1` varchar(256) DEFAULT NULL,
  `attachment_path_2` varchar(256) DEFAULT NULL,
  `attachment_path_3` varchar(256) DEFAULT NULL,
  `attachment_original_name_1` varchar(256) DEFAULT NULL,
  `attachment_original_name_2` varchar(256) DEFAULT NULL,
  `attachment_original_name_3` varchar(256) DEFAULT NULL,
  `view_count` bigint NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL,
  `created_by_id` int NOT NULL COMMENT '이 계정을 생성한 planner 아이디',
  `updated_at` datetime NOT NULL,
  `updated_by_id` int DEFAULT NULL COMMENT '이 계정을 수정한 planner id',
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by_id` int DEFAULT NULL COMMENT '이 계정을 삭제한 planner id',
  `download_count` int DEFAULT NULL,
  `display_date` date DEFAULT NULL COMMENT '게시물 노출 기준 일자',
  PRIMARY KEY (`id`),
  KEY `w_insurer_archive_insurer_id_index` (`insurer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `insurer_archive_support` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `category` varchar(50) DEFAULT NULL COMMENT '게시판 구분 (monthly-bomapp/boboosang/last-spurt)',
  `is_show` tinyint NOT NULL DEFAULT '0' COMMENT '전시 상태',
  `year` varchar(5) DEFAULT NULL COMMENT '년 (범위 : 2023 ~ 2030)',
  `month` varchar(5) DEFAULT NULL COMMENT '월 (범위 : 1 ~ 12)',
  `title` varchar(100) NOT NULL COMMENT '제목, 최대 50자까지 허용',
  `content_image_pc_path` varchar(512) DEFAULT NULL COMMENT '상세 이미지 > 이미지의 S3 업로드 경로(PC 전용)',
  `content_image_pc_original_name` varchar(256) DEFAULT NULL COMMENT '상세 이미지 > 이미지의 원본 이름(PC 전용)',
  `content_image_mobile_path` varchar(512) DEFAULT NULL COMMENT '상세 이미지 > 이미지의 S3 업로드 경로(Mobile 전용)',
  `content_image_mobile_original_name` varchar(256) DEFAULT NULL COMMENT '상세 이미지 > 이미지의 원본 이름(Mobile 전용)',
  `attachment_path` varchar(512) DEFAULT NULL COMMENT '첨부 파일 > 이미지(PDF)의 S3 업로드 경로',
  `attachment_original_name` varchar(256) DEFAULT NULL COMMENT '첨부 파일 > 이미지(PDF)의 원본 이름',
  `view_count` bigint NOT NULL DEFAULT '0' COMMENT '조회수',
  `created_by_id` int NOT NULL COMMENT '게시글 등록한 아이디',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '게시글 등록한 일시',
  `updated_by_id` int DEFAULT NULL COMMENT '게시글 수정한 아이디',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '게시글 수정한 일시',
  `deleted_at` datetime DEFAULT NULL COMMENT '게시글 삭제한 아이디',
  `deleted_by_id` int DEFAULT NULL COMMENT '게시글 삭제한 일시',
  `attach_download_count` bigint NOT NULL DEFAULT '0' COMMENT '첨부파일 다운로드 횟수',
  `thumbnail_original_name` varchar(256) DEFAULT NULL,
  `thumbnail_path` varchar(512) DEFAULT NULL,
  `display_date` date DEFAULT NULL,
  `category_id` int DEFAULT NULL,
  `video_url` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_insurer_archive_support_id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `insurer_archive_support_category` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `category_name` varchar(255) DEFAULT NULL,
  `is_show` tinyint(1) NOT NULL DEFAULT '1',
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by_id` bigint DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `created_by_id` bigint NOT NULL,
  `updated_at` datetime NOT NULL,
  `updated_by_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `insurer_archive_support_file` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `attachment_path` varchar(255) DEFAULT NULL,
  `attachment_original_name` varchar(255) DEFAULT NULL,
  `insurer_archive_support_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_insurer_archive_support_id` (`insurer_archive_support_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `insurer_bookmark` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `planner_id` bigint NOT NULL,
  `insurer_id` bigint NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `w_insurer_bookmark_planner_id_insurer_id_uindex` (`planner_id`,`insurer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `marketing_agree` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `marketing_policy_id` bigint NOT NULL COMMENT '약관 테이블 id',
  `corporation_code` varchar(255) NOT NULL COMMENT '마케팅 동의 대상 GA',
  `member_id` bigint NOT NULL,
  `is_sms_agree` tinyint NOT NULL DEFAULT '1' COMMENT '문자 수신 동의 여부 기본값 true 1',
  `is_call_agree` tinyint NOT NULL DEFAULT '1' COMMENT '전화 수신 동의 여부 기본값 true 1',
  `effective_end_at` datetime NOT NULL COMMENT '동의 유효 만료일',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `w_marketing_agree_member_id_corporation_code_index` (`member_id`,`corporation_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `memo` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `planner_member_id` bigint DEFAULT NULL,
  `content` varchar(500) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by_id` bigint NOT NULL,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by_id` bigint NOT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by_id` bigint DEFAULT NULL,
  `category` varchar(20) COLLATE utf8mb4_general_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `w_memo_planner_member_id_index` (`planner_member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `notification` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `planner_id` bigint DEFAULT NULL,
  `type` varchar(50) NOT NULL,
  `customer_type` varchar(16) NOT NULL DEFAULT 'BOMAPP',
  `message` varchar(255) DEFAULT NULL,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  `is_check` tinyint NOT NULL DEFAULT '0',
  `planner_member_id` bigint DEFAULT NULL,
  `insurer_archive_support_id` bigint DEFAULT NULL COMMENT '자료실(월간보맵/보부상/막판스퍼트) 식별자',
  `chat_room_id` bigint DEFAULT NULL COMMENT '발송 당시 채팅방 ID',
  `chat_status` varchar(255) DEFAULT NULL COMMENT '발송 당시 채팅방 상태',
  `notice_id` bigint DEFAULT NULL COMMENT '공지 알림(type=NOTICE)의 대상 공지 ID(planner_notice.id). 클릭 시 공지 상세 이동. 그 외 알림은 NULL',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_w_notification_planner_notice` (`planner_id`,`notice_id`),
  KEY `w_notification_planner_member_id_index` (`planner_member_id`),
  KEY `idx_notification_planner_ctype` (`planner_id`,`customer_type`,`deleted_at`,`is_check`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `planner` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '계정 사용자 이름',
  `mobile` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '계정 사용자 휴대폰 번호',
  `consultation_mobile` varchar(15) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '상담용 휴대폰번호',
  `branch` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '지점 정보',
  `password` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '비밀번호',
  `password_changed_at` datetime DEFAULT NULL COMMENT '비밀번호 수정일시',
  `login_id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '플래너 로그인 아이디',
  `role` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '권한 (ADMIN : 보맵 관리자, GA : GA관리자, MANAGER : 팀매니저, CONSULTANT : 설계사 )',
  `login_fail_count` int DEFAULT NULL,
  `referral_code` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `corporation_code` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `organization_id` bigint DEFAULT NULL COMMENT '조직 정보 식별키',
  `department_id` bigint DEFAULT NULL,
  `one_depth_id` bigint DEFAULT NULL,
  `two_depth_id` bigint DEFAULT NULL,
  `three_depth_id` bigint DEFAULT NULL,
  `ga_org_code` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '고객사의 조직 코드',
  `ga_role_code` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '고객사의 권한 코드',
  `self_introduction` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '설계사 자기소개',
  `is_notification` tinyint NOT NULL DEFAULT '1' COMMENT '알림 설정  on / off 여부. on : true',
  `profile_image_path` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '설계사 프로필 사진 경로 ("폴더명"/"이미지명.확장자")',
  `profile_image_original_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '유저가 업로드했던 파일의 원래 이름',
  `google_secret_key` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '구글 OTP 인증시 필요한 key',
  `blog_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '블로그 주소',
  `youtube_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '유튜브 주소',
  `instagram_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '인스타그램 주소',
  `car_direct_link1` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'AZ 설계사의 자동차 다이렉트 URL 1',
  `car_direct_link2` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'AZ 설계사의 자동차 다이렉트 URL 1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by_id` int NOT NULL DEFAULT '1' COMMENT '이 계정을 생성한 account 아이디',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by_id` int NOT NULL DEFAULT '1' COMMENT '이 계정을 수정한 account id',
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by_id` int DEFAULT NULL COMMENT '이 계정을 삭제한 account id',
  `pin` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `pin_changed_at` datetime DEFAULT NULL,
  `pin_fail_count` int DEFAULT NULL,
  `join_date` date DEFAULT NULL COMMENT 'AZ 설계사의 입사 일자',
  `exit_date` date DEFAULT NULL COMMENT 'AZ 설계사의 퇴사 일자',
  `branch_id` bigint DEFAULT NULL COMMENT '소속 지점 식별자',
  `team_id` bigint DEFAULT NULL COMMENT '소속 팀 식별자',
  `is_pause` tinyint(1) NOT NULL DEFAULT '0' COMMENT '계정 활성화 여부',
  `paused_at` datetime DEFAULT NULL COMMENT '활동 중지 처리한 시간',
  `paused_by_id` bigint DEFAULT NULL COMMENT '활동 중지 처리한 planner id',
  `last_login_at_planner` datetime DEFAULT NULL COMMENT '보맵플래너 마지막 사이트 접속일시',
  `last_login_at_padmin` datetime DEFAULT NULL COMMENT '보맵플래너 어드민 사이트 마지막 접속일시',
  `is_first_login` tinyint NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `w_planner_login_id_uindex` (`login_id`),
  UNIQUE KEY `w_planner_mobile_uindex` (`mobile`),
  UNIQUE KEY `w_planner_referral_code_uk` (`referral_code`),
  KEY `w_planner_corporation_code_index` (`corporation_code`),
  KEY `w_planner_organization_id_deleted_at_idx` (`organization_id`,`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='플래너 PC, 앱 사용하는 설계사&팀매니저 + 플래너 관리자 페이지에 접속하는 GA 관리자, 보맵 관리자(admin) 계정 테이블';

CREATE TABLE IF NOT EXISTS `planner_insurance_premium` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `planner_id` bigint NOT NULL,
  `branch_id` bigint DEFAULT NULL COMMENT '회사관리자는 null 가능',
  `team_id` bigint DEFAULT NULL COMMENT '회사관리자는 null 가능',
  `one_depth_id` bigint DEFAULT NULL,
  `two_depth_id` bigint DEFAULT NULL,
  `organization_id` bigint DEFAULT NULL,
  `daily_amount` bigint DEFAULT NULL COMMENT '설계사의 당일 보험료 합계',
  `reflection_date` varchar(10) DEFAULT NULL COMMENT '실적 반영 일자(yyyyMMdd)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `w_planner_insurance_premium_unique` (`planner_id`,`reflection_date`),
  KEY `w_planner_insurance_premium_reflection_date` (`reflection_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `planner_main_force_product` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `planner_id` bigint NOT NULL,
  `main_force_product` varchar(255) NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `w_planner_main_force_product_planner_id_index` (`planner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `planner_member` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `planner_id` bigint DEFAULT NULL,
  `member_id` bigint DEFAULT NULL,
  `inflow_type` varchar(10) DEFAULT NULL,
  `inflow_channel` char(1) NOT NULL DEFAULT 'N' COMMENT '웹 : W, 앱 : A, 미수집 데이터 : N',
  `inflow_tag` varchar(256) NOT NULL DEFAULT 'none',
  `corporation_code` varchar(64) NOT NULL DEFAULT 'az',
  `department_id` bigint DEFAULT NULL,
  `contact_type` varchar(10) DEFAULT 'TEL',
  `is_bookmark` tinyint NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  `member_deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `w_planner_member_pk` (`member_id`,`created_at`),
  KEY `w_planner_member_corporation_code_index` (`corporation_code`),
  KEY `idx_wpm_planner_deleted` (`planner_id`,`deleted_at`),
  KEY `idx_wpm_member_planner_deleted` (`member_id`,`planner_id`,`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `policy_agree` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `policy_code` varchar(255) NOT NULL COMMENT '약관 테이블 id',
  `policy_version` varchar(255) NOT NULL COMMENT '약관 버전',
  `corporation_code` varchar(255) NOT NULL COMMENT '동의 대상 보험회사 id',
  `member_id` bigint NOT NULL,
  `expire_at` datetime NOT NULL COMMENT '동의 유효 만료일',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `w_policy_agree_member_id_index` (`member_id`),
  KEY `w_policy_agree_policy_code_index` (`policy_code`),
  KEY `w_policy_agree_policy_version_index` (`policy_version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='플래너 사용에 필요한 약관 동의 정보 테이블';

CREATE TABLE IF NOT EXISTS `role_corp` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `corporation_code` varchar(32) DEFAULT NULL,
  `ga_corp_code` varchar(64) NOT NULL,
  `ga_corp_name` varchar(64) NOT NULL,
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='고객사에서 관리하는 권한 저장(since 25.01)';

CREATE TABLE IF NOT EXISTS `role_mapping` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `role_planner_id` bigint NOT NULL,
  `role_corp_id` bigint NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='보맵과 고객사의 권한 정보 맵핑(since 25.01)';

CREATE TABLE IF NOT EXISTS `role_planner` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `planner_role` varchar(32) NOT NULL COMMENT '권한 (BOMAPP_ADMIN : 보맵 관리자, CORP_ADMIN : GA 관리자, CORP_HEAD : GA 소속장, CORP_CONSULTANT : GA 설계사)',
  `planner_level` int DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='보맵에서 관리하는 권한 저장(since 25.01)';

CREATE TABLE IF NOT EXISTS `user_action_log` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint DEFAULT NULL COMMENT '행위자',
  `ip_address` varchar(50) NOT NULL COMMENT 'IP 주소',
  `action_name` varchar(50) NOT NULL COMMENT '행위',
  `data` varchar(500) NOT NULL COMMENT '행위 내용',
  `logged_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '행위 일시',
  PRIMARY KEY (`id`),
  KEY `w_user_action_log_user_id_index` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE DATABASE IF NOT EXISTS `messaging` DEFAULT CHARACTER SET utf8mb4;
USE `messaging`;
CREATE TABLE IF NOT EXISTS `alimtalk_message_queue` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '기본 키 ID',
  `priority` bigint NOT NULL COMMENT '알림톡 발송 우선순위 (낮을수록 먼저 발송)',
  `template_code` varchar(255) NOT NULL COMMENT '알림톡 템플릿 코드',
  `is_sent` tinyint(1) NOT NULL COMMENT '발송 여부 (true: 발송됨, false: 미발송)',
  `message` text COMMENT '발송할 알림톡 메시지 내용 ',
  `alimtalk_message_setting_id` bigint DEFAULT NULL COMMENT 'alimtalk_message_setting 테이블의 ID',
  `member_id` bigint NOT NULL COMMENT '알림 대상 회원 ID',
  `is_last_recipient` tinyint(1) DEFAULT '0' COMMENT '마지막 발송 대상 여부 (true 시 반복 발송 방지)',
  `created_at` datetime(6) NOT NULL COMMENT '레코드 생성 시각',
  `updated_at` datetime(6) NOT NULL COMMENT '레코드 수정 시각',
  PRIMARY KEY (`id`),
  KEY `idx_sent_priority` (`is_sent`,`priority`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='알림톡 발송 큐 테이블';

CREATE TABLE IF NOT EXISTS `alimtalk_message_setting` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `template_code` varchar(100) NOT NULL COMMENT '알림톡 템플릿 코드',
  `send_date` datetime NOT NULL COMMENT '알림톡 발송 예정 날짜',
  `is_completed` tinyint NOT NULL DEFAULT '0' COMMENT '알림톡 발송 여부',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `send_condition_id` bigint NOT NULL,
  `completed_at` datetime DEFAULT NULL COMMENT '알림톡 발송 완료 날짜',
  `next_recipient_id` bigint DEFAULT NULL,
  `is_start_cycle_point` tinyint(1) NOT NULL DEFAULT '0',
  `segment_id` bigint DEFAULT NULL COMMENT '연결 세그먼트 ID (audience_segment.id, NULL=세그먼트 미사용)',
  `segment_revision` int DEFAULT NULL COMMENT '연결 세그먼트 리비전 (추출 시점 스냅샷 고정용)',
  `canceled_at` datetime DEFAULT NULL COMMENT '알림톡 세그먼트 캠페인 취소 시각',
  `canceled_by` varchar(64) DEFAULT NULL COMMENT '알림톡 세그먼트 캠페인 취소 요청자',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='알림톡 템플릿&날짜별 발송 메세지 세팅';

CREATE TABLE IF NOT EXISTS `alimtalk_recipient` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL COMMENT '알림톡 보낸 고객 아이디',
  `setting_id` bigint NOT NULL COMMENT '알림톡 메세지 셋팅 아이디',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `alimtalk_duplicate_check_member_id_setting_id_uindex` (`member_id`,`setting_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `alimtalk_recipient_extraction_job` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `alimtalk_type` varchar(64) DEFAULT NULL COMMENT '알림톡 타입 (KakaoAlimtalkType, 세그먼트 기반 발송 시 NULL 가능)',
  `mode` varchar(16) NOT NULL COMMENT '실행 모드: FULL(실제 모수 저장) | DRY_RUN(저장 없이 단계별 카운트만)',
  `candidate_limit` int DEFAULT NULL COMMENT 'DRY_RUN 모드의 candidate 처리 상한. FULL 은 NULL.',
  `status` varchar(16) NOT NULL COMMENT '상태: PENDING → RUNNING → COMPLETED 또는 FAILED',
  `saved_count` int DEFAULT NULL COMMENT 'COMPLETED 시 저장된 수신자 수 (FULL: alimtalk_recipient row 수, DRY_RUN: afterId 통과 수)',
  `error_count` int DEFAULT NULL COMMENT 'COMPLETED 시 회원 단위 예외로 스킵된 수 (NPE/Hikari timeout 등)',
  `first_error` varchar(1024) DEFAULT NULL COMMENT '디버깅용 첫 에러 샘플 (클래스명 + 메시지 + 첫 stack frame)',
  `result_setting_id` bigint DEFAULT NULL COMMENT 'FULL 모드 완료 시 생성된 alimtalk_message_setting.id (DRY_RUN 은 NULL)',
  `requested_by` varchar(64) DEFAULT NULL COMMENT '트리거 호출자 식별자 (admin auth 도입 시 운영자 ID 기록)',
  `created_at` datetime NOT NULL COMMENT 'job enqueue 시각 (PENDING 진입)',
  `started_at` datetime DEFAULT NULL COMMENT '워커가 claim 후 RUNNING 으로 마킹한 시각',
  `completed_at` datetime DEFAULT NULL COMMENT 'COMPLETED 또는 FAILED 로 종료된 시각',
  `segment_id` bigint DEFAULT NULL COMMENT '세그먼트 기반 발송 시 audience_segment.id',
  `segment_revision` int DEFAULT NULL COMMENT '추출 시점 세그먼트 리비전',
  `result_detail` json DEFAULT NULL COMMENT 'dry-run/full 결과 상세 (SegmentDryRunResult JSON)',
  PRIMARY KEY (`id`),
  KEY `idx_status_created` (`status`,`created_at`) COMMENT '워커가 PENDING 작업 1건을 SKIP LOCKED 로 fetch 하기 위한 보조 인덱스'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='모수(수신자) 추출 작업 큐. recipient-extractor 워커가 PENDING 작업을 claim → 처리 → 결과 마킹.';

CREATE TABLE IF NOT EXISTS `alimtalk_send_condition` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `insurance_guarantee_code` varchar(100) NOT NULL COMMENT '보장 코드',
  `base` varchar(20) NOT NULL COMMENT '알림톡 발송 기준 - 또래금액, 권장금액',
  `guarantee_status` varchar(10) NOT NULL COMMENT '알림톡 발송 기준 - 금액 충분/부족',
  `percent` int NOT NULL COMMENT '알림톡 발송 기준 - 기준 금액의 몇 퍼센트 초과/부족',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='알림톡 대상자 추출 조건값 세팅';

CREATE TABLE IF NOT EXISTS `log_notification_alimtalk` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL COMMENT '고객 식별키',
  `setting_id` bigint DEFAULT NULL COMMENT '알림톡 대량발송 시 사용된 alimtalk_message_setting 테이블 식별키\n대량발송이 아닐 경우 null',
  `template_code` varchar(100) CHARACTER SET utf8mb3 NOT NULL COMMENT '알림톡 템플릿 코드',
  `content` varchar(1000) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '알림톡 발송 내용',
  `send_at` datetime NOT NULL COMMENT '알림톡 발송 요청 일시',
  `response_id` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '인포뱅크 응답값 - 식별키',
  `response_enc_tel` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '인포뱅크 응답값 - 발송한 고객 번호(암호화)',
  `response_code` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '인포뱅크 응답값 - 상태코드',
  `response_message` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '인포뱅크 응답값 - 상태명',
  `vendor_msg_key` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '벤더 발송 키 (Bizgo msgKey / legacy messageId)',
  `send_ref` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '내부 발송 상관키 (Bizgo ref 전파, M5 콜백 매칭용)',
  `kakao_code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '카카오 발송 결과 코드',
  `kakao_error_message` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '카카오 에러 내용',
  `kakao_report_at` datetime DEFAULT NULL COMMENT '카카오 리포트 수신 시간 (yyyy-MM-dd HH:mm:ss)',
  `kakao_brandtalk_type` varchar(2) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '카카오 브랜드톡 타입. 상세내용은 API문서 참조(F: 친구톡 UI, N:브랜드톡 UI / 브랜드 톡 발송 결과에만 포함)',
  `kakao_ref` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '카카오 수신 참조값. 상세내용은 API문서 참조',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `log_notification_alimtalk_response_id_index` (`response_id`),
  KEY `log_notification_alimtalk_member_id_template_code` (`member_id`,`template_code`),
  KEY `idx_lna_setting_id` (`setting_id`),
  KEY `idx_lna_member_template_sendat` (`member_id`,`template_code`,`send_at`),
  KEY `idx_log_notification_alimtalk_vendor_msg_key` (`vendor_msg_key`),
  KEY `idx_log_notification_alimtalk_send_ref` (`send_ref`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `notification` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '푸시 제목',
  `message` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '푸시 내용',
  `is_check` tinyint NOT NULL DEFAULT '0' COMMENT '푸시 확인 여부',
  `link` varchar(255) CHARACTER SET utf8mb3 DEFAULT NULL COMMENT '콘텐츠 카드 클릭 시 이동될 페이지의 링크',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `notification_message_setting` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '푸시 제목',
  `message` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '푸시 내용',
  `link` varchar(255) DEFAULT NULL COMMENT '콘텐츠 카드 클릭 시 이동될 페이지의 링크',
  `my_data_linkage_condition` varchar(1) DEFAULT NULL COMMENT '대상자 추가 조건, 마이데이터 연동_A(상관없이 전체)/L(연동)/N(미연동)',
  `is_completed` tinyint NOT NULL DEFAULT '0' COMMENT '푸시 발송 여부',
  `send_date` datetime NOT NULL COMMENT '푸시 발송 에정 날짜',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `notification_recipient` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` varchar(255) NOT NULL,
  `setting_id` varchar(255) NOT NULL COMMENT 'notification message setting id',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE DATABASE IF NOT EXISTS `bomapp` DEFAULT CHARACTER SET utf8mb4;
USE `bomapp`;
CREATE TABLE IF NOT EXISTS `analysis_survey` (
  `mb_uid` bigint NOT NULL COMMENT '고객 인덱스',
  `annual_salary` int NOT NULL DEFAULT '0' COMMENT '연봉',
  `is_spouse` tinyint(1) NOT NULL DEFAULT '0' COMMENT '배우자 유무 true 있음 / false 없음',
  `location_city` varchar(255) DEFAULT NULL COMMENT '시/도',
  `location_district` varchar(255) DEFAULT '' COMMENT '시/군/구',
  `is_fetus` tinyint(1) NOT NULL DEFAULT '0' COMMENT '태아유무 true 있음 / false 없음',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `residence` varchar(1) DEFAULT NULL COMMENT '주거형태 S- 자가, R- 전, 월세, F- 무상',
  `is_driving` tinyint(1) DEFAULT NULL COMMENT '운전 유무 true- 있음, false- 없음',
  `spouse_salary_type` char(1) DEFAULT 'N' COMMENT '배우자 소득 여부 Y 있음 / N 없음 / U 알수 없음',
  `spouse_annual_salary` int NOT NULL DEFAULT '0' COMMENT '배우자연봉',
  PRIMARY KEY (`mb_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='보장분석 설문정보';

CREATE TABLE IF NOT EXISTS `analysis_survey_children` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `mb_uid` bigint NOT NULL,
  `birth_year` varchar(4) NOT NULL COMMENT '생일 년',
  `birth_month` varchar(2) NOT NULL COMMENT '생일 월',
  `birth_day` varchar(2) NOT NULL COMMENT '생일 일',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`uid`),
  KEY `analysis_survey_children_analysis_survey_mb_uid_fk` (`mb_uid`),
  CONSTRAINT `analysis_survey_children_analysis_survey_mb_uid_fk` FOREIGN KEY (`mb_uid`) REFERENCES `analysis_survey` (`mb_uid`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='보장분석 설문 자녀 정보';

CREATE TABLE IF NOT EXISTS `biological_age` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `member_id` bigint NOT NULL COMMENT '회원 ID',
  `checkup_date` varchar(10) NOT NULL COMMENT '건강검진 날짜',
  `age` varchar(10) DEFAULT NULL COMMENT '건강검진 당시 주민등록나이',
  `total_age` varchar(10) DEFAULT NULL COMMENT '종합 생체 나이',
  `total_guide` varchar(2048) DEFAULT NULL COMMENT '종합 가이드',
  `aging_speed` varchar(10) DEFAULT NULL COMMENT '노화 속도',
  `aging_rank` varchar(10) DEFAULT NULL COMMENT '노화 등수',
  `pancreas_age` varchar(10) DEFAULT NULL COMMENT '췌장 나이',
  `kidney_age` varchar(10) DEFAULT NULL COMMENT '신장 나이',
  `lung_age` varchar(10) DEFAULT NULL COMMENT '폐 나이',
  `liver_age` varchar(10) DEFAULT NULL COMMENT '간 나이',
  `heart_age` varchar(10) DEFAULT NULL COMMENT '심장 나이',
  `obesity_body_age` varchar(10) DEFAULT NULL COMMENT '비만 체형 나이',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제된 날짜',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '생성된 날짜',
  `sas_session_id` varchar(53) DEFAULT NULL COMMENT 'SAS 세션 ID',
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정된 날짜',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='생체 나이';

CREATE TABLE IF NOT EXISTS `biomarker` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `member_id` bigint NOT NULL COMMENT '회원 ID',
  `checkup_date` varchar(10) NOT NULL COMMENT '건강검진 날짜',
  `bio_age` varchar(10) DEFAULT NULL COMMENT '바이오마커 나이 분석값',
  `unit` varchar(10) DEFAULT NULL COMMENT '단위',
  `value` varchar(10) DEFAULT NULL COMMENT '실제 값',
  `code` varchar(10) DEFAULT NULL COMMENT '바이오마커 구분 코드',
  `name_kr` varchar(50) DEFAULT NULL COMMENT '바이오마커 명 (한글)',
  `grade` varchar(16) DEFAULT NULL COMMENT '등급(한글)',
  `name_en` varchar(20) DEFAULT NULL COMMENT '바이오마커 명 (영어)',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제된 날짜',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '생성된 날짜',
  `sas_session_id` varchar(53) DEFAULT NULL COMMENT 'SAS 세션 ID',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='바이오마커';

CREATE TABLE IF NOT EXISTS `cancer_analysis_summary` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `member_id` bigint NOT NULL COMMENT '회원 ID',
  `checkup_date` varchar(10) NOT NULL COMMENT '건강검진 날짜',
  `grade` int DEFAULT NULL COMMENT '암 종합 등급',
  `aging_rank` double DEFAULT NULL COMMENT '노화 등급',
  `aging_speed` double DEFAULT NULL COMMENT '노화 속도',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제된 날짜',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '생성된 날짜',
  `sas_session_id` varchar(53) DEFAULT NULL COMMENT 'SAS 세션 ID',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='암 분석 요약';

CREATE TABLE IF NOT EXISTS `cancer_rate_prediction` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `member_id` bigint NOT NULL COMMENT '회원 ID',
  `checkup_date` varchar(10) NOT NULL COMMENT '건강검진 날짜',
  `gender` varchar(10) DEFAULT NULL COMMENT '성별',
  `age_start` varchar(10) DEFAULT NULL COMMENT '연령 시작 구간',
  `age_end` varchar(10) DEFAULT NULL COMMENT '연령 종료 구간',
  `cancer_name` varchar(50) DEFAULT NULL COMMENT '암 명 (한글)',
  `cancer_code` varchar(50) DEFAULT NULL COMMENT '암 코드',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제된 날짜',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '생성된 날짜',
  `sas_session_id` varchar(53) DEFAULT NULL COMMENT 'SAS 세션 ID',
  `value` varchar(10) DEFAULT NULL COMMENT '값',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='암 발생률 예측 공통 데이터';

CREATE TABLE IF NOT EXISTS `cancer_risk_prediction` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `member_id` bigint NOT NULL COMMENT '회원 ID',
  `checkup_date` varchar(10) NOT NULL COMMENT '건강검진 날짜',
  `value` double DEFAULT NULL COMMENT '암 상대 위험도 발병률',
  `value_description` varchar(150) DEFAULT NULL COMMENT '암 상대 위험도 발병률 설명',
  `name` varchar(20) DEFAULT NULL COMMENT '암 명',
  `code` varchar(10) DEFAULT NULL COMMENT '암 코드',
  `grade` varchar(10) DEFAULT NULL COMMENT '등급 명 (양호, 주의, 경고, 위험, 고위험)',
  `grade_code` varchar(10) DEFAULT NULL COMMENT '등급 코드',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제된 날짜',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '생성된 날짜',
  `sas_session_id` varchar(53) DEFAULT NULL COMMENT 'SAS 세션 ID',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='암 발생 위험도 예측';

CREATE TABLE IF NOT EXISTS `car_info` (
  `mb_uid` bigint NOT NULL,
  `cc_uid` bigint NOT NULL,
  `car_id` varchar(50) DEFAULT NULL,
  `color` varchar(20) DEFAULT NULL,
  `displacement` varchar(10) DEFAULT NULL,
  `fuel_type` varchar(20) DEFAULT NULL,
  `grade` varchar(128) DEFAULT NULL,
  `manufacturer` varchar(10) DEFAULT NULL,
  `model` varchar(50) DEFAULT NULL,
  `name` varchar(64) DEFAULT NULL,
  `new_price` varchar(50) DEFAULT NULL,
  `number` varchar(20) DEFAULT NULL,
  `options` text,
  `picture_url` varchar(256) DEFAULT NULL,
  `product_year` varchar(4) DEFAULT NULL,
  `registered_year_month` varchar(20) DEFAULT NULL,
  `standard_mileage` varchar(128) DEFAULT NULL,
  `status` varchar(1) DEFAULT NULL,
  `sub_model` varchar(50) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `version_fetch_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`mb_uid`,`cc_uid`),
  KEY `car_info_index_mb_uid_cc_uid_number` (`mb_uid`,`cc_uid`,`number`),
  KEY `car_info_index_number` (`number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `contract_car` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `acid` varchar(40) DEFAULT NULL,
  `address` varchar(128) DEFAULT NULL,
  `car_name` varchar(64) DEFAULT NULL,
  `car_number` varchar(20) DEFAULT NULL,
  `car_price` varchar(15) DEFAULT NULL,
  `car_year_model` varchar(10) DEFAULT NULL,
  `cell_phone` varchar(20) DEFAULT NULL,
  `code` varchar(3) DEFAULT NULL,
  `contract_date_end` varchar(10) DEFAULT NULL,
  `contract_date_start` varchar(10) DEFAULT NULL,
  `contract_person` varchar(64) DEFAULT NULL,
  `contract_state` varchar(20) DEFAULT NULL,
  `contractor` varchar(60) DEFAULT NULL,
  `contractor_regno_resident` varchar(20) DEFAULT NULL,
  `driver_age_restrict` varchar(20) DEFAULT NULL,
  `driver_state_restrict` varchar(20) DEFAULT NULL,
  `full_text_car_number` varchar(20) DEFAULT NULL,
  `home_phone` varchar(20) DEFAULT NULL,
  `insurance_name` varchar(128) DEFAULT NULL,
  `insurance_no` varchar(50) DEFAULT NULL,
  `insurance_term` varchar(20) DEFAULT NULL,
  `insured` varchar(60) DEFAULT NULL,
  `insured_regno_resident` varchar(20) DEFAULT NULL,
  `is_show` varchar(1) NOT NULL,
  `mb_uid` bigint DEFAULT NULL,
  `name` varchar(64) DEFAULT NULL,
  `payment_amount` varchar(15) DEFAULT NULL,
  `physical_extra_charge` varchar(50) DEFAULT NULL,
  `result_cd` varchar(8) DEFAULT NULL,
  `result_mg` varchar(50) DEFAULT NULL,
  `type` varchar(1) DEFAULT NULL,
  `work_phone` varchar(20) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  `sent_at` datetime DEFAULT NULL,
  PRIMARY KEY (`uid`),
  KEY `contract_car_index_deleted_at_acid` (`deleted_at`,`acid`),
  KEY `contract_car_index_deleted_at_is_show_mb_uid_contract_date_end` (`deleted_at`,`is_show`,`mb_uid`,`contract_date_end`),
  KEY `contract_car_index_deleted_at_mb_uid` (`deleted_at`,`mb_uid`),
  KEY `contract_car_index_deleted_at_mb_uid_code` (`deleted_at`,`mb_uid`,`code`),
  KEY `contract_car_index_deleted_at_mb_uid_full_text_car_number` (`deleted_at`,`mb_uid`,`full_text_car_number`),
  KEY `contract_car_index_deleted_at_mb_uid_is_show` (`deleted_at`,`mb_uid`,`is_show`),
  KEY `contract_car_index_deleted_at_mb_uid_uid` (`deleted_at`,`mb_uid`,`uid`),
  KEY `contract_car_index_mbUid` (`mb_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `contract_car_guarantee` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `mb_uid` bigint DEFAULT NULL,
  `cc_uid` bigint DEFAULT NULL,
  `acid` varchar(40) DEFAULT NULL,
  `result_cd` varchar(8) DEFAULT NULL,
  `result_mg` varchar(50) DEFAULT NULL,
  `collateral_item` varchar(64) DEFAULT NULL,
  `guarantee_amount` varchar(1200) DEFAULT NULL,
  `insurance_amount` varchar(64) DEFAULT NULL,
  `type` varchar(1) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`uid`),
  KEY `FKrgdqxy2vc7jb6d9vimb1qfx1w` (`cc_uid`),
  KEY `contract_car_guarantee_index_acid` (`acid`),
  KEY `contract_car_guarantee_index_mb_uid_cc_uid` (`mb_uid`,`cc_uid`),
  CONSTRAINT `FKrgdqxy2vc7jb6d9vimb1qfx1w` FOREIGN KEY (`cc_uid`) REFERENCES `contract_car` (`uid`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `contract_credit` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `mb_uid` bigint NOT NULL,
  `code` varchar(3) DEFAULT NULL,
  `name` varchar(64) DEFAULT NULL,
  `acid` varchar(32) DEFAULT NULL,
  `insurance_name` varchar(255) DEFAULT NULL,
  `insurance_no` varchar(350) DEFAULT NULL,
  `insurance_link_no` varchar(350) DEFAULT NULL,
  `insurance_amount` varchar(15) DEFAULT NULL,
  `contract_state` varchar(30) DEFAULT NULL,
  `contract_date_begin` varchar(8) DEFAULT NULL,
  `contract_date_end` varchar(8) DEFAULT NULL,
  `contractor` varchar(128) DEFAULT NULL,
  `insured` varchar(128) DEFAULT NULL,
  `payment_means` varchar(30) DEFAULT NULL,
  `payment_term` varchar(20) DEFAULT NULL,
  `contract_type` varchar(1) DEFAULT NULL,
  `is_show` varchar(1) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`uid`),
  KEY `contract_credit_index_deletedAt_mbUid` (`deleted_at`,`mb_uid`),
  KEY `contract_credit_index_deletedAt_mbUid_contractDateEnd` (`deleted_at`,`mb_uid`,`contract_date_end`),
  KEY `contract_credit_index_deletedAt_mbUid_isShow` (`deleted_at`,`mb_uid`,`is_show`),
  KEY `contract_credit_index_deletedAt_mbUid_uid` (`deleted_at`,`mb_uid`,`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `contract_credit_item` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `mb_uid` bigint NOT NULL,
  `credit_uid` bigint NOT NULL,
  `insurance_link_no` varchar(128) DEFAULT NULL COMMENT '증권연계번호(실제 증권번호)',
  `insurance_item_amount` varchar(256) DEFAULT NULL,
  `insurance_item_type` varchar(256) DEFAULT NULL,
  `insurance_item_name` varchar(256) DEFAULT NULL,
  `payment_state` varchar(40) DEFAULT NULL,
  `payment_term_begin` varchar(40) DEFAULT NULL,
  `payment_term_end` varchar(40) DEFAULT NULL,
  `item_type` varchar(1) DEFAULT NULL COMMENT '보장 구분 ''f'' - 정액보장, ''r'' - 실손보장',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`uid`),
  KEY `contract_credit_index_deletedAt_creditUid` (`deleted_at`,`credit_uid`),
  KEY `contract_credit_index_deletedAt_mbUid` (`deleted_at`,`mb_uid`),
  KEY `contract_credit_index_deletedAt_mbUid_creditUid` (`deleted_at`,`mb_uid`,`credit_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `contract_credit_statistics` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `mb_uid` bigint DEFAULT NULL,
  `type` varchar(1) NOT NULL DEFAULT 'n' COMMENT '신정원 보장 분류 : f : 정액형, r : 실손형.',
  `title` varchar(255) DEFAULT NULL,
  `guarantee_status` varchar(255) DEFAULT NULL COMMENT '보장구분',
  `guarantee_name` varchar(255) DEFAULT NULL COMMENT '보장명칭',
  `me` int DEFAULT NULL COMMENT '본인',
  `average` int DEFAULT NULL COMMENT '평균',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`uid`),
  KEY `contract_credit_statistics_index_mbUid` (`mb_uid`),
  KEY `contract_credit_statistics_index_mbUid_type` (`mb_uid`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='신정원 실손형 보장 분석 정보';

CREATE TABLE IF NOT EXISTS `coocon_session` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '세션의 고유 ID',
  `member_id` bigint NOT NULL COMMENT '회원 ID',
  `tr_seq` varchar(7) NOT NULL COMMENT '거래 순번',
  `sas_session_id` varchar(53) NOT NULL COMMENT 'SAS 세션 ID',
  `ss_sys_no` varchar(4) NOT NULL COMMENT 'SS 서버 번호',
  `gw_sys_no` varchar(3) NOT NULL COMMENT 'api 서버 번호',
  `thread_no` varchar(2) NOT NULL COMMENT '스레드 번호',
  `lbs_no` varchar(2) NOT NULL COMMENT 'LBS 번호',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제된 날짜',
  `created_at` datetime NOT NULL COMMENT '생성된 날짜',
  `login_type` varchar(10) DEFAULT NULL COMMENT '로그인 유형 (KAKAO, NAVER)',
  `health_linkage_status` varchar(10) NOT NULL DEFAULT 'UNEXPECTED' COMMENT '건강데이터 연동 여부',
  `is_linkage_cancelled` tinyint(1) NOT NULL DEFAULT '0' COMMENT '연동 중 이탈 여부',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='쿠콘 스크래핑을 위한 세션 저장 테이블';

CREATE TABLE IF NOT EXISTS `disease_risk_prediction` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `member_id` bigint NOT NULL COMMENT '회원 ID',
  `checkup_date` varchar(10) NOT NULL COMMENT '건강검진 날짜',
  `name` varchar(20) DEFAULT NULL COMMENT '질병 명',
  `code` varchar(10) DEFAULT NULL COMMENT '질병 코드',
  `grade` varchar(10) DEFAULT NULL COMMENT '등급',
  `value` double DEFAULT NULL COMMENT '질병 발생 위험도',
  `grade_code` varchar(10) DEFAULT NULL COMMENT '등급 코드',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제된 날짜',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '생성된 날짜',
  `sas_session_id` varchar(53) DEFAULT NULL COMMENT 'SAS 세션 ID',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='질병 발병률 예측';

CREATE TABLE IF NOT EXISTS `diseases_code` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `d_code` varchar(8) NOT NULL COMMENT '질병코드',
  `d_name` varchar(800) NOT NULL COMMENT '질병명',
  PRIMARY KEY (`uid`),
  KEY `diseases_code_dCode` (`d_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='질병코드테이블';

CREATE TABLE IF NOT EXISTS `family_health_checkup` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `mb_uid` bigint NOT NULL,
  `question` varchar(20) NOT NULL COMMENT '질문내용',
  `question_key` varchar(40) NOT NULL COMMENT '질문 키값',
  `item` varchar(60) NOT NULL COMMENT '항목내용',
  `item_key` varchar(40) NOT NULL COMMENT '항목 키값',
  `risk_score` int NOT NULL DEFAULT '0' COMMENT '위험도점수',
  `target_diseases_key` varchar(40) DEFAULT NULL COMMENT '통합질병키값',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`uid`),
  KEY `family_health_checkup_index_1` (`mb_uid`,`risk_score`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `family_health_checkup_crypto` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `mb_uid` bigint NOT NULL,
  `question` varchar(20) NOT NULL COMMENT '질문내용',
  `question_key` varchar(40) NOT NULL COMMENT '질문 키값',
  `item` varchar(60) NOT NULL COMMENT '항목내용',
  `item_key` varchar(40) NOT NULL COMMENT '항목 키값',
  `risk_score` varchar(128) NOT NULL DEFAULT '0' COMMENT '위험도점수',
  `target_diseases_key` varchar(40) DEFAULT NULL COMMENT '통합질병키값',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`uid`),
  KEY `family_health_checkup_crypto_index_1` (`mb_uid`),
  KEY `family_health_checkup_crypto_index_2` (`mb_uid`,`risk_score`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `family_health_survey` (
  `mb_uid` bigint NOT NULL COMMENT '고객 UID',
  `diseases_code` varchar(3) NOT NULL COMMENT '보맵 질병 코드',
  `is_check` varchar(64) DEFAULT NULL COMMENT '암호화 필드 체크 여부 true- 체크됨 / false- 체크안됨',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`mb_uid`,`diseases_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='건강분석 가족력 설문 정보';

CREATE TABLE IF NOT EXISTS `from_age_interval_changes` (
  `mb_uid` bigint NOT NULL COMMENT '고객인덱스',
  `checkup_date` varchar(8) NOT NULL COMMENT '검진일지',
  `age` float DEFAULT NULL COMMENT '나이',
  `metabolic_age` varchar(512) DEFAULT NULL COMMENT '프롬에이지 나이',
  `obesity_age` varchar(512) DEFAULT NULL COMMENT '복부비만 나이',
  `arteriosclerosis_age` varchar(512) DEFAULT NULL COMMENT '동맥경화 나이(TG,HDL이 있는 경우만 제공)',
  `diabetic_age` varchar(512) DEFAULT NULL COMMENT '당뇨 나이',
  `hypertension_age` varchar(512) DEFAULT NULL COMMENT '고혈압 나이',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`mb_uid`,`checkup_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='프롬에이지 변화 그래프 조회';

CREATE TABLE IF NOT EXISTS `from_age_pdf` (
  `mb_uid` bigint NOT NULL COMMENT '고객인덱스',
  `checkup_date` varchar(8) NOT NULL COMMENT '검진일자',
  `pdf_path` varchar(1024) DEFAULT NULL COMMENT 'PDF 파일 경로-암호화필드',
  `pdf_status` varchar(1) NOT NULL DEFAULT 'B' COMMENT 'C: 생성완료, B: 생성전, F: 오류발생',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`mb_uid`,`checkup_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='프롬에이지 질병/암 결과지';

CREATE TABLE IF NOT EXISTS `from_age_risk_detail` (
  `mb_uid` bigint NOT NULL COMMENT '고객인덱스',
  `checkup_date` varchar(8) NOT NULL COMMENT '검진일자',
  `diseases_code` varchar(40) NOT NULL COMMENT '분석 질병 코드(프롬에이지 제공 정보)',
  `diseases_name` varchar(80) DEFAULT NULL COMMENT '분석 질병 이름(프롬에이지 제공 정보)',
  `ranking` varchar(512) DEFAULT NULL,
  `rate` varchar(512) DEFAULT NULL COMMENT '위험도 퍼센트(%)-암호화필드',
  `death_rate` varchar(512) DEFAULT NULL COMMENT '사망률-암호화필드',
  `incidence_rate` varchar(512) DEFAULT NULL COMMENT '평균 발생률(%)-암호화필드',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`mb_uid`,`checkup_date`,`diseases_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='프롬에이지 질병/암 위험도 상세';

CREATE TABLE IF NOT EXISTS `from_age_risk_incidence_rate_age` (
  `mb_uid` bigint NOT NULL COMMENT '고객인덱스',
  `checkup_date` varchar(8) NOT NULL COMMENT '검진일자',
  `diseases_code` varchar(40) NOT NULL COMMENT '분석 질병 코드(프롬에이지 제공 정보)',
  `age_code` varchar(10) NOT NULL COMMENT '분석 나이대 정보',
  `gender` varchar(1) DEFAULT NULL COMMENT '성별(M-남성, F-여성)',
  `incidence_rate` varchar(512) DEFAULT NULL COMMENT '평균 발생률(%)-암호화필드',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`mb_uid`,`checkup_date`,`diseases_code`,`age_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='프롬에이지 질병/암 위험도 연령별 발병률';

CREATE TABLE IF NOT EXISTS `from_age_risk_result` (
  `mb_uid` bigint NOT NULL COMMENT '고객인덱스',
  `checkup_date` varchar(8) NOT NULL COMMENT '검진일자',
  `age` float DEFAULT NULL COMMENT '나이',
  `metabolic_age` varchar(512) DEFAULT NULL COMMENT '프롬에이지 나이-암호화필드',
  `gender` varchar(1) DEFAULT NULL COMMENT '성별 M- 남성, F- 여성',
  `expectancy_life` varchar(512) DEFAULT NULL COMMENT '기대수명-암호화필드',
  `cancer_rank` varchar(512) DEFAULT NULL COMMENT '전체 암 (10등급) 중 본인의 등급-암호화필드',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`mb_uid`,`checkup_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='프롬에이지 질병/암 위험도 결과';

CREATE TABLE IF NOT EXISTS `gnnet_hospitals` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `enckey` varchar(256) DEFAULT NULL,
  `code` varchar(50) DEFAULT NULL,
  `bizno` varchar(16) DEFAULT NULL,
  `name` varchar(128) DEFAULT NULL,
  `type` varchar(1) DEFAULT NULL,
  `full_address` varchar(256) DEFAULT NULL,
  `certi` varchar(1) DEFAULT NULL,
  `id_type` varchar(1) DEFAULT NULL,
  `area` varchar(16) DEFAULT NULL,
  `area2` varchar(16) DEFAULT NULL,
  `x` double DEFAULT NULL,
  `y` double DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `gnnet_hospitals_code_index` (`code`),
  KEY `gnnet_hospitals_name_index` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='GNNET 병원 목록';

CREATE TABLE IF NOT EXISTS `health_checkup_analysis_pdf_crypto` (
  `mb_uid` bigint NOT NULL,
  `checkup_date` varchar(10) NOT NULL DEFAULT '',
  `analysis_type` char(1) NOT NULL DEFAULT 'b' COMMENT 'b: 의학생체나이, m: 대사증후군위험도생체나이',
  `pdf_path` varchar(512) DEFAULT NULL COMMENT 'PDF 파일 경로 - 암호화',
  `pdf_status` char(1) NOT NULL DEFAULT 'B' COMMENT 'C: 생성완료, B: 생성전, F: 오류발생',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`checkup_date`,`mb_uid`),
  KEY `health_checkup_analysis_pdf_crypto_index_1` (`mb_uid`,`checkup_date`,`analysis_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='건강검진 분석 결과 서비스 결과지 pdf';

CREATE TABLE IF NOT EXISTS `health_checkup_bio_age_analysis_guide_crypto` (
  `mb_uid` bigint NOT NULL,
  `checkup_date` varchar(10) NOT NULL DEFAULT '',
  `age` varchar(8) DEFAULT NULL COMMENT '주민등록 나이',
  `bio_age` varchar(512) DEFAULT NULL COMMENT '생체 나이 - 암호화',
  `total_guide` text COMMENT '종합 가이드 - 암호화',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`checkup_date`,`mb_uid`),
  KEY `health_checkup_bio_age_analysis_guide_crypto_index1` (`mb_uid`),
  KEY `health_checkup_bio_age_analysis_guide_crypto_index2` (`mb_uid`,`checkup_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='건강검진 의학생체나이 종합분석 및 기본가이드';

CREATE TABLE IF NOT EXISTS `health_checkup_bio_age_life_expectancy_crypto` (
  `mb_uid` bigint NOT NULL,
  `checkup_date` varchar(10) NOT NULL DEFAULT '',
  `aging_index` varchar(512) DEFAULT NULL COMMENT '노화 지수 - 암호화',
  `aging_rank` varchar(512) DEFAULT NULL COMMENT '노화 등수 - 암호화',
  `tle` varchar(512) DEFAULT NULL COMMENT '기대 수명 - 암호화',
  `tle_avg` varchar(512) DEFAULT NULL COMMENT '평균 기대수명 - 암호화',
  `caa` varchar(512) DEFAULT NULL COMMENT '심장나이 - 암호화',
  `hea` varchar(512) DEFAULT NULL COMMENT '간나이 - 암호화',
  `paa` varchar(512) DEFAULT NULL COMMENT '췌장나이 - 암호화',
  `rea` varchar(512) DEFAULT NULL COMMENT '신장나이 - 암호화',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`checkup_date`,`mb_uid`),
  KEY `health_checkup_bio_age_life_expectancy_crypto_index_1` (`mb_uid`,`checkup_date`),
  KEY `health_checkup_bio_age_life_expectancy_crypto_index_2` (`mb_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='건강검진 의학생체나이에 따른 노화지수 및 기대 수명 관리 정보';

CREATE TABLE IF NOT EXISTS `health_checkup_crypto` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `acid` varchar(64) DEFAULT NULL COMMENT '스크랩 고유값',
  `mb_uid` bigint NOT NULL,
  `checkup_date` varchar(10) NOT NULL DEFAULT '0000000000' COMMENT '검진일자',
  `checkup_institution` varchar(128) DEFAULT NULL COMMENT '검진기관명',
  `checkup_type` varchar(64) NOT NULL DEFAULT '' COMMENT '검진구분',
  `optional` text COMMENT '건강검진 소견 - 암호화',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`uid`),
  KEY `health_checkup_crypto_index_1` (`mb_uid`,`checkup_date`),
  KEY `health_checkup_crypto_index_2` (`mb_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='건강검진 정보';

CREATE TABLE IF NOT EXISTS `health_checkup_detail_crypto` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `mb_uid` bigint NOT NULL,
  `checkup_date` varchar(10) DEFAULT '0000000000' COMMENT '검진일자',
  `checkup_type` varchar(64) DEFAULT '' COMMENT '검진구분',
  `target_diseases` varchar(256) NOT NULL DEFAULT '' COMMENT '목표질환 - 암호화',
  `inspection_item` varchar(128) NOT NULL DEFAULT '' COMMENT '검사항목',
  `reference_unit` varchar(16) DEFAULT NULL COMMENT '참고치 단위',
  `checkup_value` varchar(512) NOT NULL DEFAULT '' COMMENT '검진 수치 - 암호화',
  `risk_score` int DEFAULT NULL COMMENT '검진결과 위험도 점수 0-정상 ~ 5- 위험',
  `target_diseases_key` varchar(256) DEFAULT NULL COMMENT '통합질병키값 - 암호화',
  `item_key` varchar(40) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  `reference_normal` varchar(64) DEFAULT NULL COMMENT '참고치 정상',
  `reference_caution` varchar(64) DEFAULT NULL COMMENT '참고치 주의',
  `reference_danger` varchar(64) DEFAULT NULL COMMENT '참고치 위험',
  `acid` varchar(53) NOT NULL COMMENT 'SAS 세션 ID',
  PRIMARY KEY (`uid`),
  KEY `health_checkup_detail_crypto_index_1` (`mb_uid`),
  KEY `health_checkup_detail_crypto_index_2` (`mb_uid`,`checkup_date`),
  KEY `health_checkup_detail_crypto_index_3` (`mb_uid`,`checkup_date`,`target_diseases_key`),
  KEY `health_checkup_detail_crypto_index_4` (`mb_uid`,`checkup_date`,`item_key`),
  KEY `idx_hcdc_mbuid_created_checkup_uid_acid` (`mb_uid`,`created_at`,`checkup_date`,`uid`,`acid`),
  KEY `idx_hcdc_mbuid_acid_checkup_uid` (`mb_uid`,`acid`,`checkup_date`,`uid`),
  KEY `idx_hcdc_itemkey_mbuid` (`item_key`,`mb_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='건강검진 상세 정보';

CREATE TABLE IF NOT EXISTS `health_letter` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL COMMENT '회원 ID',
  `type` varchar(20) NOT NULL COMMENT '편지 유형 (FRIEND, MOM, TRAINER, EX_LOVER, NO_CHECKUP)',
  `header` varchar(512) NOT NULL COMMENT '제목',
  `content` longtext NOT NULL COMMENT '조합된 편지 내용',
  `footer` varchar(512) NOT NULL COMMENT '하단 문구',
  `share_token` varchar(64) NOT NULL COMMENT '공유 토큰',
  `checkup_date` varchar(10) DEFAULT NULL COMMENT '검진 일자',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_share_token` (`share_token`),
  KEY `idx_member_id` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='건강 편지 발송 내역';

CREATE TABLE IF NOT EXISTS `health_letter_template` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `type` varchar(20) NOT NULL COMMENT '편지 유형',
  `code` varchar(50) NOT NULL COMMENT '템플릿 코드 (GREETING, RISK_DIABETES_HIGH 등)',
  `content` longtext NOT NULL COMMENT '템플릿 내용 ({name} 등 변수 포함)',
  `description` varchar(255) DEFAULT NULL COMMENT '설명',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_type_code` (`type`,`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='건강 편지 템플릿';

CREATE TABLE IF NOT EXISTS `ins_claim_history` (
  `claim_uid` bigint NOT NULL AUTO_INCREMENT COMMENT '청구 ID',
  `mb_uid` bigint DEFAULT NULL COMMENT '고객 ID',
  `claim_send_id` varchar(100) NOT NULL COMMENT 'Gnnet 청구 ID',
  `virtual_fax_url` varchar(255) DEFAULT NULL COMMENT '가상팩스번호 입력 URL',
  `virtual_fax_success_yn` varchar(10) DEFAULT NULL COMMENT '가상팩스번호 입력 완료 유무',
  `virtual_fax_number` varchar(200) DEFAULT NULL COMMENT '고객입력 팩스번호',
  `accident_type` varchar(10) DEFAULT NULL COMMENT '사고유형',
  `accident_reason` varchar(200) DEFAULT NULL COMMENT '사고이유',
  `receipt_type` varchar(10) DEFAULT NULL COMMENT '영수증 타입',
  `account_holder` varchar(200) DEFAULT NULL COMMENT '수익자(예금주)',
  `account_number` varchar(255) DEFAULT NULL COMMENT '계좌번호',
  `ins_comp_uid` bigint DEFAULT NULL COMMENT '보맵 보험사 코드',
  `hospital_code` varchar(100) DEFAULT NULL COMMENT '병원 코드',
  `hospital_name` varchar(50) DEFAULT NULL COMMENT '병원명',
  `bank_name` varchar(20) DEFAULT NULL COMMENT '은행명',
  `claim_success_yn` varchar(5) NOT NULL DEFAULT 'N' COMMENT '청구 완료여부',
  `receive_success_yn` varchar(5) DEFAULT NULL COMMENT '환급 완료여부',
  `claim_same_yn` varchar(200) DEFAULT NULL COMMENT '본인청구 여부',
  `img_cnt` int DEFAULT NULL COMMENT '사진개수',
  `insurer_send_status` varchar(200) DEFAULT NULL COMMENT 'GNNET->보험사 전송 상태(S:전송성공 F:전송실패 C:전송체크: Y:상태체크)',
  `accident_date` varchar(25) DEFAULT NULL COMMENT '사고 일자',
  `patient_name` varchar(200) DEFAULT NULL COMMENT '피보험자(환자) 이름',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제 시간',
  PRIMARY KEY (`claim_uid`),
  KEY `ins_claim_history_mb_uid_send_id` (`mb_uid`,`claim_send_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='청구내역';

CREATE TABLE IF NOT EXISTS `ins_claim_member_info` (
  `mb_uid` bigint NOT NULL COMMENT '고객 ID',
  `search_save_use_yn` varchar(1) NOT NULL DEFAULT 'Y' COMMENT '검색어 저장 기능 사용 여부',
  `account_number_save_use_yn` varchar(35) NOT NULL DEFAULT 'N' COMMENT '계좌번호 저장여부',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`mb_uid`),
  KEY `ins_claim_member_info_mb_uid` (`mb_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='청구이용 고객 관리정보';

CREATE TABLE IF NOT EXISTS `ins_comp` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `title` varchar(64) DEFAULT NULL,
  `code` varchar(3) DEFAULT NULL,
  `call_no` varchar(16) DEFAULT NULL,
  `car_ins` varchar(1) DEFAULT NULL,
  `url` varchar(255) DEFAULT NULL,
  `fax` varchar(1) DEFAULT NULL,
  `fax_no` varchar(16) DEFAULT NULL,
  `basic_ins` varchar(1) DEFAULT NULL,
  `smart` varchar(1) DEFAULT NULL,
  `scrap` varchar(1) DEFAULT NULL,
  `comp_type` varchar(1) DEFAULT NULL,
  `cert` varchar(1) DEFAULT NULL,
  `cert_module` varchar(16) DEFAULT NULL,
  `color_set` varchar(16) DEFAULT NULL,
  `smart_module` varchar(16) DEFAULT NULL,
  `is_insured` varchar(1) DEFAULT NULL,
  `direct_ins` varchar(1) DEFAULT NULL,
  `direct_module` varchar(16) DEFAULT NULL,
  `label` varchar(64) DEFAULT NULL,
  `order_idx` varchar(3) DEFAULT NULL,
  `api_0207` char(1) NOT NULL,
  `api_0208` char(1) NOT NULL,
  `api_0209` char(1) NOT NULL,
  `api_0210` char(1) NOT NULL,
  `api_0211` char(1) NOT NULL,
  `api_0212` char(1) NOT NULL,
  `comp_check` varchar(1) DEFAULT NULL,
  `check_end_date` datetime DEFAULT NULL,
  `check_start_date` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `logo_url` varchar(512) DEFAULT NULL COMMENT '보험사 다이렉트로고 url',
  `direct_logo_url` varchar(512) DEFAULT NULL COMMENT '보험사 다이렉트로고 url',
  `short_insurance_name` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`uid`),
  KEY `ins_comp_index_code` (`code`),
  KEY `ins_comp_index_code_fax` (`code`,`fax`),
  KEY `ins_comp_index_direct_ins_direct_module` (`direct_ins`,`direct_module`),
  KEY `ins_comp_index_direct_module` (`direct_module`),
  KEY `ins_comp_index_scrap` (`scrap`),
  KEY `ins_comp_index_scrap_check_start_date_check_end_date` (`scrap`,`check_start_date`,`check_end_date`),
  KEY `ins_comp_index_smart` (`smart`),
  KEY `ins_comp_index_smart_module` (`smart_module`),
  KEY `ins_comp_index_title` (`title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `insurance_guarantee` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL DEFAULT '0',
  `org_code` varchar(10) DEFAULT NULL COMMENT '기관 코드',
  `insurance_id` bigint DEFAULT NULL COMMENT 'my_data_insurance table id',
  `insured_id` bigint DEFAULT NULL COMMENT '보험 물/일반, 계피동일, 계피상이에 따라 my_data_xxx_xxx_insured 테이블을 각기 참조하여야 함',
  `search_age` int DEFAULT NULL COMMENT '조회 보험 나이',
  `search_age_date` varchar(8) DEFAULT NULL COMMENT '조회 보험 나이 일자',
  `code` varchar(20) DEFAULT NULL COMMENT '보장 코드',
  `name` varchar(256) DEFAULT NULL COMMENT '보장 명',
  `contents` varchar(512) DEFAULT NULL COMMENT '보장 내용',
  `amount` bigint DEFAULT NULL COMMENT '보장 금액',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `insurance_guarantee_u_index_case1` (`insurance_id`,`insured_id`,`code`,`search_age`),
  KEY `insurance_guarantee_index_case1` (`member_id`),
  KEY `insurance_guarantee_index_case2` (`insurance_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='마이데이터 보험 보장 정보';

CREATE TABLE IF NOT EXISTS `insurance_guarantee_contract` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL,
  `insurance_id` bigint NOT NULL,
  `contract_id` bigint DEFAULT NULL,
  `code` varchar(20) DEFAULT NULL,
  `amount` bigint NOT NULL DEFAULT '0' COMMENT '보장 금액',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `insurance_guarantee_contract_insurance_id_contract_id_index` (`insurance_id`,`contract_id`),
  KEY `insurance_guarantee_contract_contract_id_index` (`contract_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `insurance_guarantee_request` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL COMMENT '고객 id',
  `status_code` varchar(1) NOT NULL DEFAULT 'I' COMMENT '요청 상태 I- 요청, F- 실패, S- 성공',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  UNIQUE KEY `member_id` (`member_id`),
  KEY `insurance_guarantee_request_index_case1` (`member_id`),
  KEY `insurance_guarantee_request_index_case2` (`status_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='보험 보장 정보 요청 정보';

CREATE TABLE IF NOT EXISTS `insurance_guarantee_request_queue` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint DEFAULT NULL COMMENT '고객 id',
  `request_id` bigint DEFAULT NULL COMMENT 'insurance_guarantee_request table id',
  `insurance_id` bigint DEFAULT NULL COMMENT 'my_data_insurance table id',
  `insured_id` bigint DEFAULT NULL COMMENT 'my_data_insurance_insured table id',
  `status_code` varchar(1) NOT NULL DEFAULT 'I' COMMENT '요청 상태 I- 요청, F- 실패, S- 성공',
  `result_log_id` bigint DEFAULT NULL COMMENT 'log_insurance_guarantee_request table id',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수정일',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일',
  PRIMARY KEY (`id`),
  KEY `request_id` (`request_id`),
  KEY `insurance_guarantee_request_queue_member_id_index` (`member_id`),
  CONSTRAINT `insurance_guarantee_request_queue_ibfk_1` FOREIGN KEY (`request_id`) REFERENCES `insurance_guarantee_request` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='보험 보장 정보 요청 큐 정보';

CREATE TABLE IF NOT EXISTS `insurer_inspection_time` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `gnnet_insurer_code` varchar(32) NOT NULL COMMENT '지앤넷 보험사 코드',
  `insurer_name` varchar(128) NOT NULL COMMENT '보험사 명',
  `inspect_type` char(1) NOT NULL COMMENT '점검 상태 (A: all, D: data, I: image)',
  `start_time` datetime NOT NULL COMMENT '점검 시작 시간',
  `end_time` datetime NOT NULL COMMENT '점검 종료 시간',
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_insurer_inspection_code` (`gnnet_insurer_code`),
  KEY `idx_insurer_inspection_period` (`start_time`,`end_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='보험사 청구 점검시간';

CREATE TABLE IF NOT EXISTS `log_agreement_health` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `mb_uid` bigint DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `tel_mobile` varchar(255) DEFAULT NULL,
  `policy_code` char(2) NOT NULL DEFAULT '00' COMMENT '약관 구분 코드',
  `policy_version` varchar(16) NOT NULL DEFAULT '' COMMENT '동의 시점 약관 버전 정보',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`uid`),
  KEY `log_agreement_health_mb_uid_created_at_updated_at` (`mb_uid`,`created_at`,`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='건강분석 약관 동의 로그';

CREATE TABLE IF NOT EXISTS `log_coocon` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `member_id` bigint NOT NULL COMMENT '회원 ID',
  `type` varchar(20) NOT NULL COMMENT '로그 타입 (간편인증, 로그아웃)',
  `result_status` varchar(10) NOT NULL COMMENT '성공 여부 (성공: 00000000)',
  `error_message` text COMMENT '에러 메시지',
  `login_type` varchar(8) NOT NULL COMMENT '로그인 유형 (KAKAO, NAVER)',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제된 날짜',
  `created_at` datetime NOT NULL COMMENT '로그 생성 날짜',
  `result_message` text COMMENT '결과 메시지',
  `error_code` varchar(20) DEFAULT NULL COMMENT '에러 코드',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='쿠콘 스크래핑 중 간편인증, 로그아웃 로그 테이블';

CREATE TABLE IF NOT EXISTS `log_from_age_analysis_result` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `mb_uid` bigint DEFAULT NULL COMMENT '고객 UID',
  `checkup_date` varchar(10) DEFAULT NULL COMMENT '건강검진 일자',
  `registered_code` varchar(1) DEFAULT NULL COMMENT '등록결과코드 Y- 성공, N- 실패',
  `registered_at` datetime DEFAULT NULL COMMENT '등록요청일자',
  `interval_change_created_at` datetime DEFAULT NULL COMMENT '변화그래프 생성일자',
  `risk_result_created_at` datetime DEFAULT NULL COMMENT '질병/암 위험도 생성일자',
  `pdf_created_at` datetime DEFAULT NULL COMMENT '결과지 생성일자',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제일자',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='프롬에이지 분석 결과 로그';

CREATE TABLE IF NOT EXISTS `log_health_checkup_analysis_register` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `mb_uid` bigint NOT NULL,
  `checkup_date` varchar(10) NOT NULL DEFAULT '',
  `analysis_type` char(1) NOT NULL DEFAULT 'b' COMMENT 'b: 의학생체나이, m: 대사증후군위험도생체나이',
  `response_code` int DEFAULT NULL COMMENT '서버응답코드',
  `result_cd` varchar(20) DEFAULT NULL COMMENT '응답코드(Y: 성공, N:실패)',
  `result_mg` varchar(64) DEFAULT NULL COMMENT '응답메세지',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`uid`),
  KEY `log_health_checkup_analysis_register_index_2` (`analysis_type`,`result_cd`,`deleted_at`),
  KEY `log_health_checkup_analysis_register_index_1` (`mb_uid`,`checkup_date`,`analysis_type`,`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='건강검진 분석 요청 결과 로그';

CREATE TABLE IF NOT EXISTS `log_insurance_guarantee_request` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `identification_key` varchar(50) DEFAULT NULL COMMENT '신화 요청 식별키',
  `member_id` bigint NOT NULL DEFAULT '0',
  `org_code` varchar(10) DEFAULT NULL COMMENT '기관 코드',
  `insurance_id` bigint DEFAULT NULL COMMENT 'my_data_insurance table id',
  `insured_id` bigint DEFAULT NULL COMMENT 'my_data_insurance_insured table id',
  `result_code` varchar(4) DEFAULT NULL COMMENT '구분코드 - 200 : 정상, 900 : 오류',
  `result_message` text COMMENT '처리 결과 메시지',
  `result_detail_code` varchar(20) DEFAULT NULL COMMENT '상세구분코드',
  `result_detail_message` varchar(512) DEFAULT NULL COMMENT '상세메세지',
  `result_type` varchar(60) DEFAULT NULL COMMENT '상세구분코드명',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `log_insurance_guarantee_request_created_at_index` (`created_at`),
  KEY `log_insurance_guarantee_request_member_id_created_at_index` (`member_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='보험 보장 정보 요청 로그';

CREATE TABLE IF NOT EXISTS `log_pdf_result` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `member_id` bigint NOT NULL COMMENT '회원 ID',
  `checkup_date` varchar(10) DEFAULT NULL COMMENT '건강검진 날짜',
  `register_code` varchar(1) DEFAULT NULL COMMENT 'pdf 생성 상태코드',
  `registered_at` datetime DEFAULT NULL COMMENT '등록 요청 시간',
  `pdf_created_at` datetime DEFAULT NULL COMMENT 'pdf 생성 완료 시간',
  `error_message` varchar(30) DEFAULT NULL COMMENT '생성 실패 시 오류 메세지',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제된 날짜',
  `updated_at` datetime DEFAULT NULL COMMENT '같은 데이터로 재시도 기록용 시간',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '생성된 날짜',
  `sas_session_id` varchar(53) DEFAULT NULL COMMENT 'SAS 세션 ID',
  `pdf_url` varchar(255) DEFAULT NULL COMMENT 'PDF 파일 URL',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='PDF 생성 상태값 로그';

CREATE TABLE IF NOT EXISTS `log_scrap_health_checkup` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `mb_uid` bigint DEFAULT NULL,
  `acid` varchar(64) DEFAULT NULL,
  `api_seq` varchar(64) DEFAULT NULL,
  `module` varchar(64) DEFAULT NULL,
  `job` varchar(64) DEFAULT NULL,
  `class_name` varchar(64) DEFAULT NULL,
  `result_cd` varchar(20) DEFAULT NULL,
  `result_mg` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`uid`),
  KEY `log_scrap_health_checkup_mb_uid_acid_api_seq_created_at` (`mb_uid`,`acid`,`api_seq`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='건강검진 조회 로그';

CREATE TABLE IF NOT EXISTS `medical_data` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `member_id` bigint NOT NULL COMMENT '회원 ID',
  `checkup_date` varchar(10) NOT NULL COMMENT '건강검진 날짜',
  `year` int DEFAULT NULL COMMENT '금년, 5년, 10년',
  `cost` double DEFAULT NULL COMMENT '데이터 값',
  `code` varchar(10) DEFAULT NULL COMMENT '어떤 데이터인지 구분(의료비, 외래진료일수, 입원 일수, 연 평균 의료비, 연 평균 의료비 상승률)',
  `is_me` tinyint(1) DEFAULT NULL COMMENT '본인 진료 여부 (1: 본인, 0: 타인)',
  `deleted_at` datetime DEFAULT NULL COMMENT '삭제된 날짜',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '생성된 날짜',
  `sas_session_id` varchar(53) DEFAULT NULL COMMENT 'SAS 세션 ID',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='생체나이에 따른 의료 데이터';

CREATE TABLE IF NOT EXISTS `peer_premium_statistics` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '기본 키',
  `insurance_category` varchar(50) NOT NULL COMMENT '보험 카테고리',
  `age_group` varchar(20) NOT NULL COMMENT '연령대 그룹',
  `sum_premium` bigint NOT NULL COMMENT '해당 연령대와 카테고리의 총 보험료 합계',
  `person_count` bigint NOT NULL COMMENT '해당 그룹에 속한 사람 수 (계피동일)',
  `average_premium` bigint NOT NULL COMMENT '해당 그룹의 평균 보험료',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '레코드 생성 시각',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '레코드 수정 시각',
  `display_date` date DEFAULT NULL COMMENT '통계 표시 기준일',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='또래 보험료 통계를 저장하는 테이블';

CREATE TABLE IF NOT EXISTS `policy` (
  `version` varchar(255) NOT NULL,
  `policy_code` varchar(255) NOT NULL,
  `writer` bigint NOT NULL,
  `modifier` bigint NOT NULL,
  `is_show` bit(1) NOT NULL,
  `is_list` char(1) NOT NULL DEFAULT '0',
  `effective_period` varchar(255) DEFAULT 'm12' COMMENT '약관 유효기간 (d(일), m(개월), y(년) 단위 + 기간)',
  `policy_text` varchar(256) DEFAULT NULL,
  `policy_url` varchar(256) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`version`,`policy_code`),
  KEY `policy_index_policy_code_is_show` (`policy_code`,`is_show`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `policy_detail` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `policy_code` varchar(4) DEFAULT NULL COMMENT '약관 구분 코드',
  `policy_version` varchar(16) DEFAULT NULL COMMENT '동의 시점 약관 버전 정보',
  `is_once` tinyint DEFAULT NULL COMMENT '일회성 제공 여부',
  `revoke_info` varchar(100) DEFAULT NULL COMMENT '철회 요청시 안내 문구',
  `prov_consent_name` varchar(100) DEFAULT NULL COMMENT '동의서명(고객이 동의한 동의서명)',
  `consent_rcv_name` varchar(200) DEFAULT NULL COMMENT '제공받는자',
  `prov_consent_purpose_type` char(2) DEFAULT NULL COMMENT '제공받는자의 이용목적 구분(코드)(01:마케팅/02:부가혜택 제공/03:부가 서비스 제공/04:업무 서비스 제공/05:데이터 중계 및 판매),',
  `prov_consent_purpose` varchar(500) DEFAULT NULL COMMENT '제공받는자의 이용목적',
  `prov_consent_period` varchar(100) DEFAULT NULL COMMENT '보유 및 이용기간',
  `prov_consent_asset` varchar(2000) DEFAULT NULL COMMENT '제공항목',
  `reward` char(2) DEFAULT NULL COMMENT '지급 대가(00:대가없음,01:금전,02:정보)',
  `total_text` varchar(1000) DEFAULT NULL COMMENT '약관 전체 내용',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `policy_detail_policy_code_policy_version_index` (`policy_code`,`policy_version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='제 3자 제공동의 약관 세부 정보';

CREATE TABLE IF NOT EXISTS `popular_insurance_statistics` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '기본 키',
  `person_count` bigint NOT NULL COMMENT '해당 보험에 가입한 사람 수 ( 계피동일, 계피상이 모두 포함) ',
  `insurance_category` varchar(50) NOT NULL COMMENT '보험 카테고리',
  `age_group` varchar(20) NOT NULL COMMENT '연령대 그룹',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '레코드 생성 시각',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '레코드 수정 시각',
  `display_date` date DEFAULT NULL COMMENT '통계 표시 기준일',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='인기 보험 가입자 수를 연령대 및 카테고리별로 저장하는 테이블';

CREATE TABLE IF NOT EXISTS `product` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `product_group_id` bigint DEFAULT NULL,
  `amount` bigint DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `status` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `product_code` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `product_group_idx` (`product_group_id`),
  CONSTRAINT `fk_product_product_group_product_group_id` FOREIGN KEY (`product_group_id`) REFERENCES `product_group` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `product_group` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `scrap_report_ins` (
  `uid` bigint NOT NULL AUTO_INCREMENT,
  `mb_uid` bigint DEFAULT NULL,
  `red_uid` bigint DEFAULT NULL,
  `code` varchar(3) DEFAULT NULL,
  `acid` varchar(40) DEFAULT NULL,
  `state` varchar(1) DEFAULT NULL,
  `scrap_result_cd` varchar(8) DEFAULT NULL,
  `scrap_state` varchar(1) DEFAULT NULL,
  `seq_regi_date` datetime DEFAULT NULL,
  `report_mg` varchar(1024) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

SET FOREIGN_KEY_CHECKS=1;
