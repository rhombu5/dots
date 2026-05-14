#!/usr/bin/env bash
# Claude Code status line — two-column multi-row layout.
# Col 1: repo root of project_dir + repo root of each added_dir.
# Col 2: cwd first, then every linked worktree of every col-1 repo (deduped vs col 1).
# Each col-2 row also shows (branch) and PR/CI status (cached, async refresh).
# Row 1 right side: model + ctx%.

input=$(cat)

project_dir=$(jq -r '.workspace.project_dir // ""' <<<"$input")
cwd=$(jq -r '.workspace.current_dir // .cwd // ""' <<<"$input")
mapfile -t added_dirs < <(jq -r '.workspace.added_dirs[]? // empty' <<<"$input")
model=$(jq -r '.model.display_name // ""' <<<"$input")
used=$(jq -r '.context_window.used_percentage // empty' <<<"$input")

CACHE_DIR="$HOME/.cache/claude-statusline"
CACHE_TTL=60
mkdir -p "$CACHE_DIR" 2>/dev/null

shorten() { local p="$1"; printf '%s' "${p/#$HOME/\~}"; }

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

cache_key() { printf '%s' "$1" | sha256sum | head -c 16; }

# Async refresh of one worktree's PR/CI cache.
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
        if output=$(cd "$wt" && gh pr view --json number,state,isDraft,statusCheckRollup 2>/dev/null); then
            printf '%s\n' "$output" > "$cache_file"
        else
            printf '{}\n' > "$cache_file"
        fi
    ) 200>"$lock_file" >/dev/null 2>&1 &
    disown 2>/dev/null
}

# Read cached annotation: outputs "<status> #<num>" or empty.
# status ∈ pass | fail | pending | open | draft | merged | closed
read_pr_annotation() {
    local wt="$1"
    local key
    key=$(cache_key "$wt")
    local cache_file="$CACHE_DIR/wt-$key.json"
    [ -s "$cache_file" ] || return
    jq -r '
        if .number then
            (if .isDraft then "draft"
             elif .state == "MERGED" then "merged"
             elif .state == "CLOSED" then "closed"
             else
                 ((.statusCheckRollup // []) | map(.conclusion // .status) | unique) as $s |
                 if   ($s | any(. == "FAILURE" or . == "TIMED_OUT" or . == "ACTION_REQUIRED")) then "fail"
                 elif ($s | any(. == "PENDING" or . == "IN_PROGRESS" or . == "QUEUED")) then "pending"
                 elif ($s | length == 0) then "open"
                 else "pass"
                 end
             end) as $status
            | "\($status) #\(.number)"
        else empty end
    ' "$cache_file" 2>/dev/null
}

color_for_status() {
    case "$1" in
        pass)    printf '\033[32m' ;;
        fail)    printf '\033[31m' ;;
        pending) printf '\033[33m' ;;
        draft)   printf '\033[2;37m' ;;
        merged)  printf '\033[35m' ;;
        closed)  printf '\033[2;31m' ;;
        *)       printf '\033[37m' ;;
    esac
}

# ── Column 1
declare -a col1_path
col1_path+=("$(repo_root_of "$project_dir")")
for d in "${added_dirs[@]}"; do col1_path+=("$(repo_root_of "$d")"); done

declare -a col1_short
for p in "${col1_path[@]}"; do col1_short+=("$(shorten "$p")"); done

declare -A seen
for p in "${col1_path[@]}"; do seen["$(realpath_safe "$p")"]=1; done

# ── Column 2: cwd, then worktrees
declare -a col2_path col2_branch
col2_path+=("$cwd")
col2_branch+=("$(git_branch_of "$cwd")")
seen["$(realpath_safe "$cwd")"]=1

for repo in "${col1_path[@]}"; do
    while IFS=$'\t' read -r wt_path wt_branch; do
        [ -z "$wt_path" ] && continue
        wt_real=$(realpath_safe "$wt_path")
        [ -n "${seen[$wt_real]}" ] && continue
        seen["$wt_real"]=1
        col2_path+=("$wt_path")
        col2_branch+=("$wt_branch")
    done < <(worktrees_of "$repo")
done

declare -a col2_short col2_pr
for p in "${col2_path[@]}"; do col2_short+=("$(shorten "$p")"); done
for ((j=0; j<${#col2_path[@]}; j++)); do
    refresh_pr_async "${col2_path[$j]}"
    col2_pr+=("$(read_pr_annotation "${col2_path[$j]}")")
done

# Widths
col1_w=0
for s in "${col1_short[@]}"; do (( ${#s} > col1_w )) && col1_w=${#s}; done
col2_w=0
for s in "${col2_short[@]}"; do (( ${#s} > col2_w )) && col2_w=${#s}; done

n=${#col1_short[@]}
(( ${#col2_short[@]} > n )) && n=${#col2_short[@]}

# Render
for ((i=0; i<n; i++)); do
    (( i > 0 )) && printf "\n"

    if (( i < ${#col1_short[@]} )); then
        printf "\033[33m%-*s\033[0m" "$col1_w" "${col1_short[$i]}"
    else
        printf "%-*s" "$col1_w" ""
    fi

    printf "  "

    if (( i < ${#col2_short[@]} )); then
        printf "\033[33m%-*s\033[0m" "$col2_w" "${col2_short[$i]}"
        if [ -n "${col2_branch[$i]}" ]; then
            printf "  \033[35m(%s)\033[0m" "${col2_branch[$i]}"
        fi
        if [ -n "${col2_pr[$i]}" ]; then
            pr_status=${col2_pr[$i]%% *}
            pr_num=${col2_pr[$i]#* }
            color=$(color_for_status "$pr_status")
            printf "  ${color}%s\033[0m" "$pr_num"
        fi
    fi

    if (( i == 0 )); then
        [ -n "$model" ] && printf "  \033[37m%s\033[0m" "$model"
        if [ -n "$used" ]; then
            used_int=$(printf '%.0f' "$used")
            if   (( used_int >= 80 )); then color="\033[31m"
            elif (( used_int >= 50 )); then color="\033[33m"
            else                            color="\033[32m"
            fi
            printf "  ${color}ctx:%s%%\033[0m" "$used_int"
        fi
    fi
done
