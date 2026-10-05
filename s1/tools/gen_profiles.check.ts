import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, rmdirSync, unlinkSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';
import {
  COMMUNITIES, DEFAULT_BOARDING, DEFAULT_SEED, POPULATION, S1_ROOT,
  generateProfiles, loadReferences, serializeGenerated,
} from './gen_profiles.ts';
import type { Generated } from './gen_profiles.ts';

const scratchRoot = join(S1_ROOT, '.local');
mkdirSync(scratchRoot, { recursive: true });
function scratch(): string { return mkdtempSync(join(scratchRoot, 'profiles-check-')); }
function writeJson(root: string, file: string, value: unknown): void {
  const path = join(root, file);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}
// Only remove known files inside this run's newly created scratch directory.
function cleanScratch(root: string): void {
  assert.equal(dirname(root), scratchRoot);
  const directories: string[] = [];
  function visit(path: string): void {
    for (const entry of readdirSync(path, { withFileTypes: true })) {
      const child = join(path, entry.name);
      assert(!entry.isSymbolicLink());
      if (entry.isDirectory()) visit(child);
      else unlinkSync(child);
    }
    directories.push(path);
  }
  visit(root);
  for (const path of directories) rmdirSync(path);
}
const emptyRefRoot = scratch();
const temporaryReferences = loadReferences(emptyRefRoot);
cleanScratch(emptyRefRoot);

function checkPopulation(data: Generated): void {
  const { profiles, familyData } = data;
  assert.equal(profiles.length, 200);
  const byId = new Map(profiles.map((person) => [person.id, person]));
  assert.equal(byId.size, 200);
  const fields = ['id', 'name', 'name_original', 'age', 'community', 'origin_tag', 'boarding', 'hometown', 'like', 'dislike', 'line', 'state'].sort();
  for (const [index, person] of profiles.entries()) {
    assert.deepEqual(Object.keys(person).sort(), fields);
    assert.equal(person.id, `p_${String(index + 1).padStart(3, '0')}`);
    assert.match(person.id, /^[a-z][a-z_0-9]*$/);
    assert(Number.isInteger(person.age) && person.age >= 0 && person.age <= 85);
    assert(COMMUNITIES.includes(person.community));
    assert(['original', 'rescued'].includes(person.origin_tag));
    assert(['depot', 'bought', 'force', 'rescue', 'refugee', 'born'].includes(person.boarding));
    for (const text of [person.name, person.hometown, person.like, person.dislike]) assert.match(text, /[가-힣]/u);
    assert(person.name_original.trim());
    assert.equal(person.line, '');
    assert.equal(person.state, 'alive');
    assert([...person.like].length <= 15 && [...person.dislike].length <= 15);
    assert.notEqual(person.like, person.dislike);
    assert.equal(person.age <= 5, person.boarding === 'born');
    if (person.boarding === 'born') assert.equal(person.hometown, '열차, 출생 정차역 미상');
    else assert.equal(person.origin_tag, ['rescue', 'refugee'].includes(person.boarding) ? 'rescued' : 'original');
    if (person.boarding === 'force' || person.boarding === 'depot') assert(person.age >= 22);
  }
  assert.equal(profiles.filter((person) => person.age <= 15).length, 30);
  assert.equal(profiles.filter((person) => person.age >= 65).length, 20);
  assert.equal(profiles.filter((person) => person.boarding === 'born').length, 8);
  assert(profiles.some((person) => person.age === 0));
  assert(profiles.some((person) => person.age === 5));
  for (const community of COMMUNITIES) {
    const members = profiles.filter((person) => person.community === community);
    assert.equal(members.length, POPULATION[community]);
    assert.equal(members.filter((person) => person.boarding !== DEFAULT_BOARDING[community]).length, members.length / 5);
  }
  const engine = profiles.filter((person) => person.community === 'engine');
  const others = profiles.filter((person) => person.community !== 'engine');
  const mean = (members: typeof profiles) => members.reduce((sum, person) => sum + person.age, 0) / members.length;
  assert(mean(engine) > mean(others) + 10);
  assert(engine.filter((person) => person.age >= 65).length / engine.length > 0.25);
  const oldWorld = profiles.filter((person) => person.boarding !== 'born');
  const central = (hometown: string) => /, (폴란드|독일|체코)$/u.test(hometown);
  assert(oldWorld.filter((person) => central(person.hometown)).length / oldWorld.length >= 0.7);
  const refugees = oldWorld.filter((person) => person.boarding === 'refugee');
  const notRefugees = oldWorld.filter((person) => person.boarding !== 'refugee');
  const wide = (members: typeof profiles) => members.filter((person) => !central(person.hometown)).length / members.length;
  assert(wide(refugees) > wide(notRefugees));
  assert(new Set(refugees.map((person) => person.hometown.split(', ')[1])).size >= 5);

  assert.equal(familyData.families.length, 16);
  assert.equal(new Set(familyData.families.map((family) => family.id)).size, 16);
  const assigned = new Set<string>();
  let siblingFamilies = 0;
  for (const family of familyData.families) {
    assert.match(family.id, /^f_\d{3}$/);
    assert.equal(family.parents.length, 2);
    assert(family.children.length === 1 || family.children.length === 2);
    if (family.children.length === 2) siblingFamilies++;
    const ids = [...family.parents, ...family.children];
    assert.equal(new Set(ids).size, ids.length);
    for (const id of ids) {
      const person = byId.get(id);
      assert(person, `존재하지 않는 가족 구성원: ${id}`);
      assert.equal(person.community, family.community);
      assert(!assigned.has(id), `여러 가족에 중복된 구성원: ${id}`);
      assigned.add(id);
    }
    for (const parentId of family.parents) {
      for (const childId of family.children) {
        const parent = byId.get(parentId)!;
        const child = byId.get(childId)!;
        assert(child.age <= 15);
        assert(parent.age - child.age >= 18 && parent.age - child.age <= 50);
        if (child.boarding !== 'born') assert.equal(child.hometown, parent.hometown);
      }
    }
    for (const childId of family.children) {
      const child = byId.get(childId)!;
      if (child.boarding === 'born') {
        const anchor = family.parents.map((id) => byId.get(id)!).find((person) => person.boarding === 'refugee') ?? byId.get(family.parents[0])!;
        assert.equal(child.origin_tag, anchor.origin_tag);
      }
    }
  }
  assert.equal(siblingFamilies, 14);
  assert.equal(assigned.size, 62);
  for (const child of profiles.filter((person) => person.age <= 15)) assert(assigned.has(child.id));
}

test('기본 데이터와 100개 시드의 인원·나이·경위·고향·가족 분포', () => {
  for (const seed of [DEFAULT_SEED, ...Array.from({ length: 100 }, (_, index) => `distribution-${index}`)]) {
    checkPopulation(generateProfiles(seed, temporaryReferences));
  }
});
test('같은 시드와 입력은 JSON 바이트까지 같고 다른 시드는 인물을 바꾼다', () => {
  const first = serializeGenerated(generateProfiles('한글 시드 0', temporaryReferences));
  assert.deepEqual(first, serializeGenerated(generateProfiles('한글 시드 0', temporaryReferences)));
  assert.notEqual(first.profiles, serializeGenerated(generateProfiles('한글 시드 1', temporaryReferences)).profiles);
  assert.deepEqual(serializeGenerated(generateProfiles(0, temporaryReferences)), serializeGenerated(generateProfiles('0', temporaryReferences)));
  assert.throws(() => generateProfiles('', temporaryReferences), /시드/u);
  assert.throws(() => generateProfiles(NaN, temporaryReferences), /시드/u);
});
test('체크인한 두 JSON은 기본 시드와 현재 레퍼런스로 재현된다', () => {
  const data = generateProfiles();
  const serialized = serializeGenerated(data);
  assert.equal(readFileSync(join(S1_ROOT, 'data/profiles.json'), 'utf8'), serialized.profiles);
  assert.equal(readFileSync(join(S1_ROOT, 'generated/profile_families.json'), 'utf8'), serialized.families);
  checkPopulation(data);
});

function referenceFixture(root: string): void {
  const given = Array.from({ length: 6 }, (_, index) => ({ original: `Safe${index}`, korean: `안전${index}` }));
  const surname = { original: 'Fictional', korean: '가상성' };
  for (const country of ['pl', 'de', 'cz', 'other']) writeJson(root, `names/${country}.json`, { given_names: given, surnames: [surname] });
  writeJson(root, 'names/famous_blocklist.json', ['safe0 fictional', { original: 'Safe1 Fictional', korean: '안전1 가상성' }]);
  writeJson(root, 'likes_dislikes.json', {
    likes: [{ text: '시험용 선호', seasons: ['winter'] }, { text: '금지된 해빙 선호', seasons: ['thaw'] }],
    dislikes: [{ text: '시험용 기피', seasons: ['winter'] }, { text: '금지된 해빙 기피', seasons: ['thaw'] }],
  });
}
test('B1·B6 읽기, 양쪽 표기 제외, 선호 태그, 원본 SHA-256 기록', () => {
  const root = scratch();
  try {
    referenceFixture(root);
    const refs = loadReferences(root);
    const data = generateProfiles('reference-fixture', refs);
    checkPopulation(data);
    assert.equal(data.familyData.warnings.length, 0);
    assert.equal(data.familyData.preference_fallbacks, 0);
    for (const person of data.profiles) {
      assert.match(person.name_original, /^Safe[2-5] Fictional$/);
      assert.equal(person.like, '시험용 선호');
      assert.equal(person.dislike, '시험용 기피');
    }
    const bytes = readFileSync(join(root, 'names/pl.json'));
    assert.equal(refs.sources.find((source) => source.path === 'ref/names/pl.json')!.sha256, createHash('sha256').update(bytes).digest('hex'));
    assert.deepEqual(serializeGenerated(data), serializeGenerated(generateProfiles('reference-fixture', loadReferences(root))));
    const tagged = { text: '꼬리칸 아이 선호', age_groups: ['child'], communities: ['tail'], seasons: ['winter'] };
    writeJson(root, 'likes_dislikes.json', { likes: [tagged], dislikes: ['태그 없는 기피'] });
    const filtered = generateProfiles('reference-fixture', loadReferences(root));
    assert.equal(filtered.familyData.preference_fallbacks, 182);
    for (const person of filtered.profiles) assert.equal(person.like === tagged.text, person.community === 'tail' && person.age <= 15);
  } finally { cleanScratch(root); }
});
test('이름 성별 형태와 부분 B1 목록, 태그 미매칭 시 임시 선호', () => {
  const root = scratch();
  try {
    const male = Array.from({ length: 4 }, (_, index) => ({ original: `Boy${index}`, korean: `남자${index}` }));
    const female = Array.from({ length: 4 }, (_, index) => ({ original: `Girl${index}`, korean: `여자${index}` }));
    writeJson(root, 'names/pl.json', { first_names: { male, female }, surnames: [{ male: { original: 'Root', korean: '남성형성' }, female: { original: 'Roota', korean: '여성형성' } }] });
    const data = generateProfiles('gender-fixture', loadReferences(root));
    const named = data.profiles.filter((person) => /^(Boy|Girl)/u.test(person.name_original));
    assert(named.length > 0);
    for (const person of named) assert.match(person.name_original, person.name_original.startsWith('Boy') ? / Root$/ : / Roota$/);
    assert(data.familyData.sources.some((source) => source.path === 'temporary:names/de'));
    assert.equal(data.familyData.preference_fallbacks, 400);
  } finally { cleanScratch(root); }
});
test('실제 B6 entries 형식, 다섯 나이대·고향 나라·한파 태그를 적용한다', () => {
  const root = scratch();
  try {
    const groups = ['child', 'young', 'adult', 'middle', 'elder'];
    const entries = groups.map((group, index) => ({
      text: `나이 선호${index}`, preference_options: ['like'],
      tags: { age_groups: [group], communities: [...COMMUNITIES], seasons: ['한파'] },
    }));
    entries.push({ text: '일반 기피', preference_options: ['dislike'], tags: { age_groups: [], communities: [], seasons: ['한파', '해빙기'] } });
    writeJson(root, 'likes_dislikes.json', { entries });
    const generated = generateProfiles('b6-entries', loadReferences(root));
    assert.equal(generated.familyData.preference_fallbacks, 0);
    for (const person of generated.profiles) {
      const group = person.age <= 15 ? 0 : person.age <= 29 ? 1 : person.age <= 49 ? 2 : person.age <= 64 ? 3 : 4;
      assert.equal(person.like, `나이 선호${group}`);
      assert.equal(person.dislike, '일반 기피');
    }
    writeJson(root, 'likes_dislikes.json', { entries: [
      { text: '폴란드 선호', preference_options: ['like'], tags: { home_countries: ['폴란드'], seasons: ['한파'] } },
      { text: '일반 기피', preference_options: ['dislike'], tags: {} },
    ] });
    const countryFiltered = generateProfiles('b6-entries', loadReferences(root));
    const people = new Map(countryFiltered.profiles.map((person) => [person.id, person]));
    for (const person of countryFiltered.profiles) {
      let hometown = person.hometown;
      if (person.boarding === 'born') {
        const family = countryFiltered.familyData.families.find((family) => family.children.includes(person.id))!;
        hometown = people.get(family.parents[0])!.hometown;
      }
      assert.equal(person.like === '폴란드 선호', hometown.endsWith(', 폴란드'));
    }
  } finally { cleanScratch(root); }
});
test('손상된 레퍼런스·잘못된 태그·막힌 이름을 조용히 대체하지 않는다', () => {
  const root = scratch();
  try {
    mkdirSync(join(root, 'names'));
    writeFileSync(join(root, 'names/pl.json'), '{', 'utf8');
    assert.throws(() => loadReferences(root), /names\/pl.json: JSON/u);
    writeJson(root, 'names/pl.json', { given_names: [], surnames: [] });
    assert.throws(() => loadReferences(root), /비어/u);
    referenceFixture(root);
    writeJson(root, 'likes_dislikes.json', { likes: [{ text: '태그 오류', communities: ['unknown'] }], dislikes: ['기피'] });
    assert.throws(() => loadReferences(root), /태그/u);
    writeJson(root, 'likes_dislikes.json', { likes: ['가'.repeat(16)], dislikes: ['기피'] });
    assert.throws(() => loadReferences(root), /15자/u);
    referenceFixture(root);
    writeJson(root, 'names/famous_blocklist.json', Array.from({ length: 6 }, (_, index) => `Safe${index} Fictional`));
    assert.throws(() => generateProfiles('blocked-fixture', loadReferences(root)), /이름과 성이 부족/u);
  } finally { cleanScratch(root); }
});
test('CLI 재현 검사와 경로·시드 오류 처리', () => {
  const root = scratch();
  const tool = join(S1_ROOT, 'tools/gen_profiles.ts');
  const run = (args: string[], cwd = resolve(S1_ROOT, '..')) => spawnSync(process.execPath, [tool, ...args], { cwd, encoding: 'utf8' });
  try {
    const out = join(root, 'output');
    const args = ['--seed', 'cli-fixture', '--ref-dir', root, '--output-dir', out];
    const generated = run(args);
    assert.equal(generated.status, 0, generated.stderr);
    const before = readFileSync(join(out, 'data/profiles.json'), 'utf8');
    const checked = run([...args, '--check'], root);
    assert.equal(checked.status, 0, checked.stderr);
    assert.equal(readFileSync(join(out, 'data/profiles.json'), 'utf8'), before);
    assert.equal(run([...args, '--seed', 'changed', '--check']).status, 1);
    assert.equal(run(['--seed']).status, 1);
    assert.equal(run(['--output-dir', resolve(S1_ROOT, '../docs')]).status, 1);
    assert.equal(run(['--output-dir', `${S1_ROOT}-outside`]).status, 1);
    assert.equal(run(['--unknown']).status, 1);
    assert.equal(run(['--help']).status, 0);
    writeJson(out, 'data/profiles.json', []);
    assert.equal(run([...args, '--check']).status, 1);
    assert(!relative(S1_ROOT, out).startsWith('..'));
  } finally { cleanScratch(root); }
});
