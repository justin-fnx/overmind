#!/usr/bin/env bash
# n8n 워크플로우 형상관리 sync (overmind 정본 ↔ n8n.bomapp.co.kr)
#   ./sync.sh pull [name]    전체 또는 특정 워크플로우 내려받기
#   ./sync.sh push <name>    정본 JSON 을 n8n 에 반영 (크레덴셜 참조 보존)
# 자격: n8n/.env 의 N8N_API_URL, N8N_API_KEY (gitignored)
set -euo pipefail
cd "$(dirname "$0")"
if [ -f .env ]; then set -a; . ./.env; set +a; fi
: "${N8N_API_URL:?N8N_API_URL not set (n8n/.env 참고)}"
: "${N8N_API_KEY:?N8N_API_KEY not set (n8n/.env 참고)}"

# 워크플로우 인벤토리: name -> id
declare -A WF=(
  [wf1-context-gate]=Y74XMZpTEUejToOQ
  [wf2-listener]=3LyKi5A20HoPrP0p
  [wf-snooze]=PpZ7nC12PWWet4DB
)

api() { curl -fsS -H "X-N8N-API-KEY: ${N8N_API_KEY}" "$@"; }

pull_one() {
  local name=$1 id=${WF[$1]:?알 수 없는 워크플로우: $1}
  api "${N8N_API_URL%/}/api/v1/workflows/${id}" | jq -S '.' > "workflows/${name}.json"
  echo "pulled ${name} (${id})"
}

push_one() {
  local name=$1 id=${WF[$1]:?알 수 없는 워크플로우: $1}
  # PUT 허용 필드만 전송 (active/id/tags 등 읽기전용 제거). nodes 의 credentials 참조는 그대로 보존됨.
  jq '{name, nodes, connections, settings}' "workflows/${name}.json" \
    | api -X PUT -H "Content-Type: application/json" --data @- \
        "${N8N_API_URL%/}/api/v1/workflows/${id}" > /dev/null
  echo "pushed ${name} (${id}) — 반영 후 n8n 에서 publish 필요"
}

cmd=${1:-}; arg=${2:-}
case "$cmd" in
  pull) if [ -n "$arg" ]; then pull_one "$arg"; else for n in "${!WF[@]}"; do pull_one "$n"; done; fi ;;
  push) [ -n "$arg" ] || { echo "push 는 워크플로우 이름이 필요합니다 (예: ./sync.sh push wf1-context-gate)"; exit 1; }; push_one "$arg" ;;
  *) echo "usage: ./sync.sh pull [name] | push <name>"; exit 1 ;;
esac
