// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G L A S S   S H E E N                                                  │
// │   the light in a glass ground · its thick edge, and the top lit          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// Laid over a ground in the glass style (`Theme.glass`) and under what is on
// it: the thick edge of a pane — light caught just inside the rim, fading in
// over a few pixels — and light falling from the top. Takes its parent's
// corners, since `clip` would cut it square. Liquid's edge is lit from one
// side (`LitEdge`).
Item {
    id: root

    required property Item shape
    // Off where the ground runs on past its own rectangle (the attached
    // notch), whose edge follows the fillets instead (`NotchOutline`).
    property bool edges: true
    // Whose glass: the bar's unless the dock or the desk hands in its own.
    property string style: Theme.surfaceStyle

    anchors.fill: parent
    visible: Theme.seeThrough(root.style)

    component Band: Rectangle {
        required property int inset
        required property real strength

        anchors.fill: parent
        anchors.margins: inset
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, Theme.edgeOf(root.style) * strength)
        radius: Math.max(0, root.shape.radius - inset)
        topLeftRadius: Math.max(0, root.shape.topLeftRadius - inset)
        topRightRadius: Math.max(0, root.shape.topRightRadius - inset)
        bottomLeftRadius: Math.max(0, root.shape.bottomLeftRadius - inset)
        bottomRightRadius: Math.max(0, root.shape.bottomRightRadius - inset)
    }

    Rectangle {
        id: sheen

        anchors.fill: parent
        radius: root.shape.radius
        topLeftRadius: root.shape.topLeftRadius
        topRightRadius: root.shape.topRightRadius
        bottomLeftRadius: root.shape.bottomLeftRadius
        bottomRightRadius: root.shape.bottomRightRadius
        readonly property real span: Theme.glassSheenDepth / Math.max(1, height)

        gradient: Gradient {
            GradientStop { position: 0; color: Theme.sheenOf(root.style) }
            GradientStop {
                position: Math.min(1, sheen.span)
                color: Qt.rgba(1, 1, 1, Theme.sheenOf(root.style).a * Math.max(0, 1 - 1 / sheen.span))
            }
        }
    }

    LitEdge {
        anchors.fill: parent
        style: root.style
        visible: root.edges

        // A style lit from one side draws its rim's light here, where it
        // can fade with the rest.
        Rectangle {
            anchors.fill: parent
            visible: Theme.litOf(root.style)
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, Theme.litRim)
            radius: root.shape.radius
            topLeftRadius: root.shape.topLeftRadius
            topRightRadius: root.shape.topRightRadius
            bottomLeftRadius: root.shape.bottomLeftRadius
            bottomRightRadius: root.shape.bottomRightRadius
        }

        Band { inset: 1; strength: 1 }
        Band { inset: 2; strength: 0.6 }
        Band { inset: 3; strength: 0.35 }
        Band { inset: 4; strength: 0.15 }
    }
}
