#!/usr/bin/env bash
# Assert that every agent meeting the mandatory threshold in REPORT_PROTOCOL.md
# carries a '## Report file' section.
# Run from the repo root: ./scripts/check-report-protocol.sh
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
agents_dir="$repo_root/agents"

# shellcheck source=lib-frontmatter.sh
. "$repo_root/scripts/lib-frontmatter.sh"

if [ ! -d "$agents_dir" ] || [ ! -r "$agents_dir" ]; then
  echo "FATAL: $agents_dir is missing or unreadable" >&2
  exit 2
fi

# Expected size of the qualifying set. Pinned because this gate asserts a
# property of a derived set, and without a pinned size it happily asserts that
# property over a set that has lost members: rename an agent out of the set and
# the gate still prints OK, over a smaller set. Non-empty is not enough. Update
# this deliberately when the fleet genuinely gains or loses a qualifying agent -
# that edit is the human review step, and is the reason the number is here.
#
# Derived from capability, not from whatever the tree currently fails on: 19 is
# the count of agents holding both Write and Edit. Re-pinning this off a failing
# run would bake the failures in as accepted.
expected_qualifying=19

mapfile -t agent_files < <(find "$agents_dir" -name '*.md' -type f | sort)

# A run over zero files would otherwise exit 0 and be read as a pass.
if [ "${#agent_files[@]}" -eq 0 ]; then
  echo "FATAL: no *.md files found under $agents_dir" >&2
  exit 2
fi

qualifying=0
missing=0
inert=0
unparseable=0

for f in "${agent_files[@]}"; do
  rel="${f#"$repo_root"/}"
  fm="$(fm_block "$f")"

  # An unreadable value must never be treated as absent: that is how an agent
  # leaves the qualifying set silently. `maxTurns: "30"` used to parse as empty
  # here, and check-agent-frontmatter.sh does not report it either, because the
  # field is present - it only reports a field that is missing outright. So a
  # quoted value fell through both gates. Both now fail on it.
  max_turns="$(fm_scalar "$fm" maxTurns)"
  case "$?" in
    0) ;;
    1) max_turns="" ;;
    2)
      echo "$rel: 'maxTurns' is present but not a readable scalar" >&2
      unparseable=$((unparseable + 1))
      max_turns=""
      ;;
  esac

  if [ -n "$max_turns" ] && ! [[ "$max_turns" =~ ^[0-9]+$ ]]; then
    echo "$rel: 'maxTurns' value '${max_turns}' is not an integer" >&2
    unparseable=$((unparseable + 1))
    max_turns=""
  fi

  tools="$(fm_scalar "$fm" tools)"
  case "$?" in
    0) ;;
    1) tools="" ;;
    2)
      echo "$rel: 'tools' is present but not a readable scalar" >&2
      unparseable=$((unparseable + 1))
      tools=""
      ;;
  esac

  # Capability, not run length. maxTurns stopped discriminating once the fleet
  # was raised to 75+ (it then selected 65 of 66 agents), and it never measured
  # the thing that matters: an agent without Write cannot create the skeleton
  # and one without Edit cannot append a finding, so the section is inert from
  # its first line. The protocol applies to agents that can actually honour it.
  qualifies=0
  if [[ "$tools" =~ (^|[[:space:],])Write([[:space:],]|$) ]] \
    && [[ "$tools" =~ (^|[[:space:],])Edit([[:space:],]|$) ]]; then
    qualifies=1
  fi

  has_section=0
  grep -q '^## Report file[[:space:]]*$' "$f" && has_section=1

  if [ "$qualifies" -eq 1 ]; then
    qualifying=$((qualifying + 1))
    if [ "$has_section" -eq 0 ]; then
      echo "$rel: holds Write and Edit but has no '## Report file' section" >&2
      missing=$((missing + 1))
    fi
  elif [ "$has_section" -eq 1 ]; then
    # The reverse defect, and the one that shipped: 36 agents carried this
    # section without the tools to honour it, and the gate passed them because
    # it only checked that the text was present.
    echo "$rel: carries '## Report file' but lacks Write and/or Edit, so it cannot honour it" >&2
    inert=$((inert + 1))
  fi
done

status=0

if [ "$unparseable" -gt 0 ]; then
  echo "FAIL: ${unparseable} unreadable frontmatter value(s); the qualifying set cannot be trusted" >&2
  status=1
fi

if [ "$qualifying" -ne "$expected_qualifying" ]; then
  echo "FAIL: qualifying set is ${qualifying}, expected ${expected_qualifying}; if this change is intended, update expected_qualifying in $0" >&2
  status=1
fi

if [ "$missing" -gt 0 ]; then
  echo "FAIL: ${missing} of ${qualifying} qualifying agent(s) missing '## Report file' (see REPORT_PROTOCOL.md)" >&2
  status=1
fi

if [ "$inert" -gt 0 ]; then
  echo "FAIL: ${inert} agent(s) carry '## Report file' without the tools to honour it" >&2
  status=1
fi

[ "$status" -ne 0 ] && exit 1

echo "OK: all ${qualifying} qualifying agent(s) carry '## Report file'"
