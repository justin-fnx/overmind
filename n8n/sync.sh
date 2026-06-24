#!/usr/bin/env bash
# n8n 워크플로우 형상관리 sync (overmind 정본 ↔ n8n.bomapp.co.kr)
#   ./sync.sh pull [name]    전체 또는 특정 워크플로우 내려받기
#   ./sync.sh push <name>    정본 JSON 을 n8n 에 반영 (크레덴셜 참조 보존)
# 자격: n8n/.env 의 N8N_API_URL, N8N_API_KEY (gitignored)
# bash 3.2(macOS 기본) 호환 — 연관배열 미사용.
set -euo pipefail
cd "$(dirname "$0")"
if [ -f .env ]; then set -a; . ./.env; set +a; fi
: "${N8N_API_URL:?N8N_API_URL not set (n8n/.env 참고)}"
: "${N8N_API_KEY:?N8N_API_KEY not set (n8n/.env 참고)}"

WF_NAMES="wf1-context-gate wf2-listener wf-snooze wf3-handoff figma-vision wf-dispatch wf-watch wf-cleanup wf-enrich wf-notion-read"

wf_id() {
  case "$1" in
    wf1-context-gate) echo "Y74XMZpTEUejToOQ" ;;
    wf2-listener)     echo "3LyKi5A20HoPrP0p" ;;
    wf-snooze)        echo "PpZ7nC12PWWet4DB" ;;
    wf3-handoff)      echo "m6YGNNCEP5RI3SSF" ;;
    figma-vision)     echo "YN6uIteF2X5BAo85" ;;
    wf-dispatch)      echo "0KSWtN1SPermSuFw" ;;
    wf-watch)         echo "Nivu3hdSDVlL5LrR" ;;
    wf-cleanup)       echo "LHLd2RloEwRUkWuS" ;;
    wf-enrich)        echo "bPNVUvuHpaograNX" ;;
    wf-notion-read)   echo "QHVMJ3uFEwlzumw3" ;;
    *) echo "알 수 없는 워크플로우: $1 (가능: ${WF_NAMES})" >&2; return 1 ;;
  esac
}

api() { curl -fsS -H "X-N8N-API-KEY: ${N8N_API_KEY}" "$@"; }

pull_one() {
  local name=$1 id; id=$(wf_id "$name") || return 1
  api "${N8N_API_URL%/}/api/v1/workflows/${id}" | jq -S '.' > "workflows/${name}.json"
  echo "pulled ${name} (${id})"
}

push_one() {
  local name=$1 id; id=$(wf_id "$name") || return 1
  # PUT 허용 필드만 전송. nodes 의 credentials 참조는 보존됨.
  # settings 는 공개 API 스키마 허용 키만 (availableInMCP/binaryMode 등 비공개 필드는 400 유발).
  jq '{name, nodes, connections,
       settings: (.settings | {executionOrder, saveExecutionProgress, saveManualExecutions, saveDataErrorExecution, saveDataSuccessExecution, executionTimeout, errorWorkflow, timezone} | with_entries(select(.value != null)))}' "workflows/${name}.json" \
    | api -X PUT -H "Content-Type: application/json" --data @- \
        "${N8N_API_URL%/}/api/v1/workflows/${id}" > /dev/null
  echo "pushed ${name} (${id}) — 반영 후 n8n 에서 publish 필요"
}

cmd=${1:-}; arg=${2:-}
case "$cmd" in
  pull) if [ -n "$arg" ]; then pull_one "$arg"; else for n in ${WF_NAMES}; do pull_one "$n"; done; fi ;;
  push) [ -n "$arg" ] || { echo "push 는 워크플로우 이름이 필요합니다 (예: ./sync.sh push wf1-context-gate)"; exit 1; }; push_one "$arg" ;;
  *) echo "usage: ./sync.sh pull [name] | push <name>"; exit 1 ;;
esac
