#!/usr/bin/env bash
# Claude Code status line — two-column multi-row layout.
# Col 1: repo root of project_dir + repo root of each added_dir.
# Col 2: cwd first, then every linked worktree of every col-1 repo (deduped vs col 1).
# Each col-2 row also shows (branch) and PR/CI status (cached, async refresh).
# Row 1 right side: model + ctx%.

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

# p10k-flavoured VCS cell text: "<host-icon> <branch-icon> <branch>[ ⇣N ⇡N *N +N !N ?N]"
vcs_text_for() {
    local d="$1" branch
    [ -z "$d" ] && return
    git --no-optional-locks -C "$d" rev-parse --is-inside-work-tree &>/dev/null || return
    branch=$(git --no-optional-locks -C "$d" symbolic-ref --short HEAD 2>/dev/null) \
        || branch=$(git --no-optional-locks -C "$d" rev-parse --short HEAD 2>/dev/null) \
        || return

    local host_icon=$'' url
    url=$(git --no-optional-locks -C "$d" remote get-url origin 2>/dev/null)
    case "$url" in
        *github.com*) host_icon=$'' ;;
        *gitlab*)     host_icon=$'' ;;
        *bitbucket*)  host_icon=$'' ;;
    esac
    local branch_icon=$''

    local out="$host_icon $branch_icon $branch"

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

    (( behind > 0 ))    && out+=" ⇣$behind"
    (( ahead > 0 ))     && out+=" ⇡$ahead"
    (( stash > 0 ))     && out+=" *$stash"
    (( staged > 0 ))    && out+=" +$staged"
    (( unstaged > 0 ))  && out+=" !$unstaged"
    (( untracked > 0 )) && out+=" ?$untracked"

    printf '%s' "$out"
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
             else "open"
             end) as $pr |
            ((.statusCheckRollup // []) | map(.conclusion // .status) | unique) as $s |
            (if   ($s | any(. == "FAILURE" or . == "TIMED_OUT" or . == "ACTION_REQUIRED")) then "fail"
             elif ($s | any(. == "PENDING" or . == "IN_PROGRESS" or . == "QUEUED")) then "pending"
             elif ($s | length == 0) then "none"
             else "pass"
             end) as $ci |
            "\($pr) \($ci) #\(.number)"
        else empty end
    ' "$cache_file" 2>/dev/null
}

color_for_pr() {
    case "$1" in
        open)   printf '\033[37m'    ;;  # white
        draft)  printf '\033[2;37m'  ;;  # dim white
        merged) printf '\033[35m'    ;;  # magenta
        closed) printf '\033[2;31m'  ;;  # dim red
        *)      printf '\033[37m'    ;;
    esac
}

color_for_ci() {
    case "$1" in
        pass)    printf '\033[32m' ;;  # green
        fail)    printf '\033[31m' ;;  # red
        pending) printf '\033[33m' ;;  # yellow
        *)       printf ''         ;;
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

# Path-cell colors
C_PROJECT='\033[33m'      # yellow
C_ADDED='\033[2;33m'      # dim yellow
C_CURRENT='\033[36m'      # cyan
C_WORKTREE='\033[34m'     # blue
C_BRANCH='\033[35m'       # magenta

# ── Column 1
declare -a col1_path
col1_path+=("$(repo_root_of "$project_dir")")
for d in "${added_dirs[@]}"; do col1_path+=("$(repo_root_of "$d")"); done

declare -a col1_short
for p in "${col1_path[@]}"; do col1_short+=("$(shorten "$p")"); done

declare -A seen
for p in "${col1_path[@]}"; do seen["$(realpath_safe "$p")"]=1; done

# ── Column 2: cwd, then worktrees
declare -a col2_path col2_vcs
col2_path+=("$cwd")
seen["$(realpath_safe "$cwd")"]=1

for repo in "${col1_path[@]}"; do
    while IFS=$'\t' read -r wt_path _; do
        [ -z "$wt_path" ] && continue
        wt_real=$(realpath_safe "$wt_path")
        [ -n "${seen[$wt_real]}" ] && continue
        seen["$wt_real"]=1
        col2_path+=("$wt_path")
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
    col2_vcs+=("$(vcs_text_for "${col2_path[$j]}")")
done

# Widths
col1_w=0
for s in "${col1_short[@]}"; do (( ${#s} > col1_w )) && col1_w=${#s}; done
col2_w=0
for s in "${col2_short[@]}"; do (( ${#s} > col2_w )) && col2_w=${#s}; done

n=${#col1_short[@]}
(( ${#col2_short[@]} > n )) && n=${#col2_short[@]}

# Build per-row strings (with ANSI) and visible widths (without ANSI),
# so we can compute "ctx% under model" alignment after all rows are built.
declare -a row_str row_vw
for ((i=0; i<n; i++)); do row_str[i]=""; row_vw[i]=0; done

append() {
    # append <i> <visible_width> <printf_format> [printf_args...]
    local i=$1 w=$2; shift 2
    row_str[i]+=$(printf "$@")
    row_vw[i]=$(( row_vw[i] + w ))
}

for ((i=0; i<n; i++)); do
    if (( i == 0 )); then
        # Row 1: merge col1[0] + col2[0] into a single path with two-color text.
        # Repo root portion (yellow) + relative-subdir suffix (blue) if cwd ≠ repo root.
        repo_short="${col1_short[0]}"
        append 0 "${#repo_short}" "${C_PROJECT}%s\033[0m" "$repo_short"
        cwd_real=$(realpath_safe "$cwd")
        repo_real=$(realpath_safe "${col1_path[0]}")
        if [[ "$cwd_real" == "$repo_real"/* ]]; then
            suffix="/${cwd_real#$repo_real/}"
            append 0 "${#suffix}" "${C_CURRENT}%s\033[0m" "$suffix"
        elif [ "$cwd_real" != "$repo_real" ] && [ -n "$cwd_real" ]; then
            # cwd outside the repo — show absolute in cyan after a separator
            cs=$(shorten "$cwd")
            append 0 2 "  "
            append 0 "${#cs}" "${C_CURRENT}%s\033[0m" "$cs"
        fi
    else
        # Other rows: col1 + sep + col2 (unchanged layout)
        if (( i < ${#col1_short[@]} )); then
            c=$C_ADDED
            append "$i" "$col1_w" "${c}%-*s\033[0m" "$col1_w" "${col1_short[$i]}"
        else
            append "$i" "$col1_w" "%-*s" "$col1_w" ""
        fi
        append "$i" 2 "  "
        if (( i < ${#col2_short[@]} )); then
            append "$i" "$col2_w" "${C_WORKTREE}%-*s\033[0m" "$col2_w" "${col2_short[$i]}"
        fi
    fi

    # Branch + PR/CI for any row with a col-2 entry
    if (( i < ${#col2_path[@]} )); then
        if [ -n "${col2_vcs[$i]}" ]; then
            vt="${col2_vcs[$i]}"
            append "$i" $(( 2 + ${#vt} )) "  ${C_BRANCH}%s\033[0m" "$vt"
        fi
        if [ -n "${col2_pr[$i]}" ]; then
            read -r pr_state ci_state pr_num <<<"${col2_pr[$i]}"
            pc=$(color_for_pr "$pr_state")
            append "$i" $(( 2 + ${#pr_num} )) "  ${pc}%s\033[0m" "$pr_num"
            if [ "$pr_state" = "open" ]; then
                cg=$(glyph_for_ci "$ci_state")
                if [ -n "$cg" ]; then
                    cc=$(color_for_ci "$ci_state")
                    append "$i" 2 " ${cc}%s\033[0m" "$cg"
                fi
            else
                append "$i" $(( 3 + ${#pr_state} )) " \033[2m(%s)\033[0m" "$pr_state"
            fi
        fi
    fi
done

# Right-side: model on row 0, ctx% on row 1 — both right-aligned to the terminal edge.
SEP=2

if [ -n "$model" ]; then
    target_col=$(( TERM_WIDTH - ${#model} ))
    pad=$(( target_col - row_vw[0] ))
    (( pad < SEP )) && pad=$SEP
    append 0 "$pad" '%*s' "$pad" ""
    append 0 "${#model}" "\033[37m%s\033[0m" "$model"
fi

if [ -n "$used" ]; then
    used_int=$(printf '%.0f' "$used")
    ctx_text="ctx:${used_int}%"
    if   (( used_int >= 80 )); then color="\033[31m"
    elif (( used_int >= 50 )); then color="\033[33m"
    else                            color="\033[32m"
    fi
    target_row=0; (( n >= 2 )) && target_row=1
    target_col=$(( TERM_WIDTH - ${#ctx_text} ))
    pad=$(( target_col - row_vw[target_row] ))
    (( pad < SEP )) && pad=$SEP
    append "$target_row" "$pad" '%*s' "$pad" ""
    append "$target_row" "${#ctx_text}" "${color}%s\033[0m" "$ctx_text"
fi

for ((i=0; i<n; i++)); do
    (( i > 0 )) && printf "\n"
    printf '%s' "${row_str[$i]}"
done
