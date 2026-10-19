// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L I T   E D G E                                                        │
// │   a glass edge lit from one side · full at two corners, faint at two     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

import "../theme"

// Holds a pane's rim and thick edge. In a style lit from one side
// (`Theme.litOf`) what it holds is shown full at the top-left and
// bottom-right corners and fades to a trace at the other two; in any other
// style it is shown as it is. The corners are this item's own, so it is
// sized to the pane.
Item {
    id: root

    property string style: Theme.surfaceStyle
    default property alias content: holder.data

    readonly property bool lit: Theme.litOf(root.style)

    Item {
        id: holder

        anchors.fill: parent

        layer.enabled: root.lit
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: light
            // Half way with the widest spread is a smooth ramp over the
            // mask's whole alpha; a threshold of 0 passes everything.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    // A cone from the centre: opaque toward the top-left and bottom-right
    // corners, the trace toward the other two. Aimed at the corners
    // themselves, so a long pill is lit at its two ends.
    Shape {
        id: light

        anchors.fill: parent
        visible: false
        layer.enabled: root.lit

        readonly property real corner: Math.atan2(height / 2, width / 2) * 180 / Math.PI
        readonly property color full: Qt.rgba(1, 1, 1, 1)
        readonly property color trace: Qt.rgba(1, 1, 1, Theme.litTrace)

        ShapePath {
            strokeWidth: 0
            fillGradient: ConicalGradient {
                centerX: light.width / 2
                centerY: light.height / 2
                angle: 180 - light.corner
                GradientStop { position: 0; color: light.full }
                GradientStop { position: light.corner / 180; color: light.trace }
                GradientStop { position: 0.5; color: light.full }
                GradientStop { position: 0.5 + light.corner / 180; color: light.trace }
                GradientStop { position: 1; color: light.full }
            }

            startX: 0
            startY: 0
            PathLine { x: light.width; y: 0 }
            PathLine { x: light.width; y: light.height }
            PathLine { x: 0; y: light.height }
            PathLine { x: 0; y: 0 }
        }
    }
}
