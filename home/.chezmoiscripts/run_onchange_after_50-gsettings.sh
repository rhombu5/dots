#!/usr/bin/env bash
# Applies GSettings that no file in this repo can carry.
#
# dconf is a binary database, not a config file, so chezmoi cannot manage these
# the way it manages everything else — without this script a fresh install gets
# the files but none of the GNOME-side settings that make them visible.
#
# `run_onchange_after_` means: after files are applied, and only re-run when the
# contents of this script change. Adding a setting below is what triggers it.
set -euo pipefail

# dconf writes need a session bus. postinstall runs `chezmoi init --apply` from
# a TTY with no graphical session, where GSettings silently falls back to the
# memory backend and every write is discarded — so re-exec under a private bus
# when there isn't one. This is the difference between working on a fresh
# install and appearing to work.
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && command -v dbus-run-session >/dev/null; then
    # Via `bash "$0"`, not `"$0"` directly: chezmoi feeds run-scripts to an
    # interpreter rather than exec'ing them, so the file has no +x bit and
    # dbus-run-session would die with "Permission denied".
    exec dbus-run-session -- bash "$0" "$@"
fi

if ! command -v gsettings >/dev/null; then
    echo "gsettings not installed — skipping GNOME settings" >&2
    exit 0
fi

installed_schemas=$(gsettings list-schemas)

set_gsetting() {
    local schema=$1 key=$2 value=$3

    # A schema is missing whenever its application isn't installed yet; that's a
    # skip, not a failure, so a partial install still completes.
    if ! grep -qxF "$schema" <<<"$installed_schemas"; then
        echo "schema $schema not installed — skipping $key" >&2
        return 0
    fi
    if [[ "$(gsettings get "$schema" "$key")" == "$value" ]]; then
        return 0
    fi
    gsettings set "$schema" "$key" "$value"
    echo "set $schema $key"
}

# Surfaces the Frame rate column provided by the nautilus-python extension in
# dot_local/share/nautilus-python/extensions/framerate-column.py. Nautilus shows
# an extension column only when it is named in BOTH lists — visible-columns
# decides what is on, column-order decides where it sits.
readonly FRAMERATE_COLUMN="NautilusPython::framerate_column"

set_gsetting org.gnome.nautilus.list-view default-visible-columns \
    "['name', 'size', '${FRAMERATE_COLUMN}', 'date_modified']"
set_gsetting org.gnome.nautilus.list-view default-column-order \
    "['name', 'size', '${FRAMERATE_COLUMN}', 'type', 'owner', 'group', 'permissions', 'mime_type', 'where', 'date_modified', 'date_modified_with_time', 'date_accessed', 'date_created', 'recency', 'starred']"
