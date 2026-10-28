// 결정 490 첫째 PR: 실제 S1a+S1c caretaker engaged 봇, 같은 sp-0… 시드.
// 사용: npx tsx tools/supplies_sim.ts [판 수=300] [JSON 경로] [--arms=off,on,full]
// full은 쓰기 직전 (1 + supPlentyNeeds)×need까지 보충해, 쓴 뒤에도 늘 넉넉함(2×need)이 선다 — 「늘 손에 넣는 길」의 위 끝.
import { writeFileSync } from 'node:fs';
import { COMMS, P, seats, standings } from '../src/game';
import type { Comm, Game } from '../src/game';
import { SUP_YIELD, SUPPLIES_PROBE } from '../src/game/supplies';
import type { SuppliesSource } from '../src/game/supplies';
import { playGame } from './s1c_bot';
import type { BotOptions } from './s1c_bot';

const ARMS = ['off', 'on', 'full'] as const;
type Arm = typeof ARMS[number];
const BASE: BotOptions = { s1c: true, policy: 'caretaker', dom: 'engaged' };
const FULL_BEFORE_USE_NEEDS = 1 + P.supPlentyNeeds;
const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
const flags = process.argv.slice(2).filter(a => a.startsWith('--'));
const n = Number(args[0] ?? 300);
const out = args[1];
if (!Number.isSafeInteger(n) || n < 1) throw new Error('판 수는 1 이상의 정수여야 한다');
if (args.length > 2 || flags.some(f => !f.startsWith('--arms=')) || flags.length > 1) {
  throw new Error('사용: supplies_sim.ts [판 수=300] [JSON] [--arms=off,on,full]');
}
const selected = flags[0]?.slice('--arms='.length).split(',') ?? [...ARMS];
if (!selected.length || selected.some(a => !ARMS.includes(a as Arm)) || new Set(selected).size !== selected.length) {
  throw new Error('--arms는 off,on,full 중 겹치지 않게 고른다');
}
const arms = selected as Arm[];

interface Row {
  seed: string;
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
  shortageShare: number | null;
  coverageSum: number;
  coverageMean: number | null;
  plentySettlements: number;
  endSupplies: number | null;
  income: { stop: number; search: number; field: number; total: number };
  injected: number;
}

function run(arm: Arm, seed: string): Row {
  let settlements = 0;
  let uses = 0;
  let observations = 0;
  let short = 0;
  let coverageSum = 0;
  let plenty = 0;
  let injected = 0;
  const income: Record<SuppliesSource, number> = { 'stop.loot': 0, 'sup.search': 0, 'field.loot': 0 };
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
      if (turn.plenty) plenty += 1;
      for (const f of Object.values(turn.cover)) {
        observations += 1;
        if (f < 1) short += 1;
        coverageSum += f;
      }
    };
    SUPPLIES_PROBE.onGain = (_g, amount, source) => { income[source] += amount; };
    const { g } = playGame(seed, { ...BASE, sup: arm !== 'off', probe: {
      beforePick: observeCards, afterPick: observeCards, beforePrep: observeCards, afterStop: observeCards,
      onSettle: x => { settlements += 1; observeCards(x); },
    } });
    observeCards(g);
    if (!g.end) throw new Error(`${arm}/${seed}: 봇이 판 끝에 닿지 못했다`);
    if (arm !== 'off' && uses !== settlements) throw new Error(`${arm}/${seed}: 사용 ${uses}회와 정산 ${settlements}회가 다르다`);
    const seatMap = seats(g);
    return {
      seed, end: g.end, complete: g.end === 'complete', settlements,
      rel: Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel])) as Record<Comm, number>,
      unrestNegativePct: COMMS.reduce((sum, c) => sum + (g.comms[c].rel < 0 ? seatMap[c] : 0), 0),
      unrestHudPct: standings(g).unrest, demand, lice, typhus: (g.dom?.stats.typhus ?? 0) > 0,
      coverageObservations: observations, shortageObservations: short,
      shortageShare: observations ? short / observations : null, coverageSum,
      coverageMean: observations ? coverageSum / observations : null, plentySettlements: plenty,
      endSupplies: g.supOn ? g.sup ?? 0 : null,
      income: { stop: income['stop.loot'], search: income['sup.search'], field: income['field.loot'],
        total: income['stop.loot'] + income['sup.search'] + income['field.loot'] },
      injected,
    };
  } finally {
    delete SUPPLIES_PROBE.beforeUse;
    delete SUPPLIES_PROBE.afterUse;
    delete SUPPLIES_PROBE.onGain;
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
  return {
    games: rows.length, wins, completeRate: wins / rows.length, completeWilson95: wilson95(wins, rows.length),
    settlementsMean: mean(r => r.settlements),
    relMean: Object.fromEntries(COMMS.map(c => [c, mean(r => r.rel[c])])) as Record<Comm, number>,
    unrestNegativePctMean: mean(r => r.unrestNegativePct), unrestHudPctMean: mean(r => r.unrestHudPct),
    demandMean: mean(r => r.demand), liceMean: mean(r => r.lice), typhusGames: sum(r => Number(r.typhus)),
    typhusRate: mean(r => Number(r.typhus)), coverageObservations: observations, shortageObservations: shortage,
    // 공동체·정산을 한 표본으로 합쳐 계산한다. 수명이 다른 판을 같은 무게로 평균하지 않는다.
    shortageShare: observations ? shortage / observations : null,
    coverageMean: observations ? sum(r => r.coverageSum) / observations : null,
    plentySettlementsMean: mean(r => r.plentySettlements),
    endSuppliesMean: rows[0].endSupplies === null ? null : mean(r => r.endSupplies ?? 0),
    incomeMean: { stop: mean(r => r.income.stop), search: mean(r => r.income.search), field: mean(r => r.income.field), total: mean(r => r.income.total) },
    injectedMean: mean(r => r.injected),
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
const full = resultArms.full?.summary;
const checks = {
  onCompletionWithin5pp: off && on ? on.completeRate - off.completeRate >= -0.05 : null,
  onShortage25to60pct: on?.shortageShare != null ? on.shortageShare >= 0.25 && on.shortageShare <= 0.60 : null,
  fullWithin6ppAndFewerDemands: full && on ? full.completeRate - on.completeRate <= 0.06 && full.demandMean < on.demandMean : null,
  onMoreLice: off && on ? on.liceMean > off.liceMean : null,
};
const result = {
  gamesPerArm: n, seedPrefix: 'sp-', bot: BASE, arms: resultArms, checks,
  fullBeforeUseNeeds: FULL_BEFORE_USE_NEEDS,
  definitions: {
    complete: 'end === complete', demandAndLice: 'generated card UIDs, including unpicked final cards',
    unrestNegativePct: 'seats(g), relation < 0', unrestHudPct: 'standings(g).unrest, relation <= -15',
    shortage: 'f < 1, pooled living-community settlement observations', coverage: 'pooled mean of f; off is null',
    full: 'top up to (1 + supPlentyNeeds) * need immediately before use, so post-use plenty always holds',
    income: 'actual positive ledger change; excludes initial stock and simulated full top-ups',
  },
  parameters: { sup0: P.sup0, supPer100: P.supPer100, supShortRel: P.supShortRel, supPlentyRel: P.supPlentyRel,
    supPlentyNeeds: P.supPlentyNeeds, supDemandCool: P.supDemandCool, supHygieneCover: P.supHygieneCover, supSearch: P.supSearch, yield: SUP_YIELD },
};

const num = (v: number | null) => v === null ? '—' : v.toFixed(3);
const pct = (v: number | null) => v === null ? '—' : `${(100 * v).toFixed(2)}%`;
const cells: [string, (s: Summary) => string][] = [
  ['판 수', s => String(s.games)], ['완주 수', s => String(s.wins)], ['완주율', s => pct(s.completeRate)],
  ['완주 Wilson 95%', s => s.completeWilson95.map(pct).join(' ~ ')], ['정산 수 평균', s => num(s.settlementsMean)],
  ...COMMS.map(c => [`끝 관계 ${c}`, (s: Summary) => num(s.relMean[c])] as [string, (s: Summary) => string]),
  ['불만 의석 % (관계 <0)', s => num(s.unrestNegativePctMean)], ['화면 불만 의석 % (관계 ≤−15)', s => num(s.unrestHudPctMean)],
  ['요구 카드 평균', s => num(s.demandMean)], ['이 카드 평균', s => num(s.liceMean)], ['발진티푸스 판 수', s => String(s.typhusGames)],
  ['발진티푸스 판 몫', s => pct(s.typhusRate)], ['모자란 공동체·정산 몫', s => pct(s.shortageShare)],
  ['f 평균', s => num(s.coverageMean)], ['넉넉한 정산 수 평균', s => num(s.plentySettlementsMean)],
  ['끝 생필품 평균', s => num(s.endSuppliesMean)], ['정차 입고 평균', s => num(s.incomeMean.stop)],
  ['맡긴 수색 덤 평균', s => num(s.incomeMean.search)], ['필드 입고 평균', s => num(s.incomeMean.field)],
  ['실제 입고 합 평균', s => num(s.incomeMean.total)], ['도구 보충 평균', s => num(s.injectedMean)],
];
console.log(`| 지표 | ${arms.join(' | ')} |\n|---|${arms.map(() => '---:').join('|')}|`);
for (const [label, f] of cells) console.log(`| ${label} | ${arms.map(a => f(resultArms[a]!.summary)).join(' | ')} |`);
console.log('\n| 합격 기준 | 결과 |\n|---|---|');
const labels = ['① on 완주율 ≥ off −5%p', '② on 모자람 25~60%', '③ full 완주율 ≤ on +6%p 및 요구 감소', '④ on 이 카드 > off'];
Object.values(checks).forEach((v, i) => console.log(`| ${labels[i]} | ${v === null ? '미측정(팔 없음)' : String(v)} |`));
console.log('\nfull: 사용 직전 (1 + supPlentyNeeds)×need 보충(쓴 뒤 늘 넉넉). 불만은 관계 <0과 화면의 ≤−15를 나란히 표시.');
if (out) writeFileSync(out, JSON.stringify(result, null, 2) + '\n', 'utf8');
