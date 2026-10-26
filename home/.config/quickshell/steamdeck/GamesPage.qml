// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G A M E S   P A G E                                                    │
// │   what is installed, how much of the disk it is, and starting one        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../components"
import "../services"
import "../theme"

// The manifests Steam leaves in every library, from `deck.py games`. A game
// installed on the microSD is here too: the script reads `libraryfolders.vdf`.
// Launching goes through the running Steam client, so the Deck keeps whatever
// session it already has.
Item {
    id: root

    property string filter: ""
    property string selected: ""

    readonly property var library: SteamDeckService.games
    readonly property var games: {
        if (!root.library)
            return []
        const term = root.filter.trim().toLowerCase()
        const all = root.library.games ?? []
        return term === "" ? all : all.filter(game => game.name.toLowerCase().includes(term))
    }

    readonly property var selectedGame: {
        if (root.selected === "")
            return null
        return root.games.find(game => String(game.id) === root.selected) ?? null
    }

    property bool asked: false

    function load(): void {
        if (root.asked && root.library !== null)
            return
        root.asked = true
        SteamDeckService.library()
    }

    onVisibleChanged: if (visible) root.load()
    Component.onCompleted: if (visible) root.load()

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ── THE FIELD ───────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "󰍉"
                font.family: Theme.fontMono
                font.pixelSize: 14
                color: Theme.textMuted
            }

            TextInput {
                id: field

                Layout.fillWidth: true
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.text
                selectByMouse: true
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                clip: true

                onTextEdited: root.filter = text
                Keys.onEscapePressed: {
                    field.text = ""
                    root.filter = ""
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text === ""
                    text: Tr.t("Filter the games…")
                    font: field.font
                    color: Theme.textMuted
                }
            }

            Text {
                text: root.library
                    ? root.games.length + " · " + SteamDeckService.human(root.library.size ?? 0)
                    : ""
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            IconButton {
                icon: "󰑓"
                iconSize: 14
                active: SteamDeckService.libraryReader.running
                onClicked: {
                    root.asked = true
                    SteamDeckService.library()
                }
            }
        }

        // ── THE LIBRARY ─────────────────────────────────────────────────────

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
                model: root.games

                delegate: Rectangle {
                    id: row

                    required property var modelData

                    readonly property bool isSelected: String(modelData.id) === root.selected

                    width: list.width
                    height: 40
                    radius: Theme.radiusSmall
                    color: row.isSelected ? Theme.surfaceHoverIn(QsWindow.window)
                        : (pointer.containsMouse ? Theme.surfaceHoverIn(QsWindow.window) : "transparent")

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: "󰊴"
                            font.family: Theme.fontMono
                            font.pixelSize: 14
                            color: row.isSelected ? Theme.accent : Theme.textMuted
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: row.isSelected ? Font.DemiBold : Font.Normal
                            color: Theme.text
                        }

                        Text {
                            Layout.preferredWidth: 76
                            horizontalAlignment: Text.AlignRight
                            text: SteamDeckService.human(row.modelData.size)
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.text
                        }

                        Text {
                            Layout.preferredWidth: 84
                            horizontalAlignment: Text.AlignRight
                            text: SteamDeckService.stamp(row.modelData.updated)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                        }
                    }

                    MouseArea {
                        id: pointer

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected = String(row.modelData.id)
                        onDoubleClicked: {
                            root.selected = String(row.modelData.id)
                            SteamDeckService.launch(row.modelData.id)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 60
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: root.games.length === 0
                    text: SteamDeckService.libraryReader.running ? Tr.t("Reading…")
                        : (root.library === null ? Tr.t("Not read yet") : Tr.t("No game matches"))
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }
            }
        }

        // ── THE SELECTED GAME ───────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.selectedGame !== null

            Text {
                Layout.fillWidth: true
                text: root.selectedGame
                    ? root.selectedGame.name + " · "
                        + SteamDeckService.human(root.selectedGame.size)
                    : ""
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            Text {
                visible: root.library !== null && (root.library.games ?? []).length > 0
                    && SteamDeckService.status !== null && !SteamDeckService.status.steam
                text: Tr.t("Starting a game needs Steam running on the deck")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }

            PillButton {
                icon: "󰐊"
                text: Tr.t("Launch")
                enabled: root.selectedGame !== null && !SteamDeckService.busy
                onClicked: SteamDeckService.launch(root.selectedGame.id)
            }
        }
    }
}
