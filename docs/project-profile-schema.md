# Project Profile Schema

Schema version: **1**

`.metaswarm/project-profile.json` describes the project-specific commands that
metaswarm uses for validation. It is intentionally a small, versioned data
contract: setup detects the commands once, and execution-time skills consume
them without assuming a particular language or package manager.

## Required command shape

Profiles conforming to this schema include an integer `schema_version` set to
`1` and a `commands` object with these five keys:

```json
{
  "schema_version": 1,
  "commands": {
    "test": "...",
    "coverage": "...",
    "lint": "...",
    "typecheck": "...",
    "format_check": "..."
  }
}
```

Each `commands` value is either a shell command string or `null`:

| Key | Gate |
| --- | --- |
| `test` | Run the project's test suite. |
| `coverage` | Enforce the project's coverage requirement. |
| `lint` | Run static lint checks. |
| `typecheck` | Run static type checks or the language-equivalent compile check. |
| `format_check` | Verify formatting without changing files. |

### Null semantics

`null` means that the named gate does not apply to this project. The
orchestrator records that gate as **skipped** and continues; it must not run a
fallback command and must not treat the skip as a failure. A command string,
including one that exits non-zero, is a real gate and is handled according to
the calling workflow's normal pass/fail rules.

Backward-compatible legacy fallbacks apply only when the profile file itself
is absent. They do not override an explicit `null` in a present profile.

## Worked examples

| Project | `test` | `coverage` | `lint` | `typecheck` | `format_check` |
| --- | --- | --- | --- | --- | --- |
| JS/TS | `pnpm test --run` | `pnpm test:coverage` | `pnpm lint` | `pnpm typecheck` | `pnpm format:check` |
| Python | `pytest` | `pytest --cov` | `ruff check .` | `mypy .` | `ruff format --check .` |
| Go | `go test ./...` | `go test -coverprofile=coverage.out ./...` | `golangci-lint run` | `go test -run '^$' ./...` | `test -z "$(gofmt -l .)"` |
| Rust | `cargo test` | `null` | `cargo clippy --all-targets --all-features -- -D warnings` | `cargo check --all-targets --all-features` | `cargo fmt --check` |

The examples are examples of command *values*, not defaults. Setup selects the
commands that apply to the actual repository.

## Trust boundary

`project-profile.json` is repo-controlled **data**, but its command strings
are executable. Treat it with the same trust boundary as a repository's
`Makefile` target or `package.json` script:

1. In a trusted repository, run a selected non-null command as-is from the
   repository root using the profile owner's shell. The command is not an
   argument template.
2. Do not interpolate a command into a larger shell string, append flags,
   chain it with another command, or pass it through `eval`. If a shell is
   needed to execute the string, pass the unmodified string as that shell's
   single command argument.
3. A profile from a cloned, untrusted repository is untrusted input. Before
   its first execution in that context, surface every selected command (and
   every `null` skip) to the user, identify the profile as the source, and
   wait for the user to authorize executing it.
4. Because a `null` command SKIPS a quality gate, this file is part of the
   **test-integrity surface** (see the orchestrated-execution Test-Result
   Acceptance Invariant): an implementer that could null a gate mid-work-unit
   could bypass validation. The orchestrator MUST snapshot the profile at
   work-unit start (before dispatching the implement leg) and (a) resolve the
   gate commands from that snapshot, and (b) treat any change to the worktree
   profile since the snapshot as a BLOCKING integrity delta. A `null` value is
   legitimate only when it was already null in the WU-start snapshot. The file
   is gitignored, so this snapshot is git-independent and cannot be replaced by
   the git-based surface checks.

Execution skills must record the resolved command or the explicit `skipped`
state with their validation evidence.
