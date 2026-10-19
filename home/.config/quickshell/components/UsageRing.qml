// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   U S A G E   R I N G                                                    │
// │   screen time · a ring split by group, the rest in grey                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

import "../theme"

// The day's total round a ring: one arc per ranked group, in its shade, the
// rest after them. `fill` is how much of the ring they take, so a ring can
// read as today against an average day.
Item {
    id: root

    // Seconds per ranked group, the rest last.
    property var parts: []
    property real fill: 1
    property real thickness: 6
    property color accent: Theme.accent
    property color ink: Theme.text
    property color track: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.1)

    readonly property real total: root.parts.reduce((a, b) => a + b, 0)
    readonly property real reach: Math.min(root.width, root.height) / 2 - root.thickness / 2
    // A sliver between arcs, in degrees.
    readonly property real seam: root.parts.filter(part => part > 0).length > 1 ? 4 : 0

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
        model: root.parts.length

        Shape {
            id: arc

            required property int index

            readonly property real before: root.parts.slice(0, arc.index).reduce((a, b) => a + b, 0)
            readonly property real share: root.total > 0 ? 360 * root.fill / root.total : 0

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            visible: root.parts[arc.index] > 0

            ShapePath {
                strokeColor: Theme.rankColorIn(arc.index < root.parts.length - 1 ? arc.index : -1,
                    root.accent, root.ink)
                strokeWidth: root.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: root.width / 2
                    centerY: root.height / 2
                    radiusX: root.reach
                    radiusY: root.reach
                    startAngle: -90 + arc.before * arc.share
                    sweepAngle: Math.max(0.5, root.parts[arc.index] * arc.share - root.seam)
                }
            }
        }
    }
}
