// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S T E A M   D E C K   S E R V I C E                                    │
// │   a deck on the network · its system, its files and its games over ssh   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Everything `deck.py` answers, kept in one place so the window's pages share
// the address, the last reading and the last complaint.
//
// The address lives beside `keys.tsv` in the state directory and `deck.py`
// owns it; this only carries it to and from the window. The connection is
// multiplexed by ssh (`ControlMaster`), so the poll below is a round trip
// rather than a handshake, and nothing here ever prompts: a Deck without this
// machine's key is an error to show, with a way to set one up.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/deck.py")

    // ── THE ADDRESS ─────────────────────────────────────────────────────────

    property var config: ({
        host: "Deck", user: "", port: 0, name: "Steam Deck", key: "", path: ""
    })

    readonly property bool configured: String(root.config.host ?? "") !== ""

    // ── WHAT CAME BACK ──────────────────────────────────────────────────────

    // `status` is the system page's reading; `listing` one directory and its
    // parent; `preview` the head of one text file. All null until asked.
    property var status: null
    property var listing: null
    property var preview: null

    // The library: { games: [{ id, name, size, updated, dir }], libraries, size }.
    property var games: null

    // ssh hosts avahi has seen, and the tool that would have found them.
    property var hosts: []
    property string discoveryTool: ""

    // The last `run`: { line, code, output }.
    property var answer: null

    // ── HOW IT WENT ─────────────────────────────────────────────────────────
    //
    // Two kinds of bad news. `connectionError` is the poll's, shown as a
    // banner and cleared by the next answer; `error` is the last thing asked
    // for and what it said, shown under the page until something else is
    // asked.
    property string connectionError: ""
    property bool reachable: false
    property string error: ""
    property string note: ""

    // The verb in flight, or "". One action at a time: a transfer and a
    // delete must not race, and a page says what it is waiting for. `asked`
    // keeps the verb the last answer belonged to, for the frame where the
    // Process has exited but `active` is already cleared.
    property string active: ""
    property string asked: ""
    readonly property bool busy: root.active !== ""

    // The window sets this while it is open; nothing polls while it is shut.
    property bool watching: false
    property bool discovering: false

    // The address has been read once. Before that the defaults would send the
    // first poll to the wrong host.
    property bool loaded: false

    // ── ASKING ──────────────────────────────────────────────────────────────

    function parse(text): var {
        if (!text || text.trim() === "")
            return null
        try {
            return JSON.parse(text)
        } catch (failure) {
            console.warn("Cannot read the deck's answer:", failure)
            return null
        }
    }

    // The window's own lifetime: config first, then a reading, then a poll.
    function start(): void {
        root.watching = true
        root.error = ""
        root.note = ""
        root.load()
    }

    function stop(): void {
        root.watching = false
        root.active = ""
        root.discovering = false
    }

    function load(): void {
        if (!root.addressing.running)
            root.addressing.running = true
    }

    function save(patch: var): void {
        if (root.saving.running)
            return
        root.error = ""
        root.note = ""
        root.saving.command = [root.script, "save", JSON.stringify(patch ?? {})]
        root.saving.running = true
    }

    function refresh(): void {
        if (!root.configured || root.reading.running)
            return
        root.reading.running = true
    }

    // ── THE FILES ───────────────────────────────────────────────────────────

    function browse(path: string): void {
        if (root.listingReader.running)
            return
        root.error = ""
        root.note = ""
        root.listingReader.command = [root.script, "ls", path ?? ""]
        root.listingReader.running = true
    }

    function up(): void {
        const parent = root.listing ? (root.listing.parent ?? "") : ""
        root.browse(parent)
    }

    // A row: a directory opens, anything else is read as text.
    function open(entry: var): void {
        if (!entry)
            return
        if (entry.dir)
            root.browse(entry.path)
        else
            root.peek(entry.path)
    }

    function peek(path: string): void {
        if (root.peekReader.running)
            return
        root.error = ""
        root.peekReader.command = [root.script, "preview", path]
        root.peekReader.running = true
    }

    function clearPreview(): void {
        root.preview = null
    }

    // ── THE ACTIONS ─────────────────────────────────────────────────────────

    // Every verb that changes something on the Deck goes through one Process,
    // in turn. `deck.py` prints one line of JSON either way.
    function act(verb: string, args: var): void {
        if (root.busy)
            return
        root.error = ""
        root.note = ""
        root.active = verb
        root.asked = verb
        root.actor.command = [root.script, verb].concat(args ?? [])
        root.actor.running = true
    }

    function download(path: string, local: string): void {
        const args = local ? [path, local] : [path]
        root.act("download", args)
    }

    function upload(local: string, path: string): void {
        root.act("upload", [local, path])
    }

    function makeDirectory(path: string, name: string): void {
        root.act("mkdir", [path, name])
    }

    function rename(path: string, name: string, wanted: string): void {
        root.act("rename", [path, name, wanted])
    }

    function remove(path: string): void {
        root.act("remove", [path])
    }

    function launch(appid: string): void {
        root.act("launch", [String(appid)])
    }

    function power(verb: string): void {
        root.act("power", [verb])
    }

    function run(line: string): void {
        root.error = ""
        root.note = ""
        root.active = "run"
        root.asked = "run"
        root.actor.command = [root.script, "run", line]
        root.actor.running = true
    }

    function library(): void {
        if (root.libraryReader.running)
            return
        root.error = ""
        root.libraryReader.running = true
    }

    function discover(): void {
        if (root.finder.running)
            return
        root.discovering = true
        root.error = ""
        root.finder.running = true
    }

    // The key the Deck wants, put there by hand in a terminal: it asks for a
    // password, so it cannot happen here. Same shape as the update's window.
    function askKey(): void {
        const user = String(root.config.user ?? "")
        const host = (user ? user + "@" : "") + String(root.config.host ?? "")
        if (host === "@" || host === "")
            return
        const args = []
        if (Number(root.config.port ?? 0) > 0)
            args.push("-p", String(root.config.port))
        args.push(host)
        Quickshell.execDetached([
            "kitty", "--class", "impasto-deck",
            "--title", "Steam Deck key",
            "sh", "-c",
            'ssh-copy-id "$@"; printf "\\nPress return to close.\\n"; read _',
            "sh"
        ].concat(args))
    }

    // ── THE READING ─────────────────────────────────────────────────────────

    readonly property Process addressing: Process {
        command: [root.script, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const report = root.parse(text)
                if (!report || !report.config)
                    return
                root.config = report.config
                root.loaded = true
                if (root.watching)
                    root.refresh()
            }
        }
    }

    readonly property Process saving: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const report = root.parse(text)
                if (!report)
                    return
                if (report.error) {
                    root.error = report.error
                    return
                }
                if (report.config)
                    root.config = report.config
                root.note = "Saved"
                root.status = null
                root.listing = null
                root.games = null
                root.preview = null
                root.reachable = false
                root.refresh()
            }
        }
    }

    readonly property Process reading: Process {
        command: [root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const report = root.parse(text)
                if (!report) {
                    root.reachable = false
                    root.connectionError = "the deck did not answer"
                    return
                }
                if (report.error) {
                    root.reachable = false
                    root.connectionError = report.error
                    return
                }
                root.status = report
                root.reachable = true
                root.connectionError = ""
            }
        }
    }

    readonly property Timer poll: Timer {
        interval: 15000
        repeat: true
        running: root.watching && root.loaded && root.configured
        onTriggered: root.refresh()
    }

    // ── THE FILES, READ ─────────────────────────────────────────────────────

    readonly property Process listingReader: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const report = root.parse(text)
                if (!report)
                    return
                if (report.error) {
                    root.error = report.error
                    return
                }
                root.listing = report
                root.preview = null
            }
        }
    }

    readonly property Process peekReader: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const report = root.parse(text)
                if (!report)
                    return
                if (report.error) {
                    root.error = report.error
                    return
                }
                root.preview = { path: root.peekReader.command[2] ?? "", text: report.text ?? "" }
            }
        }
    }

    readonly property Process libraryReader: Process {
        command: [root.script, "games"]
        stdout: StdioCollector {
            onStreamFinished: {
                const report = root.parse(text)
                if (!report)
                    return
                if (report.error) {
                    root.error = report.error
                    return
                }
                root.games = report
            }
        }
    }

    readonly property Process finder: Process {
        command: [root.script, "find"]
        stdout: StdioCollector {
            onStreamFinished: {
                const report = root.parse(text)
                root.discovering = false
                if (!report)
                    return
                if (report.error) {
                    root.error = report.error
                    return
                }
                root.hosts = report.hosts ?? []
                root.discoveryTool = report.missing ?? ""
            }
        }
        onExited: root.discovering = false
    }

    // ── THE ACTIONS, ANSWERED ───────────────────────────────────────────────

    readonly property Process actor: Process {
        stdout: StdioCollector {
            onStreamFinished: root.settle(root.asked, text)
        }
        onExited: {
            root.active = ""
            root.asked = ""
        }
    }

    // One place saying what each verb did, so the pages and the footer agree.
    function settle(verb: string, text: string): void {
        const report = root.parse(text)
        if (!report) {
            if (verb !== "")
                root.error = "the deck did not answer"
            return
        }
        if (report.error) {
            root.error = report.error
            return
        }

        if (verb === "download") {
            root.note = "Saved to " + String(report.local ?? "here")
            return
        }
        if (verb === "upload") {
            root.note = "Sent " + root.human(report.size ?? 0)
            root.browse(root.listing ? String(root.listing.path ?? "") : "")
            return
        }
        if (verb === "mkdir" || verb === "rename" || verb === "remove") {
            root.note = {
                mkdir: "Folder made",
                rename: "Renamed",
                remove: "Removed"
            }[verb] ?? "Done"
            root.preview = null
            root.browse(root.listing ? String(root.listing.path ?? "") : "")
            return
        }
        if (verb === "launch") {
            const game = root.gameOf(report.id)
            root.note = game ? "Asking Steam for " + game.name : "Asking Steam for " + String(report.id)
            return
        }
        if (verb === "power") {
            root.note = {
                sleep: "The deck is going to sleep",
                reboot: "The deck is restarting",
                shutdown: "The deck is shutting down"
            }[String(report.asked ?? "")] ?? "Asked"
            root.reachable = false
            return
        }
        if (verb === "run") {
            root.answer = {
                line: root.actor.command[2] ?? "",
                code: Number(report.code ?? 0),
                output: String(report.output ?? "")
            }
            root.note = report.ok ? "Ran" : "Exited " + String(report.code ?? "?")
        }
    }

    // ── THE LIBRARY, LOOKED UP ──────────────────────────────────────────────

    function gameOf(appid: var): var {
        if (!root.games || !root.games.games)
            return null
        const wanted = String(appid)
        return root.games.games.find(game => String(game.id) === wanted) ?? null
    }

    // ── READINGS AS WORDS ───────────────────────────────────────────────────

    function human(bytes: real): string {
        const units = ["B", "KB", "MB", "GB", "TB"]
        let value = Math.max(0, Number(bytes) || 0)
        let index = 0
        while (value >= 1024 && index < units.length - 1) {
            value /= 1024
            index += 1
        }
        const digits = index === 0 ? 0 : (value >= 100 ? 0 : 1)
        return value.toFixed(digits) + " " + units[index]
    }

    // How long the deck has been up, as the system page reads it.
    function since(seconds: int): string {
        let left = Math.max(0, Math.floor(seconds))
        const days = Math.floor(left / 86400)
        left %= 86400
        const hours = Math.floor(left / 3600)
        left %= 3600
        const minutes = Math.floor(left / 60)
        if (days > 0)
            return days + "d " + hours + "h"
        if (hours > 0)
            return hours + "h " + minutes + "m"
        return minutes + "m"
    }

    function stamp(unixSeconds: real): string {
        if (!(unixSeconds > 0))
            return ""
        return Qt.formatDateTime(new Date(unixSeconds * 1000), "d MMM yyyy")
    }

    // ── THE ADDRESS, AS ONE LINE ────────────────────────────────────────────

    readonly property string address: {
        const user = String(root.config.user ?? "")
        const host = String(root.config.host ?? "")
        if (!host)
            return ""
        return user ? user + "@" + host : host
    }
}
