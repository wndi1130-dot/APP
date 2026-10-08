import {
  COMMON_CONDITIONS, CONDITIONS, CORPSE_LAWS, COMMS, COMM_NAME, FETCH_WANT, IDEO, LAWS, LAW_IDS, LAW_VARIANT_OF, OPPOSITE, P,
} from './data';
import type { Comm, ConditionDef, Crisis, LawId } from './data';
import { josa } from './josa';
import { needOf } from './needs';
import { mourners } from './people';
import { domesticLawOpen } from './domestic/laws';
import { refreshSit } from './domestic/sit';
import { MOTIONS, motionsNow } from './motions';
import { addSecret, clamp, journal, lawActive, rnd, seats, situation, stageOf } from './state';
import type { Agenda, CouncilState, Deal, DealTool, Game, LawAgenda, MotionAgenda, VoteFlip, VoteResult } from './state';

// 의회: 입장 점수, 찬성·반대·미정, 거래 다섯, 개표, 폐지(브리프 1.3, 3장, 8.4).

export interface Bloc {
  seats: number;
  absent: number;
  yes: number;
  und: number;
  no: number;
  /** 뇌물·빚으로 대표가 끌고 오는 표. 개표 때 결속도만큼 찬성으로 온다. */
  pool: number;
  poolChance: number;
  score: number;
  ideo: number;
}

export function lawNeed(law: LawId): number {
  return LAWS[law].kind === 'rule' ? 67 : 51;
}

export function isLawAgenda(a: Agenda): a is LawAgenda {
  return a.kind !== 'motion';
}

export function agendaNeed(a: Agenda): number {
  return isLawAgenda(a) ? lawNeed(a.law) : MOTIONS[a.motion].need;
}

/** 같은 안건인가(AI 발의와 지금 안건을 맞춰 볼 때) */
export function sameAgenda(a: Agenda, b: Agenda): boolean {
  if (isLawAgenda(a) && isLawAgenda(b)) return a.law === b.law && a.repeal === b.repeal;
  if (!isLawAgenda(a) && !isLawAgenda(b)) return a.motion === b.motion && a.subject === b.subject && a.person === b.person;
  return false;
}

/** 법이 아닌 안건의 물질·이념 몫(motions.ts). */
function motionLean(g: Game, c: Comm, a: MotionAgenda): { mat: number; ideo: number } {
  return MOTIONS[a.motion].lean(g, c, a);
}

/** 입장 = 물질 + 이념 + 관계(브리프 1.3). 폐지는 물질과 이념의 부호를 뒤집는다. 적의는 열차장의 안건에만 건다. */
export function stance(g: Game, c: Comm, agenda: Agenda, withGrudge = true): { score: number; ideo: number; mat: number } {
  let mat = 0;
  let ideo = 0;
  if (!isLawAgenda(agenda)) {
    ({ mat, ideo } = motionLean(g, c, agenda));
  } else {
    const law = LAWS[agenda.law];
    mat = law.like[c] ?? 0;
    const m = law.mats[c];
    if (m) {
      const gain = m[0] + m[1] - m[2] - m[3];
      mat += gain >= 15 ? 2 : gain >= 5 ? 1 : gain <= -15 ? -2 : gain <= -5 ? -1 : 0;
    }
    const r = law.rels[c];
    if (r !== undefined) mat += r <= -15 ? -2 : r < 0 ? -1 : r >= 10 ? 1 : 0;
    ideo = law.axes.reduce((sum, a, i) => sum + a * IDEO[c][i], 0);
    if (agenda.repeal) {
      mat = -mat;
      ideo = -ideo;
    }
  }
  // 대신 나온 측근은 처지 입장에 1.5배 무게를 둔다(사람의 무게 A2).
  // 반올림을 부호 밖에서 해 찬반이 대칭이다(±1 → ±2).
  if (g.comms[c].sick) mat = Math.sign(mat) * Math.round(Math.abs(mat) * 1.5);
  let score = mat + ideo + stageOf(g.comms[c].rel).band;
  const grudge = g.comms[c].grudge;
  // 적대 표(3.7): 열차장이 올린 안건엔 사상이 같아도 반대하고, 열차장이 막으려는 안건(AI 발의)엔 기운다.
  if (withGrudge && grudge >= P.hostileGrudge) score = agenda.by ? Math.max(score, 3) : Math.min(score, -3);
  else if (withGrudge && grudge >= 1 && !agenda.by) score -= 1;
  return { score, ideo, mat };
}

export function split(score: number): [number, number, number] {
  if (score >= 3) return [0.8, 0.2, 0];
  if (score >= 1) return [0.4, 0.5, 0.1];
  if (score === 0) return [0.1, 0.8, 0.1];
  if (score >= -2) return [0.1, 0.5, 0.4];
  return [0, 0.2, 0.8];
}

export function undecidedChance(score: number): number {
  return clamp(0.5 + 0.1 * score, 0.2, 0.8);
}

function baseBloc(g: Game, c: Comm, agenda: Agenda, seatCount: number): Bloc {
  const { score, ideo } = stance(g, c, agenda);
  const s = g.comms[c];
  // 그 정차에 나갔던 사람과 상중인 사람은 회기에 빠진다. 나갔던 사람은 돌아와 언 몸을 녹이고 쓰러져 잔다(triage N3).
  const away = s.away + mourners(g, c).length;
  const absent = s.pop > 0 ? Math.min(seatCount, Math.round((seatCount * away) / s.pop)) : 0;
  const present = seatCount - absent;
  const [y, , n] = split(score);
  const yes = Math.round(present * y);
  const no = Math.round(present * n);
  return { seats: seatCount, absent, yes, und: present - yes - no, no, pool: 0, poolChance: 0, score, ideo };
}

/** 표를 움직이는 거래인가. 거절당한 뇌물은 자리만 쓰고 표는 못 움직인다(옛 저장은 글로 가린다). */
export function dealHolds(d: Deal): boolean {
  return !d.refused && d.label !== '뇌물을 거절당함';
}

/** 거래를 반영한 지금의 쐐기. */
export function blocs(g: Game, agenda: Agenda, deals: readonly Deal[] = []): Record<Comm, Bloc> {
  const seatMap = seats(g);
  const out = {} as Record<Comm, Bloc>;
  for (const c of COMMS) {
    const b = baseBloc(g, c, agenda, seatMap[c]);
    if (lawActive(g, 'guided_voting') && g.guidedLeft > 0) {
      const moved = Math.round(b.und * 0.3);
      b.yes += moved;
      b.und -= moved;
    }
    for (const deal of deals.filter(d => d.comm === c && dealHolds(d))) applyDeal(g, b, c, deal.tool);
    for (const v of g.voteShift ?? []) if (v.comm === c) shiftVotes(b, v.n * voteSide(agenda, v.side));
    out[c] = b;
  }
  return out;
}

/** 콘텐츠 사건의 votes 쪽(6.9): 찬성 1, 반대 −1. captain은 열차장이 밝힌 편인데, S1a에서 열차장이 편을 밝히는 건
 * 자기가 올린 안건(찬성)뿐이다. AI가 올린 안건이면 밝힌 편이 없어 0(효과 없음). */
export function voteSide(agenda: Agenda, side: 'captain' | 'yes' | 'no'): number {
  if (side === 'yes') return 1;
  if (side === 'no') return -1;
  return agenda.by ? 0 : 1;
}

/** 그 칸 표가 n석만큼 찬성 쪽으로(음수면 반대 쪽으로) 옮긴다. 찬성 쪽이면 반대 → 미정 순으로 빼 온다. */
function shiftVotes(b: Bloc, n: number): void {
  let left = Math.abs(Math.round(n));
  const from: ('no' | 'und' | 'yes')[] = n > 0 ? ['no', 'und'] : ['yes', 'und'];
  for (const k of from) {
    const take = Math.min(left, b[k]);
    b[k] -= take;
    if (n > 0) b.yes += take; else b.no += take;
    left -= take;
  }
}

function applyDeal(g: Game, b: Bloc, c: Comm, tool: DealTool): void {
  if (tool === 'open' || tool === 'fetch') {
    // 공개 약속은 새지 않는다(원작). 미정 전부와 반대의 20%.
    const moved = Math.round(b.no * 0.2);
    b.yes += b.und + moved;
    b.no -= moved;
    b.und = 0;
  } else if (tool === 'blackmail') {
    // 협박은 대표가 집단을 통째로 끌고 온다(3.1, 결속도 1.0).
    b.yes += b.und + b.no;
    b.und = 0;
    b.no = 0;
  } else {
    // 뇌물과 빚: 대표 몫. 남은 표가 결속도만큼 찬성으로 온다.
    b.pool += b.und + b.no;
    b.poolChance = g.comms[c].coh;
    b.und = 0;
    b.no = 0;
  }
}

export function expected(map: Record<Comm, Bloc>): { mean: number; min: number; max: number } {
  let mean = 0;
  let min = 0;
  let max = 0;
  for (const c of COMMS) {
    const b = map[c];
    mean += b.yes + b.und * undecidedChance(b.score) + b.pool * b.poolChance;
    min += b.yes;
    max += b.yes + b.und + b.pool;
  }
  return { mean, min, max };
}

// ---- 안건 ----
export function crisisNow(g: Game): Crisis[] {
  const out: Crisis[] = [];
  if (g.coal < P.crisisLine) out.push('coal');
  if (g.food < P.crisisLine) out.push('food');
  if (g.corpseIssue) out.push('corpse');
  if (g.med <= 3 && g.injured >= 4) out.push('med');
  return out;
}

export function lawOpen(g: Game, law: LawId): boolean {
  // S1c 법과 S1c가 바꾸는 법(중환자 분류)은 domestic/laws.ts가 정한다. S1a 판에선 S1c 법이 닫혀 있다.
  const dom = domesticLawOpen(g, law);
  if (dom !== null) return dom;
  const sit = (c: Comm) => situation(g, c);
  switch (law) {
    case 'seed_grain': return g.food <= 50;
    case 'common_heating': return sit('tail')[0] <= 40;
    case 'heat_quota': return g.coal <= 50;
    case 'child_labor': return g.coal <= 40 || g.food <= 40;
    case 'corpse_throw': case 'corpse_store': case 'corpse_burn': return g.corpseIssue;
    case 'triage': return g.med <= 5 || g.injured >= 6;
    case 'no_outsiders': return sit('tail')[2] >= 75;
    case 'patrol': return g.tension >= 40;
    case 'emergency_powers': return g.tension >= 50 || g.trust <= 10 || g.trustCrisis !== null;
    case 'strike_ban': return g.strikes > 0;
    case 'guided_voting': return g.session >= 3;
    default: return true;
  }
}

/** 법이 먹는 자원. 위기 때 그 법의 폐지가 안건이 될 수 있다. */
export function drains(law: LawId): Crisis[] {
  const r = LAWS[law].res;
  const out: Crisis[] = [];
  if (r.rationFloor) out.push('food');
  if (r.heatFloor) out.push('coal');
  if ((r.medMult ?? 1) > 1) out.push('med');
  return out;
}

export function agendaOptions(g: Game): { options: Agenda[]; forced: boolean } {
  const options: LawAgenda[] = [];
  const corpseSet = CORPSE_LAWS.some(l => lawActive(g, l));
  for (const law of LAW_IDS) {
    if (lawActive(g, law) || !lawOpen(g, law)) continue;
    if (CORPSE_LAWS.includes(law) && corpseSet) continue;
    if (g.session - (g.repealedAt[law] ?? -99) <= P.repealCool) continue;
    const base = LAW_VARIANT_OF[law];
    options.push(base && lawActive(g, base) ? { law, repeal: false, amend: base } : { law, repeal: false });
  }
  for (const law of LAW_IDS) {
    const at = g.passed[law];
    if (at !== undefined && g.session - at >= P.repealCool) options.push({ law, repeal: true });
  }
  // 대권이 끝난 포고의 추인을 가장 먼저 둔다(법 16: 추인하지 않은 포고는 사라진다).
  const merged: Agenda[] = [
    ...(g.ratify ?? []).filter(l => lawActive(g, l)).map(law => ({ law, repeal: false, ratify: true })),
    ...(g.ratifyRepeal ?? []).filter(l => !lawActive(g, l)).map(law => ({ law, repeal: true, ratify: true })),
  ];
  // 법이 아닌 안건은 순서 자리(s1b_dark_path 12.3: crisis > ratify > confidence > ai > player)에 끼운다.
  const motions = motionsNow(g);
  const ranked = (r: string) => motions.filter(m => MOTIONS[m.motion].rank === r);
  merged.push(...ranked('ratify'), ...ranked('confidence'));
  // AI 지도자가 올린 안건(4장)은 그다음에 둔다.
  for (const p of g.proposals) {
    if (!isLawAgenda(p) || options.some(o => sameAgenda(o, p))) merged.push(p);
  }
  merged.push(...ranked('ai'));
  // 법 요구가 걸린 안건을 그다음에 둔다.
  const needed = (o: LawAgenda) => !o.repeal && needOf(g, o.law) !== null;
  for (const o of [...options.filter(needed), ...options.filter(o => !needed(o))]) {
    if (!merged.some(m => sameAgenda(m, o))) merged.push(o);
  }
  merged.push(...ranked('player'));
  const crisis = crisisNow(g);
  const forced: Agenda[] = [...ranked('crisis'), ...merged.filter(isLawAgenda).filter(o => (o.repeal ? drains(o.law) : LAWS[o.law].crisis).some(k => crisis.includes(k)))];
  if (forced.length > 0) return { options: forced.map(o => ({ ...o, forced: true })), forced: true };
  return { options: merged, forced: false };
}

/** AI 대표가 올릴 법 안건(4장 '안건 올리기'): 의석 큰 칸부터, 제 입장(적의 빼고) 3 이상, 폐지면 2 이상,
 * 적의 3이면 폐지에 +3. 고를 게 없으면 null. S1b 정기 신임 부결 뒤의 회기도 이 법으로 고른다(5.3). */
export function aiAgendaPick(g: Game, options: readonly LawAgenda[]): { c: Comm; idx: number } | null {
  let best: { c: Comm; idx: number; score: number } | null = null;
  for (const c of [...COMMS].sort((a, b) => seats(g)[b] - seats(g)[a])) {
    const s = g.comms[c];
    options.forEach((o, idx) => {
      const own = stance(g, c, o, false).score;
      const hostileRepeal = s.grudge >= 3 && o.repeal;
      const score = own + (hostileRepeal ? 3 : 0);
      if ((own >= 3 || (o.repeal && own >= 2) || hostileRepeal) && (!best || score > best.score)) best = { c, idx, score };
    });
  }
  const pick = best as { c: Comm; idx: number } | null;
  return pick ? { c: pick.c, idx: pick.idx } : null;
}

/** 의회를 연 직후와 표결 뒤에 부를 다른 묶음의 훅(S1b 재판·불신임, dark/hooks.ts가 등록한다). */
export const COUNCIL_HOOKS: { open?: (g: Game) => void; vote?: (g: Game, agenda: Agenda, r: VoteResult) => void }[] = [];

export function openCouncil(g: Game, emergency = false): void {
  g.session += 1;
  // 적의는 새 잘못 없이 2회기가 지나면 하나 준다(3.7). 비상 소집으로 적의를 빨리 지우지는 못한다.
  // 비상 회기는 회기 수에 들어가지만 적의 시계는 그만큼 미룬다(K01 8): 정기 회기만 센다.
  if (emergency) for (const c of COMMS) g.comms[c].lastOffense += 1;
  else for (const c of COMMS) {
    const s = g.comms[c];
    if (s.grudge > 0 && g.session - s.lastOffense >= P.grudgeDecay) {
      s.grudge -= 1;
      s.lastOffense = g.session;
    }
  }
  if (!emergency && lawActive(g, 'patrol') && rnd(g) < 0.25) {
    const secret = addSecret(g);
    journal(g, `귀환 검사에서 ${COMM_NAME[secret.about]} 대표의 약점이 드러났다.`, 'dark');
  }
  const { options } = agendaOptions(g);
  let idx = 0;
  if (g.agendaHolder) {
    // 안건 선택권을 넘긴 집단이 고른다: 그 집단이 가장 좋아하는 안건.
    const holder = g.agendaHolder;
    let best = -99;
    options.forEach((o, i) => {
      const sc = stance(g, holder, o, false).score;
      if (sc > best) { best = sc; idx = i; }
    });
  }
  g.council = { options, idx, locked: g.agendaHolder !== null, deals: [], result: null, ...(emergency ? { emergency } : {}) };
  if (g.agendaHolder && options.length > 0) journal(g, `${COMM_NAME[g.agendaHolder]}이(가) 안건을 골랐다: ${agendaTitle(options[idx])}.`);
  g.agendaHolder = null;
  for (const hook of COUNCIL_HOOKS) hook.open?.(g);
}


export function agendaTitle(a: Agenda): string {
  if (!isLawAgenda(a)) return MOTIONS[a.motion].title(a);
  if (a.ratify) return `${LAWS[a.law].title}${a.repeal ? ' 폐지' : ''} 추인`;
  if (a.amend) return `${LAWS[a.amend].title} 개정: ${LAWS[a.law].title}`;
  return `${LAWS[a.law].title}${a.repeal ? ' 폐지' : ''}`;
}

/** 법 안건 앞에 따로 여는 표결(정기 신임)이 아직 끝나지 않았다. 그동안은 그 표결이 지금 안건이다. */
export function preVote(g: Game): boolean {
  const pre = g.council?.pre;
  return !!pre && !pre.result;
}

/** 앞선 표결의 결과를 접고 법 안건으로 넘어간다(주 단추 '다음 안건'). */
export function finishPreVote(g: Game): void {
  const council = g.council;
  if (!council?.pre || council.pre.result || !council.result) return;
  council.pre.result = council.result;
  council.result = null;
}

export function currentAgenda(g: Game): Agenda | null {
  const council = g.council;
  if (council?.pre && !council.pre.result) return council.pre.agenda;
  if (!council || council.options.length === 0) return null;
  return council.options[council.idx];
}

export function setAgenda(g: Game, idx: number): void {
  const council = g.council;
  if (!council || council.locked || council.result || preVote(g)) return;
  if (idx < 0 || idx >= council.options.length) return;
  council.idx = idx;
}

// ---- 거래 ----
export interface ToolStatus { ok: boolean; why?: string; cost?: string }

export function dealCount(g: Game): number {
  return g.council?.deals.length ?? 0;
}

export function toolStatus(g: Game, c: Comm, tool: DealTool): ToolStatus {
  const council = g.council;
  const agenda = currentAgenda(g);
  if (!council || !agenda) return { ok: false, why: '회기가 아니다' };
  if (preVote(g)) return { ok: false, why: '신임 표결엔 거래하지 않는다' };
  if (council.result) return { ok: false, why: '표결이 끝났다' };
  if (council.deals.some(d => d.comm === c)) return { ok: false, why: '이미 거래했다' };
  if (council.deals.length >= P.maxDealsPerSession) return { ok: false, why: `회기당 ${P.maxDealsPerSession}건` };
  const s = g.comms[c];
  const b = blocs(g, agenda, council.deals)[c];
  if (b.und + b.no === 0) return { ok: false, why: '살 표가 없다' };
  const hostile = s.grudge >= P.hostileGrudge;
  switch (tool) {
    case 'open':
    case 'fetch': {
      const cost = tool === 'fetch' ? `다음 정차: ${FETCH_WANT[c].label}` : '조건 하나';
      if (s.promise) return { ok: false, why: '지키지 않은 약속', cost };
      if (hostile) return { ok: false, why: '열차장을 적대한다', cost };
      if (s.rel <= -40) return { ok: false, why: '관계가 반대 이하', cost };
      if (b.ideo <= -3) return { ok: false, why: '신념에 정면으로 반한다', cost };
      return { ok: true, cost };
    }
    case 'favor':
      if (s.sick) return { ok: false, why: '대신 나온 측근에겐 빚이 없다', cost: '빚 1' };
      if (!s.debt) return { ok: false, why: '받을 빚이 없다', cost: '빚 1' };
      if (hostile) return { ok: false, why: '열차장을 적대한다', cost: '빚 1' };
      return { ok: true, cost: '빚 1' };
    case 'bribe': {
      const price = bribePrice(g, c);
      const cost = `사치품 ${price}`;
      if (hostile) return { ok: false, why: '집단이 따르지 않는다', cost };
      if (s.sick) return { ok: false, why: '측근은 뇌물을 받지 않는다', cost };
      if (g.lux < price) return { ok: false, why: '사치품이 모자라다', cost };
      return { ok: true, cost };
    }
    case 'blackmail': {
      const held = g.secrets.filter(x => x.about === c).length;
      const cost = `비밀 ${held}`;
      if (held === 0) return { ok: false, why: '쥔 비밀이 없다', cost };
      if (hostile) return { ok: false, why: '집단이 따르지 않는다', cost };
      return { ok: true, cost };
    }
  }
}

export function bribePrice(g: Game, c: Comm): number {
  return 2 + Math.round(seats(g)[c] / 10);
}


/** 공개 협상 조건 셋: 처지가 가장 나쁜 쪽, 그 집단의 것 하나, 공통 하나. 회기마다 같은 판이면 같다. */
export function openConditions(g: Game, c: Comm): ConditionDef[] {
  const pool = CONDITIONS[c].filter(x => !x.s1c || !!g.dom);
  const [w, r, cr] = situation(g, c);
  const worst = c === 'tail' && cr >= 70 ? pool.find(x => x.kind === 'relocate')
    : w < r ? pool.find(x => x.kind === 'heat') : pool.find(x => x.kind === 'ration');
  const first = worst ?? pool[0];
  const rest = pool.filter(x => x !== first);
  const second = rest[(g.session + g.seg) % rest.length];
  // 다음 안건 선택권은 하나뿐이다. 이미 누가 쥐었으면 같은 걸 또 팔지 않는다(먼저 받은 칸의 몫이 소리 없이 사라졌다).
  const commons = COMMON_CONDITIONS.filter(x => x.kind !== 'agenda' || g.agendaHolder === null);
  const common = commons[(g.session + COMMS.indexOf(c)) % commons.length];
  return [first, second, common];
}


export type DealOutcome = { ok: true; text: string } | { ok: false; text: string };

/** 거래를 맺는다. 공개 협상이면 condIndex로 조건을 고른다. */
export function makeDeal(g: Game, c: Comm, tool: DealTool, condIndex = 0, cutTarget?: Comm): DealOutcome {
  const status = toolStatus(g, c, tool);
  const council = g.council;
  const agenda = currentAgenda(g);
  if (!status.ok || !council || !agenda) return { ok: false, text: status.why ?? '할 수 없다' };
  const s = g.comms[c];
  const name = COMM_NAME[c];
  let label = '';
  if (tool === 'open') {
    const cond = openConditions(g, c)[condIndex];
    if (!cond) return { ok: false, text: '조건이 없다' };
    if (cond.kind === 'cut' && (!cutTarget || cutTarget === c)) return { ok: false, text: '칼질할 칸을 고른다' };
    label = cond.kind === 'cut' && cutTarget ? `${COMM_NAME[cutTarget]} 칼질` : cond.label;
    if (cond.now) {
      payNow(g, c, cond.kind, cutTarget);
    } else {
      const baseline = cond.kind === 'heat' ? s.heat : cond.kind === 'ration' || cond.kind === 'keep_ration' ? s.ration : undefined;
      s.promise = {
        kind: 'open', cond, label, due: cond.kind === 'target' || cond.kind === 'skip_dispatch' ? g.seg + 1 : g.seg + P.promiseSegments,
        madeSession: g.session, ...(isLawAgenda(agenda) ? { law: agenda.law } : {}), ...(baseline === undefined ? {} : { baseline }),
      };
    }
    // 처지가 아니라 거래로 지지가 쌓인다(1.2): 약속을 받은 쪽은 조금 누그러진다.
    journal(g, `${name}과(와) 공개 협상: ${label}. ${agendaTitle(agenda)}에 찬성하기로 했다.`, 'deal');
  } else if (tool === 'fetch') {
    const want = FETCH_WANT[c].label;
    label = `현장 조달: ${want}`;
    s.promise = {
      kind: 'fetch', cond: { kind: 'target', label: want, now: false }, label, due: g.seg + 1,
      madeSession: g.session, ...(isLawAgenda(agenda) ? { law: agenda.law } : {}),
    };
    journal(g, `${name}에 약속했다: 다음 정차에서 ${want}을(를) 가져온다.`, 'deal');
  } else if (tool === 'favor') {
    s.debt = false;
    label = '빚 회수';
    journal(g, `${s.leader.name}에게 빚을 받았다. 대표가 표를 끌고 온다.`, 'deal');
  } else if (tool === 'bribe') {
    const price = bribePrice(g, c);
    g.lux -= price;
    label = `뇌물(사치품 ${price})`;
    g.stats.bribes += 1;
    revealTrait(g, c);
    if (s.leader.trait === 'ideal') {
      // 이상주의자는 뇌물을 내밀면 폭로한다(3.3).
      exposeBribe(g, c);
      council.deals.push({ comm: c, tool, label: '뇌물을 거절당함', refused: true });
      return { ok: false, text: `${s.leader.name}이(가) 뇌물을 의회 앞에서 내보였다.` };
    }
    journal(g, `${s.leader.name}에게 사치품 ${price}을(를) 건넸다.`, 'dark');
  } else {
    const secret = [...g.secrets].filter(x => x.about === c).sort((a, b) => b.weight - a.weight)[0];
    g.secrets = g.secrets.filter(x => x.id !== secret.id);
    label = `협박: ${secret.text}`;
    g.leashes.push({ comm: c, since: g.seg, weight: Math.max(1, secret.weight - secret.uses) });
    g.blackmails += 1;
    g.stats.blackmails += 1;
    offend(g, c);
    revealTrait(g, c);
    journal(g, `${s.leader.name}을(를) 비밀로 눌렀다: "${secret.text}".`, 'dark');
    if (g.blackmails % P.blackmailReputation === 0) {
      for (const o of COMMS) offend(g, o);
      journal(g, '소문이 돈다: "열차장은 약점을 잡는다." 모든 칸이 경계한다.', 'bad');
    }
  }
  council.deals.push({ comm: c, tool, label });
  g.stats.dealsMade += 1;
  return { ok: true, text: label };
}

function payNow(g: Game, c: Comm, kind: string, cutTarget?: Comm): void {
  if (kind === 'relocate') {
    g.comms.tail.base[2] -= 15;
    g.comms.front.base[2] += 10;
    g.comms.front.rel = clamp(g.comms.front.rel - 5, -100, 100);
  } else if (kind === 'front_levy') {
    g.lux += 3;
    g.comms.front.rel = clamp(g.comms.front.rel - 8, -100, 100);
    g.comms[c].rel = clamp(g.comms[c].rel + 3, -100, 100);
  } else if (kind === 'shift') {
    g.coal -= P.shiftCoal;
    g.comms.engine.base[3] -= P.shiftRelief;
  } else if (kind === 'agenda') {
    g.agendaHolder = c;
    g.trust = clamp(g.trust + 2, 0, 100);
  } else if (kind === 'cut' && cutTarget) {
    cutComm(g, cutTarget, false);
  }
}

export function revealTrait(g: Game, c: Comm): void {
  const l = g.comms[c].leader;
  if (l.traitShown < 2) l.traitShown = (l.traitShown + 1) as 1 | 2;
}

export function offend(g: Game, c: Comm): void {
  const s = g.comms[c];
  s.grudge = Math.min(3, s.grudge + 1);
  s.lastOffense = g.session;
}

export function exposeBribe(g: Game, c: Comm): void {
  const s = g.comms[c];
  s.coh = clamp(s.coh - 0.2, 0, 1);
  s.disgraced = true;
  g.trust = clamp(g.trust - 10, 0, 100);
  offend(g, c);
  journal(g, `뇌물이 드러났다. ${s.leader.name}의 정당성이 무너지고 열차장도 신임을 잃었다.`, 'bad');
}

// ---- 비상대권(법 16) ----
export const DECREE_SEGS = 3;
/** 포고 하나를 싫어하는 칸의 관계 하락(R3 카드 3) */
export const DECREE_REL = 3;

/** 이번 구간에 포고할 수 있나: 대권 기간이고, 이번 구간엔 아직 포고하지 않았다. */
export function canDecree(g: Game): boolean {
  return g.decreeLeft > 0 && g.decreeSeg !== g.seg;
}

/** 대권이 끝날 때 부른다. 포고한 법은 다음 회기 추인 안건이 된다. 대권 법 자체는 내려놓는다.
 * S1b 계엄(s1b_dark_path 5.3)은 여기서 '표결 없이 연장'을 끼워 넣는다. */
export function endEmergencyPowers(g: Game): void {
  const decreed = (g.decreed ?? []).filter(l => lawActive(g, l));
  const repeals = (g.decreedRepeals ?? []).filter(l => !lawActive(g, l));
  g.decreed = [];
  g.decreedRepeals = [];
  if (repeals.length > 0) g.ratifyRepeal = [...(g.ratifyRepeal ?? []), ...repeals];
  const all = [...decreed.map(l => LAWS[l].title), ...repeals.map(l => `${LAWS[l].title} 폐지`)];
  if (lawActive(g, 'emergency_powers')) {
    delete g.passed.emergency_powers;
    g.repealedAt.emergency_powers = g.session;
  }
  if (decreed.length > 0) g.ratify = [...(g.ratify ?? []), ...decreed];
  if (all.length > 0) {
    journal(g, `비상대권이 끝났다. 포고한 ${all.join(', ')}은(는) 다음 회기에 추인받아야 남는다.`, 'dark');
  } else {
    journal(g, '비상대권이 끝났다.');
  }
}

/** 회기를 마친 정산에서 부른다. 이번 회기에 추인받지 못한 포고는 사라진다. 포고로 한 폐지가 추인받지 못하면 법이 돌아온다. */
export function dropUnratified(g: Game): void {
  const left = (g.ratify ?? []).filter(l => lawActive(g, l));
  g.ratify = [];
  for (const law of left) {
    repealLaw(g, law);
    journal(g, `추인받지 못한 ${LAWS[law].title}이(가) 사라졌다.`, 'bad');
  }
  const back = (g.ratifyRepeal ?? []).filter(l => !lawActive(g, l));
  g.ratifyRepeal = [];
  for (const law of back) {
    enactLaw(g, law, []);
    journal(g, `포고로 폐지한 ${LAWS[law].title}이(가) 추인받지 못해 다시 걸렸다.`, 'bad');
  }
}

// ---- 표결 ----
export function castVote(g: Game, decree = false): VoteResult | null {
  const agenda = currentAgenda(g);
  const r = vote(g, decree);
  if (r && agenda) for (const hook of COUNCIL_HOOKS) hook.vote?.(g, agenda, r);
  return r;
}

function vote(g: Game, decree: boolean): VoteResult | null {
  const council = g.council;
  const agenda = currentAgenda(g);
  if (!council || !agenda || council.result) return null;
  // 포고는 법만 한다. 추인과 법이 아닌 안건은 의회가 표결한다.
  if (decree && (!canDecree(g) || !isLawAgenda(agenda) || agenda.ratify)) return null;
  const need = agendaNeed(agenda);
  const map = blocs(g, agenda, council.deals);
  // 법 안건 앞의 표결(정기 신임)은 회기의 표결이 아니다. 옮긴 표, 유도 투표, AI 발의는 법 안건 표결에 남긴다.
  const pre = preVote(g);
  // 콘텐츠 사건으로 옮긴 표는 이 표결 한 번뿐이다. 포고는 표결이 아니라 남긴다.
  if (!decree && !pre) delete g.voteShift;
  const byComm = {} as VoteResult['byComm'];
  const flips: VoteFlip[] = [];
  let yes = 0;
  let no = 0;
  let absent = 0;
  for (const c of COMMS) {
    const b = map[c];
    let cy = b.yes;
    let cn = b.no;
    for (let i = 0; i < b.und; i += 1) {
      const v = rnd(g) < undecidedChance(b.score);
      flips.push({ comm: c, yes: v });
      if (v) cy += 1; else cn += 1;
    }
    for (let i = 0; i < b.pool; i += 1) {
      const v = rnd(g) < b.poolChance;
      flips.push({ comm: c, yes: v });
      if (v) cy += 1; else cn += 1;
    }
    byComm[c] = { yes: cy, no: cn, absent: b.absent };
    yes += cy;
    no += cn;
    absent += b.absent;
  }
  // 섞어서 하나씩 갈리게 한다.
  for (let i = flips.length - 1; i > 0; i -= 1) {
    const j = Math.floor(rnd(g) * (i + 1));
    [flips[i], flips[j]] = [flips[j], flips[i]];
  }
  const passed = decree || yes >= need;
  const result: VoteResult = { yes, no, absent, need, passed, byComm, flips, decree, secret: lawActive(g, 'secret_ballot') };
  council.result = result;
  if (!lawActive(g, 'secret_ballot') && !decree) g.fear = clamp(g.fear + 1, 0, 100);
  if (lawActive(g, 'guided_voting') && g.guidedLeft > 0 && !pre) {
    for (const c of COMMS) g.comms[c].rel = clamp(g.comms[c].rel - 3, -100, 100);
    g.fear = clamp(g.fear + 3, 0, 100);
    g.guidedLeft -= 1;
  }
  // AI 발의를 무시했으면 발의한 쪽이 서운해한다. 비상 소집은 다음 정기 회기의 발의를 건드리지 않는다.
  if (!pre && !council.emergency) {
    for (const p of g.proposals) {
      if (p.by && !sameAgenda(p, agenda)) g.comms[p.by].rel = clamp(g.comms[p.by].rel - 3, -100, 100);
    }
    g.proposals = [];
  } else if (!pre && passed) {
    // 기습 표결: 반대할 칸이 파견 나간 사이에 통과시켰다.
    for (const c of COMMS) {
      if (map[c].absent > 0 && map[c].score < 0) {
        offend(g, c);
        journal(g, `${COMM_NAME[c]}의 작업조가 돌아와 쓰러져 자는 사이 표결했다. 기습으로 기억한다.`, 'dark');
      }
    }
  }
  const title = agendaTitle(agenda);
  if (!isLawAgenda(agenda)) {
    journal(g, `${title}: 찬성 ${yes}, 반대 ${no}${absent ? `, 부재 ${absent}` : ''}. ${passed ? '가결' : '부결'}.`, passed ? 'good' : 'bad');
    if (passed) MOTIONS[agenda.motion].onPass(g, agenda);
    else MOTIONS[agenda.motion].onFail(g, agenda);
    return result;
  }
  if (decree) {
    // 대권 동안 구간마다 하나씩 포고할 수 있다. 대권이 끝나면 의회가 추인해야 남는다.
    g.decreeSeg = g.seg;
    if (agenda.repeal) (g.decreedRepeals ??= []).push(agenda.law);
    else (g.decreed ??= []).push(agenda.law);
    // 대권을 쥐는 값(R3 카드 3): 포고마다 긴장 +5, 그 포고를 싫어하는 칸과 관계 −3.
    g.tension = clamp(g.tension + 5, 0, 100);
    for (const c of COMMS) if (stance(g, c, agenda, false).score <= -3) g.comms[c].rel = clamp(g.comms[c].rel - DECREE_REL, -100, 100);
    journal(g, `비상대권으로 ${title}을(를) 포고했다.`, 'dark');
  } else {
    journal(g, `${title}: 찬성 ${yes}, 반대 ${no}${absent ? `, 부재 ${absent}` : ''}. ${passed ? '가결' : '부결'}.`, passed ? 'good' : 'bad');
  }
  if (agenda.ratify && agenda.repeal) {
    g.ratifyRepeal = (g.ratifyRepeal ?? []).filter(l => l !== agenda.law);
    if (passed) journal(g, `의회가 포고한 ${LAWS[agenda.law].title} 폐지를 추인했다.`, 'good');
    else { enactLaw(g, agenda.law, []); journal(g, `의회가 ${LAWS[agenda.law].title} 폐지를 추인하지 않았다. 법이 다시 걸렸다.`, 'bad'); }
    return result;
  }
  if (agenda.ratify) {
    g.ratify = (g.ratify ?? []).filter(l => l !== agenda.law);
    if (passed) journal(g, `의회가 포고한 ${LAWS[agenda.law].title}을(를) 추인했다.`, 'good');
    else { repealLaw(g, agenda.law); journal(g, `의회가 ${LAWS[agenda.law].title}을(를) 추인하지 않았다. 포고가 사라졌다.`, 'bad'); }
    return result;
  }
  if (!passed) {
    g.stats.lawsFailed += 1;
    return result;
  }
  if (agenda.repeal) repealLaw(g, agenda.law);
  else enactLaw(g, agenda.law, council.deals.filter(d => d.tool === 'open' || d.tool === 'fetch').map(d => d.comm));
  return result;
}

export function enactLaw(g: Game, law: LawId, boughtFrom: Comm[]): void {
  const def = LAWS[law];
  // 개정(7.3): 변형이 서면 원래 법은 내려간다. 폐지가 아니라 고쳐 쓴 것이라 지지 칸 반발·약속 배신은 없다.
  const base = LAW_VARIANT_OF[law];
  if (base && g.passed[base] !== undefined) {
    delete g.passed[base];
    // 빈틈(내정 스레드 2026-10-07): 표를 사서 세운 원래 법을 개정하면 boughtBy가 지워져 약속 배신 셈을 피한다.
    // 변형을 여는 기술이 셋(M3 가, X1, M2)뿐이라 두지만, S3에서 거래가 늘면 boughtBy를 변형 법으로 넘긴다(추천).
    delete g.boughtBy[base];
    g.repealedAt[base] = g.session;
    for (const c of COMMS) {
      const m = LAWS[base].mats[c];
      if (m) for (let i = 0; i < 4; i += 1) g.comms[c].base[i] -= m[i];
    }
    journal(g, `${LAWS[base].title}을(를) ${def.title}(으)로 고쳤다.`);
  }
  g.passed[law] = g.session;
  if (boughtFrom.length > 0) g.boughtBy[law] = { comms: boughtFrom, session: g.session };
  for (const c of COMMS) {
    const m = def.mats[c];
    if (m) for (let i = 0; i < 4; i += 1) g.comms[c].base[i] += m[i];
    const r = def.rels[c];
    if (r !== undefined) g.comms[c].rel = clamp(g.comms[c].rel + r, -100, 100);
  }
  // 1회 효과는 법마다 한 판에 한 번(R3 카드 1, 2026-10-07): 폐지했다 다시 통과시켜 또 받지 못한다. 관계 반응은 통과마다 그대로.
  // 변형 법(종자곡 반만 풀기 등)은 원래 법과 한 묶음으로 센다.
  const res = def.res;
  const once = LAW_VARIANT_OF[law] ?? law;
  if (!(g.onceTaken ??= []).includes(once)) {
    if (res.trustOnce) g.trust = clamp(g.trust + res.trustOnce, 0, 100);
    if (res.fearOnce) g.fear = clamp(g.fear + res.fearOnce, 0, 100);
    if (res.foodOnce) g.food += res.foodOnce;
    if (res.trustOnce || res.fearOnce || res.foodOnce) g.onceTaken.push(once);
  }
  if (law === 'guided_voting') g.guidedLeft = 3;
  // 3구간짜리 대권(numbers 8장 법 16). 통과한 구간은 이미 표결이 끝났으니 다음 세 구간을 센다(nextSegment가 하나씩 줄인다).
  if (law === 'emergency_powers') { g.decreeLeft = DECREE_SEGS + 1; g.decreed = []; }
  if (CORPSE_LAWS.includes(law)) g.corpseIssue = false;
  refreshSit(g); // 기술이 덜어 주는 법의 벌(7.3)
  g.stats.lawsPassed += 1;
}

export function repealLaw(g: Game, law: LawId): void {
  const def = LAWS[law];
  const supporters = COMMS.filter(c => stance(g, c, { law, repeal: false }, false).score >= 3);
  delete g.passed[law];
  g.repealedAt[law] = g.session;
  for (const c of COMMS) {
    const m = def.mats[c];
    if (m) for (let i = 0; i < 4; i += 1) g.comms[c].base[i] -= m[i];
  }
  for (const c of supporters) g.comms[c].rel = clamp(g.comms[c].rel - P.repealRel, -100, 100);
  const bought = g.boughtBy[law];
  delete g.boughtBy[law];
  if (bought && g.session - bought.session <= 3) {
    for (const c of bought.comms) offend(g, c);
    journal(g, `약속으로 통과시킨 ${def.title}을(를) 뒤집었다. ${bought.comms.map(c => COMM_NAME[c]).join(', ')}이(가) 배신으로 기억한다.`, 'bad');
  }
  if (CORPSE_LAWS.includes(law)) g.corpseIssue = true;
  if (law === 'guided_voting') g.guidedLeft = 0;
  if (law === 'emergency_powers') g.decreeLeft = 0;
  refreshSit(g);
  g.stats.repeals += 1;
}

// ---- 공동체 행동(3.6) ----
export function supportComm(g: Game, c: Comm): string | null {
  if (g.actedSeg === g.seg) return '이번 구간엔 이미 했다';
  if (g.lux < 2) return '사치품 2가 필요하다';
  const s = g.comms[c];
  g.lux -= 2;
  // 같은 칸을 3구간 안에 또 챙기면 덜 오른다: 지지 하나가 정답이 되지 않게(first_leg_story 7.7, 제안).
  const again = g.seg - s.supportedAt < P.supportGap;
  s.rel = clamp(s.rel + (again ? P.supportRepeatRel : P.supportRel), -100, 100);
  s.fervor = Math.max(0, s.fervor - 1);
  const other = OPPOSITE[c];
  g.comms[other].rel = clamp(g.comms[other].rel - 3, -100, 100);
  if (s.cutAt.some(at => g.seg - at <= 3)) {
    offend(g, c);
    journal(g, `${COMM_NAME[c]}을(를) 깎았다가 다시 챙겼다. 번복으로 기억된다.`, 'bad');
  }
  s.supportedAt = g.seg;
  g.actedSeg = g.seg;
  journal(g, `${COMM_NAME[c]}에 공간과 사치품을 더 내줬다.`, 'good');
  return null;
}

/** 공간 레버(first_leg_story 6.4): 꼬리칸 과밀을 다른 한 칸으로 옮긴다. 0~2단, 내주는 칸은 꼬리칸 말고 하나.
 * 당길 때 내주는 칸 관계 −3, 당겨 둔 동안 구간마다 단당 −1(정산). 내주는 칸을 바꾸려면 0단으로 풀었다가 다시 당긴다. 못 하면 까닭. */
export function setSpace(g: Game, step: number, giver?: Comm): string | null {
  const sp = (g.space ??= { step: 0, giver: null });
  if (giver === 'tail') return '꼬리칸은 공간을 내줄 수 없다';
  if (giver && giver !== sp.giver) {
    if (sp.step > 0) return '내준 칸을 바꾸려면 먼저 공간을 거둬라';
    sp.giver = giver;
  }
  const to = clamp(Math.round(step), 0, P.spaceMax);
  if (to > 0 && !sp.giver) return '공간을 내줄 칸을 먼저 골라라';
  if (to > sp.step && sp.giver) {
    g.comms[sp.giver].rel = clamp(g.comms[sp.giver].rel + P.spacePullRel * (to - sp.step), -100, 100);
    journal(g, `${COMM_NAME[sp.giver]}${josa(COMM_NAME[sp.giver], '이/가')} 꼬리칸에 자리를 내줬다(${to}단).`, 'bad');
  } else if (to < sp.step) {
    journal(g, to === 0 ? '꼬리칸에 내준 자리를 거뒀다.' : `꼬리칸에 내준 자리를 ${to}단으로 줄였다.`);
  }
  sp.step = to;
  return null;
}

export function cutComm(g: Game, c: Comm, asAction = true): string | null {
  if (asAction && g.actedSeg === g.seg) return '이번 구간엔 이미 했다';
  const s = g.comms[c];
  s.rel = clamp(s.rel - 15, -100, 100);
  s.fervor = Math.min(3, s.fervor + 1);
  g.food += 4;
  const other = OPPOSITE[c];
  g.comms[other].rel = clamp(g.comms[other].rel + 5, -100, 100);
  if (s.cutAt.some(at => g.seg - at <= 3) || g.seg - s.supportedAt <= 3) offend(g, c);
  s.cutAt.push(g.seg);
  if (asAction) g.actedSeg = g.seg;
  journal(g, `${COMM_NAME[c]}의 배급과 특권을 깎았다(식량 +4).`, 'dark');
  return null;
}

export function uniqueAction(g: Game, c: Comm): string | null {
  if (g.actedSeg === g.seg) return '이번 구간엔 이미 했다';
  if (g.comms[c].rel < 15) return '호의 이상이어야 한다';
  if (c === 'tail') g.coal += 3;
  else if (c === 'engine') g.forcedRun = true;
  else if (c === 'guard') g.guardEscort = true;
  else if (c === 'medtech') g.injured = Math.max(0, g.injured - 2);
  else g.lux += 2;
  g.actedSeg = g.seg;
  journal(g, `${COMM_NAME[c]}이(가) 나섰다.`, 'good');
  return null;
}

