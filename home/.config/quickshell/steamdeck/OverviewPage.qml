// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   O V E R V I E W   P A G E                                              │
// │   the deck at a glance · charge, heat, memory, disks and power           │
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

// The reading `deck.py status` answers, arranged as cards. Nothing here polls
// on its own: the service keeps one reading while the window is open and the
// header's refresh asks for the next.
Item {
    id: root

    readonly property var status: SteamDeckService.status

    // ── NOTHING YET ─────────────────────────────────────────────────────────

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 420)
        spacing: 12
        visible: root.status === null

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: SteamDeckService.reachable ? "󰑓" : "󰀦"
            font.family: Theme.fontMono
            font.pixelSize: 34
            color: SteamDeckService.connectionError !== "" ? Theme.red : Theme.textMuted
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: SteamDeckService.connectionError !== ""
                ? SteamDeckService.connectionError
                : Tr.t("Reading the deck…")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeRegular
            color: Theme.textMuted
        }

        PillButton {
            Layout.alignment: Qt.AlignHCenter
            icon: "󰑓"
            text: Tr.t("Refresh")
            enabled: SteamDeckService.configured
            onClicked: SteamDeckService.refresh()
        }

        PillButton {
            Layout.alignment: Qt.AlignHCenter
            visible: SteamDeckService.connectionError !== ""
            text: Tr.t("Set up a key")
            onClicked: SteamDeckService.askKey()
        }
    }

    // ── THE CARDS ───────────────────────────────────────────────────────────

    RowLayout {
        anchors.fill: parent
        spacing: 12
        visible: root.status !== null

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 0
            spacing: 12

            // · charge
            Card {
                Layout.fillWidth: true
                implicitHeight: charge.implicitHeight + 32

                RowLayout {
                    id: charge
                    anchors.fill: parent
                    spacing: 16

                    RingIndicator {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 84
                        Layout.preferredHeight: 84
                        thickness: 5
                        progress: (root.status?.battery?.percent ?? 0) / 100
                        fillColor: (root.status?.battery?.charging ?? false) ? Theme.green
                            : ((root.status?.battery?.percent ?? 100) < 20 ? Theme.red : Theme.accent)

                        Text {
                            anchors.centerIn: parent
                            text: (root.status?.battery?.percent ?? 0) + "%"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        CardHeading { text: Tr.t("Battery") }

                        CardFact {
                            name: Tr.t("State")
                            value: root.status?.battery?.status ?? Tr.t("None")
                        }

                        CardFact {
                            name: Tr.t("Draw")
                            value: (root.status?.battery?.watts ?? 0).toFixed(1) + " W"
                        }

                        CardFact {
                            name: Tr.t("Charge")
                            value: (root.status?.battery?.wh ?? 0).toFixed(1)
                                + " / " + (root.status?.battery?.full ?? 0).toFixed(1) + " Wh"
                        }

                        CardFact {
                            visible: (root.status?.battery?.limit ?? 0) > 0
                            name: Tr.t("Limit")
                            value: (root.status?.battery?.limit ?? 0) + "%"
                        }
                    }
                }
            }

            // · memory
            Card {
                Layout.fillWidth: true
                implicitHeight: memory.implicitHeight + 32

                ColumnLayout {
                    id: memory
                    anchors.fill: parent
                    spacing: 8

                    CardHeading { text: Tr.t("Memory") }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: Number(root.status?.memory?.used ?? 0).toFixed(1) + " GB"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeRegular
                            color: Theme.text
                        }

                        Text {
                            Layout.fillWidth: true
                            text: Tr.t("of") + " " + Number(root.status?.memory?.total ?? 0).toFixed(1) + " GB"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }
                    }

                    UsageBar {
                        Layout.fillWidth: true
                        progress: {
                            const total = Number(root.status?.memory?.total ?? 0)
                            return total > 0 ? Number(root.status?.memory?.used ?? 0) / total : 0
                        }
                    }

                    CardFact {
                        visible: Number(root.status?.memory?.swap_total ?? 0) > 0
                        name: Tr.t("Swap")
                        value: Number(root.status?.memory?.swap_used ?? 0).toFixed(1)
                            + " / " + Number(root.status?.memory?.swap_total ?? 0).toFixed(1) + " GB"
                    }
                }
            }

            // · disks
            Card {
                Layout.fillWidth: true
                implicitHeight: disks.implicitHeight + 32

                ColumnLayout {
                    id: disks

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 10

                    CardHeading { text: Tr.t("Disks") }

                    Repeater {
                        // A mount with no size (an ISO's EFI stub, a loop
                        // device) has nothing to draw and would sit at a
                        // fraction of nothing.
                        model: (root.status?.disks ?? []).filter(disk => Number(disk.total) > 0)

                        ColumnLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.mount
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.text
                                }

                                Text {
                                    text: Number(modelData.used).toFixed(0) + " / "
                                        + Number(modelData.total).toFixed(0) + " GB"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    color: Theme.textMuted
                                }
                            }

                            UsageBar {
                                Layout.fillWidth: true
                                progress: Number(modelData.percent ?? 0) / 100
                                fillColor: Number(modelData.percent ?? 0) > 90 ? Theme.red : Theme.accent
                            }
                        }
                    }
                }
            }

            // The column is taller than its three cards; the space goes under
            // them rather than into the last card's border.
            Item { Layout.fillHeight: true }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 0
            spacing: 12

            // · the system
            Card {
                Layout.fillWidth: true
                implicitHeight: systemCard.implicitHeight + 32

                ColumnLayout {
                    id: systemCard
                    anchors.fill: parent
                    spacing: 2

                    CardHeading { text: Tr.t("System") }

                    CardFact {
                        name: Tr.t("Session")
                        value: root.status?.session === "game" ? Tr.t("Game mode") : Tr.t("Desktop")
                    }

                    CardFact {
                        name: Tr.t("Steam")
                        value: root.status?.steam ? Tr.t("Running") : Tr.t("Closed")
                        valueColor: root.status?.steam ? Theme.green : Theme.textMuted
                    }

                    CardFact {
                        name: Tr.t("Uptime")
                        value: SteamDeckService.since(root.status?.uptime ?? 0)
                    }

                    CardFact {
                        name: Tr.t("Kernel")
                        value: root.status?.kernel ?? ""
                    }

                    CardFact {
                        name: Tr.t("Cores")
                        value: (root.status?.cpu?.cores ?? 0) + " · "
                            + Number(root.status?.cpu?.load ?? 0).toFixed(2)
                    }
                }
            }

            // · heat
            Card {
                Layout.fillWidth: true
                implicitHeight: thermals.implicitHeight + 32

                ColumnLayout {
                    id: thermals
                    anchors.fill: parent
                    spacing: 2

                    CardHeading { text: Tr.t("Thermals") }

                    CardFact {
                        name: Tr.t("CPU")
                        value: {
                            const temperature = root.status?.cpu?.temp
                            const watts = Number(root.status?.cpu?.watts ?? 0)
                            const parts = []
                            if (temperature !== null && temperature !== undefined)
                                parts.push(temperature + " °C")
                            if (watts > 0)
                                parts.push(watts.toFixed(1) + " W")
                            return parts.join(" · ") || "—"
                        }
                    }

                    CardFact {
                        name: Tr.t("GPU")
                        value: root.status?.gpu?.temp !== null && root.status?.gpu?.temp !== undefined
                            ? root.status.gpu.temp + " °C" : "—"
                    }

                    CardFact {
                        name: Tr.t("Fan")
                        value: Number(root.status?.fan ?? 0) > 0
                            ? Math.round(root.status.fan / 100) * 100 + " rpm" : "—"
                    }
                }
            }

            // · the network
            Card {
                Layout.fillWidth: true
                implicitHeight: network.implicitHeight + 32

                ColumnLayout {
                    id: network
                    anchors.fill: parent
                    spacing: 2

                    CardHeading { text: Tr.t("Network") }

                    CardFact {
                        name: Tr.t("Wi-Fi")
                        value: root.status?.wifi?.state ?? ""
                    }

                    CardFact {
                        name: Tr.t("SSID")
                        value: root.status?.wifi?.ssid || "—"
                    }

                    CardFact {
                        name: Tr.t("Signal")
                        value: Number(root.status?.wifi?.signal ?? 0) + " / 70"
                    }
                }
            }

            // · power
            Card {
                Layout.fillWidth: true
                implicitHeight: power.implicitHeight + 32

                ColumnLayout {
                    id: power
                    anchors.fill: parent
                    spacing: 8

                    CardHeading { text: Tr.t("Power") }

                    property string armed: ""

                    Timer {
                        interval: 3000
                        onTriggered: power.armed = ""
                    }

                    readonly property var verbs: [
                        { id: "sleep",    label: Tr.t("Sleep") },
                        { id: "reboot",   label: Tr.t("Restart") },
                        { id: "shutdown", label: Tr.t("Shut down") }
                    ]

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: power.verbs

                            PillButton {
                                required property var modelData

                                Layout.fillWidth: true
                                text: power.armed === modelData.id ? Tr.t("Confirm") : modelData.label
                                active: power.armed === modelData.id
                                enabled: !SteamDeckService.busy
                                onClicked: {
                                    if (power.armed === modelData.id) {
                                        power.armed = ""
                                        SteamDeckService.power(modelData.id)
                                        return
                                    }
                                    power.armed = modelData.id
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
