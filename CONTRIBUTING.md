# Contributing to metaswarm

Thank you for your interest in contributing to metaswarm.

## How to Contribute

### Reporting Issues

Open an issue on GitHub with:
- What you expected to happen
- What actually happened
- Steps to reproduce
- Your environment (Claude Code version, BEADS version, OS)

### Adding or Improving Agents

Agent definitions live in `agents/`. Each agent is a Markdown file with:

1. **Role** — What the agent specializes in
2. **Responsibilities** — What it does and produces
3. **Process** — Step-by-step workflow
4. **Output Format** — Expected deliverables
5. **Integration Points** — How it connects to other agents

When contributing a new agent:
- Place it in `agents/<name>-agent.md`
- Add it to the current agent roster in `ORCHESTRATION.md`
- Document it in `USAGE.md`
- Keep it generic (no project-specific references)

### Adding Skills

Skills are orchestration behaviors in `skills/<name>/SKILL.md`. A skill coordinates multiple agents or provides a reusable workflow pattern.

### Changing Skill or Agent Prose

Editing existing prose in `skills/`, `agents/`, or a gate — not just adding a new file — is a
discipline change, not a wording tweak. It requires:

1. Follow `guides/skill-authoring.md`: classify the failure (discipline vs. shaping) before
   choosing a prohibition table or a positive recipe, and keep `description` fields to
   trigger conditions only.
2. Attach evidence: a RED/GREEN pressure-test walkthrough for behavior/discipline changes,
   or a trigger-eval entry in `evals/trigger-evals.md` for routing/description changes. See
   `docs/testing.md` for which kind applies and where the evidence goes.
3. Doc-truth: any count, path, or roster claim in the changed prose must be verified against
   the actual tree before merge — grep it, don't recall it.

Skip step 2 only for changes with no behavioral or routing surface (typos, link fixes,
formatting).

### Improving Rubrics

Rubrics in `rubrics/` define quality standards for reviews. Contributions should:
- Be actionable (agents can follow them)
- Be measurable (clear pass/fail criteria)
- Not be project-specific

### Knowledge Base Templates

The `knowledge/` directory contains schema templates. Improvements to the schema, documentation, or example entries are welcome.

## Testing the Plugin

After making changes, test the plugin locally:

```bash
# Test in a fresh directory
mkdir /tmp/test-project && cd /tmp/test-project && git init

# Install your local copy as a plugin
claude plugin add /path/to/metaswarm

# In Claude Code, verify skills and commands load correctly
# Type / and check that start-task, setup, prime, etc. appear
# Run /status to verify all 9 diagnostic checks pass
```

If you're also contributing external tool adapters (Codex or the enterprise/API-key Gemini adapter), run the verification script:

```bash
bin/external-tools-verify.sh
```

## Pull Request Process

1. Fork the repository
2. Create a branch (`feat/`, `fix/`, `docs/`)
3. Make your changes
4. Test the plugin locally if you changed skills, commands, or hooks
5. Ensure all Markdown is well-formed
6. Submit a PR with a clear description

## Code of Conduct

Be respectful. Focus on the work. Assume good intent.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
