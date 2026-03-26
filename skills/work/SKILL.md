---
name: work
description: >
  This skill should be used when the user asks to update WORK.md,
  mark a task as shipped, add or move tasks, report a blocker,
  check project status, or when the week has changed and rotation
  is needed. Trigger phrases: "update work", "ship it", "mark as done",
  "what are we shipping", "add to next up", "I'm blocked on",
  "rotate work", "what's the status", "작업 완료", "블로커".
---

# WORK.md Management

WORK.md is a weekly task file in the repo root. It replaces ticket systems
with a single markdown file. Git handles history. The file handles everything else.

## Format

```
# WORK.md — Week of [Month Day]

## Shipping This Week
- [ ] Task description (owner)

## Blocked
- Blocker description (owner)
  ^ context: what was tried, who was asked, when

## Next Up
- Future task description

## Shipped
- [Month]: N features (brief list)
```

## Rules

1. Read WORK.md before any update.
2. **Week rotation**: Compare today's date against the header. If the Monday
   of the current ISO week differs from the header's week, rotate first.
   See "Rotation" below.
3. One task = one line. Detail belongs in a spec file, not here.
4. Owners in parentheses at the end: `(maria)`. Solo projects may omit.
5. Blockers require context on the next line with `^` prefix — what was
   tried, who was contacted, when. No context = not a valid blocker.
6. "Shipped" tracks monthly count with a brief parenthetical list.
7. Cap "Shipping This Week" at 3-4 items. More means planning, not shipping.

## Actions

### Ship

Remove the completed item from "Shipping This Week" and append it to "Shipped",
incrementing the feature count.

Before:
```
## Shipping This Week
- [ ] Auth: rate limiting (maria)
- [ ] Search: fuzzy matching (dev)

## Shipped
- March: 1 feature (API v2 endpoints)
```

After:
```
## Shipping This Week
- [ ] Search: fuzzy matching (dev)

## Shipped
- March: 2 features (API v2 endpoints, auth rate limiting)
```

### Add Task

Add to "Shipping This Week" for this week, "Next Up" otherwise.

### Block / Unblock

Move a task from "Shipping This Week" to "Blocked" with `^` context line.
To unblock, move it back to "Shipping This Week".

### Status

Read WORK.md and summarize in 3-4 sentences: what's shipping, what's blocked,
what's next. This replaces standup status theater.

## Rotation

Every time WORK.md is touched, check if the week has changed. If it has:

1. **Archive** the previous week to `docs/archive/work-YYYY-wNN.md`
   (use the previous week's ISO number). See `references/rotation.md`
   for archive format and a worked example.

2. **Reset WORK.md**:
   - Update header to current week's Monday: `Week of [Month Day]`
   - Unfinished "Shipping This Week" items move to "Next Up"
   - "Blocked" and "Next Up" carry over as-is
   - "Shipped": same month keeps the running count; new month starts at 0

3. **Commit** both files:
   `git commit -m "rotate work: archive week NN, start week NN+1"`

## Bootstrap

If WORK.md does not exist, create it from the format above with today's
week date, empty sections, and `- [CurrentMonth]: 0 features` in Shipped.
