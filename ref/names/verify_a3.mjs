/** Verify the existing A3 consumer in memory without writing into s1/. */
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const target = join(root, '.cache', 'a3_gen_profiles.ts');
const raw = readFileSync(target);
const blob = createHash('sha1').update(`blob ${raw.length}\0`).update(raw).digest('hex');
assert.equal(blob, '9b935fc2859632b0d24295bce34c31207efc364b', '검토한 A3 blob과 다릅니다.');

const { loadReferences, generateProfiles, serializeGenerated } = await import(pathToFileURL(target).href);
const references = loadReferences(resolve(root, '..'));
for (const language of ['pl', 'de', 'cz']) {
  assert.ok(references.names[language].given.length >= 150);
  assert.ok(references.names[language].surnames.length >= 200);
}
assert.ok(references.names.other.given.length >= 120);
assert.ok(references.names.other.surnames.length >= 150);
assert.ok(!references.warnings.some((warning) => warning.includes('names/')),
  '이름 파일 대신 임시 목록이 사용되었습니다.');

const blocklist = JSON.parse(readFileSync(join(root, 'famous_blocklist.json'), 'utf8'));
const normalize = (text) => text.normalize('NFKD').replace(/\p{M}/gu, '').trim().replace(/\s+/g, ' ').toLowerCase();
for (const person of blocklist.names) {
  assert.ok(references.blocked.has(normalize(person.original)), '원어 차단 항목 누락');
  assert.ok(references.blocked.has(normalize(person.korean)), '한글 차단 항목 누락');
}

const other = JSON.parse(readFileSync(join(root, 'other.json'), 'utf8'));
const sameLanguage = new Set();
const allOther = new Set();
for (const first of other.given_names) {
  for (const last of other.surnames) {
    const part = last.male ? last[first.gender] : last;
    const combination = `${first.original} ${part.original}`;
    allOther.add(combination);
    if (first.language === last.language) sameLanguage.add(combination);
  }
}

const seeds = ['b1-reference-check', 'b1-determinism-check', 'b1-family-check'];
let mixedOtherCount = 0;
for (const seed of seeds) {
  const generated = generateProfiles(seed, references);
  const repeated = generateProfiles(seed, references);
  assert.deepEqual(serializeGenerated(generated), serializeGenerated(repeated), '같은 시드가 재현되지 않습니다.');
  assert.equal(generated.profiles.length, 200);
  for (const person of generated.profiles) {
    assert.equal(person.line, '');
    assert.match(person.name, /[가-힣]/);
    assert.ok(!references.blocked.has(normalize(person.name)));
    assert.ok(!references.blocked.has(normalize(person.name_original)));
    if (allOther.has(person.name_original) && !sameLanguage.has(person.name_original)) mixedOtherCount += 1;
  }
}

console.log(JSON.stringify({
  contract_status: '[PASS]',
  a3_blob_sha: blob,
  source_sha256: createHash('sha256').update(raw).digest('hex'),
  seeds,
  profile_count: seeds.length * 200,
  reproducible: true,
  name_fallbacks: 0,
  checked_blocklist_rows: blocklist.names.length,
  generated_blocklist_matches: 0,
  other_language_status: mixedOtherCount ? '[WATCH]' : '[PASS]',
  mixed_other_language_names: mixedOtherCount,
  remaining_warnings: references.warnings,
  note_ko: '출력 JSON은 메모리에서만 생성했다. s1/ 파일을 만들거나 수정하지 않았다. other의 언어 메타데이터를 현재 A3가 사용하지 않는 한계는 별도 집계했다.',
}, null, 2));
