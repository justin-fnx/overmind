#!/bin/sh
# ============================================================================
# inject-mgmts-jwt-keys.sh   ★ 로컬(노트북)에서 실행 ★
#   호스트 JWT 서명키(/was/env/cert/*.pem) → SSM 로 받아 → SM SecretBinary 주입.
#
#   안전장치: 디코드한 파일 sha256 이 "검증된 호스트 지문"과 일치할 때만 주입.
#             (SSM 출력 절단/오류를 자동 차단 → 부분키 주입 방지)
#   키 값은 본인 AWS 계정/터미널에만 머무름. (제 deny 룰과 무관 — 본인 실행)
#
# 사용:  sh tools/inject-mgmts-jwt-keys.sh
#        AWS_PROFILE=<prod> sh tools/inject-mgmts-jwt-keys.sh
# ============================================================================
set -u
INSTANCE="${1:-i-03f0178089f760c6f}"
REGION="${AWS_REGION:-ap-northeast-2}"
command -v aws     >/dev/null 2>&1 || { echo "aws CLI 필요"; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "openssl 필요"; exit 1; }

# 호스트경로 | SM 시크릿 | 기대 sha256 (verify 단계에서 확인된 호스트 파일 지문)
set -- \
 "/was/env/cert/my.data.rsa.pkcs8.key.pem|bomapp/prod/mydata/mgmts-token-rsa-private-pem|8a4cd8a21ba47133006866de2bdc96aa58c0e4e548930430e59bae5323784ae2" \
 "/was/env/cert/my.data.rsa.pkcs8.public.key.pem|bomapp/prod/mydata/mgmts-token-rsa-public-pem|45266c2d29c7e0e8b688065d74023422375ba824d3779225afb2d776a9d5ae8e"

fetch_b64() {  # $1=host path -> stdout: base64(file) (SSM docker cp)
  R=$(cat <<RSH
C=""
for c in \$(docker ps --format '{{.ID}}' 2>/dev/null); do
  docker cp "\$c:$1" /tmp/_ik.bin 2>/dev/null && { C=1; break; }
done
[ -z "\$C" ] && [ -f "$1" ] && cp "$1" /tmp/_ik.bin
if [ -f /tmp/_ik.bin ]; then base64 /tmp/_ik.bin | tr -d '\n'; rm -f /tmp/_ik.bin; else echo NOFILE; fi
RSH
)
  BB=$(printf '%s' "$R" | base64 | tr -d '\n')
  J=$(mktemp)
  printf '{ "InstanceIds":["%s"], "DocumentName":"AWS-RunShellScript", "Parameters": { "commands": ["echo %s | base64 -d | sh"] } }' "$INSTANCE" "$BB" > "$J"
  CID=$(aws ssm send-command --region "$REGION" --cli-input-json "file://$J" --query Command.CommandId --output text 2>/dev/null); rm -f "$J"
  [ -z "$CID" ] && return 1
  aws ssm wait command-executed --region "$REGION" --command-id "$CID" --instance-id "$INSTANCE" 2>/dev/null
  aws ssm get-command-invocation --region "$REGION" --command-id "$CID" --instance-id "$INSTANCE" --query StandardOutputContent --output text 2>/dev/null | tr -d '\r\n '
}

RC=0
for entry in "$@"; do
  HP=$(printf '%s' "$entry"   | cut -d'|' -f1)
  SECRET=$(printf '%s' "$entry" | cut -d'|' -f2)
  EXP=$(printf '%s' "$entry"  | cut -d'|' -f3)
  echo "== $HP"
  echo "   -> $SECRET"
  B64=$(fetch_b64 "$HP")
  if [ -z "$B64" ] || [ "$B64" = "NOFILE" ]; then echo "   ❌ 호스트 키 못 읽음 (SSM/컨테이너/PingStatus 확인)"; RC=1; continue; fi
  T=$(mktemp)
  printf '%s' "$B64" | openssl base64 -d -A > "$T" 2>/dev/null
  FP=$( { sha256sum "$T" 2>/dev/null || shasum -a 256 "$T" 2>/dev/null; } | awk '{print $1}')
  SZ=$(wc -c < "$T" | tr -d ' ')
  echo "   받은 파일: ${SZ} bytes  sha256=$FP"
  if [ "$FP" != "$EXP" ]; then
    echo "   ❌ 지문 불일치 (기대 $EXP) → SSM 출력 절단/오류 의심. 주입 중단."
    rm -f "$T"; RC=1; continue
  fi
  echo "   ✅ 지문 일치 → put-secret-value (SecretBinary)"
  aws secretsmanager put-secret-value --region "$REGION" --secret-id "$SECRET" --secret-binary "fileb://$T" \
    --query '{Name:Name,Version:VersionId}' --output json 2>&1
  rm -f "$T"
done
[ "$RC" = 0 ] && echo "완료 — 두 키 주입됨." || echo "일부 실패(위 ❌). 재실행하거나 알려주세요."
exit $RC
