---
description: Run a structured planning interview for a B2B SaaS landing page and produce a build brief
allowed-tools: Read, Write, Glob, Grep, Bash(npm:*), Bash(npx:*), Bash(git:*), AskUserQuestion
---

Conduct a structured planning interview for a B2B SaaS landing page. Ask one question at a time using AskUserQuestion. Lead with recommendations based on B2B landing page experience. After gathering all answers, produce a brief file that the build phase can execute against.

## Interview Phases

Work through these phases sequentially. Ask one question per AskUserQuestion call. Use the user's previous answers to inform follow-up questions.

### Phase 1: Product Context

Ask these questions one at a time:

1. **Product name** — "What is your product called?"
2. **One-line description** — "Describe your product in one sentence — what does it do and for whom?"
3. **Target audience** — Ask with options:
   - "Technical decision-makers (CTOs, engineering leads)"
   - "Business decision-makers (CEOs, VPs, product managers)"
   - "Individual practitioners (developers, data scientists, designers)"
   - Other
4. **Key differentiators** — "What are 2-3 things that make your product different from alternatives? These become your value propositions."

### Phase 2: Page Structure

Ask about which sections to include. Recommend the standard B2B structure and let the user customize.

5. **Page sections** — Use multiSelect. Recommend all as defaults for B2B:
   - "Hero with headline + CTA (Recommended)"
   - "Value propositions (3-4 cards)"
   - "How it works / Product walkthrough"
   - "Social proof / Testimonials"
   - "Pricing"
   - "FAQ"
   - "Final CTA section"

   If the product is early-stage (no customers yet), note that social proof can use team credentials or technical expertise instead of customer logos.

6. **Hero style** — Ask with options:
   - "Product screenshot/mockup as hero visual (Recommended for B2B SaaS)"
   - "Abstract illustration or animation"
   - "Text-only with bold typography"
   - "Video or interactive demo embed"

### Phase 3: Design Direction

7. **Theme** — Ask with options:
   - "Dark theme (Recommended — stands out, premium feel)"
   - "Light theme (clean, approachable)"
   - "Mixed (dark hero, light content sections)"

8. **Visual tone** — Ask with options:
   - "Minimal and precise (think Linear, Vercel)"
   - "Bold and editorial (think Stripe, Lemon Squeezy)"
   - "Clean corporate (think Datadog, PlanetScale)"
   - "Brutalist / experimental (think Nothing, Teenage Engineering)"

9. **Reference sites** — "Are there any specific websites whose design you admire? Paste URLs or describe what you like about them. Type 'skip' if none."

### Phase 4: Technical Setup

10. **Framework** — Ask with options:
    - "Astro (Recommended — static-first, fast, great DX)"
    - "11ty / Eleventy (simpler, markdown-focused)"
    - "Plain HTML + Tailwind (no build step)"
    - Other

11. **Hosting** — Ask with options:
    - "Cloudflare Pages (Recommended — free, fast, simple)"
    - "Vercel"
    - "Netlify"
    - "GitHub Pages"
    - Other

### Phase 5: Additional Context

12. **Existing assets** — "Do you have any existing assets to incorporate? (logo, brand colors, fonts, product screenshots, copy drafts). List what you have or type 'none'."

13. **Anything else** — "Any other requirements, constraints, or preferences I should know about? (e.g., accessibility requirements, specific integrations, launch deadline). Type 'none' if nothing else."

## Producing the Brief

After gathering all answers, produce a structured brief file.

1. Determine the brief file path: write it to `landing-page-brief.md` in the current working directory
2. Write the brief using this structure:

```markdown
# Landing Page Brief: [Product Name]

## Product
- **Name:** [name]
- **Description:** [one-liner]
- **Target audience:** [audience]
- **Differentiators:**
  - [diff 1]
  - [diff 2]
  - [diff 3]

## Page Structure
[List selected sections in order with brief notes on content for each]

## Design Direction
- **Theme:** [dark/light/mixed]
- **Tone:** [selected tone with reference description]
- **Hero style:** [selected hero approach]
- **Reference sites:** [URLs or "none"]

## Technical Stack
- **Framework:** [selected]
- **CSS:** Tailwind CSS
- **Hosting:** [selected]

## Assets & Constraints
[Existing assets and additional requirements]

## Variant Directions
Based on the design direction above, generate these 3 variants:
1. **[variant-1-name]** — [brief aesthetic description]
2. **[variant-2-name]** — [brief aesthetic description]
3. **[variant-3-name]** — [brief aesthetic description]
```

3. Generate the 3 variant direction names and descriptions based on the user's design preferences. Each should be a distinct interpretation of their stated direction.

4. After writing the brief, tell the user:
   - The brief file location
   - A summary of what was captured
   - That the next step is to run the Foundation phase (scaffold project, write copy, build base layout)
   - Remind them to review and edit the brief before proceeding if anything needs adjustment
