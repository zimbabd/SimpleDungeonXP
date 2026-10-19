# Changelog

## v4.0

### Fixes
- Fixed `IsInInstance()` not filtering instance type: only `party` and `raid` instances now trigger tracking (BGs, arenas, and outdoor zones are ignored).
- Replaced non-existent `CHAT_MSG_COMBAT_XP_GAIN` event with `COMBAT_LOG_EVENT_UNFILTERED` + `UNIT_DIED` subtype. Mob kill counter now actually works on 3.3.5 clients.
- Fixed `GetInstanceInfo()` returning an empty string right after the loading screen. Added retry logic via `OnUpdate` (up to 3 seconds) before falling back to "Unknown Dungeon".
- Fixed XP tracking breaking on levelup: `PLAYER_XP_UPDATE` now correctly accounts for the XP earned to cross a level boundary using `UnitXPMax`.
- Added persistent active run state. Progress is no longer lost on `/reload` while inside a dungeon.

### Improvements
- Duration is now stored as raw seconds (`duration` field) and displayed as `Xm Ys`. Old history entries using the float `time` field are still displayed correctly.
- Added `PLAYER_LOGIN` event to restore an active run after `/reload`.
- Fixed sort header "Time" using stale key `"time"`; updated to `"duration"`.
- `deleteBtn` is now properly hidden for empty rows and shown only for populated ones.
- Fixed `bestXPH == 0` edge case where all rows were incorrectly highlighted green.
- Fixed delete button closure capturing loop variable instead of the actual entry.
- Removed all references to Ascension WoW. Addon targets Warmane and standard WotLK 3.3.5 clients.


## v3.2

### New
- Added row hover highlighting (semi-transparent gray background on mouse over).
- Added individual "X" delete buttons per history row.
- Added "Clear History" button with confirmation popup.

### Improvements
- Fixed all function ordering and circular dependency issues.


## v3.1

### New
- Increased run history limit from 10 to 100 entries.
- Added a scrollable history list.
- Added sorting by Time, XP Gained and XP/H.

### Improvements
- Improved history table usability.

