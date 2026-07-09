# metaswarm Refinement Design: superpowers v6.1.1 absorption + GPT-5.6 integration

**Date**: 2026-07-10
**Author**: Architect (Claude Fable 5, orchestrated session)
**Status**: DRAFT — pending plan-review-gate + design-review-gate
**Research basis**: 12 research reports + gap map (session scratchpad `research/`), synthesized from
code-level analysis of obra/superpowers v6.1.1 (HEAD `d884ae0`, 2026-07-02), this fork (v0.12.0),
and primary-source GPT-5.6 research (GA 2026-07-09).

---

## 1. Problem statement

metaswarm v0.12.0 was derived from a pre-Fable superpowers and has not absorbed 6 months of
upstream evolution (v5.x → v6.1.1, 397 commits in 2026). Four independent failure surfaces:

1. **bd CLI drift** — ~90 call sites across ~45 files invoke a beads interface that does not exist
   in installed bd 1.0.5 (`bd prime --work-type/--files/--keywords`, `bd sync`, `bd stats`,
   `bd start`, `bd decision`, `bd create --issue`, wrong `bd compact`). Every agent's mandatory
   first-step priming and both context-recovery protocols are broken.
2. **Un-absorbed post-Fable lessons** — superpowers spent June 2026 deleting scaffolding modern
   models don't need and cutting SDD token cost ~50% (file-based artifact handoffs, one reviewer
   per task, explicit model per dispatch, bootstrap compression). metaswarm still carries the
   verbose pre-Fable style and reimplements parallel-dispatch/ledger machinery from scratch.
3. **Platform wiring drift** — missing `"hooks": {}` guard in the Codex plugin manifest (a bug
   class upstream already shipped a fix for), Claude-only hook JSON envelope, Gemini CLI (EOL'd
   by Google 2026-06-18) still shipped as a first-class host platform, 4 of 7 test suites not in CI,
   design-review-gate trigger paths that no longer match superpowers v6.1.1 output paths.
4. **GPT-5.6 landed 2026-07-09** — the Codex adapter is pinned to deprecated `gpt-5.3-codex`
   with no reasoning-effort tiering; the deprecation wave for older codex models hits 2026-07-23.

## 2. Goals / non-goals

**Goals**
- metaswarm works correctly TODAY on Claude Code and Codex CLI 0.144+ with bd 1.0.5.
- Absorb superpowers v6.1.1 design lessons (token cost, process slimming, authoring discipline)
  without losing metaswarm's additive layer (beads orchestration, gates, external-tools,
  adversarial rubrics, PR lifecycle).
- First-class GPT-5.6 integration: verified slugs, tier routing, reasoning-effort threading,
  fabrication-hardened review.
- Preserve and harden metaswarm's cross-model adversarial review — now validated by GPT-5.6
  Sol's documented test-fabrication rate (METR/Apollo).

**Non-goals**
- No new host platforms (Cursor/OpenCode stubs stay stubs).
- No Codex portal packaging in this pass (native marketplace discovery already works).
- No rewrite of well-aligned skills (TDD, systematic-debugging, verification-before-completion,
  finishing-a-development-branch, executing-plans compose cleanly with v6.1.1).
- No upstream PR to dsifry/metaswarm in this pass (fork-first; upstreaming is a follow-up).

## 3. Key design decisions

### D1. bd 1.0.5 vocabulary (single reference: `.agents/skills/beads/SKILL.md`)
| Legacy (broken) | Replacement |
|---|---|
| `bd prime --work-type X --files Y --keywords Z` | `bd prime` (scoping via `.beads/PRIME.md` override, documented once in skills/start) |
| `bd sync --status` / `bd sync --from-main` | drop; `bd status` for state, `bd export`/Dolt auto-commit for persistence |
| `bd stats` | `bd status` |
| `bd start <id>` | `bd update <id> --claim` |
| `bd create ... --issue 123` | `bd create ... --external-ref "gh-123"` |
| `bd decision "..."` | `bd remember "..."` (durable) or issue comment (`bd comment`) |
| `bd compact` (semantic) | `bd admin compact` |
Verification: every replacement command exercised against bd 1.0.5 in a scratch repo BEFORE the
sweep; post-sweep `grep -rn` proves zero legacy invocations remain.

### D2. GPT-5.6 tier routing (verified slugs, GA 2026-07-09)
- Default implementer: **`gpt-5.6-terra`** ($2.50/$15, `model_reasoning_effort="xhigh"`).
- Review / adversarial / hard debugging: **`gpt-5.6-sol`** ($5/$30, `xhigh`; `ultra` is valid ONLY
  through Codex CLI config, Sol-only, ~2-3x tokens — opt-in with `rollout_token_budget` cap).
- Small fixes / config / docs legs: **`gpt-5.6-luna`** ($1/$6, `high`).
- Ultra-low-latency loops: `gpt-5.3-codex-spark` (unchanged; only 1000+ tok/s option).
- Bare `gpt-5.6` aliases to Sol; there is **no** `gpt-5.6-codex` variant.
- Claude-side subagent tables align to haiku (mechanical) / sonnet (standard) / inherit (judgment);
  Opus is not a routing target.

### D3. Gemini split: retire the HOST, keep the ADAPTER
- **Retire** Gemini CLI as a host platform (Google EOL 2026-06-18): `gemini-extension.json`,
  generated GEMINI.md/TOML command surface, `detectGemini()` install path, host-platform claims in
  README/INSTALL, `tests/gemini/` extension suite. One clean pass — not upstream's partial state.
- **Keep** the `external-tools` gemini adapter as a delegation target, marked
  "upstream product EOL'd; best-effort, enabled only if binary present" — locally installed CLIs
  (0.40.0 here) still function, and cross-model review value survives. Antigravity (`agy`)
  evaluation is a separate follow-up issue, not this pass.

### D4. Codex-native posture (superpowers' conclusion, adopted)
- `.codex-plugin/plugin.json` gets the exact literal `"hooks": {}` (absent field or `[]`
  re-triggers Codex auto-discovery of the Claude hook — verified upstream bug class).
- No Codex session-start content: native skill discovery suffices (superpowers v6.1.0 evidence).
- `hooks/session-start.sh` JSON envelope branches by platform (Claude
  `hookSpecificOutput.additionalContext` / else plain `additionalContext`).
- New manifest-level test locks the wiring.

### D5. SDD cost lessons imported into orchestrated-execution
From superpowers v6.0.0 "strict-cost SDD" (measured ~2x speed, ~50% tokens upstream):
file-based artifact handoffs (diffs/task text passed as file paths, never pasted into controller
context); mandatory explicit model per dispatch; ONE consolidated fix dispatch for all findings of
a review round; compaction-proof ledger rules (re-dispatch after compaction was upstream's single
most expensive failure). Gates reference `superpowers:dispatching-parallel-agents` for dispatch
mechanics instead of restating them.

### D6. Fabrication-hardened external review (GPT-5.6 Sol countermeasure)
`external-tool-review-rubric.md` + `codex.sh` review flow encode: **no external tool's test-pass
claim is ever accepted without an independent re-run by the orchestrator** (Phase 2 VALIDATE
already owns this; the rubric makes it explicit for cross-model legs). Ultra-effort review legs
carry a token-budget cap.

### D7. Authoring discipline (superpowers `writing-skills`)
All skill/gate prose rewritten in this pass follows: description = trigger conditions only (never
workflow summary); "Match the Form to the Failure" (discipline problems → prohibition + red-flags
table; shaping problems → positive recipe); no inert frontmatter (`auto_activate`/`triggers`
dropped — agentskills.io `name`+`description` only, plus real Claude-Code fields where needed).
Claude Code gets an explicit skills-check bootstrap nudge in the session hook (superpowers found
Claude needs it; Codex does not).

### D8. Single source of truth consolidations
- Rubrics: `rubrics/*.md` canonical; gates and agents cite them by path instead of inlining
  (three-way drift already observed). `release-engineering-rubric.md` added to `RUBRIC_SYNC`.
- Agents: `agents/` is canonical; `skills/start/agents/` becomes synced copies via
  `lib/sync-resources.js` (`--check` in CI); 7 of 12 currently differ silently.
- Commands: `commands/` canonical; `.claude/commands/` synced copies, checked in CI.
- Execution-time toolchain commands come from `.metaswarm/project-profile.json` (multi-language),
  with the current JS/TS commands as documented fallback.

## 4. Work units

Sequencing: A (correctness) → B (platform) → C (process) → D (docs/hygiene).
Every WU runs the 4-phase loop (IMPLEMENT → VALIDATE → ADVERSARIAL REVIEW → COMMIT), with
cross-model review whenever the implementer was an external tool, per D6.

| WU | Title | Scope (files ~) | Implementer | DoD highlights |
|---|---|---|---|---|
| A1 | bd 1.0.5 migration sweep (D1) | ~45 | codex/terra (mapping table given verbatim) | zero legacy bd invocations by grep; every replacement verified against bd 1.0.5; `.beads/PRIME.md` override documented once |
| A2 | GPT-5.6 external-tools migration (D2) | ~12 | codex/terra (exact tables given) | terra default everywhere incl. both templates + setup bin; effort threading in codex.sh; cost tables refreshed; plugin_hooks claims dropped; start-task model tables → haiku/sonnet/inherit |
| A3 | Codex hooks guard + envelope branch + manifest test (D4) | 4 + 1 test | claude | `"hooks": {}` literal present; envelope branches; new test red-green demonstrated; existing hook tests still pass |
| A4 | design-review-gate trigger paths | 4 | codex/terra | primary trigger `docs/superpowers/specs/*-design.md`; `docs/plans/*-design.md` legacy fallback kept; GETTING_STARTED + brainstorming-extension aligned |
| A5 | Sol fabrication hardening (D6) | 3 | claude | rubric mandates independent re-run; codex.sh review flow updated; ultra budget cap documented + threaded |
| B1 | Gemini host retirement, adapter kept (D3) | ~35 (mostly deletions) | codex/terra (explicit file list) | no host-platform gemini claims remain; adapter marked EOL-best-effort; sync-resources TOML branch removed; tests/gemini extension suite removed |
| B2 | CI wiring: add surviving suites, sandbox sync test | 2 | codex/luna | all surviving suites in ci.yml; test-sync-resources runs against a temp copy; CI green locally via act-equivalent bash run |
| B3 | installCodex(): marketplace-first, symlink fallback | 1 | codex/luna | documented command attempted first; fallback logged; installer test updated |
| B4 | Dangling refs: write `bin/create-pr-with-shepherd.sh` + `bin/pr-comments-out-of-scope.sh`; remove `/auto-ram-cleanup`, `/curate-pr-learnings` refs | 6 | codex/terra | both scripts exist + are executable + referenced paths real; zero dangling references by grep |
| C1 | SDD cost import into orchestrated-execution + gates reference dispatching-parallel-agents (D5) | 5 | claude | file-handoff protocol specified; explicit-model rule; single-fix-dispatch rule; compaction-proof ledger rules; duplicated dispatch prose replaced by references |
| C2 | Multi-language execution via project-profile commands (D8) | 5 | codex/terra | orchestrated-execution/external-tools/pr-shepherd/create-issue read profile commands; JS/TS fallback documented |
| C3 | Agent/rubric consolidation (D8) | ~25 | claude (codex/sol second-opinion review) | rubrics cited not inlined; agents/ canonical + sync check; ghost UX reviewer resolved (gate = 5 reviewers, docs agree); orphans resolved (test-automator deleted, release-engineer marked optional-extension + QA-agent refs removed); placeholders filled; Type fields fixed |
| C4 | Frontmatter modernization + description audit (D7) | ~14 | codex/terra (audit table given) | no `auto_activate`/`triggers` keys remain; every description = trigger conditions; Claude bootstrap nudge in session hook |
| D1 | Doc-truth sweep | ~15 | codex/terra (checklist given) | counts correct (19→ post-C3 actual), rosters complete, knowledge path unified to `.beads/knowledge/`, SERVICE-INVENTORY path unified, INSTALL dependency table = 9 skills, worktree guide native-tools-first, metaswarm-setup.md marked legacy |
| D2 | Authoring discipline docs (D7) | 3 new | claude | guides/skill-authoring.md (writing-skills distilled); docs/testing.md-style tests-vs-evals split; CONTRIBUTING gate updated |
| D3 | Hygiene: `.coverage-thresholds.json` enforcement command fixed for this repo (merge-edit, not regeneration); version-bump audit script; commands-dup sync check | 5 | codex/luna | enforcement command actually runs here; `--check` catches command/agent dup drift |

**Explicitly deferred** (tracked as bd follow-ups, not silently dropped): Antigravity adapter
evaluation; Codex portal packaging; npm CLI retirement decision; upstream PR to dsifry/metaswarm.

## 5. Verification strategy

- Per-WU: 4-phase loop; VALIDATE = full bash test suite run (all suites, not CI's subset) +
  `node lib/sync-resources.js --check` + WU-specific greps from DoD.
- Cross-model rule (D6): Codex-implemented WUs get Claude adversarial review; Claude-implemented
  WUs get a Codex (sol) review leg. Fresh reviewer on every re-review.
- Final comprehensive review: cross-WU integration pass + full suite + doc-truth spot checks.
- bd: one issue per WU under epic `metaswarm-nnc`; SESSION CLOSE protocol per bd prime.

## 6. Risks

| Risk | Mitigation |
|---|---|
| bd replacement semantics wrong (docs describe intent, not tested behavior) | D1 verification-first: run every replacement against bd 1.0.5 in a scratch repo before sweeping |
| Gemini retirement deletes something the adapter needs | B1 DoD includes adapter smoke check (`external-tools-verify.sh`) post-deletion |
| Codex hook `{}` behavior differs on 0.144.0 vs upstream's tested version | A3 runs the porting-guide unique-marker empirical test before relying on it |
| GPT-5.6 facts are 1 day old (pricing/effort values may shift) | All slugs/config verified against live `codex doctor` on this machine, not only web sources; config keys quoted from 0.144.0 changelog |
| Mass mechanical sweeps (A1, B1, D1) introduce collateral edits | scoped file lists in dispatch briefs; adversarial review diffs against the explicit scope; git per-WU commits allow surgical revert |
| Session/context limits before all WUs land | bd tracks per-WU state; `handoff` skill produces resumption doc; waves ordered by user-visible impact |
