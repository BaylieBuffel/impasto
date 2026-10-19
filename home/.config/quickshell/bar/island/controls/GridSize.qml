// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G R I D   S I Z E                                                      │
// │   the control centre's columns and rows · shown while arranging          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"

// A card under the island while the grid is arranged: the largest grid in
// miniature, its cells in the real ones' proportions, with the current size
// lit from the top left. The cell under the pointer is the corner of the size
// a click makes (`ControlsService.resize`, which keeps the blocks centred on
// the real grid). The settings page shows the same picker, bare, in a row;
// beside the island it fills a card of its own, the figure over the cells.
Rectangle {
    id: root

    // Without its own card, for a settings row.
    property bool bare: false

    // Filling: the size it is given rather than its own, the figure on top
    // and the cells stretched to the rest.
    property bool filling: false

    // The miniature, at an eighth of the real cells, or whatever fills.
    readonly property real cellGap: root.filling ? Theme.centreGutter / 2 : Theme.centreGutter / 4
    readonly property real cellWidth: root.filling
        ? (root.width - (Theme.centreColumns - 1) * root.cellGap) / Theme.centreColumns
        : Theme.centreCellWidth / 8
    readonly property real cellHeight: root.filling
        ? (root.height - figure.height - layout.spacing
            - (Theme.centreRows - 1) * root.cellGap) / Theme.centreRows
        : Theme.centreCellHeight / 8

    readonly property int least: 2

    // The size under the pointer, or 0 when it is elsewhere.
    property int hoverColumns: 0
    property int hoverRows: 0

    readonly property int shownColumns: root.hoverColumns || ControlsService.columns
    readonly property int shownRows: root.hoverRows || ControlsService.rows

    implicitWidth: layout.implicitWidth + (root.bare ? 0 : 2 * Theme.cardPadding)
    implicitHeight: layout.implicitHeight
        + (root.bare ? 0 : 2 * Theme.cardRowGap + 2 * Theme.cardInset)
    radius: Theme.radiusLarge
    color: root.bare ? "transparent" : Theme.island
    border.color: Theme.borderIn(QsWindow.window)
    border.width: root.bare ? 0 : 1

    // Side by side, the figure on the right; filling, the figure on top.
    Grid {
        id: layout

        anchors.centerIn: root.filling ? undefined : parent
        columns: root.filling ? 1 : 2
        layoutDirection: root.filling ? Qt.LeftToRight : Qt.RightToLeft
        spacing: Theme.cardGap
        verticalItemAlignment: Grid.AlignVCenter

        Column {
            id: figure

            spacing: Theme.detailRowGap

            Text {
                text: `${root.shownColumns} × ${root.shownRows}`
                font.family: Theme.fontFamily
                font.pixelSize: root.filling ? Theme.fontSizeWidget : Theme.fontSizeLarge
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                text: Tr.t("columns × rows")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }
        }

        Grid {
            id: cells

            columns: Theme.centreColumns
            spacing: root.cellGap

            Repeater {
                model: Theme.centreColumns * Theme.centreRows

                Rectangle {
                    id: cell

                    required property int index

                    readonly property int column: cell.index % Theme.centreColumns
                    readonly property int row: Math.floor(cell.index / Theme.centreColumns)

                    function within(columns: int, rows: int): bool {
                        return cell.column < columns && cell.row < rows
                    }

                    readonly property bool lit: cell.within(root.shownColumns, root.shownRows)
                    readonly property bool current: cell.within(ControlsService.columns, ControlsService.rows)
                    readonly property bool previewing: root.hoverColumns > 0

                    width: root.cellWidth
                    height: root.cellHeight
                    radius: root.cellGap
                    color: !cell.lit ? Theme.islandSurfaceHover
                        : cell.previewing ? Qt.alpha(Theme.accent, 0.55) : Theme.accent
                    // While a new size is shown, the one in use keeps an outline.
                    border.width: cell.previewing && cell.current ? 1 : 0
                    border.color: Theme.accent

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered) {
                                root.hoverColumns = Math.max(root.least, cell.column + 1)
                                root.hoverRows = Math.max(root.least, cell.row + 1)
                            }
                        }
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: ControlsService.resize(Math.max(root.least, cell.column + 1),
                            Math.max(root.least, cell.row + 1))
                    }
                }
            }

            // The gaps between cells are the grid's too, so leaving a cell
            // for its neighbour does not flicker back to the size in use.
            HoverHandler {
                onHoveredChanged: {
                    if (!hovered) {
                        root.hoverColumns = 0
                        root.hoverRows = 0
                    }
                }
            }
        }
    }
}
