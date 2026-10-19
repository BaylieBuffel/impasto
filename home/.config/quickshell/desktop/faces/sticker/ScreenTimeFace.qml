// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S C R E E N   T I M E   F A C E                                        │
// │   sticker · today on a lobed sticker, filling to an average day          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"

// Today's total printed on a lobed sticker, with a ring round it that
// fills as the day reaches the week's average one.
Spread {
    id: face

    line: ScreenTimeService.todayNote
    reading: ScreenTimeService.duration(ScreenTimeService.todayTotal)
    note: ScreenTimeService.todayNote

    Tone { id: tone; hue: face.ink.accent }

    Cut {
        id: badge

        anchors.centerIn: parent
        width: parent.width * 0.9
        height: width
        shape: "cookie"
        lobes: 12
        depth: 0.05
        seed: face.seed
        fill: tone.fill

        Ring {
            anchors.fill: parent
            anchors.margins: badge.side * 0.16
            fraction: ScreenTimeService.todayFraction
            thickness: Math.max(4, badge.side * 0.06)
            color: tone.deep
            track: tone.track
        }

        Text {
            anchors.centerIn: parent
            text: ScreenTimeService.short(ScreenTimeService.todayTotal)
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(badge.side * 0.2)
            font.weight: Font.Bold
            color: tone.deep
        }
    }
}
