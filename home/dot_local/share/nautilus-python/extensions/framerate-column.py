"""Nautilus column showing a video file's frame rate, probed with ffprobe."""

import collections
import os
from fractions import Fraction
from urllib.parse import unquote

from gi.repository import Gio, GLib, GObject, Nautilus

# Everything here runs on the GLib main loop, and must. Nautilus's main thread
# holds the GIL while idle in the GTK main loop, so a Python worker thread blocks
# re-acquiring it and resumes only when Nautilus next calls into the extension —
# i.e. when the user navigates. A thread pool therefore cannot drive this work:
# probes appear to take exactly as long as the user happens to wait.
MAX_CONCURRENT_PROBES = 4
PROBE_TIMEOUT_SECONDS = 15
FILE_URI_PREFIX = "file://"
ATTRIBUTE = "framerate"

# Nautilus calls the info provider before it has necessarily sniffed a file's
# MIME type, and which files have resolved theirs differs per visit — gating on
# MIME alone probes a random subset and leaves the rest blank.
VIDEO_SUFFIXES = frozenset(
    ".mkv .mp4 .m4v .avi .mov .webm .mpg .mpeg .wmv .flv .ts .m2ts .mts .ogv .3gp .divx .vob".split()
)


def parse_frame_rate(reported):
    """Turns ffprobe's r_frame_rate rational into a display string, or "" if unusable."""
    lines = reported.strip().splitlines()
    # Cover art and audio-only containers report "0/0".
    if not lines or lines[0].startswith("0/"):
        return ""
    try:
        rate = float(Fraction(lines[0]))
    except (ValueError, ZeroDivisionError):
        return ""
    # 24000/1001 -> "23.976";  30000/1001 -> "29.97";  25/1 -> "25".
    return f"{round(rate, 3):g}"


class FrameRateColumn(GObject.GObject, Nautilus.ColumnProvider, Nautilus.InfoProvider):
    """Adds a "Frame rate" column, probed asynchronously on the GLib main loop."""

    def __init__(self):
        super().__init__()
        # Keyed on identity plus mtime and size, so a re-encode re-probes rather
        # than showing a stale rate. Only successful reads are cached, so a
        # transient failure can't blank a file permanently.
        self.rate_cache = {}
        # Nautilus issues one handle per in-flight update. Holding provider,
        # closure and file alive until completion is mandatory — if any is
        # finalized first, update_complete_invoke silently does nothing.
        self.in_flight = {}
        # Cache keys already queued or running. Nautilus re-asks for the same
        # file repeatedly, and each ask would otherwise spawn another ffprobe.
        self.probing = set()
        self.queued = collections.deque()
        self.running = 0

    def get_columns(self):
        return [
            Nautilus.Column(
                name="NautilusPython::framerate_column",
                attribute=ATTRIBUTE,
                label="Frame rate",
                description="Frames per second of the first video stream",
            ),
        ]

    def update_file_info_full(self, provider, handle, closure, file):
        if file.get_uri_scheme() != "file":
            return Nautilus.OperationResult.COMPLETE

        path = unquote(file.get_uri()[len(FILE_URI_PREFIX):])
        mime_type = file.get_mime_type() or ""
        if not (mime_type.startswith("video/") or os.path.splitext(path)[1].lower() in VIDEO_SUFFIXES):
            return Nautilus.OperationResult.COMPLETE

        try:
            stat = os.stat(path)
        except OSError:
            return Nautilus.OperationResult.COMPLETE

        cache_key = (path, stat.st_mtime_ns, stat.st_size)
        if cache_key in self.rate_cache:
            file.add_string_attribute(ATTRIBUTE, self.rate_cache[cache_key])
            return Nautilus.OperationResult.COMPLETE

        if cache_key in self.probing:
            # Already queued or running; the result will be cached and picked up
            # by one of Nautilus's later queries.
            file.add_string_attribute(ATTRIBUTE, "")
            return Nautilus.OperationResult.COMPLETE

        self.probing.add(cache_key)
        self.in_flight[handle] = (provider, closure, file)
        self.queued.append((handle, cache_key, path))
        self.start_ready_probes()
        # Nautilus repaints the row when update_complete_invoke fires; it does
        # not repaint an extension column for invalidate_extension_info().
        return Nautilus.OperationResult.IN_PROGRESS

    def start_ready_probes(self):
        """Launches queued probes up to the concurrency limit."""
        while self.queued and self.running < MAX_CONCURRENT_PROBES:
            handle, cache_key, path = self.queued.popleft()
            try:
                probe = Gio.Subprocess.new(
                    [
                        "ffprobe",
                        "-v", "error",
                        "-select_streams", "v:0",
                        "-show_entries", "stream=r_frame_rate",
                        "-of", "default=nw=1:nk=1",
                        path,
                    ],
                    Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE,
                )
            except GLib.Error:
                self.finish_probe(cache_key, handle, "")
                continue

            self.running += 1
            # Nothing in Gio bounds a child's runtime, so a wedged ffprobe would
            # otherwise hold its row in-progress forever.
            timeout = GLib.timeout_add_seconds(PROBE_TIMEOUT_SECONDS, self.kill_probe, probe)
            probe.communicate_utf8_async(None, None, self.on_probe_finished, (cache_key, handle, timeout))

    def kill_probe(self, probe):
        probe.force_exit()
        return GLib.SOURCE_REMOVE

    def on_probe_finished(self, probe, result, user_data):
        """Runs on the main loop, so touching Nautilus here is safe."""
        cache_key, handle, timeout = user_data
        GLib.source_remove(timeout)
        self.running -= 1
        try:
            completed, stdout, _ = probe.communicate_utf8_finish(result)
            rate = parse_frame_rate(stdout or "") if completed else ""
        except GLib.Error:
            rate = ""
        self.finish_probe(cache_key, handle, rate)
        self.start_ready_probes()

    def finish_probe(self, cache_key, handle, rate):
        """Caches the result and completes the row, whether or not the update was cancelled."""
        self.probing.discard(cache_key)
        # Cache before the cancellation check: Nautilus cancels updates
        # constantly, and the result is just as valid either way.
        if rate:
            self.rate_cache[cache_key] = rate
        pending = self.in_flight.pop(handle, None)
        if pending is None:
            return
        provider, closure, file = pending
        try:
            file.add_string_attribute(ATTRIBUTE, rate)
            Nautilus.info_provider_update_complete_invoke(
                closure,
                provider,
                handle,
                Nautilus.OperationResult.COMPLETE,
            )
        except BaseException:
            # A finalized file or revoked closure must not take the extension
            # down with it; the value is cached either way.
            pass

    def cancel_update(self, provider, handle):
        # Drops only the completion handshake — the probe keeps running so its
        # result still lands in the cache for the next query.
        self.in_flight.pop(handle, None)
