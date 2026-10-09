import { COMMS, COMM_NAME, OPPOSITE } from './data';
import type { Comm } from './data';
import { addCard, clamp, journal } from './state';
import type { Game } from './state';

export interface RumorEntry {
  event: number;
  source: Comm;
  target: Comm;
  remaining: number;
  due: number;
  base: number;
  size: number;
  sentence: 0 | 1 | 2;
  lines: [string, string, string];
}
interface Delivery { target: Comm; excess: number }
export interface RumorState {
  queue: RumorEntry[];
  order: Comm[];
  nextEvent: number;
  lastCardSeg: number;
  blizzardUntil: number;
  delivered: Record<number, Delivery[]>;
  events: Record<number, { source: Comm; lines: [string, string, string] }>;
  config: { adjacentDelay: number; farDelay: number; multiplier: number; cardGap: number };
  stats: { overlaps: number; cards: number; arrivals: number; choices: [number, number, number] };
}

/** 기본 판에는 필드를 추가하지 않는다. JSON 저장·복원 및 cloneGame에 그대로 포함된다. */
export function enableRumor(g: Game, config: Partial<RumorState['config']> = {}): void {
  if (g.rumor) return;
  g.rumor = {
    queue: [], order: [...COMMS].reverse(), nextEvent: 1, lastCardSeg: -100,
    blizzardUntil: -1, delivered: {}, events: {},
    config: { adjacentDelay: 1, farDelay: 2, multiplier: 1.5, cardGap: 4, ...config },
    stats: { overlaps: 0, cards: 0, arrivals: 0, choices: [0, 0, 0] },
  };
}

/** 화물역 재배열/C3를 연결할 때 쓰는 최소 상태 경계. */
export function setRumorOrder(g: Game, order: readonly Comm[]): boolean {
  if (!g.rumor || order.length !== COMMS.length || new Set(order).size !== COMMS.length || order.some(c => !COMMS.includes(c))) return false;
  g.rumor.order = [...order];
  return true;
}
export function setRumorBlizzard(g: Game, segments = 2): void {
  if (g.rumor) g.rumor.blizzardUntil = g.seg + Math.max(1, segments) - 1;
}

export function rumorLines(source: Comm, fact = '열차장 결정'): [string, string, string] {
  const name = COMM_NAME[source];
  return [`${name} 대표가 '${fact}'를 두고 입장을 밝혔다.`, `${name} 대표는 '${fact}' 때문에 칸의 사정까지 바뀌었다더라.`, `${name} 대표는 열차장이 다음 일도 마음대로 정할 거래.`];
}

function inBlizzard(g: Game): boolean { return !!g.rumor && g.seg <= g.rumor.blizzardUntil; }

/** 실제 사건의 기존 칸별 변화만 운반한다. 건너갈 때 한 번만 부풀린다. */
export function spreadRumor(g: Game, source: Comm, deltas: Partial<Record<Comm, number>>, lines = rumorLines(source)): void {
  const r = g.rumor;
  if (!r) return;
  if (!COMMS.some(c => (deltas[c] ?? 0) !== 0)) return;
  const event = r.nextEvent++;
  r.events[event] = { source, lines };
  for (const target of r.order) {
    const base = deltas[target];
    if (base === undefined || base === 0) continue;
    const distance = Math.abs(r.order.indexOf(source) - r.order.indexOf(target));
    const sentence = Math.min(2, distance) as 0 | 1 | 2;
    const remaining = distance === 0 || inBlizzard(g) ? 0 : distance === 1 ? r.config.adjacentDelay : r.config.farDelay;
    const entry: RumorEntry = { event, source, target, base, size: base * (distance === 0 ? 1 : r.config.multiplier), sentence, lines, remaining, due: g.seg + remaining };
    // 일이 난 칸은 이미 사실을 안다. 대기 소문과 경쟁하지 않고 바로 반응한다.
    if (target === source) { arrive(g, entry); continue; }
    // 같은 칸의 대기·동시 도착만 겹침이다. 이미 지난 사건은 경쟁하지 않는다.
    const prior = r.queue.find(q => q.target === target);
    if (prior) {
      r.stats.overlaps++;
      journal(g, `${COMM_NAME[target]}의 소문이 겹쳤다. 큰 관계 변화 하나를 남겼다.`);
      if (Math.abs(prior.size) >= Math.abs(entry.size)) continue;
      r.queue = r.queue.filter(q => q !== prior);
    }
    if (remaining === 0 && !inBlizzard(g)) arrive(g, entry);
    else r.queue.push(entry);
  }
}

function arrive(g: Game, entry: RumorEntry): void {
  const r = g.rumor!;
  const before = g.comms[entry.target].rel;
  g.comms[entry.target].rel = clamp(before + entry.size, -100, 100);
  const excess = g.comms[entry.target].rel - clamp(before + entry.base, -100, 100);
  (r.delivered[entry.event] ??= []).push({ target: entry.target, excess });
  r.stats.arrivals++;
  journal(g, `${COMM_NAME[entry.target]}에 소문이 닿았다: '${entry.lines[entry.sentence]}' (관계 ${entry.size >= 0 ? '+' : ''}${entry.size}).`);
  if (entry.target === OPPOSITE[entry.source] && Math.abs(entry.size) >= 5 && g.seg - r.lastCardSeg >= r.config.cardGap) {
    addCard(g, { kind: 'rumor', comm: entry.target, n: entry.event, text: entry.lines[entry.sentence] });
    r.lastCardSeg = g.seg;
    r.stats.cards++;
  }
}

/** due는 발생 구간 기준이다. 발생 구간 정산에서 1/2를 미리 깎지 않는다. */
export function rumorSettle(g: Game): void {
  const r = g.rumor;
  if (!r) return;
  const ready: RumorEntry[] = [];
  r.queue = r.queue.filter(q => {
    q.remaining = inBlizzard(g) ? 0 : Math.max(0, q.due - g.seg);
    if (q.remaining === 0) { ready.push(q); return false; }
    return true;
  });
  for (const q of ready) arrive(g, q);
}

export function resolveRumor(g: Game, event: number, choice: number): boolean {
  const r = g.rumor;
  const e = r?.events[event];
  if (!r || !e || choice < 0 || choice > 2 || !Number.isInteger(choice)) return false;
  r.stats.choices[choice]++;
  if (choice === 0 && g.trust >= 50) {
    r.queue = r.queue.filter(q => q.event !== event);
    for (const d of r.delivered[event] ?? []) g.comms[d.target].rel = clamp(g.comms[d.target].rel - d.excess, -100, 100);
    journal(g, `열차장이 사실을 붙였다: '${e.lines[0]}' 소문이 멈추고 부풀림을 거뒀다.`);
  } else if (choice === 0) {
    g.trust = clamp(g.trust - 2, 0, 100);
    journal(g, '대표의 해명 뒤 새 소문이 돌았다: 열차장이 감춘다. (신임 −2)');
    // 별도 관계 벌점은 브리프에 없으므로 새 소문은 문장만 운반한다.
    const lines: [string, string, string] = ['대표가 열차장의 해명을 옮겼다.', '열차장이 감춘다더라.', '열차장이 다음 결정도 감출 거래.'];
    const newEvent = r.nextEvent++;
    r.events[newEvent] = { source: e.source, lines };
    for (const target of r.order) {
      const distance = Math.abs(r.order.indexOf(target) - r.order.indexOf(e.source));
      const remaining = inBlizzard(g) || distance === 0 ? 0 : distance === 1 ? r.config.adjacentDelay : r.config.farDelay;
      const q: RumorEntry = { event: newEvent, source: e.source, target, remaining, due: g.seg + remaining, base: 0, size: 0, sentence: Math.min(2, distance) as 0 | 1 | 2, lines };
      // 관계 대기열의 '큰 것 하나' 규칙을 무효화하지 않는 일지 전용 후속.
      if (!r.queue.some(p => p.target === target)) r.queue.push(q);
    }
  } else if (choice === 1) {
    r.queue = r.queue.filter(q => q.event !== event);
    g.comms[e.source].grudge++;
    g.fear = clamp(g.fear + 3, 0, 100);
    journal(g, `${COMM_NAME[e.source]} 대표에게 입단속을 시켰다. 소문이 멈췄다. 원한 +1, 공포 +3.`);
  } else journal(g, '열차장이 소문을 내버려 뒀다.');
  return true;
}

const active = new WeakSet<Game>();
/** 사건 함수의 관계 변화 묶음을 포착한다. 중첩 사건은 바깥 사건에 한 번만 포함한다. */
export function rumorEvent<T>(g: Game, source: Comm | undefined, action: () => T, fact?: string): T {
  if (!g.rumor || active.has(g)) return action();
  const before = Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel])) as Record<Comm, number>;
  active.add(g);
  let result: T;
  try { result = action(); } finally { active.delete(g); }
  const deltas = Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel - before[c]])) as Record<Comm, number>;
  for (const c of COMMS) g.comms[c].rel = before[c];
  const origin = source ?? [...g.rumor.order].sort((a, b) => Math.abs(deltas[b]) - Math.abs(deltas[a]))[0];
  spreadRumor(g, origin, deltas, rumorLines(origin, fact));
  return result;
}
