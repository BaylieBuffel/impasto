// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O N T R O L S   T R A Y                                              │
// │   block tray · shown while arranging the control centre                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"
import "../../../components"

// The card of blocks, on the bar's surface while the grid is being arranged,
// so a block can be dragged from it onto the island within one window. It
// starts under the island.
//
// Every block at the smallest size it offers, which is the size it is added
// at, packed in the grid's own cells; it grows on the grid.
EditTray {
    id: root

    // Parent for the drag ghost (the bar's overlay), so it can cross the
    // island.
    required property Item host

    // Where the card stands, handed in by the bar: centred under the island,
    // or beside it from `homeLeft`, with as many columns as `room` takes and
    // `tall` high. It is neither moved nor resized: only the desktop's is.
    property real homeTop: 0
    property real homeLeft: -1
    property real room: 0
    property real tall: 0

    // The block being dragged out of the card, or empty.
    property string pulling: ""

    // What a block is for, in the order the card shows them.
    groups: [
        { id: "controls", label: "Controls" },
        { id: "glance", label: "At a glance" },
        { id: "personal", label: "Personal" }
    ]
    readonly property var groupOf: ({
        toggles: "controls", volume: "controls", brightness: "controls", media: "controls",
        appearance: "controls", session: "controls", shortcuts: "controls",
        clock: "glance", calendar: "glance", weather: "glance", notifications: "glance",
        notes: "personal", tasks: "personal", pet: "personal", games: "personal", impasto: "personal"
    })

    entries: ControlsService.catalogue.map(entry => {
        const shape = ControlsService.parse(root.smallest(entry.id))
        return { id: entry.id, name: entry.name, cols: shape.cols, rows: shape.rows,
            group: root.groupOf[entry.id] ?? "personal" }
    })
    unitWidth: Theme.centreCellWidth
    unitHeight: Theme.centreCellHeight
    unitGap: Theme.centreGutter
    // A block is drawn denser than a desktop widget, so it is shown larger
    // than the desktop's three quarters: at nine tenths, six across and five
    // down, the card opens at the desktop card's size.
    readonly property bool beside: root.homeLeft >= 0
    startColumns: root.beside
        ? Math.max(1, Math.floor((root.room - 2 * root.pad + root.street) / root.strideX)) : 6
    startRows: 5
    factor: 0.9
    homeX: root.beside ? root.homeLeft : (root.width - root.card.width) / 2
    homeY: root.homeTop
    fixed: true
    fixedHeight: root.beside ? root.tall : 0
    receiving: ControlsService.dragging !== "" && ControlsService.landing === null

    function smallest(id: string): string {
        return ControlsService.sizesFor(id)[0] ?? "2x2"
    }

    // Published as an item rather than a rectangle so the service maps points
    // into it on demand; the card moves, and the island may still be
    // animating when it is made.
    Binding {
        target: ControlsService
        property: "tray"
        value: root.card
    }

    Component.onDestruction: {
        ControlsService.tray = null
        ControlsService.landing = null
    }

    // ── PIECE ───────────────────────────────────────────────────────────────

    delegate: Item {
        id: tile

        required property var modelData

        readonly property string blockId: tile.modelData.id
        readonly property string size: root.smallest(tile.blockId)
        readonly property var box: ControlsService.pixels(tile.size)
        readonly property real factor: tile.width / tile.box.width
        readonly property bool pulled: root.pulling === tile.blockId

        x: tile.modelData.x
        y: tile.modelData.y
        width: tile.modelData.width
        height: tile.modelData.height

        Item {
            width: tile.box.width
            height: tile.box.height
            scale: tile.factor
            transformOrigin: Item.TopLeft

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMedium
                color: "transparent"
                border.color: tile.pulled ? Theme.accent : "transparent"
                border.width: 2 / tile.factor
            }

            BlockFace {
                anchors.fill: parent
                blockId: tile.blockId
                size: tile.size
                enabled: false
            }
        }

        HoverHandler {
            cursorShape: tile.pulled ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: ControlsService.add(tile.blockId)
        }

        DragHandler {
            id: pull

            target: null

            onActiveChanged: {
                if (pull.active) {
                    root.pulling = tile.blockId
                    root.aim(pull.centroid.scenePosition)
                    return
                }
                const spot = ControlsService.landing
                const blockId = root.pulling
                root.pulling = ""
                ControlsService.landing = null
                if (spot)
                    ControlsService.add(blockId, spot.col, spot.row)
            }

            onCentroidChanged: {
                if (pull.active)
                    root.aim(pull.centroid.scenePosition)
            }
        }
    }

    // ── GHOST ───────────────────────────────────────────────────────────────
    //
    // The dragged block at its landing size, over the island, with the landing
    // cell highlighted on the grid. Hidden while the pointer is over the card.
    function aim(scene: point): void {
        const board = ControlsService.board
        const at = root.host.mapFromItem(null, scene.x, scene.y)
        ghost.x = at.x - ghost.width / 2
        ghost.y = at.y - ghost.height / 2
        if (!board)
            return
        const pointer = board.mapFromItem(null, scene.x, scene.y)
        if (ControlsService.overTray(pointer.x, pointer.y)) {
            ControlsService.landing = null
            return
        }
        const corner = board.mapFromItem(root.host, ghost.x, ghost.y)
        const spot = ControlsService.nearestFree(
            ControlsService.cellX(corner.x), ControlsService.cellY(corner.y), ghost.size, "")
        ControlsService.landing = spot
            ? { col: spot.col, row: spot.row, size: ghost.size } : null
    }

    Item {
        id: ghost

        readonly property string size: root.smallest(root.pulling)
        readonly property var box: ControlsService.pixels(ghost.size)

        parent: root.host
        z: 100
        visible: root.pulling !== ""
        width: ghost.box.width
        height: ghost.box.height
        opacity: 0.9

        Rectangle {
            anchors.fill: parent
            anchors.margins: -6
            radius: Theme.radiusLarge
            color: Theme.island
            border.color: Theme.accent
            border.width: 2
        }

        BlockFace {
            anchors.fill: parent
            blockId: root.pulling
            size: ghost.size
            enabled: false
        }
    }
}
