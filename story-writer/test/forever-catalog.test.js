const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const fetchWowheadQuests = require('../steps/fetch-wowhead-quests.js');
const enrichJsonl = require('../steps/enrich-jsonl.js');
const parseJsonl = require('../steps/parse-jsonl.js');
const collectQuestIds = require('../steps/collect-quest-ids.js');

const repoRoot = path.join(__dirname, '..', '..');
const examplePath = path.join(
  __dirname,
  '..',
  'workflows',
  'story-beat-writer',
  'examples',
  'ExampleRealm',
  'ExampleHero',
  'session-01',
  'session-01.jsonl'
);

test('empty and TBC catalogs are refused before any fetch', async () => {
  assert.equal(fetchWowheadQuests.catalogDecision('').fetch, false);
  assert.equal(fetchWowheadQuests.catalogDecision('   ').reason, 'missing-forever-catalog');
  const tbc = fetchWowheadQuests.catalogDecision('https://www.wowhead.com/tbc/quest=');
  assert.equal(tbc.fetch, false);
  assert.equal(tbc.reason, 'tbc-catalog-refused');

  const refused = await fetchWowheadQuests.run(
    { config: {}, questIds: [900001] },
    { baseUrl: 'https://www.wowhead.com/tbc/quest=' }
  );
  assert.equal(refused.quests.length, 1);
  assert.equal(refused.quests[0].questID, 900001);
  assert.equal(refused.quests[0].catalog, 'tbc-catalog-refused');
  assert.equal(Object.hasOwn(refused.quests[0], 'title'), false);
  assert.match(refused.quests[0].error, /TBC Wowhead/);
});

test('an explicit non-TBC URL is allowed by the decision and is not fetched here', () => {
  const decision = fetchWowheadQuests.catalogDecision('https://example.invalid/forever/quest=');
  assert.equal(decision.fetch, true);
  assert.equal(decision.reason, 'explicit-non-tbc-catalog');
});

test('example session enrichment keeps recorded text and adds a refusal', async () => {
  const content = fs.readFileSync(examplePath, 'utf8');
  const parsed = parseJsonl.run({ config: {}, content });
  const collected = collectQuestIds.run(parsed);
  assert.deepEqual(collected.questIds, ['900001']);

  const fetched = await fetchWowheadQuests.run(collected, { baseUrl: '' });
  const enriched = enrichJsonl.run(fetched);
  const quest = enriched.events.find((event) => event.type === 'quest');
  const note = enriched.events.find((event) => event.type === 'note');

  assert.equal(quest.msg, 'Accepted: Speak with the miller (900001)');
  assert.equal(quest.data.title, 'Speak with the miller');
  assert.equal(quest.data.questContext.catalog, 'missing-forever-catalog');
  assert.equal(Object.hasOwn(quest.data.questContext, 'title'), false);
  assert.equal(note.msg, 'Note: The north road past the mill is empty of carts.');
  assert.equal(Object.hasOwn(note.data, 'questContext'), false);
});

test('the workflow does not hard-code the TBC quest URL', () => {
  const indexJs = fs.readFileSync(
    path.join(__dirname, '..', 'workflows', 'story-beat-writer', 'index.js'),
    'utf8'
  );
  assert.equal(indexJs.includes('wowhead.com/tbc'), false);
});

test('Forever TOC files match and do not declare the TBC interface', () => {
  const base = fs.readFileSync(path.join(repoRoot, 'JournalingAddon', 'JournalingAddon.toc'), 'utf8');
  const camelot = fs.readFileSync(
    path.join(repoRoot, 'JournalingAddon', 'JournalingAddon_Camelot.toc'),
    'utf8'
  );
  assert.equal(base, camelot);
  assert.match(base, /## Interface: 16001/);
  assert.match(base, /## Version: 0\.6\.35/);
  assert.match(base, /core\/Forever\.lua/);
  assert.match(base, /features\/Minimap\.lua/);
  assert.equal(base.includes('20505'), false);
});

test('load path keeps journals and does not register the old party event', () => {
  const storage = fs.readFileSync(path.join(repoRoot, 'JournalingAddon', 'core', 'Storage.lua'), 'utf8');
  const initStart = storage.indexOf('function Journal:InitDB');
  const initEnd = storage.indexOf('function Journal:GetSetting');
  const init = storage.slice(initStart, initEnd);
  assert.equal(init.includes('self:ResetDatabase'), false);
  assert.match(storage, /CURRENT_SCHEMA = 3/);

  const events = fs.readFileSync(path.join(repoRoot, 'JournalingAddon', 'core', 'Events.lua'), 'utf8');
  const rules = fs.readFileSync(path.join(repoRoot, 'JournalingAddon', 'core', 'Forever.lua'), 'utf8');
  assert.match(rules, /"GROUP_ROSTER_UPDATE"/);
  assert.equal(rules.includes('"PARTY_MEMBERS_CHANGED"'), false);
  assert.match(events, /applyRegistrations/);
  assert.equal(events.includes('frame.RegisterEvent'), false);
  assert.match(rules, /COMBAT_LOG_EVENT_UNFILTERED = true/);
});
