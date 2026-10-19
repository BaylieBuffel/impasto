// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B E Z E L   O U T L I N E                                              │
// │   the bezel's edge · round the corners, under the band, round the drop   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import QtQuick.Shapes

import "../theme"

// One stroke from the left screen edge up the screen's corner curve, along
// the band's bottom, down the fillet, round what the island drops and up the
// other fillet, along the band again and down the right corner curve.
// Nothing runs along the screen edges. Drawn half a pixel inside the fill, as
// `NotchOutline` is.
Item {
    id: root

    // The band's height, and the screen corners' radius under it (0 square).
    property real bandHeight: 0
    property real corner: 0
    // What drops out of the band: its edges, depth below the band and lower
    // corners. A depth of 0 is no drop.
    property real dropLeft: 0
    property real dropRight: 0
    property real dropDepth: 0
    property real dropRadius: 0
    property color color: Theme.borderIn(QsWindow.window)
    // How far inside the rim the stroke runs, for the glass's thick edge.
    property int inset: 0

    readonly property real h: root.bandHeight
    readonly property real d: root.inset + 0.5
    readonly property bool dropped: root.dropDepth > 0
    // Neither the fillets nor the drop's corners run deeper than the drop.
    readonly property real f: Math.min(Theme.radiusNotch * 2, root.dropDepth)
    readonly property real r: Math.max(0, Math.min(root.dropRadius, root.dropDepth,
        (root.dropRight - root.dropLeft) / 2))
    readonly property real ri: Math.max(0, root.r - root.d)

    anchors.fill: parent

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 1
            strokeColor: root.color
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            startX: -root.d
            startY: root.h + root.corner

            PathArc {
                x: root.corner
                y: root.h - root.d
                radiusX: root.corner + root.d
                radiusY: root.corner + root.d
            }

            PathLine {
                x: root.dropped ? root.dropLeft - root.f : root.width - root.corner
                y: root.h - root.d
            }

            PathArc {
                x: root.dropped ? root.dropLeft + root.d : root.width - root.corner
                y: root.dropped ? root.h + root.f : root.h - root.d
                radiusX: root.f + root.d
                radiusY: root.f + root.d
            }
            PathLine {
                x: root.dropped ? root.dropLeft + root.d : root.width - root.corner
                y: root.dropped ? root.h + root.dropDepth - root.r : root.h - root.d
            }
            PathArc {
                x: root.dropped ? root.dropLeft + root.r : root.width - root.corner
                y: root.dropped ? root.h + root.dropDepth - root.d : root.h - root.d
                radiusX: root.ri
                radiusY: root.ri
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: root.dropped ? root.dropRight - root.r : root.width - root.corner
                y: root.dropped ? root.h + root.dropDepth - root.d : root.h - root.d
            }
            PathArc {
                x: root.dropped ? root.dropRight - root.d : root.width - root.corner
                y: root.dropped ? root.h + root.dropDepth - root.r : root.h - root.d
                radiusX: root.ri
                radiusY: root.ri
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: root.dropped ? root.dropRight - root.d : root.width - root.corner
                y: root.dropped ? root.h + root.f : root.h - root.d
            }
            PathArc {
                x: root.dropped ? root.dropRight + root.f : root.width - root.corner
                y: root.h - root.d
                radiusX: root.f + root.d
                radiusY: root.f + root.d
            }

            PathLine { x: root.width - root.corner; y: root.h - root.d }

            PathArc {
                x: root.width + root.d
                y: root.h + root.corner
                radiusX: root.corner + root.d
                radiusY: root.corner + root.d
            }
        }
    }
}
