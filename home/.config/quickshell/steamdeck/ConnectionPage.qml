// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O N N E C T I O N   P A G E                                          │
// │   which deck, how to reach it, and the key that lets this machine in     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../components"
import "../services"
import "../theme"

// The address `deck.py` keeps in the state directory, and the two things that
// most often stop a first connection: sshd not running on the Deck, and this
// machine's key not in its authorized_keys. The second is fixed in a terminal,
// because it asks for a password.
Item {
    id: root

    // What is in the fields, kept apart from what is saved so a half-typed
    // address is not sent on every keystroke.
    property var draft: ({ name: "Steam Deck", host: "Deck", user: "", port: "", key: "", path: "" })
    property bool ready: false

    function reset(): void {
        const settings = SteamDeckService.config
        root.draft = {
            name: String(settings.name ?? ""),
            host: String(settings.host ?? ""),
            user: String(settings.user ?? ""),
            port: Number(settings.port ?? 0) > 0 ? String(settings.port) : "",
            key: String(settings.key ?? ""),
            path: String(settings.path ?? "")
        }
        root.ready = true
    }

    onVisibleChanged: if (visible && !root.ready) root.reset()
    Component.onCompleted: if (visible) root.reset()

    Connections {
        target: SteamDeckService

        function onConfigChanged(): void {
            if (root.ready)
                root.reset()
        }
    }

    function edit(key: string, value: string): void {
        const next = Object.assign({}, root.draft)
        next[key] = value
        root.draft = next
    }

    function save(): void {
        SteamDeckService.save({
            name: root.draft.name,
            host: root.draft.host,
            user: root.draft.user,
            port: parseInt(root.draft.port) || 0,
            key: root.draft.key,
            path: root.draft.path
        })
    }

    Flickable {
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: body.implicitHeight

        ColumnLayout {
            id: body

            width: parent.width
            spacing: 18

            SettingGroup {
                title: Tr.t("The deck")

                note: Tr.t("An alias from ~/.ssh/config, or an address.")
                hint: Tr.t("Left as an alias (the usual Host Deck), the account, port and identity file come from ~/.ssh/config. Fill the rest only when the alias is not there to carry them.")

                SettingField {
                    label: Tr.t("Name")
                    placeholder: "Steam Deck"
                    value: root.draft.name
                    onEdited: value => root.edit("name", value)
                }

                SettingField {
                    label: Tr.t("Host")
                    placeholder: "Deck"
                    value: root.draft.host
                    onEdited: value => root.edit("host", value.trim())
                }

                SettingField {
                    label: Tr.t("Account")
                    placeholder: Tr.t("the ssh config's, or the deck's own")
                    value: root.draft.user
                    onEdited: value => root.edit("user", value.trim())
                }

                SettingField {
                    label: Tr.t("Port")
                    placeholder: "22"
                    value: root.draft.port
                    onEdited: value => root.edit("port", value.replace(/[^0-9]/g, ""))
                }

                SettingField {
                    label: Tr.t("Key")
                    placeholder: Tr.t("the ssh config's, or the agent's")
                    value: root.draft.key
                    onEdited: value => root.edit("key", value.trim())
                }

                SettingField {
                    label: Tr.t("Start in")
                    placeholder: "~"
                    value: root.draft.path
                    onEdited: value => root.edit("path", value.trim())
                }

                SettingBlock {
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: Tr.t("The shell never asks for a password. Without a key on the deck, Set up a key opens a terminal where ssh-copy-id can ask for one.")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }
            }

            // ── WHAT TO DO ──────────────────────────────────────────────────

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item { Layout.fillWidth: true }

                // Saving reads the deck again straight away, so the header's
                // light says whether the address works.
                PillButton {
                    icon: "󰄲"
                    text: Tr.t("Save")
                    enabled: root.draft.host.trim() !== "" && !SteamDeckService.saving.running
                    onClicked: root.save()
                }

                PillButton {
                    icon: "󰆏"
                    text: Tr.t("Set up a key")
                    enabled: root.draft.host.trim() !== ""
                    onClicked: SteamDeckService.askKey()
                }
            }

            // ── WHAT IS ON THE NETWORK ──────────────────────────────────────

            SettingGroup {
                title: Tr.t("On the network")

                note: Tr.t("Decks announce the ssh service over avahi.")
                hint: Tr.t("This reads what avahi has already seen on this machine; nothing is scanned. A Deck that is asleep is not there until it wakes.")

                SettingBlock {
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: SteamDeckService.discoveryTool !== ""
                                    ? Tr.t("avahi-browse is not installed here")
                                    : (SteamDeckService.hosts.length === 0
                                        ? Tr.t("Nothing seen yet") : "")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.textMuted
                            }

                            PillButton {
                                icon: "󰍉"
                                text: Tr.t("Look")
                                enabled: !SteamDeckService.discovering
                                onClicked: SteamDeckService.discover()
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: SteamDeckService.hosts

                                PillButton {
                                    required property var modelData

                                    icon: "󰓓"
                                    text: modelData.name + " · " + modelData.address
                                    onClicked: root.edit("host", modelData.address)
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
