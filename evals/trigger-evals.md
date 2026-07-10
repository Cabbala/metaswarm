# Metaswarm Skill Trigger Evals

These behavioral trigger evals are distinct from the deterministic Bash tests. They pressure-test whether each skill description alone tells a reader or model when the skill should route, without relying on unsupported frontmatter conventions.

| Skill | Positive — should fire | Negative — should not fire | Near-miss — should not fire |
| --- | --- | --- | --- |
| `brainstorming-extension` | `superpowers:brainstorming` has completed and committed `docs/superpowers/specs/2026-07-10-auth-design.md`. | A developer is editing a committed design document after its Design Review Gate has already passed. | A user asks to brainstorm a feature but brainstorming has not yet run or produced a design document. |
| `plan-review-gate` | `writing-plans` has produced a three-work-unit implementation plan that will be shown to the user. | A user asks for a one-line answer to a syntax question; no implementation plan exists. | A design document has been committed but no implementation plan has yet been drafted. |
| `design-review-gate` | A design document is committed at `docs/superpowers/specs/2026-07-10-search-design.md` after `superpowers:brainstorming`. | An existing implementation plan is updated with a missed test case; no design document was created. | A file named `design.md` is opened for reference but was not created or committed as a feature design. |
| `visual-review` | A user asks to take a screenshot and review how a local web UI looks at desktop and mobile widths. | A user asks to refactor an API handler with no rendered output to inspect. | A user asks to review CSS source for a typo but does not need a screenshot or visual inspection. |
| `start` | A user says, “Start work on issue #123; it has the `agent-ready` label.” | A user asks what the current test command is, without starting work. | A user says “metaswarm” only as the name of a dependency in an explanatory question. |
| `external-tools` | A user requests that Codex implement a bounded change and a second model perform a cross-model adversarial review. | A user asks for a normal in-process code review with no external tool delegation. | A user asks whether Codex CLI exists but does not ask to delegate work to it. |
| `orchestrated-execution` | A written, multi-work-unit specification requires the IMPLEMENT → VALIDATE → ADVERSARIAL REVIEW → COMMIT loop. | A user requests a one-file typo correction with no written work-unit specification. | A user asks for a single adversarial review opinion, but not the full four-phase execution process. |
