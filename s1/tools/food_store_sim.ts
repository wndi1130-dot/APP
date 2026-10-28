// 결정 489 ②: 게임·봇을 바꾸지 않고 afterStop에서 창고 식량만 더한다.
// s1에서: npx tsx tools/food_store_sim.ts [판 수=300] [결과 JSON] [--arms=none,store2,...]
import { createHash } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { forecast, lawActive, lawOpen } from '../src/game';
import type { Game } from '../src/game';
import { playGame } from './s1c_bot';
import type { BotOptions, BotProbe } from './s1c_bot';

const ARMS = {
  none: { multiplier: 0, interval: null },
  store2: { multiplier: 2, interval: [4, 5] },
  'store1.5': { multiplier: 1.5, interval: [4, 5] },
  store2_rare: { multiplier: 2, interval: [6, 7] },
  store1_rare: { multiplier: 1, interval: [6, 7] },
} as const;
type ArmName = keyof typeof ARMS;

// s1c_sim.ts의 무플래그 'S1a+S1c caretaker engaged'와 정확히 같은 옵션.
const BOT_OPTIONS: BotOptions = { s1c: true, policy: 'caretaker', dom: 'engaged' };
const STORE_CAP_SEGMENTS = 2;
const LAW = 'emergency_ration';

interface Delivery {
  stop: number;
  segment: number;
  interval: number;
  segmentFood: number;
  requestedFood: number;
  warehouseCap: number;
  foodBefore: number;
  foodAdded: number;
  foodAfter: number;
}

interface GameResult {
  seed: string;
  completed: boolean;
  end: string;
  segmentReached: number;
  stops: number;
  settlements: number;
  emergencyEligibleSegments: number;
  foodUnder30Segments: number;
  emergencyEverPassed: boolean;
  endFood: number;
  storeFoodAdded: number;
  deliveries: Delivery[];
}

function simulate(seed: string, armName: ArmName): GameResult {
  const arm = ARMS[armName];
  let gapDraw = 0;
  // 판 시드 + 별도 이름공간 + 뽑기 차례. 게임 rng나 arm 이름은 사용하지 않는다.
  // 같은 간격의 팔은 같은 창고 차례, rare 팔은 같은 동전값에 +2를 쓴다.
  const nextGap = (): number => {
    if (!arm.interval) return 0;
    const coin = createHash('sha256').update(`${seed}\0food-store-v1\0${gapDraw++}`).digest()[0] & 1;
    return arm.interval[coin];
  };
  let gap = nextGap();
  let nextStore = arm.interval ? gap : Infinity;
  let stops = 0;
  let settlements = 0;
  let emergencyEligibleSegments = 0;
  let foodUnder30Segments = 0;
  let emergencyEverPassed = false;
  let storeFoodAdded = 0;
  const deliveries: Delivery[] = [];
  // 끝에 폐지됐더라도 한 번 통과한 사실은 보존한다. 표결 뒤 뜨는 감축 카드,
  // 정산, 정차, 출발 준비와 최종 상태를 관찰하며 게임에는 쓰지 않는다.
  const observeLaw = (g: Game): void => { emergencyEverPassed ||= lawActive(g, LAW); };
  const probe: BotProbe = {
    beforePick: observeLaw,
    afterPick: observeLaw,
    beforePrep: observeLaw,
    afterPrep: observeLaw,
    onSettle(g) {
      observeLaw(g);
      settlements += 1;
      if (!lawActive(g, LAW) && lawOpen(g, LAW)) emergencyEligibleSegments += 1;
      if (g.food < 30) foodUnder30Segments += 1;
    },
    afterStop(g) {
      observeLaw(g);
      stops += 1;
      if (stops !== nextStore) return;
      const rngBefore = g.rng;
      // settle()이 실제로 빼는 forecast(g).food: 배급·인구·법·솥·내정 순소모 포함.
      // 순생산인 경우 음수 보급을 하지 않는다. S1 식량 재고에는 별도 상한이 없다.
      const segmentFood = Math.max(0, forecast(g).food);
      if (!Number.isFinite(segmentFood)) throw new Error(`${seed}/${armName}: 식량 예측이 유한하지 않음`);
      const requestedFood = segmentFood * arm.multiplier;
      const warehouseCap = segmentFood * STORE_CAP_SEGMENTS;
      const foodBefore = g.food;
      g.food += Math.min(requestedFood, warehouseCap);
      const foodAdded = g.food - foodBefore;
      if (g.rng !== rngBefore) throw new Error(`${seed}/${armName}: 창고 훅이 게임 rng를 바꿈`);
      storeFoodAdded += foodAdded;
      deliveries.push({ stop: stops, segment: g.seg, interval: gap, segmentFood,
        requestedFood, warehouseCap, foodBefore, foodAdded, foodAfter: g.food });
      gap = nextGap();
      nextStore += gap;
    },
  };
  const { g, m } = playGame(seed, { ...BOT_OPTIONS, probe });
  observeLaw(g);
  if (!Number.isFinite(m.endFood)) throw new Error(`${seed}/${armName}: 판 끝 식량이 유한하지 않음`);
  return {
    seed, completed: m.end === 'complete', end: m.end, segmentReached: m.segReached,
    stops, settlements, emergencyEligibleSegments, foodUnder30Segments,
    emergencyEverPassed, endFood: m.endFood, storeFoodAdded, deliveries,
  };
}

/** 완주율의 Wilson 95% 구간. 0/N·N/N에서도 오차가 0으로 사라지지 않는다. */
function wilson95(successes: number, n: number) {
  const rate = successes / n;
  const z = 1.959963984540054;
  const z2 = z * z;
  const denominator = 1 + z2 / n;
  const center = (rate + z2 / (2 * n)) / denominator;
  const half = z * Math.sqrt(rate * (1 - rate) / n + z2 / (4 * n * n)) / denominator;
  const lower = Math.max(0, center - half);
  const upper = Math.min(1, center + half);
  return { method: 'Wilson 95%', lower, upper, minus: Math.max(0, rate - lower), plus: Math.max(0, upper - rate) };
}

function summarize(games: GameResult[]) {
  const sum = (pick: (g: GameResult) => number) => games.reduce((total, g) => total + pick(g), 0);
  const completedGames = sum(g => Number(g.completed));
  const settlements = sum(g => g.settlements);
  const emergencyEligibleSegments = sum(g => g.emergencyEligibleSegments);
  const foodUnder30Segments = sum(g => g.foodUnder30Segments);
  const emergencyPassedGames = sum(g => Number(g.emergencyEverPassed));
  const ends: Record<string, number> = {};
  for (const g of games) ends[g.end] = (ends[g.end] ?? 0) + 1;
  return {
    games: games.length, completedGames, completionRate: completedGames / games.length,
    completion95: wilson95(completedGames, games.length), ends, unfinishedGames: ends.none ?? 0,
    settlements, emergencyEligibleSegments,
    emergencyEligibleShare: settlements ? emergencyEligibleSegments / settlements : null,
    foodUnder30Segments, foodUnder30Share: settlements ? foodUnder30Segments / settlements : null,
    emergencyPassedGames, emergencyPassedGameShare: emergencyPassedGames / games.length,
    meanEndFood: sum(g => g.endFood) / games.length,
    totalStoreFoodAdded: sum(g => g.storeFoodAdded), meanStoreFoodAdded: sum(g => g.storeFoodAdded) / games.length,
    deliveries: sum(g => g.deliveries.length),
  };
}

function parseArgs(argv: string[]) {
  const positional: string[] = [];
  let selected: ArmName[] = Object.keys(ARMS) as ArmName[];
  let armsSeen = false;
  for (const arg of argv) {
    if (arg.startsWith('--arms=')) {
      if (armsSeen) throw new Error('--arms는 한 번만 지정한다');
      armsSeen = true;
      const names = arg.slice(7).split(',');
      if (names.some(name => !Object.hasOwn(ARMS, name)) || new Set(names).size !== names.length) {
        throw new Error(`--arms: ${Object.keys(ARMS).join(',')} 중 중복 없이 고른다`);
      }
      selected = names as ArmName[];
    } else if (arg.startsWith('--')) throw new Error(`지원하지 않는 옵션: ${arg}`);
    else positional.push(arg);
  }
  if (positional.length > 2) throw new Error('사용: food_store_sim.ts [판 수=300] [결과 JSON] [--arms=...]');
  const n = Number(positional[0] ?? 300);
  if (!Number.isSafeInteger(n) || n < 1) throw new Error('판 수는 1 이상의 안전한 정수여야 한다');
  return { n, out: positional[1], selected };
}

function main() {
  const { n, out, selected } = parseArgs(process.argv.slice(2));
  const runs = selected.map(arm => {
    const games: GameResult[] = [];
    for (let i = 0; i < n; i += 1) {
      games.push(simulate(`fs-${i}`, arm));
      if ((i + 1) % 50 === 0 || i + 1 === n) console.error(`${arm}: ${i + 1}/${n}`);
    }
    return { arm, ...ARMS[arm], summary: summarize(games), games };
  });
  const baselineShare = runs.find(run => run.arm === 'none')?.summary.emergencyEligibleShare ?? null;
  const results = runs.map(run => {
    const share = run.summary.emergencyEligibleShare;
    const ratio = baselineShare !== null && baselineShare > 0 && share !== null ? share / baselineShare : null;
    return { ...run, summary: { ...run.summary, emergencyShareRelativeToNone: ratio,
      meetsHalfBaseline: ratio === null ? null : ratio >= 0.5 } };
  });
  const result = {
    schemaVersion: 1, n, seedPrefix: 'fs-', arms: selected, botOptions: BOT_OPTIONS,
    methodology: {
      botSource: "s1c_sim.ts: S1a+S1c caretaker engaged, no CLI feature flags",
      inheritedDefaults: {
        prologue: true, autoLevers: true, councilDeals: true, contentEvents: true,
        s1b: false, disasters: false, deathWeight: false, arrivals: false,
        climate: false, scoutGear: false, budget: false, eventPack: false,
        forcedCrew: null, forcedPot: null, forcedLoco: null, forcedLaw: null,
      },
      completion: "playGame().m.end === 'complete' (same as s1c_sim.ts)",
      settlementSample: 'Every onSettle callback, including terminal settlement; denominator is all observed settlements, not reached segment or travel-card counts',
      emergencyEligible: "!lawActive(g, 'emergency_ration') && lawOpen(g, 'emergency_ration') after settlement; potential eligibility, not actual agenda selection",
      emergencyPassed: 'Latched lawActive at every probe callback and game end; retains earlier passage after repeal',
      secondaryFoodThreshold: 'g.food < 30 after settlement',
      segmentFood: 'Math.max(0, forecast(g).food) immediately after resolveStop; forecast is also used by settle, including law and domestic net-food effects',
      injection: 'Only g.food is changed, in afterStop; every afterStop is one stop ordinal',
      warehouseCapSegments: STORE_CAP_SEGMENTS,
      inventoryFoodCap: null,
      inventoryFoodCapReason: 'Current S1 ledger.bump/bumpParts impose no upper bound on food',
      schedule: 'SHA-256(seed + NUL + food-store-v1 + NUL + zero-based delivery draw), first byte & 1 selects interval; first delivery also waits a full interval; same coin stream for all arms; g.rng unchanged',
      ratioRule: 'Pooled eligible/settlement share divided by none share; null if none omitted or none share is zero; meets threshold at ratio >= 0.5',
      completionUncertainty: 'Wilson 95% binomial interval; asymmetric error from observed rate',
      interpretation: 'Automatic full recovery, no warehouse labor/time/danger cost or spoiled food; survival and policy choices can change exposure and settlement denominators',
    },
    baselineEmergencyEligibleShare: baselineShare,
    runs: results,
  };
  if (out) writeFileSync(out, `${JSON.stringify(result, null, 2)}\n`, 'utf8');
  const pct = (value: number | null) => value === null ? '—' : `${(100 * value).toFixed(2)}%`;
  console.log(`팔마다 ${n}판, 시드 fs-0…fs-${n - 1}; 봇 ${JSON.stringify(BOT_OPTIONS)}`);
  console.log('완주율 오차는 Wilson 95%의 −/+ %p. 위기 안건 몫은 전체 정산 합산 기준.');
  console.log('\n| 팔 | 완주율 (95% 오차) | 정산 수 | 위기 안건 가능 구간 | none 대비 | 식량 <30 구간 | 위기 법 통과 판 | 평균 끝 식량 | 평균 창고 식량 | 절반 기준 |');
  console.log('|---|---:|---:|---:|---:|---:|---:|---:|---:|---|');
  for (const { arm, summary: s } of results) {
    const ci = s.completion95;
    const completion = `${pct(s.completionRate)} (−${(100 * ci.minus).toFixed(2)}/+${(100 * ci.plus).toFixed(2)}%p)`;
    console.log(`| ${arm} | ${completion} | ${s.settlements} | ${pct(s.emergencyEligibleShare)} (${s.emergencyEligibleSegments}/${s.settlements}) | ${pct(s.emergencyShareRelativeToNone)} | ${pct(s.foodUnder30Share)} | ${pct(s.emergencyPassedGameShare)} | ${s.meanEndFood.toFixed(2)} | ${s.meanStoreFoodAdded.toFixed(2)} | ${s.meetsHalfBaseline === null ? '산정 불가' : s.meetsHalfBaseline ? '충족' : '미달'} |`);
    if (s.unfinishedGames) console.error(`${arm}: ${s.unfinishedGames}판이 봇 5,000걸음 안에 끝나지 않음 (end='none')`);
  }
  if (baselineShare === null || baselineShare === 0) console.error('none 미실행 또는 위기 안건 몫이 0: 상대 비율·절반 기준을 판정하지 않는다.');
  console.log('\n식량: 정산과 같은 forecast(g).food의 정차 직후 순소모(음수는 0), 창고당 최대 2구간.');
  console.log('차례: 판 시드의 별도 SHA-256 동전값, 첫 창고부터 4~5 또는 6~7정차 대기. 게임 rng는 건드리지 않는다.');
}

main();
