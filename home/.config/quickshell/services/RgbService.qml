// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   R G B   S E R V I C E                                                  │
// │   the desk's lighting · keyboard, mouse and case fans                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pushes the palette's accent to the hardware: the keyboard through sk80ctl,
// the mouse and the fans on the motherboard's RGB headers through OpenRGB.
// `rgb.py` finds the devices and skips what is not plugged in, so nothing here
// needs to know which ones the machine has.
//
// The fans' brightness is a control centre block of its own; it is kept apart
// from the palette so it can be set without changing the wallpaper.
QtObject {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/rgb.py")

    // The last palette pushed, so turning the setting back on repaints the
    // hardware without waiting for the next wallpaper.
    property var lastColors: null
    property bool again: false

    function apply(colors: var): void {
        if (colors)
            root.lastColors = colors
        if (!root.lastColors || !SettingsService.rgbLighting || !SettingsService.arrived)
            return
        if (root.applyProcess.running) {
            root.again = true
            return
        }
        root.applyProcess.command = [root.script, "apply",
            JSON.stringify(root.lastColors), String(SettingsService.rgbFanBrightness)]
        root.applyProcess.running = true
    }

    readonly property Process applyProcess: Process {
        onExited: {
            if (root.again) {
                root.again = false
                root.apply(root.lastColors)
            }
        }
    }

    // Whether the palette paints the hardware, and the level of the fans.
    readonly property Connections settings: Connections {
        target: SettingsService

        function onRgbLightingChanged(): void {
            if (SettingsService.rgbLighting)
                root.apply(root.lastColors)
        }

        // A profile switch or a slider move. The first write at login also
        // restores the saved level.
        function onRgbFanBrightnessChanged(): void {
            root.flushBrightness()
        }
    }

    // ── FAN BRIGHTNESS ──────────────────────────────────────────────────────
    //
    // OpenRGB answers one write at a time and a drag asks faster than that,
    // so only the newest level waits for the one in flight.

    property int written: -1

    function setFanBrightness(value: int): void {
        const level = Math.max(0, Math.min(100, value))
        if (level !== SettingsService.rgbFanBrightness)
            SettingsService.set("rgbFanBrightness", level)
        root.flushBrightness()
    }

    function flushBrightness(): void {
        const level = SettingsService.rgbFanBrightness
        if (root.brightnessProcess.running || level === root.written)
            return
        root.written = level
        root.brightnessProcess.command = [root.script, "brightness", String(level)]
        root.brightnessProcess.running = true
    }

    readonly property Process brightnessProcess: Process {
        // The level may have moved while this write ran.
        onExited: exitCode => {
            // A failure is not retried in a loop: the next move asks again.
            if (exitCode !== 0)
                root.written = -1
            else
                Qt.callLater(root.flushBrightness)
        }
    }
}
