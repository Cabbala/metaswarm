#!/usr/bin/env bash
# test-codex-manifest.sh — Codex plugin manifest hook-suppression guard (W3, design D4).
#
# Codex auto-discovers hooks/hooks.json (the Claude Code SessionStart hook this repo
# ships) unless the manifest declares an explicit EMPTY OBJECT `"hooks": {}`.
# An ABSENT field, `[]`, and an empty inline list all fall back to auto-discovery
# (superpowers v6.1.1 shipped this exact fix + regression test after a live
# double-registration bug). LIVE unique-marker test (2026-07-10, codex-cli 0.144.0,
# codex exec sessions, instrumented cache install): the Claude hook did NOT execute
# with "hooks": {} present NOR with the key absent — 0.144 does not auto-discover
# plugin hooks in exec sessions on this machine. The guard is therefore
# defense-in-depth matching upstream superpowers v6.1.1 (whose tested Codex version
# DID auto-discover); interactive-TUI sessions were not instrumented.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$REPO_ROOT/.codex-plugin/plugin.json"

PASS=0
FAIL=0

check() {
  local desc="$1" ok="$2"
  if [[ "$ok" == "0" ]]; then
    echo "  ok: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# hooks_is_exactly_empty_object <file> -> exit 0 only for "hooks": {}
hooks_is_exactly_empty_object() {
  node -e '
    const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const h = m.hooks;
    const ok = h !== undefined && h !== null && !Array.isArray(h)
      && typeof h === "object" && Object.keys(h).length === 0;
    process.exit(ok ? 0 : 1);
  ' "$1"
}

echo "Test 1: real manifest parses as JSON"
node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$MANIFEST" \
  && check "plugin.json is valid JSON" 0 || check "plugin.json is valid JSON" 1

echo "Test 2: real manifest declares hooks as EXACTLY {}"
hooks_is_exactly_empty_object "$MANIFEST" \
  && check 'hooks field is the exact literal {}' 0 || check 'hooks field is the exact literal {}' 1

echo "Test 3: guard rejects the dangerous variants (fixture red-tests)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
node -e '
  const fs = require("fs");
  const base = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  const t = process.argv[2];
  const absent = { ...base }; delete absent.hooks;
  fs.writeFileSync(t + "/absent.json", JSON.stringify(absent));
  fs.writeFileSync(t + "/list.json", JSON.stringify({ ...base, hooks: [] }));
  fs.writeFileSync(t + "/nonempty.json",
    JSON.stringify({ ...base, hooks: { SessionStart: [{ command: "x" }] } }));
' "$MANIFEST" "$TMP"
for variant in absent list nonempty; do
  if hooks_is_exactly_empty_object "$TMP/$variant.json"; then
    check "guard rejects '$variant' hooks variant" 1
  else
    check "guard rejects '$variant' hooks variant" 0
  fi
done

echo "Test 4: EVERY shipped hook command remains Claude-scoped"
node -e '
  const h = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  const cmds = [];
  const walk = (o) => { if (o && typeof o === "object") {
    if (typeof o.command === "string") cmds.push(o.command);
    for (const v of Object.values(o)) walk(v); } };
  walk(h);
  const ok = cmds.length > 0 && cmds.every(c => c.includes("${CLAUDE_PLUGIN_ROOT}"));
  console.error(`hook commands: ${cmds.length}, claude-scoped: ${cmds.filter(c => c.includes("${CLAUDE_PLUGIN_ROOT}")).length}`);
  process.exit(ok ? 0 : 1);
' "$REPO_ROOT/hooks/hooks.json" \
  && check "ALL hook commands target CLAUDE_PLUGIN_ROOT (Claude-only wiring)" 0 \
  || check "ALL hook commands target CLAUDE_PLUGIN_ROOT (Claude-only wiring)" 1

echo "Test 5: Codex-side session parity lives in the AGENTS templates (all three items)"
for f in "$REPO_ROOT/templates/AGENTS-append.md" "$REPO_ROOT/templates/AGENTS.md"; do
  b="$(basename "$f")"
  grep -q 'First step of EVERY session.*`bd prime`' "$f" \
    && check "$b: bd prime first-step directive" 0 || check "$b: bd prime first-step directive" 1
  grep -qi 'compaction' "$f" && grep -q 're-run `bd prime`' "$f" \
    && check "$b: re-run-after-compaction directive" 0 || check "$b: re-run-after-compaction directive" 1
  grep -qi 'skills check' "$f" && grep -qi 'skill applies' "$f" \
    && check "$b: unconditional skills-check nudge" 0 || check "$b: unconditional skills-check nudge" 1
done

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
