#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# cmux + Claude Code 통합 설정
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# cmux 훅을 ~/.claude/settings.json에 머지합니다.
# Idempotent — 여러 번 실행해도 안전합니다.
#
# 사용법:
#   bash cmux/setup-cmux.sh                    # 훅 설치 + 테마 설정
#   bash cmux/setup-cmux.sh --hooks-only       # 훅만 설치
#   bash cmux/setup-cmux.sh --uninstall        # cmux 훅 제거
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_FILE="$SCRIPT_DIR/cmux-hooks.json"
SETTINGS="$HOME/.claude/settings.json"

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; exit 1; }

echo -e "${BOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " cmux + Claude Code Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${NC}"

# ── 사전 검사 ──────────────────────────────────────────────
command -v jq  >/dev/null 2>&1 || fail "jq가 필요합니다: brew install jq"
command -v cmux >/dev/null 2>&1 || fail "cmux가 필요합니다: brew install --cask cmux"
[[ -f "$HOOKS_FILE" ]]         || fail "cmux-hooks.json을 찾을 수 없습니다: $HOOKS_FILE"

# ── settings.json 없으면 생성 ──────────────────────────────
if [[ ! -f "$SETTINGS" ]]; then
  mkdir -p "$(dirname "$SETTINGS")"
  echo '{"hooks":{}}' > "$SETTINGS"
  ok "settings.json 생성"
fi

# ── 언인스톨 모드 ──────────────────────────────────────────
if [[ "${1:-}" == "--uninstall" ]]; then
  echo "cmux 훅 제거 중..."
  CMUX_KEYS=$(jq -r 'keys[]' "$HOOKS_FILE")
  FILTER="."
  for key in $CMUX_KEYS; do
    FILTER="$FILTER | .hooks |= del(.[\"$key\"])"
  done
  TMP=$(mktemp)
  jq "$FILTER" "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
  ok "cmux 훅 제거 완료"
  # 상태 정리
  cmux clear-status claude 2>/dev/null || true
  ok "사이드바 상태 정리"
  echo -e "\n${GREEN}Done!${NC} cmux 훅이 제거되었습니다.\n"
  exit 0
fi

# ── 훅 머지 ────────────────────────────────────────────────
echo "훅 설치 중..."

# 백업
cp "$SETTINGS" "$SETTINGS.bak"
ok "settings.json 백업 → settings.json.bak"

# hooks 키가 없으면 추가
if ! jq -e '.hooks' "$SETTINGS" >/dev/null 2>&1; then
  TMP=$(mktemp)
  jq '. + {"hooks":{}}' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
fi

# cmux-hooks.json의 각 키를 settings.json .hooks에 머지
TMP=$(mktemp)
jq --slurpfile cmux "$HOOKS_FILE" '
  .hooks = (.hooks // {}) * $cmux[0]
' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
ok "cmux 훅 머지 완료 (Notification, Stop, SessionStart, UserPromptSubmit)"

# ── 테마 설정 ──────────────────────────────────────────────
if [[ "${1:-}" != "--hooks-only" ]]; then
  echo ""
  echo "테마 설정 중..."
  cmux themes set --dark "TokyoNight Storm" 2>/dev/null && ok "다크 테마: TokyoNight Storm" || warn "다크 테마 설정 실패 (cmux 실행 중인지 확인)"
  cmux themes set --light "GitHub Light Default" 2>/dev/null && ok "라이트 테마: GitHub Light Default" || warn "라이트 테마 설정 실패"
fi

# ── 검증 ───────────────────────────────────────────────────
echo ""
echo "검증 중..."
HOOK_COUNT=$(jq '.hooks | keys | length' "$SETTINGS")
ok "settings.json 훅 이벤트: ${HOOK_COUNT}개"

# jq 파싱 가능 확인
jq empty "$SETTINGS" 2>/dev/null && ok "settings.json JSON 유효" || fail "settings.json JSON 깨짐!"

echo -e "\n${GREEN}${BOLD}Done!${NC} cmux 통합 설정 완료."
echo ""
echo "  설치된 훅:"
echo "    - Notification (idle_prompt)  → 입력 대기 시 사운드 알림"
echo "    - Notification (permission)   → 권한 요청 시 사운드 알림"
echo "    - Stop                        → 작업 완료 시 사이드바 상태"
echo "    - SessionStart                → 세션 시작 시 사이드바 상태"
echo "    - UserPromptSubmit            → 프롬프트 전송 시 상태 변경"
echo ""
echo "  명령어:"
echo "    bash cmux/setup-cmux.sh --uninstall   # 제거"
echo "    bash cmux/setup-cmux.sh --hooks-only  # 테마 제외 설치"
echo ""
