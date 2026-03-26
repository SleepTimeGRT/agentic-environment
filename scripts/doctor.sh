#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Agentic Environment Doctor
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# manifest.yaml를 읽어서 각 항목이 설치되어 있는지 검증.
# 언제든 실행 가능한 환경 헬스체크.
#
# 사용법:
#   bash scripts/doctor.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$REPO_ROOT/manifest.yaml"

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }

PASS=0
WARN=0
FAIL=0

check_pass() { ok "$1"; PASS=$((PASS + 1)); }
check_warn() { warn "$1"; WARN=$((WARN + 1)); }
check_fail() { fail "$1"; FAIL=$((FAIL + 1)); }

echo -e "${BOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Agentic Environment Doctor"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${NC}"

# ── Prerequisites ─────────────────────────────────
echo -e "${BOLD}Prerequisites${NC}"

if ! command -v yq &>/dev/null; then
  check_fail "yq not found — run bootstrap.sh first"
  echo "  yq 없이는 manifest를 파싱할 수 없습니다."
  exit 1
fi
check_pass "yq"

if [[ ! -f "$MANIFEST" ]]; then
  check_fail "manifest.yaml not found"
  exit 1
fi
check_pass "manifest.yaml"

# ── Script tools ──────────────────────────────────
echo -e "\n${BOLD}CLI Tools (script)${NC}"

for key in $(yq '.script | keys | .[]' "$MANIFEST"); do
  check_cmd=$(yq ".script.$key.check" "$MANIFEST")

  if [[ "$check_cmd" == "["* ]]; then
    if eval "$check_cmd" 2>/dev/null; then
      check_pass "$key"
    else
      check_fail "$key"
    fi
  else
    if command -v "$check_cmd" &>/dev/null; then
      version=$("$check_cmd" --version 2>/dev/null | head -1 || echo "")
      check_pass "$key${version:+ ($version)}"
    else
      check_fail "$key"
    fi
  fi
done

# Node.js (managed)
node_version=$(yq '.managed.node.version' "$MANIFEST")
if command -v node &>/dev/null; then
  actual=$(node -v 2>/dev/null)
  check_pass "Node.js $actual (want: v$node_version)"
else
  check_fail "Node.js (want: v$node_version)"
fi

# ── Brew formula ──────────────────────────────────
echo -e "\n${BOLD}Brew Packages${NC}"

BREW_INSTALLED=$(brew list --formula 2>/dev/null)
for pkg in $(yq '.brew[]' "$MANIFEST"); do
  if echo "$BREW_INSTALLED" | grep -qxF "$pkg"; then
    check_pass "$pkg"
  else
    check_fail "$pkg"
  fi
done

# ── Brew cask (command -v → /Applications fallback) ──
echo -e "\n${BOLD}macOS Apps (cask)${NC}"

for app in $(yq '.cask[]' "$MANIFEST"); do
  if command -v "$app" &>/dev/null; then
    check_pass "$app"
  else
    found=$(find /Applications -maxdepth 1 -iname "${app}*.app" 2>/dev/null | head -1)
    if [[ -n "$found" ]]; then
      check_pass "$app ($(basename "$found"))"
    else
      check_fail "$app"
    fi
  fi
done

# ── Managed (command -v 또는 앱 존재로 확인) ───────
echo -e "\n${BOLD}Managed${NC}"

for key in $(yq '.managed | keys | .[]' "$MANIFEST"); do
  [[ "$key" == "node" ]] && continue
  note=$(yq ".managed.$key.note // \"\"" "$MANIFEST")

  app_name=$(yq ".managed.$key.app // \"\"" "$MANIFEST")

  if command -v "$key" &>/dev/null; then
    check_pass "$key"
  elif [[ -n "$app_name" && -d "/Applications/$app_name" ]]; then
    check_pass "$key ($app_name)"
  else
    found=$(find /Applications -maxdepth 1 -iname "${key}*.app" 2>/dev/null | head -1)
    if [[ -n "$found" ]]; then
      check_pass "$key ($(basename "$found"))"
    else
      check_warn "$key ($note)"
    fi
  fi
done

# ── Claude Code Config ────────────────────────────
echo -e "\n${BOLD}Claude Code Config${NC}"

[[ -f ~/.claude/settings.json ]] && check_pass "~/.claude/settings.json" || check_fail "~/.claude/settings.json"
[[ -x ~/.claude/scripts/context-bar.sh ]] && check_pass "context-bar.sh (statusLine)" || check_fail "context-bar.sh (statusLine — run bootstrap.sh)"
command -v jq &>/dev/null && check_pass "jq (context-bar.sh dependency)" || check_fail "jq (brew install jq)"

# MCP servers
if command -v claude &>/dev/null; then
  if claude mcp list 2>/dev/null | grep -q "playwright"; then
    check_pass "Playwright MCP"
  else
    check_fail "Playwright MCP (claude mcp add -s user playwright npx @playwright/mcp@latest)"
  fi
else
  check_warn "Playwright MCP (claude CLI not found — install claude-code first)"
fi

# gh 인증 상태
if gh auth status &>/dev/null 2>&1; then
  check_pass "gh auth (authenticated)"
else
  check_warn "gh auth (not authenticated — run: gh auth login)"
fi

# ── Skills ────────────────────────────────────────
echo -e "\n${BOLD}Skills${NC}"

skill_count=$(yq '.skills | length' "$MANIFEST")
for i in $(seq 0 $((skill_count - 1))); do
  name=$(yq ".skills[$i].name" "$MANIFEST")
  optional=$(yq ".skills[$i].optional // false" "$MANIFEST")

  if [[ -d "$HOME/.claude/skills/$name" ]]; then
    check_pass "$name"
  elif [[ "$optional" == "true" ]]; then
    check_warn "$name (optional, not installed)"
  else
    check_fail "$name"
  fi
done

# ── PATH check ────────────────────────────────────
echo -e "\n${BOLD}Environment${NC}"

if echo "$PATH" | grep -q "$HOME/.local/bin"; then
  check_pass "~/.local/bin in PATH"
else
  check_warn "~/.local/bin not in PATH"
fi

# ── Summary ───────────────────────────────────────
TOTAL=$((PASS + WARN + FAIL))
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ "$FAIL" -eq 0 && "$WARN" -eq 0 ]]; then
  echo -e "${BOLD}${GREEN} All $TOTAL checks passed${NC}"
elif [[ "$FAIL" -eq 0 ]]; then
  echo -e "${BOLD}${YELLOW} $PASS passed, $WARN warnings${NC}"
else
  echo -e "${BOLD}${RED} $PASS passed, $WARN warnings, $FAIL failed${NC}"
  echo ""
  echo "Fix: bash $REPO_ROOT/scripts/bootstrap.sh"
fi
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
