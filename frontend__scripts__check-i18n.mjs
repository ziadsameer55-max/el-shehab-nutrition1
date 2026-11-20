// Fails if Arabic and English message files differ in keys, or any value is empty.
// Run: npm run check:i18n
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const dir = join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'messages');
const load = (l) => JSON.parse(readFileSync(join(dir, `${l}.json`), 'utf8'));

function flatten(obj, prefix = '') {
  return Object.entries(obj).flatMap(([k, v]) =>
    typeof v === 'object' && v !== null ? flatten(v, `${prefix}${k}.`) : [[`${prefix}${k}`, v]],
  );
}

const ar = new Map(flatten(load('ar')));
const en = new Map(flatten(load('en')));
const problems = [];

for (const k of ar.keys()) if (!en.has(k)) problems.push(`missing in en: ${k}`);
for (const k of en.keys()) if (!ar.has(k)) problems.push(`missing in ar: ${k}`);
for (const [name, map] of [['ar', ar], ['en', en]])
  for (const [k, v] of map) if (typeof v !== 'string' || v.trim() === '') problems.push(`empty value in ${name}: ${k}`);

// placeholders such as {name} must match between languages
const ph = (s) => (String(s).match(/\{\w+\}/g) || []).sort().join(',');
for (const [k, v] of ar) if (en.has(k) && ph(v) !== ph(en.get(k))) problems.push(`placeholder mismatch: ${k}`);

if (problems.length) {
  console.error(problems.join('\n'));
  process.exit(1);
}
console.log(`i18n OK: ${ar.size} keys in both languages`);
