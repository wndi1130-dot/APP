// S1a / S1a+S1c 자동 플레이어. tools/s1c_sim.ts(시뮬레이션)와 tests/game/domestic.test.ts가 쓴다.
// 실제 게임 코드(src/game)를 그대로 돌린다. 파이썬 s1a_balance.py의 caretaker를 흉내 내지만 같은 정책은 아니다(아래 '돌보는 정책').

import {
  advance, autoLevers, blocs, castVote, chooseCard, COMMS, createGame, createS1cGame, currentAgenda, expected, freeTeacher,
  irreplaceable, knowers, LAWS, agendaNeed, isLawAgenda, makeDeal, manualWriter, primaryAction, requestApprentice, requestManual, resolveStop, setAgenda,
  setDelegate, delegateStatus, toolStatus, viewCard, FIELDS, TECH_IDS, TECHS, restoreCheck, startRestore, usefulVariant,
} from '../src/game';
import type { Card, CardView, Choice, Eff, Game, TechId, Variant } from '../src/game';
import { loadContentEvents } from './content_fs';

// 콘텐츠 JSON 사건(data/events)도 봇 판에 섞는다.
loadContentEvents();

export type S1aPolicy = 'caretaker' | 'first';
/** engaged: 내정 카드에서 일을 벌이는 쪽을 고르고 견습·매뉴얼을 청한다. idle: 늘 '나중에/안 한다'. */
export type DomPolicy = 'engaged' | 'idle';

export interface BotOptions { s1c: boolean; policy: S1aPolicy; dom: DomPolicy; /** 탐색용: S1a 카드를 효과 점수로 고른다 */ scoreCards?: boolean; /** 탐색용: 레버를 안 만진다 */ noLevers?: boolean; /** 탐색용: 의회는 첫 안건, 거래 없음 */ plainCouncil?: boolean }

export interface GameMetrics {
  end: string;
  segReached: number;
  coalMin: number;
  foodMin: number;
  coalUnder30: number;
  foodUnder30: number;
  councils: number;
  forced: number;
  lawsPassed: number;
  harshPassed: number;
  deaths: number;
  emergencyCoal: boolean;
  endCoal: number;
  endFood: number;
  /** 서류 뭉치에 쌓인 카드(종류별) */
  cards: Record<string, number>;
  s1aCards: number;
  domCards: number;
  dom?: {
    restored: number; tier3: number; defective: number; breakdowns: number; repairs: number; lice: number; typhus: number;
    hotCoal: number; techCoal: number; apprentices: number; manuals: number; demands: number; partsMade: number; partsEnd: number;
    scrapEnd: number; woodEnd: number; buried: number; s1cLaws: number; techs: string[];
  };
}

const W: Partial<Record<Eff['t'], number>> = {
  coal: 0.25, food: 0.2, med: 0.6, lux: 0.4, trust: 1, tension: -0.6, fear: -0.3, injured: -2.5, rel: 0.25, fervor: -2, pop: -3, debt: -1, grudge: -4,
};

/** 돌보는 정책의 S1a 카드 고르기: 효과 줄 점수가 가장 높은 것. */
function scoreChoice(g: Game, ch: Choice): number {
  let s = 0;
  // 석탄·식량이 적을수록 무겁게 본다.
  const w: Partial<Record<Eff['t'], number>> = { ...W, coal: 0.2 + 25 / Math.max(10, g.coal), food: 0.15 + 20 / Math.max(10, g.food) };
  for (const e of ch.effs) {
    if (e.t === 'base') s += e.i === 0 || e.i === 1 ? e.v * 0.1 : -e.v * 0.1;
    else if (e.t === 'lever') s += e.v * (e.which === 'heat' ? (g.coal > 90 ? 0.3 : -1) : (g.food > 90 ? 0.3 : -1));
    else if ('v' in e) s += (w[e.t] ?? 0) * e.v * (e.t === 'rel' && e.c === 'tail' ? 1.3 : 1);
    else s += w[e.t] ?? 0;
  }
  if (ch.witness) s -= 0.5;
  return s;
}

/** 봇이 이 기술을 살 때 고르는 변형. 법에만 걸린 기술인데 그 법이 없으면 null(사지 않는다). 공방장과 같은 규칙이다. */
const lawVariant = usefulVariant;

/** 내정 카드: 정책에 따른 고르기(특수 표시로 알아본다). */
function domPick(g: Game, card: Card, view: CardView, policy: DomPolicy): number {
  const ok = view.choices.map((c, i) => ({ c, i })).filter(x => !x.c.disabled);
  const by = (sp: string) => ok.find(x => x.c.special === sp)?.i;
  if (policy === 'idle') return by('dom:none') ?? (card.kind === 'dom:lice' ? by('dom:lice:endure') : undefined) ?? ok[0].i;
  switch (card.kind) {
    case 'dom:fit': if (lawVariant(g, card.text as TechId) === null) return by('dom:none') ?? ok[0].i;
      return by('dom:restore:full') ?? by('dom:restore:defect') ?? ok[0].i;
    case 'dom:fork': {
      const v = TECHS[card.text as TechId]?.variants ? lawVariant(g, card.text as TechId) : undefined;
      if (v) return by(`dom:variant:${v}`) ?? ok[0].i;
      return card.text === 'e3' ? (by(g.comms.tail.rel < 0 ? 'dom:variant:a' : 'dom:variant:b') ?? ok[0].i) : ok[0].i;
    }
    case 'dom:short': {
      const running = Object.values(g.dom?.techs ?? {}).some(t => t && (t.stage === 'done' || t.stage === 'defective') && !t.off);
      return (running && card.text === 'break' ? by('dom:short:stand') : by('dom:short:target')) ?? ok[0].i;
    }
    case 'dom:pupil': return by('dom:pupil:guild') ?? ok[ok.length - 1].i;
    case 'dom:manual': return by('dom:manual:write') ?? ok[ok.length - 1].i;
    case 'dom:demand': return by('dom:demand:pupil') ?? (card.n === 0 && g.lux < 1 ? by('dom:demand:refuse') : by('dom:demand:grant')) ?? ok[0].i;
    case 'dom:car': return (g.coal > 60 ? ok[0].i : by('dom:none')) ?? ok[0].i;
    case 'dom:give': return by('dom:give:tail3') ?? by('dom:give:cold') ?? by('dom:none') ?? ok[0].i;
    case 'dom:box': return by('dom:none') ?? ok[0].i;
    case 'dom:full': return by('dom:full:parts') ?? ok[0].i;
    case 'dom:bed': return by('dom:bed:sick') ?? ok[0].i;
    case 'dom:officer': return by('dom:officer:revert') ?? ok[0].i;
    case 'dom:lice': return (g.coal > 50 ? by('dom:lice:boil') : by('dom:lice:burn')) ?? ok[0].i;
    case 'dom:typhus': return (g.med > 6 ? by('dom:typhus:bay') : by('dom:typhus:apart')) ?? ok[0].i;
    case 'dom:stoker': return by('dom:stoker:tail') ?? ok[0].i;
    case 'dom:pressure': return by('dom:pressure:vent') ?? ok[0].i;
    default: return ok[0].i;
  }
}

/** 의회: 위기면 강제 안건 중, 아니면 통과 가능성이 가장 높은 안건. 돌보는 정책은 공개 협상을 건다. */
function council(g: Game, opts: BotOptions): void {
  const c = g.council!;
  if (!c.locked && opts.policy === 'caretaker') {
    let best = -99;
    let idx = 0;
    c.options.forEach((o, i) => {
      const ex = expected(blocs(g, o, c.deals)).mean - agendaNeed(o);
      const harsh = isLawAgenda(o) && LAWS[o.law].tag === '가혹' ? -1.5 : 0;
      const sc = ex + harsh + (isLawAgenda(o) && o.repeal ? -3 : 0) + (o.forced ? 5 : 0);
      if (sc > best) { best = sc; idx = i; }
    });
    setAgenda(g, idx);
  }
  if (opts.policy === 'caretaker') {
    const a = currentAgenda(g)!;
    if (expected(blocs(g, a, c.deals)).mean < agendaNeed(a) + 3) {
      for (const k of COMMS) if (toolStatus(g, k, 'open').ok) makeDeal(g, k, 'open', 0);
    }
  }
  castVote(g);
}

/** 내정 쪽 손: 대체 불가나 한 명뿐인 분야에 견습생을 청하고, 기관 매뉴얼을 청하고, 공방장 맡기기를 켠다. */
function domesticPrep(g: Game): void {
  const d = g.dom;
  if (!d) return;
  for (const f of FIELDS) {
    const single = knowers(g, f).length <= 1;
    const learning = d.people.some(p => p.alive && !p.gone && p.field === f && p.learn);
    if ((irreplaceable(g, f) || (single && g.seg % 6 === 2)) && !learning && freeTeacher(g, f)) requestApprentice(g, f);
  }
  if (!d.manuals.engine && g.seg >= 4 && !manualWriter(g, 'engine').why && !d.people.some(p => p.writing)) requestManual(g, 'engine');
  if (!d.delegate.on && delegateStatus(g).ok) setDelegate(g, true, 'neutral');
  // 설계도 화면에서 '나중에'로 미뤄 둔 기술을 공방이 비면 시작한다(완성판 먼저, 낮은 단계부터).
  if (!d.restoring) {
    const ids = TECH_IDS.filter(id => !d.techs[id]).sort((a, b) => TECHS[a].tier - TECHS[b].tier);
    for (const id of ids) {
      const ch = restoreCheck(g, id);
      // 법을 바꾸는 기술(7.3)은 그 법이 서 있을 때만 산다. 변형은 서 있는 법 쪽으로 고른다(2026-10-07 내정 스레드).
      const v = lawVariant(g, id);
      if (v === null) continue;
      if (!ch.full && startRestore(g, id, 'full', v)) break;
      if (!ch.defect && startRestore(g, id, 'defect', v)) break;
    }
  }
}

export function playGame(seed: string, opts: BotOptions): { g: Game; m: GameMetrics } {
  const g = opts.s1c ? createS1cGame(seed) : createGame(seed);
  const seen = new Set<number>();
  const cards: Record<string, number> = {};
  const m: GameMetrics = {
    end: '', segReached: 0, coalMin: g.coal, foodMin: g.food, coalUnder30: 0, foodUnder30: 0, councils: 0, forced: 0, lawsPassed: 0, harshPassed: 0,
    deaths: 0, emergencyCoal: false, endCoal: 0, endFood: 0, cards, s1aCards: 0, domCards: 0,
  };
  let lastSeg = -1;
  let lastCouncil = -1;
  let prepSeg = -1;
  for (let guard = 0; guard < 5000 && g.phase !== 'end'; guard += 1) {
    if (g.seg !== lastSeg && g.phase === 'prep') {
      lastSeg = g.seg;
      if (g.coal < 30) m.coalUnder30 += 1;
      if (g.food < 30) m.foodUnder30 += 1;
    }
    m.coalMin = Math.min(m.coalMin, g.coal);
    m.foodMin = Math.min(m.foodMin, g.food);
    if (g.cards.length > 0) {
      const card = g.cards[0];
      if (!seen.has(card.uid)) {
        seen.add(card.uid);
        cards[card.kind] = (cards[card.kind] ?? 0) + 1;
        if (card.kind.startsWith('dom:')) m.domCards += 1; else m.s1aCards += 1;
      }
      const view = viewCard(g, card);
      // 끊어진 후속: 카드는 생겼는데 그리는 곳이 없다(tools/reach_check.ts).
      if (view.title === '빈 서류') throw new Error(`그리는 곳 없는 카드: ${card.kind}`);
      let idx: number;
      if (card.kind.startsWith('dom:')) idx = domPick(g, card, view, opts.dom);
      else if (!opts.scoreCards) idx = view.choices.findIndex(c => !c.disabled);
      else {
        let best = -1e9;
        idx = 0;
        view.choices.forEach((c, i) => { if (c.disabled) return; const s = scoreChoice(g, c); if (s > best) { best = s; idx = i; } });
      }
      if (!chooseCard(g, card.uid, idx)) throw new Error(`카드를 못 골랐다: ${card.kind} ${idx}`);
      continue;
    }
    if (g.phase === 'prep' && prepSeg !== g.seg) {
      prepSeg = g.seg;
      if (opts.policy === 'caretaker' && !opts.noLevers) autoLevers(g);
      if (opts.s1c && opts.dom === 'engaged') domesticPrep(g);
      continue;
    }
    if (g.phase === 'stop' && g.stop && !g.stop.done) { resolveStop(g, true); continue; }
    if (g.phase === 'council' && g.council && !g.council.result && currentAgenda(g)) {
      if (lastCouncil !== g.session) {
        lastCouncil = g.session;
        m.councils += 1;
        if (g.council.options[0]?.forced) m.forced += 1;
      }
      if (opts.plainCouncil) castVote(g); else council(g, opts);
      continue;
    }
    if (!primaryAction(g).ok) throw new Error(`막혔다: ${g.phase} ${primaryAction(g).why ?? ''}`);
    advance(g);
  }
  m.end = g.end ?? 'none';
  m.segReached = g.seg;
  m.lawsPassed = Object.keys(g.passed).length;
  m.harshPassed = Object.keys(g.passed).filter(l => LAWS[l as keyof typeof LAWS].tag === '가혹').length;
  m.deaths = g.deaths.length;
  m.emergencyCoal = g.emergencyUsed;
  m.endCoal = g.coal;
  m.endFood = g.food;
  const d = g.dom;
  if (d) {
    m.dom = {
      restored: d.stats.restored, tier3: d.stats.tier3, defective: d.stats.defective, breakdowns: d.stats.breakdowns, repairs: d.stats.repairs,
      lice: d.stats.lice, typhus: d.stats.typhus, hotCoal: d.stats.hotCoal, techCoal: d.stats.techCoal, apprentices: d.stats.apprentices,
      manuals: d.stats.manuals, demands: d.stats.demands, partsMade: d.stats.partsMade, partsEnd: d.parts, scrapEnd: d.scrap, woodEnd: d.wood,
      buried: d.stats.buried, s1cLaws: Object.keys(g.passed).filter(l => ['tech_control', 'apprentice_duty', 'triage_std', 'bath_rota', 'hands_first', 'seed_half', 'child_pack'].includes(l)).length,
      techs: Object.keys(d.techs).filter(id => d.techs[id as keyof typeof d.techs]?.stage !== 'restoring'),
    };
  }
  return { g, m };
}

