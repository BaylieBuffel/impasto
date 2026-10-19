#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   S C R E E N T I M E                                                    │
# │   screen time · the window in front, kept by the day                     │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Time spent in each application, recorded and reported as JSON.

  record               read the shell's events on stdin and write them down
  report VIEW DATE     day, week or month around DATE (YYYY-MM-DD)
  summary              today's report, and the seconds per class of the
                       seven days up to it

`record` is told what happens, one line each, and keeps the clock itself:

  focus CLASS          the window in front changed; empty for none
  away                 locked, or the screen gone off for idle
  back                 in use again
  unlock               the session was unlocked
  notify APP           a notification arrived

Only the window class is kept, never a title. A day is one file in
$XDG_STATE_HOME/quickshell/screentime/, a line per span (`s start end class`),
unlock (`u time`) and notification (`n time app`). A span is written when it
ends and at least every five minutes, so a crash loses at most that; a clock
that jumps (a suspend nobody locked for) ends the span where it stopped.
"""

import datetime
import fcntl
import json
import os
import re
import select
import signal
import sys
import time

CHECKPOINT = 300
TICK = 30
# More than this between two ticks is time the process did not run.
GAP = TICK * 2 + 15
# Spans of one class this close together are one session.
JOIN = 10
KEEP_DAYS = 400


def directory():
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    path = os.path.join(base, "quickshell", "screentime")
    os.makedirs(path, exist_ok=True)
    return path


def day_of(moment):
    return datetime.date.fromtimestamp(moment)


def midnight_after(moment):
    day = day_of(moment) + datetime.timedelta(days=1)
    return datetime.datetime.combine(day, datetime.time()).timestamp()


def clean(text):
    return " ".join(text.replace("\t", " ").split())[:120]


# ── RECORD ──────────────────────────────────────────────────────────────────


class Recorder:
    def __init__(self):
        self.path = directory()
        self.window = ""
        self.away = False
        self.start = None
        self.last_tick = time.time()

    def append(self, moment, line):
        target = os.path.join(self.path, f"{day_of(moment).isoformat()}.tsv")
        with open(target, "a", encoding="utf-8") as handle:
            fcntl.flock(handle, fcntl.LOCK_EX)
            handle.write(line + "\n")

    def close(self, end):
        """Write the open span up to END, split at midnight."""
        start, self.start = self.start, None
        if start is None:
            return
        while end - start >= 1:
            stop = min(end, midnight_after(start))
            if stop - start >= 1:
                self.append(start, f"s\t{start:.0f}\t{stop:.0f}\t{self.window}")
            start = stop

    def open(self, moment):
        if not self.away and self.start is None:
            self.start = moment

    def handle(self, line):
        now = time.time()
        verb, _, rest = line.rstrip("\n").partition(" ")
        if verb == "focus":
            if clean(rest) != self.window:
                self.close(now)
                self.window = clean(rest)
                self.open(now)
        elif verb == "away":
            self.close(now)
            self.away = True
        elif verb == "back":
            self.away = False
            self.open(now)
        elif verb == "unlock":
            self.append(now, f"u\t{now:.0f}")
        elif verb == "notify":
            self.append(now, f"n\t{now:.0f}\t{clean(rest)}")

    def tick(self):
        now = time.time()
        if now - self.last_tick > GAP and self.start is not None:
            self.close(self.last_tick)
            self.open(now)
        elif self.start is not None and now - self.start >= CHECKPOINT:
            self.close(now)
            self.open(now)
        self.last_tick = now


def prune():
    limit = datetime.date.today() - datetime.timedelta(days=KEEP_DAYS)
    for name in os.listdir(directory()):
        try:
            if datetime.date.fromisoformat(name.removesuffix(".tsv")) < limit:
                os.remove(os.path.join(directory(), name))
        except (ValueError, OSError):
            continue


def record():
    recorder = Recorder()
    prune()

    def finish(*_):
        recorder.close(time.time())
        sys.exit(0)

    signal.signal(signal.SIGTERM, finish)
    signal.signal(signal.SIGHUP, finish)
    # Read raw, so a second line already waiting is not hidden in a buffer
    # `select` cannot see.
    stream = sys.stdin.fileno()
    pending = b""
    while True:
        ready, _, _ = select.select([stream], [], [], TICK)
        recorder.tick()
        if not ready:
            continue
        chunk = os.read(stream, 4096)
        if not chunk:
            finish()
        pending += chunk
        *lines, pending = pending.split(b"\n")
        for line in lines:
            recorder.handle(line.decode("utf-8", "replace"))


# ── REPORT ──────────────────────────────────────────────────────────────────


def read_day(day):
    """Spans, unlocks and notifications written for DAY."""
    spans, unlocks, notes = [], [], []
    try:
        with open(os.path.join(directory(), f"{day.isoformat()}.tsv"), encoding="utf-8") as handle:
            for line in handle:
                fields = line.rstrip("\n").split("\t")
                try:
                    if fields[0] == "s" and len(fields) == 4:
                        spans.append((float(fields[1]), float(fields[2]), fields[3]))
                    elif fields[0] == "u":
                        unlocks.append(float(fields[1]))
                    elif fields[0] == "n" and len(fields) == 3:
                        notes.append(fields[2])
                except ValueError:
                    continue
    except OSError:
        pass
    spans.sort()
    return spans, unlocks, notes


def first_day():
    days = []
    for name in os.listdir(directory()):
        try:
            days.append(datetime.date.fromisoformat(name.removesuffix(".tsv")))
        except ValueError:
            continue
    return min(days) if days else None


def sessions(spans):
    """Spans of one class joined across the seams the recorder cut."""
    joined = []
    for start, end, window in spans:
        if joined and joined[-1][2] == window and start - joined[-1][1] <= JOIN:
            joined[-1][1] = max(joined[-1][1], end)
        else:
            joined.append([start, end, window])
    return joined


def add(table, key, seconds):
    table[key] = table.get(key, 0) + seconds


def by_hour(spans):
    """Seconds per class in each of the day's hours."""
    hours = [{} for _ in range(24)]
    for start, end, window in spans:
        while end - start > 0:
            moment = datetime.datetime.fromtimestamp(start)
            boundary = (moment.replace(minute=0, second=0, microsecond=0)
                        + datetime.timedelta(hours=1)).timestamp()
            stop = min(end, boundary)
            add(hours[moment.hour], window, stop - start)
            start = stop
    return hours


def period(view, day):
    if view == "week":
        start = day - datetime.timedelta(days=day.weekday())
        return start, start + datetime.timedelta(days=6)
    if view == "month":
        start = day.replace(day=1)
        following = (start + datetime.timedelta(days=32)).replace(day=1)
        return start, following - datetime.timedelta(days=1)
    return day, day


def previous(view, start):
    if view == "month":
        return period("month", start - datetime.timedelta(days=1))
    length = 7 if view == "week" else 1
    begin = start - datetime.timedelta(days=length)
    return begin, begin + datetime.timedelta(days=length - 1)


def dates(start, end):
    while start <= end:
        yield start
        start += datetime.timedelta(days=1)


def total_of(start, end):
    return sum(e - s for d in dates(start, end) for s, e, _ in read_day(d)[0])


def average_of(start, end, since, today):
    """Mean daily total over the days of START..END on record and not ahead."""
    counted = [d for d in dates(start, end) if since and since <= d <= today]
    return total_of(start, end) / len(counted) if counted else 0


STEAM_LIBRARIES = (
    "~/.local/share/Steam/steamapps",
    "~/.steam/steam/steamapps",
    "~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps",
)


def steam_name(window):
    """A Steam game's name, from its manifest: the class is only its id."""
    found = re.fullmatch(r"steam_app_(\d+)", window)
    if not found:
        return None
    for library in STEAM_LIBRARIES:
        path = os.path.join(os.path.expanduser(library), f"appmanifest_{found[1]}.acf")
        try:
            with open(path, encoding="utf-8", errors="replace") as handle:
                named = re.search(r'^\s*"name"\s+"(.*)"\s*$', handle.read(), re.MULTILINE)
        except OSError:
            continue
        if named:
            return named[1]
    return None


def report(view, day):
    today = datetime.date.today()
    since = first_day()
    start, end = period(view, day)

    days, classes, notifications = [], {}, {}
    heat = [[0] * 24 for _ in range(7)]
    chart, longest, unlocks = [], None, 0
    counted = 0
    for date in dates(start, end):
        spans, opened, notes = read_day(date)
        hours = by_hour(spans)
        total = sum(e - s for s, e, _ in spans)
        if since and since <= date <= today:
            counted += 1
        unlocks += len(opened)
        for app in notes:
            add(notifications, app, 1)
        per_class = {}
        for s, e, window in spans:
            add(per_class, window, e - s)
            add(classes, window, e - s)
        for hour, table in enumerate(hours):
            heat[date.weekday()][hour] += sum(table.values())
        for session in sessions(spans):
            if longest is None or session[1] - session[0] > longest[1] - longest[0]:
                longest = session
        days.append({
            "date": date.isoformat(),
            "total": round(total),
            "unlocks": len(opened),
            "notifications": len(notes),
            "first": round(spans[0][0]) if spans else 0,
        })
        chart.append({k: round(v) for k, v in per_class.items()})

    total = sum(d["total"] for d in days)
    names = {window: steam_name(window) for window in classes}
    reply = {
        "view": view,
        "date": day.isoformat(),
        "from": start.isoformat(),
        "to": end.isoformat(),
        "today": today.isoformat(),
        "since": since.isoformat() if since else "",
        "total": total,
        "average": round(total / counted) if counted else 0,
        "classes": {k: round(v) for k, v in classes.items()},
        "notifications": notifications,
        "names": {window: name for window, name in names.items() if name},
        "unlocks": unlocks,
        "days": days,
        "longest": {"seconds": round(longest[1] - longest[0]), "class": longest[2],
                    "start": round(longest[0])} if longest else None,
    }

    before = previous(view, start)
    reply["previous"] = round(total_of(*before))
    # Daily averages, so a month under way is not set against a whole one.
    reply["previousAverage"] = round(average_of(*before, since, today))
    if view == "day":
        spans = read_day(day)[0]
        reply["chart"] = [{k: round(v) for k, v in h.items()} for h in by_hour(spans)]
        reply["sessions"] = [[round(s), round(e), w] for s, e, w in sessions(spans)]
        # The day against the week before it, counting only days on record.
        week = [d for d in dates(day - datetime.timedelta(days=7), day - datetime.timedelta(days=1))
                if since and d >= since]
        reply["baseline"] = round(sum(total_of(d, d) for d in week) / len(week)) if week else 0
    else:
        reply["chart"] = chart
        reply["heat"] = [[round(v) for v in row] for row in heat]
    return reply


def summary():
    today = datetime.date.today()
    reply = report("day", today)
    recent = []
    for date in dates(today - datetime.timedelta(days=6), today):
        per_class = {}
        for start, end, window in read_day(date)[0]:
            add(per_class, window, end - start)
        recent.append({"date": date.isoformat(), "total": round(sum(per_class.values())),
                       "classes": {k: round(v) for k, v in per_class.items()}})
    reply["recent"] = recent
    return reply


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "record":
        record()
        return
    if len(sys.argv) == 2 and sys.argv[1] == "summary":
        print(json.dumps(summary()))
        return
    if len(sys.argv) == 4 and sys.argv[1] == "report" and sys.argv[2] in ("day", "week", "month"):
        try:
            day = datetime.date.fromisoformat(sys.argv[3])
        except ValueError:
            print(json.dumps({"error": f"Not a date: {sys.argv[3]}"}))
            sys.exit(1)
        print(json.dumps(report(sys.argv[2], day)))
        return
    sys.stderr.write(__doc__ or "")
    sys.exit(2)


if __name__ == "__main__":
    main()
