# arch-setup: dispatch any pending bootstraps from
# ~/.local/share/arch-setup-bootstraps/. Each script self-checks its own
# precondition and self-deletes on success. Runner is a no-op when the
# directory is gone (everything has bootstrapped).
#
# Scripts and their preconditions:
#   first-login.sh         — TTY login; bw + gh first-time auth.
#   ssh-signing.sh         — gh authed AND Bitwarden SSH-agent socket exposes a key.
#   hyprpm.sh              — inside a Hyprland session.
#   cloud-storage-auth.sh  — TTY login; Dropbox link + rclone gdrive OAuth + bisync seed.
#
# Fires per-shell so each precondition gets a chance the moment it's first
# met. Each script handles its own re-entrancy (hyprpm.sh uses an
# $XDG_RUNTIME_DIR marker to dedupe within a single session).
if [[ -n "${_POSTINSTALL_NONINTERACTIVE:-}" ]]; then
    return 0
fi
_bootstrap_dir="$HOME/.local/share/arch-setup-bootstraps"
if [[ -d "$_bootstrap_dir" ]]; then
    for _bs in "$_bootstrap_dir"/*.sh(N); do
        source "$_bs"
    done
    # Once the dir is empty, prune it to keep $HOME tidy. chezmoi will
    # recreate it (and any scripts not yet self-deleted) on next apply.
    if [[ -z "$(ls -A "$_bootstrap_dir" 2>/dev/null)" ]]; then
        rmdir "$_bootstrap_dir" 2>/dev/null
    fi
fi
unset _bs _bootstrap_dir
