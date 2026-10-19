// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A M E R A   P A N E L                                                │
// │   camera effects · the picture calls see, its effect and its reactions   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"

// What the virtual camera sends, read back from it as any call would, so the
// preview is the picture the others get. Beside it the gestures that set off
// a reaction; under it the effects, one at a time.
ColumnLayout {
    id: root

    signal closed()

    spacing: 14

    readonly property bool live: CameraService.ready && CameraService.enabled

    Component.onCompleted: {
        CameraService.check()
        root.forceActiveFocus()
    }

    Keys.onLeftPressed: strip.step(-1)
    Keys.onRightPressed: strip.step(1)

    // One effect on the sample portrait, drawn once: the colour ones graded
    // in the palette, the blur behind the cut-out person, centre stage
    // closer in, the marks where the face is.
    component Sample: Item {
        id: sample

        property string effect: "natural"

        readonly property bool graded: ["palette", "mono", "warm"].indexOf(sample.effect) >= 0

        Image {
            id: portrait

            anchors.fill: parent
            anchors.margins: sample.effect === "stage" ? -parent.width * 0.22 : 0
            source: CameraService.sample
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(256, 256)
            visible: !sample.graded && sample.effect !== "blur"
        }

        MultiEffect {
            anchors.fill: parent
            visible: sample.graded || sample.effect === "blur"
            source: portrait
            saturation: sample.effect === "mono" ? -1 : sample.effect === "palette" ? -0.6 : 0
            contrast: sample.effect === "mono" ? 0.15 : 0
            colorization: sample.effect === "palette" ? 0.45 : sample.effect === "warm" ? 0.25 : 0
            colorizationColor: sample.effect === "warm" ? Theme.yellow : Theme.accent
            blurEnabled: sample.effect === "blur"
            blur: 1
            blurMax: 32
        }

        // The person, sharp, over the blurred picture.
        Image {
            id: cutout

            anchors.fill: parent
            source: CameraService.sampleMask
            sourceSize: Qt.size(256, 256)
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            visible: sample.effect === "blur"
            source: portrait
            maskEnabled: true
            maskSource: cutout
        }

        Text {
            readonly property var mark: ({
                shades: { glyph: "🕶️", at: CameraService.sampleEyes, size: 0.42 },
                crown: { glyph: "👑", at: Qt.point(CameraService.sampleForehead.x,
                                                  CameraService.sampleForehead.y - 0.12), size: 0.4 },
                sparkle: { glyph: "✨", at: Qt.point(0.8, 0.22), size: 0.3 }
            })[sample.effect] ?? null

            visible: mark !== null
            x: (mark?.at.x ?? 0) * sample.width - width / 2
            y: (mark?.at.y ?? 0) * sample.height - height / 2
            text: mark?.glyph ?? ""
            font.pixelSize: Math.round((mark?.size ?? 0.3) * sample.width)
        }
    }

    component Pill: Rectangle {
        id: pill

        property string label: ""
        property bool lit: false

        implicitWidth: row.implicitWidth + 24
        implicitHeight: 26
        radius: height / 2
        color: Theme.island

        Row {
            id: row

            anchors.centerIn: parent
            spacing: 6

            Rectangle {
                visible: pill.lit
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 4
                color: Theme.indicatorBad
            }

            Text {
                text: pill.label
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: pill.lit ? Font.Bold : Font.Normal
                color: pill.lit ? Theme.text : Theme.textMuted
            }
        }
    }

    // ── PREVIEW AND REACTIONS ───────────────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        ClippingRectangle {
            id: preview

            Layout.preferredWidth: 480
            Layout.preferredHeight: 270
            radius: Theme.radiusMedium
            color: Theme.surfaceIn(QsWindow.window)
            border.color: Theme.borderIn(QsWindow.window)
            border.width: 1
            contentUnderBorder: true

            MediaDevices { id: media }

            // Built only while the server runs, so the panel never holds the
            // device open on its own.
            Loader {
                anchors.fill: parent
                active: root.live && CameraService.serving

                sourceComponent: Item {
                    CaptureSession {
                        camera: Camera {
                            cameraDevice: media.videoInputs.find(
                                device => device.description === "impasto camera") ?? null
                            active: cameraDevice !== null
                        }
                        videoOutput: output
                    }

                    // Shown as a mirror, as every call shows you yourself;
                    // what the others get is not flipped.
                    VideoOutput {
                        id: output

                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectCrop
                        transform: Scale {
                            origin.x: output.width / 2
                            xScale: -1
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width * 0.8
                visible: !root.live || CameraService.state !== "live"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: !CameraService.checked ? ""
                    : !CameraService.ready
                      ? (CameraService.missing.indexOf("camera") >= 0
                         ? Tr.t("No camera is plugged in.")
                         : Tr.t("Run ./setup camera once to set the virtual camera up."))
                    : !CameraService.enabled ? Tr.t("The virtual camera is off.")
                    : CameraService.state === "error" ? Tr.t("The camera could not be opened. Another program may be holding it.")
                    : Tr.t("Waking the camera")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeRegular
                color: Theme.textMuted
            }

            Pill {
                anchors { left: parent.left; top: parent.top; margins: 12 }
                visible: root.live && CameraService.state === "live"
                lit: CameraService.others.length > 0
                label: lit ? Tr.t("LIVE") : Tr.t("Preview")
            }

            // The flash of a photo being taken.
            Rectangle {
                id: flash

                anchors.fill: parent
                color: Theme.text
                opacity: 0

                NumberAnimation on opacity {
                    id: flashing

                    running: false
                    from: 0.8
                    to: 0
                    duration: Theme.durationMorph
                    easing.type: Easing.OutCubic
                }
            }

            // The shutter: the picture as the preview shows it, saved and copied.
            Rectangle {
                id: shutter

                anchors { right: parent.right; bottom: parent.bottom; margins: 12 }
                visible: root.live && CameraService.state === "live"
                width: 46
                height: 46
                radius: width / 2
                color: "transparent"
                border.width: 3
                border.color: Theme.text
                opacity: CameraService.snapping ? 0.5 : 1

                Rectangle {
                    anchors.centerIn: parent
                    width: press.pressed ? 30 : 36
                    height: width
                    radius: width / 2
                    color: Theme.text

                    Behavior on width { NumberAnimation { duration: Theme.durationFast } }
                }

                MouseArea {
                    id: press

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        flashing.restart()
                        CameraService.snap()
                    }
                }
            }

            Pill {
                anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
                visible: root.live && CameraService.fps > 0
                label: (CameraService.faces >= 0
                        ? `${CameraService.faces} ${CameraService.faces === 1 ? Tr.t("face") : Tr.t("faces")} · ` : "")
                    + `${Math.round(CameraService.fps)} fps`
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                CardHeading {
                    Layout.preferredHeight: Theme.cardRow + 4
                    verticalAlignment: Text.AlignTop
                    text: Tr.t("Reactions")
                }

                // A tile per gesture, lit while it sets off its reaction.
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 8

                    Repeater {
                        model: CameraService.reactions

                        Rectangle {
                            id: reaction

                            required property var modelData

                            readonly property bool on: CameraService.reacting(reaction.modelData.id)

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 44
                            radius: Theme.radiusSmall
                            color: hover.containsMouse ? Theme.surfaceHoverIn(QsWindow.window)
                                : Qt.alpha(Theme.surfaceHoverIn(QsWindow.window), 0)
                            border.width: 1
                            border.color: reaction.on ? Theme.accent : Theme.borderIn(QsWindow.window)

                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                            MouseArea {
                                id: hover

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: CameraService.setReaction(reaction.modelData.id, !reaction.on)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: reaction.modelData.gesture
                                    font.pixelSize: 18
                                    opacity: reaction.on ? 1 : 0.4

                                    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: Tr.t(reaction.modelData.label)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: reaction.on ? Font.DemiBold : Font.Normal
                                    color: reaction.on ? Theme.text : Theme.textMuted
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    // ── EFFECTS ─────────────────────────────────────────────────────────────

    Carousel {
        id: strip

        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        tileWidth: 84
        tileHeight: 84
        centreScale: 1.2
        gap: 10
        reach: 5
        model: CameraService.effects
        // An initial value, so the strip opens on the effect in use rather
        // than sliding to it.
        current: Math.max(0, CameraService.effects.findIndex(entry => entry.id === CameraService.effect))

        onCurrentChanged: {
            const chosen = CameraService.effects[strip.current]
            if (chosen && chosen.id !== CameraService.effect)
                SettingsService.set("cameraEffect", chosen.id)
        }

        delegate: CarouselTile {
            id: tile

            ClippingRectangle {
                anchors.fill: parent
                radius: 24
                color: Theme.islandSurface

                Sample {
                    anchors.fill: parent
                    effect: tile.modelData.id
                }
            }

            // The ring is a plain Rectangle over the picture: the clipping
            // one's own border is not antialiased once the carousel scales
            // the centred tile up.
            Rectangle {
                anchors.fill: parent
                radius: 24
                color: "transparent"
                border.width: 2
                border.color: Theme.accent
                antialiasing: true
                visible: tile.centred
            }
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: -8
        text: Tr.t(CameraService.effects[strip.current]?.label ?? "")
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Bold
        color: Theme.text
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.borderIn(QsWindow.window)
    }

    // ── STATUS LINE ─────────────────────────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        spacing: 12

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: !CameraService.checked ? ""
                : !CameraService.ready ? Tr.t("Not set up")
                : !CameraService.enabled ? Tr.t("Off · no program can use it")
                : CameraService.error !== "" ? CameraService.error
                : CameraService.others.length > 0
                  ? `${Tr.t("In use by")} ${CameraService.others.map(name => name.charAt(0).toUpperCase() + name.slice(1)).join(", ")}`
                : `${Tr.t("Pick")} “impasto camera” ${Tr.t("in any call")}`
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: CameraService.error !== "" ? Theme.indicatorBad : Theme.textMuted
        }

        Text {
            visible: CameraService.ready
            text: Tr.t("Virtual camera")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.text
        }

        ToggleSwitch {
            visible: CameraService.ready
            checked: CameraService.enabled
            onToggled: checked => SettingsService.set("cameraEnabled", checked)
        }
    }
}
