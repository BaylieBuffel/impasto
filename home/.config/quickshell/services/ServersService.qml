// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E R V E R S   S E R V I C E                                          │
// │   development servers · the ports listening, and stopping one            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The servers `servers.py` finds, read only while the panel is open: on
// opening, and every few seconds after, so one started meanwhile appears.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/servers.py")

    property var servers: []
    property bool loaded: false

    readonly property int exposed: root.servers.filter(server => server.network).length

    // The last thing that went wrong, said once on the panel.
    property string error: ""

    // Declared for the island, which is sized before the panel exists.
    readonly property int panelWidth: 620
    readonly property int rowHeight: 76
    readonly property int panelHeight: 81 + Math.max(2, Math.min(6, root.servers.length)) * (root.rowHeight + 8)

    property int watchers: 0

    function subscribe(): void {
        root.watchers += 1
        root.error = ""
        root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    // ── THE LIST ────────────────────────────────────────────────────────────

    readonly property Process lister: Process {
        command: [root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.servers = JSON.parse(text).servers ?? []
                    root.loaded = true
                } catch (error) {
                    console.warn("Cannot read the servers:", error)
                }
            }
        }
    }

    function refresh(): void {
        if (!root.lister.running)
            root.lister.running = true
    }

    readonly property Timer tick: Timer {
        interval: 3000
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    // How long a server has run, from the start `servers.py` reports.
    function uptime(started: int): string {
        if (started <= 0)
            return ""
        const seconds = Math.max(0, Math.floor(Date.now() / 1000) - started)
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor(seconds / 60) % 60
        return hours > 0 ? `${hours}:${String(minutes).padStart(2, "0")} h` : `${minutes} min`
    }

    function url(port: int): string {
        return `http://localhost:${port}`
    }

    function open(port: int): void {
        Qt.openUrlExternally(root.url(port))
    }

    function copy(port: int): void {
        Quickshell.execDetached(["wl-copy", "--", root.url(port)])
    }

    // ── STOPPING ────────────────────────────────────────────────────────────

    // The port being stopped, until the script answers.
    property int stopping: 0

    readonly property Process stopper: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const reply = JSON.parse(text)
                    if (reply.error)
                        root.error = reply.error
                } catch (error) {}
            }
        }
        onExited: {
            root.stopping = 0
            root.refresh()
        }
    }

    function stop(pid: int, port: int): void {
        if (root.stopper.running)
            return
        root.error = ""
        root.stopping = port
        root.stopper.command = [root.script, "stop", String(pid), String(port)]
        root.stopper.running = true
    }
}
