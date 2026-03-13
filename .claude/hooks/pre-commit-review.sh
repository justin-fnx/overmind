#!/usr/bin/env bash
# AIDEV-NOTE: Pre-commit 2단계 코드 리뷰 훅
# 1단계: Claude CLI 리뷰 → 2단계: Gemini API 리뷰
# HIGH severity 이슈 발견 시 exit 2로 커밋 차단, 피드백 전달
set -euo pipefail

# --- stdin에서 hook input 읽기 ---
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# git commit이 아니면 즉시 통과
if ! echo "$COMMAND" | grep -qE '^git commit'; then
  exit 0
fi

# --- 반복 카운터 (최대 10회) ---
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "default"')
COUNTER_FILE="/tmp/.claude-review-counter-${SESSION_ID}"
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

if [ "$COUNT" -gt 10 ]; then
  echo "리뷰 반복 10회 초과. 강제 통과합니다." >&2
  rm -f "$COUNTER_FILE"
  exit 0
fi

# --- staged diff 수집 ---
DIFF=$(git diff --cached)
if [ -z "$DIFF" ]; then
  rm -f "$COUNTER_FILE"
  exit 0
fi

# diff 크기 제한 (60000자)
MAX_DIFF_CHARS=60000
DIFF_LEN=${#DIFF}
if [ "$DIFF_LEN" -gt "$MAX_DIFF_CHARS" ]; then
  DIFF="${DIFF:0:$MAX_DIFF_CHARS}"
fi

# === 1단계: Claude CLI 리뷰 ===
echo "[1/2] Claude CLI 리뷰 실행 중..." >&2

CLAUDE_PROMPT="You are a senior code reviewer. Review the following staged diff.
Focus ONLY on HIGH severity issues:
1. Security vulnerabilities (exposed secrets, injection risks)
2. Performance issues (inefficient algorithms, memory leaks)
3. Bugs and logic errors (null handling, race conditions, off-by-one)

Respond ONLY with a valid JSON object (no markdown fences):
{
  \"issues\": [
    {
      \"file\": \"path/to/file\",
      \"line\": 123,
      \"severity\": \"HIGH\",
      \"description\": \"설명 (한국어)\"
    }
  ]
}

If no HIGH severity issues found, return: {\"issues\": []}

DIFF:
${DIFF}"

CLAUDE_RESULT=$(claude -p "$CLAUDE_PROMPT" --output-format json 2>/dev/null || echo "")

if [ -n "$CLAUDE_RESULT" ]; then
  # Claude CLI --output-format json은 result 필드에 텍스트 응답을 반환
  CLAUDE_TEXT=$(echo "$CLAUDE_RESULT" | jq -r '.result // empty' 2>/dev/null || echo "$CLAUDE_RESULT")

  # JSON 코드펜스 제거 후 파싱
  CLAUDE_JSON=$(echo "$CLAUDE_TEXT" | sed 's/```json//g; s/```//g' | jq '.' 2>/dev/null || echo "")

  if [ -n "$CLAUDE_JSON" ]; then
    CLAUDE_HIGH_COUNT=$(echo "$CLAUDE_JSON" | jq '[.issues // [] | .[] | select(.severity == "HIGH")] | length' 2>/dev/null || echo "0")

    if [ "$CLAUDE_HIGH_COUNT" -gt 0 ]; then
      echo "[1/2] Claude 리뷰: HIGH 이슈 ${CLAUDE_HIGH_COUNT}건 발견" >&2
      # 이슈 상세 내용을 stderr로 출력 (Claude에게 피드백)
      CLAUDE_FEEDBACK=$(echo "$CLAUDE_JSON" | jq -r '.issues[] | select(.severity == "HIGH") | "- [\(.file) L\(.line // "?")] \(.description)"' 2>/dev/null || echo "")
      echo "" >&2
      echo "=== Claude 리뷰 피드백 ===" >&2
      echo "$CLAUDE_FEEDBACK" >&2
      echo "==========================" >&2
      echo "" >&2
      echo "위 이슈를 수정한 후 다시 커밋해주세요. (반복 ${COUNT}/10)" >&2
      exit 2
    fi
  fi
  echo "[1/2] Claude 리뷰: HIGH 이슈 없음 ✓" >&2
else
  echo "[1/2] Claude CLI 실행 실패. 스킵합니다." >&2
fi

# === 2단계: Gemini API 리뷰 ===
if [ -z "${GEMINI_API_KEY:-}" ]; then
  echo "[2/2] GEMINI_API_KEY 없음. Gemini 리뷰 스킵." >&2
  rm -f "$COUNTER_FILE"
  exit 0
fi

echo "[2/2] Gemini API 리뷰 실행 중..." >&2

GEMINI_MODEL="gemini-flash-latest"
GEMINI_API_URL="https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent"

GEMINI_PROMPT="You are a senior software engineer reviewing a staged diff before commit.
Focus ONLY on HIGH severity issues:
1. Security vulnerabilities (exposed secrets, injection risks)
2. Performance issues (inefficient algorithms, memory leaks)
3. Bugs and logic errors (null handling, race conditions, off-by-one)

Do NOT report code style or formatting issues.

Respond ONLY with a valid JSON object (no markdown fences):
{
  \"issues\": [
    {
      \"file\": \"path/to/file\",
      \"line\": 123,
      \"severity\": \"HIGH\",
      \"description\": \"설명 (한국어)\"
    }
  ]
}

If no HIGH severity issues found, return: {\"issues\": []}

DIFF:
${DIFF}"

GEMINI_PAYLOAD=$(jq -n --arg prompt "$GEMINI_PROMPT" '{
  contents: [{
    parts: [{ text: $prompt }]
  }]
}')

GEMINI_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "$GEMINI_API_URL" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: ${GEMINI_API_KEY}" \
  -d "$GEMINI_PAYLOAD" 2>/dev/null || echo -e "\n000")

GEMINI_HTTP_CODE=$(echo "$GEMINI_RESPONSE" | tail -n1)
GEMINI_BODY=$(echo "$GEMINI_RESPONSE" | sed '$d')

if [ "$GEMINI_HTTP_CODE" -ne 200 ]; then
  echo "[2/2] Gemini API 오류 (HTTP ${GEMINI_HTTP_CODE}). 스킵합니다." >&2
  rm -f "$COUNTER_FILE"
  exit 0
fi

GEMINI_TEXT=$(echo "$GEMINI_BODY" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null || echo "")

if [ -n "$GEMINI_TEXT" ]; then
  GEMINI_JSON=$(echo "$GEMINI_TEXT" | sed 's/```json//g; s/```//g' | jq '.' 2>/dev/null || echo "")

  if [ -n "$GEMINI_JSON" ]; then
    GEMINI_HIGH_COUNT=$(echo "$GEMINI_JSON" | jq '[.issues // [] | .[] | select(.severity == "HIGH")] | length' 2>/dev/null || echo "0")

    if [ "$GEMINI_HIGH_COUNT" -gt 0 ]; then
      echo "[2/2] Gemini 리뷰: HIGH 이슈 ${GEMINI_HIGH_COUNT}건 발견" >&2
      GEMINI_FEEDBACK=$(echo "$GEMINI_JSON" | jq -r '.issues[] | select(.severity == "HIGH") | "- [\(.file) L\(.line // "?")] \(.description)"' 2>/dev/null || echo "")
      echo "" >&2
      echo "=== Gemini 리뷰 피드백 ===" >&2
      echo "$GEMINI_FEEDBACK" >&2
      echo "==========================" >&2
      echo "" >&2
      echo "위 이슈를 수정한 후 다시 커밋해주세요. (반복 ${COUNT}/10)" >&2
      exit 2
    fi
  fi
  echo "[2/2] Gemini 리뷰: HIGH 이슈 없음 ✓" >&2
else
  echo "[2/2] Gemini 응답 파싱 실패. 스킵합니다." >&2
fi

# 모두 통과 → 카운터 리셋, 커밋 허용
echo "모든 리뷰 통과! 커밋을 진행합니다." >&2
rm -f "$COUNTER_FILE"
exit 0
