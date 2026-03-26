# 설정 레이어링 전략

> "Claude Code works great out of the box, so I personally don't customize it much."
> — Boris Cherny (Claude Code 창시자)

## 원칙

글로벌 설정은 lean하게, 프로젝트 레벨이 heavy lifting.

## 3계층 모델

```
┌─────────────────────────────────────────────────┐
│  Layer 1: 글로벌 (모든 프로젝트 동일)              │
│  ~/.claude/settings.json                         │
│  보안 + 개인 설정만                                │
├─────────────────────────────────────────────────┤
│  Layer 2: 스택 (기술 스택이 결정)                   │
│  .claude/settings.json 또는 .claude/settings.local.json │
│  PostToolUse 훅 체인 (TS: tsc, Python: ruff)      │
├─────────────────────────────────────────────────┤
│  Layer 3: 프로젝트 (프로젝트가 성장하며 축적)        │
│  CLAUDE.md, .claude/rules/*.md                   │
│  아키텍처, 컨벤션, DO NOT DO                       │
└─────────────────────────────────────────────────┘
```

## Claude Code 설정 해석 우선순위

Claude Code는 5단계 우선순위로 설정을 해석한다 (높을수록 우선):

1. **Enterprise/Managed** — 조직 관리자 설정 (오버라이드 불가)
2. **Session** — `--settings` 플래그 (일시적)
3. **Project Local** — `.claude/settings.local.json` (gitignored, 개인)
4. **Project Shared** — `.claude/settings.json` (git commit, 팀 공유)
5. **User Global** — `~/.claude/settings.json` (개인 기본값)

**머지 규칙**: 배열 필드(permissions.allow, permissions.deny)는 스코프 간 **결합 + 중복 제거**. 스칼라 필드(model)는 높은 우선순위가 승리. deny 규칙은 스코프 무관하게 항상 allow를 이김.

## Layer 1: 글로벌 — 무엇을 넣는가

**넣어야 하는 것** (모든 프로젝트에서 동일):

```json
{
  "permissions": {
    "deny": [
      "Bash(rm -rf *)",
      "Read(.env)", "Read(.env.*)",
      "Write(.env)", "Write(.env.*)"
    ]
  },
  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" },
  "statusLine": { "type": "command", "command": "..." },
  "enabledPlugins": { "...": true },
  "skipDangerousModePermissionPrompt": true
}
```

**넣으면 안 되는 것**:
- PostToolUse 훅 (스택 의존 — Python 프로젝트에서 `npx tsc` 깨짐)
- `Write(src/**)` allow 규칙 (프로젝트 구조 의존)
- `Bash(npm run *)` allow 규칙 (패키지 매니저 의존)

## Layer 2: 스택 — 무엇이 다른가

| 스택 | format | lint | typecheck | test |
|------|--------|------|-----------|------|
| **TypeScript** | pnpm format | pnpm lint --fix | npx tsc --noEmit | vitest |
| **Python** | ruff format | ruff check --fix | — | pytest |
| **Go** | gofmt | go vet | — | go test |
| **Rust** | cargo fmt | cargo clippy | — | cargo test |

이 레포에서 `templates/settings.typescript.json`, `templates/settings.python.json`이 이 역할.

**적용 방법**: `init.sh --ts`가 템플릿을 프로젝트의 `.claude/settings.json`으로 복사.

## Layer 3: 프로젝트 — 템플릿화 불가

프로젝트가 성장하면서 자연스럽게 채워지는 것:

- **CLAUDE.md** — DO NOT DO 실수 로그 (claude-md-maintenance.md 참조)
- **`.claude/rules/*.md`** — 경로별 지시 (예: `*.tsx` 파일 편집 시 디자인 시스템 규칙)
- **아키텍처 결정** — 프로젝트 고유의 컨벤션, 도메인 용어

이 레포에서 제공하는 것은 **빈 시드**(CLAUDE.md 템플릿)뿐이고, 내용은 프로젝트가 채운다.

## Trail of Bits 참조 패턴

보안 팀의 글로벌 CLAUDE.md:
- 개발 철학 ("no speculative features, no premature abstraction")
- 함수 길이, 복잡도, 라인 폭 제한
- 언어별 툴체인 (Python: uv/ruff/ty, TypeScript: oxlint/vitest, Rust: clippy/cargo deny)
- → 하나의 글로벌 CLAUDE.md로 모든 스택 커버 가능

## 안티패턴

| 안티패턴 | 결과 | 대안 |
|---------|------|------|
| 글로벌에 TS 훅 넣기 | Python/Go 프로젝트에서 에러 | 스택별 템플릿으로 분리 |
| 글로벌에 `Write(src/**)` | 프로젝트 구조 달라지면 무용 | 프로젝트 레벨에서 설정 |
| 프로젝트 설정 없이 글로벌만 | 스택별 최적화 불가 | init.sh로 시드 |
| 모든 규칙을 CLAUDE.md에 | 비대화 | .claude/rules/*.md로 분리 |

## 참고 자료

- [Claude Code Settings — Official Docs](https://code.claude.com/docs/en/settings) — 5단계 우선순위
- [Trail of Bits claude-code-config](https://github.com/trailofbits/claude-code-config) — 보안팀 패턴
- [How Boris Uses Claude Code](https://howborisusesclaudecode.com) — 최소 글로벌 설정
- [Claude Code Rules Directory](https://claudefa.st/blog/guide/mechanics/rules-directory) — Progressive Disclosure
