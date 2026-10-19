// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E R V E R S   P A N E L                                              │
// │   development servers · a row per port, opened, copied or stopped        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"

// A row per listening port: the project it was started in, what runs it and
// for how long, the port, and whether more than this machine can reach it.
// The row opens the page; its rounds copy the address or stop the server.
ColumnLayout {
    id: root

    signal closed()

    spacing: 14

    Component.onCompleted: ServersService.subscribe()
    Component.onDestruction: ServersService.release()

    readonly property var glyphs: ({
        node: "󰎙", deno: "󰛦", python: "󰌠", rust: "󱘗", go: "󰟓",
        ruby: "󰴭", php: "󰌟", java: "󰬷", other: "󰒋"
    })

    // A round answer: its glyph, lit under the pointer.
    component Round: Rectangle {
        id: round

        property string glyph: ""
        property bool danger: false
        property bool live: true
        signal pressed()

        implicitWidth: 34
        implicitHeight: 34
        radius: width / 2
        opacity: round.live ? 1 : 0.35
        color: press.containsMouse && round.live ? Theme.islandSurfaceHover : Theme.island

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Text {
            anchors.centerIn: parent
            text: round.glyph
            font.family: Theme.fontMono
            font.pixelSize: 15
            color: round.danger ? Theme.indicatorBad : Theme.text
        }

        MouseArea {
            id: press

            anchors.fill: parent
            enabled: round.live
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: round.pressed()
        }
    }

    // ── SERVERS ─────────────────────────────────────────────────────────────

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Text {
            anchors.centerIn: parent
            visible: ServersService.loaded && ServersService.servers.length === 0
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Tr.t("Start a server inside a project and its port appears here.")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeRegular
            color: Theme.textMuted
        }

        ListView {
            id: serverList

            anchors.fill: parent
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds

            // By port, so a row outlives the list being read again.
            model: ScriptModel {
                values: ServersService.servers
                objectProp: "port"
            }

            delegate: Rectangle {
                id: server

                required property var modelData

                readonly property bool stopping: ServersService.stopping === server.modelData.port

                width: serverList.width
                height: ServersService.rowHeight
                radius: 20
                color: open.containsMouse ? Theme.islandSurfaceHover : Theme.islandSurface
                opacity: server.stopping ? 0.5 : 1

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                MouseArea {
                    id: open

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ServersService.open(server.modelData.port)
                        root.closed()
                    }
                }

                Rectangle {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 52
                    height: 52
                    radius: 15
                    color: Theme.island

                    Text {
                        anchors.centerIn: parent
                        text: root.glyphs[server.modelData.kind] ?? root.glyphs.other
                        font.family: Theme.fontMono
                        font.pixelSize: 26
                        color: Theme.text
                    }
                }

                Column {
                    x: 78
                    anchors.verticalCenter: parent.verticalCenter
                    width: 230
                    spacing: 3

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: server.modelData.project
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.text
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: server.stopping ? Tr.t("Stopping")
                            : [server.modelData.runner, ServersService.uptime(server.modelData.started)]
                                .filter(part => part !== "").join(" · ")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }

                Column {
                    x: 320
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: `:${server.modelData.port}`
                        font.family: Theme.fontMono
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: Theme.accent
                    }

                    Text {
                        text: Tr.t(server.modelData.network ? "the network too" : "this machine")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: server.modelData.network ? Theme.indicatorWarn : Theme.textMuted
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Round {
                        glyph: "󰖟"
                        live: !server.stopping
                        onPressed: {
                            ServersService.open(server.modelData.port)
                            root.closed()
                        }
                    }

                    Round {
                        glyph: "󰆏"
                        live: !server.stopping
                        onPressed: {
                            ServersService.copy(server.modelData.port)
                            OsdService.requested("󰆏", ServersService.url(server.modelData.port), -1)
                        }
                    }

                    Round {
                        glyph: "󰓛"
                        danger: true
                        live: !server.stopping && ServersService.stopping === 0
                        onPressed: ServersService.stop(server.modelData.pid, server.modelData.port)
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.borderIn(QsWindow.window)
    }

    // ── STATUS LINE ─────────────────────────────────────────────────────────

    Text {
        Layout.fillWidth: true
        Layout.preferredHeight: 20
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: ServersService.error !== "" ? ServersService.error
            : ServersService.servers.length === 0 ? Tr.t("None listening")
            : `${ServersService.servers.length} ${Tr.t("listening")}`
              + (ServersService.exposed > 0
                  ? ` · ${ServersService.exposed} ${Tr.t("open to the network")}` : "")
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: ServersService.error !== "" ? Theme.indicatorBad : Theme.textMuted
    }
}
