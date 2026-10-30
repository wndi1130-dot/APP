// 결정 514: 같은 sp-0… 시드와 생필품 재기의 BASE로 팔 셋을 견준다. 파일은 쓰지 않는다.
// 사용: npx tsx tools/late_sim.ts [판 수=300] [--tune=margin,step,grow] [--lengths-only]
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { COMMS, COMM_NAME, createGame, enableLate, viewCard } from '../src/game';
import { LATE, lateComm, lateKind } from '../src/game/late';
import type { Card, Comm, Game } from '../src/game';
import { playGame } from './s1c_bot';
import type { BotOptions } from './s1c_bot';

const BASE: BotOptions = { s1c: true, policy: 'caretaker', dom: 'engaged' };
const ARMS = ['off', 'base', 'always'] as const;
type Arm = typeof ARMS[number];
const hash = (text: string) => createHash('sha256').update(text).digest('hex');

/** 켜기 표시 하나만 뺀다. 카드·난수·일지·빈 목록 등 다른 상태는 전부 비교한다. */
export function lateStateHash(g: Game): string {
  const { lateOn: _on, ...state } = g;
  return hash(JSON.stringify(state));
}

export function lateLengths() {
  const rows: { kind: string; comm: string; chars: number; body: string; sample: string }[] = [];
  const observe = (g: Game, card: Card, sample: string) => {
    const kind = lateKind(card);
    if (!kind) return;
    enableLate(g);
    const v = viewCard(g, { ...card, late: 2 });
    const branch = kind === 'demand' ? `demand:${v.key === 'demand:engine_shift' ? 'shift' : v.choices[0].id === 'heat_up' ? 'heat' : 'ration'}`
      : kind === 'front_curtain' ? 'travel:front_curtain' : kind;
    rows.push({ kind: branch, comm: COMM_NAME[lateComm(card)], chars: [...v.body].length, body: v.body, sample });
  };
  const add = (kind: string, comm: Comm, patch: Partial<Card> = {}, need?: 'heat' | 'ration' | 'shift') => {
    const g = createGame('late-length');
    if (need) {
      g.comms[comm].heat = need === 'ration' ? 4 : 0;
      g.comms[comm].ration = need === 'heat' ? 4 : 0;
      g.comms[comm].base[3] = need === 'shift' ? 100 : 0;
    }
    observe(g, { uid: 1, kind, comm, ...patch }, `sample/${kind}/${comm}/${need ?? 'first'}`);
  };
  for (const c of COMMS) {
    add('demand', c, {}, 'heat');
    add('demand', c, {}, 'ration');
    if (c === 'engine') add('demand', c, {}, 'shift');
    add('favor', c);
    add('promise_ledger', c);
  }
  add('ration_cut', 'tail');
  add('travel', 'tail', { text: 'front_curtain' });
  // 기존 맞대기 표본의 대표·처지·사건 기억 변주도 읽기만 해 함께 잰다.
  const fixtures = JSON.parse(readFileSync(new URL('../../s2/tests/fixtures/train/card_vectors.json', import.meta.url), 'utf8')) as {
    cases: { name: string; state: Partial<Game>; card: Card }[];
  };
  for (const row of fixtures.cases) {
    if (!lateKind(row.card)) continue;
    observe(Object.assign(createGame('late-length'), structuredClone(row.state)), row.card, row.name);
  }
  const groups = new Map<string, typeof rows>();
  for (const row of rows) {
    const key = `${row.kind}/${row.comm}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key)!.push(row);
  }
  return [...groups.values()].map(group => {
    const longest = group.reduce((a, b) => a.chars >= b.chars ? a : b);
    const overlong = [...new Map(group.filter(r => r.chars > 120).map(r => [r.body, r])).values()];
    return { ...longest, minChars: Math.min(...group.map(r => r.chars)), samples: group.length,
      over120: overlong.length > 0, overlong };
  });
}

function runArm(arm: Arm, n: number) {
  let complete = 0;
  let deferred = 0;
  let automatic = 0;
  let tension = 0;
  const rel = Object.fromEntries(COMMS.map(c => [c, 0])) as Record<Comm, number>;
  const ends: Record<string, number> = {};
  const hashes: string[] = [];
  for (let i = 0; i < n; i++) {
    const seed = `sp-${i}`;
    const { g } = playGame(seed, { ...BASE, late: arm !== 'off', lateAlways: arm === 'always', probe: {
      beforePick: (_g, card, view, idx) => {
        if (view.choices[idx].id !== 'later') return;
        if ((card.late ?? 0) < LATE.max) deferred++; else automatic++;
      },
    } });
    if (!g.end) throw new Error(`${arm}/${seed}: 판이 끝나지 않았다`);
    complete += Number(g.end === 'complete');
    ends[g.end] = (ends[g.end] ?? 0) + 1;
    for (const c of COMMS) rel[c] += g.comms[c].rel;
    tension += g.tension;
    hashes.push(lateStateHash(g));
  }
  for (const c of COMMS) rel[c] /= n;
  return { hashes, summary: { complete, completionPct: complete / n * 100, deferredPerGame: deferred / n,
    automaticPerGame: automatic / n, endRel: rel, endTension: tension / n, ends, stateHash: hash(hashes.join('\n')) } };
}

export function measureLate(n = 300) {
  const arms = Object.fromEntries(ARMS.map(arm => [arm, runArm(arm, n)])) as Record<Arm, ReturnType<typeof runArm>>;
  const mismatches = arms.base.hashes.flatMap((h, i) => h === arms.off.hashes[i] ? [] : [`sp-${i}`]);
  const gapPP = arms.base.summary.completionPct - arms.always.summary.completionPct;
  return { gamesPerArm: n, seedPrefix: 'sp-', bot: BASE, late: { ...LATE },
    arms: Object.fromEntries(ARMS.map(arm => [arm, arms[arm].summary])),
    checks: { alwaysBelowBase: gapPP > 0, baseBelow20Pct: arms.base.summary.completionPct < 20,
      baseEqualsOff: mismatches.length === 0, gapPP, needsTuning: gapPP <= 3, mismatches },
    lengths: lateLengths() };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  const positional = args.filter(a => !a.startsWith('--'));
  const n = Number(positional[0] ?? 300);
  if (!Number.isSafeInteger(n) || n < 1 || positional.length > 1 || args.some(a => a.startsWith('--') && !a.startsWith('--tune=') && a !== '--lengths-only')) {
    throw new Error('사용: late_sim.ts [판 수=300] [--tune=margin,step,grow] [--lengths-only]');
  }
  const tune = args.find(a => a.startsWith('--tune='));
  if (tune) {
    const values = tune.slice(7).split(',').map(Number);
    if (values.length !== 3 || values.some(x => !Number.isFinite(x) || x < 0)) throw new Error('tune 값 셋은 0 이상이어야 한다');
    [LATE.margin, LATE.step, LATE.grow] = values;
  }
  console.log(JSON.stringify(args.includes('--lengths-only') ? lateLengths() : measureLate(n), null, 2));
}
