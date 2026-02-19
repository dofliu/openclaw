---
name: skill-creator
description: Create a new skill from a repeated manual workflow. Invoke when the
  same operation has been done manually 3+ times ("三次規則"). Interviews the agent
  about the pattern, drafts SKILL.md, places it in .agents/skills/, and records
  the skill creation in GROWTH_LOG.md.
license: MIT
metadata:
  author: openclaw
  version: "1.0"
---

# Skill Creator

Turn a repeated manual workflow into a reusable skill. Follow the three-times rule:
when you've done the same thing manually 3+ times, stop and build a skill.

## When to Invoke

**Trigger conditions (any one is sufficient):**
- You've performed the same multi-step operation ≥ 3 times this month
- The human asked you to "remember how to do X" more than once
- You found yourself rewriting the same instructions in memory/
- The human said "we always do it this way" about a workflow

**How it gets triggered:**
- Agent self-identifies the pattern and proposes creating a skill
- Human says "make a skill for this" / "把這個做成技能"
- `growth-reflect` references a repetitive pattern in its output

## Inputs

Ask if not already clear from context:

1. **What is the workflow?** Describe in 1-2 sentences what gets done.
2. **What triggers it?** When does someone invoke this?
3. **What are the inputs?** What does the skill need to know to start?
4. **What does success look like?** What's the expected output/outcome?
5. **Are there safety concerns?** Destructive actions, external side effects?

If the workflow was just performed in the current session, you can answer most of
these from context — don't ask unnecessarily.

## Execution

### Step 1 — Name the Skill

Choose a name following existing conventions:
- Kebab-case, verb-noun or noun: `review-pr`, `growth-reflect`, `deploy-staging`
- Short, specific, unambiguous
- Check `.agents/skills/` — don't duplicate existing skills

### Step 2 — Draft SKILL.md

Use this structure:

```markdown
---
name: <skill-name>
description: <One sentence. When to use + what it does.>
license: MIT
metadata:
  author: <agent-name or "openclaw">
  version: "1.0"
  created: YYYY-MM-DD
  created-by: skill-creator (三次規則)
---

# <Skill Title>

## Overview
<2-3 sentences. What problem does this solve? What does it automate?>

## When to Use
<bullet list of trigger conditions>

## Inputs
<what the skill needs — ask for what's missing, infer what's obvious>

## Execution
<numbered steps; be specific enough that the skill runs without ambiguity>

## Safety
<anything that could go wrong; what to check before proceeding>

## Example
<optional — a concrete example invocation if helpful>
```

**Quality bar:** a well-written skill should run correctly the first time without
human correction. If you're unsure about a step, mark it `[VERIFY]` and note what
to check.

### Step 3 — Place the Skill

```bash
mkdir -p .agents/skills/<skill-name>
# Write SKILL.md to .agents/skills/<skill-name>/SKILL.md
```

If the skill requires helper scripts or config files, note them in SKILL.md under
a `## Files` section — but don't create them unless the human asks.

### Step 4 — Record in GROWTH_LOG.md

Append to GROWTH_LOG.md under 🌱 里程碑:

```markdown
### YYYY-MM-DD — Skill created: <skill-name>
- Pattern: [what repeated 3+ times]
- Skill: `.agents/skills/<skill-name>/SKILL.md`
- Estimated time saved per use: [optional]
```

### Step 5 — Confirm

Reply with:
```
✅ Skill created: .agents/skills/<skill-name>/SKILL.md

Trigger: [when to use it]
Invoke: 「執行 <skill-name>」or "run <skill-name>"

Logged to GROWTH_LOG.md.
```

## Self-Application

This skill was itself created by the three-times rule. When you use skill-creator
enough times that *skill-creator creation* becomes routine, consider whether the
skill-creator skill itself needs improvement — and update it.

## Notes

- Skills live in `.agents/skills/` in the **repo**, not the workspace. They're
  version-controlled and shared across agent instances.
- Workspace-specific instructions (SSH details, device names) belong in `TOOLS.md`,
  not in a skill.
- If a skill is only useful for one human's setup, prefix the name with the
  agent's name: `mochi-deploy-staging` vs `deploy-staging`.
- After creating 5+ skills, consider grouping related ones under a shared prefix.
