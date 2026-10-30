// 결정 490 첫째 PR: 실제 S1a+S1c caretaker engaged 봇, 같은 sp-0… 시드.
// 사용: npx tsx tools/supplies_sim.ts [판 수=300] [JSON 경로] [--arms=off,on,on3] [--baseline-off=SHA256] [--baseline-on=SHA256]
// full은 쓰기 직전 (1 + supPlentyNeeds)×need까지 보충해, 쓴 뒤에도 늘 넉넉함(2×need)이 선다 — 「늘 손에 넣는 길」의 위 끝.
import { writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { COMMS, COMM_NAME, CONDITIONS, P, seats, standings } from '../src/game';
import type { Comm, Game } from '../src/game';
import { SUP_YIELD, SUP_MAKE, SUPPLIES_PROBE } from '../src/game/supplies';
import type { SuppliesSource } from '../src/game/supplies';
import { playGame } from './s1c_bot';
import type { BotOptions } from './s1c_bot';

const ARMS = ['off', 'on', 'on3', 'full', 'none', 'make_last', 'make_first'] as const;
type Arm = typeof ARMS[number];
const BASE: BotOptions = { s1c: true, policy: 'caretaker', dom: 'engaged' };
const FULL_BEFORE_USE_NEEDS = 1 + P.supPlentyNeeds;
const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
const flags = process.argv.slice(2).filter(a => a.startsWith('--'));
const n = Number(args[0] ?? 300);
const out = args[1];
if (!Number.isSafeInteger(n) || n < 1) throw new Error('판 수는 1 이상의 정수여야 한다');
if (args.length > 2 || flags.some(f => !/^--(?:arms|baseline-off|baseline-on)=/.test(f))
  || new Set(flags.map(f => f.split('=')[0])).size !== flags.length) {
  throw new Error(`사용: supplies_sim.ts [판 수=300] [JSON] [--arms=${ARMS.join(',')}]`);
}
const selected = flags.find(f => f.startsWith('--arms='))?.slice('--arms='.length).split(',') ?? ['off', 'on', 'full'];
const baselineOff = flags.find(f => f.startsWith('--baseline-off='))?.slice('--baseline-off='.length);
const baselineOn = flags.find(f => f.startsWith('--baseline-on='))?.slice('--baseline-on='.length);
for (const hash of [baselineOff, baselineOn]) {
  if (hash !== undefined && !/^[a-f0-9]{64}$/.test(hash)) throw new Error('기준 해시는 소문자 SHA-256이어야 한다');
}
if (!selected.length || selected.some(a => !ARMS.includes(a as Arm)) || new Set(selected).size !== selected.length) {
  throw new Error(`--arms는 ${ARMS.join(',')} 중 겹치지 않게 고른다`);
}
const arms = selected as Arm[];

interface Row {
  seed: string;
  stateHash: string;
  end: string;
  complete: boolean;
  settlements: number;
  rel: Record<Comm, number>;
  /** 발주의 관계 <0 의석 몫(%). 화면의 <=-15와 구별해 둘 다 남긴다. */
  unrestNegativePct: number;
  unrestHudPct: number;
  demand: number;
  lice: number;
  typhus: boolean;
  coverageObservations: number;
  shortageObservations: number;
  shortageSettlements: number;
  shortageShare: number | null;
  coverageSum: number;
  coverageMean: number | null;
  plentySettlements: number;
  endSupplies: number | null;
  income: { stop: number; search: number; field: number; make: number; total: number };
  injected: number;
  made: number;
  madeFine: number;
  needTotal: number;
  usedTotal: number;
  madeShare: number | null;
  madeUsedShare: number | null;
  insulatedCars: number;
  furnishJobs: number;
  w6RestoredSeg: number | null;
  asksOffered: number;
  asks: Record<'give_sup' | 'give_fine', { made: number; kept: number; broken: number; pending: number; otherEnded: number }>;
  favors: { offered: number; granted: number; fine: number; refused: number };
}

function run(arm: Arm, seed: string): Row {
  let settlements = 0;
  let uses = 0;
  let observations = 0;
  let short = 0;
  let shortageSettlements = 0;
  let asksOffered = 0;
  const favors = { offered: 0, granted: 0, fine: 0, refused: 0 };
  let coverageSum = 0;
  let plenty = 0;
  let injected = 0;
  let made = 0;
  let madeFine = 0;
  let needTotal = 0;
  let usedTotal = 0;
  let w6RestoredSeg: number | null = null;
  const income: Record<SuppliesSource, number> = { 'stop.loot': 0, 'sup.search': 0, 'field.loot': 0, 'sup.make': 0 };
  const seen = new Set<number>();
  let demand = 0;
  let lice = 0;
  // 고른 카드뿐 아니라 끝 정산에 나온 채 남은 카드까지 한 번씩 센다.
  const observeCards = (g: Game) => {
    for (const c of g.cards) {
      if (seen.has(c.uid)) continue;
      seen.add(c.uid);
      if (c.kind === 'demand') demand += 1;
      if (c.kind === 'dom:lice') lice += 1;
    }
  };
  const keep = { ...SUPPLIES_PROBE };
  try {
    SUPPLIES_PROBE.beforeUse = (g, need) => {
      if (arm !== 'full') return;
      const before = g.sup ?? 0;
      g.sup = Math.max(before, FULL_BEFORE_USE_NEEDS * need);
      injected += g.sup - before; // 도구의 공짜 보충은 실제 입고 장부와 분리한다.
    };
    SUPPLIES_PROBE.afterUse = (_g, turn) => {
      uses += 1;
      needTotal += turn.need;
      usedTotal += turn.use;
      if (turn.plenty) plenty += 1;
      if (Object.values(turn.cover).some(f => f < 1)) shortageSettlements += 1;
      for (const f of Object.values(turn.cover)) {
        observations += 1;
        if (f < 1) short += 1;
        coverageSum += f;
      }
    };
    SUPPLIES_PROBE.onGain = (_g, amount, source) => { income[source] += amount; };
    SUPPLIES_PROBE.onMake = (_g, amount, fine) => { made += amount; if (fine) madeFine += amount; };
    SUPPLIES_PROBE.onRestore = g => { w6RestoredSeg ??= g.seg; };
    const supMake = arm === 'make_first' ? 'first' : arm === 'make_last' ? 'last' : 'none';
    const { g } = playGame(seed, { ...BASE, sup: arm !== 'off', ...(arm !== 'off' ? { supMake, supAsk: arm !== 'on' } : {}), probe: {
      beforePick: (x, card, view, idx) => {
        observeCards(x);
        if (card.kind !== 'favor') return;
        favors.offered += 1;
        if (view.choices[idx].id === 'grant') favors.granted += 1;
        if (view.choices[idx].id === 'grant_fine') favors.fine += 1;
        if (view.choices[idx].id === 'refuse') favors.refused += 1;
      },
      onOpenConditions: (_g, _c, conditions) => { asksOffered += conditions.filter(x => x.sup).length; },
      afterPick: observeCards, beforePrep: observeCards, afterStop: observeCards,
      onSettle: x => { settlements += 1; observeCards(x); },
    } });
    observeCards(g);
    if (!g.end) throw new Error(`${arm}/${seed}: 봇이 판 끝에 닿지 못했다`);
    if (arm !== 'off' && uses !== settlements) throw new Error(`${arm}/${seed}: 사용 ${uses}회와 정산 ${settlements}회가 다르다`);
    const seatMap = seats(g);
    const asks: Row['asks'] = {
      give_sup: { made: 0, kept: 0, broken: 0, pending: 0, otherEnded: 0 },
      give_fine: { made: 0, kept: 0, broken: 0, pending: 0, otherEnded: 0 },
    };
    // 일지는 잘리지 않는다. 조건별 사실 문장만 세며, 지킨 뒤 붙는 대사는 세지 않는다.
    for (const c of COMMS) for (const cond of CONDITIONS[c].filter(x => x.sup)) {
      const tally = asks[cond.kind as keyof Row['asks']];
      for (const { text } of g.journal) {
        if (text.startsWith(`${COMM_NAME[c]}과(와) 공개 협상: ${cond.label}. `)) tally.made += 1;
        if (text === `${COMM_NAME[c]}과(와)의 약속을 지켰다: ${cond.label}.`) tally.kept += 1;
        if (text === `${COMM_NAME[c]}과(와)의 약속을 어겼다: ${cond.label}.`) tally.broken += 1;
      }
      if (g.comms[c].promise?.cond.kind === cond.kind) tally.pending += 1;
    }
    for (const tally of Object.values(asks)) {
      tally.otherEnded = tally.made - tally.kept - tally.broken - tally.pending;
      if (tally.otherEnded < 0) throw new Error(`${arm}/${seed}: 약속 집계가 중복됐다`);
    }
    return {
      seed, stateHash: createHash('sha256').update(JSON.stringify(g)).digest('hex'),
      end: g.end, complete: g.end === 'complete', settlements, asksOffered, asks, favors,
      rel: Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel])) as Record<Comm, number>,
      unrestNegativePct: COMMS.reduce((sum, c) => sum + (g.comms[c].rel < 0 ? seatMap[c] : 0), 0),
      unrestHudPct: standings(g).unrest, demand, lice, typhus: (g.dom?.stats.typhus ?? 0) > 0,
      coverageObservations: observations, shortageObservations: short, shortageSettlements,
      shortageShare: observations ? short / observations : null, coverageSum,
      coverageMean: observations ? coverageSum / observations : null, plentySettlements: plenty,
      endSupplies: g.supOn ? g.sup ?? 0 : null,
      income: { stop: income['stop.loot'], search: income['sup.search'], field: income['field.loot'], make: income['sup.make'],
        total: income['stop.loot'] + income['sup.search'] + income['field.loot'] + income['sup.make'] },
      injected, made, madeFine, needTotal, usedTotal,
      madeShare: needTotal > 0 ? made / needTotal : null,
      madeUsedShare: usedTotal > 0 ? made / usedTotal : null,
      insulatedCars: g.dom?.insulated.length ?? 0,
      furnishJobs: Object.values(g.dom?.furnish ?? {}).reduce((sum, f) => sum + ('jobs' in f ? f.jobs.length : 0), 0),
      w6RestoredSeg,
    };
  } finally {
    delete SUPPLIES_PROBE.beforeUse;
    delete SUPPLIES_PROBE.afterUse;
    delete SUPPLIES_PROBE.onGain;
    delete SUPPLIES_PROBE.onMake;
    delete SUPPLIES_PROBE.onRestore;
    Object.assign(SUPPLIES_PROBE, keep);
  }
}

function wilson95(wins: number, games: number): [number, number] {
  const z = 1.959963984540054;
  const p = wins / games;
  const den = 1 + z * z / games;
  const mid = (p + z * z / (2 * games)) / den;
  const half = z * Math.sqrt(p * (1 - p) / games + z * z / (4 * games * games)) / den;
  return [Math.max(0, mid - half), Math.min(1, mid + half)];
}

function summarize(rows: Row[]) {
  const sum = (f: (r: Row) => number) => rows.reduce((s, r) => s + f(r), 0);
  const mean = (f: (r: Row) => number) => sum(f) / rows.length;
  const wins = sum(r => Number(r.complete));
  const observations = sum(r => r.coverageObservations);
  const shortage = sum(r => r.shortageObservations);
  const need = sum(r => r.needTotal);
  const used = sum(r => r.usedTotal);
  const restored = rows.filter(r => r.w6RestoredSeg !== null);
  const asks = Object.fromEntries((['give_sup', 'give_fine'] as const).map(kind => [kind, {
    made: sum(r => r.asks[kind].made), kept: sum(r => r.asks[kind].kept),
    broken: sum(r => r.asks[kind].broken), pending: sum(r => r.asks[kind].pending),
    otherEnded: sum(r => r.asks[kind].otherEnded),
  }])) as Row['asks'];
  const made = asks.give_sup.made + asks.give_fine.made;
  const kept = asks.give_sup.kept + asks.give_fine.kept;
  const broken = asks.give_sup.broken + asks.give_fine.broken;
  return {
    stateHash: createHash('sha256').update(rows.map(r => `${r.stateHash}\n`).join('')).digest('hex'),
    asksOffered: sum(r => r.asksOffered), asks, asksMade: made, asksMadeMean: made / rows.length,
    asksKeptShare: kept + broken ? kept / (kept + broken) : null,
    favors: { offered: sum(r => r.favors.offered), granted: sum(r => r.favors.granted),
      fine: sum(r => r.favors.fine), refused: sum(r => r.favors.refused) },
    games: rows.length, wins, completeRate: wins / rows.length, completeWilson95: wilson95(wins, rows.length),
    settlementsMean: mean(r => r.settlements),
    relMean: Object.fromEntries(COMMS.map(c => [c, mean(r => r.rel[c])])) as Record<Comm, number>,
    unrestNegativePctMean: mean(r => r.unrestNegativePct), unrestHudPctMean: mean(r => r.unrestHudPct),
    demandMean: mean(r => r.demand), liceMean: mean(r => r.lice), typhusGames: sum(r => Number(r.typhus)),
    typhusRate: mean(r => Number(r.typhus)), coverageObservations: observations, shortageObservations: shortage,
    shortageSettlements: sum(r => r.shortageSettlements),
    shortageSettlementShare: observations ? sum(r => r.shortageSettlements) / sum(r => r.settlements) : null,
    // 공동체·정산을 한 표본으로 합쳐 계산한다. 수명이 다른 판을 같은 무게로 평균하지 않는다.
    shortageShare: observations ? shortage / observations : null,
    coverageMean: observations ? sum(r => r.coverageSum) / observations : null,
    plentySettlementsMean: mean(r => r.plentySettlements),
    endSuppliesMean: rows[0].endSupplies === null ? null : mean(r => r.endSupplies ?? 0),
    incomeMean: { stop: mean(r => r.income.stop), search: mean(r => r.income.search), field: mean(r => r.income.field), make: mean(r => r.income.make), total: mean(r => r.income.total) },
    injectedMean: mean(r => r.injected),
    madeMean: mean(r => r.made), madeFineMean: mean(r => r.madeFine),
    needTotal: need, usedTotal: used,
    madeShare: need > 0 ? sum(r => r.made) / need : null,
    madeUsedShare: used > 0 ? sum(r => r.made) / used : null,
    insulatedCarsMean: mean(r => r.insulatedCars), furnishJobsMean: mean(r => r.furnishJobs),
    w6RestoredGames: restored.length,
    w6RestoredSegMean: restored.length ? restored.reduce((s, r) => s + r.w6RestoredSeg!, 0) / restored.length : null,
  };
}

type Summary = ReturnType<typeof summarize>;
const resultArms: Partial<Record<Arm, { summary: Summary; games: Row[] }>> = {};
for (const arm of arms) {
  const games = Array.from({ length: n }, (_, i) => run(arm, `sp-${i}`));
  resultArms[arm] = { summary: summarize(games), games };
}
const off = resultArms.off?.summary;
const on = resultArms.on?.summary;
const on3 = resultArms.on3?.summary;
const askChecks = {
  on3CompletionWithin3pp: on && on3 ? Math.abs(on3.completeRate - on.completeRate) <= 0.03 + 1e-9 : null,
  on3AsksAtLeastPoint3AndKept50to90pct: on3?.asksKeptShare != null
    ? on3.asksMadeMean >= 0.3 && on3.asksKeptShare >= 0.5 && on3.asksKeptShare <= 0.9 : null,
  on3ShortageWithinPlus5pp: on?.shortageSettlementShare != null && on3?.shortageSettlementShare != null
    ? on3.shortageSettlementShare - on.shortageSettlementShare <= 0.05 + 1e-9 : null,
  offHashUnchanged: off && baselineOff ? off.stateHash === baselineOff : null,
};
const onBaselineMatches = on && baselineOn ? on.stateHash === baselineOn : null;
const full = resultArms.full?.summary;
const checks = {
  onCompletionWithin5pp: off && on ? on.completeRate - off.completeRate >= -0.05 : null,
  onShortage25to60pct: on?.shortageShare != null ? on.shortageShare >= 0.25 && on.shortageShare <= 0.60 : null,
  fullWithin6ppAndFewerDemands: full && on ? full.completeRate - on.completeRate <= 0.06 && full.demandMean < on.demandMean : null,
  onMoreLice: off && on ? on.liceMean > off.liceMean : null,
};
const none = resultArms.none?.summary;
const first = resultArms.make_first?.summary;
const last = resultArms.make_last?.summary;
const makeChecks = {
  makeFirstCompletionWithinMinus3pp: first && none ? first.completeRate - none.completeRate >= -0.03 - 1e-9 : null,
  makeFirstShareAtMost25pctAndLessShortage: first?.madeShare != null && first.shortageShare != null && none?.shortageShare != null
    ? first.madeShare <= SUP_MAKE.supMakeCap + 1e-9 && first.shortageShare < none.shortageShare : null,
  makeFirstCompletionWithinPlus6pp: first && none ? first.completeRate - none.completeRate <= 0.06 + 1e-9 : null,
  makeFirstFewerInsulatedCars: first && last ? first.insulatedCarsMean < last.insulatedCarsMean : null,
};
const result = {
  gamesPerArm: n, seedPrefix: 'sp-', bot: BASE, arms: resultArms, checks, makeChecks, askChecks,
  baselineOff, baselineOn, onBaselineMatches,
  fullBeforeUseNeeds: FULL_BEFORE_USE_NEEDS,
  definitions: {
    complete: 'end === complete', demandAndLice: 'generated card UIDs, including unpicked final cards',
    unrestNegativePct: 'seats(g), relation < 0', unrestHudPct: 'standings(g).unrest, relation <= -15',
    shortage: 'f < 1, pooled living-community settlement observations', coverage: 'pooled mean of f; off is null',
    shortageSettlements: 'at least one living community has f < 1; divided by all settlements (criterion 3)',
    asks: 'offered counts visible supplies conditions when the bot negotiates; made/kept/broken count exact journal facts; kept share excludes pending and other-ended promises',
    askArms: 'on: pre-third-PR rules, including old favors and idle w8; on3: new asks and prefer an offered supplies condition; both retain on supMake=none and the existing card policy',
    stateHash: 'SHA-256 of newline-terminated per-game SHA-256(JSON.stringify(g)), in seed order; no state fields omitted',
    full: 'top up to (1 + supPlentyNeeds) * need immediately before use, so post-use plenty always holds',
    income: 'actual positive ledger change; excludes initial stock and simulated full top-ups',
    made: 'workshop output, including fine goods; excludes initial stock, loot and full top-ups',
    madeShare: 'sum(made) / sum(suppliesNeed at use); cap uses need, actual consumed denominator is reported separately as madeUsedShare',
    furnishJobs: 'sum of completed furnish.jobs at game end; furniture placements are not workshop jobs',
    w6RestoredSeg: 'segment when w6 completes; null if never completed; mean excludes null',
    makeArms: 'none/on/full: never select w6; make_last: ordinary bot choice, production last; make_first: prioritize available w6 and move sup before restore/modify in its completion settlement',
  },
  parameters: { sup0: P.sup0, supPer100: P.supPer100, supShortRel: P.supShortRel, supPlentyRel: P.supPlentyRel,
    supPlentyNeeds: P.supPlentyNeeds, supDemandCool: P.supDemandCool, supHygieneCover: P.supHygieneCover, supSearch: P.supSearch, yield: SUP_YIELD, make: SUP_MAKE },
};

const num = (v: number | null) => v === null ? '—' : v.toFixed(3);
const pct = (v: number | null) => v === null ? '—' : `${(100 * v).toFixed(2)}%`;
const cells: [string, (s: Summary) => string][] = [
  ['판 수', s => String(s.games)], ['완주 수', s => String(s.wins)], ['완주율', s => pct(s.completeRate)],
  ['모자란 구간 수', s => String(s.shortageSettlements)], ['모자란 구간 몫', s => pct(s.shortageSettlementShare)],
  ['생필품 조건 제시 수', s => String(s.asksOffered)], ['생필품 약속 성립 수', s => String(s.asksMade)],
  ['판당 생필품 약속', s => num(s.asksMadeMean)], ['지킨 몫(정산된 약속)', s => pct(s.asksKeptShare)],
  ...(['give_sup', 'give_fine'] as const).map(k => [`${k} 성립/지킴/깸/미결/기타종료`, (s: Summary) => Object.values(s.asks[k]).join('/')] as [string, (s: Summary) => string]),
  ['부탁 제시/수락/좋은 물건/거절', s => Object.values(s.favors).join('/')],
  ['전체 판 상태 SHA-256', s => s.stateHash],
  ['완주 Wilson 95%', s => s.completeWilson95.map(pct).join(' ~ ')], ['정산 수 평균', s => num(s.settlementsMean)],
  ...COMMS.map(c => [`끝 관계 ${c}`, (s: Summary) => num(s.relMean[c])] as [string, (s: Summary) => string]),
  ['불만 의석 % (관계 <0)', s => num(s.unrestNegativePctMean)], ['화면 불만 의석 % (관계 ≤−15)', s => num(s.unrestHudPctMean)],
  ['요구 카드 평균', s => num(s.demandMean)], ['이 카드 평균', s => num(s.liceMean)], ['발진티푸스 판 수', s => String(s.typhusGames)],
  ['발진티푸스 판 몫', s => pct(s.typhusRate)], ['모자란 공동체·정산 몫', s => pct(s.shortageShare)],
  ['f 평균', s => num(s.coverageMean)], ['넉넉한 정산 수 평균', s => num(s.plentySettlementsMean)],
  ['끝 생필품 평균', s => num(s.endSuppliesMean)], ['정차 입고 평균', s => num(s.incomeMean.stop)],
  ['맡긴 수색 덤 평균', s => num(s.incomeMean.search)], ['필드 입고 평균', s => num(s.incomeMean.field)],
  ['실제 입고 합 평균', s => num(s.incomeMean.total)], ['도구 보충 평균', s => num(s.injectedMean)],
  ['만든 생필품·좋은 물건 평균', s => num(s.madeMean)], ['만든 좋은 물건 평균', s => num(s.madeFineMean)],
  ['필요량 대비 만든 몫', s => pct(s.madeShare)], ['실제 사용량 대비 만든 몫', s => pct(s.madeUsedShare)],
  ['끝 단열 칸 수 평균', s => num(s.insulatedCarsMean)], ['끝 살림 작업 수 평균', s => num(s.furnishJobsMean)],
  ['w6 복원 판 수', s => String(s.w6RestoredGames)], ['w6 복원 구간 평균(복원 판)', s => num(s.w6RestoredSegMean)],
];
console.log(`| 지표 | ${arms.join(' | ')} |\n|---|${arms.map(() => '---:').join('|')}|`);
for (const [label, f] of cells) console.log(`| ${label} | ${arms.map(a => f(resultArms[a]!.summary)).join(' | ')} |`);
console.log('\n| 합격 기준 | 결과 |\n|---|---|');
const labels = ['① on 완주율 ≥ off −5%p', '② on 모자람 25~60%', '③ full 완주율 ≤ on +6%p 및 요구 감소', '④ on 이 카드 > off'];
Object.values(checks).forEach((v, i) => console.log(`| ${labels[i]} | ${v === null ? '미측정(팔 없음)' : String(v)} |`));
console.log('\n| 공방 합격 기준 | 결과 |\n|---|---|');
const makeLabels = ['① make_first 완주율 ≥ none −3%p', '② 만든 몫 ≤25% 및 none보다 모자람 감소', '③ make_first 완주율 ≤ none +6%p', '④ make_first 단열 칸 < make_last'];
Object.values(makeChecks).forEach((v, i) => console.log(`| ${makeLabels[i]} | ${v === null ? '미측정(팔 없음)' : String(v)} |`));
console.log('\n| 부탁·거래 합격 기준 | 결과 |\n|---|---|');
const askLabels = ['① on3 완주율 on ±3%p', '② 판당 약속 ≥0.3 및 지킴 50~90%', '③ 모자람 구간 ≤ on +5%p', '④ off 수정 전 해시 일치'];
Object.values(askChecks).forEach((v, i) => console.log(`| ${askLabels[i]} | ${v === null ? '미측정(팔·기준 없음)' : String(v)} |`));
console.log(`on 수정 전 상태 해시 일치: ${onBaselineMatches === null ? '미측정' : onBaselineMatches}`);
console.log('\nfull: 사용 직전 (1 + supPlentyNeeds)×need 보충(쓴 뒤 늘 넉넉). 불만은 관계 <0과 화면의 ≤−15를 나란히 표시.');
if (out) writeFileSync(out, JSON.stringify(result, null, 2) + '\n', 'utf8');
