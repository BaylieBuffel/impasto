// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G R O U N D   R O W                                                    │
// │   settings · what one layer is made of, classic, glass or liquid         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"
import "../services"
import "../components"

// One layer's ground, on the page of the layer it paints.
SettingRow {
    id: root

    // The setting that holds it: surfaceStyle, dockGround, desktopGround or
    // terminalGround.
    required property string key

    // Empty, from a profile saved when the layer could follow the bar, is
    // drawn as the bar's, so it reads as the bar's.
    readonly property string stored: SettingsService[root.key] === ""
        ? SettingsService.surfaceStyle : SettingsService[root.key]
    readonly property string value: Theme.seeThrough(root.stored) ? root.stored : "classic"

    label: Tr.t("Ground")
    reading: root.value === "liquid" ? Tr.t("Clear frosted glass, lit at the edge")
        : root.value === "glass" ? Tr.t("The terminal's glass, over a blur")
        : Tr.t("Solid black")

    SegmentedControl {
        options: [
            { id: "classic", label: Tr.t("Classic") },
            { id: "glass", label: Tr.t("Glass") },
            { id: "liquid", label: Tr.t("Liquid") }
        ]
        current: root.value
        onSelected: id => SettingsService.set(root.key, id)
    }
}
