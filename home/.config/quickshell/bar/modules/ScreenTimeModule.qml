// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S C R E E N   T I M E   M O D U L E                                    │
// │   screen time · today on the chip; the hours and the most used           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// Today's total on the chip. The detail is the day in brief — the ring by
// group, the hours, the three most used — and opens the whole panel.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: ScreenTimeService.follow()
    Component.onDestruction: ScreenTimeService.unfollow()

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    Component {
        id: detail

        ModuleCard {
            title: ScreenTimeService.duration(ScreenTimeService.todayTotal)
            subtitle: ScreenTimeService.todayCompared !== ""
                ? `${Tr.t("Today")} · ${ScreenTimeService.todayCompared} ${Tr.t("on average")}`
                : Tr.t("Today")

            mark: UsageRing {
                anchors.fill: parent
                anchors.margins: 4
                parts: ScreenTimeService.todayParts
                thickness: 4
            }

            UsageBars {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                stacks: ScreenTimeService.todayDigest.stacks
                ceiling: 3600
                gap: 2
            }

            Repeater {
                model: ScreenTimeService.todayDigest.apps.slice(0, 3)

                CardFact {
                    required property var modelData
                    name: modelData.name
                    value: ScreenTimeService.duration(modelData.seconds)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.cardRow
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: ScreenTimeService.todayNote === "" || ScreenTimeService.todayLead
                        ? "" : ScreenTimeService.todayNote
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                // Modules can't reach the island, so this requests the panel.
                PillButton {
                    implicitHeight: Theme.cardRow
                    text: Tr.t("Open")
                    onClicked: ModuleService.requestPanel("screentime")
                }
            }
        }
    }
}
