#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   D E C K                                                                │
# │   a steam deck on the network · files, system, games and power over ssh  │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""A Steam Deck on the local network, managed over ssh.

  get                     the saved address, as JSON
  save JSON               write the address: {"host", "user", "port", "name"}
  status                  battery, temperatures, memory, disks, the session
  ls [PATH]               one directory, its entries as JSON
  download PATH [LOCAL]   copy a file here, into ~/Downloads by default
  upload LOCAL PATH       copy a file to the Deck
  mkdir PATH NAME         make a directory
  rename PATH NAME NEW    rename a file or directory beside itself
  remove PATH             delete a file or directory
  preview PATH            the first 256 KB of a text file
  games                   the installed Steam library, with sizes
  launch APPID            start a game through the running Steam client
  power VERB              sleep, reboot or shutdown
  run LINE                run a shell line on the Deck and return its output
  find                    ssh hosts advertised on the network

Every answer is one line of JSON: `{"ok": true, …}` or `{"error": "…"}`. The
address lives in the state directory beside `keys.tsv`, and the connection is
multiplexed (`ControlMaster`), so polling costs a round trip rather than a
handshake. Nothing here prompts: a Deck without this machine's key is an
error to report, and the window offers to set one up in a terminal.
"""

import json
import os
import posixpath
import shlex
import shutil
import subprocess
import sys

HOME = os.path.expanduser("~")
STATE = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.join(HOME, ".local", "state"),
    "quickshell",
)
CONFIG = os.path.join(STATE, "deck.json")
SOCKET = os.path.join(STATE, "deck-%C")

# `host` is whatever ssh is given: an alias from `~/.ssh/config` (the usual
# `Host Deck`) or an address. `user` and `port` are added only when they are
# set, so an alias keeps its own account, port and identity file.
DEFAULTS = {
    "host": "Deck",
    "user": "",
    "port": 0,
    "name": "Steam Deck",
    "key": "",
    "path": "",
}

# One `ssh` invocation per call, a shell on the far end and key=value lines
# back. Kept as a script rather than a chain of commands so quoting is never
# in the way, and so every field is read in the same round trip.
PROBE = r'''
say() { printf '%s=%s\n' "$1" "$2"; }
say host "$(hostname 2>/dev/null)"
say kernel "$(uname -r 2>/dev/null)"
say product "$(cat /sys/class/dmi/id/product_name 2>/dev/null)"
say board "$(cat /sys/class/dmi/id/board_name 2>/dev/null)"
if [ -r /etc/os-release ]; then
    . /etc/os-release
    say os "$PRETTY_NAME"
    say build "$BUILD_ID"
fi
say home "$HOME"
say account "$(id -un)"
say uptime "$(cut -d. -f1 /proc/uptime 2>/dev/null)"
say cores "$(nproc 2>/dev/null)"
read -r load _ < /proc/loadavg 2>/dev/null && say load "$load"
say memtotal "$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo 2>/dev/null)"
say memavail "$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo 2>/dev/null)"
say swaptotal "$(awk '/^SwapTotal:/ { print $2 }' /proc/meminfo 2>/dev/null)"
say swapfree "$(awk '/^SwapFree:/ { print $2 }' /proc/meminfo 2>/dev/null)"
say steam "$(pgrep -x steam >/dev/null 2>&1 && echo 1 || echo 0)"
say gamescope "$(pgrep -x gamescope >/dev/null 2>&1 && echo 1 || echo 0)"
for battery in /sys/class/power_supply/BAT*; do
    [ -e "$battery" ] || continue
    say battery "$(cat "$battery/capacity" 2>/dev/null)"
    say charging "$(cat "$battery/status" 2>/dev/null)"
    say energynow "$(cat "$battery/energy_now" 2>/dev/null)"
    say energyfull "$(cat "$battery/energy_full" 2>/dev/null)"
    say chargenow "$(cat "$battery/charge_now" 2>/dev/null)"
    say chargefull "$(cat "$battery/charge_full" 2>/dev/null)"
    say voltage "$(cat "$battery/voltage_now" 2>/dev/null)"
    say current "$(cat "$battery/current_now" 2>/dev/null)"
    say powernow "$(cat "$battery/power_now" 2>/dev/null)"
    break
done
for supply in /sys/class/power_supply/A*; do
    [ -e "$supply" ] || continue
    say ac "$(cat "$supply/online" 2>/dev/null)"
    break
done
for sensor in /sys/class/hwmon/hwmon*; do
    name=$(cat "$sensor/name" 2>/dev/null) || continue
    [ -n "$name" ] || continue
    for input in "$sensor"/temp*_input; do
        [ -e "$input" ] || continue
        label=$(cat "${input%_input}_label" 2>/dev/null)
        [ -n "$label" ] || label=$(basename "$input" _input)
        say "temp:$name:$label" "$(( $(cat "$input" 2>/dev/null) / 1000 ))"
    done
    for input in "$sensor"/fan*_input; do
        [ -e "$input" ] || continue
        say "fan:$name" "$(cat "$input" 2>/dev/null)"
    done
    if [ "$name" = "amdgpu" ]; then
        say apu "$(cat "$sensor/power1_average" 2>/dev/null)"
    fi
    if [ "$name" = "steamdeck_hwmon" ]; then
        say chargelimit "$(cat "$sensor/max_battery_charge_level" 2>/dev/null)"
    fi
done
for net in /sys/class/net/wlan*; do
    [ -e "$net" ] || continue
    say wifi "$(cat "$net/operstate" 2>/dev/null)"
    say ssid "$(iw dev "$(basename "$net")" link 2>/dev/null | sed -n 's/^[[:space:]]*SSID: //p')"
    break
done
say signal "$(awk '/wlan/ { gsub(/\./, "", $3); print $3 }' /proc/net/wireless 2>/dev/null | head -n 1)"
df -kP 2>/dev/null | awk 'NR > 1 && ($6 == "/" || $6 == "/home" || $6 ~ /^\/run\/media\//) { printf "disk:%s=%s|%s|%s|%s\n", $6, $2, $3, $4, $5 }'
'''

# The libraries, then one line per installed game: its id, size, when it was
# last updated, its install directory and its name. Read straight from the
# manifests Steam leaves in every library, so a game installed on the microSD
# is here too.
GAMES = r'''
steamapps="$HOME/.steam/steam/steamapps"
printf 'library\t%s\n' "$steamapps"
folders="$steamapps/libraryfolders.vdf"
if [ -r "$folders" ]; then
    sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$folders" |
        while IFS= read -r library; do
            printf 'library\t%s/steamapps\n' "$library"
        done
fi
for library in "$steamapps" $(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$folders" 2>/dev/null); do
    library="$library/steamapps"
    for manifest in "$library"/appmanifest_*.acf; do
        [ -r "$manifest" ] || continue
        appid=$(sed -n 's/^[[:space:]]*"appid"[[:space:]]*"\([0-9][0-9]*\)".*/\1/p' "$manifest" | head -n 1)
        [ -n "$appid" ] || continue
        name=$(sed -n 's/^[[:space:]]*"name"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$manifest" | head -n 1)
        size=$(sed -n 's/^[[:space:]]*"SizeOnDisk"[[:space:]]*"\([0-9][0-9]*\)".*/\1/p' "$manifest" | head -n 1)
        updated=$(sed -n 's/^[[:space:]]*"LastUpdated"[[:space:]]*"\([0-9][0-9]*\)".*/\1/p' "$manifest" | head -n 1)
        install=$(sed -n 's/^[[:space:]]*"installdir"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$manifest" | head -n 1)
        printf 'game\t%s\t%s\t%s\t%s\t%s\n' \
            "$appid" "${size:-0}" "${updated:-0}" "${install:-}" "$name"
    done
done
'''


# ── THE ADDRESS ─────────────────────────────────────────────────────────────


def config():
    stored = {}
    try:
        with open(CONFIG, encoding="utf-8") as handle:
            stored = json.load(handle)
    except (OSError, ValueError):
        stored = {}
    merged = dict(DEFAULTS)
    for key in DEFAULTS:
        if key in stored:
            merged[key] = stored[key]
    return merged


def clean(word, fallback=""):
    """A host or account name, with anything that could be read as a flag
    taken out. The address is always passed as one ssh argument, never as a
    command, so this is about mistakes rather than injection."""
    text = str(word or "").strip()[:64]
    for character in " \t\r\n'\"`$;&|<>()":
        text = text.replace(character, "")
    if text.startswith("-"):
        text = text.lstrip("-")
    return text or fallback


def write_config(patch):
    current = config()
    for key in DEFAULTS:
        if key not in patch:
            continue
        value = patch[key]
        if key == "port":
            try:
                value = max(0, min(65535, int(value or 0)))
            except (TypeError, ValueError):
                value = current["port"]
        elif key == "key":
            value = str(value or "").strip()
        elif key == "path":
            value = str(value or "").strip()
        elif key == "name":
            value = " ".join(str(value or "").split())[:40] or DEFAULTS["name"]
        else:
            value = clean(value, DEFAULTS[key])
        current[key] = value
    os.makedirs(STATE, exist_ok=True)
    with open(CONFIG, "w", encoding="utf-8") as handle:
        json.dump(current, handle, indent=2)
        handle.write("\n")
    return current


# ── THE CONNECTION ──────────────────────────────────────────────────────────


class Result:
    """What one ssh invocation returned, with the parts the callers read."""

    def __init__(self, code, out, err):
        self.code = code
        self.out = out
        self.err = err

    @property
    def ok(self):
        return self.code == 0

    @property
    def said(self):
        return self.out.decode(errors="replace")

    @property
    def complained(self):
        return self.err.decode(errors="replace").strip()


def target(settings):
    return ("%s@%s" % (settings["user"], settings["host"])
            if settings["user"] else settings["host"])


def connection(batch=True):
    settings = config()
    args = [
        "ssh",
        "-T",
        "-o", "BatchMode=" + ("yes" if batch else "no"),
        "-o", "ConnectTimeout=6",
        "-o", "ServerAliveInterval=5",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "ControlMaster=auto",
        "-o", "ControlPath=" + SOCKET,
        "-o", "ControlPersist=120",
        "-o", "LogLevel=ERROR",
    ]
    if settings["port"]:
        args += ["-p", str(settings["port"])]
    if settings["key"]:
        args += ["-i", os.path.expanduser(settings["key"])]
    args += [target(settings)]
    return args


def ssh(command, data=None, timeout=30, batch=True):
    settings = config()
    if not settings["host"]:
        return Result(2, b"", b"no deck is set")
    args = connection(batch) + [command]
    try:
        done = subprocess.run(
            args, input=data, capture_output=True, timeout=timeout, check=False,
        )
    except subprocess.TimeoutExpired:
        return Result(124, b"", b"the deck did not answer in time")
    except OSError as error:
        return Result(127, b"", str(error).encode())
    return Result(done.returncode, done.stdout, done.stderr)


def complaint(result):
    """The useful half of what ssh said, as a sentence for the window."""
    text = result.complained
    if "Permission denied" in text or "no matching host key" in text:
        return "the deck refused this machine's key"
    if "Could not resolve hostname" in text:
        return "that name does not resolve on this network"
    if "No route to host" in text or "Connection refused" in text:
        return "the deck is not answering — is sshd on?"
    if "Connection timed out" in text or "timed out" in text:
        return "the deck is not answering — is it awake and on this network?"
    if "Host key verification failed" in text:
        return "the deck's host key changed since last time"
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    return lines[-1] if lines else "ssh exited with %s" % result.code


def remote(path):
    return shlex.quote(path)


# ── THE SYSTEM ──────────────────────────────────────────────────────────────


def number(value, fallback=0):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return fallback


def megabytes(reading):
    return round(number(reading) / 1048576, 1)


def gigabytes(reading):
    return round(number(reading) / 1048576, 1)


def status():
    result = ssh("bash -s", data=PROBE.encode(), timeout=20)
    if not result.ok:
        return {"error": complaint(result)}

    pairs, disks = {}, []
    for line in result.said.splitlines():
        key, _, value = line.partition("=")
        if not key:
            continue
        if key.startswith("disk:"):
            total, used, free, percent = (value.split("|") + ["", "", "", ""])[:4]
            disks.append({
                "mount": key[5:],
                "total": gigabytes(total),
                "used": gigabytes(used),
                "free": gigabytes(free),
                "percent": number(percent.replace("%", "")),
            })
            continue
        pairs[key] = value

    temperatures, temps, fans = [], [], []
    for key, value in pairs.items():
        if key.startswith("temp:"):
            _, source, label = key.split(":", 2)
            temps.append({"source": source, "label": label, "value": number(value)})
        elif key.startswith("fan:"):
            fans.append(number(value))

    cpu_sources = ("k10temp", "zenpower", "coretemp", "acpitz")
    order = {name: index for index, name in enumerate(cpu_sources)}
    temps.sort(key=lambda entry: (order.get(entry["source"], len(order)), entry["label"]))

    cpu_temp = next((entry["value"] for entry in temps
                     if entry["source"] in cpu_sources), None)
    gpu_temp = next((entry["value"] for entry in temps
                     if entry["source"] in ("amdgpu", "radeon")), None)

    battery = None
    if "battery" in pairs:
        # A Deck reports charge (µAh) and voltage (µV); some drivers report
        # energy (µWh) instead. Both are Wh once divided by 10¹².
        voltage = number(pairs.get("voltage"))
        energy = number(pairs.get("energynow"))
        charge = number(pairs.get("chargenow"))
        full_energy = number(pairs.get("energyfull"))
        full_charge = number(pairs.get("chargefull"))
        watts = number(pairs.get("powernow")) / 1000000
        if not watts and voltage:
            watts = number(pairs.get("current")) * voltage / 1e12
        watt_hours = energy / 1000000 if energy else charge * voltage / 1e12
        full_hours = full_energy / 1000000 if full_energy else full_charge * voltage / 1e12
        battery = {
            "percent": number(pairs.get("battery")),
            "status": pairs.get("charging", ""),
            "charging": pairs.get("charging", "") in ("Charging", "Full"),
            "plugged": pairs.get("ac") == "1",
            "watts": round(watts, 1),
            "wh": round(watt_hours, 1),
            "full": round(full_hours, 1),
            "limit": number(pairs.get("chargelimit")),
        }

    total = number(pairs.get("memtotal"))
    available = number(pairs.get("memavail"))
    swap = number(pairs.get("swaptotal"))
    swap_free = number(pairs.get("swapfree"))

    return {
        "ok": True,
        "host": pairs.get("host", ""),
        "os": pairs.get("os", ""),
        "build": pairs.get("build", ""),
        "kernel": pairs.get("kernel", ""),
        "product": pairs.get("product", ""),
        "board": pairs.get("board", ""),
        "account": pairs.get("account", ""),
        "home": pairs.get("home", "/home/deck"),
        "uptime": number(pairs.get("uptime")),
        "session": "game" if pairs.get("gamescope") == "1" else "desktop",
        "steam": pairs.get("steam") == "1",
        "battery": battery,
        "cpu": {
            "load": float(pairs.get("load") or 0),
            "cores": number(pairs.get("cores"), 1),
            "temp": cpu_temp,
            "watts": round(number(pairs.get("apu")) / 1000000, 1),
        },
        "gpu": {"temp": gpu_temp},
        "memory": {
            "total": round(total / 1048576, 1),
            "used": round((total - available) / 1048576, 1),
            "swap_total": round(swap / 1048576, 1),
            "swap_used": round((swap - swap_free) / 1048576, 1),
        },
        "temperatures": temps,
        "fan": max(fans) if fans else 0,
        "disks": disks,
        "wifi": {
            "state": pairs.get("wifi", ""),
            "ssid": pairs.get("ssid", ""),
            "signal": number(pairs.get("signal")),
        },
    }


# ── THE FILES ───────────────────────────────────────────────────────────────


def listing(path):
    if path.startswith("-"):
        return {"error": "that is not a path"}
    where = remote(path) if path else '"$HOME"'
    script = (
        'cd -- ' + where + ' || exit 3; '
        'printf "at\\t%s\\n" "$PWD"; '
        'find . -mindepth 1 -maxdepth 1 '
        '-printf "%f\\0%y\\0%s\\0%T@\\0%l\\0"'
    )
    # bash explicitly: the Deck's login shell is fish, and this is written
    # as sh.
    result = ssh("bash -c " + remote(script), timeout=20)
    if not result.ok:
        if result.code == 3:
            return {"error": "no such directory on the deck"}
        return {"error": complaint(result)}

    head, _, body = result.out.partition(b"\n")
    at = head.decode(errors="replace").partition("\t")[2] or path or "/"
    fields = body.split(b"\0")
    entries = []
    for index in range(0, len(fields) - 4, 5):
        name = fields[index].decode(errors="replace")
        if not name:
            continue
        kind, size, modified, target = (
            fields[index + 1].decode(errors="replace"),
            number(fields[index + 2]),
            number(fields[index + 3]),
            fields[index + 4].decode(errors="replace"),
        )
        entries.append({
            "name": name,
            "path": posixpath.join(at, name),
            "dir": kind == "d",
            "link": kind == "l",
            "target": target,
            "size": size,
            "modified": modified,
            "hidden": name.startswith("."),
        })
    entries.sort(key=lambda entry: (not entry["dir"], entry["name"].lower()))
    parent = posixpath.dirname(at)
    return {
        "ok": True,
        "path": at,
        "parent": "" if parent == at else parent,
        "entries": entries,
    }


def safe(path):
    """Refuse the paths a mis-click must never reach: a home directory, a
    system directory, or anything nearer the root than one folder inside a
    home. A tree is only ever removed from three levels down."""
    text = posixpath.normpath(str(path or ""))
    if not text.startswith("/"):
        return None
    if len([part for part in text.split("/") if part]) < 3:
        return None
    if text in ("/home", "/root", "/usr", "/etc", "/var", "/boot", "/run",
                "/srv", "/opt", "/nix", "/bin", "/lib", "/dev", "/proc",
                "/sys", "/tmp", "/snap"):
        return None
    return text


def download(path, local=""):
    target = os.path.expanduser(local) if local else downloads_dir()
    if local and os.path.isdir(target):
        target = os.path.join(target, posixpath.basename(path))
    os.makedirs(os.path.dirname(target), exist_ok=True)
    target = free_name(target)
    try:
        with open(target, "wb") as handle:
            result = subprocess.run(
                ssh_command(["cat", "--", path]), stdout=handle,
                stderr=subprocess.PIPE, timeout=180, check=False,
            )
    except (OSError, subprocess.TimeoutExpired) as error:
        return {"error": str(error)}
    if result.returncode != 0:
        try:
            os.unlink(target)
        except OSError:
            pass
        return {"error": complaint(Result(result.returncode, b"", result.stderr))}
    return {"ok": True, "local": target, "size": os.path.getsize(target)}


def downloads_dir():
    try:
        with open(os.path.join(HOME, ".config", "user-dirs.dirs"), encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("XDG_DOWNLOAD_DIR="):
                    value = line.split("=", 1)[1].strip().strip('"')
                    value = value.replace("$HOME", HOME)
                    return value
    except OSError:
        pass
    return os.path.join(HOME, "Downloads")


def free_name(path):
    if not os.path.exists(path):
        return path
    stem, extension = os.path.splitext(path)
    for index in range(2, 1000):
        candidate = "%s %d%s" % (stem, index, extension)
        if not os.path.exists(candidate):
            return candidate
    return path


def upload(local, path):
    source = os.path.expanduser(local)
    if not os.path.isfile(source):
        return {"error": "no such file here"}
    destination = posixpath.join(path, os.path.basename(source))
    with open(source, "rb") as handle:
        result = subprocess.run(
            ssh_command(["sh", "-c", "cat > " + remote(destination)]),
            stdin=handle, capture_output=True, timeout=300, check=False,
        )
    if result.returncode != 0:
        return {"error": complaint(Result(result.returncode, b"", result.stderr))}
    return {"ok": True, "path": destination, "size": os.path.getsize(source)}


def ssh_command(argv):
    """The ssh argv for a command given as words, quoted for the far shell."""
    command = " ".join(remote(word) for word in argv)
    return connection() + [command]


def make_directory(path, name):
    if not name or "/" in name or name in (".", ".."):
        return {"error": "that is not a name for a folder"}
    destination = posixpath.join(path, name)
    result = ssh("mkdir -p -- " + remote(destination))
    if not result.ok:
        return {"error": complaint(result)}
    return {"ok": True, "path": destination}


def rename(path, name, new):
    if not new or "/" in new or new in (".", ".."):
        return {"error": "that is not a name for a file"}
    source = posixpath.join(path, name)
    destination = posixpath.join(path, new)
    result = ssh("mv -- " + remote(source) + " " + remote(destination))
    if not result.ok:
        return {"error": complaint(result)}
    return {"ok": True, "path": destination}


def remove(path):
    target = safe(path)
    if target is None:
        return {"error": "refusing to delete that"}
    result = ssh("rm -rf -- " + remote(target))
    if not result.ok:
        return {"error": complaint(result)}
    return {"ok": True, "path": target}


def preview(path):
    result = ssh("head -c 262144 -- " + remote(path))
    if not result.ok:
        return {"error": complaint(result)}
    if b"\0" in result.out:
        return {"error": "that is not a text file"}
    return {"ok": True, "text": result.out.decode(errors="replace")}


# ── THE LIBRARY ─────────────────────────────────────────────────────────────


def games():
    result = ssh("bash -s", data=GAMES.encode(), timeout=45)
    if not result.ok:
        return {"error": complaint(result)}

    libraries, found = [], {}
    for line in result.said.splitlines():
        fields = line.split("\t")
        if fields[0] == "library" and len(fields) > 1:
            if fields[1] and fields[1] not in libraries:
                libraries.append(fields[1])
        elif fields[0] == "game" and len(fields) > 5:
            appid = fields[1]
            found[appid] = {
                "id": appid,
                "name": fields[5],
                "size": number(fields[2]),
                "updated": number(fields[3]),
                "dir": fields[4],
            }

    ordered = sorted(found.values(), key=lambda game: game["name"].lower())
    return {
        "ok": True,
        "games": ordered,
        "libraries": libraries,
        "size": sum(game["size"] for game in ordered),
    }


def launch(appid):
    if not str(appid).isdigit():
        return {"error": "that is not an app id"}
    command = "DISPLAY=:0 steam steam://rungameid/" + appid
    result = ssh("bash -lc " + remote(command), timeout=20)
    if not result.ok:
        return {"error": complaint(result)}
    return {"ok": True, "id": appid}


def power(verb):
    commands = {
        "sleep": "systemctl suspend",
        "reboot": "sudo -n systemctl reboot",
        "shutdown": "sudo -n systemctl poweroff",
    }
    if verb not in commands:
        return {"error": "unknown power verb"}
    result = ssh(commands[verb], timeout=10)
    # A reboot takes the connection with it, which reads as an ssh failure
    # with nothing to say; the command itself was delivered.
    if not result.ok and result.code not in (124, 255):
        return {"error": complaint(result)}
    return {"ok": True, "asked": verb}


def run(line):
    if not line.strip():
        return {"error": "nothing to run"}
    result = ssh("bash -lc " + remote(line), timeout=120)
    output = result.said + result.complained
    return {
        "ok": result.ok,
        "code": result.code,
        "output": output[-200000:],
    }


# ── THE NETWORK ─────────────────────────────────────────────────────────────


def find():
    """ssh hosts avahi has seen, which is how the Deck announces itself."""
    if not shutil.which("avahi-browse"):
        return {"ok": True, "hosts": [], "missing": "avahi-browse"}
    try:
        result = subprocess.run(
            ["avahi-browse", "-rtp", "_ssh._tcp"],
            capture_output=True, text=True, timeout=10, check=False,
        )
    except (OSError, subprocess.SubprocessError) as error:
        return {"error": str(error)}

    hosts, seen = [], set()
    for line in result.stdout.splitlines():
        if not line.startswith("="):
            continue
        fields = line.split(";")
        if len(fields) < 9:
            continue
        name, address, port = fields[3], fields[7], fields[8]
        label = fields[6] or name
        if not address or address in seen:
            continue
        seen.add(address)
        hosts.append({
            "name": name,
            "host": label,
            "address": address,
            "port": number(port, 22),
        })
    hosts.sort(key=lambda entry: entry["name"].lower())
    return {"ok": True, "hosts": hosts}


# ── THE DOOR ────────────────────────────────────────────────────────────────


def main():
    verb = sys.argv[1] if len(sys.argv) > 1 else "get"

    if verb == "get":
        answer({"ok": True, "config": config()})
    elif verb == "save":
        patch = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
        answer({"ok": True, "config": write_config(patch)})
    elif verb == "status":
        answer(status())
    elif verb == "ls":
        answer(listing(sys.argv[2] if len(sys.argv) > 2 else ""))
    elif verb == "download" and len(sys.argv) > 2:
        answer(download(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else ""))
    elif verb == "upload" and len(sys.argv) > 3:
        answer(upload(sys.argv[2], sys.argv[3]))
    elif verb == "mkdir" and len(sys.argv) > 3:
        answer(make_directory(sys.argv[2], sys.argv[3]))
    elif verb == "rename" and len(sys.argv) > 4:
        answer(rename(sys.argv[2], sys.argv[3], sys.argv[4]))
    elif verb == "remove" and len(sys.argv) > 2:
        answer(remove(sys.argv[2]))
    elif verb == "preview" and len(sys.argv) > 2:
        answer(preview(sys.argv[2]))
    elif verb == "games":
        answer(games())
    elif verb == "launch" and len(sys.argv) > 2:
        answer(launch(sys.argv[2]))
    elif verb == "power" and len(sys.argv) > 2:
        answer(power(sys.argv[2]))
    elif verb == "run" and len(sys.argv) > 2:
        answer(run(sys.argv[2]))
    elif verb == "find":
        answer(find())
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)


def answer(payload):
    print(json.dumps(payload))


if __name__ == "__main__":
    try:
        main()
    except (KeyError, ValueError) as error:
        answer({"error": "cannot read that: %s" % error})
        sys.exit(1)
