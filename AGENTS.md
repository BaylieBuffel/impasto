# AGENTS.md

## What this is

A Hyprland desktop shell (Quickshell/QML) that doubles as a dotfiles installer. Almost all code lives in `home/.config/quickshell/`. The rest of `home/` is the desk around it (Hyprland, kitty, starship, nvim, yazi, btop, cava, gtk…); `system/` lands in `/` (SDDM theme, systemd, faces); `packages/{pacman,aur}.txt` are the install lists. `setup` copies files — nothing is ever symlinked.

## Dev loop

- Edit under `home/` → run `./setup sync` to copy it into `$HOME`; `./setup sync --watch` re-syncs on every save (needs `inotify-tools`).
- `setup` keeps a sha256 manifest (`~/.local/state/impasto/`) and writes atomically via a `.impasto-new` temp file — Quickshell reloads on every write, so never write half-files and never match `.impasto-new` in edits (`.gitignore`'s `_probe*.qml`/`_mock*.qml` scratch files are safe to create for `qs -p` probing; `setup` won't install them).
- Prefer `./setup sync` over hand-copying into `$HOME`; setup detects pre-existing stow symlinks and unlinks them, puts conflicting files into `~/.local/state/impasto/backups/`, and leaves files you've edited alone (repo version written beside as `<name>.new`).
- `home/.config/quickshell` changes also need the shell reloaded; `sync` does this itself via `qs ipc call shell reload` once the copy has finished.

## Verification

- `./setup check` runs exactly what CI runs: `ast.parse` for Python, `luac -p` (falls back to `luac5.4`), `zsh -n` per-file, `bash -n setup`, strict JSON, and `tomllib` for TOML. It's syntax-only, no tests. The one `.jsonc` (fastfetch) is excluded from JSON parsing.
- New components must be registered: `home/.config/quickshell/qmldir` maps singleton services (usually in `services/`) and reusable types (usually in `components/`) to their files. A singleton without a `qmldir` line silently fails to resolve.

## Quickshell architecture

- `shell.qml` is the entry point; services are singletons built on first use, but boot-critical ones are touched in its `Component.onCompleted`.
- The QML UI is a thin layer: real work (weather, stats, wallpapers/palettes, git history, clipboards…) runs in the Python scripts under `scripts/` (e.g. `theme_manager.py`, `compositor.py`, `greeting.py`). They hand data to the QML via services and transient signals.
- Generated output (palettes, greeting GIFs, rebuilt cursors, `keys.tsv`, kitty palette fragments) goes to the XDG state dir (`~/.local/state/quickshell/`), never into the repo. Don't commit generated artifacts.
- Profiles write hot-reloadable keybindings to `~/.local/state/quickshell/keys.tsv`; `hypr/modules/keybinds.lua` reads them with fallbacks. The description field is the key — renaming a description drops its binding from every profile.

## Hyprland config

- Lua config (0.55+), `hyprland.lua` requires `modules/*.lua` in order; each module runs in its own scope so an error in one won't break the rest.

## setup gotchas

- Most verbs expect a running Hyprland session (plugins build against the compositor via `hyprpm`; `gsettings` needs the session bus). `./setup plugins` from outside a session just says so and skips.
- `IMPASTO_ROOT=/some/dir ./setup system` reroutes the `system/` (rootful) tree for testing; a writable root is written without sudo.
- `setup` installs only what git would carry (`git ls-files`), so a new file must be `git add`ed before `sync` picks it up.

## Branches and releases

- `main` moves only on release; work in progress lives on `dev` (`./setup update` follows whichever branch is checked out). CI's `check.yml` runs on both.
- Releases are tags `v*`; `release.yml` verifies the tag's commit is an ancestor of `origin/main` and publishes with `gh release create`.

## File structure highlights

```
home/.config/quickshell/
├── shell.qml              # Entry point
├── qmldir                 # Module/singleton registration (must edit when adding services/components)
├── Commands.qml           # Shell commands exposed to CLI
├── services/              # 50+ singleton services (Theme, Wallpaper, Hyprland, etc.)
├── components/            # Reusable QML types (Card, ModuleCard, RingIndicator, etc.)
├── scripts/               # Python workers (theme_manager.py, compositor.py, greeting.py, etc.)
├── bar/                   # Bar + island widgets, modules, panels
├── lock/                  # Lock screen
├── deck/                  # Notes deck
├── dock/                  # Dock
├── desktop/               # Desktop widgets
├── settings/              # Settings window
├── capture/               # Screen capture
└── theme/                 # Theme, Palettes, Motion, Board, Tr

home/.config/hypr/
├── hyprland.lua           # Main config (requires modules/*)
├── modules/
│   ├── keybinds.lua       # Reads ~/.local/state/quickshell/keys.tsv
│   └── ...                # animations, autostart, env, input, look, monitors, programs, windowrules
└── xdph.conf              # XDG portal config
```

## Key Python scripts (in `scripts/`)

| Script | Purpose |
|--------|---------|
| `theme_manager.py` | Palette extraction, wallpaper handling, color generation |
| `compositor.py` | Hyprland integration, window/workspace monitoring |
| `greeting.py` | Fastfetch greeting with pixel-art animation |
| `stats.py` | System stats (CPU, RAM, GPU, disk, network) |
| `clipboard.py` | Clipboard history |
| `weather.py` | Weather data |
| `applications.py` | App launcher data |
| `monitors.py` | Monitor configuration |
| `packages.py` | Package update checking |
| `updates.py` | Version/update checking |
| `capture.py` | Screen capture/selection |
| `record.py` | Screen recording |
| `rgb.py` | Keyboard, mouse and case-fan lighting from the palette |
| `account.py` | User account/face management |

## Common tasks

| Task | Command |
|------|---------|
| Install | `./setup install` |
| Update | `./setup update` |
| Sync dev changes | `./setup sync` or `./setup sync --watch` |
| Verify syntax | `./setup check` |
| Uninstall | `./setup uninstall` |
| Test system tree | `IMPASTO_ROOT=/tmp/test ./setup system` |

## Environment notes

- Requires Arch Linux, Hyprland 0.56+, Quickshell 0.3
- Python scripts need `psutil`, `requests`, `pillow`, `pywal` (installed via packages)
- `inotify-tools` needed for `--watch` mode
- SDDM theme in `system/usr/share/sddm/themes/impasto/`
- Face unlock via howdy-next (infrared camera required)