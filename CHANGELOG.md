# Changelog

## Unreleased

- Pixel export steps aside automatically when the Companion Export addon is loaded (it carries the to-dos)
- Pixel export v3: 4 brightness levels (base-4 digits) plus a 4-block grey calibration ramp – robust against display gain/HDR clipping (16 levels were not distinguishable on HDR screens)

## v1.1.0

- Alt+D now adds a single ToDo (Enter adds and closes); new **Alt+Shift+D** / `/todo multi` keeps the dialog open for several ToDos (Esc closes)
- Pixel export of the ToDo list (top-left colour strip) for companion apps; `/todo export on|off`

## v1.0.0

- Initial release
- Questie-tracker-style ToDo window: transparent while idle, movable via title bar, hidden while empty
- Quick-add dialog on Alt+D (auto-bound once if the key is free)
- Inline input via plus button
- Checkbox to mark done, right-click to delete
- Slash commands: `/todo`, `/todo add <text>`, `/todo help`
- ToDos and window position saved per character
