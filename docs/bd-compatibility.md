# bd (beads) CLI Compatibility Contract

**Verified against**: bd 1.0.5 (`6a3f515ce`), 2026-07-10, live probes in a scratch repo.
**Purpose**: single tracked reference for migrating metaswarm's legacy bd vocabulary
(pre-1.0 interface) to the installed CLI surface. Every row below was exercised against the
real binary — see the transcript section. Migration happens by semantic class, never by blind
string replacement.

## Contract table

| # | Legacy form (broken unless noted) | Semantic intent | Replacement | Notes |
|---|---|---|---|---|
| 1 | `bd prime --work-type <t>`, `--files <g>`, `--keywords <k>` | scoped session priming | **bare `bd prime`** | Scoping flags do not exist. Project-level customization = tracked `.beads/PRIME.md` override (documented in `bd prime --help`); `--export` dumps the default for customization. Valid remaining flags: `--export/--full/--hook-json/--mcp/--memories-only/--stealth`. |
| 2 | `bd stats` | inspect DB status | **no change needed** (valid alias of `bd status`) | Optional normalization to `bd status` is non-blocking; do NOT count `bd stats` as a broken call site. |
| 3 | `bd start <id>` | claim work | `bd update <id> --claim` | `bd start` is not a command. |
| 4 | `bd create ... --issue N` | link a GitHub issue | `bd create ... --external-ref "gh-N"` | `--external-ref` accepts `gh-9`, `jira-ABC`, Linear URLs. |
| 5 | `bd decision "..."` | durable decision record | **`bd create "Decision: ..." -t decision`** | `decision` is a first-class issue type (`bug\|feature\|task\|epic\|chore\|decision`) — keeps decisions in the exported issue graph. Use `bd comment <id> "..."` for issue-scoped notes and `bd remember "..."` ONLY where cross-session memory-injection semantics are wanted (it feeds future priming — different visibility). |
| 6 | `bd compact` (intended: semantic summarization) | summarize old closed issues | `bd admin compact` | Top-level `bd compact` is Dolt HISTORY squash and remains valid where history cleanup was the intent. Only call sites meaning semantic decay migrate. |
| 7 | `bd sync --status` / `bd sync --from-main` | persistence / sync | **no drop-in replacement — use an explicit Dolt policy** | `bd sync` does not exist. State persistence is Dolt-backed: `bd dolt commit` / `bd dolt push` / `bd dolt status` (+ `--dolt-auto-commit` global flag / `dolt.auto-commit` config). `bd export` is NOT a backup substitute (its own help: does not preserve branches, history, working-set state, or non-issue tables). Docs that promised "sync to main" must describe the Dolt policy or be removed. |

## Sweep guard patterns (for CI and the W1b DoD)

Pinned patterns for the 6 genuinely-broken forms (POSIX ERE, applied to tracked text files;
exempt: this file, `CHANGELOG.md`, `docs/plans/`):

```
bd prime --(work-type|files|keywords)
bd sync( |$)
bd start [0-9a-z]
bd create.*--issue[ =]
bd decision( |$)
(^|[^a-z-])bd compact( |$)   # flag for MANUAL classification (intent: semantic vs history)
```

Pattern 6 (`bd compact`) is a classification flag, not an auto-replace: each hit must be
resolved to `bd admin compact` (semantic) or left (history squash) per row 6.

## Live verification transcript (2026-07-10, scratch repo, bd 1.0.5)

```text
$ bd prime --help | grep -A2 PRIME.md
  - Place a .beads/PRIME.md file in the local clone or resolved workspace to override the
    default output entirely.
  - Use --export to dump the default content for customization.
      --export          Output default content (ignores PRIME.md override)

$ bd comment --help | head -2
Add a comment to an issue.
Shorthand for 'bd comments add <id> "text"'.

$ bd dolt --help | grep -E '^  bd dolt (commit|push|status)'
  bd dolt status       Show Dolt server status
  bd dolt commit       Commit pending changes
  bd dolt push         Push commits to Dolt remote

$ bd create "Decision: test decision record" -t decision   # -> created bd-verify-z6f
$ bd show bd-verify-z6f | grep Type
Owner: cabbala · Type: decision

$ bd update bd-verify-z6f --claim
✓ Updated issue: bd-verify-z6f — Decision: test decision record

$ bd admin compact --help | head -1
Compact old closed issues using semantic summarization.

$ bd stats | head -2
📊 Issue Database Status

$ bd create --help | grep external-ref
      --external-ref string     External reference (e.g., 'gh-9', 'jira-ABC', Linear URL)

$ bd prime --work-type research      # legacy form, FAILS
Error: unknown flag: --work-type
```

## Provenance

Semantics decided in the approved refinement design
(`docs/plans/2026-07-10-superpowers-v6-gpt56-refinement-design.md`, decision D1), validated by
three gate rounds and a cross-model fusion panel. The locally-installed beads skill
(`.agents/skills/beads/SKILL.md`) informed the vocabulary but is untracked and does not ship
with this repo — THIS document is the reference for contributors and for the W1b migration.
