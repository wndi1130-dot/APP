import { createInitialState, createRng, randomInt } from '../../core';
import type {
  CommunityId, CommunityState, GameState, GroupInput, PersonInput, RngState, VoteChoice,
} from '../../core';
import { COMMUNITY_ORDER, DUMMY_FACTION_ID } from './groups';
import type { GroupId } from './groups';
import type { EventContent, LawContent } from './content';

// A4 화면 뼈대용 더미 데이터. 수치와 문장은 모두 임시다. A3(프로필 200명)와 A5(문장)가 오면 바꾼다.

export const DEFAULT_SEED = 's1a-dummy';

/** 콘텐츠 가이드 3.5의 공동체별 인원. */
export const DUMMY_POPULATIONS: Readonly<Record<CommunityId, number>> = Object.freeze({
  tail: 90, front: 30, medtech: 30, guard: 25, engine: 25,
});

export interface DummyProfile {
  id: string;
  community: CommunityId;
  age: number;
  name: string;
  nameOriginal: string;
}

export type CharacterRole = 'deputy' | 'ration_officer' | 'rep' | 'aide' | 'faction_leader';

export interface DummyCharacter {
  personId: string;
  role: CharacterRole;
  roleLabel: string;
  community: CommunityId;
  name: string;
  nameOriginal: string;
  age: number;
  hometown: string;
  boarding: string;
  like: string;
  dislike: string;
  /** 한 줄 소개. 40자 이내(가이드 2장). 성향과 비밀은 드러내지 않는다. */
  line: string;
  /** 더미 세력을 켰을 때만 나오는 인물. */
  factionOnly?: boolean;
}

// 이름 있는 인물. 헨리크와 파블라는 콘텐츠 가이드 3.2의 예시, 나머지 이름은 ref/names/(B1) 풀에서 골랐다.
export const DUMMY_CHARACTERS: readonly DummyCharacter[] = Object.freeze([
  {
    personId: 'p_engine_001', role: 'rep', roleLabel: '수석 기관사', community: 'engine',
    name: '헨리크 마주레크', nameOriginal: 'Henryk Mazurek', age: 67, hometown: '볼슈틴, 폴란드',
    boarding: '차고', like: '석탄 타는 냄새', dislike: "기관차를 '물건'이라 부르는 사람",
    line: '첫 겨울에 박물관 기관차에 불을 넣었다.',
  },
  {
    personId: 'p_tail_001', role: 'rep', roleLabel: '꼬리칸 대표', community: 'tail',
    name: '파블라 크레이치', nameOriginal: 'Pavla Krejčí', age: 41, hometown: '브르노, 체코',
    boarding: '피난', like: '라디오 잡음 사이의 음악', dislike: '앞칸 창에 걸린 커튼',
    line: '세 번째 겨울에 탄 피난민. 회의엔 서서 온다.',
  },
  {
    personId: 'p_tail_002', role: 'aide', roleLabel: '꼬리칸 측근', community: 'tail',
    name: '야쿠프 자용츠', nameOriginal: 'Jakub Zając', age: 29, hometown: '카토비체, 폴란드',
    boarding: '피난', like: '카드놀이', dislike: '줄 서기',
    line: '파블라 곁을 지킨다. 회기 날엔 문 앞에 선다.',
  },
  {
    personId: 'p_guard_001', role: 'rep', roleLabel: '경비대장', community: 'guard',
    name: '토마시 브루벨', nameOriginal: 'Tomasz Wróbel', age: 49, hometown: '브로츠와프, 폴란드',
    boarding: '경찰·군', like: '잘 닦인 장화', dislike: '보고 없는 이동',
    line: '경찰 출신. 보고는 세 줄을 넘지 않는다.',
  },
  {
    personId: 'p_guard_002', role: 'deputy', roleLabel: '부관', community: 'guard',
    name: '마르타 코즈워프스카', nameOriginal: 'Marta Kozłowska', age: 44, hometown: '포즈난, 폴란드',
    boarding: '경찰·군', like: '정확한 시계', dislike: '늦게 오는 답',
    line: '열차장의 일정을 가장 먼저 안다.',
  },
  {
    personId: 'p_front_001', role: 'rep', roleLabel: '앞칸 대표', community: 'front',
    name: '샤를로테 하르트만', nameOriginal: 'Charlotte Hartmann', age: 58, hometown: '라이프치히, 독일',
    boarding: '물건·권력', like: '은 식기', dislike: '닫히지 않는 칸 문',
    line: '시계와 은을 내고 탔다. 커튼을 걷지 않는다.',
  },
  {
    personId: 'p_front_002', role: 'ration_officer', roleLabel: '배급장', community: 'front',
    name: '요세프 하예크', nameOriginal: 'Josef Hájek', age: 52, hometown: '플젠, 체코',
    boarding: '물건·권력', like: '맞아떨어지는 장부', dislike: '빈칸이 있는 배급표',
    line: '배급표를 두 번 센다.',
  },
  {
    personId: 'p_medtech_001', role: 'rep', roleLabel: '의무장', community: 'medtech',
    name: '엘리아스 베버', nameOriginal: 'Elias Weber', age: 45, hometown: '코트부스, 독일',
    boarding: '구조', like: '끓인 물', dislike: '세지 않은 붕대',
    line: '구조된 의사. 남은 붕대를 매일 센다.',
  },
  {
    personId: 'p_medtech_021', role: 'faction_leader', roleLabel: '복원파 지도자', community: 'medtech',
    name: '루치에 체르나', nameOriginal: 'Lucie Černá', age: 36, hometown: '오스트라바, 체코',
    boarding: '구조', like: '라디오 부품', dislike: "'옛날이 좋았다'는 말",
    line: '고장 난 것은 고칠 수 있다고 믿는다.', factionOnly: true,
  },
]);

export function characterFor(personId: string): DummyCharacter | undefined {
  return DUMMY_CHARACTERS.find(character => character.personId === personId);
}

export function representativeOf(community: CommunityId): DummyCharacter {
  const rep = DUMMY_CHARACTERS.find(character => character.community === community && character.role === 'rep');
  if (!rep) throw new Error(`대표가 없습니다: ${community}`);
  return rep;
}

// 파견 인원처럼 그때그때 얼굴이 필요한 사람의 이름 풀(ref/names/의 pl, cz, de에서 일부).
type NamePair = readonly [korean: string, original: string];
interface Surname { male: NamePair; female?: NamePair }
interface NamePool { male: readonly NamePair[]; female: readonly NamePair[]; surnames: readonly Surname[] }

const NAME_POOLS: readonly NamePool[] = [
  {
    male: [['피오트르', 'Piotr'], ['토마시', 'Tomasz'], ['파베우', 'Paweł'], ['미하우', 'Michał'], ['마르친', 'Marcin'], ['우카시', 'Łukasz']],
    female: [['안나', 'Anna'], ['카타지나', 'Katarzyna'], ['아그니에슈카', 'Agnieszka'], ['에바', 'Ewa'], ['마그달레나', 'Magdalena'], ['요안나', 'Joanna']],
    surnames: [
      { male: ['노바크', 'Nowak'] }, { male: ['코발치크', 'Kowalczyk'] },
      { male: ['카민스키', 'Kamiński'], female: ['카민스카', 'Kamińska'] },
      { male: ['지엘린스키', 'Zieliński'], female: ['지엘린스카', 'Zielińska'] },
      { male: ['시만스키', 'Szymański'], female: ['시만스카', 'Szymańska'] },
      { male: ['마주르', 'Mazur'] }, { male: ['크라프치크', 'Krawczyk'] }, { male: ['카치마레크', 'Kaczmarek'] },
    ],
  },
  {
    male: [['이르지', 'Jiří'], ['파벨', 'Pavel'], ['마르틴', 'Martin'], ['즈데네크', 'Zdeněk'], ['카렐', 'Karel'], ['온드르제이', 'Ondřej']],
    female: [['야나', 'Jana'], ['하나', 'Hana'], ['렌카', 'Lenka'], ['페트라', 'Petra'], ['베로니카', 'Veronika'], ['테레자', 'Tereza']],
    surnames: [
      { male: ['스보보다', 'Svoboda'], female: ['스보보도바', 'Svobodová'] },
      { male: ['노보트니', 'Novotný'], female: ['노보트나', 'Novotná'] },
      { male: ['쿠체라', 'Kučera'], female: ['쿠체로바', 'Kučerová'] },
      { male: ['베셀리', 'Veselý'], female: ['베셀라', 'Veselá'] },
      { male: ['호라크', 'Horák'], female: ['호라코바', 'Horáková'] },
      { male: ['포코르니', 'Pokorný'], female: ['포코르나', 'Pokorná'] },
    ],
  },
  {
    male: [['펠릭스', 'Felix'], ['안톤', 'Anton'], ['요나스', 'Jonas'], ['에밀', 'Emil'], ['야코프', 'Jakob'], ['모리츠', 'Moritz']],
    female: [['마리', 'Marie'], ['클라라', 'Clara'], ['레나', 'Lena'], ['파울라', 'Paula'], ['이다', 'Ida'], ['엘라', 'Ella']],
    surnames: [
      { male: ['슈나이더', 'Schneider'] }, { male: ['피셔', 'Fischer'] }, { male: ['베커', 'Becker'] }, { male: ['리히터', 'Richter'] },
      { male: ['코흐', 'Koch'] }, { male: ['바우어', 'Bauer'] }, { male: ['클라인', 'Klein'] }, { male: ['노이만', 'Neumann'] },
    ],
  },
];

export function personId(community: CommunityId, index: number): string {
  return `p_${community}_${String(index).padStart(3, '0')}`;
}

function draw(rng: RngState, min: number, max: number): [number, RngState] {
  const next = randomInt(rng, min, max);
  return [next.value, next.rng];
}

/** 아이(0~15) 약 15%, 노인(65~) 약 10%. 기관실은 나이 많은 쪽으로 기운다(가이드 3.5). */
function drawAge(rng: RngState, community: CommunityId): [number, RngState] {
  const elderPercent = community === 'engine' ? 24 : 10;
  const childPercent = community === 'engine' ? 8 : 15;
  let roll: number;
  [roll, rng] = draw(rng, 1, 100);
  if (roll <= childPercent) return draw(rng, 0, 15);
  if (roll <= childPercent + elderPercent) return draw(rng, 65, 85);
  return draw(rng, 16, 64);
}

export interface DummyRoster {
  persons: PersonInput[];
  profiles: Record<string, DummyProfile>;
}

/** 시드로 200명의 나이와 이름을 정한다. 같은 시드면 같은 사람들이 나온다. */
export function createDummyRoster(seed: string): DummyRoster {
  let rng = createRng(`${seed}:people`);
  const persons: PersonInput[] = [];
  const profiles: Record<string, DummyProfile> = {};
  for (const community of COMMUNITY_ORDER) {
    for (let index = 1; index <= DUMMY_POPULATIONS[community]; index += 1) {
      const id = personId(community, index);
      const character = characterFor(id);
      let age: number;
      let name: string;
      let nameOriginal: string;
      if (character) {
        ({ age, name, nameOriginal } = character);
      } else {
        [age, rng] = drawAge(rng, community);
        let poolIndex: number;
        let gender: number;
        let givenIndex: number;
        let surnameIndex: number;
        [poolIndex, rng] = draw(rng, 0, NAME_POOLS.length - 1);
        const pool = NAME_POOLS[poolIndex];
        [gender, rng] = draw(rng, 0, 1);
        const givenList = gender === 0 ? pool.male : pool.female;
        [givenIndex, rng] = draw(rng, 0, givenList.length - 1);
        [surnameIndex, rng] = draw(rng, 0, pool.surnames.length - 1);
        const surname = pool.surnames[surnameIndex];
        const family = gender === 0 ? surname.male : surname.female ?? surname.male;
        name = `${givenList[givenIndex][0]} ${family[0]}`;
        nameOriginal = `${givenList[givenIndex][1]} ${family[1]}`;
      }
      persons.push({ id, community, age });
      profiles[id] = { id, community, age, name, nameOriginal };
    }
  }
  return { persons, profiles };
}

interface GroupStart {
  relation: number;
  cohesion: number;
}

const GROUP_START: Readonly<Record<GroupId, GroupStart>> = Object.freeze({
  tail: { relation: -58, cohesion: 0.82 },
  medtech: { relation: -12, cohesion: 0.9 },
  guard: { relation: 36, cohesion: 0.95 },
  front: { relation: 22, cohesion: 0.7 },
  engine: { relation: -27, cohesion: 0.88 },
  faction_restore: { relation: -34, cohesion: 0.92 },
});

const COMMUNITY_START: Readonly<Record<CommunityId, CommunityState>> = Object.freeze({
  tail: { warmth: 26, ration: 38, crowding: 86, exposure: 64 },
  medtech: { warmth: 48, ration: 55, crowding: 58, exposure: 40 },
  guard: { warmth: 57, ration: 66, crowding: 41, exposure: 72 },
  front: { warmth: 79, ration: 82, crowding: 24, exposure: 12 },
  engine: { warmth: 84, ration: 52, crowding: 36, exposure: 30 },
});

/** 더미 세력(복원파)이 공동체에서 끌어온 사람들. 세력원은 세력 의석으로 센다(기획서 4장). */
export const DUMMY_FACTION_MEMBERS: readonly string[] = Object.freeze([
  ...Array.from({ length: 10 }, (_, offset) => personId('tail', 61 + offset)),
  ...Array.from({ length: 4 }, (_, offset) => personId('medtech', 21 + offset)),
]);
export const DUMMY_FACTION_LEADER = personId('medtech', 21);

export function communityGroups(persons: readonly PersonInput[], withFaction: boolean): GroupInput[] {
  const factionMembers = new Set(withFaction ? DUMMY_FACTION_MEMBERS : []);
  const groups: GroupInput[] = COMMUNITY_ORDER.map(community => ({
    id: community,
    members: persons.filter(person => person.community === community && !factionMembers.has(person.id)).map(person => person.id),
    leaderId: personId(community, 1),
    ...GROUP_START[community],
  }));
  if (withFaction) {
    groups.push({
      id: DUMMY_FACTION_ID,
      members: [...DUMMY_FACTION_MEMBERS],
      leaderId: DUMMY_FACTION_LEADER,
      ...GROUP_START[DUMMY_FACTION_ID],
    });
  }
  return groups;
}

/** A2의 createInitialState로 1구간 시작 상태를 만들고 더미 시작값을 넣는다. */
export function createDummyGame(seed: string, withFaction = false): GameState {
  const roster = createDummyRoster(seed);
  const state = createInitialState({
    seed, segment: 1, persons: roster.persons, groups: communityGroups(roster.persons, withFaction),
  });
  for (const community of COMMUNITY_ORDER) state.communities[community] = { ...COMMUNITY_START[community] };
  state.trust = 58;
  state.tension = 37;
  state.fear = 12;
  state.resources = { coal: 140, food: 96, medicine: 14, luxury: 9 };
  return state;
}

/**
 * 더미 세력을 넣거나 뺀다. 사람의 처지와 상태는 그대로 두고 의석 집단만 다시 짠다.
 * 공동체 집단의 관계·결속도·약속표는 유지한다.
 */
export function withDummyFaction(state: GameState, on: boolean): GameState {
  const hasFaction = Object.hasOwn(state.groups, DUMMY_FACTION_ID);
  if (hasFaction === on) return state;
  const persons = Object.values(state.persons).map(person => ({ id: person.id, community: person.community }));
  const next: GameState = { ...state, groups: {} };
  for (const input of communityGroups(persons, on)) {
    const previous = state.groups[input.id];
    next.groups[input.id] = {
      id: input.id,
      members: [...input.members],
      ...(input.leaderId === undefined ? {} : { leaderId: input.leaderId }),
      relation: previous?.relation ?? input.relation ?? 0,
      cohesion: previous?.cohesion ?? input.cohesion ?? 0.75,
      votes: previous?.votes ?? 0,
    };
  }
  return next;
}

// 회기 안건(더미). law는 A1 법안 스키마 모양이고, title·promised·stance는 화면 뼈대에만 쓰는 값이다.
export interface DummyBill {
  law: LawContent;
  /** 법안 스키마에 이름 필드가 없어 화면용으로 따로 둔다. */
  title: string;
  /** 지도부가 거래로 약속한 표(더미). 실제 게임에선 거래 결과가 정한다. */
  promised: Partial<Record<GroupId, number>>;
  /** 약속하지 않은 표의 선택. 없으면 기권(미정). */
  stance: Partial<Record<GroupId, VoteChoice>>;
}

export const DUMMY_BILLS: readonly DummyBill[] = Object.freeze([
  {
    title: '배급 균등법',
    law: {
      id: 'law_dummy_equal_ration',
      kind: 'normal',
      opens_when: [],
      effects: [
        { type: 'community.ration', target: 'tail', amount: 10 },
        { type: 'community.ration', target: 'front', amount: -10 },
      ],
      stances: { ration: 'equal', authority: 'neutral', technology: 'neutral' },
      preview: '꼬리칸 배급 +10, 앞칸 배급 −10. 칸마다 같은 몫을 받는다.',
      chronicle: { passed: 'ch_dummy_law_passed', rejected: 'ch_dummy_law_rejected' },
    },
    promised: { tail: 38, medtech: 8 },
    stance: { engine: 'yes', guard: 'no', front: 'no' },
  },
  {
    title: '비상대권 법',
    law: {
      id: 'law_dummy_emergency_powers',
      kind: 'rule',
      opens_when: [],
      effects: [{ type: 'flag', id: 'emergency_powers', value: 3 }],
      stances: { ration: 'neutral', authority: 'discipline', technology: 'neutral' },
      preview: '3구간 동안 열차장이 표결 없이 포고를 낸다.',
      chronicle: { passed: 'ch_dummy_law_passed', rejected: 'ch_dummy_law_rejected' },
    },
    promised: { medtech: 6, engine: 8 },
    stance: { guard: 'yes', front: 'yes', tail: 'no', faction_restore: 'no' },
  },
]);

export function billById(id: string): DummyBill {
  const bill = DUMMY_BILLS.find(candidate => candidate.law.id === id);
  if (!bill) throw new Error(`모르는 안건입니다: ${id}`);
  return bill;
}

// 결정 카드(더미). event는 A1 사건 카드 스키마 모양이다. dispatch는 필드 결정 카드의
// '누구를 보내나'를 흉내 낸 화면 뼈대 값으로, 고르는 순간 사람 id를 뽑아 person.away 효과로 바꾼다.
export interface DispatchOrder {
  community: CommunityId;
  count: number;
  segments: number;
}

export interface DummyCard {
  event: EventContent;
  dispatch?: Readonly<Record<number, DispatchOrder>>;
}

export const DUMMY_CARDS: readonly DummyCard[] = Object.freeze([
  {
    event: {
      id: 'ev_dummy_tail_stove',
      stage: 's1a',
      phase: 'travel',
      trigger: [],
      speaker: 'tail',
      body: '꼬리칸 난로가 이틀째 꺼져 있다. 파블라 크레이치가 석탄 한 자루를 달라고 한다. 기관실은 남는 석탄이 없다고 한다.',
      choices: [
        {
          label: '석탄을 내준다',
          effects: [
            { type: 'coal', amount: -8 },
            { type: 'community.warmth', target: 'tail', amount: 10 },
            { type: 'relation', target: 'tail', amount: 8 },
            { type: 'relation', target: 'engine', amount: -5 },
          ],
          followups: [],
          witnesses: [],
        },
        {
          label: '앞칸 난방을 줄인다',
          effects: [
            { type: 'community.warmth', target: 'front', amount: -10 },
            { type: 'community.warmth', target: 'tail', amount: 8 },
            { type: 'relation', target: 'front', amount: -8 },
            { type: 'relation', target: 'tail', amount: 5 },
          ],
          followups: [],
          witnesses: [],
        },
        {
          label: '거절한다',
          effects: [
            { type: 'relation', target: 'tail', amount: -8 },
            { type: 'tension', amount: 5 },
          ],
          followups: [],
          witnesses: [],
        },
      ],
      repeat: 1,
    },
  },
  {
    event: {
      id: 'ev_dummy_freight_stop',
      stage: 's1a',
      phase: 'stop',
      trigger: [],
      speaker: 'guard',
      body: '측선에 버려진 화차 셋이 서 있다. 문은 얼어붙었고 승강장은 조용하다. 해가 지기까지 두 시간이다.',
      choices: [
        {
          label: '꼬리칸 4명을 보낸다',
          effects: [
            { type: 'food', amount: 12 },
            { type: 'coal', amount: -3 },
          ],
          followups: [],
          witnesses: [],
        },
        {
          label: '통과한다',
          effects: [],
          followups: [],
          witnesses: [],
        },
      ],
      repeat: 1,
    },
    dispatch: { 0: { community: 'tail', count: 4, segments: 2 } },
  },
]);

export function cardForPhase(phase: string): DummyCard | undefined {
  return DUMMY_CARDS.find(card => card.event.phase === phase);
}

export function cardById(id: string): DummyCard {
  const card = DUMMY_CARDS.find(candidate => candidate.event.id === id);
  if (!card) throw new Error(`모르는 카드입니다: ${id}`);
  return card;
}

/** 파견 추천: 열차에 있는 16~64세, 이름 있는 인물 제외, 번호 순. */
export function dispatchCandidates(state: GameState, order: DispatchOrder): string[] {
  const named = new Set(DUMMY_CHARACTERS.map(character => character.personId));
  return Object.values(state.persons)
    .filter(person => person.community === order.community && person.state === 'alive'
      && person.age !== undefined && person.age >= 16 && person.age <= 64 && !named.has(person.id))
    .map(person => person.id)
    .sort()
    .slice(0, order.count);
}
