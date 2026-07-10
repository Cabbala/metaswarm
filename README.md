# metaswarm

A self-improving multi-agent orchestration framework for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and Codex CLI. Coordinate 18 specialized AI agents and 14 orchestration skills through a complete software development lifecycle, from issue to merged PR, with recursive orchestration, parallel review gates, and a git-native knowledge base.

## What Is This?

metaswarm is an extraction of a production-tested agentic orchestration system. It has been proven in the field writing production-level code with 100% test coverage, mandatory TDD, multi-reviewed spec-driven development, and SDLC best practices across hundreds of PRs. It provides:

- **18 specialized agent personas** (Researcher, Architect, Coder, Security Auditor, PR Shepherd, etc.)
- **A structured 9-phase workflow**: Research → Plan → Design Review Gate → Work Unit Decomposition → Orchestrated Execution → Final Review → PR Creation → PR Shepherd → Closure & Learning
- **4-Phase Orchestrated Execution Loop**: Each work unit runs through IMPLEMENT → VALIDATE → ADVERSARIAL REVIEW → COMMIT. The orchestrator validates independently (never trusts subagent self-reports), and adversarial reviewers check DoD compliance with file:line evidence
- **Parallel Design Review Gate**: 5 specialist agents (PM, Architect, Designer, Security, CTO) review in parallel with a 3-iteration cap before human escalation
- **Recursive orchestration**: Swarm Coordinators spawn Issue Orchestrators, which spawn sub-orchestrators for complex epics (swarm of swarms)
- **Git-native task tracking**: Uses [BEADS](https://github.com/gastownhall/beads) (`bd` CLI) for issue/task management, dependencies, and knowledge priming
- **Knowledge base**: JSONL-based fact store for patterns, gotchas, decisions, and anti-patterns — agents prime from this before every task
- **Quality rubrics**: Standardized review criteria for code, architecture, security, testing, planning, and adversarial spec compliance
- **External AI tool delegation**: Optionally delegate implementation and review tasks to OpenAI Codex CLI and the enterprise/API-key-only Gemini adapter (consumer CLI discontinued 2026-06-18) for cross-model adversarial review
- **Visual review**: Playwright-based screenshot capture for reviewing web UIs, presentations, and rendered pages
- **PR lifecycle automation**: Autonomous CI monitoring, review comment handling, and thread resolution
- **Workflow enforcement**: Mandatory quality gate intercepts at every handoff point — agents cannot skip design review, plan review, or knowledge capture
- **Context recovery**: Approved plans and execution state persist to disk via BEADS, surviving context compaction and session interruption

## Architecture

```text
Your prompt (spec with DoD items) or GitHub Issue
        │
        ▼
┌─────────────────────────────────┐
│  Swarm Coordinator               │
│  - Assign to worktree            │
│  - Spawn Issue Orchestrator      │
└─────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────┐
│  Issue Orchestrator              │
│  - Create BEADS epic             │
│  - Decompose into work units     │
└─────────────────────────────────┘
        │
        ▼
  Research → Plan → Design Review Gate (5 parallel reviewers)
        │
        ▼
  Work Unit Decomposition (DoD items, file scopes, dependency graph)
        │
        ▼
  Orchestrated Execution Loop (per work unit):
    IMPLEMENT → VALIDATE → ADVERSARIAL REVIEW → COMMIT
    (Optionally delegates to Codex or the enterprise/API-key Gemini adapter)
    (Cross-model REVIEW: writer always reviewed by different model)
        │
        ▼
  Final Comprehensive Review (cross-unit integration)
        │
        ▼
  PR Creation → PR Shepherd (auto-monitors to merge)
        │
        ▼
  Closure → Knowledge Extraction (feedback loop)
```

## Repository Structure

```text
metaswarm/
├── .claude-plugin/
│   └── plugin.json           # Claude Code plugin manifest
├── .codex/
│   ├── install.sh            # Codex CLI install script
│   └── README.md             # Codex CLI usage guide
├── hooks/
│   ├── hooks.json            # SessionStart + PreCompact hook definitions
│   └── session-start.sh      # Context priming (platform-aware)
├── skills/                   # Orchestration skills (Agent Skills standard — portable)
│   ├── start/                # Main entry point — workflow guide + 18 agent personas
│   ├── orchestrated-execution/ # 4-phase execution loop (IMPLEMENT→VALIDATE→REVIEW→COMMIT)
│   ├── design-review-gate/   # Parallel 5-agent review
│   ├── plan-review-gate/     # 3-reviewer adversarial plan review
│   ├── setup/                # Interactive project setup
│   ├── migrate/              # Migration from npm to plugin installation
│   ├── status/               # Diagnostic checks
│   ├── pr-shepherd/          # PR lifecycle automation
│   ├── handling-pr-comments/ # Review comment workflow
│   ├── handoff/              # Session-handoff analysis
│   ├── brainstorming-extension/
│   ├── create-issue/
│   ├── external-tools/       # Cross-model AI delegation adapters (Codex, enterprise/API-key Gemini)
│   └── visual-review/        # Playwright-based screenshot review
├── commands/                  # Claude Code commands
│   └── *.md                  # Claude Code command definitions
├── agents/                    # 18 agent persona definitions
├── rubrics/                   # Quality review standards
├── guides/                    # Development patterns
├── knowledge/                 # Knowledge base schema + templates
├── templates/                 # Setup templates (CLAUDE.md and AGENTS.md + append variants)
├── lib/                       # Platform detection, sync, setup scripts
├── cli/                       # Claude/Codex installer (npx metaswarm)
├── CLAUDE.md                  # Claude Code project instructions
├── AGENTS.md                  # Codex CLI project instructions
├── INSTALL.md
├── GETTING_STARTED.md
├── USAGE.md
└── CONTRIBUTING.md
```

## Install

> **Upgrading from the upstream marketplace?** If you previously registered `dsifry/metaswarm-marketplace`, add this fork's marketplace (`claude plugin marketplace add Cabbala/metaswarm`), reinstall with `claude plugin install metaswarm@metaswarm`, then optionally remove the old source with `claude plugin marketplace remove metaswarm-marketplace` (the remove subcommand takes the registered marketplace NAME, not the repo slug).

### Claude Code (recommended)

```bash
claude plugin marketplace add Cabbala/metaswarm
claude plugin install metaswarm@metaswarm
```

*(The plugin and its marketplace intentionally share the name `metaswarm`, hence the qualified `metaswarm@metaswarm` form.)*

Then run `/setup` in Claude Code.

### Codex CLI

```bash
codex plugin marketplace add Cabbala/metaswarm
codex plugin add metaswarm@metaswarm
```

Then run `$setup` in your project.

### Platform installer

Detect supported host CLIs and install metaswarm for them:

```bash
npx metaswarm init
```

### Start building

Run `/start-task` (Claude) or `$start` (Codex) and describe what you want in plain English. No issue required.

```text
/start-task Add a webhook system with retry logic, signature verification,
and a delivery log UI.
```

See [INSTALL.md](INSTALL.md) for prerequisites, platform-specific details, and migration from older versions.

## Self-Learning System

metaswarm doesn't just execute — it learns from every session and gets smarter over time.

### Automatic Reflection

After every PR merge, the self-reflect workflow (`/self-reflect`) analyzes what happened:

- **Code review feedback** — Extracts patterns, gotchas, and anti-patterns from reviewer comments (both human and automated) and writes them back to the knowledge base as structured JSONL entries
- **Build and test failures** — Captures what broke and why, so agents avoid the same mistakes in future tasks
- **Architectural decisions** — Records the rationale behind choices so future agents understand the "why", not just the "what"

### Conversation Introspection

The reflection system also introspects into the Claude Code session itself, looking for:

- **User repetition** — When a user corrects the same behavior multiple times or repeats instructions, this signals an opportunity for a new skill or command. The system flags these as candidates for automation.
- **User disagreements** — When a user rejects or overrides Claude's recommendation, the system captures the user's preferred approach as a knowledge base entry, so agents align with the user's intent in future sessions.
- **Friction points** — Repeated manual steps that could be codified into reusable workflows.

These signals feed back into the knowledge base and can generate proposals for new skills, updated rubrics, or revised agent behaviors.

### Project-Defined Knowledge Priming

The bare `bd prime` command loads the project's priming context. To tailor that context for the repository, create the tracked `.beads/PRIME.md` override documented by `bd prime --help`; the former file, keyword, and work-type flags are not supported.

```bash
bd prime
```

This keeps the project-specific context explicit and versioned alongside the work it governs.

## Design Principles

1. **Knowledge-Driven Development** — Agents prime from the knowledge base before every task, reducing repeated mistakes
2. **Trust Nothing, Verify Everything** — Orchestrators validate independently (run tests themselves, never trust subagent self-reports), review adversarially against written spec contracts, and optionally use cross-model review via external AI tools
3. **Parallel Review Gates** — Independent specialist reviewers run concurrently, not sequentially
4. **Recursive Orchestration** — Orchestrators spawn sub-orchestrators for any level of complexity
5. **Agent Ownership** — Each agent owns its lifecycle; the orchestrator delegates, not micromanages
6. **BEADS as Source of Truth** — All task state lives in BEADS; agents coordinate via database, not messages
7. **Test-First Always** — TDD is mandatory, not optional. Coverage thresholds are enforced as a blocking gate before PR creation via `.coverage-thresholds.json`
8. **Git-Native Everything** — Issues, knowledge, specs all in version control
9. **Human-in-the-Loop** — Proactive checkpoints at planned review points, plus automatic escalation after 3 failed iterations or ambiguous decisions

## Supported Platforms

| Platform | Install Method | Commands |
|---|---|---|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | Plugin marketplace | `/start-task`, `/setup`, etc. |
| [Codex CLI](https://github.com/openai/codex) | Plugin marketplace | `$start`, `$setup`, etc. |
| Cursor | Stub/planned — not supported | No shipped integration |
| OpenCode | Stub/planned — not supported | No shipped integration |

## Requirements

- One of: Claude Code or Codex CLI
- Node.js 18+ (for automation scripts)
- [BEADS](https://github.com/gastownhall/beads) CLI (`bd`) v0.40+ — for task tracking (recommended)
- GitHub CLI (`gh`) — for PR automation (recommended)
- Playwright — for visual review skill (optional, `npx playwright install chromium`)

## License

MIT

## Acknowledgments

metaswarm stands on the shoulders of three key projects:

- **[metaswarm upstream](https://github.com/dsifry/metaswarm)** by Dave Sifry — The upstream project from which this repository evolved.

- **[BEADS](https://github.com/gastownhall/beads)** — The git-native, AI-first issue tracking system that serves as the coordination backbone for all agent task management, dependency tracking, and knowledge priming in metaswarm. BEADS made it possible to treat issue tracking as a first-class part of the codebase rather than an external service.

- **[Superpowers](https://github.com/obra/superpowers)** by [Jesse Vincent](https://github.com/obra) and contributors — The agentic skills framework and software development methodology that provides the upstream skills metaswarm builds on: `brainstorming`, `executing-plans`, `finishing-a-development-branch`, `subagent-driven-development`, `systematic-debugging`, `test-driven-development`, `using-git-worktrees`, `verification-before-completion`, and `writing-plans`. Superpowers demonstrated that disciplined agent workflows aren't overhead — they're what make autonomous development reliable.

metaswarm was created by [Dave Sifry](https://linkedin.com/in/dsifry), founder of Technorati, Linuxcare, and Warmstart, and former tech executive at Lyft and Reddit. Extracted from a production multi-tenant SaaS codebase where it has been writing production-level code with 100% test coverage, TDD, and spec-driven development across hundreds of autonomous PRs.
