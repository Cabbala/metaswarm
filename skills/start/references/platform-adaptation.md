# Platform Adaptation Guide

metaswarm has two host platforms: Claude Code and Codex CLI. Skills use the Agent Skills standard (SKILL.md with YAML frontmatter), so core workflows remain portable across both.

## Tool Equivalents

| Capability | Claude Code | Codex CLI |
|---|---|---|
| Read file | `Read` tool | `read_file` |
| Write file | `Write` tool | `write_file` |
| Run commands | `Bash` tool | `exec_command` |
| Ask user | `AskUserQuestion` | structured input |
| Subagents | `Task` tool | native subagents |

## Parallelism

### Claude Code (Full)

Claude Code supports parallel sub-agents for:

- Design review (5 specialist reviewers in parallel)
- Plan review (3 adversarial reviewers in parallel)
- Adversarial review (fresh reviewer with no prior context)
- Background research while implementation continues

### Codex CLI (Sequential Only)

Codex CLI has no host-platform subagent dispatch. All workflows run sequentially in-session:

- Review gates become self-review against rubric checklists
- The agent explicitly works through each rubric criterion, citing file:line evidence
- The quality of review is maintained through the rubric structure, not agent isolation

## Shared Quality Guarantees

1. **Never skip a quality gate** — if parallel dispatch is unavailable, run it sequentially
2. **Rubrics are the invariant** — the same review criteria apply regardless of the execution surface
3. **Evidence requirements don't change** — file:line citations are required on both host platforms
4. **TDD is mandatory everywhere** — write tests first, watch them fail, then implement
5. **Coverage gates are blocking everywhere** — `.coverage-thresholds.json` is enforced regardless of platform

## Command Invocation

Claude uses slash commands. Codex uses the `name` field from SKILL.md frontmatter for `$name` invocation — not the directory name.

| Action | Claude Code | Codex CLI |
|---|---|---|
| Start task | `/start-task` | `$start` |
| Setup | `/setup` | `$setup` |
| Status | `/status` | `$status` |
| Plan review | `/review-design` | `$plan-review-gate` |

## Instruction Files

| Platform | File | Purpose |
|---|---|---|
| Claude Code | `CLAUDE.md` | Project instructions loaded automatically |
| Codex CLI | `AGENTS.md` | Agent instructions loaded automatically |

## External Gemini Adapter

Gemini is not a metaswarm host platform. The optional Gemini adapter is an enterprise/API-key compatibility target only; consumer Gemini CLI access was discontinued 2026-06-18. It stays disabled by default, and its implement leg requires a working binary with `--sandbox`; otherwise it is review-only.
