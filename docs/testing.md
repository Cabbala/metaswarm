# Testing: tests/ vs evals/

metaswarm splits verification into two directories with different guarantees. The split is
adapted from superpowers v6.1.1's own `docs/testing.md`, which draws the same line for its
plugin.

## `tests/` — deterministic suites, CI-gated

No LLM in the loop. Every suite is bash (some drive node/python fixtures), asserts against
real files and command output, and either passes or fails deterministically. All 11 run in
`.github/workflows/ci.yml` on every push/PR to `main`/`dev`; a red suite blocks merge.

Run the full set locally with the command
`docs/plans/2026-07-10-superpowers-v6-gpt56-refinement-design.md` §5 pins as canonical:

```bash
for t in tests/*/test-*.sh; do bash "$t" || exit 1; done && node lib/sync-resources.js --check
```

| Suite | Covers |
|---|---|
| `tests/beads/test-bd-vocabulary.sh` | Tracked text files use bd 1.0.5-compatible command forms; fails on incompatible syntax. |
| `tests/bin/test-pr-scripts.sh` | PR helper scripts, via dry-run and local fixtures only — never calls `gh` or the network. |
| `tests/cli/test-installer.sh` | Cross-platform installer and platform detection. |
| `tests/codex/test-codex-manifest.sh` | Codex plugin manifest declares `"hooks": {}` explicitly, so Codex doesn't auto-discover the Claude Code SessionStart hook (regression guard, W3/D4). |
| `tests/codex/test-codex-skills.sh` | Codex CLI skill structure and install script. |
| `tests/external-tools/test-codex-adapter.sh` | Codex external-tools adapter, without invoking a real Codex CLI. |
| `tests/hooks/test-session-start.sh` | `hooks/session-start.sh` unit behavior. |
| `tests/lib/test-sync-resources.sh` | `lib/sync-resources.js` check/sync modes keep co-located resources in sync. |
| `tests/superpowers/test-upstream-refs.sh` | Upstream paths and skill names metaswarm's tracked files reference still exist in the pinned superpowers version (v6.1.1, `d884ae0`). |
| `tests/templates/test-beads-cleanup.sh` | Redundant beads files stay removed; remaining references match the standalone beads plugin. |
| `tests/templates/test-ci-template.sh` | CI template security properties. |

Add a suite here when a change has a deterministic, non-LLM-observable pass/fail: a file
exists or doesn't, a script's exit code, a manifest field's value, a grep pattern's hit
count. Name it `tests/<dir>/test-*.sh` so the local loop above picks it up automatically —
but `ci.yml` wires each suite by name, so a new suite also needs its own step added there.

## `evals/` — behavioral pressure-tests, not CI-gated

Requires a real model to execute a scenario and a judge (human or model) to grade the
transcript. Two kinds live here:

- **Trigger/routing evals** — does a skill's description alone tell a reader or model when
  to fire, without over- or under-triggering? `evals/trigger-evals.md` runs this as a table:
  positive case (should fire), negative case (should not), near-miss case (superficially
  similar, should still not fire).
- **Discipline evals** — does a rule survive an agent under pressure (time, sunk cost, "this
  is different because...")? These follow the RED/GREEN shape from
  `guides/skill-authoring.md`: run the scenario against the old prose (RED, document the
  failure verbatim), then against the new prose (GREEN, confirm it's caught).
  `skills/orchestrated-execution/SKILL.md`'s Test-Result Acceptance Invariant (commit
  `73cefe2`) is metaswarm's own worked instance.

Evals are slow — a full model session per scenario — and non-deterministic: a model executes
the scenario, and grading needs judgment. Run them manually when authoring or editing a
skill's, gate's, or agent's prose, and periodically as a regression sweep. Their results are
documented as evidence, in the eval file itself or in the commit/PR that changed the prose,
not enforced as a merge gate.

## When to add which

| Change | Add |
|---|---|
| New bash/node/CLI behavior with a deterministic assertion | A `tests/<dir>/test-*.sh` suite, wired into `ci.yml`. |
| New or edited skill/gate description (routing) | A row in `evals/trigger-evals.md`. |
| New or edited discipline rule in a skill/gate/agent's prose | A RED/GREEN walkthrough per `guides/skill-authoring.md`, attached to the change's commit or PR. |
| Both a code change and a prose change | Both — they test different things, and neither substitutes for the other. |
