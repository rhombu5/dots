# Bootstraps hyprexpo + hyprgrass on first Hyprland-session shell.
# Sourced by ~/.zshrc's `for f in ~/.zshrc.d/*(N); do source "$f"; done` loop.
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
#   - On success, subsequent shells in the same session skip the install
#     block; just re-source the post-plugins configs (cheap, no sudo).
#   - On failure, the rest of the session no-ops; next login gets one
#     more attempt.
#
# This file is chezmoi-managed (rhombu5/dots/dot_zshrc.d/) and is
# idempotent — does not self-delete, so `chezmoi apply` re-applying it
# is a no-op.

if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || ! command -v hyprpm >/dev/null; then
    return 0
fi

_have_hyprexpo=0
_have_hyprgrass=0
hyprpm list 2>/dev/null | grep -q hyprexpo  && _have_hyprexpo=1
hyprpm list 2>/dev/null | grep -q hyprgrass && _have_hyprgrass=1

if (( _have_hyprexpo && _have_hyprgrass )); then
    # Both plugins built. Source post-plugins.d configs once per session
    # (hyprctl is cheap IPC, but no point doing it every shell).
    _src_marker="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/arch-hyprpm-sourced"
    if [[ ! -e "$_src_marker" ]]; then
        mkdir -p "${_src_marker%/*}" 2>/dev/null
        : > "$_src_marker"
        for _plug in hyprexpo hyprgrass; do
            if [[ -f "$HOME/.config/hypr/post-plugins.d/$_plug.conf" ]]; then
                hyprctl keyword source "$HOME/.config/hypr/post-plugins.d/$_plug.conf" >/dev/null 2>&1 || true
            fi
        done
    fi
    unset _src_marker _plug
else
    # At least one plugin missing — try to install. Marker prevents the rest
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
    fi
    unset _marker _plug
fi

unset _have_hyprexpo _have_hyprgrass
