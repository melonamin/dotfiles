---
description: "Create a phased implementation plan in Clockwork format through collaborative brainstorming."
---

# CRITICAL: You MUST follow this process EXACTLY

Read and follow the clockwork:plan skill at `/home/sasha/.claude/skills/clockwork/plan/SKILL.md`

## Non-Negotiable Requirements

1. **ASK QUESTIONS FIRST** - You MUST NOT write any plan until you have:
   - Asked at least 2-3 clarifying questions (one at a time)
   - Proposed approaches and gotten agreement
   - Validated task breakdown with the user

2. **CORRECT FORMAT** - Plans MUST have:
   - Title: `# Plan: [Name]`
   - Section: `## Validation Commands` with test/lint commands as list items
   - Tasks: `### Task N:` headers (H3, not H2)
   - Items: `- [ ]` checkboxes under each task

3. **CORRECT LOCATION** - Write to `docs/plans/YYYY-MM-DD-<topic>.md`

## What NOT to do

- Do NOT dump a complete plan without asking questions first
- Do NOT use `## Phase N:` headers - use `### Task N:`
- Do NOT add executive summaries, appendices, tables, or extra sections
- Do NOT write to PLAN.md or any other location

START by exploring the codebase and asking your FIRST question.
