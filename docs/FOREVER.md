# WoW Forever port

This repository is a Forever-only port of [journal-addon](https://github.com/asbjborg/journal-addon) `v0.6.31` (`ab8fe5615018115a80c25074e8a562677aca966a`). The original repository is not modified by this work. Schema version stays **3**. Loading the addon does not wipe `JournalDB`.

Nothing in this file was checked inside a WoW client. Static tests run in Lua 5.4 and Node. Lines marked **Live** need a Forever client.

## What stayed

Sessions, entry shape, text export, and NDJSON export are the same v3 records: `v`, `ts`, `seq`, `type`, `data`, `msg`. `msg` is still the rendered line. The UI still reads `msg`. Notes, screenshots, target and scene capture, daily character sessions, and the Node story-writer are still here. There is no new backend and no AI integration.

## What changed for Forever

| Area | Behavior |
| --- | --- |
| TOC | `Interface: 16001` and `Interface-Camelot: 16001`. `JournalingAddon.toc` and `JournalingAddon_Camelot.toc` are the same file list. |
| Events | Each `RegisterEvent` is protected. `PARTY_MEMBERS_CHANGED` is not registered. Roster updates use `GROUP_ROSTER_UPDATE`. |
| Party size | `GetNumSubgroupMembers`, then `party1`..`partyN`. |
| Names | `UnitName`'s second return is treated as a surname, not a realm. Hyphens in the given name stay. The realm comes from `GetRealmName`. |
| Quests | `QUEST_ACCEPTED` is read as a quest id. The title comes from `C_QuestLog.GetTitleForQuestID`. |
| Hearth | Spell ids 8690 and 556. `C_Spell.GetSpellInfo` is read as a table. |
| Combat | `CombatLogGetCurrentEventInfo` is called only if it exists, inside `pcall`. Secret values are skipped. A kill name is also taken from `X dies, you gain N experience` when the log did not already count that kill. |
| Taxi | `TakeTaxiNode` is hooked only when the function exists. Flight chat and `UnitOnTaxi` still start and end flights. |
| Quests in story-writer | The Burning Crusade Wowhead URL is refused. Recorded `msg` is not replaced. |
| Install | `deploy.sh` exits without copying. |

`/journal compat` prints schema, session count, character key, combat-log state, taxi hook, build, and `WOW_PROJECT_ID`.

## Install without deleting anything

Do not run `deploy.sh`. Do not use `rsync --delete`. Do not copy this folder onto `_anniversary_` or `_classic_`.

1. In the Forever install, open `Interface/AddOns`. Public write-ups mention both `_forever_` and `_classic_beta_`. This repo has not seen either folder. Use the AddOns directory that belongs to the client whose `/dump select(4, GetBuildInfo())` prints `16001`.
2. If `JournalingAddon` is already there, rename that folder (for example `JournalingAddon-previous`). Do not delete it, and do not delete other addon folders.
3. Copy this repo's `JournalingAddon` directory into `AddOns`. A normal copy is enough. It must contain both TOC files and `core/Forever.lua`.
4. Leave `WTF/.../SavedVariables/JournalDB.lua` where it is.
5. Start the client. Enable JournalingAddon. `/reload` if it was already loaded.
6. `/journal compat` should show `schema 3` and a session count that matches the journal you already had.

## Static tests

These do not load WoW.

```bash
lua5.4 tests/forever_compat_test.lua
cd story-writer && npm test
```

`tests/forever_compat_test.lua` checks name, surname, hyphens, quest id, spell-info tables, hearth ids, the XP kill line, double-counting across combat log and chat, and the keep-on-schema-mismatch decision.

`story-writer/test/forever-catalog.test.js` checks that an empty URL and `https://www.wowhead.com/tbc/quest=` produce an error and no quest title, that the example session's `msg` survives enrichment, that the workflow file does not hard-code that TBC URL, that the two TOC files match, and that `InitDB` does not call `ResetDatabase`.

## Live smoke checklist

Run these on a Forever character. A static test passing does not check any of them.

1. **Load.** Addon list shows JournalingAddon 0.6.32. No BugSack error on login or `/reload`. `/journal compat` shows interface `16001`. If the addon is missing, say whether the client loaded `JournalingAddon.toc` or `JournalingAddon_Camelot.toc`.
2. **Data kept.** Session count from `/journal compat` is unchanged across a `/reload`. Do not run `/journal wipe` for this check.
3. **Project id.** Write down `projectId` and `projectCamelot` from `/journal compat`. Do not treat a mismatch with the notes below as an addon failure by itself. The addon does not branch on that number.
4. **Note.** `/journal note`, save one sentence. The line in the window is `Note: ` plus that sentence.
5. **Quest.** Accept a quest. The line is `Accepted: <title> (<id>)`. The id should match the quest, not a small log index such as 1 or 2. If the title is `Quest <number>`, `C_QuestLog.GetTitleForQuestID` did not return a name.
6. **Kill.** Kill one creature that grants experience. The activity line should name that creature. Then `/journal compat` and note `combatLog` (`readable`, `getter-missing`, `getter-error`, `unreadable`, or `unseen`).
7. **Name.** The character key should show the portrait name, including a surname and any hyphen, then the realm from the character select screen. A second character with a different surname must not share the key.
8. **Party.** Join one other player. Expect a join line with their name, hyphen included if they have one. Leave. Expect a leave line. No error on the roster update.
9. **Hearth.** Use the hearthstone. After the zone change, the line should be a hearth line rather than a plain zone change. Note the spell id if you can (`/dump C_Spell.GetSpellInfo(8690)`).
10. **Flight.** Take one taxi. Expect a flight-start line. `/journal compat` shows `taxiHook` as `hooked` or `TakeTaxiNode missing`. If the destination is blank, the hook was missing and the `Taking flight to:` chat line did not fire. That is a known gap, not a reason to delete flight tracking.
11. **Export.** Select the session, click JSON. The note line's `msg` equals the journal window. `v` is 3.

## Evidence and unknowns

| Claim | What we found | What this port does | Still needs a client |
| --- | --- | --- | --- |
| Interface 16001, version 1.60.x | [Patch 1.60.1/API changes](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes) lists TOC `16001`. Third-party notes agree. | Both TOC files say `16001`. | Step 1 of the checklist. |
| `_Camelot` TOC suffix, `forever` alias | The same wiki page says Forever is an alias of Camelot in TOC suffixes (`MyAddon_Forever.toc`) as of build 70291. [A community API article](https://wowforeveraddons.com/articles/wow-forever-addon-api) cites `_Camelot.toc` and `## Interface-Camelot: 16001` in shipping addons. | Both the plain TOC and `_Camelot.toc` are shipped, same contents, plus `Interface-Camelot: 16001`. `AllowLoadGameType` is not set. An unrecognized game type can skip the addon, and the wiki's `forever` token was added during the beta. | If the addon does not load, record which TOC the client wanted. |
| `WOW_PROJECT_ID` | Wiki footnote: early reports matched retail (`1`). Later text documents `WOW_PROJECT_CAMELOT` (`18`). [A cheat sheet](https://wowforeverguides.com/addons/api-cheatsheet) says build 69913 reported `1` and a later 70338 probe reported `18`. | Printed by `/journal compat` only. No feature is gated on it. | Step 3. |
| Unknown events throw | [ForeverPlusPlus `docs/forever-api.md`](https://github.com/xIGBClutchIx/ForeverPlusPlus/blob/main/docs/forever-api.md) says registering an unknown event throws and aborts the file. Upstream [issue 64](https://github.com/asbjborg/journal-addon/issues/64) shows that failure for `PARTY_MEMBERS_CHANGED`. | That event is gone. Every remaining registration is inside `pcall`. `GROUP_ROSTER_UPDATE` is listed for Forever on [Warcraft Wiki](https://warcraft.wiki.gg/wiki/GROUP_ROSTER_UPDATE). | Step 8, and any `event ... FAILED` line from `/journal compat`. |
| Quest accept payload | Classic passes log index then id and reads `GetQuestLogTitle`. ForeverPlusPlus lists `GetQuestLogTitle` as removed and `C_QuestLog` as present. Mainline `QUEST_ACCEPTED` is the quest id. | Forever-only: one numeric argument, title from `C_QuestLog.GetTitleForQuestID`. | Step 5. A small id means the payload is still index-first. |
| `C_Spell.GetSpellInfo` | ForeverPlusPlus and the cheat sheet: the call returns one table, not the old multi-value `GetSpellInfo`. Hearth ids 8690 and 556 are the usual spells. | Table field `name`, plus those two ids. | Step 9. |
| Surname | ForeverPlusPlus, in-game 2026-09-25: `UnitName("player")` returned `"Clutch", "Bloodfury"`. The same note says names can be `First Surname` or `First-Surname`, and the part after `-` is not a realm. | Second return is appended with a space when it differs from `GetRealmName`. Hyphens are not stripped. | Step 7. If the portrait uses a hyphen between the two parts, say so. The key would still contain both parts. |
| Combat log | ForeverPlusPlus: `CombatLogGetCurrentEventInfo` is gone, and `COMBAT_LOG_EVENT_UNFILTERED` never fired for the addons they read. The cheat sheet says that is unverified and not a reason to delete kill tracking. Separate community posts disagree. | The event stays registered. The getter is optional and guarded. The English XP line still supplies a kill name, and the two sources do not double-count inside 1.5 seconds. | Step 6. A localized chat line will not match `dies, you gain`. |
| `TakeTaxiNode` | ForeverPlusPlus marks `TakeTaxiNode(slot)` unverified on the live client. | Hook only when the global is a function. Other flight signals remain. | Step 10. |
| SavedVariables | ForeverPlusPlus: they persist after the 2026-09-24 fix, and they did not on 2026-09-23. | No workaround added. `/journal compat` session count is the check. | Step 2. |
| Install directory | Sources disagree (`_forever_` vs `_classic_beta_`). | Not chosen here. | Whichever folder has interface 16001. |

## Open issues on the original repo

Read-only. Nothing here closes, edits, or transfers an issue. The original list was taken from `asbjborg/journal-addon` on 2026-11-06. The only open bug is the event-registration failure this port avoids. The rest are features. They are not implemented in this port.

**Already covered by this port, still open upstream**

- [BugSack: unknown event PARTY_MEMBERS_CHANGED in TBC Classic 2.5.5](https://github.com/asbjborg/journal-addon/issues/64) — the same registration throw would stop Forever load. This port registers `GROUP_ROSTER_UPDATE` instead.

**Next session after a live smoke, not a backlog feature**

One real note, a few minutes of play, JSON export, and a short draft grounded in `msg`. See below. Do this before any of the feature issues.

**Leave for later, in this order, only if a person still wants them**

1. [Log when player reclaims body](https://github.com/asbjborg/journal-addon/issues/55) and [Track when learning new spells/abilities](https://github.com/asbjborg/journal-addon/issues/56) — closest to the combat and spell surface that is still unverified.
2. [Log Hearthstone location when setting a new home](https://github.com/asbjborg/journal-addon/issues/13) — using the hearth is already logged. Setting the home is not.
3. Session tools, as a group: [settings](https://github.com/asbjborg/journal-addon/issues/6), [merge](https://github.com/asbjborg/journal-addon/issues/7), [manual controls](https://github.com/asbjborg/journal-addon/issues/8), [search](https://github.com/asbjborg/journal-addon/issues/9), [rename](https://github.com/asbjborg/journal-addon/issues/10), [retention](https://github.com/asbjborg/journal-addon/issues/11), [split](https://github.com/asbjborg/journal-addon/issues/12).
4. Extra logs: [crafting](https://github.com/asbjborg/journal-addon/issues/14), [mail received](https://github.com/asbjborg/journal-addon/issues/15), [mail sent](https://github.com/asbjborg/journal-addon/issues/16), [food and drink](https://github.com/asbjborg/journal-addon/issues/17), [vendor junk](https://github.com/asbjborg/journal-addon/issues/20), [repair costs](https://github.com/asbjborg/journal-addon/issues/21).

## Story pilot

The story-writer does not write prose. It reads NDJSON, refuses the TBC quest catalog, and prints the same events with `data.questContext.error` on quest lines. A draft is a person writing from `msg`.

Smallest real run, after the smoke checklist:

1. `/journal note` with one sentence about where you are.
2. Play long enough to accept one quest or kill one creature. One of each is enough.
3. `/journal`, select that session, click JSON, save the file.
4. From `story-writer/`, point `.env` at that file's folder layout (`REALM/CHARACTER/session-NN/session-NN.jsonl`) and run `npm run story-beat-writer`. Leave `WOWHEAD_QUEST_BASE_URL` unset.
5. Write a short draft. Every sentence is either copied from a `msg` or marked as invention. Do not promote `questContext` into the draft. On this port that object is a refusal, not quest text.

Checked-in shape, not a play session: `story-writer/workflows/story-beat-writer/examples/ExampleRealm/ExampleHero/session-01/session-01.jsonl`. Quest id `900001` is fake. Recorded lines:

- `Session started.`
- `Accepted: Speak with the miller (900001)`
- `Note: The north road past the mill is empty of carts.`
- `Killed: Road Wolf | Gained 40 XP`

A draft that keeps the split:

> Recorded: Session started. Recorded: Accepted: Speak with the miller (900001). Recorded: Note: The north road past the mill is empty of carts. Recorded: Killed: Road Wolf | Gained 40 XP.
>
> Invented: She stayed on the road because the empty carts made the mill feel watched. The wolf is not described in the journal beyond its name and the 40 XP.

The second paragraph is not data. The first paragraph is only the `msg` fields.

Upstream files under `examples/Thunderstrike/` and `docs/tests/` are the original public fixtures. The default runner no longer points at them. Do not paste a real character's journal into this repository.
