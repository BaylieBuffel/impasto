-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │                                                                          │
-- │   P R O G R A M S                                                        │
-- │   default applications · consumed by other modules                       │
-- │                                                                          │
-- │   github.com/andreumassanet/impasto                                      │
-- │                                                                          │
-- ╰──────────────────────────────────────────────────────────────────────────╯

-- Single place declaring which program does what. To use it:
--     local apps = require("modules.programs")

return {
    terminal     = "kitty",
    file_manager = "nautilus --new-window",

    -- The system default browser.
    browser      = [[gtk-launch "$(xdg-settings get default-web-browser)"]],
}
