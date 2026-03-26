# CLAUDE.md 규칙 생명주기 관리

> "A monolithic manual turns into a graveyard of stale rules."
> — OpenAI Codex 팀, Harness Engineering

## 문제

CLAUDE.md의 DO NOT DO 섹션은 에이전트가 실수할 때마다 규칙을 추가하는 "실수 로그" 방식으로 운영된다 (Boris Cherny 원칙). 그러나 모델이 업그레이드되면 이전에 실수했던 것을 더 이상 실수하지 않게 되면서:

1. **컨텍스트 낭비** — 불필요한 규칙이 시스템 프롬프트 토큰을 차지
2. **과잉 제약** — 해결된 문제에 대해 에이전트가 불필요하게 조심
3. **신호 약화** — Anthropic 권장 200줄 이하, 300줄 넘으면 "Claude starts losing signal"

## 원칙

**"Ruthlessly edit your CLAUDE.md over time."** — Boris Cherny (Claude Code 창시자)

추가만 하지 말고, 가차없이 정리하라. 모든 규칙에는 생명주기가 있다.

## 규칙 형식

날짜와 검증 조건을 포함한 형식으로 작성:

```markdown
## DO NOT DO

- 2026-03-15: pnpm workspace에서 --filter 없이 install 하지 말 것
  verify: pnpm install이 루트에서 에러 발생하는지 확인

- 2026-02-20: API 라우트에서 try-catch 없이 에러 핸들링 생략하지 말 것
  verify: 새 API 라우트를 try-catch 없이 생성하는지 확인
```

- **날짜**: 규칙이 추가된 시점. 3개월 이상 지나면 검증 대상.
- **verify**: 규칙이 아직 필요한지 테스트할 수 있는 조건. 있으면 자동 검증 가능.

## 유지보수 전략

### 1. 주기적 정리 (월 1회)

세션 시작 시 에이전트에게 요청:

```
CLAUDE.md의 DO NOT DO 항목을 읽고, 현재 모델에서 더 이상 해당되지 않는 항목이 있으면 알려줘.
각 항목에 대해: 여전히 필요한 이유 또는 제거해도 되는 이유를 설명해.
```

**중요**: 에이전트가 제안만 하고, 사람이 삭제한다. 에이전트가 자기 제약을 스스로 제거하는 것은 신뢰도 문제가 있다.

### 2. 200줄 상한 (Anthropic 권장)

CLAUDE.md가 200줄을 넘으면 정리 시점:
- 태스크별 지시는 `.claude/rules/*.md`로 분리 (Progressive Disclosure)
- 더 이상 실수하지 않는 규칙 제거
- 중복 규칙 통합

### 3. ADR 형식 (대규모 프로젝트)

팀 프로젝트에서 규칙이 많을 때, status 필드로 생명주기 관리:

```markdown
## DO NOT DO

### active
- 2026-03-15: pnpm workspace에서 --filter 없이 install 하지 말 것

### deprecated (검증 필요)
- 2025-11-20: TypeScript strict 모드에서 any 타입 사용하지 말 것
  note: 모델 업그레이드 후 자연스럽게 지켜지는 것으로 보임
```

### 4. Doc-gardening agent (자동화)

OpenAI Codex 팀의 접근법 — 주기적으로 문서를 스캔하고 fix-up PR을 자동 생성:

- CI에 린터를 추가해서 CLAUDE.md의 규칙이 실제 코드와 맞는지 검증
- 3개월 이상 된 규칙 중 verify 조건이 없는 것을 경고
- 팀 프로젝트에서는 PR 리뷰 시 CLAUDE.md 변경도 함께 리뷰

## 안티패턴

| 안티패턴 | 결과 | 대안 |
|---------|------|------|
| 추가만 하고 정리 안 함 | 규칙 비대화, 신호 약화 | 월 1회 정리 루틴 |
| 에이전트가 자기 규칙 삭제 | 자기 제약 제거 위험 | 제안만, 사람이 삭제 |
| 모든 지시를 CLAUDE.md에 | 300줄 초과, 토큰 낭비 | Progressive Disclosure |
| 날짜 없이 규칙 추가 | 언제 추가됐는지 모름, 정리 불가 | 항상 날짜 태깅 |
| 코드에서 해결된 것도 규칙 유지 | 과잉 제약 | verify 조건으로 자동 검증 |

## 참고 자료

- [Harness Engineering — OpenAI](https://openai.com/index/harness-engineering/) — "doc-gardening agent" 개념
- [Build the Harness, Not the Code — Vitthal Mirji](https://vitthalmirji.com/2026/02/build-the-harness-not-the-code-a-staff/principal-engineers-guide-to-ai-agent-systems/) — "stale rules", ADR 형식
- [Boris Cherny on X](https://x.com/bcherny/status/2017742747067945390) — "Ruthlessly edit your CLAUDE.md"
- [Best Practices — Claude Code Docs](https://code.claude.com/docs/en/best-practices) — 200줄 권장
- [Effective Context Engineering — Anthropic](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — Progressive Disclosure
