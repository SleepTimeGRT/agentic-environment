#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# cmux 워크스페이스 런처 (자체 완결형)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# cmux 앱 안 터미널에서 실행하세요.
# 레이아웃은 아래 LAYOUT 변수에서 직접 수정합니다.
#
# 사용법:
#   bash cmux-launch.sh            # 워크스페이스 생성
#   bash cmux-launch.sh --dry-run  # 미리보기
set -euo pipefail

# ── 레이아웃 정의 ────────────────────────────────────────
# 수정하려면 여기만 바꾸세요.
#   name:    사이드바 탭 이름
#   command: 생성 후 자동 실행할 명령 (null이면 빈 터미널)
#   splits:  분할 방향 배열 ("right", "down")
LAYOUT='[
  { "name": "code",   "command": "claude",  "splits": [] },
  { "name": "server", "command": null,      "splits": [] },
  { "name": "shell",  "command": null,      "splits": ["right"] }
]'

# ── 프로젝트 디렉토리 (이 스크립트가 있는 곳) ────────────
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 색상 ─────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; exit 1; }

# ── 옵션 ─────────────────────────────────────────────────
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

run_cmd() {
  if $DRY_RUN; then
    echo -e "    ${YELLOW}[dry-run]${NC} $*"
  else
    "$@"
  fi
}

echo -e "${BOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " cmux Workspace Launcher"
echo " $PROJECT_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${NC}"

# ── 사전 검사 ────────────────────────────────────────────
command -v cmux >/dev/null 2>&1 || fail "cmux가 필요합니다"
command -v jq   >/dev/null 2>&1 || fail "jq가 필요합니다"
[[ -z "${CMUX_SOCKET_PATH:-}" ]] && fail "cmux 앱 안의 터미널에서 실행해주세요"

WS_COUNT=$(echo "$LAYOUT" | jq 'length')
echo "레이아웃: ${WS_COUNT}개 워크스페이스"
echo ""

# ── [1] 첫 번째 워크스페이스: 현재 것을 재활용 ──────────────
FIRST_NAME=$(echo "$LAYOUT" | jq -r '.[0].name')
FIRST_CMD=$(echo "$LAYOUT" | jq -r '.[0].command // empty')

echo -e "${BOLD}[1/${WS_COUNT}] ${FIRST_NAME}${NC} (현재 워크스페이스 재활용)"
run_cmd cmux rename-workspace "$FIRST_NAME"
ok "이름: $FIRST_NAME"

for dir in $(echo "$LAYOUT" | jq -r '.[0].splits[]? // empty'); do
  run_cmd cmux new-split "$dir"
  ok "분할: $dir"
done

if [[ -n "$FIRST_CMD" ]]; then
  sleep 0.3
  run_cmd cmux send -- "cd $PROJECT_DIR && $FIRST_CMD\n"
  ok "명령: $FIRST_CMD"
fi
echo ""

# ── [2..N] 나머지 워크스페이스: 새로 생성 ────────────────
for i in $(seq 1 $((WS_COUNT - 1))); do
  WS_NAME=$(echo "$LAYOUT" | jq -r ".[$i].name")
  WS_CMD=$(echo "$LAYOUT" | jq -r ".[$i].command // empty")

  echo -e "${BOLD}[$((i + 1))/${WS_COUNT}] ${WS_NAME}${NC}"

  if [[ -n "$WS_CMD" ]]; then
    run_cmd cmux new-workspace --cwd "$PROJECT_DIR" --command "$WS_CMD"
  else
    run_cmd cmux new-workspace --cwd "$PROJECT_DIR"
  fi
  ok "생성: $PROJECT_DIR"

  sleep 0.3

  if $DRY_RUN; then
    WS_REF="workspace:$((i + 1))"
    echo -e "    ${YELLOW}[dry-run]${NC} (ref=$WS_REF 가정)"
  else
    WS_REF=$(cmux list-workspaces --json 2>/dev/null | jq -r '.[-1].ref')
  fi

  run_cmd cmux rename-workspace --workspace "$WS_REF" "$WS_NAME"
  ok "이름: $WS_NAME"

  for dir in $(echo "$LAYOUT" | jq -r ".[$i].splits[]? // empty"); do
    run_cmd cmux new-split "$dir" --workspace "$WS_REF"
    ok "분할: $dir"
  done

  echo ""
done

# ── 첫 번째 워크스페이스로 복귀 ──────────────────────────
run_cmd cmux select-workspace --workspace workspace:1 2>/dev/null || true

echo -e "${GREEN}${BOLD}Done!${NC} 워크스페이스 레이아웃 적용 완료."
echo ""
echo "  워크스페이스:"
for i in $(seq 0 $((WS_COUNT - 1))); do
  WS_NAME=$(echo "$LAYOUT" | jq -r ".[$i].name")
  WS_CMD=$(echo "$LAYOUT" | jq -r ".[$i].command // \"(빈 터미널)\"")
  SPLITS=$(echo "$LAYOUT" | jq -r "[.[$i].splits[]?] | if length > 0 then \" [분할: \" + join(\", \") + \"]\" else \"\" end")
  echo "    [$((i + 1))] $WS_NAME → $WS_CMD$SPLITS"
done
echo ""
