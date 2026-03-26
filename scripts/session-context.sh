#!/bin/bash
# session-context.sh — SessionStart 훅에서 실행
# 개인(WORK.md) / 팀(INDEX.md) 자동 감지

echo "=== Session Context ==="
echo "Branch: $(git branch --show-current 2>/dev/null)"
echo ""
git log --oneline -5 2>/dev/null
echo ""
gh pr view --json title,number,state,url 2>/dev/null || echo "No open PR"
echo ""

# 자동 감지
[ -f WORK.md ] && echo "=== Tasks ===" && head -20 WORK.md
[ -f .claude/memory/INDEX.md ] && echo "=== Team Memory ===" && head -20 .claude/memory/INDEX.md

# Jira 티켓 (브랜치명에서 추출)
TICKET=$(git branch --show-current 2>/dev/null | grep -oE '[A-Z]+-[0-9]+' | head -1)
[ -n "$TICKET" ] && echo "Ticket: $TICKET"
