#!/usr/bin/env bash
# Shared YAML-frontmatter parsing for the gate scripts in this directory.
# Sourced, never executed directly.
#
# The point of this file is that all three gates read a frontmatter value the
# same way. Each gate previously carried its own sed one-liner anchored to one
# spelling of the input, so `maxTurns: "30"` parsed as empty and the agent
# dropped out of the qualifying set without anything being reported. A value a
# gate cannot read must never be treated as absent, so fm_scalar distinguishes
# the two cases and callers are expected to fail loudly on the second.

# Print the YAML block between the first pair of --- delimiters.
fm_block() {
  awk 'NR==1 && $0!="---" {exit} NR==1 {next} $0=="---" {exit} {print}' "$1"
}

# fm_scalar BLOCK FIELD
# Print the field's value with surrounding whitespace, matching quotes and any
# trailing comment removed.
#   exit 0 - parsed, value on stdout
#   exit 1 - field absent
#   exit 2 - field present but not a readable scalar (empty, unterminated
#            quote, or a block scalar such as `description: >`)
fm_scalar() {
  local fm="$1" field="$2" line v
  line="$(grep -m1 "^${field}:" <<<"$fm")"
  [ -z "$line" ] && return 1

  v="${line#*:}"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"

  case "$v" in
    '"'*)
      v="${v#\"}"
      case "$v" in
        *'"'*) v="${v%%\"*}" ;;
        *) return 2 ;;
      esac
      ;;
    "'"*)
      v="${v#\'}"
      case "$v" in
        *"'"*) v="${v%%\'*}" ;;
        *) return 2 ;;
      esac
      ;;
    '' | '>' | '|' | '>-' | '|-' | '>+' | '|+')
      return 2
      ;;
    *)
      # Unquoted. Strip a trailing comment, but only where the '#' follows
      # whitespace, so that a bare hex colour survives.
      v="${v%%[[:space:]]#*}"
      v="${v%"${v##*[![:space:]]}"}"
      ;;
  esac

  printf '%s' "$v"
}

# Normalise a colour for comparison: a hex value folds to lowercase, so that
# "#EA580C" and "#ea580c" are one colour rather than two. Quote stripping has
# already happened in fm_scalar, so quoted and unquoted spellings of the same
# value also converge here.
fm_norm_color() {
  local v="$1"
  case "$v" in
    '#'*) printf '%s' "$(tr '[:upper:]' '[:lower:]' <<<"$v")" ;;
    *) printf '%s' "$v" ;;
  esac
}
