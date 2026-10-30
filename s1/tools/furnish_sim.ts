// 결정 486·489: 게임과 기본 봇을 바꾸지 않고 probe 안에서 정책을 넣는다.
// 사용: npx tsx tools/furnish_sim.ts [판 수=300] [JSON] [--arms=none,front,tail,furn_only]
import { writeFileSync } from 'node:fs';
import {
  COMMS, D, FURNISH_CARS, FURNITURE, finishCheck, furnishOf, nextFurnishWork, placeFurniture,
  restoreCheck, startFinish, startJob, startRestore, techMult, techUsable,
} from '../src/game';
import type { Comm, FurnitureKind, FurnitureSize, Game } from '../src/game';
import { receiveDecor } from '../src/game/domestic/decor';
import { playGame } from './s1c_bot';

const ARMS = ['none', 'front', 'tail', 'furn_only'] as const;
type Arm = typeof ARMS[number];
const INSULATE_ORDER = ['tail1', 'tail2', 'tail3', 'medtech', 'guard', 'front'] as const;
const ORDER: Record<Arm, readonly string[]> = {
  none: FURNISH_CARS,
  front: ['front', 'medtech', 'guard', 'tail1', 'tail2', 'tail3'],
  tail: ['tail1', 'tail2', 'tail3', 'guard', 'medtech', 'front'],
  furn_only: FURNISH_CARS,
};
const TRANSPORT = [
  { kind: 'sled', tech: 'x1', count: 2, wood: 2, scrap: 1, parts: 0 },
  { kind: 'stretcher', tech: 'x1', count: 1, wood: 3, scrap: 0, parts: 0 },
  { kind: 'cart', tech: 'x4', count: 1, wood: 3, scrap: 2, parts: 1 },
  { kind: 'runner', tech: 'x4', count: 2, wood: 0, scrap: 2, parts: 0 },
] as const;
const SIM = { furnitureChance: 0.4, small: 0.6, medium: 0.9, z95: 1.959963984540054, emptyEpsilon: 1e-9 };
type Resources = { wood: number; scrap: number; parts: number };
const resources = (): Resources => ({ wood: 0, scrap: 0, parts: 0 });
const comms = (): Record<Comm, number> => Object.fromEntries(COMMS.map(c => [c, 0])) as Record<Comm, number>;
const mean = (xs: number[]) => xs.reduce((s, x) => s + x, 0) / Math.max(1, xs.length);
const sum = (xs: number[]) => xs.reduce((s, x) => s + x, 0);
const sd = (xs: number[]) => Math.sqrt(mean(xs.map(x => (x - mean(xs)) ** 2)));
const median = (xs: number[]) => { const s = [...xs].sort((a, b) => a - b); return (s[Math.floor((s.length - 1) / 2)] + s[Math.floor(s.length / 2)]) / 2; };
const share = (spent: number, income: number): number | null => income > 0 ? spent / income : spent === 0 ? 0 : null;
const pct = (x: number | null) => x === null ? '미정(수입 0)' : `${(100 * x).toFixed(2)}%`;
const f2 = (x: number) => x.toFixed(2);

/** 게임 RNG와 무관한 판·정차 해시. 팔 이름을 넣지 않아 같은 정차 번호에서 같은 가구를 뽑는다. */
function draw(seed: string, stop: number, lane: string): number {
  let h = 2166136261;
  for (const c of `${seed}:furniture:${stop}:${lane}`) h = Math.imul(h ^ c.charCodeAt(0), 16777619);
  h ^= h >>> 16; h = Math.imul(h, 0x7feb352d); h ^= h >>> 15; h = Math.imul(h, 0x846ca68b); h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}
function rolledFurniture(seed: string, stop: number): FurnitureKind | undefined {
  if (draw(seed, stop, 'arrive') >= SIM.furnitureChance) return undefined;
  const u = draw(seed, stop, 'size');
  const size: FurnitureSize = u < SIM.small ? 'small' : u < SIM.medium ? 'medium' : 'large';
  const kinds = (Object.keys(FURNITURE) as FurnitureKind[]).filter(k => FURNITURE[k].size === size);
  return kinds[Math.floor(draw(seed, stop, 'kind') * kinds.length)];
}

function run(seed: string, arm: Arm) {
  let initialized = false, settlements = 0, stops = 0, woodZero = 0, scrapZero = 0, furnitureArrived = 0, furniturePlaced = 0;
  const income = resources(), transport = resources(), comparison = comms();
  const firstUsableSeg: Record<'w5' | 'w1', number | null> = { w5: null, w1: null };
  const made: Record<string, number> = {};
  const seen = new WeakSet<object>();
  const observe = (g: Game) => {
    if (firstUsableSeg.w5 === null && techMult(g, 'w5') > 0) firstUsableSeg.w5 = g.seg;
    if (firstUsableSeg.w1 === null && techUsable(g, 'w1')) firstUsableSeg.w1 = g.seg;
    // 장부는 64줄만 남기므로 모든 probe 경계에서 새 줄을 읽는다. 비교 불만만 음수이고 보너스·피아노는 양수다.
    for (const row of g.ledger ?? []) if (!seen.has(row)) {
      seen.add(row);
      if (row.why === 'furnish' && row.d < 0 && row.k.startsWith('rel:')) comparison[row.k.slice(4) as Comm] += row.d;
    }
    if (initialized) return;
    initialized = true;
    // 수입은 초기 보유량을 빼고, 버리기 전 실제 양의 유입을 센다. 값의 읽기·쓰기는 그대로 통과시킨다.
    // probe 사이 순증으로 재면 같은 정차의 지출/창고 넘침과 상쇄되므로 도구 안 관측자만 붙인다.
    for (const key of ['wood', 'scrap', 'parts'] as const) {
      let value = g.dom![key];
      Object.defineProperty(g.dom!, key, {
        enumerable: true, configurable: true, get: () => value,
        set: (next: number) => { if (next > value) income[key] += next - value; value = next; },
      });
    }
  };
  const policy = (g: Game) => {
    observe(g);
    if (g.phase === 'end') return;
    const d = g.dom!;
    // e5·w5를 법과 무관하게 복원한다. 가능한 완성판/결함판 마무리를 먼저, 없으면 결함판.
    if (!d.restoring) {
      for (const id of ['e5', 'w5'] as const) {
        if (d.techs[id]?.stage === 'defective' && !finishCheck(g, id) && startFinish(g, id)) break;
        if (!restoreCheck(g, id).full && startRestore(g, id, 'full')) break;
      }
      if (!d.restoring) for (const id of ['e5', 'w5'] as const) if (!restoreCheck(g, id).defect && startRestore(g, id, 'defect')) break;
    }
    observe(g);
    for (const tool of TRANSPORT) {
      if (techMult(g, tool.tech) <= 0) continue;
      while ((made[tool.kind] ?? 0) < tool.count && d.wood >= tool.wood && d.scrap >= tool.scrap && d.parts >= tool.parts) {
        for (const key of ['wood', 'scrap', 'parts'] as const) { d[key] -= tool[key]; transport[key] += tool[key]; }
        made[tool.kind] = (made[tool.kind] ?? 0) + 1;
      }
    }
    if (d.job) return;
    // 모든 팔이 같은 첫 미단열 칸을 먼저 시도한다. 막혔을 때만 작업 팔이 살림으로 넘어가되, 다음 단열 목재는 남긴다(단열 먼저인 사람의 셈).
    const nextInsulation = INSULATE_ORDER.find(car => !d.insulated.includes(car));
    if (nextInsulation && startJob(g, 'insulate', nextInsulation)) return;
    if (arm === 'none' || arm === 'furn_only') return;
    for (const car of ORDER[arm]) {
      const step = nextFurnishWork(g, car);
      if (!step || (step >= 2 && !d.insulated.includes(car))) continue;
      if (startJob(g, 'furnish', car, step)) break;
    }
  };
  const { g, m } = playGame(seed, {
    s1c: true, policy: 'caretaker', dom: 'engaged',
    probe: {
      beforePick: observe, afterPick: policy, beforePrep: policy, afterPrep: observe,
      afterStop(g) {
        observe(g);
        const kind = rolledFurniture(seed, stops++);
        if (kind && arm !== 'none') {
          furnitureArrived += 1;
          receiveDecor(g, [kind]);
          if (ORDER[arm].some(car => placeFurniture(g, car, kind).ok)) furniturePlaced += 1;
        }
        policy(g);
      },
      onSettle(g) {
        observe(g);
        settlements += 1;
        if (g.dom!.wood <= SIM.emptyEpsilon) woodZero += 1;
        if (g.dom!.scrap <= SIM.emptyEpsilon) scrapZero += 1;
        policy(g);
      },
    },
  });
  observe(g);
  if (m.end === 'none') throw new Error(`끝나지 않은 판: ${arm}/${seed}`);
  const tiers = Object.fromEntries(FURNISH_CARS.map(car => [car, furnishOf(g, car).tier]));
  const relations = Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel])) as Record<Comm, number>;
  return {
    seed, end: m.end, complete: m.end === 'complete', settlements, stops, tiers, relations, firstUsableSeg,
    relationSd: sd(COMMS.map(c => relations[c])), comparison,
    woodZero, scrapZero, woodZeroShare: woodZero / Math.max(1, settlements), scrapZeroShare: scrapZero / Math.max(1, settlements),
    endWood: g.dom!.wood, endScrap: g.dom!.scrap,
    tier2Plus: Object.values(tiers).filter(t => t >= 2).length,
    tier3: Object.values(tiers).filter(t => t === 3).length,
    furnishJobs: FURNISH_CARS.reduce((s, car) => s + furnishOf(g, car).work, 0),
    insulated: g.dom!.insulated.filter(car => FURNISH_CARS.some(c => c === car)).length,
    armor: g.dom!.armored.includes('guard'), furnitureArrived, furniturePlaced,
    transport, made, income,
    transportShare: { wood: share(transport.wood, income.wood), scrap: share(transport.scrap, income.scrap), total: share(transport.wood + transport.scrap, income.wood + income.scrap) },
  };
}
type Row = ReturnType<typeof run>;
function wilson(wins: number, n: number): [number, number] {
  const p = wins / n, z = SIM.z95, d = 1 + z * z / n;
  const center = (p + z * z / (2 * n)) / d, half = z * Math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d;
  return [center - half, center + half];
}
function summarize(rows: Row[]) {
  const avg = (key: 'settlements' | 'relationSd' | 'endWood' | 'endScrap' | 'furnishJobs' | 'insulated' | 'woodZeroShare' | 'scrapZeroShare' | 'furnitureArrived' | 'furniturePlaced') => mean(rows.map(r => r[key]));
  const transport = resources(), income = resources();
  for (const key of ['wood', 'scrap', 'parts'] as const) { transport[key] = mean(rows.map(r => r.transport[key])); income[key] = mean(rows.map(r => r.income[key])); }
  const complete = rows.filter(r => r.complete).length;
  const tier2PlusGames = rows.filter(r => r.tier2Plus > 0).length, tier3Games = rows.filter(r => r.tier3 > 0).length;
  const techReach = Object.fromEntries((['w5', 'w1'] as const).map(id => {
    const segments = rows.map(r => r.firstUsableSeg[id]).filter((seg): seg is number => seg !== null);
    return [id, {
      reached: segments.length, missing: rows.length - segments.length, share: segments.length / rows.length,
      mean: segments.length ? mean(segments) : null, median: segments.length ? median(segments) : null,
      min: segments.length ? Math.min(...segments) : null, max: segments.length ? Math.max(...segments) : null,
    }];
  }));
  const byArmor = (armor: boolean) => {
    const group = rows.filter(r => r.armor === armor);
    return { n: group.length, completionRate: group.length ? mean(group.map(r => Number(r.complete))) : null, tailRelation: group.length ? mean(group.map(r => r.relations.tail)) : null, tier3Median: group.length ? median(group.map(r => r.tier3)) : null };
  };
  return {
    n: rows.length, complete, completionRate: complete / rows.length, wilson95: wilson(complete, rows.length),
    settlements: avg('settlements'), totalSettlements: sum(rows.map(r => r.settlements)),
    tier2PlusGames, tier2PlusShare: tier2PlusGames / rows.length, tier3Games, tier3Share: tier3Games / rows.length, techReach,
    tier3Median: median(rows.map(r => r.tier3)), tier3Distribution: Array.from({ length: 7 }, (_, n) => rows.filter(r => r.tier3 === n).length),
    tiers: Object.fromEntries(FURNISH_CARS.map(car => [car, mean(rows.map(r => r.tiers[car]))])),
    relations: Object.fromEntries(COMMS.map(c => [c, mean(rows.map(r => r.relations[c]))])),
    comparison: Object.fromEntries(COMMS.map(c => [c, mean(rows.map(r => r.comparison[c]))])),
    relationSd: avg('relationSd'), woodZeroShare: avg('woodZeroShare'), scrapZeroShare: avg('scrapZeroShare'),
    endWood: avg('endWood'), endScrap: avg('endScrap'), furnishJobs: avg('furnishJobs'), insulated: avg('insulated'),
    furnitureArrived: avg('furnitureArrived'), furniturePlaced: avg('furniturePlaced'), transport, income,
    transportShare: { wood: share(transport.wood, income.wood), scrap: share(transport.scrap, income.scrap), total: share(transport.wood + transport.scrap, income.wood + income.scrap) },
    meanGameTransportShare: Object.fromEntries((['wood', 'scrap', 'total'] as const).map(k => {
      const xs = rows.map(r => r.transportShare[k]).filter((x): x is number => x !== null);
      return [k, { mean: mean(xs), undefinedGames: rows.length - xs.length }];
    })),
    armor: { with: byArmor(true), without: byArmor(false) },
  };
}

const args = process.argv.slice(2), positional = args.filter(x => !x.startsWith('--'));
const n = Number(positional[0] ?? 300);
if (!Number.isInteger(n) || n < 1 || positional.length > 2 || args.some(x => x.startsWith('--') && !x.startsWith('--arms='))) throw new Error('사용: furnish_sim.ts [양의 정수=300] [JSON] [--arms=none,front,tail,furn_only]');
const names = (args.find(x => x.startsWith('--arms='))?.slice(7) ?? ARMS.join(',')).split(',');
if (!names.length || new Set(names).size !== names.length || names.some(x => !ARMS.includes(x as Arm))) throw new Error('팔은 중복 없이 none,front,tail,furn_only 중에서 고른다');
const arms = names as Arm[];
const results: Partial<Record<Arm, { summary: ReturnType<typeof summarize>; rows: Row[] }>> = {};
console.log(`시드 fu-0…fu-${n - 1}, S1a+S1c caretaker engaged, 팔마다 ${n}판`);
console.log('| 팔 | 완주(95% Wilson) | 정산 평균 | 2단 이상 판 | 3단 판 | 3단 칸 중앙값 | 분포 0/1/2/3/4/5/6 | 관계 SD | 목재/고철 바닥 | 끝 목재/고철 | 살림 작업/단열 칸 |');
console.log('|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|');
for (const arm of arms) {
  const rows = Array.from({ length: n }, (_, i) => run(`fu-${i}`, arm));
  const s = summarize(rows);
  results[arm] = { summary: s, rows };
  console.log(`| ${arm} | ${pct(s.completionRate)} (${s.wilson95.map(pct).join('–')}) | ${f2(s.settlements)} | ${pct(s.tier2PlusShare)} | ${pct(s.tier3Share)} | ${s.tier3Median} | ${s.tier3Distribution.join('/')} | ${f2(s.relationSd)} | ${pct(s.woodZeroShare)}/${pct(s.scrapZeroShare)} | ${f2(s.endWood)}/${f2(s.endScrap)} | ${f2(s.furnishJobs)}/${f2(s.insulated)} |`);
}
console.log('\n| 팔 | 기술 | 닿은 판 | 첫 사용 구간 평균/중앙값/최소/최대 | 닿지 못한 판 |\n|---|---|---:|---|---:|');
for (const arm of arms) for (const id of ['w5', 'w1'] as const) {
  const t = results[arm]!.summary.techReach[id];
  console.log(`| ${arm} | ${id} | ${t.reached}/${n} (${pct(t.share)}) | ${[t.mean, t.median, t.min, t.max].map(x => x === null ? '—' : f2(x)).join('/')} | ${t.missing} |`);
}
console.log('\n| 팔 | 운반 지출 목재/고철/부품 | 수입 목재/고철 | 지출 몫 목재/고철/합산 |');
console.log('|---|---:|---:|---:|');
for (const arm of arms) {
  const s = results[arm]!.summary;
  console.log(`| ${arm} | ${f2(s.transport.wood)}/${f2(s.transport.scrap)}/${f2(s.transport.parts)} | ${f2(s.income.wood)}/${f2(s.income.scrap)} | ${pct(s.transportShare.wood)}/${pct(s.transportShare.scrap)}/${pct(s.transportShare.total)} |`);
}
for (const field of ['tiers', 'relations', 'comparison'] as const) {
  const keys = field === 'tiers' ? [...FURNISH_CARS] : [...COMMS];
  console.log(`\n${field} (판 평균)\n| 팔 | ${keys.join(' | ')} |\n|---|${keys.map(() => '---:|').join('')}`);
  for (const arm of arms) {
    const values = results[arm]!.summary[field] as Record<string, number>;
    console.log(`| ${arm} | ${keys.map(k => f2(values[k])).join(' | ')} |`);
  }
}
console.log('\n| 팔 | 장갑 | 판 수 | 완주 | 꼬리칸 관계 | 3단 중앙값 |\n|---|---|---:|---:|---:|---:|');
for (const arm of arms) for (const key of ['with', 'without'] as const) {
  const s = results[arm]!.summary.armor[key];
  console.log(`| ${arm} | ${key} | ${s.n} | ${s.completionRate === null ? '표본 없음' : pct(s.completionRate)} | ${s.tailRelation === null ? '—' : f2(s.tailRelation)} | ${s.tier3Median ?? '—'} |`);
}
const base = results.none?.summary;
// ①은 단열 먼저인 팔(tail·furn_only)만 본다. 앞칸부터는 꼬리칸 몫을 빼앗는 정치의 값이라 따로 적는다.
const completionByArm = Object.fromEntries(arms.filter(a => a === 'tail' || a === 'furn_only').map(a => [a, base ? results[a]!.summary.completionRate - base.completionRate >= -0.02 - 1e-12 : null]));
const tail = results.tail?.summary;
const tailTierShares = tail ? {
  tier2Plus30to70: tail.tier2PlusShare >= 0.3 && tail.tier2PlusShare <= 0.7,
  tier3_5to30: tail.tier3Share >= 0.05 && tail.tier3Share <= 0.3,
} : null;
const transportByArm = Object.fromEntries(arms.map(a => [a, results[a]!.summary.transportShare.total !== null && results[a]!.summary.transportShare.total! <= 0.1]));
const gates = {
  completionWithin2pp: base && Object.keys(completionByArm).length ? Object.values(completionByArm).every(Boolean) : null,
  frontTailLower: results.front && results.tail ? results.tail.summary.completionRate - results.front.summary.completionRate >= 0.03 : null,
  tailTierSharesInRange: tailTierShares ? Object.values(tailTierShares).every(Boolean) : null,
  transportWithin10pct: Object.values(transportByArm).every(Boolean),
};
console.log(`\n합격: ① ${gates.completionWithin2pp} · ② ${gates.frontTailLower} · ③ ${gates.tailTierSharesInRange} · ④ ${gates.transportWithin10pct}`);
const output = {
  n, seeds: 'fu-0…', options: { s1c: true, policy: 'caretaker', dom: 'engaged' }, arms,
  definitions: {
    income: '초기 보유 제외, 창고 버리기 전 양의 유입. 부품 생산은 부품 수입으로 따로 기록. 정책은 환불하지 않음.',
    comparison: 'furnish 까닭의 실제 음수 관계 변화 합(관계 하한 반영). 관계 SD는 기관실 포함 다섯 공동체의 모집단 표준편차.',
    aggregation: '0인 정산 몫은 판별 몫의 평균. 운반 몫은 총 지출/총 수입과 판별 몫 평균을 모두 저장.',
    gate1: 'tail·furn_only 팔의 none 대비 완주율 차이가 -2%p 이상(점추정). front의 차이는 따로 적는다.',
    gate2: 'tail 팔 완주율 − front 팔 완주율 >= 3%p(누구 칸부터가 판을 가름). 비교 불만 합은 따로 적는다.',
    gate3: 'tail 팔에서 2단 이상 칸이 있는 판 30~70% 그리고 3단 칸이 있는 판 5~30%(양 끝 포함).',
    gate4: '모든 팔의 총 운반 목재+고철 지출/총 목재+고철 수입 <= 10%. 부품은 별도 보고.',
    policy: '모든 팔이 tail1→tail2→tail3→medtech→guard→front의 첫 미단열 칸을 우선한다. 그 단열을 못 하면 front·tail만 팔 순서의 첫 가능한 살림 작업을 한다. 2·3단은 이미 단열된 칸만. 모든 판의 끝을 포함하며 생존자만 고르지 않음.',
    techReach: '판별 firstUsableSeg: w5는 techMult > 0, w1은 techUsable인 첫 관측 구간. 닿지 못하면 null. 평균·중앙값·범위는 닿은 판만.',
    insulated: '판 끝 사람이 사는 객차 여섯 칸 중 단열된 칸 수. 판별 수와 전체 판 평균을 저장.',
  },
  constants: { simulation: SIM, transport: TRANSPORT, insulationOrder: INSULATE_ORDER, furnitureCap: D.furnishFurnitureCap, threshold: D.furnishThreshold },
  gates, gateDetails: { completionByArm, tailTierShares, transportByArm }, results,
};
if (positional[1]) writeFileSync(positional[1], `${JSON.stringify(output, null, 2)}\n`);
