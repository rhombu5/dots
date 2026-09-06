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

    rational = probed.stdout.strip().splitlines()
    if not rational:
        return ""
    # Cover art and audio-only containers report "0/0".
    if rational[0].startswith("0/"):
        return ""
    try:
        rate = float(Fraction(rational[0]))
    except (ValueError, ZeroDivisionError):
        return ""
    # 24000/1001 -> "23.976";  30000/1001 -> "29.97";  25/1 -> "25".
    return f"{round(rate, 3):g}"


class FrameRateColumn(GObject.GObject, Nautilus.ColumnProvider, Nautilus.InfoProvider):
    """Adds a "Frame rate" column, populated off the main loop so folders don't freeze."""

    def __init__(self):
        super().__init__()
        # ffprobe has to open and parse the container, which is far too slow to
        # run on Nautilus's main loop — a folder of videos would freeze the
        # window while it walked them.
        self.probe_pool = ThreadPoolExecutor(max_workers=PROBE_WORKERS)
        # Keyed on identity plus mtime and size, so a re-encoded file re-probes
        # instead of showing its old rate forever.
        self.rate_cache = {}
        self.pending_probes = {}

    def get_columns(self):
        return [
            Nautilus.Column(
                name="NautilusPython::framerate_column",
                attribute="framerate",
                label="Frame rate",
                description="Frames per second of the first video stream",
            ),
        ]

    def update_file_info_full(self, provider, handle, closure, file):
        mime_type = file.get_mime_type() or ""
        if file.get_uri_scheme() != "file" or not mime_type.startswith("video/"):
            return Nautilus.OperationResult.COMPLETE

        path = unquote(file.get_uri()[len(FILE_URI_PREFIX):])
        try:
            stat = os.stat(path)
        except OSError:
            return Nautilus.OperationResult.COMPLETE

        cache_key = (path, stat.st_mtime_ns, stat.st_size)
        if cache_key in self.rate_cache:
            file.add_string_attribute("framerate", self.rate_cache[cache_key])
            return Nautilus.OperationResult.COMPLETE

        probe = self.probe_pool.submit(read_frame_rate, path)
        probe.add_done_callback(
            lambda done: GLib.idle_add(
                self.publish_frame_rate, provider, handle, closure, file, cache_key, done.result()
            )
        )
        self.pending_probes[handle] = probe
        return Nautilus.OperationResult.IN_PROGRESS

    def publish_frame_rate(self, provider, handle, closure, file, cache_key, rate):
        """Hands a finished probe back on the main loop, where touching GTK is safe."""
        self.pending_probes.pop(handle, None)
        self.rate_cache[cache_key] = rate
        file.add_string_attribute("framerate", rate)
        Nautilus.info_provider_update_complete_invoke(
            closure,
            provider,
            handle,
            Nautilus.OperationResult.COMPLETE,
        )
        return GLib.SOURCE_REMOVE

    def cancel_update(self, provider, handle):
        probe = self.pending_probes.pop(handle, None)
        if probe is not None:
            probe.cancel()
