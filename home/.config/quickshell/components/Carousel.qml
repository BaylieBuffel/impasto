// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A R O U S E L                                                        │
// │   horizontal carousel · the centred tile enlarged                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// A horizontal strip of tiles with the current one centred and enlarged.
//
// Only `position` animates; each tile derives its offset and scale from its
// distance to it, so a step is one animation and a held arrow key retargets
// it instead of queueing. Delegates are `CarouselTile`s, which read the
// geometry through `parent`.
Item {
    id: root

    property alias model: repeater.model
    property alias delegate: repeater.delegate

    property int current: 0
    readonly property int count: repeater.count

    property int tileWidth: 160
    property int tileHeight: 100
    property real centreScale: 1.25
    property int gap: 12

    // Tiles further than this from the centre are not drawn.
    property real reach: 3

    // The centre tile was clicked, or Enter was pressed.
    signal activated(int index)

    // Fractional while sliding.
    property real position: root.current

    Behavior on position {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    implicitHeight: Math.ceil(root.tileHeight * root.centreScale)
    clip: true

    // Offset of a tile `distance` steps from the centre. The first step spans
    // half the large tile and half a small one; later steps a small one.
    // Linear in between, so sliding is continuous.
    readonly property real firstStep:
        root.tileWidth * root.centreScale / 2 + root.gap + root.tileWidth / 2
    readonly property real stride: root.tileWidth + root.gap

    function offsetOf(distance: real): real {
        const away = Math.abs(distance)
        const offset = away <= 1
            ? away * root.firstStep
            : root.firstStep + (away - 1) * root.stride
        return distance < 0 ? -offset : offset
    }

    function scaleOf(distance: real): real {
        return 1 + (root.centreScale - 1) * Math.max(0, 1 - Math.abs(distance))
    }

    function goTo(index: int): void {
        if (root.count === 0)
            return
        root.current = Math.max(0, Math.min(root.count - 1, index))
    }

    function step(delta: int): void {
        root.goTo(root.current + delta)
    }

    // Clicking the centre tile activates it; any other tile scrolls to it.
    function press(index: int): void {
        if (index === root.current)
            root.activated(index)
        else
            root.goTo(index)
    }

    Repeater { id: repeater }

    // Touchpads send many small deltas; accumulate them to one step per 120.
    // A WheelHandler hears only its own `orientation`, vertical unless told,
    // so a sideways swipe needs a second one.
    property real turned: 0

    function turn(delta: real): void {
        root.turned += delta
        while (Math.abs(root.turned) >= 120) {
            root.step(root.turned < 0 ? 1 : -1)
            root.turned -= 120 * Math.sign(root.turned)
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.turn(event.angleDelta.y)
    }

    WheelHandler {
        orientation: Qt.Horizontal
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.turn(event.angleDelta.x)
    }

    // Held and dragged sideways: a step for every tile's width travelled,
    // the strip following the pointer.
    DragHandler {
        property int from: 0

        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onActiveChanged: if (active) from = root.current
        onTranslationChanged: {
            if (active)
                root.goTo(from - Math.round(translation.x / root.stride))
        }
    }
}
