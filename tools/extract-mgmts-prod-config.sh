#!/bin/sh
# ============================================================================
# extract-mgmts-prod-config.sh  (rev2: docker cp 방식 — 컨테이너 내 바이너리 불필요)
#   mydata-mgmts-api PROD 설정값 추출 (BOM-113 ECS 배포 준비)
#
# 구 jar 가 실제 읽는 application-prod.properties 에서 DB datasource / JWT 키경로를
# 뽑아 [SHARE](공유가능) / [SECRET](본인만) 두 블록으로 출력.
#
# 실행:  sudo sh extract-mgmts-prod-config.sh
#
# rev2: WAS 컨테이너가 미니멀 이미지(test/grep 없음)라 docker exec 대신
#       docker cp 로 파일을 호스트에 잠깐 복사 → 호스트 도구로 처리 → 종료 시 삭제.
# ============================================================================
set -u

CFG=/was/run/bomapp-mydata-prod/data/application-prod.properties   # 컨테이너 내부 경로
TMPD=$(mktemp -d 2>/dev/null || echo "/tmp/mgmts.$$")
mkdir -p "$TMPD" 2>/dev/null
trap 'rm -rf "$TMPD"' EXIT INT TERM

LOCAL=""
C=""

# 1) docker cp 로 설정파일 확보 (컨테이너 안에 test/grep/sh 없어도 동작)
if command -v docker >/dev/null 2>&1; then
  for c in $(docker ps --format '{{.ID}}' 2>/dev/null); do
    if docker cp "$c:$CFG" "$TMPD/app.properties" 2>/dev/null; then
      C="$c"; LOCAL="$TMPD/app.properties"
      echo "# 발견: 컨테이너 $c : $CFG (docker cp)"
      break
    fi
  done
fi

# 2) 호스트 직접 탐색 fallback
if [ -z "$LOCAL" ]; then
  for H in "$CFG" $(find /was /data /opt -name 'application-prod.properties' -path '*mydata*' 2>/dev/null); do
    if [ -f "$H" ]; then
      cp "$H" "$TMPD/app.properties" && LOCAL="$TMPD/app.properties"
      echo "# 발견: 호스트 $H"; break
    fi
  done
fi

if [ -z "$LOCAL" ]; then
  echo "ERROR: application-prod.properties 미발견." >&2
  echo "-- 실행중 컨테이너 --" >&2
  docker ps --format '{{.ID}}  {{.Image}}  {{.Names}}' 2>/dev/null >&2
  echo "-- 구 jar 의 실제 --spring.config.location (이 경로를 CFG 변수에 반영) --" >&2
  ps -ef 2>/dev/null | grep 'spring.config.location' | grep -v grep >&2
  exit 1
fi

line() { grep -E "^$1=" "$LOCAL" 2>/dev/null | head -n1; }
val()  { _l=$(line "$1"); printf '%s' "${_l#*=}"; }

echo
echo "================ [SHARE] Overmind 공유 가능 (비밀 아님) ================"
for k in \
  spring.datasource.url \
  spring.datasource.username \
  spring.datasource.driver-class-name \
  spring.datasource.hikari.jdbc-url \
  spring.datasource.hikari.username \
  my-data.jwt.private-key-path \
  my-data.jwt.public-key-path ; do
  l=$(line "$k"); [ -n "$l" ] && echo "$l"
done

echo
echo "---- JWT 키파일 sha256 지문 (키 자체 아님 → 공유 가능, SM PEM 대조용) ----"
i=0
for k in my-data.jwt.private-key-path my-data.jwt.public-key-path ; do
  p=$(val "$k"); [ -z "$p" ] && continue
  i=$((i+1)); kf="$TMPD/key$i"; got=""
  if [ -n "$C" ] && docker cp "$C:$p" "$kf" 2>/dev/null; then got="$kf"
  elif [ -f "$p" ]; then got="$p"
  fi
  if [ -n "$got" ]; then
    h=$( { sha256sum "$got" 2>/dev/null || shasum -a 256 "$got" 2>/dev/null; } | awk '{print $1}')
    echo "$k  =>  ${h:-<해시 실패>}   ($p)"
  else
    echo "$k  =>  <키파일 접근 실패>   ($p)"
  fi
done

echo
echo "================ [SECRET] 본인만 — SM 직접 주입, 공유 금지 ================"
pw=$(val spring.datasource.password)
hpw=$(val spring.datasource.hikari.password)
echo "spring.datasource.password = ${pw:-<없음>}"
[ -n "$hpw" ] && echo "spring.datasource.hikari.password = $hpw"
echo
echo "# SM 주입 예시:"
echo "#   aws secretsmanager put-secret-value \\"
echo "#     --secret-id bomapp/prod/mydata-mgmts-api/db-password \\"
echo "#     --secret-string '<위 password 값>'"
echo "# (임시 복사본 $TMPD 는 스크립트 종료 시 자동 삭제)"
echo "=========================================================================="
