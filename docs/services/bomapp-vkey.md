# bomapp-vkey (transkey_servlet)

> 라온시큐어 **TouchEn 가상키보드(transkey)** 의 서버측 복호화 서블릿. `vkey.bomapp.co.kr` 도메인으로 노출되며, 보험금 청구 플로우에서 사용자가 주민번호를 가상키보드로 입력하면 클라이언트가 암호화한 페이로드를 이 서버가 복호화·검증한다.

| 항목 | 값 |
|------|----|
| 운영 도메인 | `https://vkey.bomapp.co.kr` |
| 현재 위치 | PROD-BACK 공용 WAS 컨테이너 (`next-backend-was:1.1`) 내부 `/was/run/bomapp-vkey`, PID 1205 |
| 인스턴스 | `i-03f0178089f760c6f` (= `api-was2` = `10.1.1.20`) |
| 컨테이너 포트 | **8080** (HTTP connector), 8005 (shutdown), 65355 (JMX) |
| ALB 라우팅 | PROD-ALB:443 priority 10 → TG `prod-back-ecs-host-http-8080` |
| 런타임 | **Tomcat 9.0.45** + Java 1.8 (Spring Boot 아님) |
| 빌드 시스템 | **IntelliJ artifact** (Maven/Gradle 없음) |
| 패키징 | WAR (`secure_servlet_war`) |
| 소스 리포 | [`bomapp-inc/transkey_servlet`](https://github.com/bomapp-inc/transkey_servlet) (GitHub) |

---

## 1. 개요

보맵은 사용자의 민감 정보(주민번호/인증서 비밀번호/카드번호 등) 입력 시 **라온시큐어 TouchEn mTranskey** 가상키보드를 띄운다. 가상키보드는 키 입력을 클라이언트에서 RSA(E2E) 로 암호화한 페이로드로 전환하고, 폼 제출 시 이 페이로드가 `bomapp-vkey` 의 `/transkeyServlet` 또는 `/transkeyServlet/decode` 로 전달된다. `TransKey.decode(...)` 가 서버측에서 복호화하여 평문을 호출자에게 반환한다.

**실제 사용 범위** (노션 "[보안키보드 사용 현황](https://www.notion.so/52904c5a70374c1a8e58d4d1aeeb0224)" 2020-09-07 기준):

| 영역 | 입력 항목 | 뷰 |
|------|----------|-----|
| 신용정보원 | 회원가입 주민번호, 비밀번호 재설정 주민번호 | ctrlview |
| 연동 (자동차 스크래핑·진료이용내역·건강검진결과·공인인증서) | 인증서 비밀번호, 주민번호 | 인증서 비번은 fullview, 주민번호는 ctrlview (2020-09-07 변경) |
| 청구 | 주민번호 | ctrlview |
| 마켓 | 골프 주민번호, 카드 등록 시 카드번호 + 카드 비밀번호 앞 두자리 | ctrlview |

> ⚠️ 노션 인프라 페이지(2025-10-15)의 "청구할 때 주민번호 위한 가상키보드" 설명은 일부 범위만 반영. **vkey 다운 시 청구만 막히는 게 아니라 회원가입·인증·결제 등 다수 플로우가 동시 다운** 된다.

이 서비스는 **별개 프로젝트**다 — `legacy-backend`, `next-backend` 와는 코드/리포가 독립되어 있고, BOMAPP 의 다른 서비스들이 사용하는 **GitLab 셀프호스트(`gitlab.bomapp.co.kr`)** 가 아니라 **GitHub `bomapp-inc` 조직**에 호스팅된다(예외).

---

## 2. 소스 리포지토리

### 2.1 운영 리포: `transkey_servlet`

| 항목 | 값 |
|------|----|
| URL | https://github.com/bomapp-inc/transkey_servlet |
| 첫 커밋 | 2020-06-04 11:27 KST ("Initial commit") |
| 커밋 수 | 1 (초기 커밋 이후 변경 없음) |
| 작성자 | zard21 (개발자 본인 macOS 절대경로가 `config.ini` 에 남아 있음) |
| 빌드 | IntelliJ artifact `secure_servlet_war` (no Maven, no Gradle) |
| 산출물 | `secure_servlet.war` |

### 2.2 코드 구조

```
secure_servlet/
├── secure_servlet.iml                 # IntelliJ 모듈 정의
└── web/
    ├── index.html                     # Raon transkey 데모 진입점
    ├── validate.jsp                   # transkey 디코딩 검증 JSP (운영 미사용 추정)
    ├── decoder_sample.jsp             # ServerToServer 디코딩 예시
    ├── decoder_ws_sample.jsp          # WS 디코딩 예시
    ├── TouchEn/                       # 라온 클라이언트 자산
    │   ├── transkey/                  #   - 데스크톱 가상키보드 JS/CSS/이미지
    │   ├── transkey_mobile/           #   - 모바일 가상키보드 JS/CSS/이미지
    │   └── demo/, mobileDemo/         #   - 라온 데모 페이지 (운영에는 노출 X 추정)
    └── WEB-INF/
        ├── web.xml                    # 서블릿/필터 정의
        ├── lib/
        │   ├── transkey-4-6-12_18_20190703_X.jar   # 라온 transkey 4.6.12.18 (2019-07-03 build)
        │   └── TranskeyDecryptEtoE1.5_14.jar       # E2E 복호화 라이브러리 1.5.14
        └── raon_config/
            ├── config.ini             # transkey 동작 설정
            ├── transkey_license.ini   # 라이선스 메타
            ├── transkey__T_license/   # Temporary 라이선스 (현재 사용)
            ├── transkey__P_license/   # Permanent 라이선스 (도메인 *.raonsecure.com → 데모/샘플)
            └── keyboard/              # 자판 종류별 키 매핑 (이미지 + iai/iar 매핑)
                ├── letters/, number/, numberMobile/, numberMobileFX/
                ├── qwerty/, qwertyMobile/, qwertyMobileFX/
```

### 2.3 `web.xml` 핵심 정의

```xml
<servlet>
    <servlet-name>transkeyServlet</servlet-name>
    <servlet-class>com.raonsecure.transkey.servlet.TranskeyServlet</servlet-class>
    <init-param>
        <param-name>iniFilePath</param-name>
        <param-value>/WEB-INF/raon_config/config.ini</param-value>
    </init-param>
    <init-param>
        <param-name>licenseIniPath</param-name>
        <param-value>/WEB-INF/raon_config/transkey_license.ini</param-value>
    </init-param>
    <load-on-startup>1</load-on-startup>
</servlet>
<servlet-mapping>
    <servlet-name>transkeyServlet</servlet-name>
    <url-pattern>/transkeyServlet</url-pattern>
</servlet-mapping>

<filter>
    <filter-name>CorsFilter</filter-name>
    <filter-class>org.apache.catalina.filters.CorsFilter</filter-class>
    <init-param>
        <param-name>cors.allowed.origins</param-name>
        <param-value>*</param-value>          <!-- 전 도메인 허용 -->
    </init-param>
    ...
</filter>
```

### 2.4 `config.ini` 주요 항목

```ini
limitTime=0
useSession=false                                  # 세션리스 모드
isPlainTextMode=0
useToken=true
useCORS=false                                     # web.xml 의 CorsFilter 가 처리
delimiter = $
encDelimiter = ,
pbUserIV = raonsecuretransk
ranData = raonsecure

ExE2E_algorithm_bomapp = block                    # ServerToServer E2E (block 모드)
ExE2EKey_bomapp = /Users/zard21/development/IdeaProjects/secure_servlet/web/WEB-INF/raon_config/transkey__T_license/Private2048.key
```

> ⚠️ **`ExE2EKey_bomapp`** 에 개발자 zard21 의 macOS 로컬 경로(`/Users/zard21/...`) 가 그대로 박혀 있다. **2026-05-19 SSM 검증 결과**: 운영 컨테이너에 `/Users` 디렉토리 자체가 없음에도 vkey 가 5년+ 가동 중. 즉 `ExE2E_algorithm_bomapp=block` 모드는 실제 호출 경로가 아니거나, 라이브러리가 키 부재를 옵셔널로 처리하는 것으로 보임. Spring Boot 부활 시 이 키 경로는 안전하게 제거하거나 진짜 경로로 매핑 가능.

### 2.5 라이선스 상태 (2026-05-19 SSM 검증으로 확정)

리포에 포함된 데모 라이선스(`*.raonsecure.com`) 와 **실제 운영 라이선스가 다르다**. SSM 으로 PROD 컨테이너 (`i-03f0178089f760c6f`, `/was/run/bomapp-vkey/webapps/ROOT/WEB-INF/raon_config/transkey__P_license/`) 에서 추출한 결과:

| 항목 | 값 |
|------|----|
| `transkey_license.ini` 의 `license.type` | **`p`** (permanent — 정식 라이선스 모드 활성) |
| Server 인증서 Subject | **`C=KR, O=bomapp, CN=T=P&D=[*.bomapp.co.kr]`** |
| Issuer | `C=KR, O=RaonSecure Co., Ltd., OU=Quality Assurance` |
| 발급일 / 만료일 | 2019-08-19 ~ **2049-08-11 (30년 영구 라이선스)** |
| CA 인증서 | RaonSecure self-signed root, 2013-02-07 ~ 2043-01-31 |
| 인증서 체인 | `openssl verify` 통과 |
| 개인키/인증서 페어 | modulus 일치 — 유효 |
| `domain.inf` 텍스트 | `localhost,10.0.0.72,*.raonsecure.com` (stale — 실 인증서 CN 과 불일치) |
| SHA-256 fingerprint (Server) | `3C:3D:40:4F:9A:77:57:A9:64:54:4C:7F:80:7F:B3:38:C8:44:83:91:11:3B:FB:19:6D:4D:FF:8A:7A:14:8C:1C` |

운영 라이선스 파일 7개 + `transkey_license.ini` 가 권한 0600 으로 로컬 (`~/Downloads/bomapp-vkey-license-prod/P/`) 에 추출됨. `*.bomapp.co.kr` 와일드카드라 **DEV(`dev-vkey.bomapp.co.kr`) / STG / PROD(`vkey.bomapp.co.kr`) 모두 동일 라이선스로 커버**. 갱신 우려 사실상 없음 (2049년 만료).

> 잔재 발견: `transkey__T_license/` 에는 다른 회사 (`O=HahaSavings`, T 라이선스, 2020-09-16 ~ 2021-09-16 만료) 의 라이선스가 들어 있음. `license.type=p` 모드라 미사용이지만 운영 컨테이너에 잘못 들어 있는 상태. 새 빌드 시 T 디렉토리 자체를 빼는 것 권장.

### 2.6 라이선스 번들 7개 파일의 의미

라온이 발급한 표준 X.509 PKI 라이선스 번들 — 5가지 역할 + 2가지 포맷 중복:

| 파일 | 역할 | 포맷 | 실 사용 |
|------|------|------|:-:|
| `ca.crt` | 라온 CA 인증서 (체인 검증) | PEM | ✅ |
| `Server2048.pem` | 서버 라이선스 인증서 (CN=라이선스 등재 도메인) | PEM | ✅ 둘 중 하나 |
| `Server2048.der` | 동일 인증서 (DER 바이너리) | DER | ✅ 둘 중 하나 |
| `Private2048.key` | 서버 개인키 (라이선스 페어의 비밀 절반) | PEM/PKCS#1 | ✅ 둘 중 하나 |
| `Private2048.key.der` | 동일 개인키 (PKCS#8 DER) | DER | ✅ 둘 중 하나 |
| `Server2048.csr` | 인증서 발급 요청서 (2019-08-19 신청 시 생성) — 발급 후 기능적 의미 없음 | PEM | ❌ historical |
| `domain.inf` | 도메인 텍스트 힌트 | text | ⚠ stale, 실 영향 미확정 |

**PEM/DER 중복 이유**: 라온 라이브러리가 자바 버전·JCE provider 별로 PEM 또는 DER 중 어느 것을 로딩할지 모르니 양쪽 다 동봉하는 안전망. 실 사용 시 라이브러리가 우선순위에 따라 1개만 읽음.

→ Spring Boot 부활 시 **7개 전부 그대로 동봉** 권장 (라이브러리 동작 변경 없음). `domain.inf` 만 `*.bomapp.co.kr` 로 정정하면 cosmetic 개선.

---

## 3. 관련 PoC 리포: `bomapp-vkey`

| 항목 | 값 |
|------|----|
| URL | https://github.com/bomapp-inc/bomapp-vkey |
| 첫 커밋 | 2020-06-04 11:31 KST (`transkey_servlet` 의 4분 뒤) |
| 커밋 수 | 1 |
| 작성자 | 동일 (zard21) |
| 빌드 | Maven (`mvnw` 포함) |
| 산출물 | `kr.co.bomapp:securekey:0.0.1-SNAPSHOT` (Spring Boot 2.2.1 + Java 8) |
| 운영 배포 | ❌ (SSM 으로 검증한 PROD-BACK 의 PID 1205 는 Tomcat WAR 이며 `securekey-*.jar` 은 발견되지 않음) |

### 3.1 구조

```
bomapp-vkey/
├── pom.xml                            # spring-boot-starter-parent 2.2.1.RELEASE
├── mvnw, mvnw.cmd, .mvn/              # Maven wrapper
└── src/
    ├── main/
    │   ├── java/kr/co/bomapp/securekey/
    │   │   ├── SecureKeyApplication.java        # @SpringBootApplication 진입점
    │   │   ├── config/ServletRegistrationConfig.java   # Raon TranskeyServlet 을 ServletRegistrationBean 으로 등록 (URL: /transkeyServlet)
    │   │   └── controller/SecureKeyController.java     # @PostMapping("/securekey") - decode → DecryptEtoEBlock
    │   └── webapp/WEB-INF/raon_config/           # transkey_servlet 과 동일한 설정 구조
    └── test/java/kr/co/bomapp/securekey/SecureKeyApplicationTests.java   # 빈 @SpringBootTest
```

### 3.2 transkey_servlet 과의 차이

| 측면 | transkey_servlet | bomapp-vkey |
|------|------------------|----------------------|
| 빌드 | IntelliJ artifact, 의존성 jar 직접 포함 | Maven, `com.raonsecure:transkey:1.0.0` Maven 좌표 (사설 저장소 필요) |
| 진입점 | Tomcat 의 `/transkeyServlet` (web.xml) | Spring Boot 의 `ServletRegistrationBean` 으로 동일 `/transkeyServlet` + REST `POST /securekey` 추가 |
| 세션 | `useSession=false` | `useSession=true` |
| CORS | `org.apache.catalina.filters.CorsFilter` (모든 origin) | 없음 (Spring 기본) |
| 추가 기능 | 데모 JSP 다수 | `SecureKeyController.getEncodedValue()` 가 `TransKey.decode + TranskeyEtoE.DecryptEtoEBlock` 을 한 번에 처리하여 ResponseEntity 반환. 단, 개인 키 경로 하드코딩 |

### 3.3 결론: 미완성 PoC

`bomapp-vkey` 는 **같은 날 4분 차이로 만든 Spring Boot 포팅 시도**이며 다음 이유로 **미완성 / 미배포** 로 판단:

1. 초기 커밋 후 추가 커밋이 없다 (5년+ 무변경).
2. `SecureKeyController.java:21-22` 에 개발자 로컬 절대경로가 그대로 남아 있다.
3. 사설 Maven 좌표 `com.raonsecure:transkey:1.0.0` 의 저장소가 명시되지 않아 빌드 불가 (현재 상태로 `mvn package` 시도 시 의존성 해결 실패 예상).
4. PROD-BACK SSM 검증 결과 가동 중인 자바 프로세스 어디에도 `securekey-*.jar` 형태가 없다 — `bomapp_oauth-0.1.0.jar`, `bomappmydata-0.0.1-SNAPSHOT.jar` 패턴이 있는데도 securekey 는 부재.

> **신규 개발/리뉴얼 시 의사결정 포인트**: (a) 현재 servlet WAR 유지하며 보안 패치(Tomcat 9.0.45 EOL 2024-12-31, Java 1.8 OpenJDK 무료 지원 종료 임박) 만 적용, (b) 이 PoC 를 베이스로 Spring Boot WAR 로 재기동, (c) next-backend 의 별도 모듈로 흡수. CLAUDE.md 의 "레거시에 신규 기능 추가 지양" 원칙에 따라 (c) 가 장기 방향.

---

## 3.4 벤더 컨택 (라온시큐어)

> 출처: 노션 "[⌨ 보안키보드](https://www.notion.so/432724d059c543c3887a48b6638da1b8)" 2021-07-30 기록. **5년 묵은 정보** — 메일 바운스 시 대표 채널로 우회.

| 구분 | 정보 |
|------|------|
| 1차 컨택 (Technical Support) | **장지수(Jisu Jang)** Technical Support Team II<br>M: +82-10-5337-9406<br>T: +82-70-8240-3649<br>E: [jsjang@raoncorp.com](mailto:jsjang@raoncorp.com) |
| 대표 문의 (우회용) | TEL 02-561-4545 / [salesplan@raoncorp.com](mailto:salesplan@raoncorp.com) |
| 영업 (해외) | [overseasbiz@raon.com](mailto:overseasbiz@raon.com) |

같은 노션 페이지에 다음 자산이 첨부되어 있음 (모바일 라인 작업 시 활용. **본 서버 부활 작업과는 무관**):

- **`license_mtranskey.rsl`** — 라온 RSL 포맷의 라이선스. 디코드 결과 `PRODUCT_NAME=TouchEn mTranskey` (모바일 가상키패드), `OS=[ANDROID,IOS]`, `APP_ID=[com.rv2.bomapp.*, kr.co.bomapp.iOSBomappBeta.*]` — **본 서버(PC TouchEn Transkey) 와는 다른 제품 라인**. 본 서버는 PEM/DER X.509 라이선스를 사용. 발급자 `dhkim0306@raonsecure.com` (장지수와 별개 컨택).
- **`raon_200717.zip` (135MB)** — "TouchEn mTranskey CS v4.6.8.0" 클라이언트 SDK. Android(aar/jar/LicenseSDK) + iOS(Framework/Library/LicenseSDK) + 문서만 포함. **서버 모듈 부재** — 서버 부활에 직접 사용 불가. `transkey_servlet/web/WEB-INF/lib/` 의 두 jar 는 PC Transkey 제품군이며 별도 출처.

| 추가 컨택 | 정보 |
|----------|------|
| 라이선스 발급자 | [dhkim0306@raonsecure.com](mailto:dhkim0306@raonsecure.com) (mTranskey 라이선스 발급. 서버 PEM 라이선스 갱신/재발급 시도 시 1차 시도 대상) |

## 4. 비즈니스 컨텍스트 (출처: 노션)

| 항목 | 출처 | 내용 |
|------|------|------|
| 용도 | 노션 "인프라" (2025-10-15) | "bomapp-vkey : 청구할 때 주민번호 위한 가상키보드. 바이너리 파일 통으로 가지고 있어서 실행만 하면 됨" |
| 운영 위치 변경 | 노션 "PROD-ETC-API WAS로 통합" (2024-02-20) | 별도 서버 (`10.10.10.51`, `10.10.10.52`) → `api-was2 (10.1.1.20)` 로 이전 완료 |
| Git Repository 등록 | 노션 "BM 운영 구성 / Git Repository" (2022-01-05) | URL `https://github.com/Bomapp/transkey_servlet`, 외부 URL `https://vkey.bomapp.co.kr`, 서버 설명 "보안키보드", 서버 IP `10.10.10.51`/`10.10.10.52` |
| CloudFront 흔적 | 노션 "Cloudfront 걷어내기" (2024-09-11) | 과거 `cf-vkey.bomapp.co.kr` 가 CloudFront 거쳐 vkey.bomapp.co.kr 으로 가던 흐름을 정리함 |
| 도입 시기 | 노션 "보안키보드" (2020-09-07, 2021-07-30, 2021-09-30), "웹 가상키패드 적용" (2020-01-17) | 2020-01 ~ 2021-09 에 걸쳐 단계적 도입. iOS 용 `TouchEn mTranskey V4.6 API_Manual` 문서 보관됨 |

---

## 5. 운영 / 검증 (2026-05 기준)

자세한 SSM Run Command 검증 결과는 [`runtime-verification.md §2.6`](../runtime-verification.md#26-vkey-bomapp-vkey-상세-2026-05-19-추가) 참조.

요약:
- 컨테이너 Up 3 years (재기동 없음, 동일 컨테이너에서 jar/WAR 만 수동 운영).
- `enable_execute_command = false`, awslogs 미설정 → 가시성 매우 낮음.
- 7일 ALB log 분석 결과 vkey 도메인 트래픽은 정상 (boomtable에 별도 분포는 [`runtime-verification.md §4`](../runtime-verification.md#4-7일-alb-access-log-분석-2026-04-30--2026-05-06) 의 다른 도메인 분석을 참고하되 vkey 자체는 별도 측정 필요).

### 5.1 미해결 / 검증 필요

1. 운영 환경의 실제 라이선스 파일 (도메인 `vkey.bomapp.co.kr` 매칭 여부) — 리포의 데모 라이선스 (`*.raonsecure.com`) 와 다른 파일이 컨테이너에 주입되어 있는지.
2. 운영 환경의 `ExE2EKey_bomapp` 실제 경로 — config.ini 의 하드코딩 경로(`/Users/zard21/...`) 가 어떻게 해결되는지 (override 인지, symlink 인지).
3. 두 번째 PROD-BACK 인스턴스 (`i-09e36b30bad90990d`) 에서도 동일하게 떠 있는지.

---

## 6. 현대화 / 배포 베스트 프랙티스 평가 (2026-05-19 조사)

### 6.1 라온시큐어가 제공하는 공식 배포 형태

웹 조사 결과 (라온시큐어 공식 다운로드, 네이버 클라우드 마켓플레이스, 2022 년 외부 설치 가이드, Maven Central 검색):

| 항목 | 현재 시점(2026-05) 라온의 공식 모델 |
|------|--------------------------------------|
| 산출물 형태 | **jar/war + 라이선스 파일** 수동 배포 (전통적) |
| Maven 좌표 | **Maven Central 미공개**. `com.raonsecure:transkey:*` 좌표는 라온 사설 저장소 또는 jar 수동 install 전제 |
| Docker / OCI 이미지 | **공식 제공 없음**. 네이버 클라우드 마켓플레이스 (`ncloud.com/marketplace/TouchenmTranskey`) 에 SaaS 라인이 있으나, 페이지 명세상 클라이언트 설치파일 + "E2E 옵션 선택 시 WAS 에 서버 모듈 설치" 표현 → 여전히 WAR 모델 |
| Spring Boot starter | **없음**. 외부 가이드들은 모두 Servlet/`web.xml` 방식 |
| 가이드 갱신 | 가장 최근 외부 가이드(2022-06-20 gist) 도 `log4j 1.2.17` + Servlet/`web.xml` 기준 — 신규 권장 아키텍처 부재 |

**결론**: 라온은 솔루션 벤더로서 **여전히 jar/war + 사설 라이선스** 모델을 유지한다. 클라우드 네이티브(Docker 이미지/Helm chart) 형태로 제품을 공식 배포하지 않는다. 따라서 "라온이 제공하는 모던 배포물로 갈아끼우기" 는 불가능하며, **자체 패키징/운영 현대화는 고객사 측 책임**이다.

### 6.2 현재 운영 형태의 문제점

| 항목 | 현재 상태 | 위험 |
|------|----------|------|
| Tomcat 버전 | **9.0.45** (2021 빌드, 5년+ 미패치) | 9.0.109 까지 64 마이너 뒤짐. **2025-10 CVE-2025-55752 (Path Traversal/RCE), CVE-2025-55754, CVE-2025-61795** 등 critical 패치 미적용. **인터넷 노출 서비스로서 즉각 보안 위험.** |
| Java 버전 | **JDK 1.8** | OpenJDK 8 무료 지원 종료 임박. EOL 라이브러리 누적. |
| 빌드 시스템 | **IntelliJ artifact** (`secure_servlet.iml`), Maven/Gradle 없음 | 재현 가능한 빌드 불가. CI 없음. 빌드 머신 손실 시 재배포 불가. |
| 컨테이너 | **3년+ 공용 컨테이너** (`next-backend-was:1.1`) 안에서 다른 5+개 JVM 과 동거 | vkey 의 OOM/스레드 폭주 → 동일 컨테이너의 `bomapp-api`/`wings-api`/`open-api`/`webview` 등 핵심 서비스에 전파. 격리 없음. |
| 로깅 | **awslogs 미설정**, `enable_execute_command=false` | 표준 ECS 로그 수집 안 됨, SSM exec 차단 → 운영 가시성 0, 디버깅 불가 |
| 설정 하드코딩 | `config.ini` 의 `ExE2EKey_bomapp` 가 개발자 macOS 절대경로 (`/Users/zard21/...`) | 운영 컨테이너에 `/Users` 디렉토리 자체 없음에도 가동 중 (2026-05-19 SSM). `ExE2E block 모드 미사용` 으로 추정. Spring Boot 부활 시 제거 또는 진짜 경로 매핑 가능. |
| 라이선스 관리 | 리포에는 데모 라이선스(`*.raonsecure.com`). **운영 컨테이너에는 30년 영구 P 라이선스 (`*.bomapp.co.kr`, 2049-08-11 만료) 별도 주입됨** | 라이선스가 코드와 분리되어 운영자만 알고 있던 상태. 2026-05-19 SSM 으로 추출 완료 — 새 ECS task 에서는 Secrets/볼륨 마운트로 외부화 권장 |
| 고가용성 | **vkey 가 단일 인스턴스 (`i-03f0178089f760c6f`) 에서만 가동** (PROD-BACK 의 두 번째 인스턴스에는 vkey 부재) | SPOF — 해당 인스턴스 다운 시 가입/인증/청구/마켓 다중 플로우 즉시 다운. 새 ECS service 신설 시 desired_count ≥ 2 + multi-AZ 권장 |
| 운영 형태 | `/was/data/bomapp-vkey/vkey.tar` (126MB, 2023-04-04) 를 `restart.sh` 로 untar → `/was/run/bomapp-vkey/` 에서 가동. **노션 인프라 페이지의 "바이너리 통으로 가지고 있어서 실행만 하면 됨"** 설명과 정확히 일치 | 2023-04-04 이후 갱신 없음 (3년+). 진정한 의미의 "frozen blob" 운영 |
| CORS | `*` 전 도메인 허용 | 일반적으로 보안 키보드 서버는 가능한 origin 을 좁히는 것이 권장 |

### 6.3 권고 (단계별)

라온이 모던 배포물을 주지 않으니, **자체 컨테이너화 + 격리 + 운영 가시성 확보** 가 핵심 방향이다.

**단기 (Quick Win — 1~2주)**
1. **Tomcat 보안 패치**: 9.0.45 → **9.0.109+** 업그레이드 (WAR 자체는 그대로). EOL CVE 노출 차단.
2. **awslogs 활성화**: ECS task definition 에 `awslogs` driver 추가. 운영 가시성 1차 확보.
3. ~~**운영 라이선스 위치 확인**~~ — **2026-05-19 완료**. `*.bomapp.co.kr` 30년 P 라이선스 (만료 2049-08-11) 추출 완료. SecretsManager 또는 볼륨 마운트로 외부화 준비됨.

**중기 (Containerization & Isolation — 1~2개월)**
4. **자체 Docker 이미지 빌드**: 베이스는 `tomcat:9.0.109-jdk8-temurin` 또는 `tomcat:9.0.109-jdk17-temurin` (Java 8 → 17 검토). 우리 WAR + 운영 라이선스 별도 mount.
5. **별도 ECS 서비스로 분리**: PROD-BACK 공용 컨테이너에서 빠져나와 자체 task definition + service + target group 으로 운영. **vkey 장애가 핵심 API 에 전파되지 않도록 격리.** Fargate 또는 별도 EC2 task. 비용/성능 트레이드오프는 별도 검토.
6. **CI 화**: `bomapp-inc/transkey_servlet` 리포에 GitHub Actions 추가. WAR 빌드 → Docker 이미지 빌드 → ECR push → ECS 배포. IntelliJ artifact 의존 제거.

**장기 (Modernization — 분기 단위)**
7. **Spring Boot 화 재검토**: 기존 `bomapp-vkey` PoC 를 베이스로 Spring Boot 2.7.x WAR (라온 jar 가 `javax.servlet` 이라 SB 3.x jakarta 호환 불가). 라온 jar 는 `transkey_servlet/web/WEB-INF/lib/` 의 두 jar 를 system scope 또는 사내 Nexus install. `ServletRegistrationBean` 으로 같은 `/transkeyServlet` 매핑.
8. **next-backend 의 별도 모듈로 흡수 검토**: CLAUDE.md 의 "레거시에 신규 기능 추가 지양" 원칙. 다만 라온 라이브러리 라이선스/배포 모델 때문에 next-backend Gradle 빌드에 흡수 가능 여부는 별도 검증 필요. (라온 jar 가 사설 저장소에 등록되어 있다면 가능.)
9. **CORS 좁히기**: `*` → `*.bomapp.co.kr` 등 도메인 화이트리스트.

### 6.4 결론

**현재 배포 방식은 best practice 가 아니다.** 2010년대 초반의 전형적인 SI 운영 패턴이며, 보안 패치/격리/가시성/재현 빌드 모든 측면에서 현대 표준에 미달한다. 다만 **라온시큐어 자체가 클라우드 네이티브 배포물을 제공하지 않으므로** "벤더 권장 모던 배포로 교체" 는 옵션이 아니고, **자체 컨테이너화 + ECS 격리 + CI** 를 우리가 직접 만들어야 한다. 최소한의 quick win 으로 Tomcat 패치 + awslogs 활성화는 즉시 가능하며, 우선순위가 높다.

---

## 7. 변경 시 영향 범위

`bomapp-vkey` 가 다운되거나 응답 지연 시:

- 보맵 앱/웹의 **보험금 청구 플로우 중 주민번호 입력 단계** 실패.
- ALB:443 priority 10 → TG `prod-back-ecs-host-http-8080` 의 502/504 응답.
- 동일 컨테이너 내의 다른 jar (`bomapp-api`, `wings-api`, `open-api`, `bomapp_webview_server`, `bomapp_mydata`, `bomapp_oauth`) 와 **JVM 자원을 공유** — vkey 의 JVM 문제가 OOM/스레드 폭주로 번지면 같은 컨테이너의 다른 서비스에도 영향 가능 (격리 안 됨).

---

## 8. 관련 문서

- [`runtime-verification.md §2.6`](../runtime-verification.md#26-vkey-bomapp-vkey-상세-2026-05-19-추가) — SSM 검증 결과
- [`runtime-verification.md §3`](../runtime-verification.md#3-호스트-헤더--실제-jar-매핑-검증) — 호스트헤더 → jar 매핑
- [`architecture.md §6.1`](../architecture.md#61-public--app-알리아스도-쉬운-식별자-우선) — 도메인 라우팅 매트릭스
- [`services/legacy-backend.md §3.2`](./legacy-backend.md#32-도메인-legacy-backend-잔존-영역) — legacy-backend 가 *아님* 을 명시
- 노션 "[BOMAPP 인프라](https://www.notion.so/28d673e85b34804eb7ffef90dc2c60af)" 페이지
- 노션 "[Git Repository / transkey_servlet](https://www.notion.so/6b506857a3d743fca7869530ce0ace50)" 항목

---

## 9. Spring Boot 부활본 동등성 검증 (BV-2, 2026-05-20)

**검증 대상**

| 구분 | 설명 |
|------|------|
| 로컬 가동본 | `/Users/justin/Projects/bomapp-vkey` main 브랜치 (BV-1 머지 상태). `securekey-0.0.1-SNAPSHOT.jar` (Spring Boot 2.7.18 / Java 21 / embedded Tomcat 9.0.83). |
| PROD | `vkey.bomapp.co.kr` / `i-03f0178089f760c6f` 컨테이너 내 `/was/run/bomapp-vkey` (Tomcat 9.0.45 WAR). SSM Run Command 로 응답 캡쳐. |

**빌드 환경**

```
Java  : 21.0.10 (로컬), 1.8 (PROD)
Maven : ./mvnw (wrapper, apache-maven-3.6.2)
빌드  : mvn clean package -DskipTests → BUILD SUCCESS (1.25 s)
라이선스: src/main/webapp/WEB-INF/raon_config/transkey__P_license/ 에 P 라이선스 8개 배치
         (~/Downloads/bomapp-vkey-license-prod/P/ 에서 복사 — git commit 제외)
기동 : java -DRAON_LICENSE_PATH=~/Downloads/bomapp-vkey-license-prod \
           -jar target/securekey-0.0.1-SNAPSHOT.jar --spring.profiles.active=local
```

---

### 9.1 A — Startup 검증

| 항목 | 결과 |
|------|:----:|
| `mvn clean package -DskipTests` 성공 | ✓ |
| `Tomcat started on port(s): 8080 (http)` 로그 | ✓ |
| `[transkey] log : TranskeyServlet init...` 로그 | ✓ |
| `[transkey] log : Transkey setConfigMap.` 로그 | ✓ (config.ini 정상 로드) |
| 라이선스 검증 ERROR | 0건 ✓ |
| 기동 소요 시간 | 약 2.1 s |

로그 증거 (기동 시):

```
[transkey] log : TranskeyServlet init...
[transkey] log : Transkey setConfigMap.
INFO  o.s.b.w.embedded.tomcat.TomcatWebServer : Tomcat started on port(s): 8080 (http) with context path ''
INFO  k.c.b.securekey.SecureKeyApplication    : Started SecureKeyApplication in 2.129 seconds
```

---

### 9.2 B — 자판 매핑 동작 검증

`loadOnStartup=1` 설정으로 TranskeyServlet init 이 앱 기동 시 즉시 실행되고 자판 설정(`setConfigMap`)이 완료됨이 로그로 확인.

```bash
# getKeyboard op — 로컬 및 PROD 모두 동일 결과
curl -s -o /tmp/local-keyboard-qwerty.txt -w "HTTP %{http_code} / size: %{size_download}" \
  "http://localhost:8080/transkeyServlet?op=getKeyboard&kbdType=qwerty"
# → HTTP 200 / size: 0  (로컬)
# → HTTP 200 / size: 0  (PROD — curl https://vkey.bomapp.co.kr/...)
```

`op=getKeyboard` 가 200 / Content-Length: 0 을 반환하는 것은 **로컬과 PROD 동일 동작**이다. 자판 이미지(iai/iar 파일)는 클라이언트 JS 가 `op=getToken` 으로 세션을 초기화한 뒤 렌더링 단계에서 별도 호출하는 방식이므로, 파라미터 없는 `getKeyboard` 의 빈 응답은 정상.

라이브러리가 `.iai/.iar` 파일을 정상 로드했음은 `setConfigMap` 성공 + `op=getInitTime` 동작으로 간접 확인:

```bash
curl -s "http://localhost:8080/transkeyServlet?op=getToken"
# → var TK_requestToken=0;   ✓

curl -s "http://localhost:8080/transkeyServlet?op=getInitTime"
# → var decInitTime='202605200947';var initTime='7214012aa3049d20e02ae858';var limitTime=0;var useSession=false;  ✓
```

자판 파일 경로 설정 (`config.ini`):

```ini
qwerty=/WEB-INF/raon_config/keyboard/qwerty
number=/WEB-INF/raon_config/keyboard/number
letters=/WEB-INF/raon_config/keyboard/letters
qwertyMobile=/WEB-INF/raon_config/keyboard/qwertyMobileFX
numberMobile=/WEB-INF/raon_config/keyboard/numberMobileFX
```

TldScanner 로그에서 해당 경로들이 모두 스캔됨 확인 (keyboard/qwerty/, keyboard/number/ 등 — TLD 아니므로 "No TLD found" 정상).

**시나리오 (a)/(b) fix 불필요**: 파일이 `src/main/webapp/WEB-INF/raon_config/keyboard/` 에 존재하고 embedded Tomcat 의 Document root 가 `src/main/webapp` 으로 설정됨 → `ServletContext.getRealPath()` 정상 작동.

---

### 9.3 C — iniFilePath / licenseIniPath getRealPath() 동작

```
Document root: /Users/justin/Projects/bomapp-vkey/src/main/webapp
```

embedded Tomcat 이 `src/main/webapp` 을 webapp base 로 인식하여, TranskeyServlet 의 `ServletContext.getRealPath("/WEB-INF/raon_config/config.ini")` 가 아래 실존 경로로 해소됨:

```
/Users/justin/Projects/bomapp-vkey/src/main/webapp/WEB-INF/raon_config/config.ini
/Users/justin/Projects/bomapp-vkey/src/main/webapp/WEB-INF/raon_config/transkey_license.ini
/Users/justin/Projects/bomapp-vkey/src/main/webapp/WEB-INF/raon_config/transkey__P_license/  (8개 파일)
```

TranskeyServlet init 성공 (`TranskeyServlet init...` + `Transkey setConfigMap.` 로그) 으로 getRealPath() null 반환 없음이 간접 확인됨.

**주의 (Dockerfile BV-3 가이드)**: `java -jar` 실행 경로가 `src/main/webapp` 이 없는 디렉토리인 경우, embedded Tomcat 의 `documentRoot` 가 jar 와 같은 디렉토리의 `src/main/webapp` 을 탐색한다. **jar 단독 배포 시 `src/main/webapp/` 를 jar 와 함께 COPY 해야 getRealPath() 가 non-null 을 반환한다.** (→ §9.6 BV-3 설계 가이드 참조)

---

### 9.4 D — 호출자 응답 패턴 비교

#### D-1. 루트(/) 응답 diff

| 구분 | 응답 |
|------|------|
| **로컬** (`http://localhost:8080/`) | `{"status":404,"error":"Not Found","path":"/"}` (89 bytes) |
| **PROD SSM** (`curl http://127.0.0.1:8080/`) | HTML 데모 페이지 (1,146 bytes) |

**차이 원인**: PROD Tomcat WAR 의 `ROOT/` 컨텍스트에 `index.html` 데모 파일이 포함되어 있으나, Spring Boot 부활본은 `src/main/webapp/` 에 루트 HTML 없음. 기능상 차이 없음 — 실 호출자(`next-frontend`)는 루트 `/` 를 사용하지 않고 `/transkeyServlet?op=...` 엔드포인트만 사용.

PROD HTML 파일 참조용 (`/tmp/prod-root.html`):

```html
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "...">
<html xml:lang="ko" ...>
<head>
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/2.2.4/jquery.min.js"></script>
    <script type="text/javascript" src="/TouchEn/transkey/transkey.js"></script>
    <link rel="stylesheet" type="text/css" href="/TouchEn/transkey/transkey.css" />
</head>
<body onload="initTranskey();">
<form name="frm" id="frm" action="/transkeyServlet/decode" method="post">
    <input type="password" name="pwd2" id="pwd2" data-tk-useinput="true" data-tk-kbdType="number" .../>
    <input type="submit" onclick="tk.fillEncData();"></input>
</form>
</body>
</html>
```

#### D-2. transkey.js sha256 — 완전 일치

```bash
# 로컬
curl -s "http://localhost:8080/TouchEn/transkey/transkey.js" | shasum -a 256
# d94351fec53ffcff7432cd389dbd41d97f74e3726e6b81a09248d2145c808076  -

# PROD (공개 URL)
curl -s "https://vkey.bomapp.co.kr/TouchEn/transkey/transkey.js" | shasum -a 256
# d94351fec53ffcff7432cd389dbd41d97f74e3726e6b81a09248d2145c808076  -

# PROD SSM (컨테이너 내부)
# d94351fec53ffcff7432cd389dbd41d97f74e3726e6b81a09248d2145c808076  -
```

**3개 경로 모두 동일 sha256.** `src/main/resources/static/TouchEn/transkey/transkey.js` 파일이 PROD WAR 의 정적 파일과 동일한 바이너리임을 확인.

#### D-3. 핵심 op 비교

| op | 로컬 | PROD SSM | 일치 |
|----|------|----------|:----:|
| `op=getToken` | `var TK_requestToken=0;` | `var TK_requestToken=0;` | ✓ |
| `op=getInitTime` | `var decInitTime='...'; var initTime='...'; var limitTime=0; var useSession=false;` | 동일 패턴 | ✓ |
| `op=getKeyboard&kbdType=qwerty` | HTTP 200 / 0 bytes | HTTP 200 / 0 bytes | ✓ |

---

### 9.5 E — CORS 동작

```bash
# 허용 origin (bomapp.co.kr 서브도메인)
curl -I -H "Origin: https://www.bomapp.co.kr" \
     -H "Access-Control-Request-Method: POST" \
     -X OPTIONS http://localhost:8080/transkeyServlet
```

응답 헤더:

```
HTTP/1.1 200
Access-Control-Allow-Origin: https://www.bomapp.co.kr
Access-Control-Allow-Methods: GET,POST,HEAD,OPTIONS,PUT
Access-Control-Allow-Credentials: true
Access-Control-Max-Age: 3600
```

```bash
# 거부 origin (외부 도메인)
curl -I -H "Origin: https://evil.example.com" -X OPTIONS http://localhost:8080/transkeyServlet
```

응답: `HTTP/1.1 403` — `Access-Control-Allow-Origin` 헤더 없음.

PROD Tomcat WAR 의 CORS 설정(`web.xml`: `cors.allowed.origins=*`)과 달리, Spring Boot 부활본은 `CorsConfig.java` 에서 `*.bomapp.co.kr` 패턴으로 **origin 제한이 강화**된 상태. 보안 측면에서 개선임.

---

### 9.6 F — Actuator

```bash
curl http://localhost:8080/actuator/health
# {"status":"UP"}  ✓
```

PROD Tomcat WAR 에는 Actuator 없음. Spring Boot 부활본에서 신규 추가.

---

### 9.7 발견된 미세 차이 정리

| 항목 | PROD (Tomcat 9.0.45 WAR) | 로컬 Spring Boot | 기능 영향 |
|------|--------------------------|-----------------|:--------:|
| Java 버전 | 1.8 | 21.0.10 | 없음 (javax.servlet 기반 라이브러리 동작 동일) |
| Tomcat 버전 | 9.0.45 | 9.0.83 (embedded) | 없음 |
| 루트(`/`) 응답 | HTML 데모 | 404 | **없음** (실 호출자 미사용 경로) |
| CORS 정책 | `*` 전 도메인 | `*.bomapp.co.kr` 패턴 | **개선** (더 안전) |
| Actuator | 없음 | `/actuator/health` | 신규 기능 (개선) |
| 라이선스 로딩 | filesystem (WAR 내 경로) | getRealPath() via webapp dir | 동작 동일 |
| `transkey.js` sha256 | `d94351fe...` | `d94351fe...` | **완전 일치** |
| `getToken` / `getInitTime` 응답 | 정상 | 정상 (동일 패턴) | **완전 일치** |

---

### 9.8 Fix 사항

**코드 fix 없음.** BV-1 머지 상태의 main 브랜치가 A~F 모든 검증을 통과했으며, `feature/bv-2-equivalence-fix` 브랜치 생성 불필요.

---

### 9.9 BV-3 (Dockerfile) 설계 가이드

본 검증으로 결정된 packaging 전략:

| 항목 | 결정 |
|------|------|
| jar 단독 가동 가능 여부 | **단독 가동 가능** (단, `src/main/webapp/` 동반 필요) |
| Dockerfile COPY 필요 항목 | `COPY target/securekey-0.0.1-SNAPSHOT.jar /app/securekey.jar` + **`COPY src/main/webapp/ /app/src/main/webapp/`** (embedded Tomcat 의 document root 가 jar 실행 디렉토리 기준 `src/main/webapp/` 를 찾음) |
| 라이선스 파일 | `/app/raon_config/transkey__P_license/` 에 secret volume mount. COPY 금지 (git commit 금지와 동일 이유). `transkey_license.ini` 의 `license.pathType=r` + `license.permanent.path=/WEB-INF/raon_config/transkey__P_license` → webapp dir 기준 경로. **또는** 라이선스 디렉토리 전체를 `src/main/webapp/WEB-INF/raon_config/transkey__P_license/` 로 secret mount. |
| 대안 (document root 명시) | `TomcatContextCustomizer` Bean 을 추가하여 `context.setDocBase(...)` 로 document root 를 명시적으로 지정하면 jar 와 webapp 을 분리된 경로에 둘 수 있음. BV-3 에서 선택 가능. |
| 권고 WORKDIR | `/app` |
| 권고 CMD | `java -jar /app/securekey.jar --spring.profiles.active=prod` |

> AIDEV-NOTE: embedded Tomcat 에서 `src/main/webapp/` document root 경로 해소 동작은 `TomcatServletWebServerFactory.getWebServer()` → `prepareContext()` → `docRoot = getValidDocumentRoot()` 체인에서 결정됨. jar 실행 시 현재 디렉토리의 `src/main/webapp` 을 찾으므로, WORKDIR 과 COPY 경로가 정확히 맞아야 한다.
