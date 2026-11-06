# Story-writer

Mini workflow-runner for journal addon: step templates + workflow instances. No n8n.

## Structure

- **steps/** – Reusable step templates (read-file, parse-jsonl, collect-quest-ids, fetch-wowhead-quests, parse-wowhead-html).
- **workflows/** – One folder per workflow; each runs a pipeline of steps with config.

## Run story-beat-writer

From this directory:

```bash
npm run story-beat-writer
```

Or:

```bash
node workflows/story-beat-writer/index.js
```

Default config uses `workflows/story-beat-writer/examples` (`ExampleRealm/ExampleHero/session-01`). That file is a made-up session, not a play log. Override via env or a **.env** file.

**Env file:** Put a `.env` in `workflows/story-beat-writer/` (or in the directory you run from). Copy from `.env.example` and edit. Variables:

- `PATH_TO_SESSIONS` – base path to session folders (realm/character/session-N/session-N.jsonl)
- `REALM`, `CHARACTER_NAME`, `SESSION`

Pipeline: read session JSONL → parse events → collect quest IDs → quest catalog step → **enrich** each quest event → output **JSONL** (one line per event). Non-quest lines are unchanged.

The catalog step does not call `https://www.wowhead.com/tbc/quest=`. That URL is the Burning Crusade catalog and would attach the wrong quest text to Forever ids. With `WOWHEAD_QUEST_BASE_URL` unset, each quest gets `data.questContext = { questID, error, catalog: "missing-forever-catalog" }`. The recorded `msg` and `data.title` stay as exported. This repo does not add a Forever Wowhead catalog and does not call an AI API.

To save that output: `npm run story-beat-writer > session-01-enriched.jsonl`

Static check: `npm test`.

The HTML files under `examples/wowhead/` are cached Burning Crusade pages kept so the parser can be read. They are not a source of Forever quest text.
