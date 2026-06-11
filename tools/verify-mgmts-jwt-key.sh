#!/bin/sh
# ============================================================================
# verify-mgmts-jwt-key.sh   ★ 로컬(노트북)에서 실행 ★
#   mydata-mgmts-api 호스트 JWT 서명키(/was/env/cert/*.pem) 가
#   SM  bomapp/prod/external-mydata/my-data-rsa-*-pem  와 같은 키쌍인지 판정.
#
#   원리: 양쪽에서 "DER 공개키 sha256 지문"만 산출해 비교.
#         (개인키→공개키 유도, 공개키→공개키 정규화 → 형식차 무시, 키 자료 비노출)
#
# 사용:  sh tools/verify-mgmts-jwt-key.sh
#        AWS_PROFILE=<prod> AWS_REGION=ap-northeast-2 sh tools/verify-mgmts-jwt-key.sh
# ============================================================================
set -u
INSTANCE="${1:-i-03f0178089f760c6f}"
REGION="${AWS_REGION:-ap-northeast-2}"

PRIV_HOST=/was/env/cert/my.data.rsa.pkcs8.key.pem
PUB_HOST=/was/env/cert/my.data.rsa.pkcs8.public.key.pem
SM_PRIV=bomapp/prod/external-mydata/my-data-rsa-private-key-pem
SM_PUB=bomapp/prod/external-mydata/my-data-rsa-public-key-pem

command -v openssl >/dev/null 2>&1 || { echo "ERROR: openssl 필요(로컬)"; exit 1; }
command -v aws     >/dev/null 2>&1 || { echo "ERROR: aws CLI 필요"; exit 1; }

# ---- 1) HOST 측 DER 공개키 지문 (SSM: docker cp 로 키 꺼내 호스트 openssl) ----
REMOTE=$(cat <<RSH
set -u
C=""
for c in \$(docker ps --format '{{.ID}}' 2>/dev/null); do
  if docker cp "\$c:$PRIV_HOST" /tmp/_hpriv.pem 2>/dev/null; then C="\$c"; break; fi
done
if [ -n "\$C" ]; then
  docker cp "\$C:$PUB_HOST" /tmp/_hpub.pem 2>/dev/null
else
  [ -f "$PRIV_HOST" ] && cp "$PRIV_HOST" /tmp/_hpriv.pem
  [ -f "$PUB_HOST" ]  && cp "$PUB_HOST"  /tmp/_hpub.pem
fi
echo "HOST_PRIV_PUBDER=\$(openssl pkey -in /tmp/_hpriv.pem -pubout -outform DER 2>/dev/null | sha256sum | awk '{print \$1}')"
echo "HOST_PUB_DER=\$(openssl pkey -pubin -in /tmp/_hpub.pem -pubout -outform DER 2>/dev/null | sha256sum | awk '{print \$1}')"
rm -f /tmp/_hpriv.pem /tmp/_hpub.pem
RSH
)
B64=$(printf '%s' "$REMOTE" | base64 | tr -d '\n')
JSON=$(mktemp)
cat > "$JSON" <<EOF
{ "InstanceIds":["$INSTANCE"], "DocumentName":"AWS-RunShellScript",
  "Comment":"BOM-113 jwt key fingerprint",
  "Parameters": { "commands": ["echo $B64 | base64 -d | sh"] } }
EOF
CID=$(aws ssm send-command --region "$REGION" --cli-input-json "file://$JSON" --query Command.CommandId --output text 2>&1)
rm -f "$JSON"
case "$CID" in *-*-*-*-*) : ;; *) echo "ERROR: SSM send-command 실패: $CID"; exit 1 ;; esac
aws ssm wait command-executed --region "$REGION" --command-id "$CID" --instance-id "$INSTANCE" 2>/dev/null
HOSTOUT=$(aws ssm get-command-invocation --region "$REGION" --command-id "$CID" --instance-id "$INSTANCE" --query StandardOutputContent --output text 2>/dev/null)
HOST_PRIV_PUBDER=$(printf '%s\n' "$HOSTOUT" | sed -n 's/^HOST_PRIV_PUBDER=//p' | tr -d '\r')
HOST_PUB_DER=$(printf '%s\n' "$HOSTOUT" | sed -n 's/^HOST_PUB_DER=//p' | tr -d '\r')

# ---- 2) SM 측 DER 공개키 지문 (로컬 aws + openssl; 키 자료는 출력 안 함) ----
SM_PRIV_PUBDER=$(aws secretsmanager get-secret-value --region "$REGION" --secret-id "$SM_PRIV" --query SecretString --output text 2>/dev/null | openssl pkey -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')
SM_PUB_DER=$(aws secretsmanager get-secret-value --region "$REGION" --secret-id "$SM_PUB" --query SecretString --output text 2>/dev/null | openssl pkey -pubin -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')

echo
echo "============== JWT 서명키 동일성 (DER 공개키 sha256 지문) =============="
echo "HOST  priv -> pubDER : ${HOST_PRIV_PUBDER:-<실패>}"
echo "HOST  pub     DER    : ${HOST_PUB_DER:-<실패>}"
echo "SM    priv -> pubDER : ${SM_PRIV_PUBDER:-<실패>}"
echo "SM    pub     DER    : ${SM_PUB_DER:-<실패>}"
echo "-----------------------------------------------------------------------"
if [ -n "$HOST_PRIV_PUBDER" ] && [ "$HOST_PRIV_PUBDER" = "$SM_PRIV_PUBDER" ]; then
  echo "✅ MATCH: 개인키 동일 → external-mydata SM 키를 그대로 재사용 가능"
elif [ -n "$HOST_PRIV_PUBDER" ] && [ -n "$SM_PRIV_PUBDER" ]; then
  echo "❌ DIFFER: external-mydata 와 다른 키 → mgmts 전용 키를 별도 SM 등록 필요"
  echo "   (BOM-123 가 만든 빈 컨테이너에 호스트 키 주입:"
  echo "      bomapp/prod/mydata-mgmts-api/jwt-private-key / jwt-public-key )"
else
  echo "⚠ 판정 불가 — 위 <실패> 항목 확인 (openssl/SSM/권한/PingStatus)"
fi
# 자기일관성(키쌍 내부 정합) 체크
[ -n "$HOST_PRIV_PUBDER" ] && [ -n "$HOST_PUB_DER" ] && [ "$HOST_PRIV_PUBDER" != "$HOST_PUB_DER" ] && echo "  ⚠ HOST priv/pub 불일치 — 호스트 키쌍 자체 점검"
[ -n "$SM_PRIV_PUBDER" ]   && [ -n "$SM_PUB_DER" ]   && [ "$SM_PRIV_PUBDER" != "$SM_PUB_DER" ]     && echo "  ⚠ SM priv/pub 불일치 — SM 키쌍 점검"
echo "======================================================================="
