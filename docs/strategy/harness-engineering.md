# 하네스 엔지니어링 전략

> "모델을 바꾸기 전에, 하네스를 점검하라. 대부분의 경우 ROI가 가장 높다."

## 정의

**하네스 엔지니어링** = AI 에이전트가 자율적으로 작동할 수 있도록 환경(hooks, permissions, guardrails, observability, feedback loops)을 설계하는 것.

승마 비유: 모델이 말이라면, 하네스는 그 힘을 생산적으로 방향짓는 장비.

## 세 시대

| | Prompt Engineering | Context Engineering | Harness Engineering |
|---|---|---|---|
| **핵심 질문** | "어떤 말을 할까" | "어떤 정보를 줄까" | "어떤 환경을 만들어줄까" |
| **설계 대상** | 지시문 텍스트 | 추론 시점의 모든 토큰 | 외부 제약과 시스템 |
| **작업 단위** | 단일 API 호출 | 멀티턴 세션 | 기능 전체 (버그→머지) |
| **실패 대응** | 프롬프트 재작성 | 컨텍스트 데이터 점검 | 역량 또는 가드레일 추가 |

컴퓨팅 비유 (Philipp Schmid): 모델 = CPU, 컨텍스트 윈도우 = RAM, 하네스 = OS, 에이전트 = 애플리케이션.

## 5가지 기둥

### 1. 도구 오케스트레이션
에이전트가 접근할 수 있는 도구, 호출 방법, 권한 정의.

**이 레포에서**: `configs/settings.json` — plugins, MCP servers, permissions.allow

### 2. 가드레일과 안전 제약
권한 경계의 결정론적 규칙, 검증 체크포인트.

**이 레포에서**: `permissions.deny` (`.env`, `rm -rf`), `settings.team.json` (`--force` 방지)

### 3. 에러 복구와 피드백 루프
재시도 로직, 자체 검증 루프, 롤백 메커니즘, 루프 감지.

**이 레포에서**: `templates/settings.typescript.json`의 PostToolUse 훅 체인 (format → lint → tsc). 에이전트가 편집 후 자동으로 검증 루프를 돌림. 단, 재시도/롤백/루프 감지는 Claude Code 자체와 gstack 스킬이 담당.

### 4. 관측성 (Observability)
에이전트 행동 로깅, 토큰 사용 추적, 의사결정 기록.

**이 레포에서**: `scripts/session-context.sh` (세션 시작 컨텍스트), statusLine 설정 (ykdojo/claude-code-tips 접근법)

### 5. Human-in-the-Loop 체크포인트
고위험 순간의 전략적 승인 게이트.

**이 레포에서**: Auto Mode (위험 작업만 차단), plan.md 승인 워크플로우 (gstack 스킬)

## OpenAI Codex 팀의 5원칙

3명이 5개월간 100만 줄, 1,500 PR, 수동 타이핑 0줄:

1. **에이전트가 볼 수 없으면 존재하지 않는다** — 모든 의사결정을 레포 안 문서로
2. **"왜 실패하나" 대신 "어떤 역량이 빠졌나"를 묻기** — 프롬프트 조정 대신 도구 빌드
3. **문서화보다 기계적 강제** — 규칙을 산문이 아닌 린터/훅으로
4. **에이전트에게 눈을 줘라** — 관측성과 시각적 도구 연결
5. **매뉴얼이 아닌 지도** — 간결한 아키텍처 오버뷰, 상세 문서 아님

## 실증 데이터

| 실험 | 결과 |
|------|------|
| **Hashline** — 편집 포맷만 변경 | 동일 모델, 성능 6.7% → **68.3%** |
| **LangChain** — 하네스 개선만 | 벤치마크 52.8% → **66.5%**, 순위 ~30위 → ~5위 |
| **OpenAI Codex** — 하네스 원칙 적용 | 3명 × 5개월 = 100만 줄, **~10x 생산성** |

모델 가중치 변경 없이 하네스만으로 10배 성능 차이가 발생.

## 이 레포에서의 실행 방법

새 프로젝트를 시작할 때 `init.sh`가 심는 시드가 곧 하네스의 기초:

```
init.sh --ts
  ├── CLAUDE.md              → 기둥 3 (피드백: 실수 로그로 규칙 축적)
  ├── WORK.md                → 기둥 5 (HitL: 태스크 승인)
  └── .claude/settings.json  → 기둥 1-2 (도구 + 가드레일 + 피드백 루프)
       └── PostToolUse 훅     → 기둥 3 (format → lint → tsc 자동 검증)

bootstrap.sh
  ├── ~/.claude/settings.json → 기둥 1-2 (글로벌 도구 + 가드레일)
  └── statusLine              → 기둥 4 (관측성)
```

## 안티패턴

| 안티패턴 | 대안 |
|---------|------|
| 에이전트가 실수하면 프롬프트 수정 | 하네스에 역량 추가 (도구, 훅, 규칙) |
| 모든 규칙을 산문으로 | 기계적 강제 (린터, PostToolUse 훅) |
| 단일 에이전트에 전체 위임 | 역할별 에이전트 분리 + 관측성 |
| 하네스를 처음부터 완벽하게 설계 | 실패할 때마다 점진적 추가 (CLAUDE.md = 실수 로그) |
| 모델 업그레이드만 기다리기 | 하네스 개선이 더 빠르고 확실한 ROI |

## 참고 자료

- [Harness Engineering — OpenAI](https://openai.com/index/harness-engineering/)
- [Harness Design for Long-Running Apps — Anthropic](https://www.anthropic.com/engineering/harness-design-long-running-apps)
- [Harness Engineering — Martin Fowler / Birgitta Bockeler](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [Agent Harness in 2026 — Philipp Schmid](https://www.philschmid.de/agent-harness-2026)
- [From Prompt to Harness Engineering — SoftmaxData](https://softmaxdata.com/blog/from-prompt-engineering-to-harness-engineering-the-three-eras-of-building-with-ai/)
- [Skill Issue: Harness Engineering — HumanLayer](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)
