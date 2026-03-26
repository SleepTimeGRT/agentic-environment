# Rotation Reference

## Archive File Format

Create `docs/archive/work-YYYY-wNN.md` with:

```markdown
# Week NN (Month Day-Day, Year)

## Shipped
- YYYY-MM-DD: item 1
- YYYY-MM-DD: item 2

## Carried Over
- unfinished items that moved to next week

## Was Blocked
- blockers and their resolution status
```

Use the PREVIOUS week's ISO number for the filename.
Create the `docs/archive/` directory if it does not exist.

## Worked Example

Current date: Monday March 31, 2026.
WORK.md header says "Week of March 24".

### Step 1: Archive

Create `docs/archive/work-2026-w13.md`:

```markdown
# Week 13 (March 24-28, 2026)

## Shipped
- 2026-03-26: initial commit
- 2026-03-26: CEO review
- 2026-03-27: P2 completion

## Carried Over
- bootstrap.sh vanilla validation

## Was Blocked
(none)
```

### Step 2: Reset WORK.md

```markdown
# WORK.md — Week of March 31

## Shipping This Week

## Blocked

## Next Up
- bootstrap.sh vanilla validation (carried from last week)
- yq batch optimization
- cask tap declaration

## Shipped
- March: 6 features (initial commit, CEO review, /simplify, GitHub push, ykdojo setup, P2)
```

The unfinished shipping item moved to "Next Up" because it did not ship in time.
The "Shipped" count carries over because the month (March) has not changed.

### Step 3: Commit

```bash
git add docs/archive/work-2026-w13.md WORK.md
git commit -m "rotate work: archive week 13, start week 14"
```
