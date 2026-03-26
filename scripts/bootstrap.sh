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
set -euo pipefail

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

# ── Layer 0: Prerequisites (Homebrew + yq) ─────
# 닭-달걀 문제: manifest를 파싱하려면 yq가 필요하고, yq는 brew로 설치.
# 이 두 개만 하드코딩.
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

if ! command -v yq &>/dev/null; then
  brew install yq
  ok "yq (YAML parser)"
else skip "yq"; fi

# manifest 존재 확인
if [[ ! -f "$MANIFEST" ]]; then
  fail "manifest.yaml not found at $MANIFEST"
  exit 1
fi
ok "manifest.yaml found"

# ── Layer 1: CLI Tools (script 섹션) ───────────
if [[ "$SKIP_TOOLS" == false ]]; then
  echo -e "\n${BOLD}[1/6] CLI Tools (official install scripts)${NC}"

  for key in $(yq '.script | keys | .[]' "$MANIFEST"); do
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
    eval "$install_cmd"
    ok "$key"

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

  # cmux tap 필요
  brew tap manaflow-ai/cmux 2>/dev/null || true

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


# ── Layer 5: Skills ──────────────────────────────
echo -e "\n${BOLD}[5/6] Skills${NC}"

mkdir -p ~/.claude/skills

skill_count=$(yq '.skills | length' "$MANIFEST")
for i in $(seq 0 $((skill_count - 1))); do
  repo=$(yq ".skills[$i].repo" "$MANIFEST")
  name=$(yq ".skills[$i].name" "$MANIFEST")
  setup_cmd=$(yq ".skills[$i].setup // \"\"" "$MANIFEST")
  optional=$(yq ".skills[$i].optional // false" "$MANIFEST")
  note=$(yq ".skills[$i].note // \"\"" "$MANIFEST")

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
  git clone --depth 1 "https://github.com/$repo.git" "$TMP"

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
done

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
