---
name: landing-page
description: Build B2B SaaS landing pages using a structured workflow — planning, parallel design variants, iteration, and polish. Triggers when user asks to build, create, or design a landing page.
---

Guide the user through building a B2B SaaS landing page using a proven four-phase workflow extracted from production landing page builds. Emphasize constraint-first design, parallel variants, and screenshot-driven iteration.

## Workflow Overview

Follow four phases in order. Each phase ends with a git commit checkpoint.

### Phase 1: Foundation

Gather requirements and set up the project. Run `/landing-page:plan` to conduct a structured planning interview that produces a brief file.

1. Run the plan command to interview the user and produce a brief
2. Scaffold the project (Astro + Tailwind recommended — see `references/tech-stack-setup.md`)
3. Write all copy into a centralized file (`lib/copy.ts` or `lib/copy.json`)
4. Build the base layout with semantic HTML sections matching the brief
5. Commit: "feat: scaffold landing page with base layout and copy"

### Phase 2: Parallel Design Variants

Generate 2-3 distinct visual directions simultaneously. Spawn the `design-variant` agent for each variant.

1. Define 2-3 aesthetic directions (e.g., "minimal dark", "bold editorial", "clean corporate")
2. Spawn one `design-variant` agent per direction — all run in parallel
3. Each variant lives in its own directory: `designs/[variant-name]/`
4. Each variant must build and preview independently
5. Commit all variants: "feat: add design variants [list names]"

Present all variants to the user for review. Use `agent-browser` to capture screenshots of each variant side by side.

### Phase 3: Iteration

Run a tight screenshot→fix→screenshot loop to converge on the final design.

1. User selects a primary variant (or requests a hybrid of elements from multiple variants)
2. Merge selected elements into the main implementation
3. Enter the iteration loop:
   - Take a screenshot with `agent-browser`
   - User provides numbered, specific feedback
   - Make targeted fixes (2-5 minute cycles)
   - Screenshot again to verify
4. Repeat until the user approves the overall design
5. Commit: "feat: finalize landing page design"

### Phase 4: Polish

Handle cross-browser, responsive, SEO, and performance concerns.

1. Test responsive breakpoints (mobile, tablet, desktop) via screenshots
2. Review copy against `references/b2b-copy-checklist.md`
3. Add SEO infrastructure (see `references/tech-stack-setup.md` for checklist)
4. Optimize images, fonts, and loading performance
5. Run Lighthouse audit via `agent-browser`
6. Final commit: "feat: polish landing page for production"

## Prompting Patterns

Apply these patterns throughout the workflow. They come from real session analysis.

### Constraint-First Design

When giving design direction, lead with constraints, not open-ended requests.

**Do:** "Dark background, sans-serif type, accent color #3B82F6, no gradients, no stock photos"
**Don't:** "Make it look modern and professional"

Constraints produce distinctive results. Open-ended prompts produce generic output.

### Screenshot Feedback Loop

Use `agent-browser` to capture the current state. Ask the user for feedback as a numbered list of specific items to fix.

**Do:** "1. Hero headline is too small — increase to 4xl. 2. CTA button needs more contrast. 3. Remove the decorative border on the pricing section."
**Don't:** "It doesn't feel right, make it better."

Each feedback item should be actionable in under 2 minutes.

### Numbered Selection

When presenting options (variants, color palettes, layouts), always number them. Ask the user to select by number, or specify a hybrid ("elements from 1 and 3").

### Batch Changes, Then Commit

Group related changes into a single commit rather than committing every small tweak. The phases provide natural commit boundaries. Within a phase, commit when a coherent chunk of work is complete.

## Parallel Variants Strategy

Generating multiple variants is the highest-leverage step. It prevents anchoring on a single direction and gives the user real choices.

### Variant Guidelines

- Each variant should make bold, distinctive aesthetic choices — invoke `frontend-design` skill principles
- Variants share the same copy and page structure (constraint-first)
- Variants differ in: color palette, typography, spacing, visual rhythm, decorative elements, component styling
- Each variant must be self-contained and buildable
- Name variants descriptively: "midnight-editorial", "warm-minimal", "corporate-sharp"

### After Variant Review

- User may pick one variant outright
- User may request a hybrid: "Layout from variant A, colors from variant B, typography from variant C"
- Merging a hybrid is manual — copy specific styles and components from each source variant

## Skills and Tools

### Required Skills

- **frontend-design** — Invoke this skill's principles when building any visual component. It prevents generic AI aesthetics and pushes for distinctive design choices.
- **agent-browser** — Use for all screenshot capture, responsive testing, and Lighthouse audits. Essential for the iteration loop.

### Sub-Agents

- **design-variant** — Spawns to build one complete design variant. Use the Task tool with `subagent_type` referencing this agent.

## Anti-Patterns

Avoid these patterns that lead to poor outcomes in landing page builds.

### Vague Feedback

Never accept or give vague feedback like "make it pop" or "it needs more energy." Always translate to specific, actionable items with concrete CSS properties or content changes.

### Skipping Commits

Every phase boundary is a commit checkpoint. Skipping commits means losing the ability to roll back when a design direction goes wrong. Commit early, commit at every phase.

### Single-Version Iteration

Do not iterate on a single design from the start. Always generate at least 2 variants first. The comparison reveals strengths and weaknesses that are invisible when looking at one version alone.

### Copy-Last Approach

Do not leave copy as placeholder "Lorem ipsum" text. Write real copy in Phase 1 before any design work. Design decisions depend on content length, hierarchy, and tone. Placeholder text produces layouts that break with real content.

### Over-Polishing Early

Do not spend time on hover animations, micro-interactions, or pixel-perfect spacing during Phase 2 (variants). Save polish for Phase 4 after the design direction is locked. Early polish on a variant that gets discarded is wasted effort.

### Ignoring Mobile

Do not build desktop-only and retrofit mobile later. Each variant should be responsive from the start. Use Tailwind's mobile-first breakpoints and verify with screenshots at each breakpoint.
