import { afterEach, describe, expect, it } from 'vitest';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { contentKinds, countSentences, validateContent, validateFolder } from '../tools/validate';
import type { ContentKind } from '../tools/validate';

const root = fileURLToPath(new URL('../', import.meta.url));
const scratchRoot = resolve(root, '.local');
const temporaryFolders: string[] = [];
const fixture = (kind: ContentKind, category = 'valid') =>
  JSON.parse(readFileSync(join(root, 'fixtures', category, `${kind}.json`), 'utf8'));
const errors = (value: unknown, kind: ContentKind) =>
  validateContent(value, `${kind}.json`).filter(item => item.severity === 'error');
const temporaryFolder = () => {
  mkdirSync(scratchRoot, { recursive: true });
  const folder = mkdtempSync(join(scratchRoot, 'validator-'));
  temporaryFolders.push(folder);
  return folder;
};
// Exercise the CLI entry point without requiring the tsx wrapper's IPC socket.
const cli = (...args: string[]) => spawnSync(process.execPath,
  ['--import', 'tsx', join(root, 'tools/validate.ts'), ...args],
  { cwd: root, encoding: 'utf8', timeout: 30_000 });

afterEach(() => {
  for (const folder of temporaryFolders.splice(0)) {
    if (dirname(folder) !== scratchRoot) throw new Error('임시 폴더의 경계가 맞지 않습니다.');
    rmSync(folder, { recursive: true });
  }
});

describe('fixture contract', () => {
  it.each(contentKinds)('%s has a passing and a diagnosed failing example', kind => {
    expect(errors(fixture(kind), kind)).toEqual([]);
    const issues = errors(fixture(kind, 'invalid'), kind);
    expect(issues.length).toBeGreaterThan(0);
    expect(issues.every(item => item.file === `${kind}.json` && item.path.startsWith('/') && /[가-힣]/u.test(item.message))).toBe(true);
    expect(issues.some(item => item.code.startsWith('schema.'))).toBe(true);
  });
  it('accepts all eight valid files and rejects all eight invalid files', async () => {
    const valid = await validateFolder(join(root, 'fixtures/valid'));
    expect(valid).toMatchObject({ valid: true, files: 8, records: 8, diagnostics: [] });
    const invalid = await validateFolder(join(root, 'fixtures/invalid'));
    expect(invalid.valid).toBe(false);
    expect(new Set(invalid.diagnostics.filter(item => item.severity === 'error').map(item => item.file)).size).toBe(8);
  });
  it('uses draft 2020-12 on every schema', () => {
    for (const kind of ['common', 'effects', ...contentKinds]) {
      const schema = JSON.parse(readFileSync(join(root, 'schema', `${kind}.schema.json`), 'utf8'));
      expect(schema.$schema).toBe('https://json-schema.org/draft/2020-12/schema');
    }
  });
});

describe('length and count boundaries', () => {
  it('counts Unicode code points for profile, body and labels', () => {
    const profile = fixture('profile');
    profile.line = '😀'.repeat(40);
    expect(errors(profile, 'profile')).toEqual([]);
    profile.line += '😀';
    expect(errors(profile, 'profile')).toContainEqual(expect.objectContaining({ path: '/line', code: 'schema.maxLength' }));
    const event = fixture('event');
    event.body = '가'.repeat(120);
    event.choices[0].label = '😀'.repeat(15);
    expect(errors(event, 'event')).toEqual([]);
    event.body += '가';
    event.choices[0].label += '😀';
    expect(errors(event, 'event').map(item => item.path)).toEqual(expect.arrayContaining(['/body', '/choices/0/label']));
  });
  it.each([['character', 'bio', 3], ['secret', 'text', 2], ['event', 'body', 3]] as const)(
    '%s limits %s to %i sentences', (kind, key, max) => {
      const data = fixture(kind);
      data[key] = '문이 닫혔다. '.repeat(max).trim();
      expect(errors(data, kind)).toEqual([]);
      data[key] += ' 불이 꺼졌다';
      expect(errors(data, kind)).toContainEqual(expect.objectContaining({ path: `/${key}`, code: 'length.sentences' }));
    },
  );
  it('limits witness testimony and counts unpunctuated lines', () => {
    const chronicle = fixture('chronicle');
    chronicle.witnesses[0].text = '문이 닫혔다\n불이 꺼졌다';
    expect(errors(chronicle, 'chronicle')).toEqual([]);
    chronicle.witnesses[0].text += '\n발소리가 났다';
    expect(errors(chronicle, 'chronicle')).toContainEqual(expect.objectContaining({ path: '/witnesses/0/text', code: 'length.sentences' }));
    expect(countSentences('압력 12.5다. “문을 닫아!”')).toBe(2);
  });
  it.each([1, 2, 4, 5])('accepts only two to four event choices (%i)', count => {
    const event = fixture('event');
    event.choices = Array.from({ length: count }, () => event.choices[0]);
    expect(errors(event, 'event').length === 0).toBe(count >= 2 && count <= 4);
  });
  it.each([0, 2, 3])('allows zero to two secrets (%i)', count => {
    const character = fixture('character');
    character.secrets = Array.from({ length: count }, (_, index) => `s_${index}`);
    expect(errors(character, 'character').length === 0).toBe(count <= 2);
  });
  it.each([0, 1, 3, 4])('allows one to three relations (%i)', count => {
    const character = fixture('character');
    character.relations = Array.from({ length: count }, (_, index) => ({ target: `p_${index}`, kind: 'friend' }));
    expect(errors(character, 'character').length === 0).toBe(count >= 1 && count <= 3);
  });
  it.each([1, 2, 3])('requires exactly two weights (%i)', count => {
    const character = fixture('character');
    character.weights = Array(count).fill(0.5);
    expect(errors(character, 'character').length === 0).toBe(count === 2);
  });
  it.each([-1, 0, 85, 86, 2.5])('validates integer age boundaries (%i)', age => {
    const profile = fixture('profile');
    profile.age = age;
    expect(errors(profile, 'profile').length === 0).toBe(Number.isInteger(age) && age >= 0 && age <= 85);
  });
  it('permits an empty draft line and rejects multiline lines', () => {
    const profile = fixture('profile');
    profile.line = '';
    expect(errors(profile, 'profile')).toEqual([]);
    profile.line = '첫 줄\n둘째 줄';
    expect(errors(profile, 'profile')).toContainEqual(expect.objectContaining({ path: '/line', code: 'schema.pattern' }));
  });
});

describe('effect and condition contracts', () => {
  it('accepts the complete vocabulary without implementing any effects', () => {
    const law = fixture('law');
    law.effects = [
      ...['coal', 'food', 'medicine', 'luxury', 'trust', 'tension', 'fear'].map(type => ({ type, amount: 1 })),
      ...['symbol', 'secret'].map(type => ({ type, id: 'item_one', amount: 1 })),
      ...['warmth', 'ration', 'crowding', 'exposure'].map(metric => ({ type: `community.${metric}`, target: 'tail', amount: 1 })),
      ...['relation', 'cohesion', 'votes'].map(type => ({ type, target: 'tail', amount: 1 })),
      { type: 'person.state', target: 'p_001', state: 'injured' },
      { type: 'person.away', target: 'p_001', segments: 2 },
      { type: 'flag', id: 'heat_requested', value: true },
      { type: 'followup', id: 'ev_reply', delay: 1 },
      { type: 'deal', id: 'deal_heat' }, { type: 'chronicle', id: 'ch_heat' },
    ];
    expect(errors(law, 'law')).toEqual([]);
  });
  it('rejects unknown effects and diagnoses wrong arguments in two different branches', () => {
    const law = fixture('law');
    law.effects = [{ type: 'unknown' }];
    expect(errors(law, 'law')).toContainEqual(expect.objectContaining({ path: '/effects/0/type', code: 'schema.enum' }));
    law.effects = [{ type: 'coal', amount: '많이' }, { type: 'person.state', target: 'p_001', state: 'sleeping' }];
    expect(errors(law, 'law').map(item => item.path)).toEqual(expect.arrayContaining(['/effects/0/amount', '/effects/1/state']));
  });
  it('rejects reversed segment ranges and unknown conditions', () => {
    const event = fixture('event');
    event.trigger = [{ type: 'segment', min: 3, max: 1 }];
    expect(errors(event, 'event')).toContainEqual(expect.objectContaining({ code: 'condition.range', path: '/trigger/0/max' }));
    event.trigger = [{ type: 'unknown' }];
    expect(errors(event, 'event')).toContainEqual(expect.objectContaining({ path: '/trigger/0/type', code: 'schema.enum' }));
  });
});

describe('content rules', () => {
  it('blocks manufacturer and model spellings, including case and normalized widths', () => {
    const profile = fixture('profile');
    for (const term of ['Gl' + 'ock', 'ＡＫ－４７', 'a' + 'k 74', '글' + '록']) {
      profile.like = term;
      expect(errors(profile, 'profile')).toContainEqual(expect.objectContaining({ path: '/like', code: 'rule.real_firearms' }));
    }
    profile.like = 'Glockenspiel 소리';
    expect(errors(profile, 'profile')).toEqual([]);
  });
  it.each(['수용소로 보내자.', '강제   이송을 명령했다.', '사람들을 화물칸에 실었다.', '줄 세워 사람을 갈라냈다.'])(
    'blocks forbidden transport language (%s)', body => {
      const event = fixture('event');
      event.body = body;
      expect(errors(event, 'event')).toContainEqual(expect.objectContaining({ path: '/body', code: 'rule.forced_transport' }));
    },
  );
  it('blocks zombie in dialogue and quoted speech, while permitting narrative references', () => {
    const event = fixture('event');
    event.body = '좀비가 온다.';
    expect(errors(event, 'event')).toContainEqual(expect.objectContaining({ code: 'rule.dialogue_zombie' }));
    const profile = fixture('profile');
    profile.line = '좀비라는 낱말을 모르는 사람이다.';
    expect(errors(profile, 'profile')).toEqual([]);
    profile.line = '그가 말했다. “좀비가 온다.”';
    expect(errors(profile, 'profile')).toContainEqual(expect.objectContaining({ code: 'rule.dialogue_zombie' }));
    const chronicle = fixture('chronicle');
    chronicle.witnesses[0].text = '좀비를 봤어요.';
    expect(errors(chronicle, 'chronicle')).toContainEqual(expect.objectContaining({ path: '/witnesses/0/text', code: 'rule.dialogue_zombie' }));
  });
  it('warns on labels without blocking family or hidden trait values', async () => {
    const character = fixture('character');
    character.bio = '겁쟁이는 가족을 챙겼다.';
    const diagnostics = validateContent(character, 'character.json');
    expect(diagnostics.filter(item => item.severity === 'error')).toEqual([]);
    expect(diagnostics).toContainEqual(expect.objectContaining({ code: 'rule.trait_label', severity: 'warning' }));
    const folder = temporaryFolder();
    writeFileSync(join(folder, 'character.json'), JSON.stringify(character));
    expect((await validateFolder(folder)).valid).toBe(true);
    const processResult = cli(folder);
    expect(processResult.status).toBe(0);
    expect(processResult.stdout).toContain('경고');
  });
});

describe('input and CLI', () => {
  it('reads nested uppercase JSON, BOM, arrays and optional content_type', async () => {
    const folder = temporaryFolder();
    mkdirSync(join(folder, '하위 폴더'));
    const character = fixture('character');
    character.content_type = 'character';
    const profile = fixture('profile');
    profile.age = 99;
    writeFileSync(join(folder, '하위 폴더', 'mixed.JSON'), '\uFEFF' + JSON.stringify([character, profile]));
    const result = await validateFolder(folder);
    expect(result).toMatchObject({ valid: false, files: 1, records: 2 });
    expect(result.diagnostics).toContainEqual(expect.objectContaining({ path: '/1/age', code: 'schema.maximum' }));
  });
  it('reports malformed JSON, primitive items, empty arrays and unreadable folders', async () => {
    const folder = temporaryFolder();
    expect((await validateFolder(folder)).diagnostics[0].code).toBe('input.empty');
    writeFileSync(join(folder, 'broken.json'), '{');
    writeFileSync(join(folder, 'empty.json'), '[]');
    writeFileSync(join(folder, 'primitive.json'), '[null, 7]');
    const result = await validateFolder(folder);
    expect(result.diagnostics.map(item => item.code)).toEqual(expect.arrayContaining(['input.json', 'input.empty', 'content.object']));
    expect((await validateFolder(join(folder, 'missing'))).valid).toBe(false);
    expect((await validateFolder(join(folder, 'broken.json'))).valid).toBe(false);
  });
  it('rejects extra keys, unknown kinds, malformed identifiers and missing fields', () => {
    const profile = fixture('profile');
    profile.id = 'Bad-ID';
    profile.extra = '추가 항목';
    delete profile.age;
    const issues = errors(profile, 'profile');
    expect(issues.map(item => item.path)).toEqual(expect.arrayContaining(['/id', '/extra', '/age']));
    profile.content_type = 'unknown';
    expect(errors(profile, 'profile')[0]).toMatchObject({ path: '/content_type', code: 'content.kind' });
    expect(validateContent({}, 'unknown.json')[0].code).toBe('content.kind');
  });
  it('uses CLI exit codes and prints the exact file and failing field', () => {
    const valid = cli(join(root, 'fixtures/valid'));
    expect(valid.error).toBeUndefined();
    expect(valid.status).toBe(0);
    expect(valid.stdout).toContain('오류 0개');
    const invalid = cli(join(root, 'fixtures/invalid'));
    expect(invalid.error).toBeUndefined();
    expect(invalid.status).toBe(1);
    expect(invalid.stdout).toContain('profile.json:/age');
    expect(invalid.stdout).toContain('문장은 2개 이하여야 합니다.');
    expect(cli().status).toBe(2);
    expect(cli('--help').status).toBe(0);
  });
});
