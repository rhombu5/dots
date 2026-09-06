#!/usr/bin/env python3
"""Ensures the VLC settings hardware decode depends on, without managing vlcrc itself.

VLC rewrites the whole 64 KB vlcrc on every exit, so chezmoi cannot own the file
without permanent diff noise. It can own the handful of keys that matter: this
rewrites those in place and leaves every other line untouched, so VLC's own churn
and this repo stop fighting.
"""

import os
import pathlib
import re

# gl is the load-bearing one. The session runs Hyprland, so VLC lives under
# XWayland, where the gl vout defaults its provider to "any" -> GLX. GLX cannot
# carry VAAPI surfaces (glconv_vaapi_x11 needs EGL), so VLC silently negotiates
# hardware decode away and falls back to software — which on this iGPU decodes
# 4K 10-bit HEVC at roughly 0.4x realtime, unwatchably, with nothing in the UI
# saying anything is wrong.
#
# Grouped by the vlcrc section each key belongs to, matching the layout VLC
# writes itself, so a file generated here parses exactly like one VLC produced.
SECTIONS = {
    "[core] # core program": {
        "avcodec-hw": "vaapi",
        "vout": "gl",
        # Belt-and-braces only; the real passthrough fix is the wireplumber rule
        # in dot_config/wireplumber/wireplumber.conf.d/53-hdmi-no-passthrough.conf.
        "spdif": "0",
    },
    "[gl] # OpenGL video output": {
        "gl": "egl_x11",
        "glconv": "glconv_vaapi_x11",
    },
}

KEY_LINE = re.compile(r"^#?([a-z0-9_-]+)=")

config_home = pathlib.Path(os.environ.get("XDG_CONFIG_HOME") or pathlib.Path.home() / ".config")
vlcrc = config_home / "vlc/vlcrc"

wanted = {key: value for keys in SECTIONS.values() for key, value in keys.items()}

# A fresh install has no vlcrc until VLC first exits. A partial file is fine —
# VLC falls back to its own default for every key not named here.
lines = vlcrc.read_text().splitlines() if vlcrc.exists() else []

rewritten = []
seen = set()
for line in lines:
    matched = KEY_LINE.match(line)
    key = matched.group(1) if matched else None
    if key in wanted:
        rewritten.append(f"{key}={wanted[key]}")
        seen.add(key)
    else:
        rewritten.append(line)

# Anything not already present goes under its own section header — inserted
# after the existing header when there is one, appended as a new block when
# there isn't (which is the whole file on a fresh install).
for header, keys in SECTIONS.items():
    missing = [f"{key}={value}" for key, value in keys.items() if key not in seen]
    if not missing:
        continue
    if header in rewritten:
        at = rewritten.index(header) + 1
        rewritten[at:at] = missing
    else:
        rewritten.extend(["", header, *missing])

updated = "\n".join(rewritten).lstrip("\n") + "\n"
if not vlcrc.exists() or vlcrc.read_text() != updated:
    vlcrc.parent.mkdir(parents=True, exist_ok=True)
    vlcrc.write_text(updated)
    print(f"updated {vlcrc}")
