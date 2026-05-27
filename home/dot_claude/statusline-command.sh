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

# Subagents don't fork their own `claude` process — they run inside main claude.
# So /proc-based cwd detection misses them. Fallback heuristic: each Agent(isolation:worktree)
# creates a `.claude/worktrees/agent-<id>` worktree and a transcript symlink at
# /tmp/claude-${UID}/*/*/tasks/<id>.output. If the symlink's target was touched
# in the last 10 minutes, treat the matching worktree as having a live agent.
declare -A ACTIVE_AGENT_IDS
SUBAGENT_ACTIVITY_WINDOW=600
_now=$(date +%s)
shopt -s nullglob
for f in /tmp/claude-${UID}/*/*/tasks/*.output; do
    [ -L "$f" ] || continue
    target=$(readlink -f "$f" 2>/dev/null)
    [ -z "$target" ] && continue
    mtime=$(stat -c %Y "$target" 2>/dev/null) || continue
    if (( _now - mtime < SUBAGENT_ACTIVITY_WINDOW )); then
        base=${f##*/}
        ACTIVE_AGENT_IDS["${base%.output}"]=1
    fi
done
shopt -u nullglob

project_dir=$(jq -r '.workspace.project_dir // ""' <<<"$input")
cwd=$(jq -r '.workspace.current_dir // .cwd // ""' <<<"$input")
mapfile -t added_dirs < <(jq -r '.workspace.added_dirs[]? // empty' <<<"$input")
model=$(jq -r '.model.display_name // ""' <<<"$input")
effort=$(jq -r '.effort.level // ""' <<<"$input")
used=$(jq -r '.context_window.used_percentage // empty' <<<"$input")
exceeds_200k=$(jq -r '.exceeds_200k_tokens // false' <<<"$input")
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
    (( behind > 0 ))    && counts_part+=" ⇣$behind"
    (( ahead > 0 ))     && counts_part+=" ⇡$ahead"
    (( stash > 0 ))     && counts_part+=" *$stash"
    (( staged > 0 ))    && counts_part+=" +$staged"
    (( unstaged > 0 ))  && counts_part+=" !$unstaged"
    (( untracked > 0 )) && counts_part+=" ?$untracked"

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
        pass)    printf '\033[%s32m' "$d" ;;
        fail)    printf '\033[%s31m' "$d" ;;
        pending) printf '\033[%s33m' "$d" ;;
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
declare -a col1_vcs col1_pr
for ((j=0; j<${#col1_path[@]}; j++)); do
    refresh_pr_async "${col1_path[$j]}"
    col1_pr+=("$(read_pr_annotation "${col1_path[$j]}")")
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

col2_w=0
for s in "${col2_short[@]}"; do (( ${#s} > col2_w )) && col2_w=${#s}; done

n=${#col1_short[@]}
(( ${#col2_path[@]} > n )) && n=${#col2_path[@]}

# Right-side stack: row 0 packs model+effort+ctx; rate-limit rows fall below.
# Inflate n if the left side has fewer rows so the rate-limit rows have slots.
# Graph mode (USAGE_BURNDOWN_GRAPH=1) reserves 3 rows for the braille plot;
# text mode reserves 1 row per present rate-limit window.
right_rows=1
if (( USAGE_BURNDOWN_GRAPH )); then
    if { [ -n "$rl5_used" ] && [ -n "$rl5_resets" ]; } \
    || { [ -n "$rl7_used" ] && [ -n "$rl7_resets" ]; }; then
        right_rows=4
    fi
else
    [ -n "$rl5_used" ] && [ -n "$rl5_resets" ] && right_rows=2
    [ -n "$rl7_used" ] && [ -n "$rl7_resets" ] && right_rows=3
fi
(( right_rows > n )) && n=$right_rows

declare -a row_str row_vw col1_cell_str col1_cell_vw
for ((i=0; i<n; i++)); do row_str[i]=""; row_vw[i]=0; done

append() {
    local i=$1 w=$2; shift 2
    row_str[i]+=$(printf "$@")
    row_vw[i]=$(( row_vw[i] + w ))
}

# ── Pass 1: build each col-1 cell (dir + optional cyan suffix + vcs + PR), tracking widths
col1_cell_max_w=0
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
        cell+=$(printf "  ${c_vcs}%s\033[0m" "$vt_full")
        cell_w=$(( cell_w + 2 + ${#vt_full} ))
    fi

    pr="${col1_pr[$i]}"
    if [ -n "$pr" ]; then
        read -r pr_state ci_state pr_num <<<"$pr"
        pc=$(color_for_pr "$pr_state" "$dimflag")
        # PR info is part of the status suffix - no bold.
        cell+=$(printf "  ${pc}%s\033[0m" "$pr_num")
        cell_w=$(( cell_w + 2 + ${#pr_num} ))
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

    col1_cell_str[$i]="$cell"
    col1_cell_vw[$i]=$cell_w
    (( cell_w > col1_cell_max_w )) && col1_cell_max_w=$cell_w
done

# ── Pass 2: assemble rows. Col 1 cell padded to col1_cell_max_w, then col 2.
# Rows with no col-2 content skip both the padding and the divider pipe — the
# pipe is purely a col-1/col-2 separator, so don't draw it when nothing follows.
for ((i=0; i<n; i++)); do
    has_col2=0
    (( i < ${#col2_path[@]} )) && has_col2=1

    if (( i < ${#col1_cell_str[@]} )); then
        row_str[i]+="${col1_cell_str[$i]}"
        row_vw[i]=${col1_cell_vw[$i]}
        if (( has_col2 )); then
            pad=$(( col1_cell_max_w - col1_cell_vw[i] ))
            (( pad > 0 )) && row_str[i]+=$(printf '%*s' "$pad" "") && row_vw[i]=$col1_cell_max_w
        fi
    elif (( has_col2 )); then
        row_str[i]+=$(printf '\033[0m%*s' "$col1_cell_max_w" "")
        row_vw[i]=$col1_cell_max_w
    fi

    if (( has_col2 )); then
        # Column delimiter: dim pipe with breathing room on either side
        append "$i" 3 " ${C_SEP}|\033[0m "

        # Col 2: git info only (no path).
        # Hue        — inherits from the parent col-1 entry (project_dir or one of
        #              the added_dirs). Lets you trace a worktree back to its repo.
        # Saturation — bright when cwd lives in this worktree, dim otherwise.
        # Italic     — set when an active subagent is in this worktree.
        # Strike     — set when the PR is merged (the "(merged)" label is then dropped).
        wt_real=$(realpath_safe "${col2_path[$i]}")

        # Subagent here? (forked-claude /proc check, then in-process agent-id heuristic.)
        has_subagent=0
        for sc in "${SUBAGENT_CWDS[@]}"; do
            sc_real=$(realpath_safe "$sc")
            if [ "$sc_real" = "$wt_real" ] || [[ "$sc_real" == "$wt_real"/* ]]; then
                has_subagent=1; break
            fi
        done
        if (( has_subagent == 0 )); then
            wt_basename=${col2_path[$i]##*/}
            if [[ "$wt_basename" == agent-* ]]; then
                aid="${wt_basename#agent-}"
                [ -n "${ACTIVE_AGENT_IDS[$aid]}" ] && has_subagent=1
            fi
        fi

        # Main cwd here?
        has_main=0
        if [ "$cwd_real" = "$wt_real" ] || [[ "$cwd_real" == "$wt_real"/* ]]; then
            has_main=1
        fi

        # PR state pulled up early so strikethrough can wrap the whole col-2 cell.
        pr_state=""; ci_state=""; pr_num=""
        if [ -n "${col2_pr[$i]}" ]; then
            read -r pr_state ci_state pr_num <<<"${col2_pr[$i]}"
        fi

        parent_hi=$(hue_idx_for "${col2_origin_idx[$i]}")
        if (( has_main )); then
            wt_head_c=$(sgr_hue "$parent_hi" 0); wt_rhs_c=$C_BRANCH;     wt_dim=""
        else
            wt_head_c=$(sgr_hue "$parent_hi" 1); wt_rhs_c=$C_BRANCH_DIM; wt_dim="dim"
        fi
        italic_flag=0; (( has_subagent ))          && italic_flag=1
        strike_flag=0; [ "$pr_state" = "merged" ] && strike_flag=1
        bold_flag=0;   (( has_main ))              && bold_flag=1
        # All text decorations (italic for subagent, strike for merged, bold
        # for bright) attach to the branch name only - icons left of it and the
        # status suffix right of it stay undecorated, just colored.
        ap_branch=$(attrs_prefix "$italic_flag" "$strike_flag" "$bold_flag")

        if [ -n "${col2_vcs[$i]}" ]; then
            # icons + branch name in inherited hue; counts in light gray
            # (matching col 1's status color) so "git statuses" all read alike.
            IFS=$'\t' read -r vt_icons vt_branch vt_counts <<<"${col2_vcs[$i]}"
            if [ -n "$vt_icons" ]; then
                append "$i" "${#vt_icons}" "${wt_head_c}%s\033[0m" "$vt_icons"
            fi
            if [ -n "$vt_branch" ]; then
                append "$i" "${#vt_branch}" "${ap_branch}${wt_head_c}%s\033[0m" "$vt_branch"
            fi
            if [ -n "$vt_counts" ]; then
                append "$i" "${#vt_counts}" "${wt_rhs_c}%s\033[0m" "$vt_counts"
            fi
        fi
        if [ -n "$pr_num" ]; then
            # Right of the branch name everything reads as status in light gray.
            append "$i" $(( 2 + ${#pr_num} )) "  ${wt_rhs_c}%s\033[0m" "$pr_num"
            if [ "$pr_state" = "open" ]; then
                cg=$(glyph_for_ci "$ci_state")
                if [ -n "$cg" ]; then
                    append "$i" 2 " ${wt_rhs_c}%s\033[0m" "$cg"
                fi
            elif [ "$pr_state" != "merged" ]; then
                # "(merged)" is conveyed by the strikethrough on branch - suppress
                # the label to save space. Draft/closed keep their word.
                append "$i" $(( 3 + ${#pr_state} )) " ${wt_rhs_c}(%s)\033[0m" "$pr_state"
            fi
        fi
    fi
done

# Right-side: model on row 0, ctx% on row 1 — both right-aligned to the terminal edge.
SEP=2

if [ -n "$model" ]; then
    # Row 0 packs model, effort, and ctx% into one right-aligned label.
    #   - effort comes from .effort.level (opus 4.x only); reflects live /effort state
    #   - ctx is the raw used% with no label, color-stepped against the same thresholds
    #     as before (green <50, yellow 50-79, red >=80)
    label_w=${#model}
    [ -n "$effort" ] && label_w=$(( label_w + 1 + ${#effort} ))
    if [ -n "$used" ]; then
        used_int=$(printf '%.0f' "$used")
        ctx_text="${used_int}%"
        if   [ "$exceeds_200k" = "true" ]; then ctx_color="\033[31m"
        elif (( used_int >= 80 ));         then ctx_color="\033[31m"
        elif (( used_int >= 50 ));         then ctx_color="\033[33m"
        else                                    ctx_color="\033[32m"
        fi
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

add_rate_row "5hr"  "$rl5_used" "$rl5_resets" 18000
add_rate_row "7day" "$rl7_used" "$rl7_resets" 604800

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
# Burndown graph (USAGE_BURNDOWN_GRAPH=1): two side-by-side plots, each 12 cell
# cols × 3 cell rows (= 24 × 12 dots). 5hr on the left, 7day on the right, with
# a 1-cell gap between. Total width: 12 + 1 + 12 = 25 cells. Right-aligned.
#
# Y axis (both plots) = percent remaining (top = 100%, bottom = 0%); each dot
# encodes (100 - used%) from the JSON.
#
# Per-plot layer priority (highest wins on cell overlap within that plot):
#   5hr plot:  red    > white-ideal
#   7day plot: lblue  > white-ideal
# White is a dotted diagonal across the full plot (the un-elapsed future
# included); the data line only extends to the current elapsed-x.
# ────────────────────────────────────────────────────────────────────────────
if (( USAGE_BURNDOWN_GRAPH )) && { [ -n "$rl5_resets" ] || [ -n "$rl7_resets" ]; }; then
    # Per-plot layout: 12 cells × 3 cells = 24 × 12 dots.
    #
    # Axes are reserved at the cell-level (not just dot-level) so they never
    # share a cell with data — that way they render in gray regardless of how
    # close data gets, and the "data tint bleeds into the axis" artifact from
    # the merged-bitmask approach is gone.
    #
    #   cell col 0       = Y axis (dot bits 0x47 → ⡇)
    #   cell row 2       = X axis (dot bits 0xC0 → ⣀)
    #   cell (0, 2)      = corner (0xC7 → ⣇)
    #   cells (1..11, 0..1) = data area (22 × 8 dots)
    #
    # Data x maps to [2, 23] (offset +2 puts the first dot one cell right of
    # the Y axis). Data y maps to [0, 7] (stays above the X axis row). 21/7
    # divides cleanly so the ideal diagonal lands one dot per y row at
    # perfectly even 3-apart x positions.
    BURNDOWN_PLOT_W_CELLS=12
    BURNDOWN_PLOT_H_CELLS=3
    BURNDOWN_W_DOTS=$(( BURNDOWN_PLOT_W_CELLS * 2 ))   # 24
    BURNDOWN_H_DOTS=$(( BURNDOWN_PLOT_H_CELLS * 4 ))   # 12
    BURNDOWN_DATA_X_OFFSET=2                            # shift past Y axis cell
    BURNDOWN_DATA_W_DOTS=$(( BURNDOWN_W_DOTS - BURNDOWN_DATA_X_OFFSET ))    # 22
    BURNDOWN_DATA_H_DOTS=$(( BURNDOWN_H_DOTS - 4 ))                          # 8  (X axis row eats 4 dot rows)
    BURNDOWN_GAP_CELLS=1
    BURNDOWN_TOTAL_W=$(( BURNDOWN_PLOT_W_CELLS * 2 + BURNDOWN_GAP_CELLS ))   # 25

    # Axis dot bitmasks (per axis cell):
    #   left col   = bits 1 + 2 + 4 + 64 = 0x47  (⡇)
    #   bottom row = bits 64 + 128       = 0xC0  (⣀)
    #   corner     = 0x47 | 0xC0         = 0xC7  (⣇)
    BURNDOWN_AXIS_Y=$(( 0x47 ))
    BURNDOWN_AXIS_X=$(( 0xC0 ))
    BURNDOWN_AXIS_COLOR="\033[90m"     # bright black → rendered as gray

    # Braille bit per (dx,dy). Standard mapping from U+2800 base.
    BURNDOWN_BITS=(1 2 4 64 8 16 32 128)

    declare -a br5_data br5_ideal br7_data br7_ideal

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
    # the Y axis; Y stays in [0, BURNDOWN_DATA_H_DOTS-1] so it stays above the
    # X axis row.
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
    # in the same y when the dimensions don't divide cleanly, producing
    # visible stair-stepping. With data area = 22 × 8 dots, 21/7 = 3 exactly,
    # so this gives dots at x = xoff, xoff+3, xoff+6, … evenly spaced.
    burndown_plot_ideal() {
        local layer_name=$1 x y
        for ((y=0; y<BURNDOWN_DATA_H_DOTS; y++)); do
            x=$(( BURNDOWN_DATA_X_OFFSET + y * (BURNDOWN_DATA_W_DOTS - 1) / (BURNDOWN_DATA_H_DOTS - 1) ))
            burndown_set "$layer_name" "$x" "$y"
        done
    }

    burndown_plot_ideal br5_ideal
    burndown_plot_ideal br7_ideal
    burndown_plot_log   br5_data "5hr"  "$rl5_resets" 18000
    burndown_plot_log   br7_data "7day" "$rl7_resets" 604800

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

    # Emit one cell. Each layer renders exclusively — the highest-priority
    # non-empty layer provides BOTH the dot bitmask and the color, so the
    # color of dots in a cell unambiguously matches the layer they came from.
    #
    # (We tried merging bitmasks so ideal dots stayed visible under data, but
    # because a braille cell has one fg color, the ideal dots in overlapped
    # cells took the data color — which read as rogue data samples climbing
    # away from the actual data line.)
    burndown_render_cell() {
        local -n out=$1
        local data_mask=$2 ideal_mask=$3 axis_mask=$4 data_color=$5
        local mask=0 color=""
        if   (( data_mask  != 0 )); then mask=$data_mask;  color=$data_color
        elif (( ideal_mask != 0 )); then mask=$ideal_mask; color="\033[37m"
        elif (( axis_mask  != 0 )); then mask=$axis_mask;  color=$BURNDOWN_AXIS_COLOR
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
            if (( is_axis_row )) && (( cx == now_cell )); then
                printf -v cell "${BURNDOWN_AXIS_COLOR}.\033[0m"
            else
                idx=$(( cy * BURNDOWN_PLOT_W_CELLS + cx ))
                axis_mask=0
                (( cx == 0 ))     && axis_mask=$(( axis_mask | BURNDOWN_AXIS_Y ))
                (( is_axis_row )) && axis_mask=$(( axis_mask | BURNDOWN_AXIS_X ))
                burndown_render_cell cell \
                    "${data_arr[idx]:-0}" "${ideal_arr[idx]:-0}" "$axis_mask" "$data_color"
            fi
            burndown_str+=$cell
        done
    }

    burndown_cy=0
    while (( burndown_cy < BURNDOWN_PLOT_H_CELLS )); do
        burndown_row=$(( 1 + burndown_cy ))
        burndown_target_col=$(( TERM_WIDTH - BURNDOWN_TOTAL_W ))
        burndown_pad=$(( burndown_target_col - row_vw[burndown_row] ))
        (( burndown_pad < SEP )) && burndown_pad=$SEP
        printf -v burndown_str '\033[0m%*s' "$burndown_pad" ""
        burndown_vw=$burndown_pad

        # Left plot: 5hr (red).
        burndown_emit_plot_row "$burndown_cy" br5_data br5_ideal "\033[31m" "$br5_now_cell"
        burndown_vw=$(( burndown_vw + BURNDOWN_PLOT_W_CELLS ))

        # Gap.
        burndown_str+=' '
        burndown_vw=$(( burndown_vw + 1 ))

        # Right plot: 7day (light blue \033[94m).
        burndown_emit_plot_row "$burndown_cy" br7_data br7_ideal "\033[94m" "$br7_now_cell"
        burndown_vw=$(( burndown_vw + BURNDOWN_PLOT_W_CELLS ))

        row_str[burndown_row]+=$burndown_str
        row_vw[burndown_row]=$(( row_vw[burndown_row] + burndown_vw ))
        burndown_cy=$(( burndown_cy + 1 ))
    done
fi

for ((i=0; i<n; i++)); do
    (( i > 0 )) && printf "\n"
    printf '%s' "${row_str[$i]}"
done
