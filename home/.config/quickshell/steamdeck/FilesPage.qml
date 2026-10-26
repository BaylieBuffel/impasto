// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   F I L E S   P A G E                                                    │
// │   the deck's home · one directory at a time, and the head of a file      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell

import "../components"
import "../services"
import "../theme"

// A browser over `deck.py ls`, with the head of the selected file beside it.
// Nothing is deleted on one press: Remove arms and says Confirm, and the
// script refuses anything nearer the root than a folder inside a home anyway.
Item {
    id: root

    readonly property var listing: SteamDeckService.listing
    readonly property var entries: {
        const all = root.listing ? (root.listing.entries ?? []) : []
        return root.showHidden ? all : all.filter(entry => !entry.hidden)
    }

    property bool showHidden: false
    property string selected: ""

    // "" when not naming anything, otherwise "folder" or "rename".
    property string naming: ""
    property string draft: ""

    // The path of the row armed for removal, or "".
    property string armed: ""

    readonly property var selectedEntry: {
        if (root.selected === "")
            return null
        return root.entries.find(entry => entry.path === root.selected) ?? null
    }

    // Loaded on first look and whenever the page is opened again after a
    // while elsewhere: the directory is kept, so a return lands where it left.
    property bool asked: false

    function load(): void {
        if (root.asked && root.listing !== null)
            return
        root.asked = true
        SteamDeckService.browse(root.listing ? root.listing.path : "")
    }

    onVisibleChanged: if (visible) root.load()
    Component.onCompleted: if (visible) root.load()

    onListingChanged: {
        root.selected = ""
        root.armed = ""
        if (root.naming !== "")
            root.naming = ""
    }

    function startNaming(what: string): void {
        root.naming = what
        root.draft = what === "rename" && root.selectedEntry ? root.selectedEntry.name : ""
        namer.forceActiveFocus()
        namer.selectAll()
    }

    function commitNaming(): void {
        const name = root.draft.trim()
        if (name === "" || !root.listing) {
            root.naming = ""
            return
        }
        if (root.naming === "folder")
            SteamDeckService.makeDirectory(root.listing.path, name)
        else if (root.naming === "rename" && root.selectedEntry)
            SteamDeckService.rename(root.listing.path, root.selectedEntry.name, name)
        root.naming = ""
        root.draft = ""
    }

    FileDialog {
        id: picker

        title: Tr.t("Send a file to the deck")
        fileMode: FileDialog.OpenFile

        onAccepted: {
            if (!root.listing)
                return
            const chosen = decodeURIComponent(picker.selectedFile.toString().replace("file://", ""))
            SteamDeckService.upload(chosen, root.listing.path)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ── THE PATH ────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            IconButton {
                icon: "󰁝"
                iconSize: 15
                enabled: root.listing !== null && root.listing.parent !== ""
                onClicked: SteamDeckService.up()
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Theme.radiusSmall
                color: Theme.islandSurface
                border.color: Theme.borderIn(QsWindow.window)
                border.width: 1

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: root.listing ? root.listing.path : "…"
                    elide: Text.ElideLeft
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.text
                }
            }

            IconButton {
                icon: "󰐕"
                iconSize: 15
                enabled: root.listing !== null
                onClicked: root.startNaming("folder")
            }

            IconButton {
                icon: "󰕒"
                iconSize: 15
                enabled: root.listing !== null
                onClicked: picker.open()
            }

            IconButton {
                icon: "󰈙"
                iconSize: 14
                active: root.showHidden
                onClicked: root.showHidden = !root.showHidden
            }

            IconButton {
                icon: "󰑓"
                iconSize: 14
                active: SteamDeckService.listingReader.running
                onClicked: SteamDeckService.browse(root.listing ? root.listing.path : "")
            }
        }

        // ── NAMING ──────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.naming !== ""

            Text {
                text: root.naming === "folder" ? Tr.t("New folder") : Tr.t("New name")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Theme.radiusSmall
                color: Theme.island
                border.color: namer.activeFocus ? Theme.accent : Theme.borderIn(QsWindow.window)
                border.width: 1

                TextInput {
                    id: namer

                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.draft
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.text
                    selectByMouse: true
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    clip: true

                    onTextEdited: root.draft = namer.text
                    Keys.onReturnPressed: root.commitNaming()
                    Keys.onEnterPressed: root.commitNaming()
                    Keys.onEscapePressed: {
                        root.naming = ""
                        root.draft = ""
                    }
                }
            }

            PillButton {
                text: root.naming === "folder" ? Tr.t("Make") : Tr.t("Rename")
                enabled: root.draft.trim() !== ""
                onClicked: root.commitNaming()
            }

            PillButton {
                text: Tr.t("Cancel")
                onClicked: {
                    root.naming = ""
                    root.draft = ""
                }
            }
        }

        // ── THE LIST AND THE FILE ───────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // · one directory
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: Theme.islandSurface
                border.color: Theme.islandBorder
                border.width: 1

                ListView {
                    id: list

                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.entries

                    delegate: Rectangle {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool isSelected: modelData.path === root.selected
                        readonly property bool isArmed: modelData.path === root.armed

                        width: list.width
                        height: 34
                        radius: Theme.radiusSmall
                        color: row.isArmed ? Theme.red
                            : (row.isSelected ? Theme.surfaceHoverIn(QsWindow.window)
                                : (pointer.containsMouse ? Theme.surfaceHoverIn(QsWindow.window) : "transparent"))

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: row.modelData.dir ? "󰉋"
                                    : (row.modelData.link ? "󰌷" : "󰈙")
                                font.family: Theme.fontMono
                                font.pixelSize: 13
                                color: row.isArmed ? Theme.accentText
                                    : (row.modelData.dir ? Theme.accent : Theme.textMuted)
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                elide: Text.ElideMiddle
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: row.isArmed ? Theme.accentText : Theme.text
                            }

                            Text {
                                text: row.modelData.dir ? "" : SteamDeckService.human(row.modelData.size)
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                color: row.isArmed ? Theme.accentText : Theme.textMuted
                            }

                            Text {
                                Layout.preferredWidth: 76
                                horizontalAlignment: Text.AlignRight
                                text: SteamDeckService.stamp(row.modelData.modified)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: row.isArmed ? Theme.accentText : Theme.textMuted
                            }
                        }

                        MouseArea {
                            id: pointer

                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.selected = row.modelData.path
                                root.armed = ""
                            }

                            onDoubleClicked: {
                                root.selected = row.modelData.path
                                root.armed = ""
                                SteamDeckService.open(row.modelData)
                            }
                        }
                    }

                    // Nothing here: a new home, or a filter with no match.
                    Text {
                        anchors.centerIn: parent
                        visible: root.entries.length === 0
                        text: SteamDeckService.listingReader.running
                            ? Tr.t("Reading…") : Tr.t("Nothing here")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }
            }

            // · the head of the file
            Rectangle {
                id: viewer

                readonly property var file: SteamDeckService.preview

                Layout.preferredWidth: 380
                Layout.fillHeight: true
                visible: viewer.file !== null
                radius: Theme.radiusLarge
                color: Theme.islandSurface
                border.color: Theme.islandBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: viewer.file ? String(viewer.file.path).split("/").pop() : ""
                            elide: Text.ElideMiddle
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.text
                        }

                        IconButton {
                            icon: "󰅖"
                            iconSize: 13
                            onClicked: SteamDeckService.clearPreview()
                        }
                    }

                    TextEdit {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        text: viewer.file ? viewer.file.text : ""
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        color: Theme.textMuted
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                    }
                }
            }
        }

        // ── WHAT TO DO WITH THE SELECTED ROW ────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.selectedEntry !== null

            Text {
                Layout.fillWidth: true
                text: root.selectedEntry
                    ? root.selectedEntry.name
                        + (root.selectedEntry.dir ? ""
                            : " · " + SteamDeckService.human(root.selectedEntry.size))
                    : ""
                elide: Text.ElideMiddle
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            PillButton {
                icon: "󰇚"
                text: Tr.t("Download")
                enabled: root.selectedEntry !== null && !root.selectedEntry.dir
                onClicked: SteamDeckService.download(root.selectedEntry.path)
            }

            PillButton {
                text: Tr.t("Rename")
                onClicked: root.startNaming("rename")
            }

            PillButton {
                text: root.armed === (root.selectedEntry?.path ?? "")
                    ? Tr.t("Confirm") : Tr.t("Remove")
                active: root.armed === (root.selectedEntry?.path ?? "")
                enabled: root.selectedEntry !== null && !SteamDeckService.busy
                onClicked: {
                    const entry = root.selectedEntry
                    if (!entry)
                        return
                    if (root.armed === entry.path) {
                        root.armed = ""
                        SteamDeckService.remove(entry.path)
                        return
                    }
                    root.armed = entry.path
                    disarm.restart()
                }
            }

            Timer {
                id: disarm
                interval: 3000
                onTriggered: root.armed = ""
            }
        }
    }
}
