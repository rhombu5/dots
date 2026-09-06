"""Nautilus column showing a video file's frame rate, probed with ffprobe."""

import os
import subprocess
from concurrent.futures import ThreadPoolExecutor
from fractions import Fraction
from urllib.parse import unquote

from gi.repository import GLib, GObject, Nautilus

PROBE_WORKERS = 4
PROBE_TIMEOUT_SECONDS = 5
FILE_URI_PREFIX = "file://"
ATTRIBUTE = "framerate"

# Nautilus calls update_file_info before it has necessarily sniffed a file's MIME
# type, and which files have resolved theirs differs on every visit to a folder.
# Gating on MIME alone therefore probes a random subset and leaves the rest
# permanently blank, so the extension falls back to the name.
VIDEO_SUFFIXES = frozenset(
    ".mkv .mp4 .m4v .avi .mov .webm .mpg .mpeg .wmv .flv .ts .m2ts .mts .ogv .3gp .divx .vob".split()
)


def read_frame_rate(path):
    """Returns the first video stream's frame rate as a display string, or "" if unreadable."""
    try:
        probed = subprocess.run(
            [
                "ffprobe",
                "-v", "error",
                "-select_streams", "v:0",
                "-show_entries", "stream=r_frame_rate",
                "-of", "default=nw=1:nk=1",
                path,
            ],
            capture_output=True,
            text=True,
            timeout=PROBE_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.SubprocessError):
        return ""

    reported = probed.stdout.strip().splitlines()
    # Cover art and audio-only containers report "0/0".
    if not reported or reported[0].startswith("0/"):
        return ""
    try:
        rate = float(Fraction(reported[0]))
    except (ValueError, ZeroDivisionError):
        return ""
    # 24000/1001 -> "23.976";  30000/1001 -> "29.97";  25/1 -> "25".
    return f"{round(rate, 3):g}"


class FrameRateColumn(GObject.GObject, Nautilus.ColumnProvider, Nautilus.InfoProvider):
    """Adds a "Frame rate" column, probed off the main loop so folders don't freeze."""

    def __init__(self):
        super().__init__()
        # ffprobe has to open and parse the container, far too slow for the main
        # loop — a folder of videos would freeze the window while it walked them.
        self.probe_pool = ThreadPoolExecutor(max_workers=PROBE_WORKERS)
        # Keyed on identity plus mtime and size, so a re-encode re-probes instead
        # of showing its old rate forever. Failures cache as "" too, which is what
        # stops a re-query loop.
        self.rate_cache = {}
        # Maps an in-flight cache key to the FileInfo it belongs to. This is a
        # strong reference on purpose: without one the object can be finalized
        # before the probe lands, and invalidate_extension_info() on a dead file
        # silently does nothing.
        self.probing = {}

    def get_columns(self):
        return [
            Nautilus.Column(
                name="NautilusPython::framerate_column",
                attribute=ATTRIBUTE,
                label="Frame rate",
                description="Frames per second of the first video stream",
            ),
        ]

    def update_file_info(self, file):
        if file.get_uri_scheme() != "file":
            return

        path = unquote(file.get_uri()[len(FILE_URI_PREFIX):])
        mime_type = file.get_mime_type() or ""
        is_video = mime_type.startswith("video/") or os.path.splitext(path)[1].lower() in VIDEO_SUFFIXES
        if not is_video:
            return
        try:
            stat = os.stat(path)
        except OSError:
            return
        cache_key = (path, stat.st_mtime_ns, stat.st_size)

        if cache_key in self.rate_cache:
            file.add_string_attribute(ATTRIBUTE, self.rate_cache[cache_key])
            return

        # Nothing to show on this pass. The probe below calls
        # invalidate_extension_info() when it lands, which makes Nautilus ask
        # again — and that second call takes the cache branch above.
        file.add_string_attribute(ATTRIBUTE, "")
        if cache_key in self.probing:
            return
        self.probing[cache_key] = file
        self.probe_pool.submit(self.probe_then_refresh, file, cache_key, path)

    def probe_then_refresh(self, file, cache_key, path):
        """Runs one probe on a worker thread and re-queries the row from the main loop."""
        rate = read_frame_rate(path)

        def publish():
            self.rate_cache[cache_key] = rate
            self.probing.pop(cache_key, None)
            # Touching GTK is only safe here, on the main loop.
            file.invalidate_extension_info()
            return GLib.SOURCE_REMOVE

        GLib.idle_add(publish)
