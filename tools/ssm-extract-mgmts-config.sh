#!/bin/sh
# ============================================================================
# ssm-extract-mgmts-config.sh   ★ 로컬(노트북)에서 실행 ★
#   노트북 → SSM(send-command) → prod 호스트에서 mydata-mgmts-api 설정값 추출 →
#   결과를 로컬 터미널로 가져와 출력. (호스트 직접 로그인 불필요)
#
# 사용:
#   sh tools/ssm-extract-mgmts-config.sh                 # 기본 인스턴스/리전
#   sh tools/ssm-extract-mgmts-config.sh i-xxxxxxxx      # 인스턴스 지정
#   AWS_PROFILE=prod AWS_REGION=ap-northeast-2 sh tools/ssm-extract-mgmts-config.sh
#   SHARE_ONLY=1 sh tools/ssm-extract-mgmts-config.sh    # 비번 제외([SHARE]만)
#
# 출력 두 블록: [SHARE]=공유가능 / [SECRET]=본인만(SM 주입). 원격은 root로 실행됨.
# ============================================================================
set -u

INSTANCE="${1:-i-03f0178089f760c6f}"
REGION="${AWS_REGION:-ap-northeast-2}"
SHARE_ONLY="${SHARE_ONLY:-0}"

command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI 필요"; exit 1; }

echo "# caller : $(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo '<인증 실패 — AWS_PROFILE 확인>')"
echo "# target : $INSTANCE @ $REGION"
PING=$(aws ssm describe-instance-information --region "$REGION" \
        --filters "Key=InstanceIds,Values=$INSTANCE" \
        --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null)
echo "# SSM    : PingStatus=${PING:-<조회실패>}"
[ "$PING" = "Online" ] || echo "  ⚠ Online 아님 — SSM 에이전트/IAM/인스턴스ID 확인. 그래도 send-command 는 시도함."

# ---- 원격(prod 호스트)에서 root 로 실행될 추출 스크립트 (docker cp 방식) ----
REMOTE=$(cat <<'RSH'
CFG=/was/run/bomapp-mydata-prod/data/application-prod.properties
TMPD=$(mktemp -d 2>/dev/null || echo "/tmp/mg.$$"); mkdir -p "$TMPD" 2>/dev/null
trap 'rm -rf "$TMPD"' EXIT INT TERM
LOCAL=""; C=""
if command -v docker >/dev/null 2>&1; then
  for c in $(docker ps --format '{{.ID}}' 2>/dev/null); do
    if docker cp "$c:$CFG" "$TMPD/app.properties" 2>/dev/null; then
      C="$c"; LOCAL="$TMPD/app.properties"; echo "# 발견: 컨테이너 $c (docker cp)"; break
    fi
  done
fi
if [ -z "$LOCAL" ]; then
  for H in "$CFG" $(find /was /data /opt -name 'application-prod.properties' -path '*mydata*' 2>/dev/null); do
    [ -f "$H" ] && { cp "$H" "$TMPD/app.properties"; LOCAL="$TMPD/app.properties"; echo "# 발견: 호스트 $H"; break; }
  done
fi
if [ -z "$LOCAL" ]; then
  echo "ERROR: application-prod.properties 미발견"
  echo "-- 실행중 컨테이너 --"; docker ps --format '{{.ID}}  {{.Image}}  {{.Names}}' 2>/dev/null
  echo "-- 구 jar cmdline (실제 config 경로) --"; ps -ef 2>/dev/null | grep 'spring.config.location' | grep -v grep
  exit 1
fi
line() { grep -E "^$1=" "$LOCAL" 2>/dev/null | head -n1; }
val()  { _l=$(line "$1"); printf '%s' "${_l#*=}"; }

echo; echo "================ [SHARE] Overmind 공유 가능 (비밀 아님) ================"
for k in spring.datasource.url spring.datasource.username spring.datasource.driver-class-name \
         spring.datasource.hikari.jdbc-url spring.datasource.hikari.username \
         my-data.jwt.private-key-path my-data.jwt.public-key-path ; do
  l=$(line "$k"); [ -n "$l" ] && echo "$l"
done
echo; echo "---- JWT 키파일 sha256 지문 (키 자체 아님 → 공유 가능) ----"
i=0
for k in my-data.jwt.private-key-path my-data.jwt.public-key-path ; do
  p=$(val "$k"); [ -z "$p" ] && continue; i=$((i+1)); kf="$TMPD/k$i"; g=""
  if [ -n "$C" ] && docker cp "$C:$p" "$kf" 2>/dev/null; then g="$kf"; elif [ -f "$p" ]; then g="$p"; fi
  if [ -n "$g" ]; then
    h=$({ sha256sum "$g" 2>/dev/null || shasum -a 256 "$g" 2>/dev/null; } | awk '{print $1}')
    echo "$k  =>  ${h:-<해시실패>}   ($p)"
  else
    echo "$k  =>  <키파일 접근실패>   ($p)"
  fi
done

if [ "${SHARE_ONLY:-0}" = "1" ]; then
  echo; echo "# SHARE_ONLY=1 → [SECRET] 생략 (비번은 별도 추출)"
else
  echo; echo "================ [SECRET] 본인만 — SM 직접 주입, 공유 금지 ================"
  echo "spring.datasource.password = $(val spring.datasource.password)"
  hpw=$(val spring.datasource.hikari.password); [ -n "$hpw" ] && echo "spring.datasource.hikari.password = $hpw"
  echo "# SM: aws secretsmanager put-secret-value --secret-id bomapp/prod/mydata-mgmts-api/db-password --secret-string '<위 password>'"
  echo "# ⚠ 이 비번은 SSM 커맨드 히스토리(본인 AWS계정)에도 남음. 싫으면 SHARE_ONLY=1 로 재실행 후 비번 따로."
fi
RSH
)

# SHARE_ONLY 값을 원격으로 전달 + base64 로 감싸 따옴표/개행 문제 회피
PAYLOAD="SHARE_ONLY=$SHARE_ONLY
$REMOTE"
B64=$(printf '%s' "$PAYLOAD" | base64 | tr -d '\n')

JSON=$(mktemp)
cat > "$JSON" <<EOF
{ "InstanceIds": ["$INSTANCE"],
  "DocumentName": "AWS-RunShellScript",
  "Comment": "BOM-113 mydata-mgmts-api config extract",
  "Parameters": { "commands": ["echo $B64 | base64 -d | sh"] } }
EOF

CID=$(aws ssm send-command --region "$REGION" --cli-input-json "file://$JSON" \
        --query Command.CommandId --output text 2>&1)
rm -f "$JSON"
case "$CID" in
  *-*-*-*-*) : ;;
  *) echo "ERROR: send-command 실패: $CID"; exit 1 ;;
esac
echo "# CommandId: $CID"

aws ssm wait command-executed --region "$REGION" --command-id "$CID" --instance-id "$INSTANCE" 2>/dev/null
S=$(aws ssm get-command-invocation --region "$REGION" --command-id "$CID" --instance-id "$INSTANCE" --query Status --output text 2>/dev/null)
echo "# Status: ${S:-<조회실패>}"
echo "============================ OUTPUT ============================"
aws ssm get-command-invocation --region "$REGION" --command-id "$CID" --instance-id "$INSTANCE" --query StandardOutputContent --output text 2>/dev/null
ERR=$(aws ssm get-command-invocation --region "$REGION" --command-id "$CID" --instance-id "$INSTANCE" --query StandardErrorContent --output text 2>/dev/null)
[ -n "${ERR:-}" ] && { echo "============================ STDERR ============================"; echo "$ERR"; }
