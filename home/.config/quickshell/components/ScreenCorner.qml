// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S C R E E N   C O R N E R                                              │
// │   one rounded corner of the screen · the square outside the curve        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "../theme"

// Drawn as the top left corner and turned into place by `turn`, in degrees
// clockwise: 90 is the top right, 180 the bottom right, 270 the bottom left.
Shape {
    id: root

    property int turn: 0
    property color color: Theme.island
    property real size: Theme.screenRadius

    // Set, not implicit: a Shape sizes itself to its path, and this path is
    // drawn from the size.
    width: root.size
    height: root.size
    rotation: root.turn
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.color
        strokeWidth: -1
        startX: 0
        startY: 0

        PathLine { x: root.width; y: 0 }
        PathArc {
            x: 0
            y: root.height
            radiusX: root.width
            radiusY: root.height
            direction: PathArc.Counterclockwise
        }
        PathLine { x: 0; y: 0 }
    }
}
