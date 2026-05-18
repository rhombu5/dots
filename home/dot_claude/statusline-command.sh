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
        *github.com*) host_icon=$'\uF1BB' ;;
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

# attrs_prefix <italic:0|1> <strike:0|1>  →  \033[3;9m-style prefix (or empty)
# Stacks before a color escape; \033[0m later resets all attributes.
attrs_prefix() {
    local parts=()
    (( $1 )) && parts+=(3)
    (( $2 )) && parts+=(9)
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
C_BRANCH='\033[35m'        # magenta (col 1 vcs cell)
C_BRANCH_DIM='\033[2;35m'  # dim magenta
C_SEP='\033[2;37m'         # dim white (column separator pipe)

# ── Column 1
declare -a col1_path
col1_path+=("$(repo_root_of "$project_dir")")
for d in "${added_dirs[@]}"; do col1_path+=("$(repo_root_of "$d")"); done

declare -a col1_short
for p in "${col1_path[@]}"; do col1_short+=("$(shorten "$p")"); done

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
    col2_vcs+=("$(vcs_text_for "${col2_path[$j]}")")
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

# If cwd lives inside one of the col-2 worktrees, the col-1 entry that *owns*
# that worktree (its main repo) stays bright too — the "dupe" exception so col 1
# keeps a visual anchor when work has moved into a worktree.
active_wt_origin_idx=-1
for ((j=0; j<${#col2_path[@]}; j++)); do
    wt_real=$(realpath_safe "${col2_path[$j]}")
    if [ "$cwd_real" = "$wt_real" ] || [[ "$cwd_real" == "$wt_real"/* ]]; then
        active_wt_origin_idx=${col2_origin_idx[$j]}
        break
    fi
done

col2_w=0
for s in "${col2_short[@]}"; do (( ${#s} > col2_w )) && col2_w=${#s}; done

n=${#col1_short[@]}
(( ${#col2_path[@]} > n )) && n=${#col2_path[@]}

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
    if (( i == matching_idx || i == active_wt_origin_idx )); then
        c_dir=$(sgr_hue "$hi" 0); c_vcs=$C_BRANCH; dimflag=""
    else
        c_dir=$(sgr_hue "$hi" 1); c_vcs=$C_BRANCH_DIM; dimflag="dim"
    fi

    dir="${col1_short[$i]}"
    cell+=$(printf "${c_dir}%s\033[0m" "$dir")
    cell_w=$(( cell_w + ${#dir} ))

    # Cyan suffix only on the matching row, when cwd is a subdir of it
    if (( i == matching_idx )); then
        krp=$(realpath_safe "${col1_path[$i]}")
        if [ "$cwd_real" != "$krp" ] && [[ "$cwd_real" == "$krp"/* ]]; then
            suffix="/${cwd_real#$krp/}"
            cell+=$(printf "${C_CURRENT}%s\033[0m" "$suffix")
            cell_w=$(( cell_w + ${#suffix} ))
        fi
    fi

    vt="${col1_vcs[$i]}"
    if [ -n "$vt" ]; then
        cell+=$(printf "  ${c_vcs}%s\033[0m" "$vt")
        cell_w=$(( cell_w + 2 + ${#vt} ))
    fi

    pr="${col1_pr[$i]}"
    if [ -n "$pr" ]; then
        read -r pr_state ci_state pr_num <<<"$pr"
        pc=$(color_for_pr "$pr_state" "$dimflag")
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
            # "(merged)" is the common terminal state — suppress to save space.
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
            wt_vcs=$(sgr_hue "$parent_hi" 0); wt_dim=""
        else
            wt_vcs=$(sgr_hue "$parent_hi" 1); wt_dim="dim"
        fi
        italic_flag=0; (( has_subagent )) && italic_flag=1
        strike_flag=0; [ "$pr_state" = "merged" ] && strike_flag=1
        ap=$(attrs_prefix "$italic_flag" "$strike_flag")

        if [ -n "${col2_vcs[$i]}" ]; then
            vt="${col2_vcs[$i]}"
            append "$i" "${#vt}" "${ap}${wt_vcs}%s\033[0m" "$vt"
        fi
        if [ -n "$pr_num" ]; then
            pc=$(color_for_pr "$pr_state" "$wt_dim")
            append "$i" $(( 2 + ${#pr_num} )) "  ${ap}${pc}%s\033[0m" "$pr_num"
            if [ "$pr_state" = "open" ]; then
                cg=$(glyph_for_ci "$ci_state")
                if [ -n "$cg" ]; then
                    cc=$(color_for_ci "$ci_state" "$wt_dim")
                    append "$i" 2 " ${ap}${cc}%s\033[0m" "$cg"
                fi
            elif [ "$pr_state" != "merged" ]; then
                # "(merged)" is conveyed by the strikethrough — suppress the label
                # to save space. Draft/closed still need an explicit word.
                append "$i" $(( 3 + ${#pr_state} )) " ${ap}${pc}(%s)\033[0m" "$pr_state"
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
