# Agentic Environment

새 환경에서 동일한 AI-native 개발 환경을 재현하기 위한 레포지토리.

## Quick Start

```bash
# 새 맥에서 전체 환경 세팅
bash scripts/bootstrap.sh

# CLI 도구는 이미 있고 Claude Code 설정만
bash scripts/bootstrap.sh --skip-tools
```

## 구조

```
manifest.yaml               # 모든 설치 대상 선언 (packages, plugins, skills)

scripts/
  bootstrap.sh              # manifest를 읽어서 원샷 환경 세팅
  init.sh                   # 새 프로젝트 스택별 시드 (--ts, --py, --team)
  doctor.sh                 # 환경 헬스체크 (manifest 기반 검증)
  session-context.sh        # SessionStart 훅 — 세션 시작 시 컨텍스트 자동 주입

configs/
  settings.json             # Claude Code 글로벌 설정 (보안/개인만, 스택 훅 없음)

templates/
  CLAUDE.md                 # CLAUDE.md 템플릿 (순수 실수 로그)
  WORK.md                   # 마크다운 태스크 관리 템플릿
  settings.typescript.json  # TypeScript PostToolUse 훅 (format → lint → tsc)
  settings.python.json      # Python PostToolUse 훅 (ruff format → ruff check → pytest)
  settings.team.json        # 팀 프로젝트 협업 규칙 (deny, SessionStart)

docs/
  strategy/
    claude-md-maintenance.md  # DO NOT DO 규칙 생명주기 관리
    settings-layering.md      # 글로벌 vs 스택 vs 프로젝트 설정 분리
    harness-engineering.md    # 하네스 엔지니어링 5가지 기둥
  report.md                   # 리서치 리포트 (시점 스냅샷, 아카이브)
  methodology.md              # 방법론 요약 (strategy/의 목차 역할)
```

## manifest.yaml

모든 설치 대상을 선언적으로 관리. bootstrap.sh가 이 파일을 읽어서 설치.

| 카테고리 | 설치 방법 | 예시 |
|----------|----------|------|
| `brew` | `brew install` | gh, yq |
| `cask` | `brew install --cask` | cmux, antigravity |
| `script` | 공식 설치 스크립트 | nvm, pnpm, bun, claude-code, codex, gemini-cli |
| `managed` | 수동 설치 / 버전 매니저 | Node.js (nvm), Claude Desktop (.dmg) |
| `plugins` | Claude Code 플러그인 | context7, superpowers, dx 등 25개 |
| `skills` | git clone + setup | gstack, cmux-skill, obsidian-skills |
