# External Tools Health Check

Run health checks on all configured external AI tools and report their status.

## Steps

1. Run `skills/external-tools/adapters/codex.sh health` and capture JSON output
2. Run the enterprise/API-key-only Gemini adapter (consumer CLI discontinued 2026-06-18): `skills/external-tools/adapters/gemini.sh health`; capture the resolved binary path and version output
3. Report status of each tool (ready/unavailable) with version and auth info
4. If any tools are unavailable, suggest setup steps from `templates/external-tools-setup.md`
5. Check for `.metaswarm/external-tools.yaml` config file — report if present and summarize settings
