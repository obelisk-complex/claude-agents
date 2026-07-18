#!/usr/bin/env bash
# Assert the frontmatter contract from AGENT_CHECKLIST.md across the fleet.
# Run from the repo root: ./scripts/check-agent-frontmatter.sh
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
agents_dir="$repo_root/agents"

# shellcheck source=lib-frontmatter.sh
. "$repo_root/scripts/lib-frontmatter.sh"

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

# This gate needs no pinned file count. Its set is anchored from both ends: every
# agent file must have a tier-table row, and every tier-table row must match an
# agent. Deleting an agent leaves an orphan row, which is reported below.

required_fields=(name description tools permissionMode model maxTurns memory color)

# The subset of required fields that some gate actually reads as a value. These
# must parse; 'description' and 'tools' are excluded because they are legitimately
# block scalars or comma lists rather than simple scalars.
scalar_fields=(name permissionMode model maxTurns memory color)

# Bare colour names already in use in the fleet. Pinned rather than "any word" so
# that a typo is reported instead of silently accepted; extend this list
# deliberately when a genuinely new name is introduced.
bare_colors=(amber emerald gold magenta orange purple teal)

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

declare -A color_holders=()
declare -A agent_names=()

for f in "${agent_files[@]}"; do
  rel="${f#"$repo_root"/}"
  fm="$(fm_block "$f")"

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

  # A field that is present but unreadable is a hard failure, not a skip. The
  # gates downstream of this one treat an unparseable value as absent, which is
  # exactly how an agent leaves a qualifying set without anyone noticing.
  declare -A value=()
  for field in "${scalar_fields[@]}"; do
    v="$(fm_scalar "$fm" "$field")"
    case "$?" in
      0) value["$field"]="$v" ;;
      1) value["$field"]="" ;;
      2)
        echo "$rel: field '${field}' is present but not a readable scalar" >&2
        violations=$((violations + 1))
        value["$field"]=""
        ;;
    esac
  done

  model="${value[model]}"
  if [ -n "$model" ] && ! [[ "$model" =~ ^(haiku|sonnet|opus)$ ]]; then
    echo "$rel: model '${model}' is not one of haiku|sonnet|opus" >&2
    violations=$((violations + 1))
  fi

  # Every plan-mode agent must declare disallowedTools: Write, Edit.
  #
  # permissionMode: plan is a declaration of intent, not an enforcement
  # boundary: tested 2026-07-18, two plan agents created and edited files
  # successfully. disallowedTools is the documented hard block, so it is what
  # actually keeps an auditor off the tree, and an invariant across 47 files
  # with no gate is one edit away from being quietly untrue.
  #
  # It does not cover shell writes. An agent holding Bash can still redirect
  # into a file, and this gate cannot see that. Do not read a pass here as
  # proof the agent cannot write.
  perm="${value[permissionMode]}"
  if [ "$perm" = "plan" ]; then
    dis="$(fm_scalar "$fm" disallowedTools)"
    case "$?" in
      2)
        echo "$rel: 'disallowedTools' is present but not a readable scalar" >&2
        violations=$((violations + 1))
        ;;
      *)
        if ! [[ "$dis" =~ (^|[[:space:],])Write([[:space:],]|$) ]] \
          || ! [[ "$dis" =~ (^|[[:space:],])Edit([[:space:],]|$) ]]; then
          echo "$rel: permissionMode is plan but disallowedTools does not block both Write and Edit" >&2
          violations=$((violations + 1))
        fi
        ;;
    esac
  fi

  # color: was previously unvalidated while model: was, so a malformed colour
  # passed through to the uniqueness comparison as its own distinct value.
  color="${value[color]}"
  if [ -n "$color" ]; then
    ok=0
    [[ "$color" =~ ^#[0-9A-Fa-f]{6}$ ]] && ok=1
    for name in "${bare_colors[@]}"; do
      [ "$color" = "$name" ] && ok=1
    done
    if [ "$ok" -eq 0 ]; then
      echo "$rel: color '${color}' is neither a #rrggbb hex nor a known bare name" >&2
      violations=$((violations + 1))
    else
      key="$(fm_norm_color "$color")"
      color_holders["$key"]="${color_holders[$key]:-}${color_holders[$key]:+$'\n'}$rel"
    fi
  fi

  if grep -q '^mcpServers:' <<<"$fm"; then
    echo "$rel: 'mcpServers:' is banned fleet-wide" >&2
    violations=$((violations + 1))
  fi

  # Model must match the checked-in tier table, so that a change to an agent's
  # model is a deliberate edit to two files rather than a silent one.
  agent_name="${value[name]}"
  if [ -n "$agent_name" ]; then
    agent_names["$agent_name"]=1
    expected="$(awk -F'\t' -v n="$agent_name" '$1==n {print $2; exit}' "$tier_table")"
    if [ -z "$expected" ]; then
      echo "$rel: '${agent_name}' has no row in docs/model-tiers.tsv" >&2
      violations=$((violations + 1))
    elif [ "$expected" != "$model" ]; then
      echo "$rel: model '${model}' but docs/model-tiers.tsv says '${expected}'" >&2
      violations=$((violations + 1))
    fi
  else
    echo "$rel: no readable 'name:' to check against docs/model-tiers.tsv" >&2
    violations=$((violations + 1))
  fi
done

# Every tier-table row must correspond to an agent, so a renamed or deleted
# agent cannot leave a stale row behind that silently matches nothing.
while IFS=$'\t' read -r row_name _; do
  [ "$row_name" = "agent" ] && continue
  [ -z "$row_name" ] && continue
  if [ -z "${agent_names[$row_name]:-}" ]; then
    echo "docs/model-tiers.tsv: row '${row_name}' matches no agent" >&2
    violations=$((violations + 1))
  fi
done < "$tier_table"

# Colour uniqueness between distinct agent families, compared on the normalised
# value so that "#EA580C", "#ea580c" and #ea580c are one colour. Two deliberate
# patterns are exempt, because in both the shared colour carries information
# rather than hiding a clash:
#   1. A variant inherits its base agent's colour (plan-auditor and
#      opus-variants/plan-auditor-opus are one agent at two tiers).
#   2. The rt-* red-team agents share "#dc2626" as a squad colour. This is
#      deliberate, not drift - do not "fix" it by fanning them out to 12 hexes.
for key in "${!color_holders[@]}"; do
  mapfile -t holders <<<"${color_holders[$key]}"
  [ "${#holders[@]}" -lt 2 ] && continue

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

  echo "color ${key} is shared by distinct agent families: ${holders[*]}" >&2
  violations=$((violations + 1))
done

if [ "$violations" -gt 0 ]; then
  echo "FAIL: ${violations} frontmatter violation(s) across ${#agent_files[@]} agent file(s)" >&2
  exit 1
fi

echo "OK: ${#agent_files[@]} agent file(s) satisfy the frontmatter contract"
