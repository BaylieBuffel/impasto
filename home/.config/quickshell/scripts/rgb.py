#!/usr/bin/env python3
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   R G B                                                                  │
# │   the desk's lighting · keyboard, mouse and case fans from the palette   │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Drive the desk's lighting from the palette.

    apply [JSON] [brightness]  the keyboard's, the mouse's and the case fans'
                               colour, taken from the palette (or from
                               dynamic-colors.json when no JSON is given);
                               the fans' brightness dims their colour
    brightness N               the case fans' brightness, 0-100
    devices                    the OpenRGB devices found, as JSON

The keyboard goes through sk80ctl, which recolours the effect it is already
showing without touching the mode, speed or brightness. The mouse and the case
fans go through OpenRGB: a "Mouse" device, and a "Motherboard" device whose
RGB headers the fans sit on. The fans are switched to the board's Static
effect first, since its own rainbow otherwise wins over the colour;
IMPASTO_RGB_FANS_MODE names another mode. Set IMPASTO_RGB_MOUSE or
IMPASTO_RGB_FANS to a name fragment to pick a device by name instead. A device
that is not plugged in, or a tool that is not installed, is skipped; a mode the
controller does not offer is reported on stderr rather than counted as painted.
Nothing here is fatal.
"""

import json
import os
import re
import shutil
import subprocess
import sys

XDG_STATE_HOME = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
STATE_DIR = os.path.join(XDG_STATE_HOME, "quickshell")
COLORS_FILE = os.path.join(STATE_DIR, "dynamic-colors.json")
# The accent last painted, so the brightness slider knows which colour to dim
# without the shell having to hand it over on every step.
APPLIED_FILE = os.path.join(STATE_DIR, "rgb.json")

# OpenRGB device types for the two devices that are not the keyboard. The
# environment variables let a name fragment win over the type.
MOUSE_TYPE = "Mouse"
FAN_TYPE = "Motherboard"

# The fans must be put in a mode that shows the colour handed to them; the
# board's own effect (a rainbow) otherwise wins. "Static" is MSI's constant
# effect, which holds one colour. The mouse is left in whatever direct mode it
# already uses.
FAN_MODE = os.environ.get("IMPASTO_RGB_FANS_MODE", "Static")
MOUSE_MODE = os.environ.get("IMPASTO_RGB_MOUSE_MODE", "")

TIMEOUT = 20


def run(command):
    try:
        return subprocess.run(command, capture_output=True, text=True, timeout=TIMEOUT)
    except (OSError, subprocess.SubprocessError) as error:
        sys.stderr.write(f"{command[0]} failed: {error}\n")
        return None


def load_colors(argument):
    if argument:
        try:
            return json.loads(argument)
        except ValueError as error:
            sys.stderr.write(f"Cannot read the palette: {error}\n")
            return None
    try:
        with open(COLORS_FILE, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def accent_of(colors):
    value = (colors or {}).get("accent")
    if not isinstance(value, str) or not re.fullmatch(r"#?[0-9A-Fa-f]{6}", value):
        return None
    return value.lstrip("#").upper()


def remember(accent):
    os.makedirs(STATE_DIR, exist_ok=True)
    try:
        with open(APPLIED_FILE, "w", encoding="utf-8") as handle:
            json.dump({"accent": accent}, handle)
    except OSError as error:
        sys.stderr.write(f"Cannot save the last colour: {error}\n")


def last_accent():
    try:
        with open(APPLIED_FILE, encoding="utf-8") as handle:
            accent = json.load(handle).get("accent")
    except (OSError, ValueError):
        accent = None
    if isinstance(accent, str) and re.fullmatch(r"[0-9A-Fa-f]{6}", accent):
        return accent.upper()
    return accent_of(load_colors(None))


def dimmed(accent, percent):
    """The accent at a percentage, channel by channel.

    OpenRGB's own brightness is a mode flag several controllers, MSI's
    included, do not offer; scaling the colour dims anything that takes a
    colour.
    """
    factor = percent / 100
    channels = (round(int(accent[index:index + 2], 16) * factor) for index in (0, 2, 4))
    return "".join(f"{channel:02X}" for channel in channels)


def openrgb_devices():
    """OpenRGB's devices, from a list that reads as `N: name` and `Type: ...`."""
    if not shutil.which("openrgb"):
        return []
    result = run(["openrgb", "--list-detailed"])
    if result is None or result.returncode != 0:
        return []

    found = []
    current = None
    for line in result.stdout.splitlines():
        head = re.match(r"^(\d+):\s+(.+)$", line)
        if head:
            current = {"index": int(head.group(1)), "name": head.group(2).strip(), "type": ""}
            found.append(current)
            continue
        kind = re.match(r"^\s+Type:\s+(.+)$", line)
        if kind and current is not None:
            current["type"] = kind.group(1).strip()
    return found


def pick(devices, variable, wanted_type):
    name = os.environ.get(variable, "").strip().lower()
    if name:
        return next((device for device in devices if name in device["name"].lower()), None)
    return next((device for device in devices if device["type"] == wanted_type), None)


def apply_keyboard(accent):
    tool = shutil.which("sk80ctl")
    if not tool:
        return False
    # No --mode: the effect the keyboard is showing is kept, only its colour
    # changes. An unplugged keyboard exits non-zero, which is not an error.
    result = run([tool, "lighting", "--color", accent])
    return result is not None and result.returncode == 0


def paint(device, colour, mode):
    """Set one device's colour, and its mode first when one is named.

    OpenRGB exits 0 even when it refuses a mode or a colour — the only sign is
    the ``Error:`` line it prints — so its output is what says whether this
    worked. The message is passed on: a board whose modes are named differently
    is a reason to set IMPASTO_RGB_FANS_MODE, not a silent nothing.
    """
    command = ["openrgb", "--device", device["name"]]
    if mode:
        command += ["--mode", mode]
    command += ["--color", colour]
    result = run(command)
    if result is None:
        return False
    for line in (result.stdout + result.stderr).splitlines():
        if line.startswith("Error:"):
            sys.stderr.write(f"{device['name']}: {line.removeprefix('Error:').strip()}\n")
            return False
    return result.returncode == 0


def apply_openrgb(devices, accent, fan_colour):
    applied = []
    for variable, wanted_type, what, colour, mode in (
            ("IMPASTO_RGB_MOUSE", MOUSE_TYPE, "mouse", accent, MOUSE_MODE),
            ("IMPASTO_RGB_FANS", FAN_TYPE, "case fans", fan_colour, FAN_MODE)):
        device = pick(devices, variable, wanted_type)
        if device is None:
            continue
        if paint(device, colour, mode):
            applied.append(what)
    return applied


def clamp_brightness(value):
    try:
        return max(0, min(100, int(value)))
    except (TypeError, ValueError):
        return None


def set_brightness(value):
    percent = clamp_brightness(value)
    if percent is None:
        sys.stderr.write(f"Not a brightness: {value}\n")
        return 1
    accent = last_accent()
    if accent is None:
        sys.stderr.write("No palette has been applied yet\n")
        return 1
    device = pick(openrgb_devices(), "IMPASTO_RGB_FANS", FAN_TYPE)
    if device is None:
        sys.stderr.write("No case-fan controller found\n")
        return 1
    return 0 if paint(device, dimmed(accent, percent), FAN_MODE) else 1


def apply(colors, brightness):
    accent = accent_of(colors)
    if accent is None:
        sys.stderr.write("The palette has no accent colour\n")
        return 1
    remember(accent)

    percent = clamp_brightness(brightness)
    if percent is None:
        percent = 100

    applied = []
    if apply_keyboard(accent):
        applied.append("keyboard")
    applied += apply_openrgb(openrgb_devices(), accent, dimmed(accent, percent))

    if applied:
        print(f"Applied #{accent} to the {', '.join(applied)}")
    return 0


def main():
    actions = "apply [JSON] [brightness] | brightness N | devices"
    if len(sys.argv) < 2:
        sys.stderr.write(f"Usage: rgb.py {actions}\n")
        return 1

    action = sys.argv[1]
    if action == "apply":
        colors = load_colors(sys.argv[2] if len(sys.argv) >= 3 else None)
        if colors is None:
            return 1
        brightness = sys.argv[3] if len(sys.argv) >= 4 else None
        return apply(colors, brightness)
    if action == "brightness" and len(sys.argv) >= 3:
        return set_brightness(sys.argv[2])
    if action == "devices":
        print(json.dumps(openrgb_devices()))
        return 0

    sys.stderr.write(f"Unknown action: {action}\n")
    return 1


if __name__ == "__main__":
    sys.exit(main())
