# Skill Authoring Discipline

**Provenance.** Distilled from superpowers v6.1.1's `skills/writing-skills/SKILL.md` — the
TDD-for-documentation methodology. Superpowers is the source; this guide restates only the
four disciplines metaswarm's own gates and skills depend on, each cited back to a
`file:line`. Read the source directly for the rest (persuasion principles, flowchart
conventions, discovery workflow) — this file does not repeat it.

## (a) TDD for documentation

Prose is production code for agent behavior, and it follows the same RED-GREEN-REFACTOR
cycle (writing-skills/SKILL.md:30-45): **RED** — run the scenario without the change and
record the literal failure, choices and rationalizations, verbatim
(writing-skills/SKILL.md:556-563). **GREEN** — write only the prose that addresses that
specific failure, then re-run and confirm compliance. **REFACTOR** — a new rationalization
surfaces, close it, re-test. "If you didn't watch an agent fail without the skill, you don't
know if the skill teaches the right thing" (writing-skills/SKILL.md:16).

One real worked example carries both RED and GREEN (writing-skills/SKILL.md:150-158):

- **RED.** A skill's description read "code review between tasks." An agent dispatching
  against it ran ONE review, even though the skill's own flowchart specified two
  (spec-compliance, then code quality). The description became the shortcut; the body
  became documentation the agent never opened.
- **GREEN.** The description was rewritten to state only the trigger — "Use when executing
  implementation plans with independent tasks" — with no workflow summary. The same agent
  then read the flowchart and ran both reviews.

Nothing else changed between the two runs. The entire failure and fix live in the
description field — which is why description-writing gets its own rule, (c) below.

## (b) Match the form to the failure

Two failure shapes need two different prose shapes; using the wrong one measurably makes
things worse (writing-skills/SKILL.md:459-474):

| Baseline failure | Right form | Wrong form |
|---|---|---|
| Agent knows the rule, skips it under pressure (discipline problem) | Prohibition + rationalization table + red-flags list | Soft guidance ("prefer...", "consider...") |
| Agent complies, but the output has the wrong shape (shaping problem) | Positive recipe — state what the output IS, its parts, in order | Prohibition list ("don't restate", "never narrate") |

Discipline problems get the apparatus metaswarm already runs on: a flat prohibition, an
"Excuse → Reality" rationalization table built from observed excuses, and a red-flags
self-check list (see the Test-Result Acceptance Invariant's countermeasures in
`skills/orchestrated-execution/SKILL.md` for a live instance).

Shaping problems get a recipe, never a ban. In superpowers' own head-to-head wording tests
on dispatch-prompt guidance, the prohibition-worded arm produced *more* of the unwanted
content than the recipe arm — and trended worse than giving no guidance at all
(writing-skills/SKILL.md:470). A prohibition invites negotiation ("this is different
because..."); a recipe leaves nothing to negotiate against.

Two corollaries bind either form (writing-skills/SKILL.md:472-474): no nuance clauses — "don't
X unless it matters" reopens the negotiation a flat prohibition just closed — and exemption
clauses don't scope — "this limit doesn't apply to code blocks" still suppresses code blocks
in practice; restructure the rule so it can't reach the exempt part instead.

Classify the failure before drafting. A prohibition table aimed at a shaping problem, or
soft guidance aimed at a discipline problem, is the most common way a prose change fails its
own pressure test.

## (c) `description` is trigger conditions ONLY

The description field decides whether an agent reads the skill body at all. If it already
answers "what does this do," the agent may act on that summary and skip the file — the exact
regression in (a) above. The rule (writing-skills/SKILL.md:99-102, 150-158):

- State ONLY when to use it: symptoms, situations, observable triggers. Start with "Use
  when...", third person, short.
- Never summarize the workflow, the steps, or the stage count.

```
BAD:  Use when executing implementation plans — dispatches subagent per task with code
      review between tasks.
GOOD: Use when executing implementation plans with independent tasks.
```

This is why `evals/trigger-evals.md` tests descriptions in isolation — positive, negative,
near-miss — rather than the skill body: the description is the only part guaranteed to be
in context before the agent decides whether to read further.

## (d) Pressure-test every gate/skill prose change

A change to a skill's, agent's, or gate's prose needs evidence it does what it claims, not
just review. Which evidence depends on what changed (see `docs/testing.md` for the full
tests-vs-evals split):

- **Routing change** — does the right skill fire, and only then? Add a trigger-eval entry:
  positive / negative / near-miss, in the shape `evals/trigger-evals.md` already uses.
- **Discipline or behavior change** — does the rule survive pressure? Run a RED/GREEN
  walkthrough: the baseline failure under the old prose, then the same scenario against the
  new prose. `skills/orchestrated-execution/SKILL.md:333-355` (the Test-Result Acceptance
  Invariant, commit `73cefe2`) is metaswarm's own instance — the old VALIDATE text was
  pressure-tested against a weakened-assertion scenario and a tampered-`vitest.config`
  scenario, both of which slipped through; the rewrite (baseline-restored re-run, red-green
  proof for new tests, surface-delta blocking) catches both. The commit message is the
  transcript; there is no separate walkthrough file. Reproduce that shape — state the
  scenario, show what the old prose let through, show what the new prose catches — for the
  next discipline-prose change.

Skip the pressure test only when the change has no behavioral or routing surface (typos,
link fixes, formatting). Anything that could change what an agent does or when it fires
needs one.

## (e) This guide follows its own rules

No hype words. Every mechanic cited to a real `file:line`. (a) and (c) share one worked
example instead of inventing two. If this guide is edited, the edit is a prose change under
rule (d): pressure-test it.
