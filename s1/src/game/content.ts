import { COMMS, COMM_NAME, LAWS, P, PLACES, REP_ROLE } from './data';
import type { Comm, LawId } from './data';
import { affordable, applyEffs, CARD_EXTENSIONS, costLines, EVENT_CHAIN_MAX, EVENT_COOLDOWN, memo, politicsLines, withAfford } from './cards';
import type { CardView, Choice, Eff } from './cards';
import { onDeath } from './death';
import { CAR_COMM } from './domestic/data';
import { living } from './domestic/state';
import { CAR_NAME } from './domestic/workshop';
import { addCard, clamp, isGone, journal, lawActive, pick, PROFILES, situation } from './state';
import type { Card, Game, Profile } from './state';

// 콘텐츠 JSON 사건(s1_content_guide 6장, 이야기 스레드 6c0fd2b): Gemini로 새로 쓰는 사건은 처음부터 JSON(event.schema.json)에 넣고
// 게임은 여기서 읽는다. 지금 TS 안에 있는 사건(cards.ts TRAVEL_EVENTS)은 그대로 두고 S3에서 키로 뺀다.
// 데이터는 npm run validate를 통과한 것만 들어온다고 본다(tests/game/content.test.ts가 data/events를 검사한다).
// 지금 읽는 것: 이동(travel) 단계 사건, 단계 s1a(내정 켠 판이면 s1c도). 정차·회기·정산 단계와 s1b는 아직 안 뽑는다.
// 자리표시자 묶기(bind), 효과 넷(secret·votes·deal·chronicle), 대표 사건의 community는 콘텐츠 가이드 6.9(main e3c0302)를 따른다.
// 비밀(data/secrets)과 거래 조건(data/deals)도 같은 길로 읽는다.

export type Placeholder = 'person' | 'person2' | 'captain' | 'community' | 'law' | 'place' | 'car' | 'item' | 'n' | 'n2';
type CommunityMetric = 'warmth' | 'ration' | 'crowding' | 'exposure';
export type ContentCondition =
  | { type: 'segment'; min: number; max: number }
  | { type: 'community'; community: Comm; metric: CommunityMetric; operator: 'lt' | 'lte' | 'eq' | 'gte' | 'gt'; value: number }
  | { type: 'flag'; id: string; value: boolean | number | string }
  | { type: 'person'; id: string; state: 'alive' | 'injured' | 'dead' | 'away' };
export type ContentEffect =
  | { type: 'coal' | 'food' | 'medicine' | 'luxury'; amount: number }
  | { type: 'symbol' | 'secret'; id: string; amount: number }
  | { type: 'community.warmth' | 'community.ration' | 'community.crowding' | 'community.exposure'; target: Comm; amount: number }
  | { type: 'trust' | 'tension' | 'fear'; amount: number }
  | { type: 'relation' | 'cohesion'; target: string; amount: number }
  | { type: 'votes'; target: string; amount: number; side?: 'captain' | 'yes' | 'no' }
  | { type: 'person.state'; target: string; state: 'alive' | 'injured' | 'dead' | 'away' }
  | { type: 'person.away'; target: string; segments: number }
  | { type: 'flag'; id: string; value: boolean | number | string }
  | { type: 'followup'; id: string; delay: number }
  | { type: 'deal' | 'chronicle'; id: string };
export interface ContentChoice {
  id: string; label: string; say?: string; effects: ContentEffect[]; followups: string[];
  witnesses: (string | { person: string; text: string })[];
}
export interface ContentEvent {
  id: string; stage: 's1a' | 's1b' | 's1c'; phase: 'travel' | 'stop' | 'council' | 'settle'; trigger: ContentCondition[];
  speaker: string; body: string; choices: ContentChoice[]; repeat: number; chronicle?: string; params?: Placeholder[];
  /** 자리표시자 값을 어디서 가져올지(6.9 표). 없으면 고정 규칙 */
  bind?: Partial<Record<Placeholder, string>>;
  /** speaker가 rep·aide일 때 그 공동체 id나 any */
  community?: string;
  /** speaker가 faction_leader일 때 세력 id(S1b 몫, S1a는 안 뽑는다) */
  faction?: string;
}
/** 비밀(schema/secret.schema.json). 텍스트의 {person}은 그 비밀을 가진 사람이다. */
export interface ContentSecret { id: string; kind: string; severity: number; proof: 'rumor' | 'evidence'; sources: string[]; text: string }
/** 거래 조건(schema/deal.schema.json). ask는 기한에 열차장이 치를 것, gives는 받자마자 오는 것, breach는 못 치렀을 때 */
export interface ContentDeal {
  id: string; tool: string; from: string; ask: ContentEffect[]; deadline: number; gives: ContentEffect[]; breach: ContentEffect[]; arc_tags: string[];
  /** 요구하는 쪽의 말(40자). 요구·주는 것·어기면은 효과에서 비용 줄로 만든다 */
  say?: string;
}

/** 읽어 들인 사건. 브라우저는 main.ts가 data/events를, 도구는 tools/content_fs.ts가 디스크에서 채운다. */
export const CONTENT_EVENTS: ContentEvent[] = [];

export const CONTENT_SECRETS: ContentSecret[] = [];
export const CONTENT_DEALS: ContentDeal[] = [];

function upsert<T extends { id: string }>(into: T[], list: unknown[], ok: (x: T) => boolean): void {
  for (const raw of list) {
    const x = raw as T;
    if (!x || typeof x.id !== 'string' || !ok(x)) continue;
    const at = into.findIndex(e => e.id === x.id);
    if (at >= 0) into[at] = x; else into.push(x);
  }
}

export function registerContentEvents(list: unknown[]): void {
  upsert(CONTENT_EVENTS, list, ev => Array.isArray(ev.choices));
}
export function registerContentSecrets(list: unknown[]): void {
  upsert(CONTENT_SECRETS, list, x => typeof x.text === 'string');
}
export function registerContentDeals(list: unknown[]): void {
  upsert(CONTENT_DEALS, list, x => Array.isArray(x.ask) && Array.isArray(x.gives) && Array.isArray(x.breach));
}

export const CONTENT_CARD_KIND = 'content';
export const CONTENT_DEAL_KIND = 'content-deal';
/** person.state away: 돌아오는 구간을 정하지 않은 떠남. 저장(JSON)에 Infinity를 못 써서 큰 수로 둔다 */
const AWAY_FOREVER = 1e6;

// ---- 한국어 조사(6.3) ----
// 숫자는 한국어로 읽은 끝소리로 본다(1 일, 3 삼, 6 육, 7 칠, 8 팔, 0 영은 받침, 그중 1·7·8은 ㄹ).
const DIGIT_FINAL: Record<string, 'none' | 'final' | 'rieul'> = {
  0: 'final', 1: 'rieul', 2: 'none', 3: 'final', 4: 'none', 5: 'none', 6: 'final', 7: 'rieul', 8: 'rieul', 9: 'none',
};

function finalOf(word: string): 'none' | 'final' | 'rieul' {
  const ch = [...word.trim()].pop() ?? '';
  const code = ch.charCodeAt(0);
  if (code >= 0xac00 && code <= 0xd7a3) {
    const jong = (code - 0xac00) % 28;
    return jong === 0 ? 'none' : jong === 8 ? 'rieul' : 'final';
  }
  return DIGIT_FINAL[ch] ?? 'none';
}

/** '이/가' 같은 짝에서 받침에 맞는 쪽을 고른다. 으로/로는 ㄹ 받침이면 로. */
export function josa(word: string, pair: string): string {
  const [withFinal, without] = pair.split('/');
  const f = finalOf(word);
  if (withFinal === '으로') return f === 'final' ? '으로' : '로';
  return f === 'none' ? without : withFinal;
}

/** {name}[a/b]를 값과 조사로 채운다. 값이 없는 자리표시자는 그대로 둔다(사건이 뽑히기 전에 거른다). */
export function fillText(text: string, values: Partial<Record<Placeholder, string>>): string {
  return text.replace(/\{([a-z0-9]+)\}(\[([^\]/]+\/[^\]]+)\])?/gu, (whole, name: Placeholder, _b, pair?: string) => {
    const v = values[name];
    if (v === undefined) return whole;
    return pair ? v + josa(v, pair) : v;
  });
}

// ---- 조건 ----
const METRIC_INDEX: Record<CommunityMetric, 0 | 1 | 2 | 3> = { warmth: 0, ration: 1, crowding: 2, exposure: 3 };

function flagsOf(g: Game): Record<string, boolean | number | string> {
  return (g.contentFlags ??= {});
}

export function personState(g: Game, id: string): 'alive' | 'injured' | 'dead' | 'away' {
  const p = PROFILES.find(x => x.id === id);
  if (!p) return 'dead';
  if ((g.contentAway ?? {})[id] !== undefined) return 'away';
  if (g.deaths.includes(p.name)) return 'dead';
  if (isGone(g, p.name)) return 'away';
  if ((g.contentInjured ?? []).includes(id)) return 'injured';
  return 'alive';
}

function holds(g: Game, c: ContentCondition): boolean {
  switch (c.type) {
    case 'segment': return g.seg >= c.min && g.seg <= c.max;
    case 'community': {
      const v = situation(g, c.community)[METRIC_INDEX[c.metric]];
      return c.operator === 'lt' ? v < c.value : c.operator === 'lte' ? v <= c.value : c.operator === 'eq' ? Math.round(v) === c.value
        : c.operator === 'gte' ? v >= c.value : v > c.value;
    }
    case 'flag': return flagsOf(g)[c.id] === c.value;
    case 'person': return personState(g, c.id) === c.state;
    default: return false;
  }
}

/** 말하는 칸: speaker가 칸이면 그 칸, 대표·측근이면 community 필드(any면 카드를 올릴 때 고른다). */
function speakerComm(ev: ContentEvent): Comm | undefined {
  if (isComm(ev.speaker)) return ev.speaker;
  return ev.community && isComm(ev.community) ? ev.community : undefined;
}

// ---- 자리표시자 값(s1_content_guide 6.9 표) ----
// 판에 값을 댈 사람·법·상징물이 없으면 그 사건은 뽑지 않는다. 뽑을 때 고르는 값은 카드에 얼려 둔다(다시 그려도 같다).
// 뽑을 수 있는지 보는 단계(canBind)는 난수를 안 쓴다. 쓰면 사건이 없는 판의 흐름까지 바뀐다.

/** 사람 후보: 그 칸의 산 사람 중 대표가 아니고 자리를 비우지 않은 사람. */
function people(g: Game, c: Comm, except: string[] = []): Profile[] {
  const rep = g.comms[c].leader.name;
  return PROFILES.filter(p => p.community === c && p.name !== rep && !isGone(g, p.name) && personState(g, p.id) === 'alive' && !except.includes(p.name));
}

function witnessPeople(g: Game, ev: ContentEvent): Profile[] {
  const ids = [...new Set(ev.choices.flatMap(ch => ch.witnesses.map(w => (typeof w === 'string' ? w : w.person))))];
  return ids.map(id => PROFILES.find(p => p.id === id)).filter((p): p is Profile => !!p && personState(g, p.id) === 'alive');
}

function rolePeople(g: Game, role: string): string[] {
  return (g.dom ? living(g) : []).filter(p => p.role === role).map(p => p.name);
}

/** person·person2 후보 이름. 희생양 후보는 처지로만 켠 표시(g.scapegoatOk)가 참인 사람뿐이다(민감 규칙: 탓은 처지로만). */
function personPool(g: Game, ev: ContentEvent, c: Comm, bind: string | undefined, except: string[]): string[] {
  if (!bind) return people(g, c, except).map(p => p.name);
  if (bind.startsWith('community:')) { const o = bind.slice(10); return isComm(o) ? people(g, o, except).map(p => p.name) : []; }
  if (bind.startsWith('role:')) return rolePeople(g, bind.slice(5)).filter(n => !except.includes(n));
  if (bind === 'witness') return witnessPeople(g, ev).map(p => p.name).filter(n => !except.includes(n));
  if (bind === 'scapegoat') return (g.scapegoatOk ?? []).map(id => PROFILES.find(p => p.id === id)).filter((p): p is Profile => !!p && personState(g, p.id) === 'alive').map(p => p.name).filter(n => !except.includes(n));
  return [];
}

function lastLaw(g: Game): LawId | undefined {
  return (Object.entries(g.passed) as [LawId, number][]).sort((a, b) => b[1] - a[1])[0]?.[0];
}
function lastRepealed(g: Game): LawId | undefined {
  return (Object.entries(g.repealedAt) as [LawId, number][]).filter(([l]) => !lawActive(g, l)).sort((a, b) => b[1] - a[1])[0]?.[0];
}
function placeName(id: string): string {
  return PLACES.find(x => x.id === id)?.name ?? id;
}
const RES_NAME: Record<string, string> = { coal: '석탄', food: '식량', medicine: '의약품', luxury: '사치품', symbol: '상징물' };

/** 난수 없이 정해지는 값. 정할 수 없으면 undefined. person·person2와 community any는 여기서 안 다룬다. */
function fixedValue(g: Game, name: Placeholder, bind: string | undefined, c: Comm): string | undefined {
  switch (name) {
    case 'captain': return g.captainName ?? '열차장';
    case 'community': {
      if (!bind) return COMM_NAME[c];
      if (isComm(bind)) return COMM_NAME[bind];
      // 칸별 긴장 수치가 S1a엔 없어 열기(fervor)로 어림한다.
      if (bind === 'lowest_relation') return COMM_NAME[[...COMMS].sort((a, b) => g.comms[a].rel - g.comms[b].rel)[0]];
      if (bind === 'highest_tension') return COMM_NAME[[...COMMS].sort((a, b) => g.comms[b].fervor - g.comms[a].fervor || g.comms[a].rel - g.comms[b].rel)[0]];
      return undefined;
    }
    case 'law': {
      const law = !bind ? lastLaw(g) : bind === 'last_repealed' ? lastRepealed(g) : bind.startsWith('law:') ? bind.slice(4) as LawId : undefined;
      return law && LAWS[law] ? LAWS[law].title : undefined;
    }
    case 'place': {
      // 다음 정차는 도착해서야 정해진다(S1a는 노선이 없다). 그래서 이동 중의 기본값·next_stop은 값을 못 댄다.
      const here = g.phase === 'stop' && g.stop ? placeName(g.stop.place) : undefined;
      if (!bind) return here;
      if (bind === 'last_stop') return g.stop ? placeName(g.stop.place) : undefined;
      return undefined;
    }
    case 'car': {
      // 같은 칸이 객차 여럿에 살면(꼬리칸) 카드를 올릴 때 그중 하나를 고른다(bindValues).
      const cars = bind?.startsWith('car:') ? carsOf(bind.slice(4)) : [];
      return cars.length > 0 ? CAR_NAME[cars[0]] : undefined;
    }
    case 'item': {
      if (bind?.startsWith('resource:')) return RES_NAME[bind.slice(9)];
      // last_symbol: S1a는 상징물을 개수로만 센다. 이름 붙은 상징물이 들어오면 연다.
      return undefined;
    }
    case 'n': case 'n2': {
      if (!bind) return undefined;
      const num = numberOf(g, bind);
      return num === undefined ? undefined : String(num);
    }
    default: return undefined;
  }
}

function carsOf(comm: string): string[] {
  return Object.keys(CAR_COMM).filter(car => CAR_COMM[car] === comm && CAR_NAME[car]);
}

function numberOf(g: Game, bind: string): number | undefined {
  if (bind === 'food_shortfall') return Math.max(0, Math.round(COMMS.reduce((s, c) => s + g.comms[c].pop * g.comms[c].ration, 0) * P.foodPerPersonLever - g.food));
  if (bind === 'coal_left') return Math.round(g.coal);
  if (bind === 'food_left') return Math.round(g.food);
  if (bind === 'dead_last_segment') return (g.deathLog ?? []).filter(d => d.seg === g.seg - 1).length;
  if (bind === 'injured') return g.injured;
  if (bind === 'away') return COMMS.reduce((s, c) => s + g.comms[c].away, 0);
  if (bind.startsWith('pop:') && isComm(bind.slice(4))) return g.comms[bind.slice(4) as Comm].pop;
  return undefined;
}

/** 이 사건에 지금 값을 다 댈 수 있나(난수 없음). 말하는 칸이 any면 어느 칸이든 하나 되면 된다. */
function canBind(g: Game, ev: ContentEvent): boolean {
  if (ev.speaker === 'faction_leader') return false; // 세력은 S1b 몫(6.9)
  if (!effectsReady(ev)) return false;
  const anyComm = ev.community === 'any' && !isComm(ev.speaker);
  return (anyComm ? [...COMMS] : [speakerComm(ev) ?? 'tail']).some(c => bindsIn(g, ev, c));
}

/** 말하는 칸을 c로 두고 값을 다 댈 수 있나. */
function bindsIn(g: Game, ev: ContentEvent, c: Comm): boolean {
  const params = ev.params ?? [];
  const bind = ev.bind ?? {};
  const wantsPerson = params.includes('person') || params.includes('person2');
  const first = wantsPerson ? personPool(g, ev, c, bind.person, []) : [];
  if (wantsPerson && first.length === 0) return false;
  // person2는 person과 다른 사람이다. person 후보가 둘 이상이면 하나를 person2 쪽에서 빼도 남는지 본다.
  if (params.includes('person2') && !first.some(a => personPool(g, ev, c, bind.person2, [a]).length > 0)) return false;
  if (ev.speaker === 'aide' && people(g, c).length === 0) return false;
  // 비밀을 쥐는 사람: person이 있으면 그 사람, 없으면 말하는 칸의 대표. 열차장·부관·배급장이 말하는 사건은 person이 있어야 한다.
  if (hasEffect(ev, 'secret') && !wantsPerson && !speakerComm(ev) && ev.community !== 'any') return false;
  return params.filter(p => p !== 'person' && p !== 'person2').every(p => fixedValue(g, p, bind[p], c) !== undefined);
}

function hasEffect(ev: ContentEvent, type: ContentEffect['type']): boolean {
  return ev.choices.some(ch => ch.effects.some(e => e.type === type));
}

/** 비밀·거래는 그 정의(data/secrets, data/deals)가 들어와 있어야 뽑는다. */
function effectsReady(ev: ContentEvent): boolean {
  return ev.choices.every(ch => ch.effects.every(e =>
    e.type === 'secret' ? CONTENT_SECRETS.some(x => x.id === e.id)
      : e.type === 'deal' ? CONTENT_DEALS.some(x => x.id === e.id)
        : true));
}

/** 카드를 올릴 때 값을 정한다(난수 사용). */
function bindValues(g: Game, ev: ContentEvent, c: Comm): Record<string, string> {
  const params = ev.params ?? [];
  const bind = ev.bind ?? {};
  const vals: Record<string, string> = {};
  if (params.includes('person') || params.includes('person2')) {
    const pool = personPool(g, ev, c, bind.person, []);
    // person2를 댈 수 있는 사람만 person으로 고른다.
    const ok = params.includes('person2') ? pool.filter(a => personPool(g, ev, c, bind.person2, [a]).length > 0) : pool;
    vals.person = pick(g, ok);
  }
  if (params.includes('person2')) vals.person2 = pick(g, personPool(g, ev, c, bind.person2, [vals.person]));
  for (const p of params) if (p !== 'person' && p !== 'person2') vals[p] = fixedValue(g, p, bind[p], c) ?? '';
  if (params.includes('car') && bind.car?.startsWith('car:')) vals.car = CAR_NAME[pick(g, carsOf(bind.car.slice(4)))];
  if (ev.speaker === 'aide') vals['@aide'] = pick(g, people(g, c).map(p => p.name));
  return vals;
}

function stageOpen(g: Game, ev: ContentEvent): boolean {
  return ev.stage === 's1a' || (ev.stage === 's1c' && !!g.dom);
}

/** 이동 단계에서 뽑을 수 있는 콘텐츠 사건. 같은 사건은 쿨다운·사슬 한도·repeat를 지킨다. */
export function contentPool(g: Game, phase: ContentEvent['phase'] = 'travel'): ContentEvent[] {
  return CONTENT_EVENTS.filter(ev => {
    if (ev.phase !== phase || !stageOpen(g, ev)) return false;
    const m = memo(g, `content:${ev.id}`);
    if (m && (m.n > ev.repeat || m.n >= EVENT_CHAIN_MAX || g.seg - m.seg < EVENT_COOLDOWN)) return false;
    return ev.trigger.every(c => holds(g, c)) && canBind(g, ev);
  });
}

/** 사건을 카드로 올린다. 자리표시자 값은 이때 정해 카드에 붙인다. 값을 못 대면 올리지 않는다. */
export function addContentCard(g: Game, id: string, front = false): boolean {
  const ev = CONTENT_EVENTS.find(e => e.id === id);
  if (!ev || !canBind(g, ev)) return false;
  let c = speakerComm(ev) ?? 'tail';
  if (ev.community === 'any' && !isComm(ev.speaker)) {
    const ok = COMMS.filter(o => canBind(g, { ...ev, community: o }));
    c = pick(g, ok);
  }
  const vals = bindValues(g, ev, c);
  const card: Omit<Card, 'uid'> = { kind: CONTENT_CARD_KIND, text: id, comm: c, vals };
  if (front) { g.cards.unshift({ uid: g.nextCardUid, ...card }); g.nextCardUid += 1; } else addCard(g, card);
  return true;
}

// ---- 효과 ----
const RES: Record<string, 'coal' | 'food' | 'med' | 'lux'> = { coal: 'coal', food: 'food', medicine: 'med', luxury: 'lux' };
const BASE: Record<string, 0 | 1 | 2 | 3> = { 'community.warmth': 0, 'community.ration': 1, 'community.crowding': 2, 'community.exposure': 3 };
const isComm = (x: string): x is Comm => (COMMS as readonly string[]).includes(x);

/** 카드의 비용·정치 줄에 보이는 효과(Eff)로 옮길 수 있는 것만. 나머지는 고른 뒤 applyRest가 한다. */
function toEffs(list: ContentEffect[]): Eff[] {
  const out: Eff[] = [];
  for (const e of list) {
    if (e.type in RES) out.push({ t: RES[e.type], v: (e as { amount: number }).amount });
    else if (e.type in BASE && 'target' in e && isComm(e.target)) out.push({ t: 'base', c: e.target, i: BASE[e.type], v: (e as { amount: number }).amount });
    else if (e.type === 'trust' || e.type === 'tension' || e.type === 'fear') out.push({ t: e.type, v: e.amount });
    else if (e.type === 'relation' && isComm(e.target)) out.push({ t: 'rel', c: e.target, v: e.amount });
  }
  return out;
}

/** 효과가 걸린 자리: 누가 말했고 값이 무엇이었나(비밀을 쥔 사람, 일대기의 누가·목격자). */
interface EffectCtx { from: string; comm: Comm; vals: Record<string, string>; speaker: string; witnesses: string[] }

function applyRest(g: Game, list: ContentEffect[], ctx: EffectCtx): void {
  const flags = flagsOf(g);
  for (const e of list) {
    switch (e.type) {
      case 'symbol': g.symbols = Math.max(0, g.symbols + e.amount); break;
      case 'cohesion': if (isComm(e.target)) g.comms[e.target].coh = clamp(g.comms[e.target].coh + e.amount, 0, 1); break;
      case 'flag': flags[e.id] = e.value; break;
      case 'followup': queue(g, e.id, e.delay); break;
      case 'person.state': setPerson(g, e.target, e.state); break;
      case 'person.away': (g.contentAway ??= {})[e.target] = g.seg + e.segments; break;
      case 'secret': gainSecret(g, e.id, e.amount, ctx); break;
      case 'votes': {
        // 다음 표결 한 번에만 그 칸의 표가 옮긴다. 결속도를 걸지 않는다(politics.ts blocs). 쪽은 표결 때 정한다.
        if (!isComm(e.target)) break;
        const shift = (g.voteShift ??= []).find(v => v.comm === e.target && v.side === (e.side ?? 'captain'));
        if (shift) shift.n += e.amount; else g.voteShift.push({ comm: e.target, n: e.amount, side: e.side ?? 'captain' });
        break;
      }
      case 'deal': addDealCard(g, e.id, ctx.comm); break;
      case 'chronicle':
        (g.chronicle ??= []).push({
          template: e.id, who: ctx.vals.person ?? ctx.speaker, where: g.phase === 'stop' && g.stop ? g.stop.place : '', when: g.seg,
          witnesses: ctx.witnesses, from: ctx.from,
        });
        break;
      default: break;
    }
  }
}

/** 비밀을 손에 넣는다(6.9). 단계는 1 소문·2 증거로, 정의의 proof가 기본이고 효과의 amount가 더 높으면 그쪽이다.
 * 이미 가진 비밀이면 높은 단계로만 오른다. 협박에 쓸 수 있게 S1a 비밀(g.secrets)에도 올린다: 쥔 사람의 칸을 누르는 재료이고,
 * 무게는 정의의 severity(1~3)다. 소문·증거 단계는 무게와 따로 센다(s1a 3.4, 7장). */
function gainSecret(g: Game, id: string, amount: number, ctx: EffectCtx): void {
  const def = CONTENT_SECRETS.find(x => x.id === id);
  if (!def) return;
  const level: 1 | 2 = amount >= 2 || def.proof === 'evidence' ? 2 : 1;
  const who = ctx.vals.person ?? g.comms[ctx.comm].leader.name;
  const comm = PROFILES.find(p => p.name === who)?.community ?? ctx.comm;
  const had = (g.contentSecrets ??= {})[id];
  if (had && had.level >= level) return;
  g.contentSecrets[id] = { level, who, comm };
  const text = fillText(def.text, { person: who });
  const old = g.secrets.find(x => x.cid === id);
  if (old) old.proof = level;
  else { g.secrets.push({ id: g.nextSecretId, text, weight: clamp(Math.round(def.severity), 1, 3), about: comm, uses: 0, cid: id, proof: level }); g.nextSecretId += 1; }
  journal(g, `${level === 2 ? '증거를 쥐었다' : '소문을 들었다'}: ${text}`, 'dark');
}

function queue(g: Game, id: string, delay: number): void {
  if (delay <= 0) addContentCard(g, id, true);
  else (g.contentQueue ??= []).push({ id, at: g.seg + delay });
}

function setPerson(g: Game, id: string, state: 'alive' | 'injured' | 'dead' | 'away'): void {
  const p = PROFILES.find(x => x.id === id);
  if (!p) return;
  if (state === 'dead' && !g.deaths.includes(p.name)) onDeath(g, p.community, [p.name], 'other');
  else if (state === 'injured') { if (!(g.contentInjured ??= []).includes(id)) { g.contentInjured.push(id); g.injured += 1; } }
  else if (state === 'away') (g.contentAway ??= {})[id] = AWAY_FOREVER;
  else if (state === 'alive') { g.contentInjured = (g.contentInjured ?? []).filter(x => x !== id); delete (g.contentAway ?? {})[id]; }
}

/** 구간마다: 돌아올 때가 된 사람을 돌린다. */
export function contentAwayTick(g: Game): void {
  for (const [id, until] of Object.entries(g.contentAway ?? {})) if (until <= g.seg) delete g.contentAway![id];
}

// ---- 거래 조건(6.9 deal) ----
// 받으면 gives가 바로 온다. ask는 기한(구간)이 되면 치른다. 그때 모자라면 breach가 온다. 기한 0이면 받을 때 같이 치른다.

/** 효과 목록을 카드 글 한 줄로. */
export function effectText(list: ContentEffect[]): string {
  const effs = toEffs(list);
  const parts = [...costLines({ label: '', effs }), ...politicsLines({ label: '', effs }).map(x => x.text)];
  for (const e of list) if (e.type === 'symbol') parts.push(`상징물 ${e.amount > 0 ? '+' : '−'}${Math.abs(e.amount)}`);
  return parts.length > 0 ? parts.join(', ') : '없음';
}

function addDealCard(g: Game, id: string, comm: Comm): void {
  const def = CONTENT_DEALS.find(x => x.id === id);
  if (!def) return;
  const c = isComm(def.from) ? def.from : comm;
  g.cards.unshift({ uid: g.nextCardUid, kind: CONTENT_DEAL_KIND, text: id, comm: c });
  g.nextCardUid += 1;
}

function canPay(g: Game, list: ContentEffect[]): boolean {
  if (affordable(g, toEffs(list))) return false;
  return list.every(e => e.type !== 'symbol' || e.amount >= 0 || g.symbols >= -e.amount);
}

function settleDeal(g: Game, d: { id: string; comm: Comm }): void {
  const def = CONTENT_DEALS.find(x => x.id === d.id);
  if (!def) return;
  const ctx: EffectCtx = { from: d.id, comm: d.comm, vals: {}, speaker: g.comms[d.comm].leader.name, witnesses: [] };
  const who = COMM_NAME[d.comm] + josa(COMM_NAME[d.comm], '과/와');
  if (canPay(g, def.ask)) {
    applyEffs(g, toEffs(def.ask));
    applyRest(g, def.ask, ctx);
    journal(g, `${who}의 거래를 치렀다: ${effectText(def.ask)}.`, 'deal');
  } else {
    applyEffs(g, toEffs(def.breach));
    applyRest(g, def.breach, ctx);
    journal(g, `${who}의 거래를 치르지 못했다: ${effectText(def.breach)}.`, 'bad');
  }
}

/** 미뤄 둔 후속 사건 중 때가 된 것을 올리고, 기한이 된 거래를 치른다(구간 시작). */
export function contentFollowupTick(g: Game): void {
  const dueDeals = (g.contentDeals ?? []).filter(d => d.due <= g.seg);
  if (dueDeals.length > 0) {
    g.contentDeals = (g.contentDeals ?? []).filter(d => d.due > g.seg);
    for (const d of dueDeals) settleDeal(g, d);
  }
  const due = (g.contentQueue ?? []).filter(q => q.at <= g.seg);
  if (due.length === 0) return;
  g.contentQueue = (g.contentQueue ?? []).filter(q => q.at > g.seg);
  for (const q of due) addContentCard(g, q.id);
}

// ---- 카드 ----
const SPEAKER_ROLE: Record<string, string> = {
  captain: '열차장', deputy: '부관', ration_officer: '배급장', rep: '대표', aide: '측근', faction_leader: '세력 지도자',
};

function speakerOf(g: Game, ev: ContentEvent, card: Card): { name: string; role: string; comm?: Comm } {
  const c = card.comm;
  if (c && (isComm(ev.speaker) || ev.speaker === 'rep')) return { name: g.comms[c].leader.name, role: REP_ROLE[c], comm: c };
  if (c && ev.speaker === 'aide') return { name: card.vals?.['@aide'] ?? g.comms[c].leader.name, role: `${COMM_NAME[c]} 측근`, comm: c };
  return { name: SPEAKER_ROLE[ev.speaker] ?? ev.speaker, role: '' };
}

function contentView(g: Game, card: Card): CardView | null {
  if (card.kind === CONTENT_DEAL_KIND) return dealView(g, card);
  if (card.kind !== CONTENT_CARD_KIND) return null;
  const ev = CONTENT_EVENTS.find(e => e.id === card.text);
  if (!ev) return { title: '빈 서류', body: `읽을 수 없는 사건: ${card.text ?? ''}`, choices: [{ label: '덮는다', effs: [] }], required: false };
  const vals = (card.vals ?? {}) as Partial<Record<Placeholder, string>>;
  const speaker = speakerOf(g, ev, card);
  const c = speaker.comm;
  const choices: Choice[] = ev.choices.map(ch => ({
    label: fillText(ch.label, vals), ...(ch.say ? { say: fillText(ch.say, vals) } : {}),
    effs: toEffs(ch.effects), special: `content:${ch.id}`, witness: ch.witnesses.length > 0,
  }));
  return {
    title: c ? COMM_NAME[c] : speaker.name, speaker, body: fillText(ev.body, vals), choices: withAfford(g, choices), required: true, key: `content:${ev.id}`,
    ...(c ? { focus: c } : {}),
  };
}

function dealView(g: Game, card: Card): CardView {
  const def = CONTENT_DEALS.find(x => x.id === card.text);
  const c = card.comm ?? 'tail';
  if (!def) return { title: '빈 서류', body: `읽을 수 없는 거래: ${card.text ?? ''}`, choices: [{ label: '덮는다', effs: [] }], required: false };
  const now = def.deadline <= 0;
  const body = [...(def.say ? [def.say] : []), `요구: ${effectText(def.ask)}`, `기한: ${now ? '지금' : `${def.deadline}구간 뒤`}`, `어기면: ${effectText(def.breach)}`].join('. ') + '.';
  const accept = toEffs(def.gives).concat(now ? toEffs(def.ask) : []);
  return {
    title: `${COMM_NAME[c]}의 거래`, speaker: { name: g.comms[c].leader.name, role: REP_ROLE[c], comm: c }, body,
    choices: withAfford(g, [
      { label: '받는다', effs: accept, special: 'content-deal:accept' },
      { label: '거절한다', effs: [], special: 'content-deal:refuse' },
    ]),
    required: true, key: `content-deal:${def.id}`, focus: c,
  };
}

function contentChoose(g: Game, card: Card, choice: Choice): void {
  if (card.kind === CONTENT_DEAL_KIND) {
    const def = CONTENT_DEALS.find(x => x.id === card.text);
    const c = card.comm ?? 'tail';
    if (!def || choice.special !== 'content-deal:accept') return;
    const ctx: EffectCtx = { from: def.id, comm: c, vals: {}, speaker: g.comms[c].leader.name, witnesses: [] };
    applyRest(g, def.gives, ctx);
    if (def.deadline <= 0) applyRest(g, def.ask, ctx);
    else (g.contentDeals ??= []).push({ id: def.id, comm: c, due: g.seg + def.deadline });
    return;
  }
  if (card.kind !== CONTENT_CARD_KIND || !choice.special?.startsWith('content:')) return;
  const ev = CONTENT_EVENTS.find(e => e.id === card.text);
  const ch = ev?.choices.find(x => `content:${x.id}` === choice.special);
  if (!ev || !ch) return;
  const witnesses = ch.witnesses.map(w => (typeof w === 'string' ? w : w.person));
  applyRest(g, ch.effects, { from: `${ev.id}.${ch.id}`, comm: card.comm ?? 'tail', vals: card.vals ?? {}, speaker: speakerOf(g, ev, card).name, witnesses });
  for (const id of ch.followups) queue(g, id, 0);
}

CARD_EXTENSIONS.push({ view: contentView, choose: contentChoose });
