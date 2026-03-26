#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Agentic Project Init
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 새 프로젝트에 스택별 하네스 시드를 심는 스크립트.
#
# 사용법:
#   bash scripts/init.sh <project-path> --ts         # TypeScript
#   bash scripts/init.sh <project-path> --py         # Python
#   bash scripts/init.sh <project-path> --ts --team  # TypeScript + 팀 규칙
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES="$REPO_ROOT/templates"

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
skip() { echo -e "  ${YELLOW}→${NC} $1 (exists)"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }

# ── 인자 파싱 ─────────────────────────────────────
PROJECT_PATH=""
STACK=""
TEAM=false

for arg in "$@"; do
  case "$arg" in
    --ts)   STACK="typescript" ;;
    --py)   STACK="python" ;;
    --team) TEAM=true ;;
    -*)     echo "Unknown option: $arg"; exit 1 ;;
    *)      PROJECT_PATH="$arg" ;;
  esac
done

if [[ -z "$PROJECT_PATH" ]]; then
  echo "Usage: bash scripts/init.sh <project-path> [--ts|--py] [--team]"
  echo ""
  echo "Options:"
  echo "  --ts     TypeScript 프로젝트 (format → lint → tsc 훅)"
  echo "  --py     Python 프로젝트 (ruff format → ruff check → pytest 훅)"
  echo "  --team   팀 규칙 추가 (git push --force 차단)"
  exit 1
fi

# 프로젝트 디렉토리 확인/생성
if [[ ! -d "$PROJECT_PATH" ]]; then
  mkdir -p "$PROJECT_PATH"
  ok "Created $PROJECT_PATH"
fi

PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

echo -e "${BOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Agentic Project Init"
echo " → $PROJECT_PATH"
[[ -n "$STACK" ]] && echo " → Stack: $STACK"
[[ "$TEAM" == true ]] && echo " → Team rules: enabled"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${NC}"

# ── CLAUDE.md ─────────────────────────────────────
if [[ -f "$PROJECT_PATH/CLAUDE.md" ]]; then
  skip "CLAUDE.md"
else
  cp "$TEMPLATES/CLAUDE.md" "$PROJECT_PATH/CLAUDE.md"
  ok "CLAUDE.md (DO NOT DO 실수 로그)"
fi

# ── WORK.md ───────────────────────────────────────
if [[ -f "$PROJECT_PATH/WORK.md" ]]; then
  skip "WORK.md"
else
  cp "$TEMPLATES/WORK.md" "$PROJECT_PATH/WORK.md"
  ok "WORK.md (태스크 관리)"
fi

# ── .claude/ 디렉토리 ─────────────────────────────
mkdir -p "$PROJECT_PATH/.claude"

# ── 스택별 settings ───────────────────────────────
SETTINGS_FILE="$PROJECT_PATH/.claude/settings.json"

if [[ -f "$SETTINGS_FILE" ]]; then
  skip ".claude/settings.json"
else
  case "$STACK" in
    typescript)
      cp "$TEMPLATES/settings.typescript.json" "$SETTINGS_FILE"
      ok ".claude/settings.json (TypeScript: format → lint → tsc)"
      ;;
    python)
      cp "$TEMPLATES/settings.python.json" "$SETTINGS_FILE"
      ok ".claude/settings.json (Python: ruff format → ruff check → pytest)"
      ;;
    *)
      # 스택 미지정 — 빈 설정
      echo '{}' > "$SETTINGS_FILE"
      ok ".claude/settings.json (empty — 스택 미지정)"
      warn "스택별 훅을 추가하려면: --ts 또는 --py"
      ;;
  esac
fi

# ── 팀 규칙 머지 ──────────────────────────────────
if [[ "$TEAM" == true ]]; then
  if command -v yq &>/dev/null; then
    TEAM_SETTINGS="$TEMPLATES/settings.team.json"
    yq -i -p json -o json '. *+ load("'"$TEAM_SETTINGS"'")' "$SETTINGS_FILE"
    ok "Team rules merged (deny: git push --force, SessionStart hook)"

    # session-context.sh 복사
    mkdir -p "$PROJECT_PATH/scripts"
    cp "$REPO_ROOT/scripts/session-context.sh" "$PROJECT_PATH/scripts/session-context.sh"
    chmod +x "$PROJECT_PATH/scripts/session-context.sh"
    ok "scripts/session-context.sh copied"
  else
    warn "yq not found — 팀 규칙을 수동으로 머지해주세요"
    warn "  참조: $TEMPLATES/settings.team.json"
  fi
fi

# ── .gitignore에 local 설정 추가 ──────────────────
GITIGNORE="$PROJECT_PATH/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
  if ! grep -q "settings.local.json" "$GITIGNORE" 2>/dev/null; then
    echo "" >> "$GITIGNORE"
    echo "# Claude Code local settings" >> "$GITIGNORE"
    echo ".claude/settings.local.json" >> "$GITIGNORE"
    echo "CLAUDE.local.md" >> "$GITIGNORE"
    ok ".gitignore updated (local settings)"
  else
    skip ".gitignore (already has local settings)"
  fi
else
  skip ".gitignore (not found)"
fi

# ── 요약 ──────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN} Project initialized${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "생성된 파일:"
echo "  CLAUDE.md              — 실수할 때마다 DO NOT DO에 추가"
echo "  WORK.md                — Doing / Next Up / Done"
echo "  .claude/settings.json  — 스택별 PostToolUse 훅"
echo ""
echo "다음:"
echo "  cd $PROJECT_PATH && claude"
