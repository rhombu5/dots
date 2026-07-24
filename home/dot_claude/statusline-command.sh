#!/usr/bin/env bash
# Claude Code status line — two-column multi-row layout.
# The left side is ONE list, laid out column-major: repo root of project_dir,
# then each added_dir, then every linked worktree of those repos (deduped). It
# fills column A top-to-bottom to the height the right-side stack forces (the
# burndown / rate-limit rows), then wraps the tail into column B — keeping the
# two columns even once the list outgrows that height. Header cells show the
# path + vcs + PR/CI; worktree cells show (branch) + PR/CI (cached, async).
# Right side: row 0 = model + effort + ctx%; rows below = rate-limit burndown.

input=$(cat)

# Terminal width: read from parent's controlling TTY (status line script has none of its own)
detect_term_width() {
    local tty cols
    tty=$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ')
    if [ -n "$tty" ] && [ "$tty" != "?" ] && [ -e "/dev/$tty" ]; then
        cols=$(stty -F "/dev/$tty" size 2>/dev/null | awk '{print $2}')
        if [ -n "$cols" ] && [ "$cols" -gt 0 ] 2>/dev/null; then
            printf '%s' "$cols"; return
        fi
    fi
    printf '80'
}
TERM_WIDTH=$(detect_term_width)
# TUI status line area is narrower than the raw terminal — leave a gutter.
TERM_WIDTH=$(( TERM_WIDTH - 4 ))

# Minimum gap between col-2 content and right-side content on a row. Used by
# the col-2 word-column budgeter and by the right-side renderers below.
SEP=2

# ── Subagent detection: find descendant `claude` processes and their cwds.
detect_claude_root_pid() {
    local p="$PPID"
    while [ -n "$p" ] && [ "$p" != "1" ]; do
        local pcomm
        pcomm=$(ps -o comm= -p "$p" 2>/dev/null | tr -d ' ')
        if [ "$pcomm" = "claude" ]; then
            printf '%s' "$p"; return
        fi
        p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
    done
}

descendants_of() {
    local root="$1"
    [ -z "$root" ] && return
    local queue=("$root") pid kids k
    while (( ${#queue[@]} > 0 )); do
        pid="${queue[0]}"; queue=("${queue[@]:1}")
        mapfile -t kids < <(pgrep -P "$pid" 2>/dev/null)
        for k in "${kids[@]}"; do
            [ -n "$k" ] && queue+=("$k") && printf '%s\n' "$k"
        done
    done
}

declare -a SUBAGENT_CWDS
claude_root=$(detect_claude_root_pid)
if [ -n "$claude_root" ]; then
    while IFS= read -r pid; do
        [ -z "$pid" ] && continue
        pcomm=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ "$pcomm" = "claude" ]; then
            cwd_link=$(readlink "/proc/$pid/cwd" 2>/dev/null)
            [ -n "$cwd_link" ] && SUBAGENT_CWDS+=("$cwd_link")
        fi
    done < <(descendants_of "$claude_root")
fi

# Subagents don't fork their own `claude` process - they run inside main claude.
# So /proc-based cwd detection misses them. Fallback: each subagent's transcript
# JSONL records `cwd` on every line, so `tail -1 | jq -r .cwd` is the agent's
# current cwd. The /tmp/claude-${UID}/*/*/tasks/<id>.output symlinks point at
# those transcripts; the live/idle check is two-tier:
#   - Fresh tier (mtime < 60s): always counted as live - file was just appended.
#   - Mid-turn tier (mtime < 15min, older than fresh): only live if the last
#     assistant message has stop_reason=null (unfinished tool_use). end_turn /
#     stop_sequence on the last line means the agent's turn completed - idle.
# The 15-min ceiling guards against transcripts from sessions that crashed
# mid-turn (would leave a permanent stop_reason=null otherwise).
# Reading the cwd works regardless of dispatch shape - PR-bound subagents in
# `feat-foo` worktrees and Agent(isolation:worktree) ones in `agent-<id>`
# worktrees both write the worktree path as their cwd.
SUBAGENT_FRESH_WINDOW=60
SUBAGENT_MIDTURN_WINDOW=900
_now=$(date +%s)
shopt -s nullglob
for f in /tmp/claude-${UID}/*/*/tasks/*.output; do
    [ -L "$f" ] || continue
    target=$(readlink -f "$f" 2>/dev/null)
    [ -z "$target" ] && continue
    mtime=$(stat -c %Y "$target" 2>/dev/null) || continue
    age=$(( _now - mtime ))
    (( age < SUBAGENT_MIDTURN_WINDOW )) || continue
    last_json=$(tail -1 "$target" 2>/dev/null)
    [ -z "$last_json" ] && continue
    if (( age >= SUBAGENT_FRESH_WINDOW )); then
        # Idle iff last entry is an assistant message whose stop_reason is a
        # conversation-end signal. `tool_use` means the agent emitted tool
        # calls and is waiting for results - that's mid-flight, not idle.
        # null stop_reason is also live (incomplete assistant message).
        stop_reason=$(jq -r 'if .type == "assistant" then (.message.stop_reason // "_null") else "_nonassistant" end' <<<"$last_json" 2>/dev/null)
        case "$stop_reason" in
            end_turn|stop_sequence|max_tokens) continue ;;
        esac
    fi
    # Three potential cwd signals, used in fallback order. They all just feed
    # SUBAGENT_CWDS; matching against worktrees happens later. Whichever wins
    # depends on dispatch shape.
    #   1. meta.json's worktreePath - set by pr-bound-coder convention.
    #   2. Bash cd-targets - most recent `cd /absolute/path` in any tool_use
    #      Bash command. This is what catches the standard "parent creates
    #      worktree, agent cd's in" pattern, where the transcript cwd is
    #      stuck at the parent's launch dir.
    #   3. transcript .cwd - set per-entry but doesn't update on cd; the
    #      harness sets it correctly only for isolation:worktree dispatches.
    meta="${target%.jsonl}.meta.json"
    if [ -f "$meta" ]; then
        wp=$(jq -r '.worktreePath // empty' "$meta" 2>/dev/null)
        [ -n "$wp" ] && SUBAGENT_CWDS+=("$wp")
    fi
    bash_cd=$(tail -200 "$target" 2>/dev/null \
        | jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Bash") | .input.command // empty' 2>/dev/null \
        | grep -oE 'cd[[:space:]]+["'\'']?/[^[:space:]"'\'';|&)]+' \
        | sed -E 's/^cd[[:space:]]+["'\'']?//' \
        | tail -1)
    [ -n "$bash_cd" ] && SUBAGENT_CWDS+=("$bash_cd")
    sub_cwd=$(jq -r '.cwd // empty' <<<"$last_json" 2>/dev/null)
    [ -n "$sub_cwd" ] && SUBAGENT_CWDS+=("$sub_cwd")
done
shopt -u nullglob

project_dir=$(jq -r '.workspace.project_dir // ""' <<<"$input")
cwd=$(jq -r '.workspace.current_dir // .cwd // ""' <<<"$input")
mapfile -t added_dirs < <(jq -r '.workspace.added_dirs[]? // empty' <<<"$input")
model=$(jq -r '.model.display_name // ""' <<<"$input")
effort=$(jq -r '.effort.level // ""' <<<"$input")
used=$(jq -r '.context_window.used_percentage // empty' <<<"$input")
# Absolute context size for the latest turn = input + cache_creation + cache_read.
# This is the exact quantity fnclaude's context-notice monitor watches
# (turn.input + cacheCreation + cacheRead; see context-monitor.ts), so coloring
# ctx% off this same number makes the color escalate on precisely the token
# thresholds where fnc fires its <fnc-notice> compaction nudges. Falls back to
# total_input_tokens (which mirrors the sum) if the per-field breakdown is absent.
ctx_tokens=$(jq -r '
    (.context_window.current_usage // {}) as $u
    | (($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0)) as $sum
    | if $sum > 0 then $sum else (.context_window.total_input_tokens // 0) end
' <<<"$input")
rl5_used=$(jq   -r '.rate_limits.five_hour.used_percentage // empty' <<<"$input")
rl5_resets=$(jq -r '.rate_limits.five_hour.resets_at       // empty' <<<"$input")
rl7_used=$(jq   -r '.rate_limits.seven_day.used_percentage // empty' <<<"$input")
rl7_resets=$(jq -r '.rate_limits.seven_day.resets_at       // empty' <<<"$input")

# Set to 0 to revert the right-side rate-limit display from the burndown
# graph back to the text-based "ratio% (used%/elapsed%) day time" rows.
USAGE_BURNDOWN_GRAPH=1

# Persist a usage data point per invocation. The reset epoch in the filename
# means a new window naturally rolls into a new file, and any file whose name's
# epoch is in the past is stale historical data we can ignore (or archive).
USAGE_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-statusline"
log_usage_point() {
    local scope=$1 used=$2 resets_at=$3
    [ -z "$used" ] && return
    [ -z "$resets_at" ] && return
    mkdir -p "$USAGE_LOG_DIR" 2>/dev/null || return
    printf '%d %s\n' "$(date +%s)" "$used" >> "$USAGE_LOG_DIR/${scope}-${resets_at}.log"
}
log_usage_point "5hr"  "$rl5_used" "$rl5_resets"
log_usage_point "7day" "$rl7_used" "$rl7_resets"

CACHE_DIR="$HOME/.cache/claude-statusline"
CACHE_TTL=60
mkdir -p "$CACHE_DIR" 2>/dev/null

# ── Fable weekly limit ───────────────────────────────────────────────────────
# The statusline payload carries only five_hour and seven_day. The per-model
# weekly bucket that /usage renders as "Current week (Fable)" isn't in it — it
# lives in the OAuth usage endpoint's limits[] array, as the weekly_scoped entry
# whose scope.model.display_name is "Fable". So fetch it ourselves, on the same
# async-refresh-plus-cache idiom the PR/CI annotations use below: the render path
# reads only the cache file and never blocks on the network.
#
# A longer TTL than CACHE_TTL because this is a per-account number that moves on
# the scale of a 7-day window, not a per-keystroke one.
OAUTH_USAGE_CACHE="$CACHE_DIR/oauth-usage.json"
OAUTH_USAGE_TTL=300

refresh_oauth_usage_async() {
    local age lock_file="$OAUTH_USAGE_CACHE.lock"
    if [ -f "$OAUTH_USAGE_CACHE" ]; then
        age=$(( $(date +%s) - $(stat -c %Y "$OAUTH_USAGE_CACHE" 2>/dev/null || echo 0) ))
        (( age < OAUTH_USAGE_TTL )) && return
    fi
    (
        flock -n 200 || exit 0
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json" 2>/dev/null)
        [ -z "$token" ] && exit 0
        # On failure (expired token, offline), touch the cache instead of
        # overwriting it: the last good body stays readable and the mtime bump
        # backs the retry off by one TTL rather than refetching every render.
        if body=$(curl -sf --max-time 5 \
                    -H "Authorization: Bearer $token" \
                    -H "Content-Type: application/json" \
                    -H "anthropic-beta: oauth-2025-04-20" \
                    https://api.anthropic.com/api/oauth/usage); then
            printf '%s\n' "$body" > "$OAUTH_USAGE_CACHE"
        else
            touch "$OAUTH_USAGE_CACHE"
        fi
    ) 200>"$lock_file" >/dev/null 2>&1 &
    disown 2>/dev/null
}
refresh_oauth_usage_async

# .percent is already 0-100 (same scale as used_percentage); .resets_at is ISO
# 8601, converted here to the epoch seconds every downstream window calculation
# assumes. Both stay empty until the first async fetch lands, which the rest of
# the script treats the same as "this window isn't present".
rlf_used=""; rlf_resets=""; rlf_iso=""; rlf_epoch=""
if [ -s "$OAUTH_USAGE_CACHE" ]; then
    read -r rlf_used rlf_iso < <(jq -r '
        (.limits // [])
        | map(select(.kind == "weekly_scoped"
                     and (.scope.model.display_name // "") == "Fable"))
        | .[0] // empty
        | "\(.percent) \(.resets_at)"
    ' "$OAUTH_USAGE_CACHE" 2>/dev/null)
    # The endpoint jitters resets_at either side of the boundary second — one
    # call returns ...T01:59:59.99+00:00, the next ...T02:00:00.08+00:00 — and
    # `date -d` floors. A raw conversion therefore yields two different epochs
    # for the same window, which (the epoch being the usage log's filename key)
    # silently splits the burndown's history across two files. Reset boundaries
    # always land on a whole minute, so round to the nearest one for a key
    # that's stable across fetches. The five_hour/seven_day paths don't need
    # this: the payload hands them an integer epoch with no rounding to do.
    if [ -n "$rlf_iso" ]; then
        rlf_epoch=$(date -d "$rlf_iso" +%s 2>/dev/null)
        [ -n "$rlf_epoch" ] && rlf_resets=$(( (rlf_epoch + 30) / 60 * 60 ))
    fi
fi
log_usage_point "fable" "$rlf_used" "$rlf_resets"

shorten() { local p="$1"; printf '%s' "${p/#$HOME/\~}"; }

# Read repoSettings.cloneTemplate's literal prefix (everything before {repo}) so
# repos parked in the canonical location can be shown as just "name@owner" or
# "name@owner+input" instead of the full ~/src/... path. The clone and worktree
# templates share their prefix in normal setups, so we only need to read one.
TEMPLATE_PREFIX=""
if [ -r "$HOME/.claude/settings.json" ]; then
    _tmpl=$(jq -r '.repoSettings.cloneTemplate // empty' "$HOME/.claude/settings.json" 2>/dev/null)
    [ -n "$_tmpl" ] && TEMPLATE_PREFIX="${_tmpl%%\{*}"
fi
[ -z "$TEMPLATE_PREFIX" ] && TEMPLATE_PREFIX="~/src/"

# If a ~-shortened path fits the templated layout, strip the prefix; else return
# unchanged. Pattern check is structural (<word>@<word>[+<rest>]) - no variable
# substitution needed.
abbreviate_if_templated() {
    local p="$1"
    if [[ "$p" == "$TEMPLATE_PREFIX"* ]]; then
        local rest="${p#$TEMPLATE_PREFIX}"
        if [[ "$rest" =~ ^[^/]+@[^/]+(\+[^/]+)?$ ]]; then
            printf '%s' "$rest"
            return
        fi
    fi
    printf '%s' "$p"
}

realpath_safe() {
    local p="$1"
    if [ -d "$p" ]; then
        realpath -m "$p" 2>/dev/null || printf '%s' "$p"
    else
        printf '%s' "$p"
    fi
}

repo_root_of() {
    local d="$1"
    if [ -z "$d" ] || [ ! -d "$d" ]; then printf '%s' "$d"; return; fi
    local root
    root=$(git --no-optional-locks -C "$d" rev-parse --show-toplevel 2>/dev/null) || { printf '%s' "$d"; return; }
    printf '%s' "$root"
}

git_branch_of() {
    local d="$1"
    [ -z "$d" ] && return
    git --no-optional-locks -C "$d" rev-parse --is-inside-work-tree &>/dev/null || return
    git --no-optional-locks -C "$d" symbolic-ref --short HEAD 2>/dev/null \
        || git --no-optional-locks -C "$d" rev-parse --short HEAD 2>/dev/null
}

# p10k-flavoured VCS cell. Emits three parts joined by TAB so callers can color
# / decorate them independently:  <icons>\t<branch>\t<counts>
#   icons  = "<host-icon> <branch-icon> "  (trailing space; concat == original)
#   branch = "<branch-name>"
#   counts = " ⇣N ⇡N *N +N !N ?N"  (or empty)
# $2 = icon_mode: "tree" -> tree glyph for GitHub origins (col 2 worktrees);
#                  default -> octocat (col 1 repos).
vcs_text_for() {
    local d="$1" icon_mode="${2:-default}" branch
    [ -z "$d" ] && return
    git --no-optional-locks -C "$d" rev-parse --is-inside-work-tree &>/dev/null || return
    branch=$(git --no-optional-locks -C "$d" symbolic-ref --short HEAD 2>/dev/null) \
        || branch=$(git --no-optional-locks -C "$d" rev-parse --short HEAD 2>/dev/null) \
        || return

    local host_icon=$'' url
    local gh_icon=$'\uF408'    # nf-fa-github_alt (octocat) - col 1 default
    [ "$icon_mode" = "tree" ] && gh_icon=$'\uF1BB'    # nf-fa-tree - col 2 worktrees
    url=$(git --no-optional-locks -C "$d" remote get-url origin 2>/dev/null)
    case "$url" in
        *github.com*) host_icon="$gh_icon" ;;
        *gitlab*)     host_icon=$'' ;;
        *bitbucket*)  host_icon=$'' ;;
    esac
    local branch_icon=$''

    local icons_part="$host_icon $branch_icon "    # trailing space so concat == original
    local branch_part="$branch"

    local staged=0 unstaged=0 untracked=0 line
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if [ "${line:0:2}" = "??" ]; then
            untracked=$(( untracked + 1 ))
        else
            local x="${line:0:1}" y="${line:1:1}"
            [ "$x" != " " ] && [ "$x" != "?" ] && staged=$(( staged + 1 ))
            [ "$y" != " " ] && [ "$y" != "?" ] && unstaged=$(( unstaged + 1 ))
        fi
    done < <(git --no-optional-locks -C "$d" status --porcelain=v1 2>/dev/null)

    local ahead=0 behind=0 counts
    counts=$(git --no-optional-locks -C "$d" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
    if [ -n "$counts" ]; then
        behind=${counts%%[[:space:]]*}
        ahead=${counts##*[[:space:]]}
    fi
    local stash
    stash=$(git --no-optional-locks -C "$d" stash list 2>/dev/null | wc -l)

    local counts_part=""
    (( behind > 0 ))    && counts_part+="⇣$behind"
    (( ahead > 0 ))     && counts_part+="⇡$ahead"
    (( stash > 0 ))     && counts_part+="*$stash"
    (( staged > 0 ))    && counts_part+="+$staged"
    (( unstaged > 0 ))  && counts_part+="!$unstaged"
    (( untracked > 0 )) && counts_part+="?$untracked"
    [ -n "$counts_part" ] && counts_part=" $counts_part"   # one leading space; tokens packed

    printf '%s\t%s\t%s' "$icons_part" "$branch_part" "$counts_part"
}

worktrees_of() {
    local repo="$1"
    if [ -z "$repo" ] || [ ! -d "$repo" ]; then return; fi
    git --no-optional-locks -C "$repo" worktree list --porcelain 2>/dev/null | awk '
        function flush() { if (wt) print wt "\t" br; wt=""; br="" }
        /^worktree / { flush(); wt=$2 }
        /^branch /   { sub("refs/heads/", "", $2); br=$2 }
        /^detached/  { br="(detached)" }
        END          { flush() }
    '
}

# If $1 is inside any worktree of a repo (linked or main), return the path of the
# repo's MAIN worktree - which is always the first entry of `git worktree list`.
# Falls back to $1 unchanged when it isn't a git repo. Used so col 1 always shows
# the canonical repo root even after EnterWorktree has shifted cwd / project_dir
# into a linked worktree.
main_worktree_of() {
    local d="$1"
    [ -z "$d" ] && return
    [ -d "$d" ] || { printf '%s' "$d"; return; }
    git --no-optional-locks -C "$d" rev-parse --is-inside-work-tree &>/dev/null \
        || { printf '%s' "$d"; return; }
    local first
    first=$(worktrees_of "$d" | head -n 1 | cut -f1)
    [ -n "$first" ] && printf '%s' "$first" || printf '%s' "$d"
}

cache_key() { printf '%s' "$1" | sha256sum | head -c 16; }

# Async refresh of one worktree's PR/CI cache. Two gh calls:
#   - `pr view` for PR meta (number, state, isDraft)
#   - `pr checks` for per-check status + the event that triggered it
# The event field is only on `pr checks`, not on view's statusCheckRollup;
# we need it to split the aggregate into branch-commit (event=push) vs
# PR-open (event=pull_request) CI states.
refresh_pr_async() {
    local wt="$1"
    [ -d "$wt" ] || return
    local key cache_file lock_file age
    key=$(cache_key "$wt")
    cache_file="$CACHE_DIR/wt-$key.json"
    lock_file="$cache_file.lock"

    if [ -f "$cache_file" ]; then
        age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))
        (( age < CACHE_TTL )) && return
    fi

    (
        flock -n 200 || exit 0
        pr_meta=$(cd "$wt" && gh pr view --json number,state,isDraft 2>/dev/null)
        if [ -n "$pr_meta" ]; then
            checks=$(cd "$wt" && gh pr checks --json bucket,event 2>/dev/null)
            [ -z "$checks" ] && checks='[]'
            jq -n --argjson pr "$pr_meta" --argjson checks "$checks" \
                '{pr: $pr, checks: $checks}' > "$cache_file"
        else
            printf '{}\n' > "$cache_file"
        fi
    ) 200>"$lock_file" >/dev/null 2>&1 &
    disown 2>/dev/null
}

# Read cached annotation. Output: "<pr_state> <overall_ci> <branch_ci> <pr_ci> #<num>"
#   pr_state    ∈ open | draft | merged | closed
#   overall_ci  ∈ pass | fail | pending | none   (drives branch color)
#   branch_ci   ∈ pass | fail | pending | none | -   (event=push aggregate; - when no such runs)
#   pr_ci       ∈ pass | fail | pending | none | -   (event=pull_request aggregate)
# Skipped runs are filtered out of every aggregate.
read_pr_annotation() {
    local wt="$1"
    local key
    key=$(cache_key "$wt")
    local cache_file="$CACHE_DIR/wt-$key.json"
    [ -s "$cache_file" ] || return
    jq -r '
        def agg(checks):
            (checks | map(.bucket) | unique - ["skipping"]) as $b |
            if   ($b | any(. == "fail" or . == "cancel")) then "fail"
            elif ($b | any(. == "pending"))               then "pending"
            elif ($b | length == 0)                        then "none"
            else "pass"
            end;
        def event_state(checks; ev):
            (checks | map(select(.event == ev))) as $sub |
            if ($sub | length) == 0 then "-" else agg($sub) end;
        (.pr // {}) as $pr |
        (.checks // []) as $checks |
        if $pr.number then
            (if $pr.isDraft then "draft"
             elif $pr.state == "MERGED" then "merged"
             elif $pr.state == "CLOSED" then "closed"
             else "open"
             end) as $pr_state |
            agg($checks) as $overall |
            event_state($checks; "push")         as $branch_ci |
            event_state($checks; "pull_request") as $pr_ci |
            "\($pr_state) \($overall) \($branch_ci) \($pr_ci) #\($pr.number)"
        else empty end
    ' "$cache_file" 2>/dev/null
}

# Async refresh of one repo's most-recent-push-to-main CI state.
# Separate from refresh_pr_async because it's a different gh call shape and
# different cache key namespace (repo, not worktree).
refresh_main_ci_async() {
    local repo="$1"
    [ -d "$repo" ] || return
    local key cache_file lock_file age
    key=$(cache_key "$repo")
    cache_file="$CACHE_DIR/mainci-$key.json"
    lock_file="$cache_file.lock"

    if [ -f "$cache_file" ]; then
        age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))
        (( age < CACHE_TTL )) && return
    fi

    (
        flock -n 200 || exit 0
        if output=$(cd "$repo" && gh run list --branch main --event push --limit 1 --json status,conclusion 2>/dev/null); then
            printf '%s\n' "$output" > "$cache_file"
        else
            printf '[]\n' > "$cache_file"
        fi
    ) 200>"$lock_file" >/dev/null 2>&1 &
    disown 2>/dev/null
}

# Read cached main-CI state. Outputs pass | fail | pending, or empty when no
# runs match (no workflow on main, or filter returned nothing).
read_main_ci_annotation() {
    local repo="$1"
    local key
    key=$(cache_key "$repo")
    local cache_file="$CACHE_DIR/mainci-$key.json"
    [ -s "$cache_file" ] || return
    jq -r '
        .[0] // null |
        if . == null then empty
        elif .conclusion == "success" then "pass"
        elif .conclusion == "failure" or .conclusion == "cancelled" or .conclusion == "timed_out" then "fail"
        elif .status == "in_progress" or .status == "queued" then "pending"
        else empty
        end
    ' "$cache_file" 2>/dev/null
}

color_for_pr() {
    local pr="$1" dim="$2" d=""
    [ "$dim" = "dim" ] && d="2;"
    case "$pr" in
        open)   printf '\033[%s37m'    "$d" ;;
        draft)  printf '\033[2;37m'         ;;
        merged) printf '\033[%s35m'    "$d" ;;
        closed) printf '\033[2;31m'         ;;
        *)      printf '\033[%s37m'    "$d" ;;
    esac
}

color_for_ci() {
    local ci="$1" dim="$2" d=""
    [ "$dim" = "dim" ] && d="2;"
    case "$ci" in
        pass)    printf '\033[%s32m' "$d" ;;   # green
        fail)    printf '\033[%s31m' "$d" ;;   # red
        pending) printf '\033[%s36m' "$d" ;;   # cyan - in flight
        none)    printf '\033[%s33m' "$d" ;;   # yellow - no checks yet
        *)       printf ''                ;;
    esac
}

glyph_for_ci() {
    case "$1" in
        pass)    printf '✓' ;;
        fail)    printf '✗' ;;
        pending) printf '●' ;;
        *)       printf ''  ;;
    esac
}

# Hue palette: project_dir is always index 0 (yellow); added_dirs cycle through
# indices 1..N. Worktrees in col 2 inherit their parent col-1 entry's hue, so
# you can visually trace a worktree back to the added-dir it belongs to.
HUE_CODES=(33 36 32 34 37)   # yellow, cyan, green, blue, white

# sgr_hue <hue-idx> <dim:0|1>  →  \033[<...>m
sgr_hue() {
    local code="${HUE_CODES[$1]:-${HUE_CODES[0]}}"
    if (( $2 )); then printf '\033[2;%sm' "$code"
    else              printf '\033[%sm'   "$code"
    fi
}

# attrs_prefix <italic:0|1> <strike:0|1> <bold:0|1>  ->  SGR prefix or empty.
# Stacks before a color escape; \033[0m later resets all attributes.
attrs_prefix() {
    local parts=()
    (( ${3:-0} )) && parts+=(1)
    (( ${1:-0} )) && parts+=(3)
    (( ${2:-0} )) && parts+=(9)
    (( ${#parts[@]} == 0 )) && return
    local IFS=';'
    printf '\033[%sm' "${parts[*]}"
}

# Map col-1 index → hue index: project_dir stays at 0, added_dirs cycle 1..N-1.
hue_idx_for() {
    local i=$1 size=${#HUE_CODES[@]}
    (( i == 0 )) && { printf '0'; return; }
    printf '%d' $(( (i - 1) % (size - 1) + 1 ))
}

C_CURRENT='\033[36m'       # cyan (cwd subdir suffix on col 1 path)
C_CURRENT_DIM='\033[2;36m' # dim cyan
C_BRANCH='\033[38;5;252m'  # very light gray (col 1 vcs + col 2 status suffix)
C_BRANCH_DIM='\033[38;5;245m'  # medium gray
C_SEP='\033[2;37m'         # dim white (column separator pipe)

# ── Column 1
# Suppress col 1 entirely when project_dir is the fnclaude noop dir and no
# added_dirs are attached — noop is the "no project loaded" placeholder, so
# rendering it as a path is noise. Any added_dir means real work is in flight
# and the noop entry stays so the hues line up.
NOOP_DIR_REAL=$(realpath_safe "${XDG_CONFIG_HOME:-$HOME/.config}/fnclaude/noop")
project_dir_real=$(realpath_safe "$project_dir")
declare -a col1_path
if ! { [ "$project_dir_real" = "$NOOP_DIR_REAL" ] && (( ${#added_dirs[@]} == 0 )); }; then
    col1_path+=("$(main_worktree_of "$project_dir")")
    for d in "${added_dirs[@]}"; do col1_path+=("$(main_worktree_of "$d")"); done
fi

declare -a col1_short
for p in "${col1_path[@]}"; do col1_short+=("$(abbreviate_if_templated "$(shorten "$p")")"); done

declare -A seen
for p in "${col1_path[@]}"; do seen["$(realpath_safe "$p")"]=1; done

# ── Column 2: worktrees only (cwd is folded into col 1 below).
# `seen` already contains col-1 paths (project_dir + added_dirs), which prevents
# duplicating *main* worktrees here. Cwd is NOT added to `seen` — if cwd happens
# to be a linked worktree, it should still appear and get its yellow saturation.
declare -a col2_path col2_vcs col2_origin_idx

for ((ridx=0; ridx<${#col1_path[@]}; ridx++)); do
    repo="${col1_path[$ridx]}"
    while IFS=$'\t' read -r wt_path _; do
        [ -z "$wt_path" ] && continue
        wt_real=$(realpath_safe "$wt_path")
        [ -n "${seen[$wt_real]}" ] && continue
        seen["$wt_real"]=1
        col2_path+=("$wt_path")
        col2_origin_idx+=("$ridx")
    done < <(worktrees_of "$repo")
done

relative_to_repo() {
    # Find the col-1 repo that contains this path; emit path relative to it.
    # Falls back to ~-shortened absolute if no col-1 repo is an ancestor.
    local wt="$1" wt_real repo repo_real
    wt_real=$(realpath_safe "$wt")
    for repo in "${col1_path[@]}"; do
        repo_real=$(realpath_safe "$repo")
        if [ "$wt_real" = "$repo_real" ]; then
            printf '.'
            return
        fi
        if [[ "$wt_real" == "$repo_real"/* ]]; then
            printf './%s' "${wt_real#$repo_real/}"
            return
        fi
    done
    shorten "$wt"
}

declare -a col2_short col2_pr
for p in "${col2_path[@]}"; do col2_short+=("$(relative_to_repo "$p")"); done
for ((j=0; j<${#col2_path[@]}; j++)); do
    refresh_pr_async "${col2_path[$j]}"
    col2_pr+=("$(read_pr_annotation "${col2_path[$j]}")")
    col2_vcs+=("$(vcs_text_for "${col2_path[$j]}" tree)")
done

# Pre-fetch vcs + PR for col 1 entries too (added dirs now show git status).
# Also fetch the latest push-to-main CI state per repo - that's the release
# pipeline gate Tom watches after a PR merges.
declare -a col1_vcs col1_pr col1_main_ci
for ((j=0; j<${#col1_path[@]}; j++)); do
    refresh_pr_async      "${col1_path[$j]}"
    refresh_main_ci_async "${col1_path[$j]}"
    col1_pr+=("$(read_pr_annotation       "${col1_path[$j]}")")
    col1_main_ci+=("$(read_main_ci_annotation "${col1_path[$j]}")")
    col1_vcs+=("$(vcs_text_for "${col1_path[$j]}")")
done

# Which col-1 entry contains the cwd? (-1 if none)
cwd_real=$(realpath_safe "$cwd")
matching_idx=-1
for ((k=0; k<${#col1_path[@]}; k++)); do
    krp=$(realpath_safe "${col1_path[$k]}")
    if [ "$cwd_real" = "$krp" ] || [[ "$cwd_real" == "$krp"/* ]]; then
        matching_idx=$k
        break
    fi
done

# Right-side stack height: row 0 packs model+effort+ctx; the rows below hold
# either the text rate-limit rows or the 3-row braille burndown. This is the
# MINIMUM height the layout must reach so the right side has its slots — and,
# below, the height column A fills to before the worktree list wraps into B.
# Graph mode (USAGE_BURNDOWN_GRAPH=1) reserves 3 rows for the plot (row 1..3);
# text mode reserves 1 row per present rate-limit window.
right_rows=1
if (( USAGE_BURNDOWN_GRAPH )); then
    if { [ -n "$rl5_used" ] && [ -n "$rl5_resets" ]; } \
    || { [ -n "$rl7_used" ] && [ -n "$rl7_resets" ]; } \
    || { [ -n "$rlf_used" ] && [ -n "$rlf_resets" ]; }; then
        right_rows=4
    fi
else
    [ -n "$rl5_used" ] && [ -n "$rl5_resets" ] && right_rows=2
    [ -n "$rl7_used" ] && [ -n "$rl7_resets" ] && right_rows=3
    [ -n "$rlf_used" ] && [ -n "$rlf_resets" ] && right_rows=4
fi

# ── Column split. The left side is ONE list — repo headers (project_dir +
# added_dirs) first, then every worktree — laid out column-major: fill column A
# top-to-bottom, then spill the tail into column B. Constraints:
#   • column A never drops below right_rows, so the burndown / rate-limit rows
#     on the right always have a left row to sit beside;
#   • once the list is long enough that half of it exceeds right_rows, the two
#     columns grow evenly (balanced rowcounts) rather than piling into B; and
#   • column B is only actually used if it fits horizontally beside the right-
#     side content — the fit test in the reflow block below drops back to a
#     single column (taller, but no burndown collision) when it doesn't.
# The candidate split height is:
#       rows = max(right_rows, ceil(total / 2))
# with column A = left items [0, rows) and column B = left items [rows, total).
total_left=$(( ${#col1_path[@]} + ${#col2_path[@]} ))
rows=$(( (total_left + 1) / 2 ))
(( rows < right_rows )) && rows=$right_rows
n=$rows

# Right-side horizontal reservations, for the column-B fit test in the reflow
# block: rr_row0 = the model+effort+ctx% label on row 0; rr_plot = the width the
# burndown (or text rate rows) occupy on rows 1..3.
rr_row0=0
if [ -n "$model" ]; then
    rr_row0=${#model}
    [ -n "$effort" ] && rr_row0=$(( rr_row0 + 1 + ${#effort} ))
    if [ -n "$used" ]; then
        rr_used_int=$(printf '%.0f' "$used")
        rr_row0=$(( rr_row0 + 1 + ${#rr_used_int} + 1 ))   # " " + digits + "%"
    fi
fi
rr_plot=0
if (( USAGE_BURNDOWN_GRAPH )) && { [ -n "$rl5_resets" ] || [ -n "$rl7_resets" ] || [ -n "$rlf_resets" ]; }; then
    rr_plot=38    # flat burndown = 3 plots × 12 cells + 2 gaps (worst case)
elif [ -n "$rl5_used" ] || [ -n "$rl7_used" ] || [ -n "$rlf_used" ]; then
    rr_plot=34    # widest text rate-limit row
fi

declare -a row_str row_vw col1_cell_str col1_cell_vw
for ((i=0; i<n; i++)); do row_str[i]=""; row_vw[i]=0; done

append() {
    local i=$1 w=$2; shift 2
    row_str[i]+=$(printf "$@")
    row_vw[i]=$(( row_vw[i] + w ))
}

# ── Pass 1: build each col-1 (repo header) cell — dir + optional cyan cwd
# suffix + vcs + PR + main-CI marker — recording each cell's visible width.
for ((i=0; i<${#col1_short[@]}; i++)); do
    cell=""
    cell_w=0
    hi=$(hue_idx_for "$i")
    # Bright + bold travel together and only one item ever has them -
    # the row containing the literal cwd. Everything else is dim, not bold.
    if (( i == matching_idx )); then
        c_dir=$(sgr_hue "$hi" 0); c_vcs=$C_BRANCH;     dimflag="";    bold='\033[1m'
    else
        c_dir=$(sgr_hue "$hi" 1); c_vcs=$C_BRANCH_DIM; dimflag="dim"; bold=""
    fi

    dir="${col1_short[$i]}"
    cell+=$(printf "${bold}${c_dir}%s\033[0m" "$dir")
    cell_w=$(( cell_w + ${#dir} ))

    # Cyan suffix only on the matching row, when cwd is a subdir of it.
    if (( i == matching_idx )); then
        krp=$(realpath_safe "${col1_path[$i]}")
        if [ "$cwd_real" != "$krp" ] && [[ "$cwd_real" == "$krp"/* ]]; then
            suffix="/${cwd_real#$krp/}"
            cell+=$(printf "${bold}${C_CURRENT}%s\033[0m" "$suffix")
            cell_w=$(( cell_w + ${#suffix} ))
        fi
    fi

    vt="${col1_vcs[$i]}"
    if [ -n "$vt" ]; then
        # vcs_text_for emits icons\tbranch\tcounts; col 1 paints the whole vcs
        # cell in the status color and leaves it unstyled - it's status info,
        # not row identity. Only the path/cwd-suffix carry the bold.
        IFS=$'\t' read -r vt_icons vt_branch vt_counts <<<"$vt"
        vt_full="${vt_icons}${vt_branch}${vt_counts}"
        cell+=$(printf " ${c_vcs}%s\033[0m" "$vt_full")
        cell_w=$(( cell_w + 1 + ${#vt_full} ))
    fi

    pr="${col1_pr[$i]}"
    if [ -n "$pr" ]; then
        # col1 only uses overall ci_state; branch/PR per-event states are
        # for col2's two-glyph cluster.
        read -r pr_state ci_state _branch_ci _pr_ci pr_num <<<"$pr"
        pc=$(color_for_pr "$pr_state" "$dimflag")
        # PR info is part of the status suffix - no bold.
        cell+=$(printf " ${pc}%s\033[0m" "$pr_num")
        cell_w=$(( cell_w + 1 + ${#pr_num} ))
        if [ "$pr_state" = "open" ]; then
            cg=$(glyph_for_ci "$ci_state")
            if [ -n "$cg" ]; then
                cc=$(color_for_ci "$ci_state" "$dimflag")
                cell+=$(printf " ${cc}%s\033[0m" "$cg")
                cell_w=$(( cell_w + 2 ))
            fi
        elif [ "$pr_state" != "merged" ]; then
            # "(merged)" suppressed to save space - terminal state, common.
            cell+=$(printf " \033[2m(%s)\033[0m" "$pr_state")
            cell_w=$(( cell_w + 3 + ${#pr_state} ))
        fi
    fi

    # Main-merge CI marker: `↪` colored by the latest push-to-main CI state.
    # Same palette as the worktree-CI rule (green/cyan/yellow/red). Skipped
    # entirely when the repo has no matching runs.
    main_ci="${col1_main_ci[$i]}"
    if [ -n "$main_ci" ]; then
        mc=$(color_for_ci "$main_ci" "$dimflag")
        if [ -n "$mc" ]; then
            cell+=$(printf " ${mc}↪\033[0m")
            cell_w=$(( cell_w + 2 ))
        fi
    fi

    col1_cell_str[$i]="$cell"
    col1_cell_vw[$i]=$cell_w
done

# ── Pre-render each worktree into a standalone cell (branch + PR/CI status, no
# path). Built once here so a worktree renders identically whether it lands in
# column A (under the repo headers) or wraps into column B.
#   Hue        — inherits from the parent col-1 entry (project_dir or one of the
#                added_dirs). Lets you trace a worktree back to its repo.
#   Saturation — bright when cwd lives in this worktree, dim otherwise.
#   Italic     — set when an active subagent is in this worktree.
#   Strike     — set when the PR is merged (the "(merged)" label is then dropped).
declare -a wt_cell_str wt_cell_vw
wappend() {  # wappend <j> <visible-width> <printf-fmt> [args…] → append to worktree cell j
    local j=$1 w=$2; shift 2
    wt_cell_str[j]+=$(printf "$@")
    wt_cell_vw[j]=$(( ${wt_cell_vw[j]:-0} + w ))
}
for ((j=0; j<${#col2_path[@]}; j++)); do
    wt_cell_str[j]=""
    wt_cell_vw[j]=0

    wt_real=$(realpath_safe "${col2_path[$j]}")

    # Subagent here? SUBAGENT_CWDS now combines /proc-walked forked claudes
    # and transcript-cwd-scanned in-process subagents, so one pass covers
    # both PR-bound (feat-foo) and isolation-spawned (agent-<id>) worktrees.
    has_subagent=0
    for sc in "${SUBAGENT_CWDS[@]}"; do
        sc_real=$(realpath_safe "$sc")
        if [ "$sc_real" = "$wt_real" ] || [[ "$sc_real" == "$wt_real"/* ]]; then
            has_subagent=1; break
        fi
    done

    # Main cwd here?
    has_main=0
    if [ "$cwd_real" = "$wt_real" ] || [[ "$cwd_real" == "$wt_real"/* ]]; then
        has_main=1
    fi

    # PR state pulled up early so strikethrough can wrap the whole cell.
    pr_state=""; ci_state=""; branch_ci=""; pr_ci=""; pr_num=""
    if [ -n "${col2_pr[$j]}" ]; then
        read -r pr_state ci_state branch_ci pr_ci pr_num <<<"${col2_pr[$j]}"
        [ "$branch_ci" = "-" ] && branch_ci=""
        [ "$pr_ci"     = "-" ] && pr_ci=""
    fi

    parent_hi=$(hue_idx_for "${col2_origin_idx[$j]}")
    if (( has_main )); then
        wt_head_c=$(sgr_hue "$parent_hi" 0); wt_rhs_c=$C_BRANCH;     wt_dim=""
    else
        wt_head_c=$(sgr_hue "$parent_hi" 1); wt_rhs_c=$C_BRANCH_DIM; wt_dim="dim"
    fi
    italic_flag=0; (( has_subagent ))          && italic_flag=1
    strike_flag=0; [ "$pr_state" = "merged" ] && strike_flag=1
    bold_flag=0;   (( has_main ))              && bold_flag=1
    # All text decorations (italic for subagent, strike for merged, bold for
    # bright) attach to the branch name only - icons left of it and the status
    # suffix right of it stay undecorated, just colored.
    ap_branch=$(attrs_prefix "$italic_flag" "$strike_flag" "$bold_flag")

    # Branch color: overall CI state overrides the inherited repo hue when
    # there's an open PR with a known CI state. Per-event states surface as
    # the glyph cluster after the branch; the branch itself carries the
    # aggregate signal. Saturation honors wt_dim so the existing bright/dim
    # has_main rule still applies.
    wt_branch_c="$wt_head_c"
    if [ "$pr_state" = "open" ]; then
        case "$ci_state" in
            pass|fail|pending|none) wt_branch_c=$(color_for_ci "$ci_state" "$wt_dim") ;;
        esac
    fi
    if [ -n "${col2_vcs[$j]}" ]; then
        # Icons + branch share the aggregate CI color when there's an open
        # PR (else the repo hue); counts in light gray (matches col 1). The
        # icons track the branch color so the whole name cluster recolors
        # together on CI state, rather than the glyphs staying repo-hue.
        IFS=$'\t' read -r vt_icons vt_branch vt_counts <<<"${col2_vcs[$j]}"
        if [ -n "$vt_icons" ]; then
            wappend "$j" "${#vt_icons}" "${wt_branch_c}%s\033[0m" "$vt_icons"
        fi
        if [ -n "$vt_branch" ]; then
            wappend "$j" "${#vt_branch}" "${ap_branch}${wt_branch_c}%s\033[0m" "$vt_branch"
        fi
        if [ -n "$vt_counts" ]; then
            wappend "$j" "${#vt_counts}" "${wt_rhs_c}%s\033[0m" "$vt_counts"
        fi
    fi
    if [ -n "$pr_num" ]; then
        # CI cluster: branch-commit CI (event=push) then PR-open CI
        # (event=pull_request). Glyph per state:
        #   pass → ✓ (green)   pending → ● (cyan)
        #   fail → ✗ (red)
        # Squeezed: only glyphs that have a state are drawn (no blank-slot
        # padding), so a lone ✓/✗/● is 1 cell and both present are 2 adjacent.
        g1=""; c1=""; g2=""; c2=""
        case "$branch_ci" in
            pass)    g1="✓"; c1=$(color_for_ci pass    "$wt_dim") ;;
            fail)    g1="✗"; c1=$(color_for_ci fail    "$wt_dim") ;;
            pending) g1="●"; c1=$(color_for_ci pending "$wt_dim") ;;
        esac
        case "$pr_ci" in
            pass)    g2="✓"; c2=$(color_for_ci pass    "$wt_dim") ;;
            fail)    g2="✗"; c2=$(color_for_ci fail    "$wt_dim") ;;
            pending) g2="●"; c2=$(color_for_ci pending "$wt_dim") ;;
        esac
        if [ -n "$g1" ] || [ -n "$g2" ]; then
            wappend "$j" 1 " "
            [ -n "$g1" ] && wappend "$j" 1 "${c1}%s\033[0m" "$g1"
            [ -n "$g2" ] && wappend "$j" 1 "${c2}%s\033[0m" "$g2"
        fi
        # PR # in light gray (status suffix).
        wappend "$j" $(( 1 + ${#pr_num} )) " ${wt_rhs_c}%s\033[0m" "$pr_num"
        if [ "$pr_state" != "open" ] && [ "$pr_state" != "merged" ]; then
            # "(merged)" suppressed - strikethrough on branch carries it.
            # "(open)" suppressed - branch color carries it.
            # Draft/closed keep their word.
            wappend "$j" $(( 3 + ${#pr_state} )) " ${wt_rhs_c}(%s)\033[0m" "$pr_state"
        fi
    fi
done

# ── Reflow into two columns. One column-major list — repo header cells (built
# in Pass 1) then worktree cells — split at `rows`: column A = [0, rows),
# column B = [rows, total). See the `rows` derivation above.
declare -a left_str left_vw
for ((h=0; h<${#col1_cell_str[@]}; h++)); do
    left_str+=("${col1_cell_str[$h]}")
    left_vw+=("${col1_cell_vw[$h]}")
done
for ((j=0; j<${#wt_cell_str[@]}; j++)); do
    left_str+=("${wt_cell_str[$j]}")
    left_vw+=("${wt_cell_vw[$j]}")
done

# Column A cell width = widest cell that lands in column A (the [0, rows) slice).
colA_width=0
for ((r=0; r<rows && r<${#left_str[@]}; r++)); do
    (( left_vw[r] > colA_width )) && colA_width=${left_vw[r]}
done

# Only actually use column B if every one of its cells clears the right-side
# content on its row. A column-B cell sits at colA_width + 3 (the pipe), so the
# cell shown on display row k needs
#     colA_width + 3 + cell_width + SEP + reserve(k) <= TERM_WIDTH,
# where reserve is the model label on row 0 and the burndown/rate width on rows
# 1..3. If any cell doesn't clear it, drop column B and stack the whole list in
# a single column — taller, but no collision with the burndown. This is what
# "don't use the second column if they don't fit" asks for.
colB_count=$(( total_left - rows ))
(( colB_count < 0 )) && colB_count=0
if (( colB_count > 0 )); then
    two_col_fits=1
    for ((k=0; k<colB_count; k++)); do
        reserve=0
        if   (( k == 0 )); then reserve=$rr_row0
        elif (( k <= 3 )); then reserve=$rr_plot
        fi
        if (( colA_width + 3 + left_vw[rows + k] + SEP + reserve > TERM_WIDTH )); then
            two_col_fits=0; break
        fi
    done
    if (( ! two_col_fits )); then
        rows=$total_left
        (( rows < right_rows )) && rows=$right_rows
        n=$rows
    fi
fi

# Assemble each display row: the column-A cell (padded only when column B
# follows on that row), a dim pipe divider, then the column-B cell. Column B's
# row i holds left-list item (rows + i). Rows with no column-B content skip both
# the padding and the divider — the pipe is purely a column-A/column-B separator.
for ((i=0; i<n; i++)); do
    bidx=$(( rows + i ))
    has_colB=0
    (( bidx < ${#left_str[@]} )) && has_colB=1

    if (( i < ${#left_str[@]} )); then
        row_str[i]+="${left_str[$i]}"
        row_vw[i]=${left_vw[$i]}
        if (( has_colB )); then
            pad=$(( colA_width - left_vw[i] ))
            (( pad > 0 )) && row_str[i]+=$(printf '%*s' "$pad" "") && row_vw[i]=$colA_width
        fi
    elif (( has_colB )); then
        row_str[i]+=$(printf '\033[0m%*s' "$colA_width" "")
        row_vw[i]=$colA_width
    fi

    if (( has_colB )); then
        # Column delimiter: dim pipe with breathing room on either side.
        append "$i" 3 " ${C_SEP}|\033[0m "
        row_str[i]+="${left_str[$bidx]}"
        row_vw[i]=$(( row_vw[i] + left_vw[bidx] ))
    fi
done

# ── fnclaude context-notice ladder → ctx% color ─────────────────────────────
# fnclaude fires <fnc-notice> compaction nudges when the session's context size
# crosses a ladder of token thresholds (consider → plan → now → urgent). Color
# the ctx% readout off that SAME ladder so the number visibly escalates on the
# exact tokens where fnc starts nudging, instead of fixed 50/80% steps.
#
# resolve_notice_ladder mirrors fnclaude's resolveContextNoticeLadder precedence,
# emitting uniform "TIER <at> <level>" lines plus an optional "REPEAT <every>
# <level>" line:
#   1. FNC_CONTEXT_NOTICE_THRESHOLD env       → single 'now' tier
#   2. [[context.notice_tiers]] + [context.notice_repeat] in config.toml
#   3. legacy [context] notice_threshold      → single 'now' tier
#   4. built-in default ladder (150k/200k/250k, repeat 50k urgent)
FNC_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/fnclaude/config.toml"

resolve_notice_ladder() {
    local env_raw="${FNC_CONTEXT_NOTICE_THRESHOLD:-}"
    if [[ "$env_raw" =~ ^[0-9]+$ ]] && (( env_raw > 0 )); then
        printf 'TIER %s now\n' "$env_raw"; return
    fi
    if [ -r "$FNC_CONFIG" ]; then
        local parsed
        parsed=$(awk '
            function flush() {
                if (sec=="tier"   && at!=""    && lvl!="") print "TIER " at " " lvl
                if (sec=="repeat" && every!="" && lvl!="") print "REPEAT " every " " lvl
                sec=""; at=""; every=""; lvl=""
            }
            function strval(s) { if (match(s, /"[^"]*"/)) return substr(s, RSTART+1, RLENGTH-2); return "" }
            { sub(/#.*/, "") }
            /^[[:space:]]*\[\[context\.notice_tiers\]\][[:space:]]*$/ { flush(); sec="tier";   next }
            /^[[:space:]]*\[context\.notice_repeat\][[:space:]]*$/    { flush(); sec="repeat"; next }
            /^[[:space:]]*\[/ { flush(); next }
            sec=="tier"   && /^[[:space:]]*at[[:space:]]*=/    { v=$0; gsub(/[^0-9]/, "", v); at=v;    next }
            sec=="tier"   && /^[[:space:]]*level[[:space:]]*=/ { lvl=strval($0);                       next }
            sec=="repeat" && /^[[:space:]]*every[[:space:]]*=/ { v=$0; gsub(/[^0-9]/, "", v); every=v; next }
            sec=="repeat" && /^[[:space:]]*level[[:space:]]*=/ { lvl=strval($0);                       next }
            END { flush() }
        ' "$FNC_CONFIG")
        if [[ "$parsed" == *"TIER "* ]]; then printf '%s\n' "$parsed"; return; fi
        local legacy
        legacy=$(awk -F= '/^[[:space:]]*notice_threshold[[:space:]]*=/ { v=$2; gsub(/[^0-9]/,"",v); print v; exit }' "$FNC_CONFIG")
        if [[ "$legacy" =~ ^[0-9]+$ ]] && (( legacy > 0 )); then printf 'TIER %s now\n' "$legacy"; return; fi
    fi
    printf 'TIER 150000 consider\nTIER 200000 plan\nTIER 250000 now\nREPEAT 50000 urgent\n'
}

# ctx_color_for_tokens <tokens> → a literal "\033[..m" escape (stored the same way
# as the other color vars in this script). Finds the highest ladder point ≤ tokens
# — finite tiers plus repeat points past the last finite tier — exactly like
# fnclaude's highestCrossedPoint, then maps that point's level to an escalating hue.
ctx_color_for_tokens() {
    local T="$1"
    [[ "$T" =~ ^[0-9]+$ ]] || T=0
    local kind a lvl
    local best_at=-1 best_level="" last_tier_at=0 repeat_every=0 repeat_level=""
    while read -r kind a lvl; do
        case "$kind" in
            TIER)
                (( a > last_tier_at )) && last_tier_at=$a
                if (( a <= T )) && (( a > best_at )); then best_at=$a; best_level=$lvl; fi
                ;;
            REPEAT) repeat_every=$a; repeat_level=$lvl ;;
        esac
    done < <(resolve_notice_ladder)
    if (( repeat_every > 0 )) && (( T >= last_tier_at + repeat_every )); then
        local n=$(( (T - last_tier_at) / repeat_every ))
        local point=$(( last_tier_at + n * repeat_every ))
        (( point > best_at )) && { best_at=$point; best_level=$repeat_level; }
    fi
    case "$best_level" in
        consider) printf '%s' '\033[33m'       ;;  # yellow
        plan)     printf '%s' '\033[38;5;208m' ;;  # orange
        now)      printf '%s' '\033[38;5;202m' ;;  # red-orange
        urgent)   printf '%s' '\033[31m'       ;;  # red
        *)        printf '%s' '\033[32m'       ;;  # green — below the first tier
    esac
}

# Right-side: model on row 0, ctx% on row 1 — both right-aligned to the terminal edge.
# SEP is hoisted to the top of the file so the col-2 budgeter can use it.

if [ -n "$model" ]; then
    # Row 0 packs model, effort, and ctx% into one right-aligned label.
    #   - effort comes from .effort.level (opus 4.x only); reflects live /effort state
    #   - ctx is the raw used% with no label; its COLOR is stepped against fnclaude's
    #     context-notice ladder (ctx_color_for_tokens) rather than fixed % cutoffs, so
    #     green → yellow → orange → red-orange → red tracks consider/plan/now/urgent —
    #     the same rungs where fnc starts nudging for a compaction.
    label_w=${#model}
    [ -n "$effort" ] && label_w=$(( label_w + 1 + ${#effort} ))
    if [ -n "$used" ]; then
        used_int=$(printf '%.0f' "$used")
        ctx_text="${used_int}%"
        ctx_color=$(ctx_color_for_tokens "$ctx_tokens")
        label_w=$(( label_w + 1 + ${#ctx_text} ))
    fi
    target_col=$(( TERM_WIDTH - label_w ))
    pad=$(( target_col - row_vw[0] ))
    (( pad < SEP )) && pad=$SEP
    # Leading \033[0m so the TUI doesn't trim the pad when row 0 has no col1
    # content in front of it (e.g. noop suppression). Without it, the model
    # label collapses to the left edge.
    append 0 "$pad" '\033[0m%*s' "$pad" ""
    append 0 "${#model}" "\033[3;37m%s\033[0m" "$model"
    if [ -n "$effort" ]; then
        case "$effort" in
            auto)   effort_color='\033[3;36m' ;;       # cyan
            low)    effort_color='\033[3;32m' ;;       # green
            medium) effort_color='\033[3;38;5;226m' ;; # yellow
            high)   effort_color='\033[3;38;5;208m' ;; # orange
            xhigh)  effort_color='\033[3;38;5;202m' ;; # red-orange
            max)    effort_color='\033[3;31m' ;;       # red
            *)      effort_color='\033[2;3;37m' ;;     # fallback: dim
        esac
        append 0 $(( 1 + ${#effort} )) " ${effort_color}%s\033[0m" "$effort"
    fi
    if [ -n "$used" ]; then
        append 0 $(( 1 + ${#ctx_text} )) " ${ctx_color}%s\033[0m" "$ctx_text"
    fi
fi

# Rate-limit row: show used / elapsed-through-window as a single "burn ratio" with
# the raw fraction in parens, e.g. "5hr: 200% (50%/25%)" meaning we've burned half
# the budget but only a quarter of the window — twice the natural pace. Color the
# ratio against pace: under = green, near (±10%) = yellow, over = red.
#
# Segments build their plain (uncolored) text first so the combined width is known
# for right-alignment, then each one is re-emitted as colored pieces via append.
SEG_TEXT=""; SEG_LABEL=""; SEG_USED=0; SEG_ELAPSED=0; SEG_RATIO=0; SEG_COLOR=""
compute_rate_segment() {
    local label=$1 used=$2 resets_at=$3 window_sec=$4
    SEG_TEXT=""
    [ -z "$used" ] && return
    [ -z "$resets_at" ] && return
    local now elapsed elapsed_pct used_int divisor ratio_pct color
    now=$(date +%s)
    elapsed=$(( now - (resets_at - window_sec) ))
    (( elapsed < 0 ))          && elapsed=0
    (( elapsed > window_sec )) && elapsed=$window_sec
    elapsed_pct=$(( elapsed * 100 / window_sec ))
    used_int=$(printf '%.0f' "$used")
    # Floor the divisor to 1 so a freshly-reset window doesn't divide by zero;
    # the resulting "very large ratio" reading is itself informative.
    divisor=$(( elapsed_pct > 0 ? elapsed_pct : 1 ))
    ratio_pct=$(( used_int * 100 / divisor ))
    if   (( ratio_pct > 110 )); then color="\033[31m"
    elif (( ratio_pct >=  90 )); then color="\033[33m"
    else                             color="\033[32m"
    fi
    SEG_LABEL=$label
    SEG_USED=$used_int
    SEG_ELAPSED=$elapsed_pct
    SEG_RATIO=$ratio_pct
    SEG_COLOR=$color
    SEG_TEXT="${label}: ${ratio_pct}% (${used_int}%/${elapsed_pct}%)"
}

# Collect segments first so we can pad numeric columns to a common width per slot,
# keeping the least-significant digits vertically aligned across the two rows.
# No row label — the two rows are distinguished by position (5hr first, 7day second)
# and by the reset day+time trailing each line.
#
# Reset stored as day + time *separately* so the day-of-week column stays fixed
# (always 3 chars: Mon/Tue/...) while the time slot right-justifies its variable
# 5-7 char content (1:00am .. 12:00pm) so am/pm align.
RATE_USED=(); RATE_ELAPSED=(); RATE_RATIO=(); RATE_COLOR=(); RATE_DAY=(); RATE_TIME=()
add_rate_row() {
    local label=$1 used=$2 resets_at=$3 window_sec=$4
    compute_rate_segment "$label" "$used" "$resets_at" "$window_sec"
    [ -z "$SEG_TEXT" ] && return
    RATE_USED+=("$SEG_USED")
    RATE_ELAPSED+=("$SEG_ELAPSED")
    RATE_RATIO+=("$SEG_RATIO")
    RATE_COLOR+=("$SEG_COLOR")
    RATE_DAY+=("$(date -d "@$resets_at" +"%a" 2>/dev/null)")
    RATE_TIME+=("$(date -d "@$resets_at" +"%-I:%M%P" 2>/dev/null)")
}

add_rate_row "5hr"   "$rl5_used" "$rl5_resets" 18000
add_rate_row "7day"  "$rl7_used" "$rl7_resets" 604800
add_rate_row "fable" "$rlf_used" "$rlf_resets" 604800

if (( ! USAGE_BURNDOWN_GRAPH )) && (( ${#RATE_USED[@]} > 0 )); then
    # Column widths = max across present rows. Numbers render right-justified
    # to their slot so the trailing digits stack column-true. Day is always 3
    # chars so a fixed dw=3 keeps the day column anchored regardless of input.
    rw=0; uw=0; ew=0; tmw=0; dw=3
    for v in "${RATE_RATIO[@]}";   do (( ${#v} > rw  )) && rw=${#v};  done
    for v in "${RATE_USED[@]}";    do (( ${#v} > uw  )) && uw=${#v};  done
    for v in "${RATE_ELAPSED[@]}"; do (( ${#v} > ew  )) && ew=${#v};  done
    for v in "${RATE_TIME[@]}";    do (( ${#v} > tmw )) && tmw=${#v}; done

    emit_rate_row() {
        local row=$1 used=$2 elapsed=$3 ratio=$4 color=$5 day=$6 time=$7
        # Plain width: ratio + "%" + " (" + used + "%" + "/" + elapsed + "%" + ")"
        #            + " " + day(3) + " " + time(tmw)
        # Counted delimiters: 1 + 2 + 1 + 1 + 1 + 1 + 1 + 1 = 9 chars.
        local text_w=$(( rw + uw + ew + dw + tmw + 9 ))
        local target_col pad
        target_col=$(( TERM_WIDTH - text_w ))
        pad=$(( target_col - row_vw[row] ))
        (( pad < SEP )) && pad=$SEP
        # Prefix the pad with a no-op ANSI reset so the TUI doesn't trim the
        # leading run of whitespace (it preserves whitespace only when something
        # non-whitespace appears earlier on the line).
        append "$row" "$pad" '\033[0m%*s' "$pad" ""
        append "$row" "$rw" "${color}%*s\033[0m"   "$rw" "$ratio"
        append "$row" 1 "%%"
        append "$row" 2 " ("
        append "$row" "$uw" "\033[2;37m%*s\033[0m" "$uw" "$used"
        append "$row" 1 "%%"
        append "$row" 1 "/"
        append "$row" "$ew" "\033[2;37m%*s\033[0m" "$ew" "$elapsed"
        append "$row" 1 "%%"
        append "$row" 1 ")"
        append "$row" 1 " "
        append "$row" "$dw"  "\033[2;37m%-*s\033[0m" "$dw"  "$day"
        append "$row" 1 " "
        append "$row" "$tmw" "\033[2;37m%*s\033[0m" "$tmw" "$time"
    }

    for (( j=0; j<${#RATE_USED[@]}; j++ )); do
        emit_rate_row $(( j + 1 )) \
            "${RATE_USED[j]}" "${RATE_ELAPSED[j]}" \
            "${RATE_RATIO[j]}" "${RATE_COLOR[j]}" \
            "${RATE_DAY[j]}"   "${RATE_TIME[j]}"
    done
fi

# ────────────────────────────────────────────────────────────────────────────
# Burndown graph (USAGE_BURNDOWN_GRAPH=1): three plots, each 12 cell cols × 3
# cell rows (= 24 × 12 dots). Single-row order is 5hr, Fable, 7day. When the
# worktree list has already made the status area taller than 3 rows, the plots
# column-wrap to use that height and shrink horizontally (we never ADD rows for
# them): 2 bands of vertical room → 7day drops beneath Fable (2 cols, 25 cells);
# 3 bands → Fable drops too (1 col, 12 cells). 5hr always anchors the top-left.
# Right-aligned. Layout math lives in the render loop near the end of this block.
#
# Y axis (all plots) = percent remaining (top = 100%, bottom = 0%); each dot
# encodes (100 - used%) from the JSON.
#
# Per-plot layer priority (highest wins on cell overlap within that plot):
#   5hr plot:   red    > white-ideal
#   7day plot:  lblue  > white-ideal
#   fable plot: yellow > white-ideal
# White is a dotted diagonal across the full plot (the un-elapsed future
# included); the data line only extends to the current elapsed-x.
# ────────────────────────────────────────────────────────────────────────────
if (( USAGE_BURNDOWN_GRAPH )) && { [ -n "$rl5_resets" ] || [ -n "$rl7_resets" ] || [ -n "$rlf_resets" ]; }; then
    # Per-plot layout: 12 cells × 3 cells = 24 × 12 dots.
    #
    # Axes occupy specific dot positions, not entire cells: the Y axis is
    # cell col 0 (dot bits 0x47), the X axis is cy=2's bottom dot row only
    # (bits 0xC0 → dy=3). Data and ideal can land in cy=2's upper dot rows
    # (dy=0..2); the renderer merges the axis bits into data/ideal cells so
    # the data line flows down to the axis instead of stranding 3 dot rows
    # above it.
    #
    #   cell col 0       = Y axis (dot bits 0x47 → ⡇)
    #   cell row 2       = X axis (dot bits 0xC0 → ⣀, dy=3 only)
    #   cell (0, 2)      = corner (0xC7 → ⣇)
    #   cells (1..11, 0..2) = data area (22 × 11 dots; cy=2 dy=3 is the axis)
    #
    # Data x maps to [2, 23] (offset +2 puts the first dot one cell right of
    # the Y axis). Data y maps to [0, 10] (inclusive of cy=2 dy=0..2; the
    # axis dot at cy=2 dy=3 is the y=11 row, off-limits to data). 21/10
    # gives mostly-2-dot ideal-line gaps with one 3-dot jump at the bottom
    # right — acceptable cosmetic cost for letting data reach the axis.
    BURNDOWN_PLOT_W_CELLS=12
    BURNDOWN_PLOT_H_CELLS=3
    BURNDOWN_W_DOTS=$(( BURNDOWN_PLOT_W_CELLS * 2 ))   # 24
    BURNDOWN_H_DOTS=$(( BURNDOWN_PLOT_H_CELLS * 4 ))   # 12
    BURNDOWN_DATA_X_OFFSET=2                            # shift past Y axis cell
    BURNDOWN_DATA_W_DOTS=$(( BURNDOWN_W_DOTS - BURNDOWN_DATA_X_OFFSET ))    # 22
    BURNDOWN_DATA_H_DOTS=$(( BURNDOWN_H_DOTS - 1 ))                          # 11  (only the X axis dot row at y=11 is off-limits)
    BURNDOWN_PLOT_COUNT=3

    # Axis dot bitmasks (per axis cell):
    #   left col   = bits 1 + 2 + 4 + 64 = 0x47  (⡇)
    #   bottom row = bits 64 + 128       = 0xC0  (⣀)
    #   corner     = 0x47 | 0xC0         = 0xC7  (⣇)
    BURNDOWN_AXIS_Y=$(( 0x47 ))
    BURNDOWN_AXIS_X=$(( 0xC0 ))
    BURNDOWN_AXIS_COLOR="\033[90m"     # bright black → rendered as gray

    # Braille bit per (dx,dy). Standard mapping from U+2800 base.
    BURNDOWN_BITS=(1 2 4 64 8 16 32 128)

    declare -a br5_data br5_ideal br7_data br7_ideal brf_data brf_ideal

    burndown_set() {
        local -n layer=$1
        local x=$2 y=$3
        (( x < 0 || x >= BURNDOWN_W_DOTS )) && return
        (( y < 0 || y >= BURNDOWN_H_DOTS )) && return
        local cx=$(( x / 2 )) cy=$(( y / 4 ))
        local dx=$(( x % 2 )) dy=$(( y % 4 ))
        local idx=$(( cy * BURNDOWN_PLOT_W_CELLS + cx ))
        local bit=${BURNDOWN_BITS[ dx * 4 + dy ]}
        layer[idx]=$(( ${layer[idx]:-0} | bit ))
    }

    # Plot a log file's (epoch, used%) samples into the layer. Awk pre-buckets
    # by x so bash only iterates over ≤W_DOTS unique points.
    # layer_name passes as plain string so burndown_set's own nameref doesn't
    # form a circular reference with ours.
    # X is offset by BURNDOWN_DATA_X_OFFSET so data starts one cell right of
    # the Y axis; Y stays in [0, BURNDOWN_DATA_H_DOTS-1] so it reaches into
    # the X axis cell row but stops one dot row above the axis dot itself.
    burndown_plot_log() {
        local layer_name=$1 scope=$2 resets_at=$3 window_sec=$4
        [ -z "$resets_at" ] && return
        local file="$USAGE_LOG_DIR/${scope}-${resets_at}.log"
        [ -f "$file" ] || return
        local window_start=$(( resets_at - window_sec ))
        local x y
        while IFS=' ' read -r x y; do
            [ -z "$x" ] && continue
            burndown_set "$layer_name" "$x" "$y"
        done < <(awk -v ws="$window_start" -v win="$window_sec" \
                     -v dw="$BURNDOWN_DATA_W_DOTS" -v dh="$BURNDOWN_DATA_H_DOTS" \
                     -v xoff="$BURNDOWN_DATA_X_OFFSET" '
            # Anchor every line at the data-area top-left dot — the window-
            # start corner just inside the axes. By definition the window has
            # just reset there, so used% is 0; this is real data, not a fudge,
            # and it keeps the line connected even if logging started mid-window.
            BEGIN { seen[xoff] = 0 }
            {
                t = $1 + 0; used = $2 + 0
                elapsed = t - ws
                if (elapsed < 0 || elapsed >= win) next
                x = xoff + int(elapsed * (dw - 1) / win)
                y = int(used * (dh - 1) / 100)
                seen[x] = y
            }
            END { for (k in seen) print k, seen[k] }
        ' "$file")
    }

    # White ideal diagonal — iterate y, compute x. One dot per y row,
    # evenly spaced. Iterating x and computing y would land multiple x's
    # in the same y when the dimensions don't divide cleanly. With data area
    # = 22 × 11 dots, 21/10 = 2.1 so x gaps are mostly 2 with one 3-dot
    # gap at the very bottom-right; acceptable cosmetic cost for letting
    # data reach the axis row.
    burndown_plot_ideal() {
        local layer_name=$1 x y
        for ((y=0; y<BURNDOWN_DATA_H_DOTS; y++)); do
            x=$(( BURNDOWN_DATA_X_OFFSET + y * (BURNDOWN_DATA_W_DOTS - 1) / (BURNDOWN_DATA_H_DOTS - 1) ))
            burndown_set "$layer_name" "$x" "$y"
        done
    }

    burndown_plot_ideal br5_ideal
    burndown_plot_ideal br7_ideal
    burndown_plot_ideal brf_ideal
    burndown_plot_log   br5_data "5hr"   "$rl5_resets" 18000
    burndown_plot_log   br7_data "7day"  "$rl7_resets" 604800
    burndown_plot_log   brf_data "fable" "$rlf_resets" 604800

    # X-axis tick: cell column matching "now" inside this plot's window.
    # Same elapsed→dot-x math as the data plotter, then dot→cell.
    burndown_now_cell() {
        local resets_at=$1 window_sec=$2
        [ -z "$resets_at" ] && { printf '%s' -1; return; }
        local now elapsed dot_x
        now=$(date +%s)
        elapsed=$(( now - (resets_at - window_sec) ))
        if (( elapsed < 0 || elapsed >= window_sec )); then
            printf '%s' -1; return
        fi
        dot_x=$(( BURNDOWN_DATA_X_OFFSET + elapsed * (BURNDOWN_DATA_W_DOTS - 1) / window_sec ))
        printf '%s' $(( dot_x / 2 ))
    }
    br5_now_cell=$(burndown_now_cell "$rl5_resets" 18000)
    br7_now_cell=$(burndown_now_cell "$rl7_resets" 604800)
    brf_now_cell=$(burndown_now_cell "$rlf_resets" 604800)

    # Emit one cell. Data and ideal layers stay exclusive of each other (the
    # ideal-under-data merge was tried and rejected: ideal dots in overlapped
    # cells took the data color and read as rogue data samples climbing away
    # from the data line). The AXIS layer, by contrast, IS merged into data
    # and ideal cells when both fall in the same cell — its bits are anchored
    # to fixed positions (X axis dy=3, Y axis dx=0) that don't overlap data's
    # dot positions in the same cell, so unioning them just lets the axis
    # line stay visually contiguous beneath data flowing into the axis row.
    # The axis dots in those cells render in the data/ideal color, which
    # reads correctly as "the line approaches the axis."
    burndown_render_cell() {
        local -n out=$1
        local data_mask=$2 ideal_mask=$3 axis_mask=$4 data_color=$5
        local mask=0 color=""
        if   (( data_mask  != 0 )); then mask=$(( data_mask  | axis_mask )); color=$data_color
        elif (( ideal_mask != 0 )); then mask=$(( ideal_mask | axis_mask )); color="\033[37m"
        elif (( axis_mask  != 0 )); then mask=$axis_mask;                    color=$BURNDOWN_AXIS_COLOR
        fi
        if (( mask == 0 )); then
            out=' '
            return
        fi
        local hex
        printf -v hex '%04x' $(( 0x2800 + mask ))
        printf -v out "${color}%b\033[0m" "\\u${hex}"
    }

    # Emit one plot's row of cells. Per-cell axis bits are computed inline:
    #   cx == 0                          → Y axis bits (solid left col)
    #   cy == BURNDOWN_PLOT_H_CELLS - 1  → X axis bits (solid bottom row)
    #   both true (corner)               → OR of the two
    burndown_emit_plot_row() {
        local cy=$1 data_arr_name=$2 ideal_arr_name=$3 data_color=$4 now_cell=$5
        local -n data_arr=$data_arr_name
        local -n ideal_arr=$ideal_arr_name
        local cx idx axis_mask cell is_axis_row=0
        (( cy == BURNDOWN_PLOT_H_CELLS - 1 )) && is_axis_row=1
        for ((cx=0; cx<BURNDOWN_PLOT_W_CELLS; cx++)); do
            idx=$(( cy * BURNDOWN_PLOT_W_CELLS + cx ))
            axis_mask=0
            (( cx == 0 ))     && axis_mask=$(( axis_mask | BURNDOWN_AXIS_Y ))
            (( is_axis_row )) && axis_mask=$(( axis_mask | BURNDOWN_AXIS_X ))
            # Now-tick: a `.` glyph marking the current time's column on the
            # X axis. Suppressed when data or ideal also land in this cell,
            # so the tick never shadows the layers' own renders.
            if (( is_axis_row )) && (( cx == now_cell )) \
               && (( ${data_arr[idx]:-0} == 0 )) && (( ${ideal_arr[idx]:-0} == 0 )); then
                printf -v cell "${BURNDOWN_AXIS_COLOR}.\033[0m"
            else
                burndown_render_cell cell \
                    "${data_arr[idx]:-0}" "${ideal_arr[idx]:-0}" "$axis_mask" "$data_color"
            fi
            burndown_str+=$cell
        done
    }

    # How many 3-row bands the existing layout gives us (rows 1..n-1; row 0 is
    # the model label). We NEVER add rows for the graphs — this is purely what
    # the worktree list already made room for. More bands ⇒ stack plots ⇒ a
    # narrower block: 1 band = flat 3-across, 2 = two columns, 3 = one column.
    burndown_bands=$(( (n - 1) / BURNDOWN_PLOT_H_CELLS ))
    (( burndown_bands < 1 )) && burndown_bands=1
    (( burndown_bands > BURNDOWN_PLOT_COUNT )) && burndown_bands=$BURNDOWN_PLOT_COUNT

    # Plots in single-row order: 5hr, Fable, 7day (left→right when flat). As
    # bands appear, plots drop below to shrink width — 7day first, then Fable;
    # 5hr always anchors the top-left. A dropped plot stacks under the rightmost
    # column, so the block narrows right-to-left. plot index: 0=5hr 1=Fable 2=7day.
    burndown_layer_data=(br5_data brf_data br7_data)
    burndown_layer_ideal=(br5_ideal brf_ideal br7_ideal)
    burndown_layer_color=("\033[31m" "\033[33m" "\033[94m")   # 5hr red, Fable yellow, 7day blue
    burndown_layer_now=("$br5_now_cell" "$brf_now_cell" "$br7_now_cell")
    case $burndown_bands in
        1) burndown_pb=(0 0 0); burndown_pc=(0 1 2); burndown_ncols=3 ;;  # [5hr][Fable][7day]
        2) burndown_pb=(0 0 1); burndown_pc=(0 1 1); burndown_ncols=2 ;;  # 5hr | Fable-over-7day
        *) burndown_pb=(0 1 2); burndown_pc=(0 0 0); burndown_ncols=1 ;;  # 5hr / Fable / 7day
    esac
    burndown_total_w=$(( burndown_ncols * BURNDOWN_PLOT_W_CELLS + (burndown_ncols - 1) ))

    # Walk band by band; each band's 3 cell-rows land on consecutive display
    # rows. On each row, walk columns left→right, emitting the plot that sits at
    # (band, col) or a blank 12-cell gap where none does (e.g. band 2 left col).
    for ((burndown_band=0; burndown_band<burndown_bands; burndown_band++)); do
        for ((burndown_cy=0; burndown_cy<BURNDOWN_PLOT_H_CELLS; burndown_cy++)); do
            burndown_row=$(( 1 + burndown_band * BURNDOWN_PLOT_H_CELLS + burndown_cy ))
            burndown_target_col=$(( TERM_WIDTH - burndown_total_w ))
            burndown_pad=$(( burndown_target_col - row_vw[burndown_row] ))
            (( burndown_pad < SEP )) && burndown_pad=$SEP
            printf -v burndown_str '\033[0m%*s' "$burndown_pad" ""
            burndown_vw=$burndown_pad

            for ((burndown_col=0; burndown_col<burndown_ncols; burndown_col++)); do
                if (( burndown_col > 0 )); then
                    burndown_str+=' '
                    burndown_vw=$(( burndown_vw + 1 ))
                fi
                burndown_p=-1
                for ((bp=0; bp<BURNDOWN_PLOT_COUNT; bp++)); do
                    if (( burndown_pb[bp] == burndown_band && burndown_pc[bp] == burndown_col )); then
                        burndown_p=$bp; break
                    fi
                done
                if (( burndown_p >= 0 )); then
                    burndown_emit_plot_row "$burndown_cy" \
                        "${burndown_layer_data[burndown_p]}" "${burndown_layer_ideal[burndown_p]}" \
                        "${burndown_layer_color[burndown_p]}" "${burndown_layer_now[burndown_p]}"
                else
                    printf -v burndown_blank '%*s' "$BURNDOWN_PLOT_W_CELLS" ""
                    burndown_str+=$burndown_blank
                fi
                burndown_vw=$(( burndown_vw + BURNDOWN_PLOT_W_CELLS ))
            done

            row_str[burndown_row]+=$burndown_str
            row_vw[burndown_row]=$(( row_vw[burndown_row] + burndown_vw ))
        done
    done
fi

for ((i=0; i<n; i++)); do
    (( i > 0 )) && printf "\n"
    printf '%s' "${row_str[$i]}"
done
