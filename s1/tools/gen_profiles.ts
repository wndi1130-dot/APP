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
// Refugees from 'other' keep one language for given name, surname and hometown.
type Language = 'pl' | 'de' | 'cz' | 'uk' | 'sk' | 'hu' | 'lt';
const OTHER_LANGUAGES = ['uk', 'sk', 'hu', 'lt'] as const;
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
function towns(country: string, names: string[]): string[] {
  return names.map((name) => `${name}, ${country}`);
}
// Korean spellings come from ref/names/transliterate.py, written without spaces.
// Established usages override it: 슈트랄준트, 켐니츠, 마그데부르크.
const TOWNS: Record<Language, string[]> = {
  // 고향 목록엔 금지선 장소 줄에 이름이 오른 곳과 수용소나 학살 장소로 알려진 작은 도시·마을을 쓰지 않는다. 큰 도시는 쓴다(2026-10-07).
  // 뺀 자리는 같은 시드로 같은 사람이 나오게 자리 수를 지키고 다른 이름으로 채운다(pl 다섯째·여섯째·열다섯째, de 아홉째).
  pl: towns('폴란드', [
    '볼슈틴', '포즈난', '브로츠와프', '레슈노', '포즈난', '레슈노', '라코니에비체', '노비토미실', '지엘로나구라', '술레후프',
    '카르고바', '바비모스트', '그워구프', '레그니차', '슈체친', '시렘', '제핀', '시비에보진', '미엥지제치', '그로지스크비엘코폴스키',
  ]),
  de: towns('독일', [
    '라이프치히', '드레스덴', '베를린', '코트부스', '괴를리츠', '구벤', '바우첸', '리자', '포츠담', '비텐베르크',
    '할레', '아이젠휘텐슈타트', '젠프텐베르크', '치타우', '슈트랄준트', '노이브란덴부르크', '켐니츠', '츠비카우', '마그데부르크', '데사우',
  ]),
  cz: towns('체코', [
    '프라하', '브르노', '오스트라바', '데친', '우스티나트라벰', '리베레츠', '파르두비체', '체스카트르제보바', '프르제로프', '올로모우츠',
    '콜린', '이흘라바', '타보르', '클라드노', '모스트', '호무토프', '트루트노프', '나호트', '즐린', '흐라데츠크랄로베',
  ]),
  uk: towns('우크라이나', ['리비우', '키이우', '루츠크', '리우네', '지토미르']),
  sk: towns('슬로바키아', ['브라티슬라바', '코시체', '질리나', '니트라']),
  hu: towns('헝가리', ['부다페스트', '데브레첸', '죄르', '페치']),
  lt: towns('리투아니아', ['빌뉴스', '카우나스', '클라이페다', '샤울레이']),
};

export interface Profile {
  id: string;
  name: string;
  name_original: string;
  /** 이름 풀의 성별. 폴란드어·체코어 과거형이 주어 성별을 따라서 번역에 쓴다(s1_content_guide 6.5). 화면엔 안 보인다.
   *  성별을 적지 않은 이름 풀에서 뽑힌 사람은 비워 두고 경고를 남긴다(스키마 검사에서 걸린다). */
  gender?: Gender;
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
interface NamePart { original: string; korean: string; gender?: Gender; language?: string }
interface Surname { male: NamePart; female: NamePart; femaleMarried?: NamePart; language?: string }
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
/** 임시 이름 목록은 앞 여섯이 여자 이름, 뒤 여섯이 남자 이름이다. */
function temporaryPool(given: string[], surnames: string[]): NamePool {
  const named = parts(given).map((part, index): NamePart => ({ ...part, gender: index < given.length / 2 ? 'female' : 'male' }));
  return { given: named, surnames: parts(surnames).map((part) => ({ male: part, female: part })) };
}
// Surnames are fictional placeholders, not a researched B1 name pool. Each pool is
// large enough for 200 unique full names when ref/names/ is missing (tests).
const TEMPORARY_NAMES: Record<Country, NamePool> = {
  pl: temporaryPool(
    ['Marta|마르타', 'Zofia|조피아', 'Ewa|에바', 'Anna|안나', 'Hanna|한나', 'Maria|마리아', 'Piotr|피오트르', 'Jan|얀', 'Tomasz|토마시', 'Adam|아담', 'Marek|마레크', 'Jakub|야쿠프'],
    ['Welenik|벨레니크', 'Dalowik|달로비크', 'Zorenik|조레니크', 'Ralenik|랄레니크', 'Selenik|셀레니크', 'Talowik|탈로비크', 'Morenik|모레니크', 'Darenik|다레니크', 'Kalowik|칼로비크', 'Borenik|보레니크', 'Pelowik|펠로비크', 'Wirenik|비레니크'],
  ),
  de: temporaryPool(
    ['Marta|마르타', 'Greta|그레타', 'Lena|레나', 'Anna|안나', 'Ilse|일제', 'Frieda|프리다', 'Paul|파울', 'Emil|에밀', 'Otto|오토', 'Kurt|쿠르트', 'Hans|한스', 'Karl|카를'],
    ['Talwick|탈비크', 'Sornfeld|조른펠트', 'Lernau|레르나우', 'Falkried|팔크리트', 'Welnau|벨나우', 'Dornwick|도른비크', 'Marnfeld|마른펠트', 'Selried|젤리트', 'Halbern|할베른', 'Kornwald|코른발트', 'Brennau|브레나우', 'Gelwitz|겔비츠'],
  ),
  cz: temporaryPool(
    ['Marta|마르타', 'Jana|야나', 'Eva|에바', 'Anna|안나', 'Petra|페트라', 'Lucie|루치에', 'Pavel|파벨', 'Milan|밀란', 'Lukas|루카시', 'Adam|아담', 'Jiří|이르지', 'Tomáš|토마시'],
    ['Dalenik|달레니크', 'Velenec|벨레네츠', 'Zoravec|조라베츠', 'Ralovec|랄로베츠', 'Selenec|셀레네츠', 'Morinek|모리네크', 'Talenec|탈레네츠', 'Dorenik|도레니크', 'Hrabec|흐라베츠', 'Kolenec|콜레네츠', 'Pivonec|피보네츠', 'Smolenec|스몰레네츠'],
  ),
  other: temporaryPool(
    ['Marta|마르타', 'Elena|엘레나', 'Eva|에바', 'Anna|안나', 'Olena|올레나', 'Iryna|이리나', 'Milan|밀란', 'Pavel|파벨', 'Adam|아담', 'Emil|에밀', 'Taras|타라스', 'Andrii|안드리'],
    ['Orlenik|오를레니크', 'Varenko|바렌코', 'Dorelka|도렐카', 'Zelenik|젤레니크', 'Tarenko|타렌코', 'Morelka|모렐카', 'Sarenik|사레니크', 'Darenko|다렌코', 'Kovrenko|코브렌코', 'Lisenko|리센코', 'Pavlenik|파블레니크', 'Hordenko|호르덴코'],
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
  const language = typeof item.language === 'string' && item.language.trim() ? item.language.trim() : undefined;
  return {
    original: item.original.trim(), korean: item.korean.trim(),
    ...(specified ? { gender: specified as Gender } : {}), ...(language ? { language } : {}),
  };
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
    const own = typeof item.language === 'string' && item.language.trim() ? item.language.trim() : undefined;
    if ('male' in item || 'female' in item) {
      const male = namePart(item.male, context);
      const female = namePart(item.female, context);
      const femaleMarried = item.female_married === undefined ? undefined : namePart(item.female_married, context);
      const language = own ?? male.language;
      return { male, female, ...(femaleMarried ? { femaleMarried } : {}), ...(language ? { language } : {}) };
    }
    const part = namePart(item, context);
    const language = own ?? part.language;
    return { male: part, female: part, ...(language ? { language } : {}) };
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
  const languages = new Map<string, Language>();
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
      name: '', name_original: '', gender: undefined, age, community, origin_tag: 'original',
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
      const language: Language = country === 'other' ? pick(OTHER_LANGUAGES) : country;
      countries.set(person.id, country);
      languages.set(person.id, language);
      person.origin_tag = originTag(person.boarding);
      person.hometown = person.boarding === 'born' ? '열차, 출생 정차역 미상' : pick(TOWNS[language]);
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
        languages.set(person.id, languages.get(anchor.id)!);
        homeCountries.set(person.id, homeCountries.get(anchor.id)!);
        if (person.boarding !== 'born') person.hometown = anchor.hometown;
        else person.origin_tag = anchor.origin_tag;
      }
      families.push({ id: `f_${String(families.length + 1).padStart(3, '0')}`, community, parents: parents.map((person) => person.id), children: siblings.map((person) => person.id) });
    }
    profiles.push(...members);
  }
  const byId = new Map(profiles.map((person) => [person.id, person]));
  const parentIds = new Set(families.flatMap((family) => family.parents));
  // Players remember people by name, so no two of the 200 share a full name in either script.
  const usedNames = new Set<string>();
  const genderless = new Set<string>();
  const assigned = new Set<string>();
  const fits = (entry: string | undefined, language: Language) => entry === undefined || entry === language;
  function lastName(surname: Surname, gender: Gender, person: Profile): NamePart {
    return gender === 'female' && surname.femaleMarried && parentIds.has(person.id) ? surname.femaleMarried : surname[gender];
  }
  function candidates(pool: NamePool, surname: Surname, person: Profile, language: Language, takenGiven: Set<string>, takenKeys: Set<string>) {
    return pool.given.filter((given) => fits(given.language, language) && !takenGiven.has(given.original)).map((given) => {
      const last = lastName(surname, given.gender ?? 'male', person);
      // Hungarian names keep family-name-first order in Korean too (e.g. 버르토크 벨러).
      const [first, second] = given.language === 'hu' ? [last, given] : [given, last];
      return { given: given.original, gender: given.gender, original: `${first.original} ${second.original}`, korean: `${first.korean} ${second.korean}` };
    }).filter((name) => ![normalizedName(name.original), normalizedName(name.korean)].some((key) => references.blocked.has(key) || usedNames.has(key) || takenKeys.has(key)));
  }
  function assignNames(members: Profile[]) {
    const pool = references.names[countries.get(members[0].id)!];
    const language = languages.get(members[0].id)!;
    // Try surnames in seeded order; a family shares one surname but never a given name.
    for (const surname of shuffle(pool.surnames.filter((surname) => fits(surname.language, language)))) {
      // Different spellings can share a Korean form (Lukas, Lucas), so siblings are checked in both scripts.
      const takenGiven = new Set<string>();
      const takenKeys = new Set<string>();
      const chosen: { person: Profile; name: ReturnType<typeof candidates>[number] }[] = [];
      for (const person of members) {
        const available = candidates(pool, surname, person, language, takenGiven, takenKeys);
        if (!available.length) break;
        const name = pick(available);
        chosen.push({ person, name });
        takenGiven.add(name.given);
        takenKeys.add(normalizedName(name.original));
        takenKeys.add(normalizedName(name.korean));
      }
      if (chosen.length !== members.length) continue;
      for (const { person, name } of chosen) {
        person.name = name.korean;
        person.name_original = name.original;
        if (name.gender) person.gender = name.gender;
        else genderless.add(name.given);
        usedNames.add(normalizedName(name.original));
        usedNames.add(normalizedName(name.korean));
        assigned.add(person.id);
      }
      return;
    }
    throw new Error('유명인 제외와 이름 중복 금지 뒤 가족 구성원에게 줄 이름과 성이 부족합니다.');
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
    familyData: { version: 1, seed: String(seed), sources: references.sources.map((source) => ({ ...source })), warnings: [...references.warnings, ...(genderless.size ? [`이름 풀에 성별이 없는 이름 ${genderless.size}개가 뽑혔다(${[...genderless].slice(0, 5).join(', ')}). 그 사람은 gender가 비어 번역 성별 검사가 빠진다.`] : [])], preference_fallbacks: preferenceFallbacks, families },
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
