#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Agentic Environment Bootstrap
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# manifest.yaml를 읽어서 AI-native 개발 환경을 원샷으로 세팅.
# Idempotent — 여러 번 실행해도 안전.
#
# 사용법:
#   bash scripts/bootstrap.sh              # 전체 설치
#   bash scripts/bootstrap.sh --skip-tools # CLI 도구 스킵, 설정만
set -uo pipefail
# set -e 제거: 개별 설치 실패가 전체 스크립트를 중단하지 않도록.
# 각 단계에서 실패를 개별 처리.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$REPO_ROOT/manifest.yaml"

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
skip() { echo -e "  ${YELLOW}→${NC} $1 (exists)"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }

SKIP_TOOLS=false
[[ "${1:-}" == "--skip-tools" ]] && SKIP_TOOLS=true

echo -e "${BOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Agentic Environment Bootstrap"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${NC}"

# ── Layer 0: Prerequisites (Homebrew + yq + jq) ──
# 닭-달걀 문제: manifest를 파싱하려면 yq가 필요하고, yq는 brew로 설치.
# jq는 ykdojo setup.sh + context-bar.sh에 필요.
# 이 세 개를 하드코딩.
echo -e "${BOLD}[0/6] Prerequisites${NC}"

if ! command -v brew &>/dev/null; then
  echo "  Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Apple Silicon PATH 설정
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  ok "Homebrew"
else skip "Homebrew"; fi

# yq: manifest 파싱 전제조건, jq: ykdojo setup.sh + context-bar.sh 전제조건.
# 둘 다 manifest brew 섹션이 아닌 여기서 하드코딩 (닭-달걀).
PREREQ_TO_INSTALL=()
if ! command -v yq &>/dev/null; then PREREQ_TO_INSTALL+=(yq); else skip "yq"; fi
if ! command -v jq &>/dev/null; then PREREQ_TO_INSTALL+=(jq); else skip "jq"; fi
if [[ ${#PREREQ_TO_INSTALL[@]} -gt 0 ]]; then
  brew install "${PREREQ_TO_INSTALL[@]}"
  for pkg in "${PREREQ_TO_INSTALL[@]}"; do ok "$pkg"; done
fi

# git은 Homebrew 설치 시 Xcode CLT와 함께 설치됨.
# curl은 macOS 기본 포함.

# manifest 존재 확인
if [[ ! -f "$MANIFEST" ]]; then
  fail "manifest.yaml not found at $MANIFEST"
  exit 1
fi
ok "manifest.yaml found"

# ── Layer 1: CLI Tools (script 섹션) ───────────
if [[ "$SKIP_TOOLS" == false ]]; then
  echo -e "\n${BOLD}[1/6] CLI Tools (official install scripts)${NC}"

  SCRIPT_KEYS=$(yq '.script | keys | .[]' "$MANIFEST")
  if [[ -z "$SCRIPT_KEYS" ]]; then
    warn "No script entries found in manifest"
  fi
  for key in $SCRIPT_KEYS; do
    # homebrew는 이미 Layer 0에서 설치
    [[ "$key" == "homebrew" ]] && continue

    check_cmd=$(yq ".script.$key.check" "$MANIFEST")
    install_cmd=$(yq ".script.$key.install" "$MANIFEST")

    # check 조건 평가
    if [[ "$check_cmd" == "["* ]]; then
      # 셸 조건식 (예: [ -d $HOME/.nvm ])
      if eval "$check_cmd" 2>/dev/null; then
        skip "$key"
        continue
      fi
    else
      # 커맨드 존재 확인
      if command -v "$check_cmd" &>/dev/null; then
        skip "$key"
        continue
      fi
    fi

    echo "  Installing $key..."
    if eval "$install_cmd"; then
      ok "$key"
    else
      fail "$key (install failed — continuing)"
    fi

    # nvm 설치 후 Node.js 설치 (managed 섹션)
    if [[ "$key" == "nvm" ]]; then
      export NVM_DIR="$HOME/.nvm"
      # shellcheck disable=SC1091
      [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
      node_version=$(yq '.managed.node.version' "$MANIFEST")
      if [[ -n "$node_version" && "$node_version" != "null" ]]; then
        echo "  Installing Node.js $node_version via nvm..."
        nvm install "$node_version"
        ok "Node.js $node_version"
      fi
    fi
  done

  # ── Layer 1.5: Brew taps (manifest 선언) ──────
  TAPS=$(yq '.tap[]' "$MANIFEST" 2>/dev/null)
  if [[ -n "$TAPS" ]]; then
    TAPS_INSTALLED=$(brew tap 2>/dev/null)
    for tap_name in $TAPS; do
      if echo "$TAPS_INSTALLED" | grep -qxF "$tap_name"; then
        skip "tap $tap_name"
      else
        echo "  Tapping $tap_name..."
        if brew tap "$tap_name"; then
          ok "tap $tap_name"
        else
          fail "tap $tap_name (brew tap failed — continuing)"
        fi
      fi
    done
  fi

  # ── Layer 2: Brew formula ──────────────────────
  echo -e "\n${BOLD}[2/6] Brew Packages${NC}"

  BREW_INSTALLED=$(brew list --formula 2>/dev/null)
  BREW_TO_INSTALL=()
  for pkg in $(yq '.brew[]' "$MANIFEST"); do
    if echo "$BREW_INSTALLED" | grep -qxF "$pkg"; then
      skip "$pkg"
    else
      BREW_TO_INSTALL+=("$pkg")
    fi
  done
  if [[ ${#BREW_TO_INSTALL[@]} -gt 0 ]]; then
    echo "  Installing ${BREW_TO_INSTALL[*]}..."
    brew install "${BREW_TO_INSTALL[@]}"
    for pkg in "${BREW_TO_INSTALL[@]}"; do ok "$pkg"; done
  fi

  # ── Layer 3: Brew cask ─────────────────────────
  echo -e "\n${BOLD}[3/6] macOS Apps (cask)${NC}"

  CASK_INSTALLED=$(brew list --cask 2>/dev/null)
  CASK_TO_INSTALL=()
  for app in $(yq '.cask[]' "$MANIFEST"); do
    if echo "$CASK_INSTALLED" | grep -qxF "$app"; then
      skip "$app"
    else
      CASK_TO_INSTALL+=("$app")
    fi
  done
  if [[ ${#CASK_TO_INSTALL[@]} -gt 0 ]]; then
    echo "  Installing ${CASK_TO_INSTALL[*]}..."
    brew install --cask "${CASK_TO_INSTALL[@]}"
    for app in "${CASK_TO_INSTALL[@]}"; do ok "$app"; done
  fi

  # cmux CLI 심링크
  mkdir -p ~/.local/bin
  if [[ ! -L ~/.local/bin/cmux ]] && [[ -f /Applications/cmux.app/Contents/MacOS/cmux ]]; then
    ln -sf /Applications/cmux.app/Contents/MacOS/cmux ~/.local/bin/cmux
    ok "cmux CLI → ~/.local/bin/"
  fi

  # managed 섹션 — 수동 설치 안내
  for key in $(yq '.managed | keys | .[]' "$MANIFEST"); do
    # node는 nvm에서 이미 설치됨
    [[ "$key" == "node" ]] && continue
    note=$(yq ".managed.$key.note // \"\"" "$MANIFEST")
    install_url=$(yq ".managed.$key.install // \"\"" "$MANIFEST")
    if [[ -n "$note" ]]; then
      warn "$key: $note"
      warn "  → $install_url"
    fi
  done
else
  echo -e "${BOLD}[1-3/6] CLI Tools — skipped${NC}"
fi

# ── Layer 4: Claude Code Config ──────────────────
echo -e "\n${BOLD}[4/6] Claude Code Config${NC}"

mkdir -p ~/.claude/scripts

if [[ -f ~/.claude/settings.json ]]; then
  warn "~/.claude/settings.json exists — overwrite? (y/N)"
  read -n 1 -r; echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    skip "settings.json (kept)"
    SKIP_SETTINGS=true
  fi
fi

if [[ "${SKIP_SETTINGS:-false}" != true ]]; then
  cp "$REPO_ROOT/configs/settings.json" ~/.claude/settings.json
  ok "settings.json (global — security + personal only)"
fi

# ykdojo/claude-code-tips setup (statusLine, DX plugin, cc-safe, permissions, aliases 등)
# Skip: 4 (disable auto-updates), 8 (disable attribution — Co-Authored-By 유지)
# 참고: setup.sh 내부에서 claude CLI가 없으면 DX plugin 설치만 스킵하고 나머지는 진행.
echo "  Running ykdojo/claude-code-tips setup.sh (skip 4,8)..."
if echo "4 8" | bash <(curl -s https://raw.githubusercontent.com/ykdojo/claude-code-tips/main/scripts/setup.sh); then
  ok "ykdojo setup (DX, cc-safe, statusLine, permissions, aliases, fork shortcut)"
else
  fail "ykdojo setup (partial failure — continuing)"
fi

# Playwright MCP (browser automation)
if command -v claude &>/dev/null; then
  if claude mcp list 2>/dev/null | grep -q "playwright"; then
    skip "Playwright MCP"
  else
    claude mcp add -s user playwright npx @playwright/mcp@latest
    ok "Playwright MCP"
  fi
else
  warn "Playwright MCP (claude CLI not found — install claude-code first, then: claude mcp add -s user playwright npx @playwright/mcp@latest)"
fi

# ── Layer 5: Skills ──────────────────────────────
echo -e "\n${BOLD}[5/6] Skills${NC}"

mkdir -p ~/.claude/skills

# 전체 skills를 단일 yq 호출로 TSV 추출
SKILLS_TSV=$(yq '.skills[] | [.repo, .name, .setup // "", .optional // "false", .note // ""] | @tsv' "$MANIFEST" 2>/dev/null)
if [[ -z "$SKILLS_TSV" ]]; then
  warn "No skills found in manifest"
fi
while IFS=$'\t' read -r repo name setup_cmd optional note; do
  if [[ -z "$repo" || -z "$name" ]]; then
    warn "Malformed skill entry — skipping"
    continue
  fi

  target_dir="$HOME/.claude/skills/$name"

  if [[ -d "$target_dir" ]]; then
    skip "$name"
    continue
  fi

  # optional 스킬은 확인 후 설치
  if [[ "$optional" == "true" ]]; then
    echo -n "  $name 설치? ($note) (y/N) "; read -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      skip "$name (skipped)"
      continue
    fi
  fi

  echo "  Installing $name..."
  TMP=$(mktemp -d)
  if ! git clone --depth 1 "https://github.com/$repo.git" "$TMP" 2>/dev/null; then
    fail "$name (git clone failed — continuing)"
    rm -rf "$TMP" 2>/dev/null || true
    continue
  fi

  # 스킬에 따라 설치 방법이 다름
  if [[ "$name" == "obsidian-cli" ]]; then
    cp -r "$TMP/obsidian-cli" "$HOME/.claude/skills/obsidian-cli"
    cp -r "$TMP/obsidian-markdown" "$HOME/.claude/skills/obsidian-markdown"
  elif [[ -n "$setup_cmd" && "$setup_cmd" != "null" ]]; then
    if [[ "$name" == "using-cmux" ]]; then
      (cd "$TMP" && chmod +x install.sh && ./install.sh)
    else
      mv "$TMP" "$target_dir"
      (cd "$target_dir" && eval "$setup_cmd")
    fi
  else
    mv "$TMP" "$target_dir"
  fi

  rm -rf "$TMP" 2>/dev/null || true
  ok "$name"
done <<< "$SKILLS_TSV"

# ── Layer 6: Verification ────────────────────────
echo -e "\n${BOLD}[6/6] Verification${NC}"
bash "$REPO_ROOT/scripts/doctor.sh"
echo ""
echo "다음:"
echo "  gh auth login          # GitHub 인증 (처음만)"
echo "  cmux                   # 멀티 에이전트 터미널"
echo "  claude                 # 첫 실행 시 플러그인 자동 설치"
echo ""
echo "새 프로젝트 시작 시:"
echo "  bash $REPO_ROOT/scripts/init.sh <project-path> --ts    # TypeScript"
echo "  bash $REPO_ROOT/scripts/init.sh <project-path> --py    # Python"
echo "  bash $REPO_ROOT/scripts/init.sh <project-path> --team  # + 팀 규칙"
