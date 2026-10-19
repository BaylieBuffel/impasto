// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E S S I O N   R I B B O N                                            │
// │   screen time · the day's sessions in a line, in order                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick

import "../theme"

// The sessions laid end to end across the hours they span, each in its
// group's shade; the gaps are the time away.
Item {
    id: root

    // [start, end, class, rank] in seconds since the epoch.
    property var sessions: []
    property color accent: Theme.accent
    property color ink: Theme.text
    property color track: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

    // From the hour of the first to the hour after the last, six at least.
    readonly property real from: {
        if (root.sessions.length === 0)
            return 0
        const start = new Date(root.sessions[0][0] * 1000)
        start.setMinutes(0, 0, 0)
        return start.getTime() / 1000
    }
    readonly property real to: root.sessions.length === 0 ? 1
        : Math.max(root.from + 6 * 3600, Math.ceil(root.sessions[root.sessions.length - 1][1] / 3600) * 3600)

    Rectangle {
        anchors.fill: parent
        radius: Math.min(height / 2, 4)
        color: root.track
    }

    Repeater {
        model: root.sessions

        Rectangle {
            required property var modelData

            readonly property real span: root.to - root.from

            x: root.width * (modelData[0] - root.from) / span
            width: Math.max(1.5, root.width * (modelData[1] - modelData[0]) / span - 1)
            height: root.height
            radius: 2
            color: Theme.rankColorIn(modelData[3] ?? -1, root.accent, root.ink)
        }
    }
}
