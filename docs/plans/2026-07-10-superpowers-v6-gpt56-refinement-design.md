# metaswarm Refinement Design: superpowers v6.1.1 absorption + GPT-5.6 integration

**Date**: 2026-07-10 (v3 — v2 revised after gate round 2: wave mapping made explicit, D10
marketplace strategy resolved as self-marketplace, sync-resources edit-ownership enumerated,
grep DoDs made satisfiable with pinned patterns + exemptions)
**Author**: Architect (Claude Fable 5, orchestrated session)
**Status**: REVISED DRAFT — pending gate round 3
**Research basis**: 12 research reports + gap map (session scratchpad `research/`); superpowers v6.1.1
(HEAD `d884ae0`); GPT-5.6 GA (verified 2026-07-09, global rollout <48h old); live-verified toolchain
facts (bd 1.0.5, codex-cli 0.144.0) — every load-bearing external claim in this doc is either
live-probed on this machine or carries a primary-source citation in the research reports.
**Review basis**: plan-review-gate (3 adversarial) + design-review-gate (5 reviewers) round 1
(19 blocking findings, all addressed below) + fusion panel fable-gpt5.6 (provenance:
`~/.claude/fusion-runs/2026-07-10_052346_fable-gpt5.6.md`).

---

## 1. Problem statement

metaswarm v0.12.0 was derived from a pre-Fable superpowers and has not absorbed 6 months of
upstream evolution (v5.x → v6.1.1). Verified failure surfaces:

1. **bd CLI drift** — legacy invocations across ~45-66 files (`bd prime --work-type/--files/
   --keywords`, `bd sync`, `bd start`, `bd decision`, `bd create --issue`, mis-targeted
   `bd compact`) do not exist in installed bd 1.0.5. (`bd stats` is a VALID alias of `bd status`
   — earlier drafts wrongly listed it as broken; live-verified.)
2. **Un-absorbed post-Fable lessons** — superpowers' June-2026 strict-cost SDD, process slimming,
   and authoring discipline are missing; the 19 agent personas carry pre-Fable scaffolding,
   SaaS-stack lock-in (12 files), orphans, and a 699-line runtime-loaded orchestrator.
3. **Platform wiring drift** — missing `"hooks": {}` Codex manifest guard; Gemini CLI consumer
   access discontinued 2026-06-18 (enterprise/API-key access continues) while metaswarm ships it
   as a first-class host; 4 of 7 test suites not in CI; design-review-gate trigger paths that
   never fire on stock superpowers v6.1.1 output.
4. **External-tools adapter is partly non-functional** (live-verified this session):
   `DEFAULT_MODEL` is never passed to either `codex exec` invocation (model routing is
   decorative); `verify_scope` runs AFTER the worktree commit and inspects the then-empty
   `git diff HEAD` (scope enforcement is dead code on the success path); the yaml config is
   documentation, not a control plane; the implement leg uses deprecated `--full-auto` and
   inherits the user's global codex config including network egress.
5. **Fork identity** — `.agents/plugins/marketplace.json`, `.codex-plugin/plugin.json`, and the
   `lib/sync-resources.js:256` validator all hardcode `dsifry/metaswarm`; marketplace-first
   install would deliver upstream, not this fork.
6. **GPT-5.6 GA'd 2026-07-09** — templates seed the picker-deprecated `gpt-5.3-codex` with no
   tier routing or reasoning-effort threading. (NOT a hard deadline: `gpt-5.3-codex` is supported
   through Feb 2027; the 2026-07-23 wave kills only 5.0/5.1/5.2-codex, which metaswarm never
   pinned. The driver is quality/routing, not expiry.)

## 2. Goals / non-goals

**Goals** (unchanged from v1): correct-today on Claude Code + Codex CLI + bd 1.0.5; absorb
superpowers v6.1.1 lessons without losing metaswarm's additive layer; first-class, *functional*
GPT-5.6 tier routing; fabrication-hardened validation.

**Wave 0+1 alone deliver the "works correctly today" goal.** Wave membership is explicit in §4
(Wave 1 includes W3 hooks-guard and W4 gate-triggers — they are correctness fixes, not platform
work). *Known limitations if execution stops after Wave 1*: the Gemini consumer-host surface is
still present (a maintenance/labeling burden, not a correctness break for Claude/Codex users —
rationale in D3), personas remain verbose (quality, W11), and doc counts remain stale (W13).
The §5 end-to-end smoke scenario runs at the Wave 1 boundary as well as at final review.

**Non-goals**: no new host platforms (incl. no 3-way hook envelope — noted as future work if a
shell-hook host is added); no Codex portal packaging; no rewrite of well-aligned skills; no
upstream PR to dsifry/metaswarm (fork-first; git operations target Cabbala/metaswarm only).

## 3. Key design decisions

### D1. bd 1.0.5 semantic compatibility contract (tracked, not a blind sweep)
A tracked doc `docs/bd-compatibility.md` records the contract; migration happens by semantic
class, not one mechanical pass. Live-verified mappings:

| Legacy intent | Treatment |
|---|---|
| Prime session context (`bd prime --work-type/--files/--keywords`) | bare `bd prime`; scoping via tracked `.beads/PRIME.md` override, documented once |
| Inspect status (`bd stats`) | valid alias — leave as-is (optional normalization, non-blocking) |
| Claim work (`bd start <id>`) | `bd update <id> --claim` |
| Link GitHub issue (`--issue N`) | `--external-ref "gh-N"` |
| Durable decision (`bd decision`) | **`bd create --type decision`** (first-class issue type, live-verified) — keeps decisions in the exported issue graph; `bd remember`/`bd comment` only where memory/comment semantics are intended |
| Semantic summarization (`bd compact`) | `bd admin compact` ONLY at call sites intending semantic decay; `bd compact` (Dolt history squash) is itself valid and stays where history cleanup was meant |
| Persistence/sync (`bd sync --status/--from-main`) | drop the fiction; document an explicit Dolt policy (`bd dolt commit/push/pull` or auto-commit setting). `bd export` is NOT a backup substitute (its own help says so) |

The vocabulary was derived from live bd 1.0.5 probing (the locally-installed beads skill is
untracked and will not ship with the fork — the tracked contract doc is the reference).
A permanent CI grep-guard (pinned patterns for the 6 genuinely-broken forms) prevents re-drift.

### D2. GPT-5.6 tier routing — functional, availability-aware
GA confirmed 2026-07-09 (preview 06-26 → GA; global rollout <48h old at design time).
- **Functional wiring is part of the decision**: `parse_args` gains `--model`; both `codex exec`
  invocations receive `-c model="..."` and `-c model_reasoning_effort="..."`. Without this,
  model constants are reporting-only (live-verified defect).
- Tiers: implement=`gpt-5.6-terra`/`xhigh`; review/adversarial=`gpt-5.6-sol`/`xhigh`;
  small=`gpt-5.6-luna`/`high`; latency loops=`gpt-5.3-codex-spark` (unchanged). Bare `gpt-5.6`
  aliases to Sol; no `gpt-5.6-codex` variant exists.
- **Availability fallback**: health check verifies the configured model is usable; on
  model-unavailable the adapter reports a distinct error and the escalation chain proceeds —
  no silent substitution.
- Documented effort ladder is `minimal|low|medium|high|xhigh` (official config reference).
  **`ultra` is undocumented** (accepted by the local CLI; Sol-only semantics) → experimental
  opt-in ONLY, guarded by the *real* budget keys `features.rollout_budget.enabled` /
  `features.rollout_budget.limit_tokens` (config-reference-verified; empirical probe in W2 via
  clean `CODEX_HOME`; note `--strict-config` cannot be a standing guard — real configs carry
  unknown fields, live-verified). `rollout_token_budget` does not exist (probe-confirmed) and
  appears nowhere in this design's outputs. `XT_TIMEOUT` remains the hard backstop.
- Claude-side subagent tables: haiku (mechanical) / sonnet (standard) / inherit (judgment).
  *Fork-local policy note*: these tables encode this fork owner's routing policy; genericize
  before any future upstream PR.

### D3. Gemini split — consumer host retired, adapter kept as enterprise/API-key target
Wording corrected per primary source: Google discontinued CONSUMER access 2026-06-18;
Code Assist Standard/Enterprise and paid API-key access continue; the OSS repo still receives
security fixes. metaswarm retires the Gemini *host platform* surface in one clean pass and keeps
the delegation adapter labeled "enterprise/API-key compatibility target" with hardening:
`enabled: false` in seeded templates (explicit opt-in), removed from default `escalation_order`,
implement leg loses `--yolo` (sandboxed if 0.40.0 supports it, else the adapter is review-only),
health check records binary path+version as a post-transition supply-chain tripwire.

### D4. Codex-native posture + explicit Codex enforcement story
- `.codex-plugin/plugin.json` gets the exact literal `"hooks": {}`; manifest test asserts the
  parsed field is exactly `{}` (absent field and `[]` must FAIL the test); a unique-marker
  empirical test verifies Codex never executes the Claude hook (this also settles the open
  question whether current Codex supplies `CLAUDE_PLUGIN_ROOT` compat vars — unverifiable from
  docs at design time).
- No Codex session-start content (superpowers' conclusion). **The Codex-side replacement story
  is explicit**: static `AGENTS.md` (written by setup) must carry parity with what the Claude
  hook injects (skills-check nudge, bd prime First-Step, gate triggers); documented limitation:
  Codex has no post-compaction re-priming path — AGENTS.md persistence is the mitigation.
- The hook envelope stays Claude-only (envelope branching dropped — Codex hooks are suppressed
  and no other shell-hook host is in scope).

### D5. SDD lessons via a host-neutral dispatch contract (vendored)
The vendored contract lives at `guides/dispatch-contract.md` (joins GUIDE_SYNC so skill-local
copies exist), and gate citations of it ride the same D8 dispatch-time absolute-path expansion
and `--check` coverage as rubrics — otherwise the vendored doc would recreate the relative-path
failure class D8 fixes. metaswarm vendors a small dispatch contract in its own skills (parallel isolated dispatch, file-based
artifact handoffs — never paste diffs/task text into controller context, explicit model per
dispatch, single consolidated fix dispatch per review round, base/head-SHA review packages,
fresh-reviewer rule, compaction-proof ledger). superpowers is cited as the source, NOT referenced
as a runtime dependency — this preserves INSTALL.md's standalone claim and avoids by-name
upstream coupling (the failure class that silently disabled the design-review-gate). Claude and
Codex mappings of the contract are documented separately. Upstream's "~2x speed / ~50% tokens"
is treated as anecdote: this refinement itself is the pilot; W9 records dispatch counts, tokens,
and redispatch rates before/after.
**Preservation boundary**: Team Mode / Task Mode dual-mode sections are preserved (or explicitly
relocated to `guides/agent-coordination.md`) — never silently deleted.

### D6. One validation invariant at the boundary (covers fabrication AND tampering)
Stated once, in the VALIDATE phase definition + adversarial rubrics, applying to ALL implementers
(external or Claude): *no claimed test result is accepted until the orchestrator records the
command, exit status, and a fresh re-run from an orchestrator-controlled baseline.* Additions
that close the tampering hole (GPT-5.6 Sol has the highest measured benchmark-gaming rate, and
concealment is rising — METR/Apollo): (a) test-file modifications outside the declared scope are
review-BLOCKING; (b) new tests get red-green verification (fail when implementation reverted);
(c) pre-existing suites are re-run against base-SHA copies of test files, not the worktree's;
(d) external-tool output and diffs are untrusted DATA (delimited in review prompts; instructions
inside them are never followed); (e) review legs are always `--sandbox read-only`, pinned by test.

### D7. Authoring discipline + trigger evals
As v1 (writing-skills: description = trigger conditions only; Match the Form to the Failure;
pressure-test rewritten gate prose RED/GREEN), plus: trigger-behavior evals (positive / negative /
near-miss cases per skill) accompany any frontmatter/description change; the inert `triggers:`
lists are folded into descriptions BEFORE deletion; Claude Code session hook gains an
UNCONDITIONAL skills-check nudge (discriminating DoD: the exact hook content is specified, not
"a nudge exists").

### D8. Single sources of truth with a path-resolution rule
- `rubrics/` canonical; gates/agents cite rubrics with **dispatch-time absolute-path expansion**
  (the orchestrator resolves the skill-local synced copy to an absolute path before embedding in
  any subagent prompt — bare relative paths break under installed-plugin cwd; a test greps gate
  prompts for unresolved relative rubric paths). `release-engineering-rubric.md` joins RUBRIC_SYNC.
- `agents/` canonical; `skills/start/agents/` becomes synced copies (7 of 19 currently diverge —
  measured list in the dispatch brief; W1b sweep is mapping-only and must NOT reconcile divergent
  pairs — that is W11's decision).
- `commands/` canonical with an EXPLICIT per-file sync roster (trees already diverge: 2 differing
  files, 7 commands-only entries — roster built from a dispatch-time diff, not this doc);
  `.claude/commands/` synced; thin-shim claims in setup/migrate docs corrected. `bin/` ↔
  `skills/setup/bin/` is ALREADY dynamically synced via `buildDirSync` (sync-resources.js:75) —
  W11a decides keep-dynamic vs explicit roster; note the side effect that any new `bin/` script
  (W6's two) auto-syncs into `skills/setup/bin/`, so W6 expects those copies.
- Execution-time toolchain commands come from `.metaswarm/project-profile.json` under a versioned,
  validated schema (W10 defines: null semantics, command quoting, cwd, timeouts, trust boundary —
  profile content is repo-controlled data, never shell-injected).
- All sync surfaces ride `lib/sync-resources.js --check` in CI (one idiom, no bespoke checkers).
  **Edit-ownership of sync-resources.js**: the sync-MAP roster consolidation (agents/commands/bin)
  happens in W11; earlier WUs make enumerated line-scoped edits that are IN-scope for their
  reviews: W0.2 = validator URL derivation (line ~256); W1b = TOML_COMMAND_MAP prompt strings
  (line ~108) + regeneration of the generated TOMLs so `--check` stays green (those TOMLs are
  swept by W1b even though W7 later deletes them — accepted waste, keeps every wave green);
  W7 = TOML branch removal + gemini entries in validateManifests (lines ~283/293).

### D9. Delegation security envelope (new)
Implement legs: `--sandbox workspace-write` (replaces deprecated `--full-auto`), network egress
OFF by default (`-c sandbox_workspace_write.network_access=false` — key live-verified), explicit
approval policy for non-interactive runs. Review legs: `--sandbox read-only`, pinned by test.
Config inheritance (HOME preserved → user's global codex config, MCP servers, hooks apply) is
documented and surfaced by the health check (effective sandbox/approval/network/model posture).
Session logs: directory 0700 / files 0600, `raw_log` capped. `external-tools.yaml` carries
env-var NAMES only (asserted in template refresh). Prompt-injection posture: repo-derived text
(issue bodies, PR comments, PRIME.md) is data; wrap injected context in explicit delimiters.

### D10. Fork identity + marketplace strategy (new)
This fork distributes as **Cabbala/metaswarm**, and **the plugin repo serves as its own
marketplace** (the pattern is live-proven on this machine: `rohitg00/agentmemory` is registered
as both plugin and marketplace in `known_marketplaces.json`). The upstream install path runs
through a SEPARATE tiny repo `dsifry/metaswarm-marketplace` (verified: it contains only
`.claude-plugin/marketplace.json` whose `plugins[0].source.url` points at dsifry/metaswarm.git)
— the fork does NOT create a second repo:
- Add `.claude-plugin/marketplace.json` to this repo (marketplace name `metaswarm`, plugin source
  URL = the fork), alongside the existing `.claude-plugin/plugin.json`.
- Re-point `.agents/plugins/marketplace.json` (Codex self-marketplace, already in-repo) to the fork.
- Install commands become: Claude Code `claude plugin marketplace add Cabbala/metaswarm` +
  `claude plugin install metaswarm@metaswarm`; Codex `codex plugin marketplace add
  Cabbala/metaswarm` + `codex plugin add metaswarm` (two-step, W8).
- Canonical URL source: `package.json.repository.url` (updated to the fork). Normalization is
  specified: the validator compares with the `.git` suffix stripped and accepts string-or-object
  `repository` forms.
- Grep DoD carve-out: **upstream-attribution/lineage mentions of dsifry stay** (README
  acknowledgments, CHANGELOG, docs/plans history); only INSTALL-PATH literals migrate
  (install commands, manifests, platform-detect.js, cli/metaswarm.js, docs/index.html).
- Migration note for existing installs (this machine included): documented in README/INSTALL —
  add the fork marketplace, reinstall, optionally remove the old `metaswarm-marketplace` source.
Without this, marketplace-first install ships upstream's code (live-verified blocker).

### D11. Persona refinement — all 19 agents (user-mandated expansion)
Roster disposition: **core 11 kept + rewritten** (issue-orchestrator, researcher, architect, coder,
code-review, security-auditor, cto, product-manager, designer, security-design, pr-shepherd);
**test-automator deleted** (never spawned; duplicates coder's TDD duties); **release-engineer →
optional extension** (ghost "QA Agent" refs removed ×5); **peripheral 5 genericized + marked
optional** (metrics, sre, slack-coordinator, customer-service, swarm-coordinator — swarm-coordinator
gains the missing header template); **knowledge-curator kept** (live in the learning loop).
Rewrite rules: adversarial-rubric contract style (role contract, binary verdicts, evidence
requirements — no triple-restated checklists, no isomorphic worked examples, no literal bash
sequences); descriptions = trigger conditions; SaaS stack references (Prisma/Zod/Hono/Clerk/
Stripe/PostHog, 12 files) replaced by `.metaswarm/project-profile.json` references; superpowers'
read-only-reviewer contract + anti-sycophancy discipline imported verbatim into reviewer personas;
per-persona model-tier note (Claude haiku/sonnet/inherit; Codex terra/sol/luna); Type fields
fixed; security-auditor's 4 "Your-Project" placeholders resolved; ghost UX Reviewer resolved as
**gate = 5 reviewers, docs corrected** (UX flow checks fold into Designer's checklist);
cto-vs-plan-review-gate reconciled: **the adversarial plan-review-gate is the live mechanism**;
cto-agent's collaborative plan review is folded into it and `rubrics/plan-review-rubric.md` is
marked historical/absorbed; issue-orchestrator trimmed from 699 lines to a lean contract (it is
the ONLY agent file loaded verbatim at runtime — highest-leverage single rewrite).

## 4. Work units

IDs renamed (W-prefix) to kill the D-collision. **Explicit wave membership**: Wave 0 = W0.1, W0.2 ·
Wave 1 (correctness) = W1a, W1b, W2a, W2b, W3, W4, W5, W6 · Wave 2 (platform) = W7, W8 ·
Wave 3 (process/personas) = W9, W10, W11, W12 · Wave 4 (docs) = W13, W14, W15.
Within-wave dispatch is SERIAL (same-wave WUs touch overlapping surfaces). Every WU: 4-phase
loop; VALIDATE per §5. New test suites follow `tests/<dir>/test-*.sh` naming so §5's full-suite
glob picks them up automatically (pinned in the W3/W4/W6/W15 briefs); any test probing the local
toolchain (bd, codex, installed superpowers) must skip gracefully when the binary is absent, so
CI on GitHub runners stays green. Cross-model adversarial review is MANDATORY for
externally-implemented, security-sensitive, or architecturally broad WUs; optional elsewhere
(cost trim per fusion).

| WU | Title | Impl | DoD highlights (verifiable) |
|---|---|---|---|
| W0.1 | CI safety net: wire all 7 suites; sandbox `test-sync-resources.sh` (temp-copy); fix `.coverage-thresholds.json` enforcement command to this repo's real suite; add §5-authority note | codex/terra | ci.yml runs 7/7 suites green; sync test leaves `git status` clean (asserted in-test); enforcement command red-green (fails on a seeded failing test, passes on the real suite); note added that the JSON's percentage thresholds apply to future JS tooling — bash suites gate on pass/fail |
| W0.2 | Fork identity + self-marketplace (D10): add `.claude-plugin/marketplace.json`; re-point `.agents/plugins/marketplace.json`; validator URL derivation from package.json (normalized); install-path literal sweep (~30 files incl. INSTALL/README/GETTING_STARTED, platform-detect.js, cli/metaswarm.js, docs/index.html, templates + synced pairs, .codex/install.sh); migration note | codex/terra (scope enumerated at dispatch) | zero dsifry INSTALL-PATH literals (grep; attribution/lineage/CHANGELOG/docs-plans exempt); `claude plugin marketplace add Cabbala/metaswarm` shape verified against the live known_marketplaces format; `sync-resources --check` green; manifest test |
| W1a | bd semantic contract (D1): write `docs/bd-compatibility.md`; decide per-class semantics; scratch-repo verification transcript committed alongside | claude | every contract row carries live command+output evidence; PRIME.md override documented once |
| W1b | bd mechanical migration, batched by directory (incl. docs/index.html and TOML_COMMAND_MAP strings + TOML regeneration per D8 edit-ownership); adds permanent CI grep-guard test | codex/terra (batches) | pinned-pattern grep = zero hits outside `docs/bd-compatibility.md`, CHANGELOG.md, and `docs/plans/` (history + this design quote the broken forms legitimately — same exemption in the CI guard test); new guard test red-green; full suite green |
| W2a | external-tools adapter correctness (D2/D6/D9): `--model`/effort threading into both invocations; verify_scope against explicit base SHA BEFORE commit; sandbox envelope; availability fallback; review-leg read-only pin; fake-CLI argv tests; log hardening | codex/terra, **claude adversarial review (security-sensitive)** | fake-CLI test asserts exact argv (model, effort, sandbox, network flags); scope-violation test red-green; base/head review package test; no `--full-auto` remains |
| W2b | GPT-5.6 config/docs surface: templates ×2, setup bin ×4 + root `bin/` dups, SKILL.md tier table, cost tables ($2.50/$15, $5/$30, $1/$6), ultra=experimental + `features.rollout_budget.*` probe procedure, start-task model tables → haiku/sonnet/inherit, drop stale plugin_hooks claims | codex/luna | grep pattern `gpt-5\.3-codex($\|[^-])` = zero hits outside CHANGELOG.md and `docs/plans/` (spark tier deliberately excluded from the pattern and KEPT in the tier table); `sandbox:`/`auth_env_var:` dead keys reconciled (wired or removed); gemini `enabled: false` seeded |
| W3 | Codex hooks guard (D4): `"hooks": {}` + exact-literal manifest test (absent/`[]` fail) + unique-marker empirical test + AGENTS.md parity checklist | claude | manifest test red-green; marker test proves no Claude-hook execution under Codex; AGENTS.md template carries the enumerated parity items |
| W4 | Gate trigger paths + upstream-drift guard: primary `docs/superpowers/specs/*-design.md`, legacy `docs/plans/*-design.md` fallback; GETTING_STARTED + brainstorming-extension aligned; new test checks referenced superpowers skill names + trigger path against installed plugin (skips gracefully if absent); tested-version recorded | codex/terra | trigger fires on a stock v6.1.1-path fixture (behavior test, not filename grep); drift test red-green |
| W5 | Validation invariant (D6): rewrite VALIDATE definition + `external-tool-review-rubric.md` + adversarial rubric — once at the boundary; evidence format (command, exit status, rerun); tampering countermeasures (a)-(e) | claude | rubric mandates baseline re-run + red-green for new tests + out-of-scope test-diff block; RED/GREEN pressure-test of the rewritten prose |
| W6 | Dangling refs: spec + implement `bin/create-pr-with-shepherd.sh`, `bin/pr-comments-out-of-scope.sh` with red-green bash tests (`tests/bin/test-*.sh`); remove `/auto-ram-cleanup`, `/curate-pr-learnings` refs; note: buildDirSync auto-copies the new scripts into `skills/setup/bin/` — copies expected and in-scope | codex/terra | behavioral tests pass (PR-creation dry-run mode, out-of-scope classifier fixtures); zero dangling references by grep; `--check` green with the auto-synced copies |
| W7 | Gemini consumer-host retirement (D3): host surface removed (extension json, GEMINI.md ×3, 13 TOMLs + TOML branch of sync-resources + gemini entries in validateManifests lines ~283/293, tests/gemini, detectGemini install path, platform tables); adapter hardened + relabeled; `.metaswarm/project-profile.json` test command updated; CHANGELOG breaking-change note for existing Gemini-host users | codex/terra (explicit list from case-insensitive grep ≈59 files minus adapter keeps) | case-insensitive grep clean outside adapter+CHANGELOG+docs/plans; `external-tools-verify.sh` still passes for adapter; full suite green with gemini suite removed from ci.yml |
| W8 | installCodex(): two-step (`codex plugin marketplace add <fork>` THEN `codex plugin add metaswarm`), install-completion verification, legacy clone+symlink fallback on failure; INSTALL.md corrected | codex/luna | mocked-CLI test asserts both commands + completion check; depends on W0.2 |
| W9 | SDD dispatch contract (D5): vendored contract doc + orchestrated-execution rewrite (file handoffs, explicit model, single fix dispatch, compaction-proof ledger, base/head packages); gates reference the vendored contract; Team Mode boundary | claude (frontier quick) | contract doc exists + gates cite it; Team/Task dual-mode sections intact (grep); pilot metrics recorded for this refinement's own dispatches |
| W10 | project-profile schema + multi-language execution: versioned schema, validation, trust boundary; orchestrated-execution / external-tools / pr-shepherd / create-issue consume profile commands with documented JS/TS fallback | codex/terra + claude review | schema doc + validator; the 4 skills reference profile commands (grep); hardcoded `pnpm/vitest/tsc/eslint` remain only as documented fallback |
| W11 | Persona refinement (D11), 3 stages: (a) roster decisions + canonical template + agents/commands/bin sync-map consolidation in sync-resources.js; (b) 19-persona rewrite per D11 rules (issue-orchestrator deepest); (c) gate/rubric reference consolidation, ghost UX + cto-gate reconciliation | claude (frontier quick; issue-orchestrator full-depth), **codex/sol cross-review** | roster matches D11 disposition table; zero SaaS-stack tokens in agents/ (grep for Prisma/Clerk/PostHog/Stripe); issue-orchestrator ≤~200 lines with all runtime contracts intact; `--check` covers agents+commands+bin; docs state 5-reviewer gate |
| W12 | Frontmatter modernization + trigger evals (D7): fold `triggers:` into descriptions, delete inert keys ×10 skills; eval cases (positive/negative/near-miss) per skill; unconditional skills-check nudge in Claude session hook (exact content specified) | codex/terra + claude evals | zero `auto_activate`/`triggers` keys (grep); eval file per changed skill; hook diff shows the specified nudge |
| W13 | Doc-truth sweep (expanded): counts (post-W11 actuals), USAGE roster, ORCHESTRATION.md + CONTRIBUTING.md pointers, knowledge path AND schema/type-enum unification, phantom `skills/start/guides/` tree, SERVICE-INVENTORY path, INSTALL dependency table (recounted post-W9 vendoring), README acknowledgments (9 skills), beads repo links steveyegge→gastownhall, thin-shim claims, stub platform table, worktree guide native-tools-first, metaswarm-setup.md legacy status | codex/terra (checklist enumerated in brief) | every checklist item has a diff or an explicit "already true" note; no dead pointers by link-check |
| W14 | Authoring discipline docs (D7): `guides/skill-authoring.md`, tests-vs-evals split doc, CONTRIBUTING gate | claude (frontier quick) | docs exist; CONTRIBUTING references them; rewritten-prose WUs cite the pressure-test procedure |
| W15 | Hygiene: version-bump audit script (`--check` mode), remaining packaging notes | codex/luna | audit script red-green on a seeded drift fixture |

**Explicitly deferred** (bd follow-up issues, not silently dropped): Antigravity (`agy`) adapter
evaluation; Codex portal packaging; npm CLI retirement decision (W8 is deliberately minimal);
upstream PR + policy genericization; Cursor 3-way hook envelope; `bd remember`-based
knowledge-base seeding for the 7 empty JSONL files.

## 5. Verification strategy

- Full-suite command (named): `for t in tests/*/test-*.sh; do bash "$t" || exit 1; done && node
  lib/sync-resources.js --check` — run at each WAVE boundary and in the final review; per-WU
  VALIDATE runs the WU's targeted tests + `--check` + DoD greps (cost trim per fusion; W0.1 makes
  the full suite safe to run at all).
- §5 is authoritative over the repo's JS-specific coverage gate until W0.1 lands the corrected
  enforcement command (this sentence is the CTO-required carve-out).
- Every DoD grep uses pinned patterns enumerated in the dispatch brief. Scratch-repo verification
  transcripts (command + output) attach to the WU's bd issue.
- Cross-model rule: Codex-implemented WUs get Claude adversarial review; Claude-implemented
  security/architecture WUs (W5, W9, W11) get a Codex sol review leg. Fresh reviewer per re-review.
- Final comprehensive review: cross-WU integration + full suite + doc link-check + an end-to-end
  smoke scenario (create issue → start-task → dispatch → PR creation dry-run → shepherd handoff);
  the smoke scenario ALSO runs once at the Wave 1 boundary (§2 early-stop risk).
- Risk addendum: local-vs-CI toolchain divergence — every new guard test that probes local
  binaries skips gracefully in CI (see §4 preamble).
- bd: one issue per WU under epic `metaswarm-nnc` (gh-1); SESSION CLOSE protocol per bd prime.

## 6. Risks

| Risk | Mitigation |
|---|---|
| bd replacement semantics wrong | W1a live-verifies EVERY contract row before W1b sweeps; transcripts committed |
| Upstream superpowers drifts again under the fork (the class that silently killed the gate) | W4 drift-guard test (names + paths vs installed plugin, graceful skip); tested version recorded; D5 vendors the dispatch contract instead of runtime references |
| GPT-5.6 rollout is <48h old; availability may vary per account | D2 availability detection + distinct model-unavailable error + escalation; templates keep terra default but document the fallback |
| `ultra`/budget-key semantics undocumented | experimental opt-in only; empirical probe (clean CODEX_HOME) in W2; `XT_TIMEOUT` hard backstop |
| Mass sweeps (W1b, W7, W13) collateral edits | scoped file lists generated by validated grep at dispatch time; adversarial review diffs against the list; per-WU commits enable surgical revert |
| Validation loop self-contamination (repo tests mutate the repo being validated) | W0.1 sandboxes the mutating test BEFORE any sweep; wave-boundary full runs |
| Sol test-fabrication/tampering in delegated legs | D6 invariant (baseline re-run, red-green, out-of-scope test-diff block, untrusted-data delimiters, read-only reviews pinned by test) |
| Prompt injection via repo-derived text into delegated/hook contexts | D9 delimiters + network-off default + read-only reviews; hook self-heal made visible |
| Session/context limits before all WUs land | bd tracks per-WU state; `handoff` skill; Wave 0+1 alone deliver the correctness goal |
