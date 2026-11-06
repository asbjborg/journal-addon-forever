# JournalingAddon Architecture

This addon uses a simple module split with toc load order. New features are added
as new Lua files and listed in both `JournalingAddon.toc` and `JournalingAddon_Camelot.toc`.

Forever client notes, the install copy, and the live checklist are in `docs/FOREVER.md`.

## Layout

Core (loaded first):
- `JournalingAddon/core/Namespace.lua` (shared `Journal` table + event bus)
- `JournalingAddon/core/Util.lua` (helpers: timestamps, JSON, money formatting)
- `JournalingAddon/core/Storage.lua` (SavedVariables, sessions, events, schema reset)
- `JournalingAddon/core/Renderers.lua` (message renderers registry)
- `JournalingAddon/core/Events.lua` (WoW events -> internal bus)

Features (loaded after core):
- `JournalingAddon/features/*.lua` (quest, travel, combat, screenshots, notes, etc.)

UI (loaded last):
- `JournalingAddon/JournalUI.lua`

## Event Lifecycle

1. `core/Events.lua` registers WoW events and calls `Journal.Emit(event, ...)`.
2. Feature modules register handlers via `Journal.On("EVENT", fn)`.
3. Handlers call `Journal:AddEvent(type, data)` to create a journal entry.
4. `Journal:AddEvent` uses the renderer for `type` to derive `msg`.
5. UI reads `entry.msg` (the derived message) and never infers from `data`.

## Renderer Contract

- `data` is the source of truth.
- `msg` is derived by a renderer and cached on the event.
- UI should use `msg` and not attempt to rebuild it.

## Schema policy

`Journal.CURRENT_SCHEMA` stays at 3. Loading the addon does not wipe sessions when `JournalDB.schemaVersion` differs. `/journal wipe` is still an explicit delete.

No per-entry migration runs. A saved v3 session is read as v3.

## Exported data and automation

Sessions are exported as NDJSON (one JSON object per line). This format is consumed by the **story-writer** workflow runner in this repo (`story-writer/`), which enriches quest events with Wowhead data and outputs JSONL. Automation is done in Node.js workflows there, not via n8n.

## Adding a New Feature

1. Create a new file under `JournalingAddon/features/`.
2. Register handlers with `Journal.On(...)`.
3. Register a renderer with `Journal:RegisterRenderer(type, fn)`.
4. Add the new file to `JournalingAddon.toc` under the features section.
