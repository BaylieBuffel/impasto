// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S T E A M   D E C K   W I N D O W                                      │
// │   the deck on the network · a regular, movable window                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../components"
import "../theme"

// The Deck is a window rather than an island panel: it is worked in for a
// while at a time, holds a file browser and a terminal's worth of output, and
// wants the size. An xdg-shell toplevel, so Hyprland moves, resizes, focuses
// and closes it like any other window; `windowrules.lua` floats and sizes it,
// matched on the title.
FloatingWindow {
    id: root
    CornerGuard {}

    // Kept in sync with `visible` both ways, so closing the window from the
    // compositor resets it and it can be opened again.
    property bool shown: false

    function open(): void { root.shown = true }
    function close(): void { root.shown = false }
    function toggle(): void { root.shown = !root.shown }

    // Matched by the window rule in `windowrules.lua`.
    title: "Steam Deck"

    implicitWidth: 1120
    implicitHeight: 720

    color: Theme.island
    visible: root.shown

    onVisibleChanged: {
        if (!root.visible && root.shown)
            root.shown = false
    }

    // Built on open and destroyed on close, so the pages read the Deck when
    // the window is looked at and stop when it is gone.
    Loader {
        anchors.fill: parent
        active: root.visible
        sourceComponent: panel
    }

    Component {
        id: panel

        SteamDeckPanel {
            onClosed: root.close()
        }
    }
}
