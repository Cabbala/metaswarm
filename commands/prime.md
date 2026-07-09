---
description: Load relevant knowledge base facts into context before starting work
---

# BEADS Prime

**CRITICAL**: Run this command at the START of any investigation, planning, or implementation work to load relevant knowledge into your context.

## When to Use

- Starting work on a GitHub Issue
- Beginning investigation/research
- Before writing a plan
- Before implementing changes
- When switching to a new area of the codebase

## How It Works

This command queries the BEADS knowledge base for facts relevant to your current context and injects them into the conversation, ensuring you:

1. Follow established patterns and rules
2. Avoid known gotchas and pitfalls
3. Make decisions aligned with architectural choices
4. Don't repeat mistakes that have been learned from

## Usage

### Quick Prime (Most Common)

For general context with automatic detection:

```bash
bd prime
```

### Project-Specific Priming

`bd prime` no longer accepts file, keyword, or work-type filters. Maintain the tracked `.beads/PRIME.md` override to define the repository's project-specific context, then run:

```bash
bd prime
```

### Prime for Context Recovery

When resuming after context compaction or in a new session:

```bash
bd prime
```

This loads the context defined by the tracked `.beads/PRIME.md` override, including any recovery guidance the project needs. See "Context Recovery" section below.

## What Gets Loaded

### 1. MUST FOLLOW (Critical Rules)

Non-negotiable rules containing NEVER/ALWAYS/MUST:

- "NEVER use `as any` type casting"
- "ALWAYS use centralized AI config"
- Security-critical patterns

### 2. GOTCHAS (Common Pitfalls)

Known issues to avoid:

- "Truthy check fails for explicit zero values - use !== undefined"
- API behavior quirks

### 3. PATTERNS (Best Practices)

Established patterns in this codebase:

- "Use mock factories from test utilities"
- "Services should follow TDD (Red-Green-Refactor)"

### 4. DECISIONS (Architectural Choices)

Team/architectural decisions:

- "State management uses Zustand + TanStack Query"
- "AI providers implement Strategy Pattern"

### 5. API BEHAVIORS

External API quirks:

- "Prisma findMany returns [] not null"

## Auto-Priming

The BEADS system should auto-prime in these scenarios:

1. **Session Start**: When `.beads/` directory is detected
2. **File Touch**: When reading/editing files that match knowledge patterns
3. **Keyword Detection**: When task description matches known topics

## Integration Points

### In Planning Phase

Before writing a plan, run the project-defined priming command:

```bash
bd prime
```

### In Implementation Phase

Before writing code, run the same project-defined priming command:

```bash
bd prime
```

### In Review Phase

Before reviewing code, run the same project-defined priming command:

```bash
bd prime
```

## Manual Knowledge Check

If you need to check for specific knowledge:

```bash
# Search for specific topic
cat .beads/knowledge/*.jsonl | jq -r 'select(.fact | test("authentication"; "i")) | .fact'

# Get all gotchas
cat .beads/knowledge/gotchas.jsonl | jq -r '.fact'

# Get all patterns
cat .beads/knowledge/patterns.jsonl | jq -r '.fact'
```

## Output Format

The prime command outputs formatted knowledge that looks like:

```markdown
# Relevant Knowledge Base Facts

_25 facts loaded for this context_

## MUST FOLLOW (Critical Rules)

These are non-negotiable rules:

- **[pattern]** NEVER use `as any` type casting...
- **[security]** Always validate JWT tokens server-side...

## GOTCHAS (Common Pitfalls)

Avoid these known issues:

- **[gotcha]** Truthy check fails for explicit zero values...

## PATTERNS (Best Practices)

- **[pattern]** Use mock factories from test utilities...
```

## Context Recovery

When an orchestrator detects it lost context (post-compaction or session interruption), re-run bare `bd prime` — the recovery context below loads in addition to the standard knowledge base:

### What Gets Loaded

1. **Active Plan** — reads `.beads/plans/active-plan.md` if it exists with `status: in-progress`
2. **Project Context** — reads `.beads/context/project-context.md` (completed work units, established patterns, tooling)
3. **Execution State** — reads `.beads/context/execution-state.md` (current work unit, phase, retry count)
4. **Standard Knowledge** — all the usual MUST FOLLOW, GOTCHAS, PATTERNS, DECISIONS facts

### Recovery Flow

```bash
# 1. Check for active execution
if [ -f .beads/plans/active-plan.md ]; then
  grep -q 'status: in-progress' .beads/plans/active-plan.md && echo "ACTIVE PLAN FOUND"
fi

# 2. Load all context files
cat .beads/plans/active-plan.md           # The approved plan
cat .beads/context/project-context.md     # Completed work, patterns
cat .beads/context/execution-state.md     # Where we left off

# 3. Load relevant knowledge base facts
cat .beads/knowledge/*.jsonl | jq -r '.fact'
```

### When Recovery Triggers Automatically

- Orchestrated execution starts and finds `.beads/plans/active-plan.md` with `status: in-progress` but has no plan in its current context
- A new session begins with `bd prime` and active execution state is detected
- After context compaction, when the agent recognizes it has lost plan/execution context

### Output Format (Recovery Mode)

```markdown
# Context Recovery

_Recovered from BEADS persisted state_

## Active Plan
<plan summary — title, work unit count, current position>

## Execution State
- Current work unit: WU-<id> (<title>)
- Phase: <IMPLEMENT|VALIDATE|REVIEW|COMMIT>
- Completed: <N> of <total> work units

## Project Context
<tooling, completed work units, established patterns>

## Relevant Knowledge
<standard priming output: MUST FOLLOW, GOTCHAS, PATTERNS, DECISIONS>
```

## Verification

After priming, you should be able to answer:

1. What are the critical rules I must follow?
2. What gotchas should I watch out for?
3. What patterns should I apply?
4. What architectural decisions constrain my options?
5. (If recovery mode) Where did execution stop and what comes next?
