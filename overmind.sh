#!/usr/bin/env bash
# Overmind: Microservices Orchestration Leader
# Usage: ./overmind.sh [LINEAR_TICKET_ID]
#
# Examples:
#   ./overmind.sh BKO-1234
#   ./overmind.sh              # (interactive mode)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TICKET_ID="${1:-}"

# Teammate 표시 모드 (tmux 또는 iTerm2 자동 감지)
TEAMMATE_MODE="tmux"
if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
  TEAMMATE_MODE="iterm2"
fi

cd "$SCRIPT_DIR"

if [[ -n "$TICKET_ID" ]]; then
  exec claude \
    --teammate-mode "$TEAMMATE_MODE" \
    --model "claude-opus-4-6" \
    -p "services.yaml을 읽고 Service Catalog를 로드한 뒤, Linear 티켓 ${TICKET_ID}을 분석하여 작업을 진행해줘. 에이전트 팀을 구성해서 처리해."
else
  exec claude \
    --teammate-mode "$TEAMMATE_MODE" \
    --model "claude-opus-4-6"
fi
