#!/usr/bin/env bash
# Assert that every auditor agent carrying prior findings in its brief has a
# '## Prior findings in a brief' section (class-level briefing rule).
# The file set is derived from the tree by agent name, so it picks up the
# opus-variants/ and sonnet-variants/ copies without them being listed here.
# Run from anywhere: ./scripts/check-audit-briefing-rule.sh
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
agents_dir="$repo_root/agents"

if [ ! -d "$agents_dir" ] || [ ! -r "$agents_dir" ]; then
  echo "FATAL: $agents_dir is missing or unreadable" >&2
  exit 2
fi

mapfile -t audit_files < <(
  grep -rl '^name: \(agent-auditor\|blind-spot-auditor\|plan-auditor\|requirements-auditor\|conformance-auditor\)' \
    "$agents_dir" | sort
)

# A run over zero files would otherwise exit 0 and be read as a pass. If the
# name pattern stops matching, that is a broken check, not a clean fleet.
if [ "${#audit_files[@]}" -eq 0 ]; then
  echo "FATAL: no auditor agents matched under $agents_dir" >&2
  exit 2
fi

missing=0

for f in "${audit_files[@]}"; do
  rel="${f#"$repo_root"/}"
  if ! grep -q '^## Prior findings in a brief[[:space:]]*$' "$f"; then
    echo "$rel: no '## Prior findings in a brief' section" >&2
    missing=$((missing + 1))
  fi
done

if [ "$missing" -gt 0 ]; then
  echo "FAIL: ${missing} of ${#audit_files[@]} auditor(s) missing '## Prior findings in a brief'" >&2
  exit 1
fi

echo "OK: all ${#audit_files[@]} auditor(s) carry '## Prior findings in a brief'"
