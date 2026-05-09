#!/usr/bin/env sh
# hyprmural hook chain — wired via hyprmural.conf:
#
#   hook = ~/.config/hyprmural/hook.sh
#
# Runs both hook scripts on every per-output image change, with
# HYPRMURAL_MONITOR / HYPRMURAL_WORKSPACE / HYPRMURAL_IMAGE in the env.
# Failures in one don't stop the other.
set -u
dir="$(dirname "$0")"
"$dir/accent.py"        || true
"$dir/pill-accents.py"  || true
