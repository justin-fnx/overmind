-- 프리로드 행수 대조: 소스(bomapp_member.old) vs 타깃(schema.new). 불일치만 출력.
-- (CDC 가동 중이라 라이브 쓰기가 있으면 소폭 차이 가능 → 곧 수렴)
SELECT * FROM (
  SELECT 'chat.ban_word' t, (SELECT COUNT(*) FROM `bomapp_member`.`ban_word`) s, (SELECT COUNT(*) FROM `chat`.`ban_word`) g
  UNION ALL
  SELECT 'chat.activation_history' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_activation_history`) s, (SELECT COUNT(*) FROM `chat`.`activation_history`) g
  UNION ALL
  SELECT 'chat.bot_block' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_bot_block`) s, (SELECT COUNT(*) FROM `chat`.`bot_block`) g
  UNION ALL
  SELECT 'chat.bot_block_button' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_bot_block_button`) s, (SELECT COUNT(*) FROM `chat`.`bot_block_button`) g
  UNION ALL
  SELECT 'chat.bot_block_image' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_bot_block_image`) s, (SELECT COUNT(*) FROM `chat`.`bot_block_image`) g
  UNION ALL
  SELECT 'chat.bot_scenario' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_bot_scenario`) s, (SELECT COUNT(*) FROM `chat`.`bot_scenario`) g
  UNION ALL
  SELECT 'chat.bot_scenario_activation_setting' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_bot_scenario_activation_setting`) s, (SELECT COUNT(*) FROM `chat`.`bot_scenario_activation_setting`) g
  UNION ALL
  SELECT 'chat.bot_scenario_deployment_history' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_bot_scenario_deployment_history`) s, (SELECT COUNT(*) FROM `chat`.`bot_scenario_deployment_history`) g
  UNION ALL
  SELECT 'chat.bot_template' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_bot_template`) s, (SELECT COUNT(*) FROM `chat`.`bot_template`) g
  UNION ALL
  SELECT 'chat.bot_template_button' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_bot_template_button`) s, (SELECT COUNT(*) FROM `chat`.`bot_template_button`) g
  UNION ALL
  SELECT 'chat.button' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_button`) s, (SELECT COUNT(*) FROM `chat`.`button`) g
  UNION ALL
  SELECT 'chat.consultation_end_message' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_consultation_end_message`) s, (SELECT COUNT(*) FROM `chat`.`consultation_end_message`) g
  UNION ALL
  SELECT 'chat.consultation_end_message_button' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_consultation_end_message_button`) s, (SELECT COUNT(*) FROM `chat`.`consultation_end_message_button`) g
  UNION ALL
  SELECT 'chat.consultation_history' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_consultation_history`) s, (SELECT COUNT(*) FROM `chat`.`consultation_history`) g
  UNION ALL
  SELECT 'chat.file' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_file`) s, (SELECT COUNT(*) FROM `chat`.`file`) g
  UNION ALL
  SELECT 'chat.global_template' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_global_template`) s, (SELECT COUNT(*) FROM `chat`.`global_template`) g
  UNION ALL
  SELECT 'chat.global_template_button' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_global_template_button`) s, (SELECT COUNT(*) FROM `chat`.`global_template_button`) g
  UNION ALL
  SELECT 'chat.image' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_image`) s, (SELECT COUNT(*) FROM `chat`.`image`) g
  UNION ALL
  SELECT 'chat.member_tag' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_member_tag`) s, (SELECT COUNT(*) FROM `chat`.`member_tag`) g
  UNION ALL
  SELECT 'chat.message' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_message`) s, (SELECT COUNT(*) FROM `chat`.`message`) g
  UNION ALL
  SELECT 'chat.message_result' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_message_result`) s, (SELECT COUNT(*) FROM `chat`.`message_result`) g
  UNION ALL
  SELECT 'chat.room' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_room`) s, (SELECT COUNT(*) FROM `chat`.`room`) g
  UNION ALL
  SELECT 'chat.room_memo' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_room_memo`) s, (SELECT COUNT(*) FROM `chat`.`room_memo`) g
  UNION ALL
  SELECT 'chat.room_requested_data_request' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_room_requested_data_request`) s, (SELECT COUNT(*) FROM `chat`.`room_requested_data_request`) g
  UNION ALL
  SELECT 'chat.status' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_status`) s, (SELECT COUNT(*) FROM `chat`.`status`) g
  UNION ALL
  SELECT 'chat.template' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_template`) s, (SELECT COUNT(*) FROM `chat`.`template`) g
  UNION ALL
  SELECT 'chat.template_button' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_template_button`) s, (SELECT COUNT(*) FROM `chat`.`template_button`) g
  UNION ALL
  SELECT 'chat.template_category' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_template_category`) s, (SELECT COUNT(*) FROM `chat`.`template_category`) g
  UNION ALL
  SELECT 'chat.template_favorite' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_template_favorite`) s, (SELECT COUNT(*) FROM `chat`.`template_favorite`) g
  UNION ALL
  SELECT 'chat.template_image' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_template_image`) s, (SELECT COUNT(*) FROM `chat`.`template_image`) g
  UNION ALL
  SELECT 'chat.view_state' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_view_state`) s, (SELECT COUNT(*) FROM `chat`.`view_state`) g
  UNION ALL
  SELECT 'chat.work_hour' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_work_hour`) s, (SELECT COUNT(*) FROM `chat`.`work_hour`) g
  UNION ALL
  SELECT 'chat.work_hour_setting' t, (SELECT COUNT(*) FROM `bomapp_member`.`chat_work_hour_setting`) s, (SELECT COUNT(*) FROM `chat`.`work_hour_setting`) g
  UNION ALL
  SELECT 'chat.deployed_bot_block' t, (SELECT COUNT(*) FROM `bomapp_member`.`deployed_chat_bot_block`) s, (SELECT COUNT(*) FROM `chat`.`deployed_bot_block`) g
  UNION ALL
  SELECT 'chat.deployed_bot_block_button' t, (SELECT COUNT(*) FROM `bomapp_member`.`deployed_chat_bot_block_button`) s, (SELECT COUNT(*) FROM `chat`.`deployed_bot_block_button`) g
  UNION ALL
  SELECT 'chat.deployed_bot_block_image' t, (SELECT COUNT(*) FROM `bomapp_member`.`deployed_chat_bot_block_image`) s, (SELECT COUNT(*) FROM `chat`.`deployed_bot_block_image`) g
  UNION ALL
  SELECT 'chat.deployed_bot_scenario' t, (SELECT COUNT(*) FROM `bomapp_member`.`deployed_chat_bot_scenario`) s, (SELECT COUNT(*) FROM `chat`.`deployed_bot_scenario`) g
  UNION ALL
  SELECT 'chat.kakao_kakaopay_member' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakao_kakaopay_member`) s, (SELECT COUNT(*) FROM `chat`.`kakao_kakaopay_member`) g
  UNION ALL
  SELECT 'chat.kakaopay_bot_template' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakaopay_chat_bot_template`) s, (SELECT COUNT(*) FROM `chat`.`kakaopay_bot_template`) g
  UNION ALL
  SELECT 'chat.kakaopay_bot_template_button' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakaopay_chat_bot_template_button`) s, (SELECT COUNT(*) FROM `chat`.`kakaopay_bot_template_button`) g
  UNION ALL
  SELECT 'chat.kakaopay_button' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakaopay_chat_button`) s, (SELECT COUNT(*) FROM `chat`.`kakaopay_button`) g
  UNION ALL
  SELECT 'chat.kakaopay_consultation_history' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakaopay_chat_consultation_history`) s, (SELECT COUNT(*) FROM `chat`.`kakaopay_consultation_history`) g
  UNION ALL
  SELECT 'chat.kakaopay_file' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakaopay_chat_file`) s, (SELECT COUNT(*) FROM `chat`.`kakaopay_file`) g
  UNION ALL
  SELECT 'chat.kakaopay_image' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakaopay_chat_image`) s, (SELECT COUNT(*) FROM `chat`.`kakaopay_image`) g
  UNION ALL
  SELECT 'chat.kakaopay_member_tag' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakaopay_chat_member_tag`) s, (SELECT COUNT(*) FROM `chat`.`kakaopay_member_tag`) g
  UNION ALL
  SELECT 'chat.kakaopay_memo' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakaopay_chat_memo`) s, (SELECT COUNT(*) FROM `chat`.`kakaopay_memo`) g
  UNION ALL
  SELECT 'chat.kakaopay_message' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakaopay_chat_message`) s, (SELECT COUNT(*) FROM `chat`.`kakaopay_message`) g
  UNION ALL
  SELECT 'chat.kakaopay_message_result' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakaopay_chat_message_result`) s, (SELECT COUNT(*) FROM `chat`.`kakaopay_message_result`) g
  UNION ALL
  SELECT 'chat.kakaopay_room' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakaopay_chat_room`) s, (SELECT COUNT(*) FROM `chat`.`kakaopay_room`) g
  UNION ALL
  SELECT 'chat.kakaopay_room_status_history' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakaopay_chat_room_status_history`) s, (SELECT COUNT(*) FROM `chat`.`kakaopay_room_status_history`) g
  UNION ALL
  SELECT 'chat.kakaopay_consultation' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakaopay_consultation`) s, (SELECT COUNT(*) FROM `chat`.`kakaopay_consultation`) g
  UNION ALL
  SELECT 'chat.kakaopay_consultation_cancel_reason' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakaopay_consultation_cancel_reason`) s, (SELECT COUNT(*) FROM `chat`.`kakaopay_consultation_cancel_reason`) g
  UNION ALL
  SELECT 'chat.kakaopay_consultation_status_history' t, (SELECT COUNT(*) FROM `bomapp_member`.`kakaopay_consultation_status_history`) s, (SELECT COUNT(*) FROM `chat`.`kakaopay_consultation_status_history`) g
  UNION ALL
  SELECT 'mydata.log_alimtalk_send' t, (SELECT COUNT(*) FROM `bomapp_member`.`log_my_data_alimtalk_send`) s, (SELECT COUNT(*) FROM `mydata`.`log_alimtalk_send`) g
  UNION ALL
  SELECT 'mydata.log_api_request' t, (SELECT COUNT(*) FROM `bomapp_member`.`log_my_data_api_request`) s, (SELECT COUNT(*) FROM `mydata`.`log_api_request`) g
  UNION ALL
  SELECT 'mydata.log_api_request_v2' t, (SELECT COUNT(*) FROM `bomapp_member`.`log_my_data_api_request_v2`) s, (SELECT COUNT(*) FROM `mydata`.`log_api_request_v2`) g
  UNION ALL
  SELECT 'mydata.log_member_token_reissue' t, (SELECT COUNT(*) FROM `bomapp_member`.`log_my_data_member_token_reissue`) s, (SELECT COUNT(*) FROM `mydata`.`log_member_token_reissue`) g
  UNION ALL
  SELECT 'mydata.detail_request' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_detail_request`) s, (SELECT COUNT(*) FROM `mydata`.`detail_request`) g
  UNION ALL
  SELECT 'mydata.detail_request_queue' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_detail_request_queue`) s, (SELECT COUNT(*) FROM `mydata`.`detail_request_queue`) g
  UNION ALL
  SELECT 'mydata.insurance' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_insurance`) s, (SELECT COUNT(*) FROM `mydata`.`insurance`) g
  UNION ALL
  SELECT 'mydata.insurance_basic' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_insurance_basic`) s, (SELECT COUNT(*) FROM `mydata`.`insurance_basic`) g
  UNION ALL
  SELECT 'mydata.insurance_car' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_insurance_car`) s, (SELECT COUNT(*) FROM `mydata`.`insurance_car`) g
  UNION ALL
  SELECT 'mydata.insurance_car_transaction' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_insurance_car_transaction`) s, (SELECT COUNT(*) FROM `mydata`.`insurance_car_transaction`) g
  UNION ALL
  SELECT 'mydata.insurance_contract' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_insurance_contract`) s, (SELECT COUNT(*) FROM `mydata`.`insurance_contract`) g
  UNION ALL
  SELECT 'mydata.insurance_general_basic' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_insurance_general_basic`) s, (SELECT COUNT(*) FROM `mydata`.`insurance_general_basic`) g
  UNION ALL
  SELECT 'mydata.insurance_general_contract' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_insurance_general_contract`) s, (SELECT COUNT(*) FROM `mydata`.`insurance_general_contract`) g
  UNION ALL
  SELECT 'mydata.insurance_general_insured' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_insurance_general_insured`) s, (SELECT COUNT(*) FROM `mydata`.`insurance_general_insured`) g
  UNION ALL
  SELECT 'mydata.insurance_general_transaction' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_insurance_general_transaction`) s, (SELECT COUNT(*) FROM `mydata`.`insurance_general_transaction`) g
  UNION ALL
  SELECT 'mydata.insurance_insured' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_insurance_insured`) s, (SELECT COUNT(*) FROM `mydata`.`insurance_insured`) g
  UNION ALL
  SELECT 'mydata.insurance_payment' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_insurance_payment`) s, (SELECT COUNT(*) FROM `mydata`.`insurance_payment`) g
  UNION ALL
  SELECT 'mydata.insurance_payment_average' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_insurance_payment_average`) s, (SELECT COUNT(*) FROM `mydata`.`insurance_payment_average`) g
  UNION ALL
  SELECT 'mydata.insurance_transaction' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_insurance_transaction`) s, (SELECT COUNT(*) FROM `mydata`.`insurance_transaction`) g
  UNION ALL
  SELECT 'mydata.insured_basic' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_insured_basic`) s, (SELECT COUNT(*) FROM `mydata`.`insured_basic`) g
  UNION ALL
  SELECT 'mydata.insured_contract' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_insured_contract`) s, (SELECT COUNT(*) FROM `mydata`.`insured_contract`) g
  UNION ALL
  SELECT 'mydata.irp' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_irp`) s, (SELECT COUNT(*) FROM `mydata`.`irp`) g
  UNION ALL
  SELECT 'mydata.irp_basic' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_irp_basic`) s, (SELECT COUNT(*) FROM `mydata`.`irp_basic`) g
  UNION ALL
  SELECT 'mydata.irp_detail' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_irp_detail`) s, (SELECT COUNT(*) FROM `mydata`.`irp_detail`) g
  UNION ALL
  SELECT 'mydata.irp_transaction' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_irp_transaction`) s, (SELECT COUNT(*) FROM `mydata`.`irp_transaction`) g
  UNION ALL
  SELECT 'mydata.linkage_count' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_linkage_count`) s, (SELECT COUNT(*) FROM `mydata`.`linkage_count`) g
  UNION ALL
  SELECT 'mydata.management_statistics' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_management_statistics`) s, (SELECT COUNT(*) FROM `mydata`.`management_statistics`) g
  UNION ALL
  SELECT 'mydata.management_statistics_org' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_management_statistics_org`) s, (SELECT COUNT(*) FROM `mydata`.`management_statistics_org`) g
  UNION ALL
  SELECT 'mydata.management_statistics_org_api' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_management_statistics_org_api`) s, (SELECT COUNT(*) FROM `mydata`.`management_statistics_org_api`) g
  UNION ALL
  SELECT 'mydata.management_statistics_org_api_error_count' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_management_statistics_org_api_error_count`) s, (SELECT COUNT(*) FROM `mydata`.`management_statistics_org_api_error_count`) g
  UNION ALL
  SELECT 'mydata.management_statistics_org_api_time_slot' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_management_statistics_org_api_time_slot`) s, (SELECT COUNT(*) FROM `mydata`.`management_statistics_org_api_time_slot`) g
  UNION ALL
  SELECT 'mydata.management_statistics_user_count' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_management_statistics_user_count`) s, (SELECT COUNT(*) FROM `mydata`.`management_statistics_user_count`) g
  UNION ALL
  SELECT 'mydata.member_consents' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_member_consents`) s, (SELECT COUNT(*) FROM `mydata`.`member_consents`) g
  UNION ALL
  SELECT 'mydata.member_token' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_member_token`) s, (SELECT COUNT(*) FROM `mydata`.`member_token`) g
  UNION ALL
  SELECT 'mydata.member_token_duplicate' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_member_token_duplicate`) s, (SELECT COUNT(*) FROM `mydata`.`member_token_duplicate`) g
  UNION ALL
  SELECT 'mydata.member_token_refresh_fail' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_member_token_refresh_fail`) s, (SELECT COUNT(*) FROM `mydata`.`member_token_refresh_fail`) g
  UNION ALL
  SELECT 'mydata.org' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_org`) s, (SELECT COUNT(*) FROM `mydata`.`org`) g
  UNION ALL
  SELECT 'mydata.org_api' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_org_api`) s, (SELECT COUNT(*) FROM `mydata`.`org_api`) g
  UNION ALL
  SELECT 'mydata.org_api_version' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_org_api_version`) s, (SELECT COUNT(*) FROM `mydata`.`org_api_version`) g
  UNION ALL
  SELECT 'mydata.org_domain_ip' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_org_domain_ip`) s, (SELECT COUNT(*) FROM `mydata`.`org_domain_ip`) g
  UNION ALL
  SELECT 'mydata.org_inspection_time' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_org_inspection_time`) s, (SELECT COUNT(*) FROM `mydata`.`org_inspection_time`) g
  UNION ALL
  SELECT 'mydata.org_ip' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_org_ip`) s, (SELECT COUNT(*) FROM `mydata`.`org_ip`) g
  UNION ALL
  SELECT 'mydata.org_schedule_time' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_org_schedule_time`) s, (SELECT COUNT(*) FROM `mydata`.`org_schedule_time`) g
  UNION ALL
  SELECT 'mydata.refresh_member' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_refresh_member`) s, (SELECT COUNT(*) FROM `mydata`.`refresh_member`) g
  UNION ALL
  SELECT 'mydata.signup_org' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_signup_org`) s, (SELECT COUNT(*) FROM `mydata`.`signup_org`) g
  UNION ALL
  SELECT 'mydata.support_agreement_history' t, (SELECT COUNT(*) FROM `bomapp_member`.`my_data_support_agreement_history`) s, (SELECT COUNT(*) FROM `mydata`.`support_agreement_history`) g
  UNION ALL
  SELECT 'planner.planner_profile' t, (SELECT COUNT(*) FROM `bomapp_member`.`planner_profile`) s, (SELECT COUNT(*) FROM `planner`.`planner_profile`) g
  UNION ALL
  SELECT 'planner.planner_profile_featured_product' t, (SELECT COUNT(*) FROM `bomapp_member`.`planner_profile_featured_product`) s, (SELECT COUNT(*) FROM `planner`.`planner_profile_featured_product`) g
  UNION ALL
  SELECT 'planner.recommend_amount_member' t, (SELECT COUNT(*) FROM `bomapp_member`.`recommend_amount_member`) s, (SELECT COUNT(*) FROM `planner`.`recommend_amount_member`) g
  UNION ALL
  SELECT 'planner.recommend_amount_planner' t, (SELECT COUNT(*) FROM `bomapp_member`.`recommend_amount_planner`) s, (SELECT COUNT(*) FROM `planner`.`recommend_amount_planner`) g
  UNION ALL
  SELECT 'planner.consultation' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_consultation`) s, (SELECT COUNT(*) FROM `planner`.`consultation`) g
  UNION ALL
  SELECT 'planner.consultation_allocation_history' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_consultation_allocation_history`) s, (SELECT COUNT(*) FROM `planner`.`consultation_allocation_history`) g
  UNION ALL
  SELECT 'planner.consultation_allocation_setting' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_consultation_allocation_setting`) s, (SELECT COUNT(*) FROM `planner`.`consultation_allocation_setting`) g
  UNION ALL
  SELECT 'planner.consultation_apply_history' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_consultation_apply_history`) s, (SELECT COUNT(*) FROM `planner`.`consultation_apply_history`) g
  UNION ALL
  SELECT 'planner.consultation_cancel_reason' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_consultation_cancel_reason`) s, (SELECT COUNT(*) FROM `planner`.`consultation_cancel_reason`) g
  UNION ALL
  SELECT 'planner.consultation_status_history' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_consultation_status_history`) s, (SELECT COUNT(*) FROM `planner`.`consultation_status_history`) g
  UNION ALL
  SELECT 'planner.corp_one_depth' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_corp_one_depth`) s, (SELECT COUNT(*) FROM `planner`.`corp_one_depth`) g
  UNION ALL
  SELECT 'planner.corp_organization' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_corp_organization`) s, (SELECT COUNT(*) FROM `planner`.`corp_organization`) g
  UNION ALL
  SELECT 'planner.corp_three_depth' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_corp_three_depth`) s, (SELECT COUNT(*) FROM `planner`.`corp_three_depth`) g
  UNION ALL
  SELECT 'planner.corp_two_depth' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_corp_two_depth`) s, (SELECT COUNT(*) FROM `planner`.`corp_two_depth`) g
  UNION ALL
  SELECT 'planner.corporation' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_corporation`) s, (SELECT COUNT(*) FROM `planner`.`corporation`) g
  UNION ALL
  SELECT 'planner.faq' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_faq`) s, (SELECT COUNT(*) FROM `planner`.`faq`) g
  UNION ALL
  SELECT 'planner.insurer' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_insurer`) s, (SELECT COUNT(*) FROM `planner`.`insurer`) g
  UNION ALL
  SELECT 'planner.insurer_archive' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_insurer_archive`) s, (SELECT COUNT(*) FROM `planner`.`insurer_archive`) g
  UNION ALL
  SELECT 'planner.insurer_archive_support' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_insurer_archive_support`) s, (SELECT COUNT(*) FROM `planner`.`insurer_archive_support`) g
  UNION ALL
  SELECT 'planner.insurer_archive_support_category' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_insurer_archive_support_category`) s, (SELECT COUNT(*) FROM `planner`.`insurer_archive_support_category`) g
  UNION ALL
  SELECT 'planner.insurer_archive_support_file' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_insurer_archive_support_file`) s, (SELECT COUNT(*) FROM `planner`.`insurer_archive_support_file`) g
  UNION ALL
  SELECT 'planner.insurer_bookmark' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_insurer_bookmark`) s, (SELECT COUNT(*) FROM `planner`.`insurer_bookmark`) g
  UNION ALL
  SELECT 'planner.marketing_agree' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_marketing_agree`) s, (SELECT COUNT(*) FROM `planner`.`marketing_agree`) g
  UNION ALL
  SELECT 'planner.memo' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_memo`) s, (SELECT COUNT(*) FROM `planner`.`memo`) g
  UNION ALL
  SELECT 'planner.notification' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_notification`) s, (SELECT COUNT(*) FROM `planner`.`notification`) g
  UNION ALL
  SELECT 'planner.planner' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_planner`) s, (SELECT COUNT(*) FROM `planner`.`planner`) g
  UNION ALL
  SELECT 'planner.planner_insurance_premium' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_planner_insurance_premium`) s, (SELECT COUNT(*) FROM `planner`.`planner_insurance_premium`) g
  UNION ALL
  SELECT 'planner.planner_main_force_product' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_planner_main_force_product`) s, (SELECT COUNT(*) FROM `planner`.`planner_main_force_product`) g
  UNION ALL
  SELECT 'planner.planner_member' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_planner_member`) s, (SELECT COUNT(*) FROM `planner`.`planner_member`) g
  UNION ALL
  SELECT 'planner.policy_agree' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_policy_agree`) s, (SELECT COUNT(*) FROM `planner`.`policy_agree`) g
  UNION ALL
  SELECT 'planner.role_corp' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_role_corp`) s, (SELECT COUNT(*) FROM `planner`.`role_corp`) g
  UNION ALL
  SELECT 'planner.role_mapping' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_role_mapping`) s, (SELECT COUNT(*) FROM `planner`.`role_mapping`) g
  UNION ALL
  SELECT 'planner.role_planner' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_role_planner`) s, (SELECT COUNT(*) FROM `planner`.`role_planner`) g
  UNION ALL
  SELECT 'planner.user_action_log' t, (SELECT COUNT(*) FROM `bomapp_member`.`w_user_action_log`) s, (SELECT COUNT(*) FROM `planner`.`user_action_log`) g
  UNION ALL
  SELECT 'messaging.alimtalk_message_queue' t, (SELECT COUNT(*) FROM `bomapp_member`.`alimtalk_message_queue`) s, (SELECT COUNT(*) FROM `messaging`.`alimtalk_message_queue`) g
  UNION ALL
  SELECT 'messaging.alimtalk_message_setting' t, (SELECT COUNT(*) FROM `bomapp_member`.`alimtalk_message_setting`) s, (SELECT COUNT(*) FROM `messaging`.`alimtalk_message_setting`) g
  UNION ALL
  SELECT 'messaging.alimtalk_recipient' t, (SELECT COUNT(*) FROM `bomapp_member`.`alimtalk_recipient`) s, (SELECT COUNT(*) FROM `messaging`.`alimtalk_recipient`) g
  UNION ALL
  SELECT 'messaging.alimtalk_recipient_extraction_job' t, (SELECT COUNT(*) FROM `bomapp_member`.`alimtalk_recipient_extraction_job`) s, (SELECT COUNT(*) FROM `messaging`.`alimtalk_recipient_extraction_job`) g
  UNION ALL
  SELECT 'messaging.alimtalk_send_condition' t, (SELECT COUNT(*) FROM `bomapp_member`.`alimtalk_send_condition`) s, (SELECT COUNT(*) FROM `messaging`.`alimtalk_send_condition`) g
  UNION ALL
  SELECT 'messaging.log_notification_alimtalk' t, (SELECT COUNT(*) FROM `bomapp_member`.`log_notification_alimtalk`) s, (SELECT COUNT(*) FROM `messaging`.`log_notification_alimtalk`) g
  UNION ALL
  SELECT 'messaging.notification' t, (SELECT COUNT(*) FROM `bomapp_member`.`notification`) s, (SELECT COUNT(*) FROM `messaging`.`notification`) g
  UNION ALL
  SELECT 'messaging.notification_message_setting' t, (SELECT COUNT(*) FROM `bomapp_member`.`notification_message_setting`) s, (SELECT COUNT(*) FROM `messaging`.`notification_message_setting`) g
  UNION ALL
  SELECT 'messaging.notification_recipient' t, (SELECT COUNT(*) FROM `bomapp_member`.`notification_recipient`) s, (SELECT COUNT(*) FROM `messaging`.`notification_recipient`) g
  UNION ALL
  SELECT 'bomapp.analysis_survey' t, (SELECT COUNT(*) FROM `bomapp_member`.`analysis_survey`) s, (SELECT COUNT(*) FROM `bomapp`.`analysis_survey`) g
  UNION ALL
  SELECT 'bomapp.analysis_survey_children' t, (SELECT COUNT(*) FROM `bomapp_member`.`analysis_survey_children`) s, (SELECT COUNT(*) FROM `bomapp`.`analysis_survey_children`) g
  UNION ALL
  SELECT 'bomapp.biological_age' t, (SELECT COUNT(*) FROM `bomapp_member`.`biological_age`) s, (SELECT COUNT(*) FROM `bomapp`.`biological_age`) g
  UNION ALL
  SELECT 'bomapp.biomarker' t, (SELECT COUNT(*) FROM `bomapp_member`.`biomarker`) s, (SELECT COUNT(*) FROM `bomapp`.`biomarker`) g
  UNION ALL
  SELECT 'bomapp.cancer_analysis_summary' t, (SELECT COUNT(*) FROM `bomapp_member`.`cancer_analysis_summary`) s, (SELECT COUNT(*) FROM `bomapp`.`cancer_analysis_summary`) g
  UNION ALL
  SELECT 'bomapp.cancer_rate_prediction' t, (SELECT COUNT(*) FROM `bomapp_member`.`cancer_rate_prediction`) s, (SELECT COUNT(*) FROM `bomapp`.`cancer_rate_prediction`) g
  UNION ALL
  SELECT 'bomapp.cancer_risk_prediction' t, (SELECT COUNT(*) FROM `bomapp_member`.`cancer_risk_prediction`) s, (SELECT COUNT(*) FROM `bomapp`.`cancer_risk_prediction`) g
  UNION ALL
  SELECT 'bomapp.car_info' t, (SELECT COUNT(*) FROM `bomapp_member`.`car_info`) s, (SELECT COUNT(*) FROM `bomapp`.`car_info`) g
  UNION ALL
  SELECT 'bomapp.contract_car' t, (SELECT COUNT(*) FROM `bomapp_member`.`contract_car`) s, (SELECT COUNT(*) FROM `bomapp`.`contract_car`) g
  UNION ALL
  SELECT 'bomapp.contract_car_guarantee' t, (SELECT COUNT(*) FROM `bomapp_member`.`contract_car_guarantee`) s, (SELECT COUNT(*) FROM `bomapp`.`contract_car_guarantee`) g
  UNION ALL
  SELECT 'bomapp.contract_credit' t, (SELECT COUNT(*) FROM `bomapp_member`.`contract_credit`) s, (SELECT COUNT(*) FROM `bomapp`.`contract_credit`) g
  UNION ALL
  SELECT 'bomapp.contract_credit_item' t, (SELECT COUNT(*) FROM `bomapp_member`.`contract_credit_item`) s, (SELECT COUNT(*) FROM `bomapp`.`contract_credit_item`) g
  UNION ALL
  SELECT 'bomapp.contract_credit_statistics' t, (SELECT COUNT(*) FROM `bomapp_member`.`contract_credit_statistics`) s, (SELECT COUNT(*) FROM `bomapp`.`contract_credit_statistics`) g
  UNION ALL
  SELECT 'bomapp.coocon_session' t, (SELECT COUNT(*) FROM `bomapp_member`.`coocon_session`) s, (SELECT COUNT(*) FROM `bomapp`.`coocon_session`) g
  UNION ALL
  SELECT 'bomapp.disease_risk_prediction' t, (SELECT COUNT(*) FROM `bomapp_member`.`disease_risk_prediction`) s, (SELECT COUNT(*) FROM `bomapp`.`disease_risk_prediction`) g
  UNION ALL
  SELECT 'bomapp.diseases_code' t, (SELECT COUNT(*) FROM `bomapp_member`.`diseases_code`) s, (SELECT COUNT(*) FROM `bomapp`.`diseases_code`) g
  UNION ALL
  SELECT 'bomapp.family_health_checkup' t, (SELECT COUNT(*) FROM `bomapp_member`.`family_health_checkup`) s, (SELECT COUNT(*) FROM `bomapp`.`family_health_checkup`) g
  UNION ALL
  SELECT 'bomapp.family_health_checkup_crypto' t, (SELECT COUNT(*) FROM `bomapp_member`.`family_health_checkup_crypto`) s, (SELECT COUNT(*) FROM `bomapp`.`family_health_checkup_crypto`) g
  UNION ALL
  SELECT 'bomapp.family_health_survey' t, (SELECT COUNT(*) FROM `bomapp_member`.`family_health_survey`) s, (SELECT COUNT(*) FROM `bomapp`.`family_health_survey`) g
  UNION ALL
  SELECT 'bomapp.from_age_interval_changes' t, (SELECT COUNT(*) FROM `bomapp_member`.`from_age_interval_changes`) s, (SELECT COUNT(*) FROM `bomapp`.`from_age_interval_changes`) g
  UNION ALL
  SELECT 'bomapp.from_age_pdf' t, (SELECT COUNT(*) FROM `bomapp_member`.`from_age_pdf`) s, (SELECT COUNT(*) FROM `bomapp`.`from_age_pdf`) g
  UNION ALL
  SELECT 'bomapp.from_age_risk_detail' t, (SELECT COUNT(*) FROM `bomapp_member`.`from_age_risk_detail`) s, (SELECT COUNT(*) FROM `bomapp`.`from_age_risk_detail`) g
  UNION ALL
  SELECT 'bomapp.from_age_risk_incidence_rate_age' t, (SELECT COUNT(*) FROM `bomapp_member`.`from_age_risk_incidence_rate_age`) s, (SELECT COUNT(*) FROM `bomapp`.`from_age_risk_incidence_rate_age`) g
  UNION ALL
  SELECT 'bomapp.from_age_risk_result' t, (SELECT COUNT(*) FROM `bomapp_member`.`from_age_risk_result`) s, (SELECT COUNT(*) FROM `bomapp`.`from_age_risk_result`) g
  UNION ALL
  SELECT 'bomapp.gnnet_hospitals' t, (SELECT COUNT(*) FROM `bomapp_member`.`gnnet_hospitals`) s, (SELECT COUNT(*) FROM `bomapp`.`gnnet_hospitals`) g
  UNION ALL
  SELECT 'bomapp.health_checkup_analysis_pdf_crypto' t, (SELECT COUNT(*) FROM `bomapp_member`.`health_checkup_analysis_pdf_crypto`) s, (SELECT COUNT(*) FROM `bomapp`.`health_checkup_analysis_pdf_crypto`) g
  UNION ALL
  SELECT 'bomapp.health_checkup_bio_age_analysis_guide_crypto' t, (SELECT COUNT(*) FROM `bomapp_member`.`health_checkup_bio_age_analysis_guide_crypto`) s, (SELECT COUNT(*) FROM `bomapp`.`health_checkup_bio_age_analysis_guide_crypto`) g
  UNION ALL
  SELECT 'bomapp.health_checkup_bio_age_life_expectancy_crypto' t, (SELECT COUNT(*) FROM `bomapp_member`.`health_checkup_bio_age_life_expectancy_crypto`) s, (SELECT COUNT(*) FROM `bomapp`.`health_checkup_bio_age_life_expectancy_crypto`) g
  UNION ALL
  SELECT 'bomapp.health_checkup_crypto' t, (SELECT COUNT(*) FROM `bomapp_member`.`health_checkup_crypto`) s, (SELECT COUNT(*) FROM `bomapp`.`health_checkup_crypto`) g
  UNION ALL
  SELECT 'bomapp.health_checkup_detail_crypto' t, (SELECT COUNT(*) FROM `bomapp_member`.`health_checkup_detail_crypto`) s, (SELECT COUNT(*) FROM `bomapp`.`health_checkup_detail_crypto`) g
  UNION ALL
  SELECT 'bomapp.health_letter' t, (SELECT COUNT(*) FROM `bomapp_member`.`health_letter`) s, (SELECT COUNT(*) FROM `bomapp`.`health_letter`) g
  UNION ALL
  SELECT 'bomapp.health_letter_template' t, (SELECT COUNT(*) FROM `bomapp_member`.`health_letter_template`) s, (SELECT COUNT(*) FROM `bomapp`.`health_letter_template`) g
  UNION ALL
  SELECT 'bomapp.ins_claim_history' t, (SELECT COUNT(*) FROM `bomapp_member`.`ins_claim_history`) s, (SELECT COUNT(*) FROM `bomapp`.`ins_claim_history`) g
  UNION ALL
  SELECT 'bomapp.ins_claim_member_info' t, (SELECT COUNT(*) FROM `bomapp_member`.`ins_claim_member_info`) s, (SELECT COUNT(*) FROM `bomapp`.`ins_claim_member_info`) g
  UNION ALL
  SELECT 'bomapp.ins_comp' t, (SELECT COUNT(*) FROM `bomapp_member`.`ins_comp`) s, (SELECT COUNT(*) FROM `bomapp`.`ins_comp`) g
  UNION ALL
  SELECT 'bomapp.insurance_guarantee' t, (SELECT COUNT(*) FROM `bomapp_member`.`insurance_guarantee`) s, (SELECT COUNT(*) FROM `bomapp`.`insurance_guarantee`) g
  UNION ALL
  SELECT 'bomapp.insurance_guarantee_contract' t, (SELECT COUNT(*) FROM `bomapp_member`.`insurance_guarantee_contract`) s, (SELECT COUNT(*) FROM `bomapp`.`insurance_guarantee_contract`) g
  UNION ALL
  SELECT 'bomapp.insurance_guarantee_request' t, (SELECT COUNT(*) FROM `bomapp_member`.`insurance_guarantee_request`) s, (SELECT COUNT(*) FROM `bomapp`.`insurance_guarantee_request`) g
  UNION ALL
  SELECT 'bomapp.insurance_guarantee_request_queue' t, (SELECT COUNT(*) FROM `bomapp_member`.`insurance_guarantee_request_queue`) s, (SELECT COUNT(*) FROM `bomapp`.`insurance_guarantee_request_queue`) g
  UNION ALL
  SELECT 'bomapp.insurer_inspection_time' t, (SELECT COUNT(*) FROM `bomapp_member`.`insurer_inspection_time`) s, (SELECT COUNT(*) FROM `bomapp`.`insurer_inspection_time`) g
  UNION ALL
  SELECT 'bomapp.log_agreement_health' t, (SELECT COUNT(*) FROM `bomapp_member`.`log_agreement_health`) s, (SELECT COUNT(*) FROM `bomapp`.`log_agreement_health`) g
  UNION ALL
  SELECT 'bomapp.log_coocon' t, (SELECT COUNT(*) FROM `bomapp_member`.`log_coocon`) s, (SELECT COUNT(*) FROM `bomapp`.`log_coocon`) g
  UNION ALL
  SELECT 'bomapp.log_from_age_analysis_result' t, (SELECT COUNT(*) FROM `bomapp_member`.`log_from_age_analysis_result`) s, (SELECT COUNT(*) FROM `bomapp`.`log_from_age_analysis_result`) g
  UNION ALL
  SELECT 'bomapp.log_health_checkup_analysis_register' t, (SELECT COUNT(*) FROM `bomapp_member`.`log_health_checkup_analysis_register`) s, (SELECT COUNT(*) FROM `bomapp`.`log_health_checkup_analysis_register`) g
  UNION ALL
  SELECT 'bomapp.log_insurance_guarantee_request' t, (SELECT COUNT(*) FROM `bomapp_member`.`log_insurance_guarantee_request`) s, (SELECT COUNT(*) FROM `bomapp`.`log_insurance_guarantee_request`) g
  UNION ALL
  SELECT 'bomapp.log_pdf_result' t, (SELECT COUNT(*) FROM `bomapp_member`.`log_pdf_result`) s, (SELECT COUNT(*) FROM `bomapp`.`log_pdf_result`) g
  UNION ALL
  SELECT 'bomapp.log_scrap_health_checkup' t, (SELECT COUNT(*) FROM `bomapp_member`.`log_scrap_health_checkup`) s, (SELECT COUNT(*) FROM `bomapp`.`log_scrap_health_checkup`) g
  UNION ALL
  SELECT 'bomapp.medical_data' t, (SELECT COUNT(*) FROM `bomapp_member`.`medical_data`) s, (SELECT COUNT(*) FROM `bomapp`.`medical_data`) g
  UNION ALL
  SELECT 'bomapp.peer_premium_statistics' t, (SELECT COUNT(*) FROM `bomapp_member`.`peer_premium_statistics`) s, (SELECT COUNT(*) FROM `bomapp`.`peer_premium_statistics`) g
  UNION ALL
  SELECT 'bomapp.policy' t, (SELECT COUNT(*) FROM `bomapp_member`.`policy`) s, (SELECT COUNT(*) FROM `bomapp`.`policy`) g
  UNION ALL
  SELECT 'bomapp.policy_detail' t, (SELECT COUNT(*) FROM `bomapp_member`.`policy_detail`) s, (SELECT COUNT(*) FROM `bomapp`.`policy_detail`) g
  UNION ALL
  SELECT 'bomapp.popular_insurance_statistics' t, (SELECT COUNT(*) FROM `bomapp_member`.`popular_insurance_statistics`) s, (SELECT COUNT(*) FROM `bomapp`.`popular_insurance_statistics`) g
  UNION ALL
  SELECT 'bomapp.product' t, (SELECT COUNT(*) FROM `bomapp_member`.`product`) s, (SELECT COUNT(*) FROM `bomapp`.`product`) g
  UNION ALL
  SELECT 'bomapp.product_group' t, (SELECT COUNT(*) FROM `bomapp_member`.`product_group`) s, (SELECT COUNT(*) FROM `bomapp`.`product_group`) g
  UNION ALL
  SELECT 'bomapp.scrap_report_ins' t, (SELECT COUNT(*) FROM `bomapp_member`.`scrap_report_ins`) s, (SELECT COUNT(*) FROM `bomapp`.`scrap_report_ins`) g
) x WHERE s <> g ORDER BY t;
