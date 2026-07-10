# External Tools Health Check

Check the status of external AI tools: Codex CLI and the enterprise/API-key-only Gemini adapter (consumer CLI discontinued 2026-06-18).

## Usage

```text
/external-tools-health
```

## Steps

1. **Check adapter availability**:
   ```bash
   command -v codex >/dev/null 2>&1 && echo "codex: available" || echo "codex: not found"
   skills/external-tools/adapters/gemini.sh health
   ```

2. **Check configuration**: Read `.metaswarm/external-tools.yaml` if it exists. Report which adapters are enabled/disabled.

3. **Run verification scripts** (if available):
   ```bash
   bash bin/external-tools-verify.sh
   ```

4. **Report status**: Summary table showing each tool's install status, configuration, and reachability.

## Related

- `skills/external-tools/SKILL.md` — the external tools delegation skill
- `.metaswarm/external-tools.yaml` — configuration file
- `bin/external-tools-verify.sh` — verification script
