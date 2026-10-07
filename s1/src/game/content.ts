import { COMMS, COMM_NAME, LAWS, PLACES, REP_ROLE } from './data';
import type { Comm, LawId } from './data';
import { CARD_EXTENSIONS, EVENT_CHAIN_MAX, EVENT_COOLDOWN, memo } from './cards';
import type { CardView, Choice, Eff } from './cards';
import { onDeath } from './death';
import { addCard, clamp, drawPerson, isGone, PROFILES, situation } from './state';
import type { Card, Game } from './state';

// 콘텐츠 JSON 사건(s1_content_guide 6장, 이야기 스레드 6c0fd2b): Gemini로 새로 쓰는 사건은 처음부터 JSON(event.schema.json)에 넣고
// 게임은 여기서 읽는다. 지금 TS 안에 있는 사건(cards.ts TRAVEL_EVENTS)은 그대로 두고 S3에서 키로 뺀다.
// 데이터는 npm run validate를 통과한 것만 들어온다고 본다(tests/game/content.test.ts가 data/events를 검사한다).
// 지금 읽는 것: 이동(travel) 단계 사건, 단계 s1a(내정 켠 판이면 s1c도). 정차·회기·정산 단계와 s1b는 아직 안 뽑는다.

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
  | { type: 'relation' | 'cohesion' | 'votes'; target: string; amount: number }
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
}

/** 읽어 들인 사건. 브라우저는 main.ts가 data/events를, 도구는 tools/content_fs.ts가 디스크에서 채운다. */
export const CONTENT_EVENTS: ContentEvent[] = [];

export function registerContentEvents(list: unknown[]): void {
  for (const raw of list) {
    const ev = raw as ContentEvent;
    if (!ev || typeof ev.id !== 'string' || !Array.isArray(ev.choices)) continue;
    const at = CONTENT_EVENTS.findIndex(e => e.id === ev.id);
    if (at >= 0) CONTENT_EVENTS[at] = ev; else CONTENT_EVENTS.push(ev);
  }
}

export const CONTENT_CARD_KIND = 'content';
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

function speakerComm(ev: ContentEvent): Comm | undefined {
  return (COMMS as readonly string[]).includes(ev.speaker) ? ev.speaker as Comm : undefined;
}

/** 값을 댈 수 있는 자리표시자. car·item·n·n2는 어디서 값을 가져올지 아직 정하지 않았다(이야기 스레드에 물음). */
function bindable(g: Game, name: Placeholder): boolean {
  if (name === 'law') return lastLaw(g) !== undefined;
  if (name === 'place') return !!g.stop;
  return name === 'person' || name === 'person2' || name === 'captain' || name === 'community';
}

function lastLaw(g: Game): LawId | undefined {
  return (Object.entries(g.passed) as [LawId, number][]).sort((a, b) => b[1] - a[1])[0]?.[0];
}

function stageOpen(g: Game, ev: ContentEvent): boolean {
  return ev.stage === 's1a' || (ev.stage === 's1c' && !!g.dom);
}

/** 이동 단계에서 뽑을 수 있는 콘텐츠 사건. 같은 사건은 쿨다운·사슬 한도·repeat를 지킨다. */
export function contentPool(g: Game, phase: ContentEvent['phase'] = 'travel'): ContentEvent[] {
  return CONTENT_EVENTS.filter(ev => {
    if (ev.phase !== phase || !stageOpen(g, ev)) return false;
    if (!(ev.params ?? []).every(p => bindable(g, p))) return false;
    const m = memo(g, `content:${ev.id}`);
    if (m && (m.n > ev.repeat || m.n >= EVENT_CHAIN_MAX || g.seg - m.seg < EVENT_COOLDOWN)) return false;
    return ev.trigger.every(c => holds(g, c));
  });
}

/** 사건을 카드로 올린다. 사람 자리표시자는 이때 정해 카드에 붙인다(다시 그려도 같은 사람). */
export function addContentCard(g: Game, id: string, front = false): boolean {
  const ev = CONTENT_EVENTS.find(e => e.id === id);
  if (!ev) return false;
  const c = speakerComm(ev) ?? 'tail';
  const names: string[] = [];
  const params = ev.params ?? [];
  if (params.includes('person') || params.includes('person2')) names.push(drawPerson(g, c).name);
  if (params.includes('person2')) names.push(drawPerson(g, c).name);
  const card: Omit<Card, 'uid'> = { kind: CONTENT_CARD_KIND, text: id, comm: c, ...(names.length ? { names } : {}) };
  if (front) { g.cards.unshift({ uid: g.nextCardUid, ...card }); g.nextCardUid += 1; } else addCard(g, card);
  return true;
}

/** 미뤄 둔 후속 사건 중 때가 된 것을 올린다(구간 시작). */
export function contentFollowupTick(g: Game): void {
  const due = (g.contentQueue ?? []).filter(q => q.at <= g.seg);
  if (due.length === 0) return;
  g.contentQueue = (g.contentQueue ?? []).filter(q => q.at > g.seg);
  for (const q of due) addContentCard(g, q.id);
}

function values(g: Game, card: Card, ev: ContentEvent): Partial<Record<Placeholder, string>> {
  const c = speakerComm(ev) ?? card.comm ?? 'tail';
  const law = lastLaw(g);
  return {
    person: card.names?.[0], person2: card.names?.[1], captain: '열차장', community: COMM_NAME[c],
    ...(law ? { law: LAWS[law].title } : {}), ...(g.stop ? { place: PLACES.find(x => x.id === g.stop?.place)?.name ?? g.stop.place } : {}),
  };
}

const SPEAKER_ROLE: Record<string, string> = {
  captain: '열차장', deputy: '부관', ration_officer: '배급장', rep: '대표', aide: '측근', faction_leader: '세력 지도자',
};

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

function applyRest(g: Game, ev: ContentEvent, ch: ContentChoice, card: Card): void {
  const flags = flagsOf(g);
  for (const e of ch.effects) {
    switch (e.type) {
      case 'symbol': g.symbols = Math.max(0, g.symbols + e.amount); break;
      case 'cohesion': if (isComm(e.target)) g.comms[e.target].coh = clamp(g.comms[e.target].coh + e.amount, 0, 1); break;
      case 'flag': flags[e.id] = e.value; break;
      case 'followup': queue(g, e.id, e.delay); break;
      case 'person.state': setPerson(g, e.target, e.state); break;
      case 'person.away': (g.contentAway ??= {})[e.target] = g.seg + e.segments; break;
      // 뜻이 아직 덜 정해진 어휘(비밀 쪽지, 표, 거래, 연대기)는 아직 아무것도 안 한다. 무엇을 했어야 하는지만 판에 적어 둔다
      // (플레이어에겐 안 보이고 재현 묶음에 실린다). 이야기 스레드에 뜻을 물었다.
      case 'secret': case 'votes': case 'deal': case 'chronicle':
        g.contentPending = [...(g.contentPending ?? []), `${ev.id}.${ch.id}:${e.type}`].slice(-20);
        break;
      default: break;
    }
  }
  for (const id of ch.followups) queue(g, id, 0);
  void card;
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

// ---- 카드 ----
function contentView(g: Game, card: Card): CardView | null {
  if (card.kind !== CONTENT_CARD_KIND) return null;
  const ev = CONTENT_EVENTS.find(e => e.id === card.text);
  if (!ev) return { title: '빈 서류', body: `읽을 수 없는 사건: ${card.text ?? ''}`, choices: [{ label: '덮는다', effs: [] }], required: false };
  const vals = values(g, card, ev);
  const c = speakerComm(ev);
  const speaker = c ? { name: g.comms[c].leader.name, role: REP_ROLE[c], comm: c } : { name: SPEAKER_ROLE[ev.speaker] ?? ev.speaker, role: '' };
  const choices: Choice[] = ev.choices.map(ch => ({
    label: fillText(ch.label, vals), ...(ch.say ? { say: fillText(ch.say, vals) } : {}),
    effs: toEffs(ch.effects), special: `content:${ch.id}`, witness: ch.witnesses.length > 0,
  }));
  return {
    title: c ? COMM_NAME[c] : speaker.name, speaker, body: fillText(ev.body, vals), choices, required: true, key: `content:${ev.id}`,
    ...(c ? { focus: c } : {}),
  };
}

function contentChoose(g: Game, card: Card, choice: Choice): void {
  if (card.kind !== CONTENT_CARD_KIND || !choice.special?.startsWith('content:')) return;
  const ev = CONTENT_EVENTS.find(e => e.id === card.text);
  const ch = ev?.choices.find(x => `content:${x.id}` === choice.special);
  if (ev && ch) applyRest(g, ev, ch, card);
}

CARD_EXTENSIONS.push({ view: contentView, choose: contentChoose });
