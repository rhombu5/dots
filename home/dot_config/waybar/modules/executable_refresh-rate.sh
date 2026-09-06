#!/usr/bin/env bash
# waybar custom module — active refresh rate of the primary display.
# Outputs JSON: {text, tooltip, class}.
# Click toggles 23.98 <-> 60 Hz (same action as Super+Shift+1 / Super+Shift+2).
#
# Refreshed on SIGRTMIN+9, which ~/.local/bin/hypr-refresh-rate raises after
# every mode change, plus a slow poll to catch changes made elsewhere
# (hotplug, nwg-displays, `hyprctl reload`).

set -euo pipefail

readonly OUTPUT=DP-1

rate=$(hyprctl monitors -j 2>/dev/null \
    | jq -r --arg o "$OUTPUT" '.[] | select(.name == $o) | .refreshRate' 2>/dev/null || true)

# Monitor absent (undocked) — empty text so the cell collapses.
if [[ -z "${rate:-}" || "$rate" == "null" ]]; then
    printf '{"text":"","tooltip":"%s not connected","class":"absent"}\n' "$OUTPUT"
    exit 0
fi

# 60.00000 -> "60";  23.98000 -> "23.98".
pretty=$(awk -v r="$rate" 'BEGIN { s = sprintf("%.2f", r); sub(/\.?0+$/, "", s); print s }')

# Anything under 30 Hz is the 24p film mode. Styled distinctly so a mode left
# on by accident is obvious — 23.98 Hz makes the whole desktop feel broken.
if awk -v r="$rate" 'BEGIN { exit !(r < 30) }'; then
    class=film
    note="24p film mode — matches 23.976 fps content"
else
    class=desktop
    note="Desktop mode"
fi

esc() { jq -Rn --arg s "$1" '$s'; }

printf '{"text":%s,"tooltip":%s,"class":"%s"}\n' \
    "$(esc "󰍹  ${pretty} Hz")" \
    "$(esc "${OUTPUT}: ${pretty} Hz"$'\n'"${note}"$'\n'"Click to toggle")" \
    "$class"
