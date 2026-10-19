// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D A Y   D I A L                                                        │
// │   screen time · the day on a 24 hour face, a session per arc             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

import "../theme"

// Midnight at the top and noon at the foot: each session an arc where it
// fell, in its group's shade, with the hours ticked round the rim and a hand
// at the present.
Item {
    id: root

    // [start, end, class, rank] in seconds since the epoch.
    property var sessions: []
    property real thickness: Math.max(6, root.side * 0.07)
    property bool ticks: true
    property bool numerals: root.side >= 140
    property color accent: Theme.accent
    property color ink: Theme.text
    property color track: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

    readonly property real side: Math.min(root.width, root.height)
    readonly property real rim: root.ticks ? Math.max(6, root.side * 0.06) : 0
    readonly property real reach: root.side / 2 - root.rim - root.thickness / 2

    // Minutes into the day, for the hand; read once a minute.
    property real minute: 0

    function angleOf(epoch: real): real {
        const date = new Date(epoch * 1000)
        return (date.getHours() * 60 + date.getMinutes() + date.getSeconds() / 60) / 4
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: {
            const now = new Date()
            root.minute = now.getHours() * 60 + now.getMinutes()
        }
    }

    Repeater {
        model: root.ticks ? 24 : 0

        Rectangle {
            required property int index

            readonly property bool major: index % 6 === 0

            x: root.width / 2 - width / 2
            y: root.height / 2 - root.side / 2
            width: major ? 2 : 1
            height: major ? root.rim : root.rim / 2
            radius: width / 2
            color: root.ink
            opacity: major ? 0.7 : 0.3
            transform: Rotation {
                origin.x: width / 2
                origin.y: root.side / 2
                angle: index * 15
            }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.track
            strokeWidth: root.thickness
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.reach
                radiusY: root.reach
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    Repeater {
        model: root.sessions

        Shape {
            id: arc

            required property var modelData

            readonly property real from: root.angleOf(arc.modelData[0])
            readonly property real span: Math.max(0.8, (arc.modelData[1] - arc.modelData[0]) / 240 - 0.6)

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.rankColorIn(arc.modelData[3] ?? -1, root.accent, root.ink)
                strokeWidth: root.thickness
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap

                PathAngleArc {
                    centerX: root.width / 2
                    centerY: root.height / 2
                    radiusX: root.reach
                    radiusY: root.reach
                    startAngle: arc.from - 90
                    sweepAngle: arc.span
                }
            }
        }
    }

    // The present, across the ring.
    Rectangle {
        x: root.width / 2 - width / 2
        y: root.height / 2 - root.side / 2 + root.rim - 3
        width: 2
        height: root.thickness + 6
        radius: 1
        color: root.ink
        transform: Rotation {
            origin.x: 1
            origin.y: root.side / 2 - root.rim + 3
            angle: root.minute / 4
        }
    }

    Repeater {
        model: root.numerals ? ["0", "6", "12", "18"] : []

        Text {
            required property int index
            required property string modelData

            readonly property real distance: root.reach - root.thickness / 2 - 10

            x: root.width / 2 + distance * Math.sin(index * Math.PI / 2) - width / 2
            y: root.height / 2 - distance * Math.cos(index * Math.PI / 2) - height / 2
            text: modelData
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel - 1
            color: root.ink
            opacity: 0.55
        }
    }
}
