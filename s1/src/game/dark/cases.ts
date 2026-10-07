import { COMM_NAME, COMMS } from '../data';
import type { Comm } from '../data';
import { onDeath } from '../death';
import { offend } from '../politics';
import { clamp, journal, lawActive } from '../state';
import type { Game } from '../state';
import { B } from './data';
import { cross, scene } from './chronicle';
import { CLUE_LINES, CROWD_LINES } from './lines';
import {
  adults, alive, byId, commOf, darkCard, dpick, dr, FACT_SCORE, isRep, killEmber, nameOf, neighbors, newId, rivals, segFull, TIE_FACTS,
} from './state';
import type { Case, CaseKind, Clue, ClueKind, Ember, EmberCause, Fact, Suspect, Target } from './state';

/** 불씨 만들기. embers.ts가 newEmber로 채운다(cases ↔ embers import 순환을 끊는다). 채우기 전엔 불씨가 안 생긴다. */
export const EMBER_LINK: { born: (g: Game, who: Comm, target: Target, cause: EmberCause) => Ember | null } = { born: () => null };

// 4.4 수사와 처벌, 4.5 린치와 희생양. 증거는 불완전하고, 수사하는 동안 군중이 기다리지 않는다.
// 진범은 불씨의 '누가'로 정해진다. 단서와 증거는 의심 점수를 보지 않는다. 의심 점수는 '군중이 누구를 의심하나'다.

/** 사건이 난 곳에 드나들 수 있는 칸(4.5 표: 창고 열쇠 앞칸, 탄수차·보일러 화부, 무기고 경비대) */
const ACCESS: Partial<Record<CaseKind, Comm>> = { boiler: 'engine', poison: 'front', theft: 'front', assault: 'guard', assn: 'guard', order: 'guard', coupling: 'tail' };

function factsOf(g: Game, id: string, kind: CaseKind, victimComm: Comm): Fact[] {
  const p = byId(id);
  if (!p) return [];
  const d = g.dark!;
  const f: Fact[] = [];
  const c = p.community;
  if (ACCESS[kind] === c) f.push('access');
  if (c === victimComm || neighbors(victimComm).includes(c)) f.push('car');
  if (rivals(c, victimComm)) f.push('rival');
  // 판 중 합류(+2)와 구조민(+1)은 겹쳐 세지 않는다(4.5): 둘 다면 합류만.
  if (d.joined.includes(id)) f.push('joined');
  else if ((p as { origin_tag?: string }).origin_tag === 'rescued') f.push('rescued');
  if (d.punished.includes(id)) f.push('punished');
  return f;
}

/** 의심 점수(4.5): 사실 점수 + 그 사람을 가리킨 단서 하나마다 +1 */
export function suspicion(s: Suspect): number {
  return s.facts.reduce((sum, f) => sum + FACT_SCORE[f], 0) + s.clues.length;
}

/** 증거 단계: 0 소문, 1 정황, 2 증거. 밀고 한 건으로는 정황에 오르지 않고, 헛단서만으로는 증거가 되지 않는다(4.4). */
export function level(s: Suspect): 0 | 1 | 2 {
  const hard = s.clues.filter(c => c.kind !== 'informant').length;
  if (s.clues.length >= 2 && hard >= 1 && s.clues.some(c => c.truth)) return 2;
  return hard >= 1 ? 1 : 0;
}
export const LEVEL_WORD = ['소문', '정황', '증거'] as const;

/** 탄 경위(1.4: 출신 대신). 프로필의 boarding을 쓴다. */
export function boardingText(g: Game, id: string): string {
  if (g.dark!.joined.includes(id)) return '판 중에 탔다';
  const b = (byId(id) as { boarding?: string } | undefined)?.boarding;
  return ({ refugee: '피난길에 탔다', bought: '자리를 사서 탔다', rescue: '구조돼 탔다', depot: '차고에서부터 있었다', force: '밀고 올라탔다', born: '열차에서 났다' } as Record<string, string>)[b ?? ''] ?? '처음부터 탔다';
}

export interface OpenArgs {
  kind: CaseKind; culprit: string; victimComm: Comm; victim?: string; dead: boolean; clock: number | null; ember?: number; where: string; own?: boolean;
}

/** 수사를 연다. 용의자 셋: 진범 하나와 군중이 의심하는 사람 둘(4.4). 진범이 대표면 측근이 대신 오른다. */
export function openCase(g: Game, a: OpenArgs): Case {
  const d = g.dark!;
  d.stats.cases += 1;
  let culprit: Suspect;
  if (isRep(g, a.culprit)) {
    const c = commOf(g, a.culprit);
    const hands = adults(g, c, { noRep: true });
    const hand = hands.length ? dpick(g, hands).id : a.culprit;
    culprit = { id: hand, culprit: true, ...(hand !== a.culprit ? { proxyFor: a.culprit } : {}), facts: factsOf(g, hand, a.kind, a.victimComm), clues: [], acq: false };
  } else {
    culprit = { id: a.culprit, culprit: true, facts: factsOf(g, a.culprit, a.kind, a.victimComm), clues: [], acq: false };
  }
  const taken = new Set([culprit.id, a.victim ?? '', a.culprit]);
  const comms: Comm[] = ['tail', a.victimComm];
  const acc = ACCESS[a.kind];
  if (acc) comms.push(acc);
  const rival = COMMS.find(c => rivals(c, a.victimComm));
  if (rival) comms.push(rival);
  const cands: Suspect[] = [];
  for (const c of comms) {
    const pool = adults(g, c, { noRep: true }).filter(p => !taken.has(p.id) && !d.confined.some(x => x.id === p.id));
    if (!pool.length) continue;
    const p = dpick(g, pool);
    taken.add(p.id);
    cands.push({ id: p.id, culprit: false, facts: factsOf(g, p.id, a.kind, a.victimComm), clues: [], acq: false });
  }
  const ranked = cands.map(s => ({ s, k: suspicion(s) + dr(g) * 0.9 })).sort((x, y) => y.k - x.k).map(x => x.s).slice(0, 2);
  const sus = [culprit, ...ranked];
  // 화면에서 진범이 늘 첫 줄에 오지 않게 섞는다.
  for (let i = sus.length - 1; i > 0; i -= 1) { const j = Math.floor(dr(g) * (i + 1)); [sus[i], sus[j]] = [sus[j], sus[i]]; }
  const c: Case = {
    id: newId(g), kind: a.kind, victimComm: a.victimComm, ...(a.victim ? { victim: a.victim } : {}), dead: a.dead, clock: a.clock,
    status: 'open', protects: 0, promiseUsed: false, trialExt: false, paused: false, opened: g.seg, ...(a.ember !== undefined ? { ember: a.ember } : {}),
    own: !!a.own, sus, where: a.where,
  };
  d.cases.push(c);
  updateFlags(g);
  return c;
}

/** 경비가 선 자리에서 잡혔다: 진범이 '증거' 단계로 잡힌다(4.2). */
export function caught(g: Game, c: Case): void {
  const s = c.sus.find(x => x.culprit);
  if (!s) return;
  while (s.clues.length < 2) s.clues.push({ kind: 'witness', truth: true, line: `경비가 그 자리에서 ${nameOf(g, s.id)}${eulOf(nameOf(g, s.id))} 붙잡았다.`, seg: g.seg });
  updateFlags(g);
}
function eulOf(w: string): string {
  const ch = w.charCodeAt(w.length - 1);
  return ch < 0xac00 || ch > 0xd7a3 ? '을(를)' : (ch - 0xac00) % 28 ? '을' : '를';
}

function clueKind(g: Game, kind: CaseKind, truth: boolean): ClueKind {
  if (g.fear >= 20 && dr(g) < (truth ? 0.25 : 0.4)) return 'informant';
  const by: Record<CaseKind, ClueKind[]> = {
    boiler: ['foot', 'witness'], poison: ['ledger', 'foot'], theft: ['ledger', 'witness'], coupling: ['foot', 'witness'], heating: ['item', 'witness'],
    assault: ['item', 'witness', 'foot'], assn: ['witness', 'item'], order: ['witness', 'foot'],
  };
  return dpick(g, by[kind]);
}

function clueLine(g: Game, c: Case, s: Suspect, kind: ClueKind): string {
  const pool = adults(g, c.victimComm, { noRep: true }).filter(p => !c.sus.some(x => x.id === p.id));
  const w = pool.length ? dpick(g, pool).name : '경비 하나';
  return dpick(g, CLUE_LINES[kind]).replaceAll('{who}', nameOf(g, s.id)).replaceAll('{w}', w).replaceAll('{seg}', String(Math.max(1, c.opened)))
    .replaceAll('{place}', c.where);
}

/** 수사하는 구간마다 단서 하나(4.4). 진범 단서 min(75%, 40% + 경비대 지지 15% + 순찰 법 15% + 밀고자 10%). */
export function addClue(g: Game, c: Case): Clue | null {
  const pTrue = Math.min(B.clueCap, B.clueTrue + (g.comms.guard.rel >= 15 ? 0.15 : 0) + (lawActive(g, 'patrol') ? 0.15 : 0) + (g.fear >= 20 ? 0.1 : 0));
  const pFalse = (1 - pTrue) * (g.fear >= 60 ? B.falseMultFear : B.falseMult);
  const roll = dr(g);
  let s: Suspect | undefined;
  let truth = false;
  if (roll < pTrue) { s = c.sus.find(x => x.culprit); truth = true; }
  else if (roll < pTrue + pFalse) { const others = c.sus.filter(x => !x.culprit && alive(g, x.id)); s = others.length ? dpick(g, others) : undefined; }
  if (!s) return null;
  const kind = clueKind(g, c.kind, truth);
  const clue: Clue = { kind, truth, line: clueLine(g, c, s, kind), seg: g.seg };
  s.clues.push(clue);
  updateFlags(g);
  return clue;
}

/** 벌받지 않은(무죄로 풀려나지 않은) 산 용의자 */
export function eligible(g: Game, c: Case): Suspect[] {
  const live = c.sus.filter(s => alive(g, s.id));
  const free = live.filter(s => !s.acq);
  return free.length ? free : live;
}
/** 단서로 본 맨 위(재판의 피고, 즉결 대상) */
export function topByClues(g: Game, c: Case): Suspect | undefined {
  return [...eligible(g, c)].sort((a, b) => level(b) - level(a) || b.clues.length - a.clues.length || suspicion(b) - suspicion(a))[0];
}
/** 군중이 끌어낼 사람: 희생양 표시가 켜진 사람 중 의심 점수 맨 위. 없으면 undefined(군중이 이름에 모이지 못한다). */
export function mobTarget(g: Game, c: Case): Suspect | undefined {
  return [...eligible(g, c)].filter(s => flagged(g, s)).sort((a, b) => suspicion(b) - suspicion(a) || b.clues.length - a.clues.length)[0];
}

/** 희생양 후보 표시(1.4 두 층): 그 사건에 닿은 사실(드나듦·사건 칸이나 옆 칸·피해자와 원수·그 사람을 가리킨 단서) 하나 이상과
 * 의심 점수 전체 2 이상. 늦게 탐·밖에서 옴은 순위만 올린다. 이름 거름(프로필의 mob_exempt, 생성기 몫)과 아이는 언제나 빠진다. */
export function flagged(g: Game, s: Suspect): boolean {
  const p = byId(s.id);
  if (!p || p.age < 16 || (p as { mob_exempt?: boolean }).mob_exempt) return false;
  const tied = s.facts.some(f => TIE_FACTS.includes(f)) || s.clues.length > 0;
  return tied && suspicion(s) >= 2;
}

/** 열린 사건 동안만 켜진다. 콘텐츠 사건의 scapegoat 묶기(content.ts)가 이 목록을 읽는다. */
export function updateFlags(g: Game): void {
  const ids = new Set<string>();
  for (const c of g.dark!.cases) {
    if (c.status === 'closed') continue;
    for (const s of c.sus) if (!s.acq && alive(g, s.id) && flagged(g, s)) ids.add(s.id);
  }
  g.scapegoatOk = [...ids];
}

export function caseById(g: Game, id: number | undefined): Case | undefined {
  return g.dark?.cases.find(c => c.id === id);
}

/** 출발 전: 열린 사건마다 단서 하나와 수사 서류. 서류는 필수 결정이 셋이면 다음 구간으로 미룬다(단서는 쌓인다). */
export function investigate(g: Game): void {
  const d = g.dark!;
  for (const c of d.cases) {
    if (c.status !== 'open' || c.opened >= g.seg) continue;
    if (g.seg - c.opened >= B.coldCase) {
      c.status = 'closed';
      journal(g, `${crimeTitle(g, c)} 수사가 묻혔다. 아무도 벌받지 않았다.`, 'dark');
      continue;
    }
    if (g.cards.some(x => x.kind === 'dark:case' && x.n === c.id)) continue;
    addClue(g, c);
    if (segFull(g)) { d.stats.cardsDeferred += 1; continue; }
    darkCard(g, { kind: 'dark:case', comm: c.victimComm, n: c.id });
  }
  updateFlags(g);
}

export function crimeTitle(g: Game, c: Case): string {
  const v = c.victim ? nameOf(g, c.victim) : COMM_NAME[c.victimComm];
  switch (c.kind) {
    case 'assault': return `${v} ${c.dead ? '살해' : '폭행'}`;
    case 'assn': case 'order': return `${v} ${c.dead ? '살해' : '습격'}`;
    case 'boiler': return '보일러 수위 조작';
    case 'coupling': return '연결기 풀기';
    case 'poison': return '창고 식량 오염';
    case 'heating': return `${COMM_NAME[c.victimComm]} 난방관 파손`;
    case 'theft': return '창고 도둑질';
  }
}

/** 군중 조짐 한 줄(시계가 돌 때). 숫자 대신 조짐으로 보인다. */
export function crowdLine(g: Game, c: Case): string {
  const top = mobTarget(g, c);
  const line = dpickStable(CROWD_LINES.filter(l => top || !l.includes('{who}')), `${c.id}|${g.seg}`);
  return line.replaceAll('{who}', top ? nameOf(g, top.id) : '').replaceAll('{comm}', COMM_NAME[c.victimComm]);
}
function dpickStable(pool: string[], salt: string): string {
  let h = 0;
  for (let i = 0; i < salt.length; i += 1) h = (h * 31 + salt.charCodeAt(i)) >>> 0;
  return pool[h % pool.length];
}

// ---- 처리 ----

/** 재판에 넘긴다: 다음 회기 안건 자리를 쓴다. 군중 시계는 한 번 한 구간 는다. */
export function sendTrial(g: Game, c: Case): void {
  c.status = 'trial';
  if (c.clock !== null && !c.trialExt) { c.trialExt = true; c.clock += 1; }
}

/** 즉결(4.4): 경비대장이 바로 벌한다. 오판 확률 증거 0%, 정황 40%, 소문 70%. 공포 +5, 경비대 외 모든 칸 관계 −2. */
export function summary(g: Game, c: Case): Suspect | undefined {
  const top = topByClues(g, c);
  if (!top) return undefined;
  const pMis = [0.7, 0.4, 0][level(top)];
  let person = top;
  if (dr(g) < pMis) {
    const wrong = eligible(g, c).filter(s => !s.culprit);
    if (wrong.length) person = dpick(g, wrong);
  } else {
    person = c.sus.find(s => s.culprit && alive(g, s.id)) ?? top;
  }
  g.fear = clamp(g.fear + B.summaryFear, 0, 100);
  for (const k of COMMS) if (k !== 'guard') g.comms[k].rel = clamp(g.comms[k].rel - B.summaryRel, -100, 100);
  cross(g, 'summary');
  return person;
}

/** 덮는다: 수사 끝. 불씨는 꺼지지 않는다. 피해 칸 적의 +1. */
export function coverUp(g: Game, c: Case): void {
  c.status = 'closed';
  offend(g, c.victimComm);
  updateFlags(g);
}

export type Punish = 'ration' | 'confine' | 'exile' | 'execute';
export const PUNISH_SEGS = { ration: 3, confine: 4 };

/** 벌(4.4 표). 벌은 긴장을 내리지 않는다. 군중 시계를 끝낼 뿐이다. */
export function punish(g: Game, c: Case, s: Suspect, how: Punish, via: 'trial' | 'summary'): string[] {
  const d = g.dark!;
  const lines: string[] = [];
  const name = nameOf(g, s.id);
  const comm = commOf(g, s.id);
  c.status = 'closed';
  d.punished.push(s.id);
  switch (how) {
    case 'ration':
      g.comms[comm].rel = clamp(g.comms[comm].rel - 3, -100, 100);
      lines.push(`${name}의 배급을 사흘 끊었다. 그 몫은 피해 칸에 갔다.`);
      break;
    case 'confine':
      d.confined.push({ id: s.id, until: g.seg + PUNISH_SEGS.confine });
      lines.push(`${name}이(가) 경비대칸 구석에서 지켜보는 자리에 앉았다. 넉 구간이다.`);
      break;
    case 'exile':
      d.exile.push({ id: s.id, comm });
      g.comms[comm].rel = clamp(g.comms[comm].rel - 8, -100, 100);
      g.fear = clamp(g.fear + 5, 0, 100);
      cross(g, 'exiles');
      lines.push(`${name}에게 짐 하나와 사흘 치 빵을 줬다. 다음 역에서 내린다.`);
      scene(g, 'exile', 2, `${g.seg}구간, ${name}에게 하차 명령을 내렸다.`, [s.id]);
      break;
    case 'execute':
      cross(g, via === 'trial' ? 'executions' : 'executions');
      onDeath(g, comm, [name], 'chosen');
      offend(g, comm);
      g.fear = clamp(g.fear + 10, 0, 100);
      lines.push(`해가 지기 전에 총소리 하나가 났다. ${name}의 일은 그것으로 끝났다.`);
      scene(g, 'execute', 3, `${g.seg}구간, ${via === 'trial' ? '의회의 판결로' : '경비대의 손으로'} ${name}을(를) 처형했다.`, [s.id]);
      break;
  }
  if (s.culprit) {
    d.stats.solved += 1;
    killEmber(g, d.embers.find(e => e.id === c.ember));
    // 측근에서 지시한 사람으로(4.4): 50%로 시킨 사람을 댄다.
    if (s.proxyFor && alive(g, s.proxyFor) && dr(g) < 0.5) {
      const boss: Suspect = { id: s.proxyFor, culprit: true, facts: factsOf(g, s.proxyFor, c.kind, c.victimComm), clues: [], acq: false };
      boss.clues.push({ kind: 'witness', truth: true, line: `${name}이(가) ${nameOf(g, s.proxyFor)}이(가) 시켰다고 댔다.`, seg: g.seg });
      s.culprit = false;
      c.sus.push(boss);
      c.status = 'open';
      c.clock = null;
      lines.push(`${name}이(가) 시킨 사람을 댔다. ${nameOf(g, s.proxyFor)}. 수사를 다시 열 수 있다.`);
    }
    if (c.own && dr(g) < B.orderNamesChief) lines.push(...exposeOrderLines(g, c));
  } else {
    d.stats.misjudged += 1;
    d.innocents.push({ id: s.id, comm, seg: g.seg, caseId: c.id, how: 'punish' });
    EMBER_LINK.born(g, comm, 'guard', 'misjudged');
  }
  updateFlags(g);
  return lines;
}

/** 실행자가 열차장을 댔다(4.6 실패·벌). 대면 신임 −20, 모든 칸 적의 +1, 대상 칸 적의 +2. */
export function exposeOrderLines(g: Game, c: Case): string[] {
  g.trust = clamp(g.trust - 20, 0, 100);
  for (const k of COMMS) offend(g, k);
  offend(g, c.victimComm);
  offend(g, c.victimComm);
  scene(g, 'exposed', 4, `${g.seg}구간, 열차장이 시킨 죽음이 드러났다.`, []);
  journal(g, '실행자가 열차장이 시켰다고 말했다. 열차 전체가 들었다.', 'bad');
  return ['실행자가 열차장의 이름을 댔다.'];
}

// ---- 군중(4.5) ----

/** 정산: 군중 시계를 돌린다. 다 되면 시계 카드. 재판 중이면 조짐을 일지에 남긴다. */
export function crowdTick(g: Game): void {
  for (const c of g.dark!.cases) {
    if ((c.status !== 'open' && c.status !== 'trial') || c.clock === null || c.opened >= g.seg) continue;
    c.clock -= 1;
    if (c.clock <= 0) {
      if (!g.cards.some(x => x.kind === 'dark:mob' && x.n === c.id)) darkCard(g, { kind: 'dark:mob', comm: c.victimComm, n: c.id });
    } else if (c.status === 'trial' && c.crowdSeen !== g.seg) {
      c.crowdSeen = g.seg;
      journal(g, `${crowdLine(g, c)} 사람들이 범인을 찾는다.`, 'dark');
    }
  }
}

/** 지킨다: 1구간을 번다. 경비대 노출 +5, 군중 칸 관계 −5, 공포 +3. 두 번째엔 경비대도 다칠 수 있다(30%). */
export function protect(g: Game, c: Case): string {
  const d = g.dark!;
  d.stats.protected += 1;
  let hurt = '';
  if (c.protects >= 1 && dr(g) < B.protectHurt) {
    g.injured += 1;
    d.harm += 1;
    hurt = ' 밀치는 사이 경비 하나가 다쳤다.';
  }
  c.protects += 1;
  c.clock = 1;
  g.comms.guard.base[3] += 5;
  g.fear = clamp(g.fear + 3, 0, 100);
  g.comms[c.victimComm].rel = clamp(g.comms[c.victimComm].rel - 5, -100, 100);
  return `경비대가 앞에 섰다. 군중이 물러났지만 흩어지지는 않았다.${hurt}`;
}

/** 내준다(희생양) 또는 막지 않은 린치. 60% 죽고 아니면 크게 다친다. 긴장은 내리지 않고 시계만 끝난다. */
export function scapegoat(g: Game, c: Case, s: Suspect, allowed: boolean): string {
  const d = g.dark!;
  const name = nameOf(g, s.id);
  const comm = commOf(g, s.id);
  d.harm += 1;
  if (allowed) { d.stats.lynches += 1; g.fear = clamp(g.fear + 5, 0, 100); cross(g, 'lynch_allowed'); }
  else { d.stats.scapegoats += 1; cross(g, 'scapegoats'); }
  const died = dr(g) < B.scapegoatDeath;
  if (died) { d.stats.violentDeaths += 1; onDeath(g, comm, [name], 'chosen'); }
  else g.injured += 1;
  g.comms[comm].rel = clamp(g.comms[comm].rel - 10, -100, 100);
  offend(g, comm);
  c.status = 'closed';
  d.punished.push(s.id);
  if (s.culprit) {
    d.stats.solved += 1;
    killEmber(g, d.embers.find(e => e.id === c.ember));
  } else {
    d.innocents.push({ id: s.id, comm, seg: g.seg, caseId: c.id, how: allowed ? 'lynch' : 'scapegoat' });
  }
  EMBER_LINK.born(g, comm, 'guard', 'scapegoat');
  scene(g, allowed ? 'lynch' : 'scapegoat', allowed ? 2 : 3,
    `${g.seg}구간, ${allowed ? `군중이 ${name}을(를) 끌어내는 것을 막지 않았다` : `${name}을(를) 군중에게 내줬다`}.${s.culprit ? '' : ` 그가 ${s.facts.includes('joined') || s.facts.includes('rescued') ? '밖에서 왔다는 것' : '그 자리에 있었다는 것'} 말고는 아무것도 없었다.`}`, [s.id]);
  updateFlags(g);
  return `${name}이(가) 끌려 나갔다. ${died ? '돌아오지 않았다.' : '크게 다친 채 돌아왔다.'}`;
}

// ---- 진실은 늦게 드러난다(4.4) ----

/** 정산: 오판·희생양이었다면 6구간 안에 구간마다 10%로 진실이 드러날 수 있다. */
export function truthTick(g: Game): void {
  const d = g.dark!;
  const keep: typeof d.innocents = [];
  for (const x of d.innocents) {
    if (g.seg - x.seg > B.revealWindow) continue;
    if (dr(g) >= B.revealP || g.cards.some(k => k.kind === 'dark:truth')) { keep.push(x); continue; }
    // 드러나기 전에 예고 카드: 말하려는 사람을 '조용히 처리한다'가 열릴 수 있다(4.6).
    const witnesses = adults(g, x.comm, { noRep: true }).filter(p => p.id !== x.id);
    const w = witnesses.length ? dpick(g, witnesses) : null;
    darkCard(g, { kind: 'dark:truth', comm: x.comm, who: x.id, n: x.caseId, ...(w ? { text: w.id } : {}) });
  }
  d.innocents = keep;
}

/** 진실이 드러났다: 신임 −10, 벌받은 사람의 칸 적의 +1, 결과에 '죄 없는 사람을 벌했다'. */
export function reveal(g: Game, id: string, comm: Comm): string {
  const d = g.dark!;
  d.stats.revealed += 1;
  g.trust = clamp(g.trust - 10, 0, 100);
  offend(g, comm);
  const name = nameOf(g, id);
  scene(g, 'innocent', 3, `${g.seg}구간, 벌받은 ${name}이(가) 죄가 없었다는 것이 드러났다.`, [id]);
  return `${name}은(는) 그날 밤 거기 없었다. 진짜 한 사람은 따로 있었다. 열차가 그걸 알게 됐다.`;
}

export { alive as personAlive };
