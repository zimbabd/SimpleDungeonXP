# Simple Dungeon XP

![WoW Version](https://img.shields.io/badge/WoW-3.3.5-blue)
![Status](https://img.shields.io/badge/status-active-brightgreen)

## Overview

**Simple Dungeon XP** is a lightweight World of Warcraft addon for tracking dungeon leveling efficiency. It records XP gains, run duration, XP per hour, and other useful statistics for every dungeon run.

---

## Features

### Dungeon Run Tracking

Simple Dungeon XP automatically tracks:

- Dungeon name
- Run start and end time
- Total run duration (minutes and seconds)
- Experience gained (with correct levelup handling)
- Estimated XP per hour
- Number of hostile NPCs killed

### Dungeon Timer

The addon includes a separate timer window for tracking time spent in an instance.

- The timer starts when entering an instance and pauses when leaving.
- Returning to the same instance within 15 seconds resumes the timer; otherwise, it resets.
- A small countdown bar shows the remaining time before the paused timer resets.
- Timer position and size are saved between sessions.
- The timer can be locked to prevent moving or resizing it. Locking also hides its background and border.
- Timer visibility and locking can be controlled from the minimap button's right-click menu using `Show`, `Hide`, `Lock`, and `Unlock`.

---

## Screenshots
<img width="1009" height="549" alt="626001384-6b22cca6-57d7-427d-9ab1-c35638b1d0c3" src="https://github.com/user-attachments/assets/b6f9f062-c103-487f-bbdf-d593c15af078" />
<img width="630" height="308" alt="2026-07-21_133606" src="https://github.com/user-attachments/assets/b951a1a0-c5db-49ab-8b6b-2a7b818c5992" />
<img width="1920" height="1200" alt="2026-10-19_132527" src="https://github.com/user-attachments/assets/e5859e41-aae4-4303-9745-a04c9231c9ba" />




### Run History

The addon stores your previous dungeon runs and displays them in a simple statistics window.

Features:

- Keeps a history of up to 100 previous runs
- Shows your best XP/hour run highlighted in green
- Easy comparison between different dungeons
- Sortable columns: Dungeon name, Time, XP, XP/Hour
- Hover row highlight
- Per-row delete button
- Clear all history with confirmation

---

### User Interface

The addon includes:

- Movable statistics window
- Scrollable history table
- Minimap button
- Slash command support
- Right-click minimap menu for timer visibility and lock controls

Open the window using:

/sdxp

or click the minimap icon.

---

## Compatibility

Supported:

✅ World of Warcraft 3.3.5 clients
✅ Warmane - 3.3.5 servers
✅ Other standard WotLK 3.3.5 private servers

---

## Installation

1. Download the addon.
2. Extract the folder into:

World of Warcraft/Interface/AddOns/SimpleDungeonXP

3. Rename the folder from `SimpleDungeonXP-main` to `SimpleDungeonXP` if needed.
4. Restart the game.
5. Enable the addon in the character selection screen.

---

## Commands

Open statistics window:

/sdxp

Reset saved history:

/sdxp reset

---

## Development

Created and developed by:

**Yevhen Peresunko**

---

## Credits

Libraries used:

- LibStub
- LibDataBroker-1.1
- LibDBIcon-1.0
- CallbackHandler-1.0

Thanks to the developers of these open-source libraries.

---

## License

This project is released under the GPL-3.0 License.

You are free to modify and redistribute this addon while keeping the original credits.

