import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const S1_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const DEFAULT_SEED = 's1-winter-six';
export const COMMUNITIES = ['tail', 'front', 'medtech', 'guard', 'engine'] as const;
export type Community = typeof COMMUNITIES[number];
export type Boarding = 'depot' | 'bought' | 'force' | 'rescue' | 'refugee' | 'born';
type Country = 'pl' | 'de' | 'cz' | 'other';
type AgeGroup = 'child' | 'young' | 'adult' | 'middle' | 'elder';
type Gender = 'male' | 'female';

export const POPULATION = { tail: 90, front: 30, medtech: 30, guard: 25, engine: 25 } as const;
export const DEFAULT_BOARDING: Record<Community, Boarding> = {
  tail: 'refugee', front: 'bought', medtech: 'rescue', guard: 'force', engine: 'depot',
};
const COHORTS = {
  tail: { children: 18, elders: 4, born: 4 },
  front: { children: 5, elders: 3, born: 1 },
  medtech: { children: 3, elders: 3, born: 1 },
  guard: { children: 2, elders: 2, born: 1 },
  engine: { children: 2, elders: 8, born: 1 },
} as const;
const BOARDINGS: Boarding[] = ['depot', 'bought', 'force', 'rescue', 'refugee'];
const TOWNS: Record<Country, string[]> = {
  pl: ['볼슈틴, 폴란드', '포즈난, 폴란드', '브로츠와프, 폴란드'],
  de: ['라이프치히, 독일', '드레스덴, 독일', '베를린, 독일'],
  cz: ['프라하, 체코', '브르노, 체코', '오스트라바, 체코'],
  other: ['리비우, 우크라이나', '브라티슬라바, 슬로바키아', '부다페스트, 헝가리', '빌뉴스, 리투아니아'],
};

export interface Profile {
  id: string;
  name: string;
  name_original: string;
  age: number;
  community: Community;
  origin_tag: 'original' | 'rescued';
  boarding: Boarding;
  hometown: string;
  like: string;
  dislike: string;
  line: string;
  state: 'alive';
}
export interface Family {
  id: string;
  community: Community;
  parents: string[];
  children: string[];
}
interface NamePart { original: string; korean: string; gender?: Gender }
interface Surname { male: NamePart; female: NamePart }
interface NamePool { given: NamePart[]; surnames: Surname[] }
interface Preference {
  text: string;
  age_groups: AgeGroup[];
  communities: Community[];
  countries: Country[];
  home_countries: string[];
  seasons: ('winter' | 'thaw')[];
}
interface Source { path: string; sha256: string }
export interface References {
  names: Record<Country, NamePool>;
  likes: Preference[];
  dislikes: Preference[];
  blocked: Set<string>;
  sources: Source[];
  warnings: string[];
}
export interface Generated {
  profiles: Profile[];
  familyData: {
    version: 1;
    seed: string;
    sources: Source[];
    warnings: string[];
    preference_fallbacks: number;
    families: Family[];
  };
}

function parts(entries: string[]): NamePart[] {
  return entries.map((entry) => {
    const [original, korean] = entry.split('|');
    return { original, korean };
  });
}
function temporaryPool(given: string[], surnames: string[]): NamePool {
  return { given: parts(given), surnames: parts(surnames).map((part) => ({ male: part, female: part })) };
}
// Surnames are fictional placeholders, not a researched B1 name pool.
const TEMPORARY_NAMES: Record<Country, NamePool> = {
  pl: temporaryPool(
    ['Marta|마르타', 'Zofia|조피아', 'Ewa|에바', 'Anna|안나', 'Piotr|피오트르', 'Jan|얀', 'Tomasz|토마시', 'Adam|아담'],
    ['Welenik|벨레니크', 'Dalowik|달로비크', 'Zorenik|조레니크', 'Ralenik|랄레니크', 'Selenik|셀레니크', 'Talowik|탈로비크', 'Morenik|모레니크', 'Darenik|다레니크'],
  ),
  de: temporaryPool(
    ['Marta|마르타', 'Greta|그레타', 'Lena|레나', 'Anna|안나', 'Paul|파울', 'Emil|에밀', 'Otto|오토', 'Kurt|쿠르트'],
    ['Talwick|탈비크', 'Sornfeld|조른펠트', 'Lernau|레르나우', 'Falkried|팔크리트', 'Welnau|벨나우', 'Dornwick|도른비크', 'Marnfeld|마른펠트', 'Selried|젤리트'],
  ),
  cz: temporaryPool(
    ['Marta|마르타', 'Jana|야나', 'Eva|에바', 'Anna|안나', 'Pavel|파벨', 'Milan|밀란', 'Lukas|루카시', 'Adam|아담'],
    ['Dalenik|달레니크', 'Velenec|벨레네츠', 'Zoravec|조라베츠', 'Ralovec|랄로베츠', 'Selenec|셀레네츠', 'Morenik|모레니크', 'Talenec|탈레네츠', 'Dorenik|도레니크'],
  ),
  other: temporaryPool(
    ['Marta|마르타', 'Elena|엘레나', 'Eva|에바', 'Anna|안나', 'Milan|밀란', 'Pavel|파벨', 'Adam|아담', 'Emil|에밀'],
    ['Orlenik|오를레니크', 'Varenko|바렌코', 'Dorelka|도렐카', 'Zelenik|젤레니크', 'Tarenko|타렌코', 'Morelka|모렐카', 'Sarenik|사레니크', 'Darenko|다렌코'],
  ),
};
const TEMPORARY_LIKES = {
  child: ['천 조각 인형', '눈 위 발자국', '따뜻한 우유'],
  adult: ['손때 묻은 공구', '따뜻한 수프', '낡은 지도', '조용한 아침'],
  elder: ['오래된 사진', '따뜻한 담요', '옛 민요'],
};
const TEMPORARY_DISLIKES = ['찬 침상', '젖은 양말', '철판 긁는 소리', '빈 배급통', '새벽 호각'];

function hash(text: string): string {
  return createHash('sha256').update(text).digest('hex');
}
function normalizedName(text: string): string {
  return text.normalize('NFKD').replace(/\p{M}/gu, '').trim().replace(/\s+/g, ' ').toLowerCase();
}
function record(value: unknown, context: string): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error(`${context}: 객체가 필요합니다.`);
  return value as Record<string, unknown>;
}
function namePart(value: unknown, context: string, gender?: Gender): NamePart {
  const item = record(value, context);
  if (typeof item.original !== 'string' || !item.original.trim() || typeof item.korean !== 'string' || !/[가-힣]/u.test(item.korean)) {
    throw new Error(`${context}: original과 한글 korean이 필요합니다.`);
  }
  const specified = item.gender ?? gender;
  if (specified !== undefined && specified !== 'male' && specified !== 'female') throw new Error(`${context}: gender 값이 잘못되었습니다.`);
  return { original: item.original.trim(), korean: item.korean.trim(), ...(specified ? { gender: specified as Gender } : {}) };
}
function parseNamePool(value: unknown, context: string): NamePool {
  const data = record(value, context);
  const given = data.given_names ?? data.first_names ?? { male: data.male, female: data.female };
  let names: NamePart[];
  if (Array.isArray(given)) names = given.map((item) => namePart(item, context));
  else {
    const groups = record(given, context);
    names = (['male', 'female'] as const).flatMap((gender) => {
      if (!Array.isArray(groups[gender])) throw new Error(`${context}: ${gender} 이름 목록이 필요합니다.`);
      return groups[gender].map((item) => namePart(item, context, gender));
    });
  }
  if (!names.length || !Array.isArray(data.surnames) || !data.surnames.length) throw new Error(`${context}: 이름과 성 목록이 비어 있습니다.`);
  const surnames = data.surnames.map((value): Surname => {
    const item = record(value, context);
    if ('male' in item || 'female' in item) return { male: namePart(item.male, context), female: namePart(item.female, context) };
    const part = namePart(item, context);
    return { male: part, female: part };
  });
  return { given: names, surnames };
}
function tags<T extends string>(value: unknown, allowed: readonly T[], context: string): T[] {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.some((tag) => !allowed.includes(tag))) throw new Error(`${context}: 태그 목록이 잘못되었습니다.`);
  return [...value] as T[];
}
function parsePreferences(value: unknown, context: string): Preference[] {
  if (!Array.isArray(value)) throw new Error(`${context}: 목록이 필요합니다.`);
  return value.map((entry) => {
    const item = typeof entry === 'string' ? { text: entry } : record(entry, context);
    if (typeof item.text !== 'string' || !/[가-힣]/u.test(item.text) || [...item.text].length > 15 || item.text !== item.text.trim()) {
      throw new Error(`${context}: text는 공백 없는 양끝과 한글을 갖춘 15자 이내 문구여야 합니다.`);
    }
    const criteria = item.tags === undefined ? item : record(item.tags, context);
    const seasons = criteria.seasons;
    if (seasons !== undefined && (!Array.isArray(seasons) || seasons.some((season) => !['winter', 'thaw', '한파', '해빙기'].includes(season)))) {
      throw new Error(`${context}: 계절 태그가 잘못되었습니다.`);
    }
    const homeCountries = criteria.home_countries;
    if (homeCountries !== undefined && (!Array.isArray(homeCountries) || homeCountries.some((country) => typeof country !== 'string' || !country.trim()))) {
      throw new Error(`${context}: 고향 나라 태그가 잘못되었습니다.`);
    }
    return {
      text: item.text,
      age_groups: tags(criteria.age_groups, ['child', 'young', 'adult', 'middle', 'elder'], context),
      communities: tags(criteria.communities, COMMUNITIES, context),
      countries: tags(criteria.countries, ['pl', 'de', 'cz', 'other'], context),
      home_countries: homeCountries === undefined ? [] : [...homeCountries] as string[],
      seasons: seasons === undefined ? [] : seasons.map((season: string) => season === '한파' || season === 'winter' ? 'winter' : 'thaw'),
    };
  });
}

export function loadReferences(refRoot = resolve(S1_ROOT, '../ref')): References {
  const sources: Source[] = [];
  const warnings: string[] = [];
  function read(path: string): unknown | undefined {
    const fullPath = join(refRoot, path);
    if (!existsSync(fullPath)) return undefined;
    const raw = readFileSync(fullPath, 'utf8');
    const text = raw.replace(/^\uFEFF/u, '');
    sources.push({ path: `ref/${path.replaceAll('\\', '/')}`, sha256: hash(raw) });
    try { return JSON.parse(text); } catch { throw new Error(`ref/${path}: JSON을 읽을 수 없습니다.`); }
  }
  const names = {} as Record<Country, NamePool>;
  for (const country of ['pl', 'de', 'cz', 'other'] as const) {
    const path = `names/${country}.json`;
    const data = read(path);
    if (data === undefined) {
      names[country] = TEMPORARY_NAMES[country];
      sources.push({ path: `temporary:names/${country}`, sha256: hash(JSON.stringify(names[country])) });
      warnings.push(`B1 ${country}: 임시 이름 사용. 외래어 표기와 유명인 전수 대조는 미확인.`);
    } else names[country] = parseNamePool(data, `ref/${path}`);
  }
  const blocked = new Set<string>();
  const blocklist = read('names/famous_blocklist.json');
  if (blocklist === undefined) warnings.push('B1 유명인 제외 목록 없음. 가상 성을 쓰는 임시 목록으로 생성하며 전수 대조는 미확인.');
  else {
    const entries = Array.isArray(blocklist) ? blocklist : record(blocklist, '유명인 제외 목록').names;
    if (!Array.isArray(entries)) throw new Error('유명인 제외 목록: names 목록이 필요합니다.');
    for (const entry of entries) {
      if (typeof entry === 'string' && entry.trim()) blocked.add(normalizedName(entry));
      else {
        const item = namePart(entry, '유명인 제외 목록');
        blocked.add(normalizedName(item.original));
        blocked.add(normalizedName(item.korean));
      }
    }
  }
  const preferences = read('likes_dislikes.json');
  let likes: Preference[] = [];
  let dislikes: Preference[] = [];
  if (preferences === undefined) warnings.push('B6 없음. 나이대별 작은 임시 선호 목록 사용.');
  else {
    const data = record(preferences, 'B6');
    if (data.entries !== undefined) {
      if (!Array.isArray(data.entries)) throw new Error('B6: entries 목록이 필요합니다.');
      const entries = data.entries.map((entry) => {
        const item = record(entry, 'B6 entries');
        const options = tags(item.preference_options, ['like', 'dislike'], 'B6 preference_options');
        if (!options.length) throw new Error('B6: preference_options가 비어 있습니다.');
        return { item, options };
      });
      likes = parsePreferences(entries.filter(({ options }) => options.includes('like')).map(({ item }) => item), 'B6 likes');
      dislikes = parsePreferences(entries.filter(({ options }) => options.includes('dislike')).map(({ item }) => item), 'B6 dislikes');
    } else {
      likes = parsePreferences(data.likes, 'B6 likes');
      dislikes = parsePreferences(data.dislikes, 'B6 dislikes');
    }
    if (!likes.length || !dislikes.length) throw new Error('B6: 좋아하는 것과 싫어하는 것 목록이 모두 필요합니다.');
  }
  sources.push({ path: 'temporary:preferences', sha256: hash(JSON.stringify([TEMPORARY_LIKES, TEMPORARY_DISLIKES])) });
  return { names, likes, dislikes, blocked, sources, warnings };
}

function seededRandom(seed: string) {
  let state = 2166136261;
  for (const char of seed) state = Math.imul(state ^ char.codePointAt(0)!, 16777619) >>> 0;
  return () => {
    state = (state + 0x6D2B79F5) >>> 0;
    let value = Math.imul(state ^ (state >>> 15), state | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}
function ageGroup(age: number): AgeGroup {
  return age <= 15 ? 'child' : age <= 29 ? 'young' : age <= 49 ? 'adult' : age <= 64 ? 'middle' : 'elder';
}
function originTag(boarding: Boarding): Profile['origin_tag'] {
  return boarding === 'rescue' || boarding === 'refugee' ? 'rescued' : 'original';
}

export function generateProfiles(seed: string | number = DEFAULT_SEED, references = loadReferences()): Generated {
  if ((typeof seed === 'number' && !Number.isFinite(seed)) || !String(seed).trim()) throw new Error('시드는 비어 있지 않은 문자열이나 유한한 수여야 합니다.');
  const random = seededRandom(String(seed));
  const integer = (min: number, max: number) => min + Math.floor(random() * (max - min + 1));
  const pick = <T,>(items: readonly T[]): T => {
    if (!items.length) throw new Error('선택할 항목이 없습니다.');
    return items[integer(0, items.length - 1)];
  };
  const shuffle = <T,>(items: readonly T[]): T[] => {
    const copy = [...items];
    for (let i = copy.length - 1; i > 0; i--) { const j = integer(0, i); [copy[i], copy[j]] = [copy[j], copy[i]]; }
    return copy;
  };
  const profiles: Profile[] = [];
  const families: Family[] = [];
  const countries = new Map<string, Country>();
  const homeCountries = new Map<string, string>();
  for (const community of COMMUNITIES) {
    const cohort = COHORTS[community];
    const ages: number[] = [];
    for (let i = 0; i < cohort.born; i++) ages.push(community === 'tail' && i < 2 ? i * 5 : integer(0, 5));
    for (let i = cohort.born; i < cohort.children; i++) ages.push(integer(6, 15));
    for (let i = 0; i < cohort.elders; i++) ages.push(integer(65, 85));
    // Reserve enough age-compatible caregivers before filling other adult slots.
    const caregivers = Math.ceil(cohort.children / 2) * 2;
    for (let i = 0; i < caregivers; i++) ages.push(community === 'engine' ? integer(45, 50) : integer(35, 45));
    while (ages.length < POPULATION[community]) ages.push(community === 'engine' ? integer(52, 64) : integer(community === 'guard' ? 22 : 16, 64));
    const members = shuffle(ages).map((age, index): Profile => ({
      id: `p_${String(profiles.length + index + 1).padStart(3, '0')}`,
      name: '', name_original: '', age, community, origin_tag: 'original',
      boarding: DEFAULT_BOARDING[community], hometown: '', like: '', dislike: '', line: '', state: 'alive',
    }));
    const requiredExceptions = members.filter((person) => person.age <= 5 || ((community === 'guard' || community === 'engine') && person.age < 22));
    for (const person of requiredExceptions) person.boarding = person.age <= 5 ? 'born' : 'rescue';
    const remaining = POPULATION[community] / 5 - requiredExceptions.length;
    for (const person of shuffle(members.filter((person) => !requiredExceptions.includes(person))).slice(0, remaining)) {
      person.boarding = pick(BOARDINGS.filter((boarding) => boarding !== DEFAULT_BOARDING[community] && (person.age >= 22 || (boarding !== 'force' && boarding !== 'depot'))));
    }
    // Refugees have a wider birthplace pool; no community is assigned a nationality.
    let refugeeIndex = 0;
    for (const person of members) {
      const country = person.boarding === 'refugee' && refugeeIndex++ % 3 === 0 ? 'other' : pick(['pl', 'de', 'cz'] as const);
      countries.set(person.id, country);
      person.origin_tag = originTag(person.boarding);
      person.hometown = person.boarding === 'born' ? '열차, 출생 정차역 미상' : pick(TOWNS[country]);
      homeCountries.set(person.id, person.boarding === 'born' ? '' : person.hometown.split(', ')[1]);
    }
    const children = members.filter((person) => person.age <= 15).sort((a, b) => a.age - b.age || a.id.localeCompare(b.id));
    const usedParents = new Set<string>();
    for (let i = 0; i < children.length; i += 2) {
      const siblings = children.slice(i, i + 2);
      const eligible = members.filter((person) => !usedParents.has(person.id) && siblings.every((child) => person.age - child.age >= 18 && person.age - child.age <= 50));
      const parents = shuffle(eligible).slice(0, 2);
      if (parents.length !== 2) throw new Error(`${community}: 아이와 나이가 맞는 부모가 부족합니다.`);
      parents.forEach((parent) => usedParents.add(parent.id));
      const anchor = parents.find((parent) => parent.boarding === 'refugee') ?? parents[0];
      const country = countries.get(anchor.id)!;
      for (const person of [...parents, ...siblings]) {
        countries.set(person.id, country);
        homeCountries.set(person.id, homeCountries.get(anchor.id)!);
        if (person.boarding !== 'born') person.hometown = anchor.hometown;
        else person.origin_tag = anchor.origin_tag;
      }
      families.push({ id: `f_${String(families.length + 1).padStart(3, '0')}`, community, parents: parents.map((person) => person.id), children: siblings.map((person) => person.id) });
    }
    profiles.push(...members);
  }
  const byId = new Map(profiles.map((person) => [person.id, person]));
  const usedNames = new Map<string, number>();
  const assigned = new Set<string>();
  function candidates(pool: NamePool, surname: Surname, excluded = new Set<string>()) {
    return pool.given.map((given) => {
      const last = surname[given.gender ?? 'male'];
      return { original: `${given.original} ${last.original}`, korean: `${given.korean} ${last.korean}` };
    }).filter((name) => !references.blocked.has(normalizedName(name.original)) && !references.blocked.has(normalizedName(name.korean)) && !excluded.has(name.original));
  }
  function assignNames(members: Profile[]) {
    const pool = references.names[countries.get(members[0].id)!];
    const surnames = pool.surnames.filter((surname) => candidates(pool, surname).length >= members.length);
    if (!surnames.length) throw new Error('유명인 제외 후 가족 구성원에게 줄 이름과 성이 부족합니다.');
    const surname = pick(surnames);
    const excluded = new Set<string>();
    for (const person of members) {
      const available = candidates(pool, surname, excluded);
      const minimum = Math.min(...available.map((name) => usedNames.get(name.original) ?? 0));
      const name = pick(available.filter((name) => (usedNames.get(name.original) ?? 0) === minimum));
      person.name = name.korean;
      person.name_original = name.original;
      usedNames.set(name.original, (usedNames.get(name.original) ?? 0) + 1);
      excluded.add(name.original);
      assigned.add(person.id);
    }
  }
  for (const family of families) assignNames([...family.parents, ...family.children].map((id) => byId.get(id)!));
  for (const person of profiles) if (!assigned.has(person.id)) assignNames([person]);
  let preferenceFallbacks = 0;
  function preference(person: Profile, pool: Preference[], fallback: string[], excluded = ''): string {
    const country = countries.get(person.id)!;
    const group = ageGroup(person.age);
    const matches = pool.filter((item) => item.text !== excluded &&
      (!item.age_groups.length || item.age_groups.includes(group)) &&
      (!item.communities.length || item.communities.includes(person.community)) &&
      (!item.countries.length || item.countries.includes(country)) &&
      (!item.home_countries.length || item.home_countries.includes(homeCountries.get(person.id)!)) &&
      (!item.seasons.length || item.seasons.includes('winter')));
    if (matches.length) return pick(matches).text;
    preferenceFallbacks++;
    return pick(fallback.filter((text) => text !== excluded));
  }
  for (const person of profiles) {
    person.like = preference(person, references.likes, TEMPORARY_LIKES[person.age <= 15 ? 'child' : person.age >= 65 ? 'elder' : 'adult']);
    person.dislike = preference(person, references.dislikes, TEMPORARY_DISLIKES, person.like);
  }
  return {
    profiles,
    familyData: { version: 1, seed: String(seed), sources: references.sources.map((source) => ({ ...source })), warnings: [...references.warnings], preference_fallbacks: preferenceFallbacks, families },
  };
}

export function serializeGenerated(data: Generated): { profiles: string; families: string } {
  return { profiles: `${JSON.stringify(data.profiles, null, 2)}\n`, families: `${JSON.stringify(data.familyData, null, 2)}\n` };
}
function cli(args: string[]) {
  let seed = DEFAULT_SEED;
  let outputRoot = S1_ROOT;
  let refRoot = resolve(S1_ROOT, '../ref');
  let check = false;
  for (let index = 0; index < args.length; index++) {
    const option = args[index];
    if (option === '--check') check = true;
    else if (option === '--help') {
      console.log('사용법: node s1/tools/gen_profiles.ts [--seed 값] [--ref-dir 폴더] [--output-dir s1/내부폴더] [--check]');
      return;
    } else if (['--seed', '--ref-dir', '--output-dir'].includes(option)) {
      const value = args[++index];
      if (!value || value.startsWith('--')) throw new Error(`${option}: 값이 필요합니다.`);
      if (option === '--seed') seed = value;
      if (option === '--ref-dir') refRoot = resolve(value);
      if (option === '--output-dir') outputRoot = resolve(value);
    } else throw new Error(`알 수 없는 옵션: ${option}`);
  }
  const boundary = relative(S1_ROOT, outputRoot);
  if (boundary === '..' || boundary.startsWith(`..\\`) || boundary.startsWith('../') || isAbsolute(boundary)) throw new Error('출력 폴더는 s1/ 안에 있어야 합니다.');
  const data = generateProfiles(seed, loadReferences(refRoot));
  const serialized = serializeGenerated(data);
  for (const [path, text] of [[join(outputRoot, 'data/profiles.json'), serialized.profiles], [join(outputRoot, 'generated/profile_families.json'), serialized.families]]) {
    if (check) {
      if (!existsSync(path) || readFileSync(path, 'utf8') !== text) throw new Error(`${relative(S1_ROOT, path)}: 같은 시드·입력으로 재현되지 않습니다.`);
    } else {
      mkdirSync(dirname(path), { recursive: true });
      writeFileSync(path, text, 'utf8');
    }
  }
  console.log(`${check ? '재현 확인' : '생성 완료'}: 200명, 아이 30명, 노인 20명, 열차 출생 8명, 가족 ${data.familyData.families.length}묶음. 시드: ${seed}`);
  if (data.familyData.warnings.length) console.log(data.familyData.warnings.join('\n'));
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { cli(process.argv.slice(2)); } catch (error) {
    console.error(`프로필 생성 실패: ${error instanceof Error ? error.message : String(error)}`);
    process.exitCode = 1;
  }
}
