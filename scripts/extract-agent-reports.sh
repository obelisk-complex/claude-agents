#!/usr/bin/env bash
# Extract each subagent's findings from its persisted transcript into a readable
# report, so an orchestrator can keep the findings without reading them into its
# own context: run this, then read only the reports that matter.
#
# The harness already writes every subagent's full transcript to
#   ~/.claude/projects/<project-slug>/<session-id>/subagents/agent-<id>.jsonl
# with a sidecar agent-<id>.meta.json. Durability is therefore already provided;
# what this adds is structure and a findable path.
#
# Usage: ./scripts/extract-agent-reports.sh [-o OUTDIR] [-s SESSION_ID] [TRANSCRIPT_DIR]
set -uo pipefail

out_dir=".agent-reports"
session_id="${CLAUDE_CODE_SESSION_ID:-}"
transcript_dir=""

usage() {
  cat <<'EOF'
Usage: extract-agent-reports.sh [-o OUTDIR] [-s SESSION_ID] [TRANSCRIPT_DIR]

  -o OUTDIR        where to write reports (default: .agent-reports)
  -s SESSION_ID    session to extract (default: $CLAUDE_CODE_SESSION_ID, else
                   the most recently modified session for this project)
  TRANSCRIPT_DIR   explicit path to a subagents/ directory; overrides -s

Writes OUTDIR/<agent-name>.md per subagent plus OUTDIR/INDEX.md.
Exits non-zero if no transcripts are found.
EOF
}

while getopts ":o:s:h" opt; do
  case "$opt" in
    o) out_dir="$OPTARG" ;;
    s) session_id="$OPTARG" ;;
    h) usage; exit 0 ;;
    \?) echo "FATAL: unknown option -$OPTARG" >&2; usage >&2; exit 2 ;;
    :) echo "FATAL: -$OPTARG needs a value" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
[ "$#" -gt 0 ] && transcript_dir="$1"

command -v jq >/dev/null 2>&1 || { echo "FATAL: jq is required but not on PATH" >&2; exit 2; }

projects_root="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"

# The harness slug is the working directory with every character outside
# [A-Za-z0-9] replaced by '-'. Derived, not hardcoded, so this works in any repo.
project_slug="$(pwd | sed 's/[^A-Za-z0-9]/-/g')"

if [ -z "$transcript_dir" ]; then
  project_dir="$projects_root/$project_slug"
  if [ ! -d "$project_dir" ]; then
    echo "FATAL: no transcripts for this project: $project_dir does not exist" >&2
    echo "       (derived from cwd $(pwd); pass TRANSCRIPT_DIR to override)" >&2
    exit 1
  fi
  if [ -n "$session_id" ]; then
    transcript_dir="$project_dir/$session_id/subagents"
  else
    # Fall back to the most recently modified session that actually has
    # subagent transcripts, rather than the newest session outright.
    transcript_dir="$(find "$project_dir" -mindepth 2 -maxdepth 2 -type d -name subagents \
      -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
    if [ -z "$transcript_dir" ]; then
      echo "FATAL: no session under $project_dir has a subagents/ directory" >&2
      exit 1
    fi
    echo "note: no session id given; using $(basename "$(dirname "$transcript_dir")")" >&2
  fi
fi

if [ ! -d "$transcript_dir" ] || [ ! -r "$transcript_dir" ]; then
  echo "FATAL: transcript directory is missing or unreadable: $transcript_dir" >&2
  exit 1
fi

mapfile -t transcripts < <(find "$transcript_dir" -maxdepth 1 -name 'agent-*.jsonl' -type f | sort)

# A run over zero transcripts must not exit 0. Silently writing nothing and
# reporting success is the failure mode this fleet keeps finding elsewhere.
if [ "${#transcripts[@]}" -eq 0 ]; then
  echo "FATAL: no agent-*.jsonl transcripts in $transcript_dir" >&2
  exit 1
fi

mkdir -p "$out_dir" || { echo "FATAL: cannot create $out_dir" >&2; exit 2; }

# One jq program per transcript. It emits a JSON object of extracted fields;
# the shell formats the markdown. Record shapes it relies on:
#   - every record has .type ("user" | "assistant" | "attachment") and .isSidechain
#   - .message.content is a list of blocks (or a bare string on the dispatch
#     prompt), each block having .type of text | tool_use | tool_result
#   - tool results come back as .type=="user" records carrying .toolUseResult
#   - harness-injected context is .type=="user" with .isMeta==true
#   - the last assistant record's .message.stop_reason is the completion signal
read -r -d '' extract_program <<'JQ'
def blocktext:
  if type == "string" then .
  else [ .[] | select(type == "object" and .type == "text") | .text ] | join("\n")
  end;

# Records, minus the attachment entries which carry no message.
[ inputs | select(.message != null) ] as $recs
| [ $recs[] | select(.type == "assistant") ] as $asst
# Bound as an array, not a stream: a stream binding would re-emit the whole
# object once per matching record.
| [ $recs[] | select(.type == "user" and (.isMeta != true) and (.toolUseResult == null))
    | .message.content | blocktext ] as $prompts
| ( $asst | last ) as $final
| ( $recs | last ) as $tail
| ( [ $asst[] | .message.content[]?
      | select(type == "object" and .type == "tool_use" and .name == "SendMessage") ]
    | last ) as $sent
| {
    agent_id:     ( $recs[0].agentId // "" ),
    session_id:   ( $recs[0].sessionId // "" ),
    cwd:          ( $recs[0].cwd // "" ),
    first_ts:     ( $recs[0].timestamp // "" ),
    last_ts:      ( ($tail // {}) | .timestamp // "" ),
    records:      ( $recs | length ),
    assistant_turns: ( $asst | length ),
    prompt:       ( $prompts | first // "" ),
    stop_reason:  ( ($final // {}) | .message.stop_reason // null ),
    tail_type:    ( ($tail // {}) | .type // "" ),
    tail_is_tool_result: ( ($tail // {}) | (.toolUseResult != null) ),
    final_text:   ( if $final == null then "" else ($final.message.content | blocktext) end ),
    sent_to:      ( ($sent // {}) | .input.to // "" ),
    sent_message: ( ($sent // {}) | .input.message // .input.content // "" )
  }
JQ

# now_epoch lets us separate "stopped mid-pass" from "still running", which
# otherwise look identical: both end on an unanswered tool call.
now_epoch="$(date +%s)"
running_window=180

index_rows=()
written=0
complete_n=0
incomplete_n=0
empty_n=0

for t in "${transcripts[@]}"; do
  base="$(basename "$t" .jsonl)"
  agent_id="${base#agent-}"
  meta="${t%.jsonl}.meta.json"

  data="$(jq -n -c "$extract_program" < "$t" 2>/dev/null)"
  if [ -z "$data" ]; then
    echo "warn: could not parse $t; skipping" >&2
    continue
  fi

  get() { printf '%s' "$data" | jq -r --arg k "$1" '.[$k] // ""'; }

  # Identity: the meta sidecar names teammate-style agents; classic Task-spawned
  # agents only carry agentType. Fall back to the transcript id so a report is
  # never anonymous.
  agent_name=""; agent_type=""; model=""; description=""
  if [ -r "$meta" ]; then
    agent_name="$(jq -r '.name // ""' "$meta" 2>/dev/null)"
    agent_type="$(jq -r '.agentType // ""' "$meta" 2>/dev/null)"
    model="$(jq -r '.model // ""' "$meta" 2>/dev/null)"
    description="$(jq -r '.description // ""' "$meta" 2>/dev/null)"
  fi
  label="${agent_name:-${agent_type:-$agent_id}}"
  # Keep the id in the filename when the name is not unique to one transcript.
  slug="$(printf '%s' "$label" | sed 's/[^A-Za-z0-9._-]/-/g')"
  target="$out_dir/$slug.md"
  if [ -e "$target" ] && ! grep -qxF "<!-- agent-id: $agent_id -->" "$target" 2>/dev/null; then
    target="$out_dir/$slug-$agent_id.md"
  fi

  stop_reason="$(get stop_reason)"
  tail_type="$(get tail_type)"
  tail_is_tool_result="$(get tail_is_tool_result)"
  final_text="$(get final_text)"
  assistant_turns="$(get assistant_turns)"
  last_ts="$(get last_ts)"

  # Is the transcript still growing? mtime is the only signal available from
  # outside the run, so it is reported as a possibility, never as a fact.
  mtime="$(stat -c %Y "$t" 2>/dev/null || echo 0)"
  fresh=0
  [ $((now_epoch - mtime)) -lt "$running_window" ] && fresh=1

  # Completion state. A report from a dead run must be visibly different from a
  # clean one, so every branch below names what actually happened.
  case "$stop_reason" in
    end_turn)
      state="COMPLETE"
      state_note="Agent ended its turn normally (stop_reason: end_turn)."
      ;;
    max_tokens)
      state="TRUNCATED"
      state_note="Agent hit the output token limit mid-message (stop_reason: max_tokens). The findings below are cut off."
      ;;
    tool_use|pause_turn)
      if [ "$tail_is_tool_result" = "true" ]; then
        where="on a tool result the agent never acted on"
      else
        where="on a tool call that never returned"
      fi
      if [ "$fresh" -eq 1 ]; then
        state="IN PROGRESS"
        state_note="Transcript ends $where and was modified $((now_epoch - mtime))s ago, so this agent is probably still running. Re-run this script once it finishes."
      else
        state="INCOMPLETE"
        state_note="Transcript ends $where (stop_reason: $stop_reason) with no write since $last_ts. The agent stopped mid-pass; it did not deliver a final answer."
      fi
      ;;
    ""|null)
      if [ "$assistant_turns" -eq 0 ]; then
        state="NO OUTPUT"
        state_note="The transcript contains no assistant message at all. The agent produced nothing; this is not the same as an agent that ran and found nothing."
      elif [ "$tail_type" = "user" ] || [ "$tail_is_tool_result" = "true" ]; then
        state="INCOMPLETE"
        state_note="Transcript ends on a tool result the agent never responded to. The agent stopped mid-pass."
      elif [ -n "$final_text" ]; then
        state="COMPLETE (UNCONFIRMED)"
        state_note="The final assistant message is present and the transcript ends on it, but no stop_reason was recorded, so a clean finish cannot be confirmed from the transcript."
      else
        state="INCOMPLETE"
        state_note="No stop_reason and no final assistant text. The agent stopped mid-pass."
      fi
      ;;
    *)
      state="UNKNOWN ($stop_reason)"
      state_note="Unrecognised stop_reason '$stop_reason'. Treat this run as unverified."
      ;;
  esac

  case "$state" in
    COMPLETE*) complete_n=$((complete_n + 1)) ;;
    "NO OUTPUT") empty_n=$((empty_n + 1)) ;;
    *) incomplete_n=$((incomplete_n + 1)) ;;
  esac

  # Write to a temp file and move into place: a re-run that dies halfway must
  # not leave a half-written report looking like a real one.
  tmp="$target.tmp.$$"
  {
    printf '<!-- agent-id: %s -->\n' "$agent_id"
    printf '# %s\n\n' "$label"
    printf '**Status: %s**\n\n' "$state"
    printf '%s\n\n' "$state_note"
    printf '| field | value |\n|---|---|\n'
    printf '| agent id | `%s` |\n' "$agent_id"
    [ -n "$agent_type" ] && printf '| agent type | `%s` |\n' "$agent_type"
    [ -n "$model" ] && printf '| model | `%s` |\n' "$model"
    [ -n "$description" ] && printf '| description | %s |\n' "$description"
    printf '| session | `%s` |\n' "$(get session_id)"
    printf '| assistant turns | %s |\n' "$assistant_turns"
    printf '| first / last record | %s / %s |\n' "$(get first_ts)" "$last_ts"
    printf '| transcript | `%s` |\n' "$t"
    printf '\n## Dispatch prompt\n\n'
    prompt="$(get prompt)"
    if [ -n "$prompt" ]; then
      printf '%s\n' "$prompt"
    else
      printf '_No dispatch prompt found in the transcript._\n'
    fi

    sent_message="$(get sent_message)"
    if [ -n "$sent_message" ]; then
      printf '\n## Reported to `%s` via SendMessage\n\n' "$(get sent_to)"
      printf '%s\n' "$sent_message"
    fi

    printf '\n## Final assistant message\n\n'
    if [ -n "$final_text" ]; then
      printf '%s\n' "$final_text"
    elif [ "$assistant_turns" -eq 0 ]; then
      printf '_The agent produced no assistant message at all._\n'
    else
      printf '_The agent produced no final assistant text: its last turn was a tool call, not an answer._\n'
    fi
  } > "$tmp" && mv -f "$tmp" "$target" || {
    rm -f "$tmp"
    echo "warn: failed to write $target" >&2
    continue
  }

  written=$((written + 1))
  index_rows+=("| [$label]($(basename "$target")) | $state | $assistant_turns | $last_ts |")
  unset -f get
done

if [ "$written" -eq 0 ]; then
  echo "FATAL: found ${#transcripts[@]} transcript(s) but wrote no reports" >&2
  exit 1
fi

index="$out_dir/INDEX.md"
tmp="$index.tmp.$$"
{
  printf '# Subagent reports\n\n'
  printf 'Extracted from `%s`\n' "$transcript_dir"
  printf 'at %s.\n\n' "$(date -Is)"
  printf '%s complete, %s incomplete or in progress, %s with no output.\n\n' \
    "$complete_n" "$incomplete_n" "$empty_n"
  printf '| agent | status | turns | last record |\n|---|---|---|---|\n'
  printf '%s\n' "${index_rows[@]}"
} > "$tmp" && mv -f "$tmp" "$index"

echo "wrote $written report(s) to $out_dir ($complete_n complete, $incomplete_n incomplete/running, $empty_n empty)"
