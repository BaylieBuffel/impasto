// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O R N E R   G U A R D                                                │
// │   a right click on a window's first pixel · taken, so Qt never sees it   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

// Qt takes an unaccepted right click at a window's (0, 0) for a keyboard
// menu request and asks the focused item where it is; a layer surface has no
// focused item, and the shell crashes. This accepts that one pixel first, and
// sits under everything, so an item there that wants the click still gets it.
MouseArea {
    x: 0
    y: 0
    z: -1
    width: 1
    height: 1
    acceptedButtons: Qt.RightButton
}
