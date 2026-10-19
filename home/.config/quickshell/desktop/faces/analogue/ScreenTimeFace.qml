// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S C R E E N   T I M E   F A C E                                        │
// │   analogue · the day on a 24 hour dial                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"
import "../../../components"

// The day on a dial with midnight at the top, a session per arc in its
// group's shade. The total under it on a square, beside it on a wide face
// with the sessions in a line below; a 4×4 adds the week.
Item {
    id: root

    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)

    Instrument {
        anchors.fill: parent
        family: root.family
        ink: root.ink
        line: ScreenTimeService.short(ScreenTimeService.todayTotal)
        reading: ScreenTimeService.duration(ScreenTimeService.todayTotal)
        note: ScreenTimeService.todayNote
        filled: root.family !== "2x2"

        DayDial {
            anchors.fill: parent
            sessions: ScreenTimeService.todayDigest.sessions
            accent: root.ink.accent
            ink: root.ink.text
        }

        extra: [
            SessionRibbon {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 10
                sessions: ScreenTimeService.todayDigest.sessions
                accent: root.ink.accent
                ink: root.ink.text
            }
        ]

        body: [
            UsageBars {
                anchors.fill: parent
                stacks: ScreenTimeService.todayDigest.recent
                average: ScreenTimeService.todayBaseline
                gap: 10
                accent: root.ink.accent
                ink: root.ink.text
            }
        ]
    }
}
