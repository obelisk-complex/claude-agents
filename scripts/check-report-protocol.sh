#!/usr/bin/env bash
# Assert that every agent meeting the mandatory threshold in REPORT_PROTOCOL.md
# carries a '## Report file' section.
# Run from the repo root: ./scripts/check-report-protocol.sh
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
agents_dir="$repo_root/agents"

if [ ! -d "$agents_dir" ] || [ ! -r "$agents_dir" ]; then
  echo "FATAL: $agents_dir is missing or unreadable" >&2
  exit 2
fi

mapfile -t agent_files < <(find "$agents_dir" -name '*.md' -type f | sort)

# A run over zero files would otherwise exit 0 and be read as a pass.
if [ "${#agent_files[@]}" -eq 0 ]; then
  echo "FATAL: no *.md files found under $agents_dir" >&2
  exit 2
fi

frontmatter() {
  awk 'NR==1 && $0!="---" {exit} NR==1 {next} $0=="---" {exit} {print}' "$1"
}

qualifying=0
missing=0

for f in "${agent_files[@]}"; do
  rel="${f#"$repo_root"/}"
  fm="$(frontmatter "$f")"

  max_turns="$(grep -m1 '^maxTurns:' <<<"$fm" | sed 's/^maxTurns:[[:space:]]*//; s/[^0-9].*$//')"
  perm="$(grep -m1 '^permissionMode:' <<<"$fm" | sed 's/^permissionMode:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//')"

  # An agent with no parseable maxTurns does not qualify on that criterion;
  # check-agent-frontmatter.sh is what reports the missing field.
  qualifies=0
  [ -n "$max_turns" ] && [ "$max_turns" -ge 30 ] && qualifies=1
  [ "$perm" = "acceptEdits" ] && qualifies=1
  [ "$qualifies" -eq 1 ] || continue

  qualifying=$((qualifying + 1))
  if ! grep -q '^## Report file[[:space:]]*$' "$f"; then
    echo "$rel: qualifies (maxTurns=${max_turns:-none}, permissionMode=${perm:-none}) but has no '## Report file' section" >&2
    missing=$((missing + 1))
  fi
done

if [ "$missing" -gt 0 ]; then
  echo "FAIL: ${missing} of ${qualifying} qualifying agent(s) missing '## Report file' (see REPORT_PROTOCOL.md)" >&2
  exit 1
fi

echo "OK: all ${qualifying} qualifying agent(s) carry '## Report file'"
