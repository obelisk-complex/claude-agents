#!/usr/bin/env bash
# Assert the frontmatter contract from AGENT_CHECKLIST.md across the fleet.
# Run from the repo root: ./scripts/check-agent-frontmatter.sh
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
agents_dir="$repo_root/agents"

if [ ! -d "$agents_dir" ] || [ ! -r "$agents_dir" ]; then
  echo "FATAL: $agents_dir is missing or unreadable" >&2
  exit 2
fi

tier_table="$repo_root/docs/model-tiers.tsv"

if [ ! -r "$tier_table" ]; then
  echo "FATAL: $tier_table is missing or unreadable" >&2
  exit 2
fi

mapfile -t agent_files < <(find "$agents_dir" -name '*.md' -type f | sort)

# A run over zero files would otherwise exit 0 and be read as a pass.
if [ "${#agent_files[@]}" -eq 0 ]; then
  echo "FATAL: no *.md files found under $agents_dir" >&2
  exit 2
fi

required_fields=(name description tools permissionMode model maxTurns memory color)
violations=0

# Base agent name: opus-variants/X-opus.md and sonnet-variants/X-sonnet.md both
# reduce to X, so a variant sharing its base agent's colour is not a collision.
base_agent_name() {
  local rel="${1#agents/}"
  rel="$(basename "$rel" .md)"
  rel="${rel%-opus}"
  rel="${rel%-sonnet}"
  printf '%s' "$rel"
}

frontmatter() {
  # Print the YAML block between the first pair of --- delimiters.
  awk 'NR==1 && $0!="---" {exit} NR==1 {next} $0=="---" {exit} {print}' "$1"
}

for f in "${agent_files[@]}"; do
  rel="${f#"$repo_root"/}"
  fm="$(frontmatter "$f")"

  if [ -z "$fm" ]; then
    echo "$rel: no YAML frontmatter block" >&2
    violations=$((violations + 1))
    continue
  fi

  for field in "${required_fields[@]}"; do
    if ! grep -q "^${field}:" <<<"$fm"; then
      echo "$rel: missing required field '${field}'" >&2
      violations=$((violations + 1))
    fi
  done

  model="$(grep -m1 '^model:' <<<"$fm" | sed 's/^model:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//')"
  if [ -n "$model" ] && ! [[ "$model" =~ ^(haiku|sonnet|opus)$ ]]; then
    echo "$rel: model '${model}' is not one of haiku|sonnet|opus" >&2
    violations=$((violations + 1))
  fi

  if grep -q '^mcpServers:' <<<"$fm"; then
    echo "$rel: 'mcpServers:' is banned fleet-wide" >&2
    violations=$((violations + 1))
  fi

  # Model must match the checked-in tier table, so that a change to an agent's
  # model is a deliberate edit to two files rather than a silent one.
  agent_name="$(grep -m1 '^name:' <<<"$fm" | sed 's/^name:[[:space:]]*//; s/[[:space:]]*$//')"
  if [ -n "$agent_name" ]; then
    expected="$(awk -F'\t' -v n="$agent_name" '$1==n {print $2; exit}' "$tier_table")"
    if [ -z "$expected" ]; then
      echo "$rel: '${agent_name}' has no row in docs/model-tiers.tsv" >&2
      violations=$((violations + 1))
    elif [ "$expected" != "$model" ]; then
      echo "$rel: model '${model}' but docs/model-tiers.tsv says '${expected}'" >&2
      violations=$((violations + 1))
    fi
  fi
done

# Every tier-table row must correspond to an agent, so a renamed or deleted
# agent cannot leave a stale row behind that silently matches nothing.
while IFS=$'\t' read -r row_name _; do
  [ "$row_name" = "agent" ] && continue
  [ -z "$row_name" ] && continue
  if ! grep -rqx "name: ${row_name}" "$agents_dir"; then
    echo "docs/model-tiers.tsv: row '${row_name}' matches no agent" >&2
    violations=$((violations + 1))
  fi
done < "$tier_table"

# Colour uniqueness between distinct agent families. Two deliberate patterns are
# exempt, because in both the shared colour carries information rather than
# hiding a clash:
#   1. A variant inherits its base agent's colour (plan-auditor and
#      opus-variants/plan-auditor-opus are one agent at two tiers).
#   2. The rt-* red-team agents share "#dc2626" as a squad colour. This is
#      deliberate, not drift - do not "fix" it by fanning them out to 12 hexes.
dupes="$(grep -rh '^color:' "$agents_dir" | sed 's/[[:space:]]*$//' | sort | uniq -d)"
if [ -n "$dupes" ]; then
  while IFS= read -r line; do
    value="${line#color:}"
    value="$(sed 's/^[[:space:]]*//' <<<"$value")"
    mapfile -t holders < <(grep -rl "^color:[[:space:]]*${value}[[:space:]]*$" "$agents_dir" \
      | sed "s|^${repo_root}/||" | sort)

    bases=()
    all_rt=1
    for h in "${holders[@]}"; do
      b="$(base_agent_name "$h")"
      bases+=("$b")
      [[ "$b" == rt-* ]] || all_rt=0
    done
    distinct_bases="$(printf '%s\n' "${bases[@]}" | sort -u | wc -l)"

    if [ "$distinct_bases" -eq 1 ] || [ "$all_rt" -eq 1 ]; then
      continue
    fi

    echo "color ${value} is shared by distinct agent families: ${holders[*]}" >&2
    violations=$((violations + 1))
  done <<<"$dupes"
fi

if [ "$violations" -gt 0 ]; then
  echo "FAIL: ${violations} frontmatter violation(s) across ${#agent_files[@]} agent file(s)" >&2
  exit 1
fi

echo "OK: ${#agent_files[@]} agent file(s) satisfy the frontmatter contract"
