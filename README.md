# Todo Tracker

A tiny per-character ToDo list for World of Warcraft, styled after the Questie tracker: transparent while idle (backdrop only on mouseover), freely movable, and hidden entirely while the list is empty.

## Features

- Questie-tracker look: unobtrusive, highlights only on mouseover
- Quick-add via **Alt+D** (one ToDo: Enter adds and closes) or **Alt+Shift+D** (several: stays open, Enter adds, Esc closes)
- Inline input via the **plus button** next to the title
- **Checkbox** to mark a ToDo as done (greyed out)
- **Right-click** a row to delete it
- Drag the **title bar** to move the window — position is saved per character
- Window is hidden while the list is empty

## Slash commands

| Command | Effect |
| --- | --- |
| `/todo` | Quick-add one ToDo (Enter adds and closes) |
| `/todo multi` | Quick-add several ToDos (stays open until Esc) |
| `/todo add <text>` | Add a new ToDo directly |
| `/todo help` | Show the help listing in chat |

## Installation

Install from CurseForge, or copy the `TodoTracker` folder into `World of Warcraft\_anniversary_\Interface\AddOns\`.

## Key binding

On first login the addon binds **Alt+D** (one ToDo) and **Alt+Shift+D** (several ToDos) if those keys are free. You can change it any time under *Key Bindings → AddOns → Todo Tracker*; manual changes are respected and never overwritten.

## Saved data

ToDos and the window position are stored per character in `TodoTrackerDB` (SavedVariablesPerCharacter).

## Companion apps

Live export of the to-do list for companion apps (e.g. [WoW-Companion](https://github.com/HexToolFactory/wow-companion)) is handled by the separate [Companion Export](https://github.com/HexToolFactory/CompanionExport) addon, which reads `TodoTrackerDB` in game.
