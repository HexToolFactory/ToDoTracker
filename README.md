# Todo Tracker

A tiny per-character ToDo list for World of Warcraft, styled after the Questie tracker: transparent while idle (backdrop only on mouseover), freely movable, and hidden entirely while the list is empty.

## Features

- Questie-tracker look: unobtrusive, highlights only on mouseover
- Quick-add dialog via **Alt+D** (Enter adds and clears the field, Escape closes — or tick *close on Enter* in the dialog to close it right away)
- Inline input via the **plus button** next to the title
- **Checkbox** to mark a ToDo as done (greyed out)
- **Right-click** a row to delete it
- Drag the **title bar** to move the window — position is saved per character
- Window is hidden while the list is empty

## Slash commands

| Command | Effect |
| --- | --- |
| `/todo` | Open the centered quick-add dialog |
| `/todo add <text>` | Add a new ToDo directly |
| `/todo help` | Show the help listing in chat |
| `/todo closeonenter on\|off` | Close the quick-add dialog right after Enter (default: off, stays open) |
| `/todo export on\|off` | Toggle the pixel export (default: on) |

## Installation

Install from CurseForge, or copy the `TodoTracker` folder into `World of Warcraft\_anniversary_\Interface\AddOns\`.

## Key binding

On first login the addon binds **Alt+D** to the quick-add dialog if that key is free. You can change it any time under *Key Bindings → AddOns → Todo Tracker*; manual changes are respected and never overwritten.

## Saved data

ToDos and the window position are stored per character in `TodoTrackerDB` (SavedVariablesPerCharacter).

## Pixel export (companion apps)

WoW addons cannot write files while you play, so the current list is also rendered as a small strip of coloured blocks in the top-left screen corner (4×4 px blocks, 16 colour levels per channel, CRC-protected). External tools such as [WoW-Companion](https://github.com/HexToolFactory/wow-companion) read it via screen capture to sync your ToDos about once a minute without a `/reload`. Disable with `/todo export off` if you don't need it.
