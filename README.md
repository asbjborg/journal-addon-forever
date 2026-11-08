# Journal addon

A World of Warcraft Forever addon for a personal journal of your adventures. It tracks quests, kills, loot, XP, travel, and the rest of the session, and it still takes manual notes, target captures, and scene captures. Forever install, live checks, and the story pilot are in [docs/FOREVER.md](docs/FOREVER.md).

## Features

### Automatic Tracking
- **Quest Logging**: Automatically logs quest acceptance and completion
- **Combat Activity**: Tracks kills and XP gains, combining them into activity entries per combat session
- **Loot Tracking**: Logs items looted from mobs (with smart aggregation)
- **Travel Logging**: Tracks zone changes, flight paths, hearthstone usage, and boat/zeppelin travel
- **Reputation**: Monitors reputation gains and tier changes
- **Screenshots**: Automatically logs when you take screenshots with filename
- **Death Tracking**: Logs when you die

### Manual Capture
- **Target Capture** (`/journal capture`): Document targets (NPCs, players, mobs) with screenshot and note
- **Scene Capture** (`/journal capture` without target): Take a screenshot with a note for documenting locations or moments
- **Note Entry** (`/journal note`): Add standalone multiline notes to your journal

### Session Management
- Sessions are automatically organized by character and day
- Sessions persist across reloads and relogs (same character + same day = same session)
- Character name visible in session labels
- Export sessions as plain text or NDJSON (machine-readable) for easy sharing, backup, or automation (e.g. story-writer workflows)

## Requirements

- World of Warcraft: Forever (1.60.x)
- Interface version: 16001
- This port does not target The Burning Crusade Classic

## Installation

Copy `JournalingAddon` into the Forever client's `Interface/AddOns` folder yourself. Do not use `rsync --delete`, and do not run `deploy.sh` (it exits without copying). SavedVariables are left alone. The schema stays at v3, so loading this version does not wipe an existing `JournalDB`.

Paths differ by install. This repository has not been checked against a live client. Look for the AddOns directory next to the Forever executable. Two locations that show up in public write-ups, and that still need a look on your machine, are a `_forever_` folder and a `_classic_beta_` folder. Details, the smoke checklist, and what is still unverified: [docs/FOREVER.md](docs/FOREVER.md).

## Usage

### Opening the Journal
- Type `/journal` in chat to open/close the journal UI
- Left-click the book button on the minimap to open and close that same window. Drag the button to move it. The angle is stored in `JournalDB.settings.minimapAngle` and does not change session entries or the schema.
- Use the dropdown to select different sessions
- Click "Export" to copy a session as plain text
- Click "JSON" to export as NDJSON (one JSON object per line) for automation (e.g. [story-writer](story-writer/) workflows)

### Commands
- `/journal` - Toggle the journal UI (the minimap button does the same thing)
- `/journal note` - Open dialog to add a standalone note
- `/journal capture` or `/journal capture-target` - Capture target (or scene) with screenshot and note
- `/journal undo` - Remove the last entry
- `/journal clear` - Clear all entries from current session
- `/journal reset` - End current session and start a fresh one
- `/journal wipe` - Wipe all journal data and start fresh
- `/journal help` - Show all available commands
- `/journal compat` - Print schema, session count, character key, and client build
- `/journal debug` - Toggle debug logging

### Entry Types

The journal automatically creates entries for:
- **Accepted**: Quest acceptance with name and ID
- **Turned in**: Quest completion with name and ID
- **Killed**: Mob kills with XP gained (aggregated per combat session)
- **Gained XP**: Non-combat XP gains
- **Looted**: Items looted from mobs
- **Traveled to**: Zone changes with subzone information
- **Hearth to**: Hearthstone usage
- **Started flying to**: Flight path initiation
- **Landed in**: Flight path completion
- **Reputation**: Reputation gains and tier changes
- **Screenshot**: Automatic screenshot logging
- **Died**: Player death events

Manual entries:
- **Spotted**: Target capture with level, reaction, race, class, note, and screenshot
- **Scene**: Screenshot with note (no target)
- **Note**: Standalone text note

## Data Storage

Journal data is stored in `SavedVariables/JournalDB.lua` in your WTF folder. This persists across game sessions and characters. Schema version stays 3. A character key is the given name, a space, and the surname when `UnitName` returns one, then a hyphen and the realm from `GetRealmName`. Hyphens inside a name are kept.

## Development

### Project Structure
```
JournalingAddon/
├── JournalingAddon.toc    # Addon manifest
├── core/                  # Namespace, storage, renderers, event bus
├── features/              # Feature modules (quest, combat, travel, etc.)
└── JournalUI.lua          # UI components and interaction
```

See `ARCHITECTURE.md` for the module layout and event flow.

### Automation and workflows

Session JSONL can be processed with the **story-writer** workflow runner (no n8n, no AI API). See [story-writer/](story-writer/). The quest step refuses the Burning Crusade Wowhead catalog so Forever quest ids are not filled with the wrong text. A one-session path from `/journal note` to a draft that stays tied to `msg` is in [docs/FOREVER.md](docs/FOREVER.md).

### Deployment

`deploy.sh` does not copy files. Install by the manual steps in [docs/FOREVER.md](docs/FOREVER.md).

## License

The addon stays under the original non-commercial license. Copyright (c) 2026 asbjborg. Stories, videos, and other creative works made from journal data may be published and monetized by their creators. This is not an OSI-approved open source license. See [LICENSE](LICENSE).

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## Author

asbjborg

## Version

See [changes.md](changes.md) for the current version and full version history.
