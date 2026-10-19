// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   R E C O R D E R                                                        │
// │   a strip-chart recorder · graph paper and the pen's trace               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "../../../theme"
import "../../../services"

// A recorder's case in outline with a window onto its paper: a grid ruled on
// it, the trace drawn left to right, and the pen's arm reaching in from the
// right to where the trace ends. `values` are fractions from 0 to 1.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property var values: []
    property color pen: root.ink.text

    readonly property real wall: Math.max(6, Math.min(root.width, root.height) * 0.08)
    readonly property real arm: Math.max(10, root.width * 0.12)

    Rectangle {
        anchors.fill: parent
        radius: root.wall * 1.4
        color: Qt.rgba(root.ink.text.r, root.ink.text.g, root.ink.text.b, 0.06)
        border.width: 2.5
        border.color: root.ink.text
    }

    Paper {
        id: paper

        ink: root.ink
        radius: 3
        x: root.wall
        y: root.wall
        width: root.width - 2 * root.wall - root.arm
        height: root.height - 2 * root.wall

        // The ruling: a line every fifth of the height, and as many across
        // as keep the squares square.
        Repeater {
            model: 4

            Rectangle {
                required property int index

                y: (index + 1) * paper.height / 5
                width: paper.width
                height: 1
                color: Theme.paperInkMuted
                opacity: 0.35
            }
        }

        Repeater {
            model: Math.max(1, Math.floor(paper.width / (paper.height / 5)))

            Rectangle {
                required property int index

                x: (index + 1) * paper.height / 5
                width: 1
                height: paper.height
                color: Theme.paperInkMuted
                opacity: 0.35
            }
        }

        Shape {
            anchors.fill: parent
            anchors.margins: 6
            visible: root.values.length > 1
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 2
                strokeColor: root.pen
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap

                PathPolyline {
                    path: {
                        const out = []
                        const box = paper.width - 12
                        const tall = paper.height - 12
                        const count = root.values.length
                        for (let index = 0; index < count; index++)
                            out.push(Qt.point(index / (count - 1) * box,
                                              tall - root.values[index] * tall))
                        return out
                    }
                }
            }
        }
    }

    // The arm, from the case's right wall to the trace's last point.
    Shape {
        id: arm

        readonly property real tipY: root.values.length > 1
            ? paper.y + 6 + (paper.height - 12) * (1 - root.values[root.values.length - 1])
            : paper.y + paper.height / 2
        readonly property real tipX: paper.x + paper.width - 6

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 2.5
            strokeColor: root.ink.text
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: root.width - root.wall * 0.6
            startY: root.height / 2

            PathLine { x: arm.tipX + 4; y: arm.tipY }
        }
    }

    Rectangle {
        x: arm.tipX - width / 2
        y: arm.tipY - height / 2
        width: 7
        height: 7
        radius: 3.5
        color: root.pen
        border.width: 1.5
        border.color: root.ink.text
    }

    Rectangle {
        x: root.width - root.wall * 0.6 - width / 2
        y: root.height / 2 - height / 2
        width: 8
        height: 8
        radius: 4
        color: root.ink.text
    }
}
