#!/usr/bin/env bash
# Assert that every auditor agent carrying prior findings in its brief has a
# '## Prior findings in a brief' section (class-level briefing rule).
# The file set is derived from the tree by agent name, so it picks up the
# opus-variants/ and sonnet-variants/ copies without them being listed here.
# Run from anywhere: ./scripts/check-audit-briefing-rule.sh
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
agents_dir="$repo_root/agents"

# shellcheck source=lib-frontmatter.sh
. "$repo_root/scripts/lib-frontmatter.sh"

if [ ! -d "$agents_dir" ] || [ ! -r "$agents_dir" ]; then
  echo "FATAL: $agents_dir is missing or unreadable" >&2
  exit 2
fi

auditor_names=(agent-auditor blind-spot-auditor plan-auditor requirements-auditor conformance-auditor)

# Expected size of the derived set. Pinned because this gate asserts a property
# of a set it derives from the tree, and an unpinned derived set lets the gate
# report success over a set that lost a member: rename plan-auditor and delete
# its section, and the old gate printed OK at 11. Non-empty is not enough.
# Update this deliberately when an auditor or a tier variant is genuinely added
# or removed - that edit is the human review step, and is why the number is here.
expected_auditors=12

mapfile -t agent_files < <(find "$agents_dir" -name '*.md' -type f | sort)

if [ "${#agent_files[@]}" -eq 0 ]; then
  echo "FATAL: no *.md files found under $agents_dir" >&2
  exit 2
fi

audit_files=()
unparseable=0
declare -A seen_base=()

for f in "${agent_files[@]}"; do
  rel="${f#"$repo_root"/}"
  fm="$(fm_block "$f")"
  [ -z "$fm" ] && continue

  # A quoted name must not drop the file out of the set. An unreadable name is
  # reported rather than skipped, because a name this gate cannot read is a name
  # it cannot rule out of the auditor class.
  name="$(fm_scalar "$fm" name)"
  case "$?" in
    0) ;;
    1) continue ;;
    2)
      echo "$rel: 'name' is present but not a readable scalar" >&2
      unparseable=$((unparseable + 1))
      continue
      ;;
  esac

  # Variants share their base agent's name stem: plan-auditor-opus is a
  # plan-auditor at another tier and carries the same class-level rule.
  base="${name%-opus}"
  base="${base%-sonnet}"

  for a in "${auditor_names[@]}"; do
    if [ "$base" = "$a" ]; then
      audit_files+=("$rel")
      seen_base["$a"]=$(( ${seen_base[$a]:-0} + 1 ))
      break
    fi
  done
done

# A run over zero files would otherwise exit 0 and be read as a pass. If the
# name pattern stops matching, that is a broken check, not a clean fleet.
if [ "${#audit_files[@]}" -eq 0 ]; then
  echo "FATAL: no auditor agents matched under $agents_dir" >&2
  exit 2
fi

status=0

if [ "$unparseable" -gt 0 ]; then
  echo "FAIL: ${unparseable} agent(s) with an unreadable 'name'; the auditor set cannot be trusted" >&2
  status=1
fi

# Per-name coverage, so that losing one auditor and gaining a variant of another
# cannot leave the total unchanged and the loss unreported.
for a in "${auditor_names[@]}"; do
  if [ "${seen_base[$a]:-0}" -eq 0 ]; then
    echo "FAIL: no agent file found for auditor '${a}'" >&2
    status=1
  fi
done

if [ "${#audit_files[@]}" -ne "$expected_auditors" ]; then
  echo "FAIL: auditor set is ${#audit_files[@]}, expected ${expected_auditors}; if this change is intended, update expected_auditors in $0" >&2
  status=1
fi

missing=0
for rel in "${audit_files[@]}"; do
  if ! grep -q '^## Prior findings in a brief[[:space:]]*$' "$repo_root/$rel"; then
    echo "$rel: no '## Prior findings in a brief' section" >&2
    missing=$((missing + 1))
  fi
done

if [ "$missing" -gt 0 ]; then
  echo "FAIL: ${missing} of ${#audit_files[@]} auditor(s) missing '## Prior findings in a brief'" >&2
  status=1
fi

[ "$status" -ne 0 ] && exit 1

echo "OK: all ${#audit_files[@]} auditor(s) carry '## Prior findings in a brief'"
