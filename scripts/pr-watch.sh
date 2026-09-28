#!/usr/bin/env bash
# Watch open PRs for maintainer activity and CI state transitions.
#
# Each stdout line becomes a notification (wire this into the Monitor tool, or run it
# by hand). Bot accounts and your own comments are filtered out, so what reaches you is
# *human maintainer activity*; CI is reported separately, only on state transitions.
#
# To watch a PR, add a "owner/repo number label" row to WATCH below.
#
# Portable to macOS's stock bash 3.2: no associative arrays, no mapfile.
set -u

# --- configure ------------------------------------------------------------------
# Your own GitHub login, excluded so your own pushes/replies do not notify you.
SELF="${PR_WATCH_SELF:-$(gh api user --jq .login 2>/dev/null || echo nobody)}"

# "owner/repo number label" — one row per PR.
# Example:  "bytedance/deer-flow 1234 deer-flow #1234"
WATCH=(
)

if [ ${#WATCH[@]} -eq 0 ]; then
  echo "pr-watch: add at least one \"owner/repo number label\" row to WATCH" >&2
  exit 2
fi
# --------------------------------------------------------------------------------

STATE=$(mktemp -t prwatch)
trap 'rm -f "$STATE"' EXIT

# Human-only predicate: excludes bots, the CLA app, and your own comments.
HUMAN="select(((.user.login | test(\"\\\\[bot\\\\]$\")) | not) and .user.login != \"CLAassistant\" and .user.login != \"$SELF\")"
SQUASH='gsub("[\n\r]+"; " ") | .[0:160]'

# Issue comments, review bodies, and inline review comments, for every watched PR.
comments() {
  for entry in "${WATCH[@]}"; do
    repo=${entry%% *}
    rest=${entry#* }
    num=${rest%% *}
    label=${rest#* }
    slug="${repo//\//-}-$num"
    gh api "repos/$repo/issues/$num/comments" --jq ".[] | $HUMAN | \"c-$slug-\(.id)\t[$label] comment by \(.user.login): \(.body | $SQUASH)\"" 2>/dev/null
    gh api "repos/$repo/pulls/$num/reviews" --jq ".[] | $HUMAN | \"v-$slug-\(.id)\t[$label] review (\(.state)) by \(.user.login): \(.body | $SQUASH)\"" 2>/dev/null
    gh api "repos/$repo/pulls/$num/comments" --jq ".[] | $HUMAN | \"rc-$slug-\(.id)\t[$label] review comment by \(.user.login): \(.body | $SQUASH)\"" 2>/dev/null
  done
}

# ALL_GREEN == every reported check passed or was skipped. An empty summary means
# "no checks registered yet" — on a fork PR that is the pre-approval state.
ci_summary() {
  gh pr checks "$2" --repo "$1" --json name,bucket 2>/dev/null \
    | jq -r '([.[] | select(.bucket != "pass" and .bucket != "skipping")]) as $rest | if length == 0 then "" elif ($rest | length) == 0 then "ALL_GREEN" else ($rest | sort_by(.name) | map("\(.name)=\(.bucket)") | join(" ")) end' 2>/dev/null
}

# Prime: record what already exists so the first poll does not replay history, and
# prime the CI fingerprints so a restart is silent about the current state.
# FP is an indexed array parallel to WATCH (stable order).
comments | cut -f1 >> "$STATE" 2>/dev/null || true
FP=()
for i in "${!WATCH[@]}"; do
  entry=${WATCH[$i]}
  repo=${entry%% *}; rest=${entry#* }; num=${rest%% *}
  FP[$i]=$(ci_summary "$repo" "$num")
done

while true; do
  comments | while IFS=$'\t' read -r key text; do
    [ -z "$key" ] && continue
    if ! grep -qxF "$key" "$STATE"; then
      printf '%s\n' "$key" >> "$STATE"
      printf '%s\n' "$text"
    fi
  done

  for i in "${!WATCH[@]}"; do
    entry=${WATCH[$i]}
    repo=${entry%% *}; rest=${entry#* }; num=${rest%% *}; label=${rest#* }
    cur=$(ci_summary "$repo" "$num")
    prev=${FP[$i]}
    # An empty summary means "no checks registered yet" OR a transient gh failure
    # (both seen in practice). Keeping the old fingerprint stops a momentary API
    # hiccup from wiping state and re-firing ALL_GREEN on the next poll.
    case "$cur" in
      "") ;;
      *pending*) FP[$i]="$cur" ;;
      ALL_GREEN)
        [ "$prev" != "ALL_GREEN" ] && printf '[%s] CI all green\n' "$label" || true
        FP[$i]="$cur" ;;
      *)
        [ "$cur" != "$prev" ] && printf '[%s] CI needs attention: %s\n' "$label" "$cur" || true
        FP[$i]="$cur" ;;
    esac
  done

  sleep 60
done
