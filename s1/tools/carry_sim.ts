// 「왜 다 태우고 가나」 재기(결정 425, carry_people.md 4장): 「태우고 간다」와 「줄인다」 두 정책의 완주를 견준다.
// 사용: npx tsx tools/carry_sim.ts [판 수=1000] [--only=caretaker|engaged]
//   태우고 간다: 서막에서 다섯을 약속하고 운반조부터 부른다, 사람 들어옴 카드는 모두 태우거나 데리러 간다.
//   줄인다: 서막에서 약속하지 않고 바로 돌아선다, 사람 들어옴 카드는 돌려보내거나 지금은 못 간다고 한다.
// 사람 들어옴(arrivals.ts)은 켠 판으로 돈다. 그 밖의 카드는 봇 규칙대로다.
import { COMMS } from '../src/game';
import type { Card, CardView, Game } from '../src/game';
import { playGame } from './s1c_bot';
import type { BotOptions, GameMetrics } from './s1c_bot';

const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
const flags = process.argv.slice(2).filter(a => a.startsWith('--'));
const N = Number(args[0] ?? 1000);
const only = flags.find(x => x.startsWith('--only='))?.slice(7);

const ARRIVAL_KINDS = ['arrival', 'family'];
const TAKE = ['take_all', 'escort', 'fetch', 'take_some'];
const SHED = ['turn_away', 'turn_away_law', 'stay_put'];

function picker(prefer: string[]) {
  return (_g: Game, card: Card, view: CardView, open: number[]): number | undefined => {
    if (!ARRIVAL_KINDS.includes(card.kind)) return undefined;
    for (const id of prefer) {
      const i = view.choices.findIndex(c => c.id === id && !c.disabled);
      if (i >= 0 && open.includes(i)) return i;
    }
    return undefined;
  };
}

const BASES: [string, BotOptions][] = [
  ['S1a caretaker', { s1c: false, policy: 'caretaker', dom: 'idle', arrivals: true }],
  ['S1a+S1c caretaker engaged', { s1c: true, policy: 'caretaker', dom: 'engaged', arrivals: true }],
];
const POLICIES: [string, Partial<BotOptions>][] = [
  ['태우고 간다', { prologuePicks: [0, 0, 0], forcePick: picker(TAKE) }],
  ['줄인다', { prologuePicks: [1, 2, 0], forcePick: picker(SHED) }],
];

const mean = (xs: number[]) => xs.reduce((s, x) => s + x, 0) / Math.max(1, xs.length);
const t0 = Date.now();
for (const [baseName, base] of BASES.filter(([n]) => !only || n.includes(only))) {
  for (const [name, pol] of POLICIES) {
    const ms: GameMetrics[] = [];
    const pops: number[] = [];
    for (let i = 0; i < N; i += 1) {
      const { g, m } = playGame(`sim-${i}`, { ...base, ...pol } as BotOptions);
      ms.push(m);
      pops.push(COMMS.reduce((s, c) => s + g.comms[c].pop, 0));
    }
    const done = ms.filter(m => m.end === 'complete').length / N;
    console.log(`${baseName.padEnd(26)} ${name.padEnd(6)} 완주 ${(100 * done).toFixed(1)}% · 끝 인구 ${mean(pops).toFixed(1)} · 죽음 ${mean(ms.map(m => m.deaths)).toFixed(2)} · 석탄최저 ${mean(ms.map(m => m.coalMin)).toFixed(1)} · 식량최저 ${mean(ms.map(m => m.foodMin)).toFixed(1)} · 도달 구간 ${mean(ms.map(m => m.segReached)).toFixed(1)}`);
  }
}
console.log(`(${N}판씩, ${((Date.now() - t0) / 1000).toFixed(1)}초)`);
