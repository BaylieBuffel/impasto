// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B E Z E L   S H A P E                                                  │
// │   the bezel's silhouette · band, screen corners and drop as one fill     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "../theme"

// The band across the top, the screen's corners curving under its ends, and
// what the island drops out of its middle with a fillet either side, filled
// as one shape: what the bar's shadow is cast from and cut out by, so the
// pieces cast and clear one shadow and not one each.
Shape {
    id: root

    // The same measures as `BezelOutline`.
    property real bandHeight: 0
    property real corner: 0
    property real dropLeft: 0
    property real dropRight: 0
    property real dropDepth: 0
    property real dropRadius: 0
    property color color: Theme.island

    readonly property real h: root.bandHeight
    readonly property real c: root.corner
    readonly property bool dropped: root.dropDepth > 0
    readonly property real dl: root.dropped ? root.dropLeft : root.width / 2
    readonly property real dr: root.dropped ? root.dropRight : root.width / 2
    readonly property real depth: Math.max(0, root.dropDepth)
    readonly property real f: Math.min(Theme.radiusNotch * 2, root.depth)
    readonly property real r: Math.max(0, Math.min(root.dropRadius, root.depth,
        (root.dr - root.dl) / 2))

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.color
        strokeWidth: -1
        startX: 0
        startY: 0

        PathLine { x: root.width; y: 0 }
        PathLine { x: root.width; y: root.h + root.c }
        PathArc {
            x: root.width - root.c
            y: root.h
            radiusX: root.c
            radiusY: root.c
            direction: PathArc.Counterclockwise
        }
        PathLine { x: root.dr + root.f; y: root.h }
        PathArc {
            x: root.dr
            y: root.h + root.f
            radiusX: root.f
            radiusY: root.f
            direction: PathArc.Counterclockwise
        }
        PathLine { x: root.dr; y: root.h + root.depth - root.r }
        PathArc {
            x: root.dr - root.r
            y: root.h + root.depth
            radiusX: root.r
            radiusY: root.r
        }
        PathLine { x: root.dl + root.r; y: root.h + root.depth }
        PathArc {
            x: root.dl
            y: root.h + root.depth - root.r
            radiusX: root.r
            radiusY: root.r
        }
        PathLine { x: root.dl; y: root.h + root.f }
        PathArc {
            x: root.dl - root.f
            y: root.h
            radiusX: root.f
            radiusY: root.f
            direction: PathArc.Counterclockwise
        }
        PathLine { x: root.c; y: root.h }
        PathArc {
            x: 0
            y: root.h + root.c
            radiusX: root.c
            radiusY: root.c
            direction: PathArc.Counterclockwise
        }
        PathLine { x: 0; y: 0 }
    }
}
