# Agentic Coding 방법론

## 핵심 원칙

1. **CLAUDE.md = 실수 로그** — 처음부터 완벽하게 쓰지 말 것. 틀릴 때마다 한 줄 추가. 가차없이 정리. → [상세: claude-md-maintenance.md](strategy/claude-md-maintenance.md)
2. **설정 3계층** — 글로벌(보안/개인) → 스택(TS/Python 훅) → 프로젝트(CLAUDE.md). → [상세: settings-layering.md](strategy/settings-layering.md)
3. **하네스 > 프롬프트** — 에이전트 실수 시 프롬프트가 아닌 하네스(훅, 가드레일, 도구)를 개선. → [상세: harness-engineering.md](strategy/harness-engineering.md)
4. **Plan before code** — 코드 전에 항상 research.md → plan.md.

## 방법론 × 도구

| 방법론 | 도구 | 시너지 |
|--------|------|--------|
| Plan → Annotate → Implement | plan.md 파일 | compaction에서 살아남는 영속 기억 |
| Red/Green TDD | PostToolUse 훅 (vitest) | 에이전트 자동 Red→Green 루프 |
| Closed-Loop | lint + tsc + test 훅 체인 | 사람이 루프에서 빠짐 |
| Independent Review | cmux 별도 워크스페이스 | 구현/리뷰 동시 모니터링 |
| Parallel Exploration | cmux + worktree | 같은 스펙, 다른 접근 — 비용 0 |
| Context Engineering | SessionStart 훅 + CLAUDE.md | 매 세션 올바른 컨텍스트 자동 로딩 |

## 코어 테크닉

### 1. Research → Plan → Annotate → Implement (Boris Tane)

1. **Research**: "관련 파일을 깊이 읽고 research.md에 정리해"
2. **Plan**: "구현 계획을 plan.md에 작성해. 아직 구현하지 마"
3. **Annotate**: plan.md를 직접 편집 → 수정/거부/제약 추가 → 1-6회 반복
4. **Implement**: "plan.md의 모든 항목을 구현해. 중간에 멈추지 마"

plan.md가 Claude의 Plan Mode보다 나은 이유: 사람이 직접 편집 가능 + context compaction 생존.

### 2. Red/Green TDD

프롬프트: "Use red/green TDD." 테스트가 실행 가능한 스펙 역할.
PostToolUse에 vitest 추가 → 에이전트가 자동 루프.

### 3. Closed-Loop

코드 작성 → 검증 도구 실행 → 실패 시 에러가 다음 프롬프트 → 수정 → 재검증.
전제: 검증 도구가 deterministic이어야 함.

### 4. Independent Review Agent

구현 에이전트와 다른 세션에서 리뷰. "문제만 찾아. 설명하지 마."
구현 에이전트는 anchoring bias 있음 — fresh context 리뷰가 필수.

### 5. Parallel Exploration

같은 스펙에 다른 접근법으로 두 에이전트 동시 실행 → 비교 → 선택.

## 안티패턴

| 안티패턴 | 해결 |
|---------|------|
| 바로 코드부터 | Research → Plan 필수 |
| "프롬프트 하나만 더" (scope creep) | 스펙에 "하지 않는 것" 명시 |
| 리뷰 안 한 PR | Independent Review Agent |
| 도구 출력으로 토큰 소진 | 서브에이전트로 격리 |
| 단일 에이전트에 전체 위임 | 역할별 분리 |

## Worktree 선택 기준

| 시나리오 | 방식 | 이유 |
|---------|------|------|
| 독립 피처 2개+ | worktree | 파일 격리 |
| 대규모 리팩토링 | /batch | 자동 분할 |
| 빠른 핫픽스 | 같은 폴더 | 오버헤드 0 |
| 솔로 + 파일 수동 분배 | 같은 폴더 | Peter S 스타일 |

pnpm: worktree 설치 거의 즉시. npm/yarn: 10분+ → /batch 사용 권장.

## 참고

- [Boris Tane — How I Use Claude Code](https://boristane.com/blog/how-i-use-claude-code/)
- [Addy Osmani — Agentic Engineering](https://addyosmani.com/blog/agentic-engineering/)
- [Simon Willison — Anti-patterns](https://simonwillison.net/guides/agentic-engineering-patterns/anti-patterns/)
- [Boris Cherny — How he uses CC](https://howborisusesclaudecode.com)
- [Context Engineering — Anthropic](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
