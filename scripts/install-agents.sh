#!/usr/bin/env bash
# Install/sync this repo's agent definitions into an installed agents tree.
# The repo is the source of truth: every *.md under agents/ (including the
# opus-variants/ and sonnet-variants/ subdirs) is copied to the matching path
# under TARGET_DIR. Files present only in the target (e.g. a locally installed
# house-researcher.md, or an ollama/ subtree) are never touched and never
# deleted; this script only ever creates or overwrites a file that has a repo
# counterpart. Use --dry-run to preview.
#
# Run from anywhere: ./scripts/install-agents.sh [--dry-run] [TARGET_DIR]
#   TARGET_DIR defaults to ${HOME}/.claude/agents when omitted.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="$repo_root/agents"

dry_run=0
target_dir=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1; shift ;;
    --) shift; break ;;
    -*)
      echo "FATAL: unknown option: $1" >&2
      exit 2
      ;;
    *)
      if [ -z "$target_dir" ]; then
        target_dir="$1"
        shift
      else
        echo "FATAL: unexpected extra argument: $1" >&2
        exit 2
      fi
      ;;
  esac
done

# Any positional left after -- is a stray extra argument.
if [ "$#" -gt 0 ]; then
  if [ -z "$target_dir" ]; then
    target_dir="$1"
    shift
  fi
  if [ "$#" -gt 0 ]; then
    echo "FATAL: unexpected extra argument: $1" >&2
    exit 2
  fi
fi

[ -z "$target_dir" ] && target_dir="${HOME}/.claude/agents"

# --- Prerequisite: the source tree must exist, be readable, and be non-empty.
if [ ! -d "$src" ] || [ ! -r "$src" ]; then
  echo "FATAL: source tree $src is missing or unreadable" >&2
  exit 2
fi

mapfile -t repo_files < <(find "$src" -name '*.md' -type f | sort)

# An empty source set is never a silent pass: it means the tree moved or the
# glob broke, not that there is nothing to install.
if [ "${#repo_files[@]}" -eq 0 ]; then
  echo "FATAL: no *.md files found under $src" >&2
  exit 2
fi

# --- Prerequisite (apply mode only): the target must be creatable and writable.
if [ "$dry_run" -eq 0 ]; then
  if ! mkdir -p "$target_dir" 2>/dev/null; then
    echo "FATAL: cannot create target directory $target_dir" >&2
    exit 2
  fi
  if [ ! -w "$target_dir" ]; then
    echo "FATAL: target directory $target_dir is not writable" >&2
    exit 2
  fi
fi

# Set of repo-relative paths, used to tell install-only target files apart from
# files this repo provides.
declare -A repo_rel=()
for f in "${repo_files[@]}"; do
  rel="${f#"$src"/}"
  repo_rel["$rel"]=1
done

status=0
n_new=0
n_update=0
n_same=0

# --- Sync every repo file to its target, preserving subdirectories.
for f in "${repo_files[@]}"; do
  rel="${f#"$src"/}"
  target="$target_dir/$rel"

  if [ ! -e "$target" ]; then
    echo "NEW    $rel"
    n_new=$((n_new + 1))
    if [ "$dry_run" -eq 0 ]; then
      if ! mkdir -p "$(dirname "$target")"; then
        echo "FATAL: cannot create directory for $rel" >&2
        exit 2
      fi
      if ! cp "$f" "$target"; then
        echo "FAIL: copy failed for $rel" >&2
        status=1
      fi
    fi
  elif cmp -s "$f" "$target"; then
    echo "SAME   $rel"
    n_same=$((n_same + 1))
  else
    # An installed file is being overwritten with different content. Report it
    # loudly: this is the case a human is most likely to want to see.
    echo "UPDATE $rel  (installed file differs from repo)"
    n_update=$((n_update + 1))
    if [ "$dry_run" -eq 0 ]; then
      if ! cp "$f" "$target"; then
        echo "FAIL: copy failed for $rel" >&2
        status=1
      fi
    fi
  fi
done

# --- Count (never delete) install-only files: present in target, no repo peer.
n_install_only=0
if [ -d "$target_dir" ]; then
  while IFS= read -r tf; do
    trel="${tf#"$target_dir"/}"
    if [ -z "${repo_rel[$trel]:-}" ]; then
      echo "KEEP   $trel  (install-only; left untouched)"
      n_install_only=$((n_install_only + 1))
    fi
  done < <(find "$target_dir" -name '*.md' -type f | sort)
fi

# --- Post-copy verification (apply mode only): every repo file must now be
# byte-identical to its target. A surviving difference means a copy silently
# failed and the install is not what the repo says it should be.
if [ "$dry_run" -eq 0 ]; then
  mismatch=0
  for f in "${repo_files[@]}"; do
    rel="${f#"$src"/}"
    target="$target_dir/$rel"
    if ! cmp -s "$f" "$target"; then
      echo "FAIL: post-copy mismatch: $rel is not identical to its repo source" >&2
      mismatch=$((mismatch + 1))
    fi
  done
  [ "$mismatch" -gt 0 ] && status=1
fi

if [ "$status" -ne 0 ]; then
  echo "FAIL: sync incomplete: $n_new new, $n_update updated, $n_same unchanged, $n_install_only install-only left untouched" >&2
  exit 1
fi

mode_note=""
[ "$dry_run" -eq 1 ] && mode_note="  (dry-run: nothing written)"
echo "OK: $n_new new, $n_update updated, $n_same unchanged, $n_install_only install-only left untouched$mode_note"
exit 0
