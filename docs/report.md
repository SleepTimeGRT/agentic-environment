# AI-Native 개발 환경 업그레이드 리포트

> **Date**: 2026-03-25
> **Author**: minchul (Claude Code assisted)
> **Last Updated**: 2026-03-26

---

## 3가지 핵심 원칙

**1. CLAUDE.md = 실수 로그** (Boris Cherny, CC 창시자)
> "Claude가 잘못할 때마다 CLAUDE.md에 추가한다. 그래서 다음엔 안 틀린다."

처음부터 완벽하게 쓰지 말 것. 틀릴 때마다 한 줄 추가 → 모든 줄이 실제 가치를 가짐.

**2. 최소 세팅에서 시작**
개인 프로젝트 MVP는 파일 3개: `CLAUDE.md` + `WORK.md` + `~/.claude/settings.json`.
나머지(cmux, hooks, MCP)는 필요할 때 점진적 추가.

**3. 개인 vs 팀 = git commit 여부**
개인: `~/.claude/` (글로벌, 비공개). 팀: `.claude/` (프로젝트, git commit → clone 시 전원 적용).

---

## TL;DR

| 항목 | 설명 | 범위 | 즉시 적용 |
|------|------|------|----------|
| **Auto Mode** | 안전한 자동 권한 승인 (3/24) | 모두 | ✅ |
| **cmux** | 멀티 에이전트 터미널 — 병렬 작업의 게임 체인저 | 모두 | ✅ |
| **/batch** | 빌트인 병렬 worktree 실행 | 모두 | ✅ |
| **SessionStart 훅** | 세션 컨텍스트 자동 주입 | 모두 | ✅ |
| **Plan → Annotate → Implement** | 코드 전에 plan.md 작성 + 사람이 교정 | 모두 | ✅ |
| **Red/Green TDD** | 테스트 먼저, 에이전트가 통과시킴 | 모두 | ✅ |
| **WORK.md** | 마크다운 태스크 관리 (Jira 대체) | 개인 | ✅ |
| **Obsidian CLI** | 지식-코드 연동 | 선택 | 선택적 |
| **deny 규칙** | .env 보호, rm -rf 차단 | 팀 (개인 선택) | ✅ |
| **PostToolUse 훅 (TS)** | 자동 format → lint → tsc | TypeScript 프로젝트 | ✅ |
| **하네스 엔지니어링** | 에이전트 환경 설계 패러다임 | 모두 | 참조 |
| **Jira 통합** | 티켓 → 설계 → 구현 자동화 | vProp | 구축 완료 |

---

# Part 1: 즉시 적용 가능한 업그레이드

## 1.1 Auto Mode (3/24 출시)

```
  Default          → 모든 도구 사용에 승인 필요
  Auto Mode (NEW)  → AI가 안전성 판단, 위험한 것만 차단
  --dangerously... → 모든 것 자동 승인 (위험)
```

별도 설치 없음. `settings.json`의 수십 개 `allow` 규칙을 대부분 대체.
안전한 작업(파일 읽기, 편집, 테스트)은 자동, 위험한 작업(mass delete, force push)만 차단.

> Auto Mode를 쓰더라도 **deny 규칙은 유지**해야 함 (`.env` 읽기, `rm -rf` 등).

## 1.2 /batch (2/28)

대규모 태스크를 자동으로 5-30개 단위로 분할 → 각각 독립 worktree에서 병렬 실행.

```bash
/batch "모든 API 라우트에서 에러 핸들링을 표준 패턴으로 통일"
```

자동으로: 파일 분석 → 단위 분할 → worktree agent N개 → `/simplify` → 테스트 → PR.
수동 worktree 관리 불필요.

## 1.3 SessionStart 훅

매 세션마다 반복하는 "git log", "현재 브랜치"를 자동화.

**session-context.sh** (범용 — 개인/팀 자동 감지):

```bash
#!/bin/bash
echo "=== Session Context ==="
echo "Branch: $(git branch --show-current 2>/dev/null)"
echo ""
git log --oneline -5 2>/dev/null
echo ""
gh pr view --json title,number,state,url 2>/dev/null || echo "No open PR"
echo ""
# 자동 감지: WORK.md(개인) 또는 INDEX.md(팀)
[ -f WORK.md ] && echo "=== Current Tasks ===" && head -20 WORK.md
[ -f .claude/memory/INDEX.md ] && echo "=== Team Memory ===" && head -20 .claude/memory/INDEX.md
```

설정: Part 3 세팅 레시피 참조.

## 1.4 기타 최신 기능

| 기능 | 설명 |
|------|------|
| **Voice Mode** | 스페이스바 push-to-talk. `/voice` 활성화 |
| **Code Review 플러그인** | 5개 병렬 에이전트 PR 리뷰. $15-25/회 |
| **--bare 플래그** | 헤드리스 실행 최적화 (hooks/LSP/plugin 스킵) |
| **Background Agents** | 장기 서브태스크 백그라운드 실행 |

### Hooks: 4가지 핸들러 타입

| Handler | 용도 | 예시 |
|---------|------|------|
| `command` | 셸 명령 실행 | format, lint, tsc |
| `http` | 외부 서비스 JSON POST | CI/CD webhook |
| `prompt` | Claude에게 프롬프트 주입 | 동적 가드레일 |
| `agent` | 별도 에이전트 생성 | 비동기 검증 |

---

# Part 2: 도구

## 2.1 cmux — 멀티 에이전트 터미널

에이전트를 여러 개 동시에 돌릴 때의 핵심 도구. 개인/팀 모두 해당.

**일반 터미널 대비 차별점:**
- **세로 사이드바**: 워크스페이스별 git branch, PR 번호, 포트, 최근 알림
- **알림 링**: approval 대기 시 파란 링 + macOS 알림 (`Cmd+Shift+U`로 점프)
- **내장 브라우저**: WebKit, 에이전트가 DOM 조작 가능
- **GPU 가속**: libghostty 렌더러, Native Swift/AppKit

### 설치

```bash
brew tap manaflow-ai/cmux && brew install --cask cmux
mkdir -p ~/.local/bin
ln -s /Applications/cmux.app/Contents/MacOS/cmux ~/.local/bin/cmux
```

macOS 14.0+ 필수. 무료 + 오픈소스 (AGPL-3.0).

### cmux CLI (에이전트가 자기 환경을 제어)

```bash
cmux new-workspace --name "feature-auth"   # 워크스페이스 생성
cmux notify "PR ready for review"          # 알림
cmux set-progress 75                       # 진행률
cmux new-split --direction horizontal      # 패널 분할
cmux browser navigate "http://localhost:3000"  # 내장 브라우저
```

### cmux 스킬

```bash
git clone https://github.com/hashangit/cmux-skill.git /tmp/cmux-skill
cd /tmp/cmux-skill && chmod +x install.sh && ./install.sh
```

`CMUX_*` 환경변수 감지 시 자동 활성화.

### 제한사항

- macOS 전용. 재시작 시 프로세스 복원 안 됨 (레이아웃은 보존).
- Claude Code 샌드박스가 `/tmp/cmux.sock` 차단할 수 있음 → sandbox access mode 설정 필요.

---

## 2.2 Obsidian CLI — 지식-코드 연동 (선택)

Obsidian v1.12의 공식 CLI. 100개+ 명령. Early Access ($25 Catalyst License, 추후 무료).

### Claude Code 연동

**A. kepano/obsidian-skills** (Obsidian CEO 제작, 권장):
```bash
git clone https://github.com/kepano/obsidian-skills.git /tmp/obsidian-skills
cp -r /tmp/obsidian-skills/obsidian-cli ~/.claude/skills/obsidian-cli
cp -r /tmp/obsidian-skills/obsidian-markdown ~/.claude/skills/obsidian-markdown
```

**B. MCP 서버** — `.mcp.json`에 추가:
```json
{ "mcpServers": { "obsidian": { "command": "npx", "args": ["-y", "obsidian-claude-code-mcp"], "env": { "OBSIDIAN_VAULT_PATH": "/path/to/vault" } } } }
```

**양방향 연동**: vault는 마크다운 파일 → Claude Code가 직접 읽기/쓰기. 별도 API 불필요.
설계 문서 참조, 세션 요약 기록, 트러블슈팅 검색, ADR 자동 생성.

---

# Part 3: 세팅 레시피

> 핵심: CLAUDE.md를 실수 로그로 취급. 처음부터 완벽하게 쓰지 말고 틀릴 때마다 추가.

## 3.1 개인 프로젝트 MVP (30분)

파일 **2개** + 설정 **1개**:

**`CLAUDE.md`** (프로젝트 루트):
```markdown
# [프로젝트명]

## DO NOT DO
(Claude가 틀릴 때마다 여기에 추가. 모든 줄이 실제 실패에서 나온 것이어야 함.)
```

> Stack, Commands, Workflow는 CLAUDE.md에 넣지 않음.
> - Stack/Commands: README.md, package.json에서 추론 가능
> - Workflow (research→plan→implement, TDD 등): gstack 스킬이 이미 커버
> - CLAUDE.md = 순수 실수 로그 (Boris Cherny 원칙)

**`WORK.md`** (프로젝트 루트):
```markdown
# WORK.md

## Doing
- [ ] [현재 작업]

## Next Up
- [다음 작업들]

## Done
- [x] YYYY-MM-DD: [완료된 작업]
```

**`~/.claude/settings.json`** (글로벌, 한 번만):
```json
{
  "permissions": {
    "deny": ["Bash(rm -rf *)", "Read(.env)", "Read(.env.*)"]
  },
  "hooks": {
    "SessionStart": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "scripts/session-context.sh", "timeout": 5000 }] }
    ]
  }
}
```

> Auto Mode 사용 시 `allow` 규칙 불필요. `deny`만 유지.

**TypeScript 프로젝트라면** `.claude/settings.json`에 추가 (Solo/Team 무관):
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "pnpm format" },
          { "type": "command", "command": "pnpm lint --fix" },
          { "type": "command", "command": "npx tsc --noEmit --pretty 2>&1 | head -20", "timeout": 20000 }
        ]
      }
    ]
  }
}
```

> format → lint → tsc 훅 체인은 팀 규모가 아닌 **개발 환경(스택)**이 결정. TypeScript면 Solo든 Team이든 필수.

### 고급: Boris Tane 스타일

태스크마다 `research.md` → `plan.md` → annotation (1-6회) → 구현:

```
프로젝트/
├── CLAUDE.md
├── WORK.md
├── research.md        # Claude가 작성, 사용자가 검증
├── plan.md            # Claude가 작성, 사용자가 annotation, 반복
└── specs/             # SDD 스펙 (태스크별)
    └── feature-a.md   # Intent, Constraints, Acceptance Criteria
```

### 고급: 파일 기반 이슈 트래커

WORK.md보다 구조화, Jira보다 가벼움:

```
issues/
├── open/ISSUE-003-add-search.md
├── wip/ISSUE-001-auth-flow.md
├── closed/ISSUE-002-login-bug.md
└── OVERVIEW.md              # 자동 생성 대시보드
```

`.claude/commands/`에 `/create-issue`, `/complete-issue` 추가하여 관리.

---

## 3.2 소규모 팀 MVP (반나절)

1명이 세팅 → 전원 `clone`만 하면 즉시 적용.

**`CLAUDE.md`** (프로젝트 루트, git commit):
```markdown
# [프로젝트명]

## DO NOT DO
(Claude가 틀릴 때마다 팀원 누구나 추가 → PR로 리뷰)
```

> 팀 프로젝트에서도 CLAUDE.md는 순수 실수 로그. Commands/Architecture/Conventions는 README.md와 코드 자체에서 추론 가능.

**`.claude/settings.json`** (git commit — 협업 규칙):
```json
{
  "permissions": {
    "deny": [
      "Bash(rm -rf *)",
      "Bash(git push --force *)",
      "Read(.env)",
      "Read(.env.*)"
    ]
  },
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "scripts/session-context.sh", "timeout": 5000 }
        ]
      }
    ]
  }
}
```

> TypeScript 프로젝트라면 PostToolUse 훅 체인 (format → lint → tsc)을 추가. Part 3.1의 `settings.typescript.json` 참조.
> 이 훅 체인은 팀 규모가 아닌 **스택**이 결정 — Solo/Team 무관.

**`.claude/settings.local.json`** (gitignored — 개인 오버라이드):
```json
{ "permissions": { "allow": ["Bash(bun run *)"] } }
```

**`CLAUDE.local.md`** (gitignored):
```markdown
## My Setup
- git remote: origin = fork, upstream = 본 repo
```

**`.claude/commands/pr-review.md`** (git commit — 팀 표준):
```markdown
PR을 리뷰해줘. 확인할 것:
1. 변경이 태스크 요구사항을 충족하는지
2. 에러 핸들링 누락 없는지
3. 테스트 충분한지
```

**`.mcp.json`** (git commit — 팀 공용):
```json
{ "mcpServers": { "trigger": { "command": "npx", "args": ["trigger.dev@latest", "mcp"] } } }
```

### 개인 vs 팀: 핵심 차이

| 항목 | 개인 | 팀 |
|------|------|-----|
| CLAUDE.md | `~/.claude/CLAUDE.md` (실수 로그) | 프로젝트 루트 (git commit, 실수 로그) |
| settings.json | `~/.claude/settings.json` | `.claude/settings.json` (git commit) |
| deny 규칙 | 선택 | **필수** |
| PostToolUse 훅 | **스택이 결정** (TS면 필수) | **스택이 결정** (TS면 필수) |
| .claude/commands/ | 개인 편의 | **팀 표준** 워크플로우 |
| MCP | `~/.claude.json` | `.mcp.json` (git commit) |
| CLAUDE.local.md | 불필요 | **필수** (개인 환경 차이) |
| 태스크 관리 | WORK.md | Jira + MCP + 스킬 |
| 메모리 | auto memory 기본 | 팀 공유 (.claude/memory/) |

---

# Part 4: 워크플로우 패턴

## 4.1 태스크 관리

| | **WORK.md** | **파일 이슈 트래커** | **Jira** |
|---|---|---|---|
| 적합 환경 | 개인, 사이드 프로젝트 | 소규모 팀 (2-5명) | 중대규모 팀 |
| 오버헤드 | 0 | 낮음 | 높음 |
| CC 연동 | 직접 파일 읽기/쓰기 | 커맨드 (`/create-issue`) | MCP + 커스텀 스킬 |

Claude Code 프롬프트 예시:
```
"WORK.md 읽고 Doing의 첫 번째 항목 진행해. 완료하면 Done으로 이동해."
"specs/auth-ratelimit.md 읽고 구현해. AC 완료 시 체크해."
```

## 4.2 단일 태스크 (Single Agent)

```
스펙/태스크 → Plan Mode로 계획 → 사용자 승인 → worktree에서 구현
→ 검증 (훅이 자동: lint+tsc+test) → 독립 리뷰 → 커밋 + PR
```

cmux: `cmux new-workspace --name "auth-ratelimit"` → `claude` → 사이드바 모니터링.

## 4.3 병렬 작업 (Multi-Agent)

각 에이전트가 독립 worktree에서 독립 태스크. cmux 4-pane으로 모니터링.

```bash
git worktree add .claude/worktrees/fix-task-a -b fix/task-a main
cd .claude/worktrees/fix-task-a && claude
```

### Worktree vs 같은 폴더 — 언제 뭘 쓸까

같은 폴더에서 여러 에이전트를 돌리면 **변경이 뒤섞임** — git status에 두 에이전트의 변경이 혼합, 커밋 구분 불가, 함수 시그니처 변경 시 다른 에이전트가 깨짐.

Peter Steinberger가 "같은 폴더가 빠르다"고 한 조건: 솔로 프로젝트 + 에이전트별 파일을 사람이 직접 분배 + 코드를 읽지 않고 ship. **팀 프로젝트에서는 해당 안 됨**.

| 시나리오 | 방식 | 이유 |
|---------|------|------|
| 독립 피처 2개+ 동시 | **worktree** | 파일 격리 필수 |
| 대규모 리팩토링 | **/batch** | 자동 분할 + 자동 worktree |
| 코드 리뷰 중 다른 작업 | **worktree** | 클래식 유스케이스 |
| 빠른 핫픽스 1개 | **같은 폴더** | 오버헤드 0 |

> pnpm을 쓰는 팀 프로젝트에서는 worktree가 최선 (설치 거의 즉시).
> npm/yarn: worktree당 node_modules 재설치 10분+ → 사전 pool 또는 /batch 사용.

## 4.4 대규모 리팩토링

**방법 A: /batch (권장)**
```bash
/batch "모든 API 라우트에서 에러 핸들링을 표준 패턴으로 통일"
```

**방법 B: 수동 오케스트레이션** (/batch 부적합 시 — 복잡한 의존성)
```
Phase 1: 분석 → 독립 단위 분할
Phase 2: 병렬 실행 (각각 worktree)
Phase 3: 통합 → 순차 머지 + 충돌 해결
```

---

# Part 5: vProp 팀 특화

## 5.1 현재 세팅

| 항목 | 상태 |
|------|------|
| Hooks | PostToolUse: format + lint + tsc |
| Plugins | 27개 (superpowers, figma, atlassian…) |
| Skills | 42개 글로벌 + 13개 프로젝트 |
| MCP | Trigger.dev, Slack, Figma, Amplitude, Atlassian, Notion, Playwright |
| Memory | Team shared (.claude/memory/) + git |
| Worktrees | .claude/worktrees/ + post-checkout hook |
| Jira 연동 | /create-ticket, /plan-ticket, /implement-ticket |

커뮤니티 대비 **상위 5%**.

## 5.2 Jira 티켓 워크플로우

```
Jira (VP-XXX) → /create-ticket → /plan-ticket → /implement-ticket → PR
```

각 스킬이 Atlassian MCP로 티켓 상태 자동 업데이트.

## 5.3 팀 메모리

```
.claude/memory/
  MEMORY.md, INDEX.md, decisions/, patterns/, troubleshooting/, changelog/
```

Git-tracked → 팀 공유. 세션 시작 시 자동 로딩.

## 5.4 갭 분석

| 영역 | 현재 | 개선 방향 |
|------|------|----------|
| Auto Mode | 수동 퍼미션 | Auto Mode 전환 + allow 규칙 정리 |
| /batch | 수동 worktree | 대규모 리팩토링에 활용 |
| SDD | Plan Mode만 | /plan-ticket에 SDD 템플릿 통합 |

---

---

> Part 6, 7은 strategy/ 문서로 이전됨.
> - **방법론**: [docs/methodology.md](methodology.md)
> - **하네스 엔지니어링**: [docs/strategy/harness-engineering.md](strategy/harness-engineering.md)

---

# Part 8: 2026 Q1 트렌드

## SDD (Spec-Driven Development)

Martin Fowler, GitHub, Amazon(Kiro) 채택. 코드가 아닌 **스펙이 source of truth**.

```markdown
# Feature: [제목]
## Intent — 뭘 만들건지 (1-2문장)
## Constraints — 제약 조건 (체크리스트)
## Acceptance Criteria — 완료 기준 (실행 가능한 검증)
## Out of Scope — 명시적으로 하지 않는 것
```

**개인**: WORK.md에 `spec: specs/feature-a.md` 링크. **팀**: Jira Description에 포함.
프롬프트: `"specs/auth-ratelimit.md 읽고 구현해. AC 완료 시 체크해."`

## 경쟁 도구

| 도구 | 포지션 |
|------|--------|
| **Kiro** (Amazon) | VS Code fork + 빌트인 SDD |
| **Codex** (OpenAI) | CC 경쟁 CLI. `/codex`로 second opinion |
| **Gemini CLI** (Google) | 무료 티어 넉넉 |

## 향후 과제

| 항목 | 우선순위 | 범위 |
|------|---------|------|
| Auto Mode 팀 배포 + allow 규칙 정리 | P1 | vProp |
| SDD 템플릿을 /plan-ticket에 통합 | P2 | vProp |
| 생산성 측정 (도입 2-3주 후) | P3 | 범용 |

---

# 참고 자료

## 방법론
- [How I Use Claude Code — Boris Tane](https://boristane.com/blog/how-i-use-claude-code/) (Research→Plan→Annotate→Implement)
- [Agentic Engineering — Addy Osmani](https://addyosmani.com/blog/agentic-engineering/) (Factory Model)
- [Context Engineering — Anthropic](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [SDD — GitHub Blog](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/)
- [SDD Tools — Martin Fowler](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)
- [Anti-patterns — Simon Willison](https://simonwillison.net/guides/agentic-engineering-patterns/anti-patterns/)
- [work.md 패턴 — 요즘IT](https://yozm.wishket.com/magazine/detail/3617/)

## 세팅 & 워크플로우
- [How Boris Cherny Uses CC](https://howborisusesclaudecode.com) (CC 창시자)
- [Trail of Bits claude-code-config](https://github.com/trailofbits/claude-code-config) (보안 팀 예시)
- [Peter Steinberger — AI Dev Workflow](https://steipete.me/posts/2025/optimal-ai-development-workflow) (worktree 거부 이유)
- [Worktree 한계 — Dave Schumaker](https://daveschumaker.net/use-git-worktrees-they-said-itll-be-fun-they-said/)
- [파일 이슈 트래커 — Thomas Landgraf](https://thomaslandgraf.substack.com/p/how-i-replaced-jira-with-a-600-line)

## Claude Code 기능
- [Auto Mode](https://claude.com/blog/auto-mode) (2026-03-24)
- [/simplify, /batch — Boris Cherny](https://x.com/bcherny/status/2027534984534544489) (2026-02-28)
- [Code Review 플러그인 — TechCrunch](https://techcrunch.com/2026/03/09/anthropic-launches-code-review-tool-to-check-flood-of-ai-generated-code/)
- [Hooks 가이드](https://code.claude.com/docs/en/hooks)
- [Best Practices](https://code.claude.com/docs/en/best-practices)

## 도구
- [cmux](https://cmux.com) | [GitHub](https://github.com/manaflow-ai/cmux) (AGPL-3.0)
- [cmux skill](https://github.com/hashangit/cmux-skill)
- [Obsidian CLI](https://help.obsidian.md/cli) | [obsidian-skills](https://github.com/kepano/obsidian-skills)

## 하네스 엔지니어링
- [Harness Engineering — OpenAI](https://openai.com/index/harness-engineering/) (Codex 팀 5원칙)
- [Harness Design for Long-Running Apps — Anthropic](https://www.anthropic.com/engineering/harness-design-long-running-apps) (Planner-Generator-Evaluator)
- [Effective Harnesses for Long-Running Agents — Anthropic](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Harness Engineering — Martin Fowler / Birgitta Bockeler](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [Agent Harness in 2026 — Philipp Schmid](https://www.philschmid.de/agent-harness-2026) (CPU/RAM/OS 비유)
- [From Prompt to Harness Engineering: Three Eras — SoftmaxData](https://softmaxdata.com/blog/from-prompt-engineering-to-harness-engineering-the-three-eras-of-building-with-ai/)
- [Skill Issue: Harness Engineering for Coding Agents — HumanLayer](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)
- [하네스 엔지니어링 — GPTers](https://www.gpters.org/dev/post/harness-engineering-easy-follow-25VIHLOgYq6YGzt) (한국어)

## 커뮤니티
- [52일 74개 릴리즈 — Product Compass](https://www.productcompass.pm/p/claude-shipping-calendar)
- [claude-code-hooks 모음](https://github.com/karanb192/claude-code-hooks)
- [vProp #dev Slack — cmux 토론](https://v6x.slack.com/archives/CCVA0GYAY/p1773731207933849)
