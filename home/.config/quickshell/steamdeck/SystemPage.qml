// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S Y S T E M   P A G E                                                  │
// │   one line on the deck, and what it printed                              │
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

// `deck.py run`: a login shell on the Deck, its output here. The window is not
// a terminal — a program that asks a question would sit there — so this is for
// the lines that answer and end: a unit's state, a `df`, a `journalctl -n`.
Item {
    id: root

    readonly property var answer: SteamDeckService.answer

    property string line: ""

    function send(): void {
        const said = root.line.trim()
        if (said === "")
            return
        SteamDeckService.run(said)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ── THE LINE ────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "$"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.accent
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: Theme.radiusSmall
                color: Theme.islandSurface
                border.color: field.activeFocus ? Theme.accent : Theme.borderIn(QsWindow.window)
                border.width: 1

                TextInput {
                    id: field

                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.line
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.text
                    selectByMouse: true
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    clip: true

                    onTextEdited: root.line = field.text
                    onAccepted: root.send()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: Tr.t("a command, as on the deck's own terminal")
                        font: field.font
                        color: Theme.textMuted
                    }
                }
            }

            PillButton {
                icon: "󰆍"
                text: Tr.t("Run")
                enabled: root.line.trim() !== "" && !SteamDeckService.busy
                onClicked: root.send()
            }

            IconButton {
                icon: "󰆏"
                iconSize: 14
                enabled: root.answer !== null
                onClicked: {
                    if (root.answer)
                        Quickshell.execDetached(["wl-copy", "--", root.answer.output])
                }
            }
        }

        // ── WHAT IT PRINTED ─────────────────────────────────────────────────

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
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
                        text: root.answer
                            ? "$ " + root.answer.line
                            : Tr.t("Nothing has been run yet")
                        elide: Text.ElideRight
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.answer ? Theme.text : Theme.textMuted
                    }

                    Text {
                        visible: root.answer !== null
                        text: root.answer
                            ? (root.answer.code === 0 ? Tr.t("ok") : Tr.t("exit") + " " + root.answer.code)
                            : ""
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: root.answer && root.answer.code === 0 ? Theme.green : Theme.red
                    }
                }

                TextEdit {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.answer !== null
                    clip: true
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.NoWrap
                    text: root.answer ? root.answer.output : ""
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    color: Theme.textMuted
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                }

                Text {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.answer === null
                    wrapMode: Text.WordWrap
                    text: Tr.t("A login shell's answer appears here. A program that waits for an answer will wait: use a terminal for that.")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                    verticalAlignment: Text.AlignTop
                }
            }
        }
    }
}
