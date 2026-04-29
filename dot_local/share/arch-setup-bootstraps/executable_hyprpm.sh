#!/usr/bin/env zsh
# Bootstraps hyprexpo + hyprgrass on first Hyprland-session shell.
# Self-deletes once both plugins are listed.
#
# WHY THE MARKER:
# `hyprpm update` and `hyprpm add` both invoke sudo internally (rebuild
# plugin DSOs against current Hyprland headers; pacman-install matching
# -dev packages on header drift). With pinpam wired into the sudo PAM
# stack, every such call fires a TPM-PIN prompt. Without a marker, a
# partial-install state (one plugin built, one failed) re-runs hyprpm on
# EVERY new zsh — meaning every new ghostty window prompts for a PIN.
# Unacceptable.
#
# Marker lives in $XDG_RUNTIME_DIR (auto-wiped on logout). Effect:
#   - At most one hyprpm install attempt per Hyprland session.
#   - On full success, the script self-deletes — no future runs.
#   - On failure, the rest of the session no-ops; next login gets one
#     more attempt.
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || ! command -v hyprpm >/dev/null; then
    return 0
fi

_have_hyprexpo=0
_have_hyprgrass=0
hyprpm list 2>/dev/null | grep -q hyprexpo  && _have_hyprexpo=1
hyprpm list 2>/dev/null | grep -q hyprgrass && _have_hyprgrass=1

if (( _have_hyprexpo && _have_hyprgrass )); then
    # Both plugins built. Source post-plugins.d once per session, then
    # self-delete so future shells skip the file entirely.
    for _plug in hyprexpo hyprgrass; do
        if [[ -f "$HOME/.config/hypr/post-plugins.d/$_plug.conf" ]]; then
            hyprctl keyword source "$HOME/.config/hypr/post-plugins.d/$_plug.conf" >/dev/null 2>&1 || true
        fi
    done
    rm -f ~/.local/share/arch-setup-bootstraps/hyprpm.sh
    unset _plug
else
    # At least one plugin missing — try install. Marker prevents the rest
    # of the session's shells from re-attempting and re-PIN-prompting.
    _marker="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/arch-hyprpm-bootstrap.attempted"
    if [[ ! -e "$_marker" ]]; then
        mkdir -p "${_marker%/*}" 2>/dev/null
        : > "$_marker"
        hyprpm update >/dev/null 2>&1 || true
        if (( ! _have_hyprexpo )); then
            hyprpm add https://github.com/hyprwm/hyprland-plugins 2>/dev/null \
                && hyprpm enable hyprexpo 2>/dev/null
        fi
        if (( ! _have_hyprgrass )); then
            hyprpm add https://github.com/horriblename/hyprgrass 2>/dev/null \
                && hyprpm enable hyprgrass 2>/dev/null
        fi
        for _plug in hyprexpo hyprgrass; do
            if hyprpm list 2>/dev/null | grep -q "$_plug" \
               && [[ -f "$HOME/.config/hypr/post-plugins.d/$_plug.conf" ]]; then
                hyprctl keyword source "$HOME/.config/hypr/post-plugins.d/$_plug.conf" >/dev/null 2>&1 || true
            fi
        done
        # Self-delete only if BOTH plugins ended up loaded.
        if hyprpm list 2>/dev/null | grep -q hyprexpo \
           && hyprpm list 2>/dev/null | grep -q hyprgrass; then
            rm -f ~/.local/share/arch-setup-bootstraps/hyprpm.sh
        fi
        unset _plug
    fi
    unset _marker
fi

unset _have_hyprexpo _have_hyprgrass
