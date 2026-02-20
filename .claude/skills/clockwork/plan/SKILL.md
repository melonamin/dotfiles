---
name: clockwork-plan
description: "Use when creating implementation plans for ralphex orchestration. Produces plans with Task headers, Validation Commands, and checkbox items suitable for automated agent execution."
---

# Clockwork Plan Creation

## Overview

Turn ideas into implementation plans through **collaborative dialogue**. Output follows the ralphex plan format for automated orchestration.

<CRITICAL>
## MANDATORY: Follow This Process

You MUST NOT write any plan file until you have completed these steps:

### Step 1: Understand (ask 2-3 questions minimum)
- Check out the current project state first (files, docs, recent commits)
- Ask questions ONE AT A TIME to refine the idea
- Prefer multiple choice questions when possible
- WAIT for user response before asking next question
- Focus on: purpose, constraints, success criteria

### Step 2: Propose Approaches
- Propose 2-3 different approaches with trade-offs
- Lead with your recommended option and explain why
- WAIT for user agreement before proceeding

### Step 3: Design Tasks
- Break the work into sequential tasks (one unit of work each)
- Present tasks one at a time, validating each before moving on
- Each task should be independently verifiable
- Ask: "Does this task breakdown make sense?"
- WAIT for user confirmation

### Step 4: Write the Plan
- ONLY after user validates tasks, write the plan file
- Write specific, concrete, actionable checkbox items for each task
- Include test items in each task where applicable

DO NOT skip steps. DO NOT dump a complete plan without the conversation.
</CRITICAL>

## Plan Format

```markdown
# Plan: [Meaningful Title]

[Brief description of the feature and overall goal - the overview section]

## Validation Commands

- `go test ./...`
- `golangci-lint run`

### Task 1: [First Task Title]

[2-4 sentences of context: what this task accomplishes, key components involved, what becomes possible after this task completes]

- [ ] Implement X
- [ ] Add tests for Y

### Task 2: [Second Task Title]

[Context for task 2...]

- [ ] Implement Z
- [ ] Update documentation
```

**Format rules:**
- Plan title uses `# Plan: [Name]` format (H1)
- Validation Commands section is required (`## Validation Commands`) with test/lint commands as a list
- Tasks use `### Task N:` headers (H3) — alternative: `### Iteration N:`
- Each task starts with context paragraph before checkbox items
- Checkbox items use `- [ ]` format (ralphex marks them `- [x]` when complete)
- Tasks are processed sequentially by the orchestrator

## After the Plan

**Documentation:**
- Write the plan to `docs/plans/YYYY-MM-DD-<topic>.md`
- Commit the plan to git

**Next steps:**
- Ask: "Ready to run this with ralphex?"
- If yes, remind them: `ralphex run --plan docs/plans/YYYY-MM-DD-<topic>.md`

## Key Principles

- **One question at a time** - Don't overwhelm
- **Multiple choice preferred** - Easier to answer
- **YAGNI ruthlessly** - Remove unnecessary work from plans
- **Verifiable tasks** - Each task must be mechanically verifiable via Validation Commands
- **Incremental validation** - Validate tasks, then write plan immediately
