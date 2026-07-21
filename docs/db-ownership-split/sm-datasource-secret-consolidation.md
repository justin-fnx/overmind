# datasource 시크릿 정규화 — `bomapp/{env}/datasource/{schema}` (스키마 키)

> 상위: DB 오너십 분리(BOM-399). **스키마 전환(앱 데이터소스 오너십 분리) 이전 선행 정리.**
> **코드 전환 방식 = 엔티티 `@Table(schema=)` 명시(2026-07-13 확정).** 앱은 단일 datasource로 접속하고
> 엔티티가 소속 스키마를 명시, 앱 계정은 필요한 스키마에 grant를 받는다(멀티 DS 아님).
> → datasource 연결은 **스키마 단위**가 자연스럽고, 같은 스키마 도메인의 여러 앱이 **하나의 datasource 시크릿을 공용**한다.
> 이 정리는 URL의 **스키마를 `/bomapp_member` 그대로 유지**(엔티티 어노테이션이 테이블별 스키마 해석)하고,
> 연결정보(url+user+pass)가 어느 시크릿에 사는가만 스키마 키로 정규화한다(엔티티 마이그레이션과 독립).

## 규칙

```
bomapp/{env}/datasource/{schema}      # url+user+pass. 홈 스키마 공용. (기존 bomapp/{env}/{app}/kafka 와 유사 계층)
```

- 앱은 **자기 홈 스키마**의 datasource 시크릿을 import. 같은 스키마 도메인의 여러 앱이 공용.
- 크로스 스키마 접근(예: chat-api→planner/bomapp)은 **홈 datasource 유저에 타 스키마 grant**로 해결 — 시크릿은 홈 스키마 1개.
- **리네임 금지 — 신규 생성.** 구 시크릿(`datasource-{app}`, `chat-api`, yml URL 등) 존치 → 앱 config 전환 → 재배포 → 검증 후 구 삭제(무중단).
- 신규 시크릿 URL의 DB = **`/bomapp_member` 유지**(지금). ⚠️ **엔티티 `@Table(schema=)` 어노테이션 미적용 상태** → 엔티티가 커넥션 default 스키마로 해석되므로, `datasource/bomapp`에 `/bomapp`를 넣으면 그 앱의 타 스키마·잔류(bomapp_member) 테이블을 못 찾아 파손. **소유 스키마(`/bomapp` 등)로의 전환은 엔티티 어노테이션 마이그레이션 완료 후.** (시크릿 이름은 소유 스키마 = 의도, URL default는 어노테이션 타임라인을 따름.)
- URL 형식: 앱이 `write-url`/`read-url`을 **완전한 JDBC URL**로 읽음(전 datasource 시크릿 공통). 파라미터는 기존 동작 URL과 동일하게(`autoReconnect=true&useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Seoul&useSSL=false`). write=writer(`cluster-`), read=reader(`cluster-ro-`) 엔드포인트.

## ✅ 신규 시크릿 (스키마 키, 플레이스홀더 생성 완료 2026-07-13)

**5 스키마 × dev/stg/prod = 15개** 생성(+ mydata-mgmts prod 1 = 16). Leader create-secret; **값은 운영자가 채움 — 명시적 허용**. 태그 `Purpose=datasource, Env, Schema, Status=placeholder, Ticket=BOM-399`.
(앞서 잘못 만든 **앱 키 27개(`bomapp/{env}/{app}/datasource`)는 삭제 완료**.)

| 시크릿 `bomapp/{env}/datasource/{schema}` | 공용 앱 | 값 출처(복사원) |
|------|------|------|
| `datasource/chat` | chat-api | dev=`bomapp/dev/chat-api`(URL)+`chat-api-app`(chat-username/password); stg/prod=yml write/read-url+`chat-api-app`. **키: write-url/read-url/chat-username/chat-password**(chat-api는 chat-username 우선, username 폴백). |
| `datasource/planner` | wings-api | stg/prod=`datasource-wings-api`; dev=`bomapp/dev/chat-api`(현 공유값). |
| `datasource/mydata` | mydata-api, mydata-batch | stg/prod=`datasource-mydata-{api,batch}`; dev=`bomapp/dev/datasource`. |
| `datasource/bomapp` | bomapp-api, bomapp-batch, statics-batch, recipient-extractor, open-api | stg/prod=`datasource-bomapp-{api,batch}` 등(공용 연결·union grant); dev=`bomapp/dev/datasource`. |
| `datasource/messaging` | messaging 스키마 홈(messaging 서비스=별도 repo `bomapp/{env}/messaging`; next-backend 앱들은 홈 datasource + messaging grant로 alimtalk/notification 테이블 write) | 값=messaging 스키마 연결(현 messaging 서비스 DB부). dev/stg/prod 생성. |

- 값 주입 시 **URL 스키마 `/bomapp_member` 유지**. 표준 키: `spring.datasource.write-url`/`read-url`/`username`/`password` (chat은 `chat-username`/`chat-password`).
- **⚠️ chat-api-app 은 폐지 아님** — JWT/crypto/AWS키/meritz/infobank/monitor 등 **앱시크릿 번들**이라 유지(datasource-only 만 datasource/chat 로 추출). 운영자는 datasource/chat 채운 뒤 chat-api-app에서 chat-username/chat-password 제거(중복 방지).
- open-api·recipient-extractor는 사용자 지시로 **bomapp 스키마** 매핑(현행 연결 유지). messaging/bomapp_member 전용 시크릿은 이번 미생성.

## 코드 (next-backend yml import) — MR !192 (`→ rc/db-ownership-split`)

각 앱 datasource import를 홈 스키마 시크릿으로. datasource 외 import(file-storage-security-*, jwt-open-api, wings application-private, **chat-api-app**)는 유지.
- bomapp-api·bomapp-batch·statics-batch·recipient-extractor·open-api `application-server-{stg,prod}.yml` → `bomapp/{env}/datasource/bomapp`.
- mydata-api·mydata-batch → `bomapp/{env}/datasource/mydata`.
- wings-api `application-server-{stg,prod}.yml` → `datasource/planner`; `{dev,local}` → `bomapp/dev/datasource/planner`.
- chat-api `application-{prod,stg}.yml` import 리스트 = `datasource/chat` + `chat-api-app`, yml write/read-url 삭제; `application-server-{dev,local}.yml` = `bomapp/dev/datasource/chat` + `chat-api-app`; `application-dev.yml` 무변경.
- statics-batch 프로파일 테스트 assert = `bomapp/{prod,stg}/datasource/bomapp`.
- **⚠️ 신규 시크릿 값 주입 후에만 배포**(플레이스홀더 상태 배포 시 부팅 실패). MR은 스테이징만.

## 마이그레이션 순서 (무중단)
1. ✅ 신규 스키마 키 시크릿 생성(플레이스홀더) — 완료(앱 키 27개 삭제 완료).
2. 운영자: 12개에 값 주입(구 시크릿 값 복사, 스키마 `/bomapp_member` 유지). chat-api-app에서 chat-username/password 제거.
3. MR !192 머지(rc/db-ownership-split) — 엔티티 마이그레이션과 순서 조율.
4. 앱별 재배포 → 기동 확인(로그 `Master DataSource URL`).
5. 전 앱 전환·검증 후 구 시크릿 삭제(아래).

## 삭제 후보 (전환·검증 후)
- `bomapp/{stg,prod}/datasource-{bomapp-api,bomapp-batch,mydata-api,mydata-batch,open-api,wings-api}`.
- `bomapp/dev/datasource`(공통, dev 소비 앱 전환 완료 후), `bomapp/dev/chat-api`.
- `bomapp/{env}/chat-api-app`의 **datasource 키만**(secret 자체는 앱시크릿 번들이라 유지).
- 미참조 `bomapp/stg/chat-api`·`bomapp/prod/chat-api`. (디커미션 `bomapp/stg/datasource-alimtalk-callback` = ✅ **삭제 완료** 2026-07-14.)
- mydata-mgmts-api 구 `bomapp/prod/datasource-mydata-mgmts-api` = mydata 스키마 컷오버 후 삭제(신규는 공유 `datasource/mydata`). 별도 `datasource/mydata-mgmts` 는 만들었다가 **삭제**(자체 DB 오판이었음).

## 범위 밖 / 오픈
- ✅ **mydata-mgmts-api**(GitHub, prod-only): 조사 결과 **자체 DB 아님** — 자체 엔티티(member·member_view·my_data_member_consents·my_data_member_token·my_data_org·log_my_data_api_request)가 **mydata 스키마**(my_data_*, log_my_data_api_request) + **member/member_view(bomapp_member)** 소속. → 별도 `datasource/mydata-mgmts`(생성 후 **삭제**) 대신 **공유 `datasource/mydata` 조준 + reader/writer 라우팅 DataSource(`@Profile("prod")`)** 추가(**PR #20**, config/rds/*). member/member_view=bomapp_member grant read. dev/stg는 datasource 설정 없음(prod 전용). 배포는 mydata 스키마 컷오버와 함께.
- legacy `datasource-bomapp-redmin`/`-webview`(legacy-backend, SM config import 미사용·소비 경로 별개 → 이 정규화 무관). console(`bomapp/{env}/console` DATABASE_URL)·messaging(`bomapp/{env}/messaging`)=자체 DB를 앱 시크릿에 임베드한 별도 서비스 → 정규화 제외(현행 유지).
- dev 소비 앱을 `datasource/{schema}`로 옮기는 코드(현재 dev는 공통 `bomapp/dev/datasource` 경유 다수) — 스키마 flip/엔티티 마이그레이션과 함께.
- `/{env}/wings-api/config/application-private`(datasource 아님, `bomapp/` 프리픽스 없음).
