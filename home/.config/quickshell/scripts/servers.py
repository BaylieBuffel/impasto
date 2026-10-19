#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   S E R V E R S                                                          │
# │   development servers · the ports listening, and what opened them        │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""The development servers this user has listening, as JSON.

  list              every TCP port in LISTEN held by a process of this user
                    started inside a project under $HOME
  stop PID PORT     end the server that holds PORT, as Ctrl+C would

A project is a directory with a marker in it (package.json, Cargo.toml, a git
checkout…), found by walking up from the process's working directory; a
listener outside one is somebody's daemon and is left out. The sockets come
from `ss`, which shows the owning process only for this user's own.
"""

import json
import os
import signal
import subprocess
import sys
import time

HOME = os.path.realpath(os.path.expanduser("~"))

MARKERS = (
    "package.json", "deno.json", "deno.jsonc", "Cargo.toml", "go.mod",
    "pyproject.toml", "requirements.txt", "manage.py", "Gemfile",
    "composer.json", "mix.exs", "pom.xml", "build.gradle", "build.gradle.kts",
    ".git",
)

# Executables whose first argument is the program actually running.
INTERPRETERS = ("node", "nodejs", "bun", "deno", "python", "ruby", "php")

KINDS = {
    "node": "node", "nodejs": "node", "bun": "node", "deno": "deno",
    "python": "python", "ruby": "ruby", "php": "php", "java": "java",
}

MARKER_KINDS = {
    "Cargo.toml": "rust", "go.mod": "go", "package.json": "node",
    "pyproject.toml": "python", "manage.py": "python",
    "requirements.txt": "python", "Gemfile": "ruby", "composer.json": "php",
    "pom.xml": "java", "build.gradle": "java", "build.gradle.kts": "java",
}


def sockets():
    """(pid, port, host) for every listening TCP socket ss can name."""
    try:
        result = subprocess.run(
            ["ss", "-Hltnp"], capture_output=True, text=True, timeout=5, check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    found = []
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) < 6 or "pid=" not in line:
            continue
        host, _, port = fields[3].rpartition(":")
        if not port.isdigit():
            continue
        host = host.strip("[]").split("%")[0]
        pids = sorted({int(part.split(",")[0]) for part in line.split("pid=")[1:]})
        found.append((pids[0], int(port), host))
    return found


def loopback(host):
    return host.startswith(("127.", "::ffff:127.")) or host in ("::1", "localhost")


def project(cwd):
    """The nearest directory at or above cwd, inside $HOME, with a marker."""
    path = cwd
    while path.startswith(HOME + os.sep):
        for marker in MARKERS:
            if os.path.exists(os.path.join(path, marker)):
                return path, marker
        path = os.path.dirname(path)
    return None, None


def plain(word):
    """A subcommand rather than a flag, a path or a value."""
    return word.isalpha() and word.islower()


def tool(script):
    """What a script path names: the package under node_modules, or the file."""
    parts = os.path.normpath(script).split("/")
    if "node_modules" in parts:
        index = len(parts) - 1 - parts[::-1].index("node_modules")
        rest = parts[index + 1:]
        if rest and rest[0] == ".bin" and len(rest) > 1:
            return rest[1]
        if rest and rest[0].startswith("@") and len(rest) > 1:
            return f"{rest[0]}/{rest[1]}"
        if rest:
            return rest[0]
    return os.path.basename(script)


def runner(name, args):
    """How the server reads to a person: `vite`, `astro dev`, `http.server`."""
    if name.startswith(INTERPRETERS):
        for index, arg in enumerate(args):
            if arg == "-m" and index + 1 < len(args):
                rest = args[index + 2:]
                return args[index + 1] + (f" {rest[0]}" if rest and plain(rest[0]) else "")
            if arg in ("run", "serve", "task") and name.startswith("deno"):
                continue
            if not arg.startswith("-"):
                rest = args[index + 1:]
                return tool(arg) + (f" {rest[0]}" if rest and plain(rest[0]) else "")
        return name
    return name + (f" {args[0]}" if args and plain(args[0]) else "")


def boot_time():
    try:
        with open("/proc/stat", encoding="ascii") as handle:
            for line in handle:
                if line.startswith("btime "):
                    return int(line.split()[1])
    except OSError:
        pass
    return 0


def started(pid, btime):
    """When the process started, in seconds since the epoch."""
    try:
        with open(f"/proc/{pid}/stat", encoding="ascii", errors="replace") as handle:
            fields = handle.read().rpartition(")")[2].split()
        return btime + int(fields[19]) // os.sysconf("SC_CLK_TCK")
    except (OSError, ValueError, IndexError):
        return 0


def describe(pid, btime):
    """The server behind a pid, or None when it is not a project's."""
    try:
        if os.stat(f"/proc/{pid}").st_uid != os.getuid():
            return None
        cwd = os.path.realpath(os.readlink(f"/proc/{pid}/cwd"))
        with open(f"/proc/{pid}/cmdline", "rb") as handle:
            argv = [part.decode(errors="replace") for part in handle.read().split(b"\0") if part]
        exe = os.readlink(f"/proc/{pid}/exe")
    except OSError:
        return None
    root, marker = project(cwd)
    if root is None or not argv:
        return None
    name = os.path.basename(exe).removesuffix(" (deleted)")
    family = next((kind for prefix, kind in KINDS.items() if name.startswith(prefix)), None)
    return {
        "pid": pid,
        "project": os.path.basename(root),
        "path": "~" + root[len(HOME):],
        "runner": runner(name, argv[1:]),
        "kind": family or MARKER_KINDS.get(marker or "", "other"),
        "started": started(pid, btime),
    }


def servers():
    listening = sockets()
    if listening is None:
        return None
    btime = boot_time()
    known, rows = {}, {}
    for pid, port, host in listening:
        if pid not in known:
            known[pid] = describe(pid, btime)
        if known[pid] is None:
            continue
        row = rows.setdefault((pid, port), dict(known[pid], port=port, network=False))
        row["network"] = row["network"] or not loopback(host)
    return sorted(rows.values(), key=lambda row: row["port"])


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def wait(pid, seconds):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if not alive(pid):
            return True
        time.sleep(0.1)
    return not alive(pid)


def stop(pid, port):
    """Interrupt the server's job as a terminal would, then terminate it."""
    listed = servers() or []
    if not any(row["pid"] == pid and row["port"] == port for row in listed):
        return {"error": f"nothing of yours is listening on {port} any more"}
    try:
        group = os.getpgid(pid)
        # Its own job in a terminal: the whole job, npm and all, as Ctrl+C.
        # Otherwise only the process, never a session leader's group or ours.
        if group != os.getsid(pid) and group != os.getpgid(0):
            os.killpg(group, signal.SIGINT)
        else:
            os.kill(pid, signal.SIGINT)
        if not wait(pid, 3):
            os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        return {"stopped": True}
    except PermissionError as error:
        return {"error": str(error)}
    return {"stopped": wait(pid, 2)}


def main():
    verb = sys.argv[1] if len(sys.argv) > 1 else "list"
    if verb == "list":
        print(json.dumps({"servers": servers()}))
    elif verb == "stop" and len(sys.argv) == 4 and sys.argv[2].isdigit() and sys.argv[3].isdigit():
        print(json.dumps(stop(int(sys.argv[2]), int(sys.argv[3]))))
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
