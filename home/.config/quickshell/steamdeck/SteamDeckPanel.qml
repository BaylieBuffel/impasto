// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S T E A M   D E C K   P A N E L                                        │
// │   the deck's window · a header, five pages and a line under them         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// │ ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../components"
import "../services"
import "../theme"

// The window's contents. One row says whose Deck this is and whether it is
// answering, the strip switches pages, and the line below says what the last
// thing asked for did.
//
// Every page is built once and hidden, rather than rebuilt on each switch:
// the file browser would otherwise lose its directory and the connection form
// would lose what was typed into it.
FocusScope {
    id: root

    signal closed()

    readonly property var pages: [
        { id: "overview",   label: Tr.t("Overview"),   icon: "󰻠" },
        { id: "files",      label: Tr.t("Files"),      icon: "󰉋" },
        { id: "games",      label: Tr.t("Games"),      icon: "󰊴" },
        { id: "system",     label: Tr.t("System"),     icon: "󰆍" },
        { id: "connection", label: Tr.t("Connection"), icon: "󰆏" }
    ]

    property string page: "overview"

    // What the last thing asked for is doing, while it happens. The verbs are
    // the script's names; this is what they are, said once.
    readonly property var doing: ({
        download: Tr.t("Saving the file…"),
        upload: Tr.t("Sending the file…"),
        mkdir: Tr.t("Making the folder…"),
        rename: Tr.t("Renaming…"),
        remove: Tr.t("Removing…"),
        launch: Tr.t("Asking Steam…"),
        power: Tr.t("Asking the deck…"),
        run: Tr.t("Running…")
    })

    // Focus on open, so Escape and the page's own keys arrive here first.
    Component.onCompleted: {
        root.forceActiveFocus()
        SteamDeckService.start()
    }

    Component.onDestruction: SteamDeckService.stop()

    function show(id: string): void {
        root.page = id
        root.forceActiveFocus()
    }

    Keys.onEscapePressed: root.closed()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: 14

        // ── WHOSE DECK ──────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "󰓓"
                font.family: Theme.fontMono
                font.pixelSize: 26
                color: Theme.accent
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    text: String(SteamDeckService.config.name ?? "Steam Deck")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Text {
                    text: {
                        const parts = []
                        if (SteamDeckService.address !== "")
                            parts.push(SteamDeckService.address)
                        if (SteamDeckService.status) {
                            parts.push(SteamDeckService.status.session === "game"
                                ? Tr.t("Game mode") : Tr.t("Desktop"))
                            if (SteamDeckService.status.os)
                                parts.push(SteamDeckService.status.os)
                        }
                        return parts.join(" · ")
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                    elide: Text.ElideRight
                }
            }

            Item { Layout.fillWidth: true }

            // The poll's answer, as a light and a sentence. The sentence is
            // the complaint while there is one, so the header says why.
            RowLayout {
                spacing: 7

                Rectangle {
                    width: 7
                    height: 7
                    radius: 4
                    color: SteamDeckService.reachable ? Theme.green
                        : (SteamDeckService.connectionError !== "" ? Theme.red : Theme.textMuted)

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                Text {
                    Layout.maximumWidth: 340
                    text: SteamDeckService.reachable ? Tr.t("Connected")
                        : (SteamDeckService.connectionError !== ""
                            ? SteamDeckService.connectionError : Tr.t("Not asked yet"))
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: SteamDeckService.reachable ? Theme.textMuted
                        : (SteamDeckService.connectionError !== "" ? Theme.red : Theme.textMuted)
                    elide: Text.ElideRight
                }
            }

            IconButton {
                icon: "󰑓"
                iconSize: 15
                active: SteamDeckService.reading.running
                onClicked: SteamDeckService.refresh()
            }

            IconButton {
                icon: "󰅖"
                iconSize: 15
                onClicked: root.closed()
            }
        }

        // ── THE STRIP ───────────────────────────────────────────────────────

        TabStrip {
            tabs: root.pages.map(entry => ({ id: entry.id, label: entry.label }))
            current: root.page
            onPicked: id => root.show(id)
        }

        // ── THE PAGE ────────────────────────────────────────────────────────

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: Math.max(0, root.pages.findIndex(entry => entry.id === root.page))

            OverviewPage {}
            FilesPage {}
            GamesPage {}
            SystemPage {}
            ConnectionPage {}
        }

        // ── THE LINE UNDER IT ───────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: {
                    if (SteamDeckService.active !== "")
                        return root.doing[SteamDeckService.active] ?? Tr.t("Working…")
                    if (SteamDeckService.error !== "")
                        return SteamDeckService.error
                    return SteamDeckService.note
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: SteamDeckService.error !== "" ? Theme.red : Theme.textMuted
                elide: Text.ElideRight

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            Text {
                visible: SteamDeckService.listing !== null && root.page === "files"
                text: SteamDeckService.listing
                    ? SteamDeckService.listing.entries.length + " "
                        + Tr.t(SteamDeckService.listing.entries.length === 1 ? "entry" : "entries")
                    : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }
        }
    }
}
