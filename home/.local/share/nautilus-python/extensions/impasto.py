# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   I M P A S T O                                                          │
# │   the file manager's right-click menu · terminal, editor, wallpaper      │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Right-click actions for Nautilus, each using a program from impasto.

Loaded by nautilus-python when Nautilus starts.
"""

import subprocess

from gi.repository import GObject, Nautilus


def run(*command):
    """Start a program detached from Nautilus."""
    try:
        subprocess.Popen(command, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


def copy(text):
    try:
        subprocess.run(["wl-copy"], input=text, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        pass


def item(name, label, icon, action):
    entry = Nautilus.MenuItem(name=f"Impasto::{name}", label=label, icon=icon)
    entry.connect("activate", lambda _entry: action())
    return entry


def folder_items(path):
    return [
        item("terminal", "Open Terminal Here", "utilities-terminal",
             lambda: run("kitty", "--working-directory", path)),
        item("yazi", "Open yazi Here", "folder-open",
             lambda: run("kitty", "--working-directory", path, "yazi")),
    ]


class ImpastoMenu(GObject.GObject, Nautilus.MenuProvider):

    def get_file_items(self, files):
        paths = [f.get_location().get_path() for f in files]
        if not paths or None in paths:
            return []

        items = []
        if len(files) == 1 and files[0].is_directory():
            items += folder_items(paths[0])
        items.append(item("editor", "Open in the Editor", "accessories-text-editor",
                          lambda: run("codium", *paths)))
        if len(files) == 1 and files[0].get_mime_type().startswith(("image/", "video/")):
            items.append(item("wallpaper", "Set as Wallpaper",
                              "preferences-desktop-wallpaper",
                              lambda: run("qs", "ipc", "call", "wallpaper", "set", paths[0])))
        items.append(item("copy-path", "Copy Path", "edit-copy",
                          lambda: copy("\n".join(paths))))
        return items

    def get_background_items(self, folder):
        path = folder.get_location().get_path()
        if path is None:
            return []
        return folder_items(path) + [
            item("editor-here", "Open in the Editor", "accessories-text-editor",
                 lambda: run("codium", path)),
        ]
