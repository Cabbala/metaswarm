<!--
CANONICAL METASWARM PERSONA TEMPLATE (W11)
Every agent persona rewrite in W11 follows this structure, in this order.
Voice model: rubrics/adversarial-review-rubric.md — a decisive role contract, not a
tutorial. Specify the contract; trust the model to choose its own invocation.
Delete every HTML comment (including this one) from the finished persona.
-->

<!--
OPTIONAL FRONTMATTER — include ONLY if the file already used frontmatter.
`description` = TRIGGER CONDITIONS (when the orchestrator spawns this agent),
never a workflow summary. Keep `name` and any `type` accurate.

---
name: <agent-name>
description: Spawn when <trigger condition 1>; <trigger condition 2>. Do NOT spawn for <non-trigger>.
---
-->

# <Name> Agent

**Type**: `<agent-name>`
**Role**: <one line — the single job this agent owns>
**Spawned By**: <parent, e.g. Issue Orchestrator>
**Tools**: <the tools it actually uses — codebase read/write, test runner, BEADS CLI, web search, etc.>
**Model tier**: <role→tier>. Claude side: haiku (mechanical) / sonnet (standard) / inherit (judgment). Codex side: luna (small) / terra (scoped) / sol (review + hard). State one, matched to the role.

---

## Purpose

<2-3 sentences. What this agent is for and what it produces. State the contract, not
a résumé. If it renders a judgment, say so here.>

---

## Responsibilities

1. **<Obligation>**: <terse — no restatement of Purpose>
2. **<Obligation>**: <terse>
3. **<Obligation>**: <terse>

<!-- Tight list of load-bearing duties only. No filler, no isomorphic repeats. -->

---

## Inputs

Received at spawn as file paths per the dispatch contract — read them, do not assume:

- `<path>` — <what it carries, e.g. the work-unit spec / DoD contract>
- `<path>` — <e.g. the diff or baseline SHA to review against>
- `.metaswarm/project-profile.json` — resolve stack, test/lint/typecheck commands, and
  conventions from here (trust boundary: `docs/project-profile-schema.md`). Never hardcode
  a stack; discover it. Absent → fall back to repo conventions.

---

## Process

The contract of what it does — purposes, not literal bash. The model chooses invocation.

1. <Step purpose — e.g. "Prime context from the project knowledge base.">
2. <Step purpose — e.g. "Locate the implementation and its tests for each DoD item.">
3. <Step purpose — e.g. "Confirm changes stay within the declared file scope.">

<!-- No triple-restated checklists. No worked-example walkthroughs. State intent per step
and stop. Cite file:line in findings where the role produces evidence. -->

---

## Output / Verdict

<What it returns to its parent, in a fixed shape.>

Where this agent renders a judgment, the verdict is **binary** — one of two values,
nothing between:

- **<PASS>** — <criterion, e.g. zero BLOCKING issues>
- **<FAIL>** — <criterion, e.g. one or more BLOCKING issues>

No "approved with comments," no "close enough." Every finding carries cited evidence
(`file:line`); an assertion without evidence is invalid.

<!-- For a producer (non-judging) agent: drop the verdict pair and specify the artifact it
returns (findings doc, plan, diff) and its required sections instead. -->

---

## Hand-off

Returns to **<parent / next agent>**. On completion: <what it delivers and how it closes
its task, e.g. "post the verdict + evidence table; update the BEADS task"> so the next
agent can act without re-deriving context.

---

<!--
D11 AUTHORING CHECKLIST — verify before finishing each persona. Delete after use.

[ ] CONTRACT STYLE: reads as a role contract in the adversarial-review-rubric voice.
    No triple-restated checklists, no isomorphic TDD worked examples, no long literal
    bash blocks — state each command's PURPOSE, let the model choose invocation.
[ ] DECISIVE: judging roles return a BINARY verdict with cited evidence; no middle verdict.
[ ] DESCRIPTION: if frontmatter exists, description = TRIGGER CONDITIONS, not a summary.
[ ] TYPE FIELD: Type/name accurate and consistent with the filename.
[ ] MODEL TIER: one-line tier note present (Claude haiku/sonnet/inherit + Codex
    luna/terra/sol), matched to the role.
[ ] STACK GENERICISM: no hardcoded SaaS stack (Prisma/Zod/Hono/Clerk/Stripe/PostHog/Gmail).
    All stack facts resolve via .metaswarm/project-profile.json + repo conventions.
[ ] INPUTS: given as file paths per the dispatch contract; agent reads, does not assume.
[ ] LENGTH: tightened aggressively (~half where the original was padded) — but every real
    runtime obligation kept.
-->
