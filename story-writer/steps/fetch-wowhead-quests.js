const https = require('https');
const { parseQuestHtml } = require('./parse-wowhead-html.js');

const TBC_MARKER = '/tbc/';

/**
 * Decide whether a Wowhead base URL is safe to fetch for Forever quest ids.
 * The old default, https://www.wowhead.com/tbc/quest=, is refused. An empty
 * URL is refused. There is no Forever catalog in this repo.
 */
function catalogDecision(baseUrl) {
  if (typeof baseUrl !== 'string' || baseUrl.trim() === '') {
    return {
      fetch: false,
      reason: 'missing-forever-catalog',
      error: 'skipped: no Forever quest catalog configured; refusing to guess',
    };
  }
  if (baseUrl.toLowerCase().includes(TBC_MARKER)) {
    return {
      fetch: false,
      reason: 'tbc-catalog-refused',
      error: 'skipped: TBC Wowhead catalog is not valid for Forever quest ids',
    };
  }
  return {
    fetch: true,
    reason: 'explicit-non-tbc-catalog',
  };
}

/**
 * For each quest ID, either refuse the catalog or GET the explicit base URL.
 * Input: { config, questIds }
 * Params: { baseUrl } — required, and must not be a /tbc/ Wowhead URL.
 * Output: { config, quests }
 */
async function run(input, params = {}) {
  const { config, events, questIds } = input;
  const decision = catalogDecision(params.baseUrl);
  if (!Array.isArray(questIds)) throw new Error('fetch-wowhead-quests: missing questIds array');

  if (!decision.fetch) {
    const quests = questIds.map((qid) => ({
      questID: qid,
      error: decision.error,
      catalog: decision.reason,
    }));
    return { config, events, quests };
  }

  const quests = [];
  for (const qid of questIds) {
    const url = `${params.baseUrl}${qid}`;
    const html = await fetchUrl(url);
    const parsed = parseQuestHtml(html);
    if (parsed.error) {
      quests.push({ questID: qid, error: parsed.error, catalog: decision.reason });
    } else {
      quests.push({ ...parsed, catalog: decision.reason });
    }
  }
  return { config, events, quests };
}

function fetchUrl(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, (res) => {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
      })
      .on('error', reject);
  });
}

module.exports = { run, catalogDecision };
