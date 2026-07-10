# Dispatch Contract

Host-neutral rules for a **controller** that dispatches independent **workers** to
do bounded work and return verifiable results. Every metaswarm skill that spawns
subagents — orchestrated execution, the design- and plan-review gates — dispatches
against this contract instead of restating the mechanics inline. One deliberate
exception: the **design-review gate's collaborative reviewers persist across
revisions** (Team Mode) and are therefore exempt from the fresh-reviewer rule (§f);
every other rule still binds them.

**Provenance.** These lessons are distilled from superpowers v6.1.1 — its
subagent-driven-development and dispatching-parallel-agents skills. Superpowers is
the **source**; metaswarm **vendors** the contract so the pipeline works standalone.
Do not turn this citation into a runtime dependency: no skill needs superpowers
installed to consume this file. (Referencing superpowers by name at runtime is the
coupling that once silently disabled the design-review gate; INSTALL.md promises
metaswarm works on its own.)

**On the "~2× faster / ~50% fewer tokens" figure.** That is an upstream *anecdote*
from superpowers sessions — use it as motivation for why the discipline pays off.
It is **not** a metaswarm acceptance criterion; never gate work on reproducing it.

**Terms.** *Controller* — the orchestrating agent. *Worker* — a dispatched agent
with isolated context. *Dispatch surface* — the host primitive that spawns a worker
(§h). *Ledger* — durable on-disk progress state (§g).

---

## (a) Parallelism & isolation

**Rule.** A worker never inherits the controller's context or history. The
controller constructs exactly what each worker needs and nothing else. Workers have
**no cross-visibility**: no worker sees another worker's prompt, output, or
existence.

**Rule.** For N independent problem domains, spawn N workers — one per domain. On a
host where dispatches issued in a single turn run concurrently, issue all N in one
turn; one dispatch per turn serializes them and forfeits the parallelism.

**Why.** Isolation is what makes a second worker's judgment an *independent* check.
Shared context produces convergence and anchoring, not verification. Cross-visibility
between reviewers destroys the value of having more than one.

## (b) File-based artifact handoffs

**Rule.** Bulk artifacts — specs, plans, diffs/review packages, project context, and
producer reports — pass as file **paths**, never pasted into a prompt inline. The
worker reads the file itself. Short structured items the worker must check one by one
(a DoD checklist, a few global constraints) MAY be enumerated inline; that is the
worker's worklist, not bulk prose.

**Rule — producers write files, reviewers return their verdict.** A *producer* (an
implementer, or a fixer) writes its full artifacts and detailed report to files and
returns only a status, a one-line summary, and the report-file path — never full prose.
A *reviewer* runs read-only (§f, §h): it does NOT write a repo report file; it RETURNS
its verdict and findings as its result. The inputs a reviewer reads as file paths are
the base/head review package (§e) and — in review models that feed it — the producer's
report and the task brief. (metaswarm's Phase-3 adversarial reviewer deliberately
withholds the producer's self-assessment and judges the package alone; that is a
stricter specialization, not a conflict.)

**Why — controller context is the scarce resource.** Anything pasted into a dispatch,
and anything a worker prints back, stays resident in the controller's context and is
re-read on every later turn. Upstream, one real dispatch reached 42k characters of
which 99% was pasted history; the fix was to hand artifacts as files. Bulk bytes
belong on disk, not in the transcript.

**Rule — absolute paths only.** Every path handed to a worker MUST be absolute. A
worker's working directory is not the controller's; a bare relative path resolves
against the wrong root and the read fails or reads the wrong file. (Skills that ship a
synced copy resolve it against the host plugin root before embedding it — see §h.)

## (c) Explicit model per dispatch

**Rule.** Name the model tier for **every** worker. Never rely on an inherited
default.

**Why.** An omitted model inherits the controller's model — usually the most capable
and most expensive tier — silently defeating cost control. Match tier to the job:
transcription / single-file mechanical work → cheapest tier; multi-file integration
and judgment → mid tier; architecture, subtle-risk, or whole-branch review → most
capable tier. A small mechanical diff does not need the top model; a subtle
concurrency change does.

## (d) Single consolidated fix dispatch

**Rule.** All findings from ONE review round go to ONE fixer in ONE dispatch — not
one fixer per finding. The fixer re-runs the tests covering its changes and reports
the command and output.

**Why.** Each fixer rebuilds context and re-runs suites from cold. A per-finding
fan-out's fix wave can cost more than all the original implementation combined.
Consolidation is the difference between one context rebuild and one per finding.

## (e) Base/head-SHA review packages

**Rule.** A reviewer receives an explicit `BASE..HEAD` range, where `BASE` is the SHA
the controller recorded **before** the worker started. Not "the latest diff." Not
`HEAD~1`.

**Why.** `HEAD~1` silently drops every commit but the last of a multi-commit task;
"the latest diff" is undefined after any intervening commit. The package — commit
list, stat summary, and full diff with context — is written to one file and handed
over per §b, so the reviewer reads it in a single call and it never enters the
controller's context.

## (f) Fresh-reviewer rule (adversarial reviewers)

**Rule.** An **adversarial** re-review after a fix uses a **new** reviewer with zero
memory of the prior review. Never resume the reviewer; never hand it the previous
reviewer's findings. It reads the UPDATED inputs — the new base/head package (now
carrying the fix commits) and, in review models that feed the producer's report, the
report the fixer appended its fix report to — and forms its verdict independently.

**Why.** A reviewer that remembers its earlier findings checks for *those* specifically
instead of reviewing fresh. Anchoring bias makes the re-check a formality rather than an
independent verdict — the exact failure the second pass exists to prevent.

**Exception — collaborative reviewers persist.** This rule scopes to *adversarial*
reviewers (metaswarm's Phase-3 execution review and the plan-review gate). The
design-review gate's collaborative panel (PM, Architect, Designer, Security, CTO)
deliberately RETAINS context across design revisions under Team Mode, so it need not
re-read the whole design each round. That persistence is intentional and is the one
exception to this rule; it does not weaken it for the adversarial path.

## (g) Compaction-proof ledger

**Rule.** Completed-work state lives in a durable on-disk ledger, not only in
conversation memory or a todo list. Before dispatching, the controller reads the
ledger; anything it marks complete is DONE and MUST NOT be re-dispatched. Append one
line per completed unit (with its commit range) in the same turn as the rest of the
bookkeeping.

**Why.** Conversation memory does not survive compaction. Upstream, controllers that
lost their place re-dispatched entire completed sequences — the single most expensive
failure observed. The ledger names commits that exist in git even when the controller
no longer remembers creating them; after compaction, trust the ledger and `git log`
over recollection.

## (h) Host mapping — Claude Code vs Codex

The contract body is host-neutral; each host maps it to its own dispatch surface. On
Codex the in-session subagent primitive is `spawn_agent` (the native equivalent of
`Task()`); `codex exec` is the external/headless runner, used only when the work must
outlive the session.

| Contract element        | Claude Code                                      | Codex                                                          |
| ----------------------- | ------------------------------------------------ | -------------------------------------------------------------- |
| Dispatch surface        | `Task(subagent_type, prompt, model)`             | `spawn_agent` (in-session); `codex exec` for headless/external |
| N parallel workers (a)  | N `Task()` calls in one turn                     | N `spawn_agent` calls in one turn (headless: N `codex exec`)    |
| Explicit model (c)      | `model` on the `Task()` call                     | `model` on `spawn_agent`; `--model` on `codex exec`            |
| Read-only reviewer (f)  | read-only subagent                               | read-only sandbox (`codex exec`: `sandbox: read-only`, `approval-policy: never`) |
| Path root for handoffs (b) | resolve against `${CLAUDE_PLUGIN_ROOT}`       | resolve against `${PLUGIN_ROOT}` / `${CODEX_HOME}`             |
| Ledger location (g)     | on-disk under the repo (git-tracked or scratch)  | same                                                           |

Both hosts obey §a–§g identically. Only the surface changes; the rules do not.
