#!/usr/bin/env bash
# Claude Code status line — mirrors p10k left (dir + git) + right (user@host, time, model, context)
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# user@host
user=$(whoami)
host=$(hostname -s)

# Shorten cwd: replace $HOME with ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Git branch (skip index lock to avoid stalling)
branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree --no-optional-locks &>/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
             || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Assemble the line with ANSI colors (terminal will dim them)
# cyan user@host | yellow cwd | magenta git branch | white model | green/yellow context
printf "\033[36m%s@%s\033[0m  \033[33m%s\033[0m" "$user" "$host" "$short_cwd"

if [ -n "$branch" ]; then
    printf "  \033[35m(%s)\033[0m" "$branch"
fi

if [ -n "$model" ]; then
    printf "  \033[37m%s\033[0m" "$model"
fi

if [ -n "$used" ]; then
    used_int=$(printf '%.0f' "$used")
    if [ "$used_int" -ge 80 ]; then
        printf "  \033[31mctx:%s%%\033[0m" "$used_int"
    elif [ "$used_int" -ge 50 ]; then
        printf "  \033[33mctx:%s%%\033[0m" "$used_int"
    else
        printf "  \033[32mctx:%s%%\033[0m" "$used_int"
    fi
fi
