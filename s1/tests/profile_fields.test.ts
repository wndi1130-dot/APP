import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateContent } from '../tools/validate';
import type { ContentKind } from '../tools/validate';

// 사람 프로필의 선택 필드 넷(build, char_traits, body, job). 모양과 id 목록은 character_creation.md 9장이 기준이다.
const root = fileURLToPath(new URL('../', import.meta.url));
const fixture = (kind: ContentKind) =>
  JSON.parse(readFileSync(join(root, 'fixtures', 'valid', `${kind}.json`), 'utf8'));
const errors = (value: unknown, kind: ContentKind) =>
  validateContent(value, `${kind}.json`).filter(item => item.severity === 'error');
const common = JSON.parse(readFileSync(join(root, 'schema', 'common.schema.json'), 'utf8'));
const brief = readFileSync(join(root, '..', 'docs', 'design', 'briefs', 'character_creation.md'), 'utf8');

const BODY_KEYS = ['stamina', 'melee', 'shooting', 'stealth', 'search'];
const body = (value = 5) => Object.fromEntries(BODY_KEYS.map(key => [key, value]));
const full = { build: 'stocky', char_traits: ['light_feet', 'debt'], body: body(), job: 'fireman' };

// 9장 'id 목록'의 한 줄("- 직업: `a` …")에서 백틱 id만 뽑는다.
const briefIds = (label: string) => {
  const line = brief.split('\n').find(text => text.startsWith(`- ${label}:`));
  if (!line) throw new Error(`character_creation.md에 '${label}' 줄이 없다`);
  return [...line.matchAll(/`([a-z_]+)`/g)].map(match => match[1]);
};

describe('profile body and traits (character_creation 9)', () => {
  it('keeps old profiles valid: all four fields are optional', () => {
    expect(errors(fixture('profile'), 'profile')).toEqual([]);
    for (const key of Object.keys(full)) expect(common.$defs.profileFields.required).not.toContain(key);
  });

  it.each(['profile', 'character'] as const)('accepts the four fields on %s', kind => {
    expect(errors({ ...fixture(kind), ...full }, kind)).toEqual([]);
    expect(errors({ ...fixture(kind), ...full, char_traits: [] }, kind)).toEqual([]);
  });

  it('accepts every build, trait and job id and the body edges', () => {
    const profile = fixture('profile');
    for (const build of ['thin', 'average', 'stocky']) expect(errors({ ...profile, build }, 'profile')).toEqual([]);
    for (const trait of common.$defs.charTrait.enum) expect(errors({ ...profile, char_traits: [trait] }, 'profile')).toEqual([]);
    for (const job of common.$defs.job.enum) expect(errors({ ...profile, job }, 'profile')).toEqual([]);
    expect(errors({ ...profile, body: body(0) }, 'profile')).toEqual([]);
    expect(errors({ ...profile, body: body(10) }, 'profile')).toEqual([]);
  });

  it('matches the id lists in character_creation.md', () => {
    expect(common.$defs.job.enum).toEqual(briefIds('직업'));
    const traits = [...briefIds('좋은 몸 특성'), ...briefIds('나쁜 몸 특성'), ...briefIds('정치 특성')];
    expect(common.$defs.charTrait.enum).toEqual(traits);
    expect(traits).toHaveLength(27);
    expect(common.$defs.job.enum).toHaveLength(16);
  });

  it('keeps char_traits apart from the leader trait', () => {
    const leader = ['greed', 'ideal', 'family', 'fear', 'ambition'];
    for (const id of leader) expect(common.$defs.charTrait.enum).not.toContain(id);
    const profile = fixture('profile');
    expect(errors({ ...profile, char_traits: ['greed'] }, 'profile'))
      .toContainEqual(expect.objectContaining({ path: '/char_traits/0', code: 'schema.enum' }));
    expect(errors({ ...profile, traits: ['tough'] }, 'profile').length).toBeGreaterThan(0);
  });

  it.each([
    ['unknown build', { build: 'fat' }, '/build'],
    ['four traits', { char_traits: ['tough', 'steady', 'debt', 'habit'] }, '/char_traits'],
    ['repeated trait', { char_traits: ['tough', 'tough'] }, '/char_traits'],
    ['unknown trait', { char_traits: ['lucky'] }, '/char_traits/0'],
    ['trait as string', { char_traits: 'tough' }, '/char_traits'],
    ['body over 10', { body: { ...body(), melee: 11 } }, '/body/melee'],
    ['body below 0', { body: { ...body(), stealth: -1 } }, '/body/stealth'],
    ['body fraction', { body: { ...body(), search: 2.5 } }, '/body/search'],
    ['body missing key', { body: Object.fromEntries(BODY_KEYS.slice(1).map(key => [key, 3])) }, '/body'],
    ['body extra key', { body: { ...body(), luck: 3 } }, '/body'],
    ['unknown job', { job: 'soldier' }, '/job'],
  ])('rejects %s', (_name, patch, path) => {
    const issues = errors({ ...fixture('profile'), ...patch }, 'profile');
    expect(issues.some(item => item.path.startsWith(path) && item.code.startsWith('schema.'))).toBe(true);
  });
});
