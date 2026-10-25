// 「왜 다 태우고 가나」 재기(결정 425, carry_people.md 4장): 「태우고 간다」와 「줄인다」 두 정책의 완주를 견준다.
// 사용: npx tsx tools/carry_sim.ts [판 수=1000] [--only=caretaker|engaged]
//   태우고 간다: 서막에서 다섯을 약속하고 운반조부터 부른다, 사람 들어옴 카드는 모두 태우거나 데리러 간다(두고 온 사람의 흔적은 기다렸다 태운다).
//   줄인다: 서막에서 약속하지 않고 바로 돌아선다, 사람 들어옴 카드는 돌려보내거나 지금은 못 간다고 한다(흔적엔 쪽지만 남긴다).
// 사람 들어옴(arrivals.ts)은 켠 판으로 돈다. 그 밖의 카드는 봇 규칙대로다.
// 손 몫 줄(결정 425-1): 정산마다 handsNow를 읽어, 한 번이라도 일이 빈 판과 그 까닭(모두 뜻 1이어도 모자람 = 사람 탓, 아니면 뜻 탓),
// 일마다 한 번이라도 빈 판, 판마다 가장 적은 손과 가장 적은 여유(낸 손 − 드는 손)를 센다. 읽기만 하고 판을 바꾸지 않는다.
import { COMMS, HANDS, handsNow, workShare } from '../src/game';
import type { Card, CardView, Game, HandJob } from '../src/game';
import { playGame } from './s1c_bot';
import type { BotOptions, GameMetrics } from './s1c_bot';

const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
const flags = process.argv.slice(2).filter(a => a.startsWith('--'));
const N = Number(args[0] ?? 1000);
const only = flags.find(x => x.startsWith('--only='))?.slice(7);

const ARRIVAL_KINDS = ['arrival', 'family', 'pro_trail'];
const TAKE = ['take_all', 'escort', 'fetch', 'take_some', 'trail_wait'];
const SHED = ['turn_away', 'turn_away_law', 'stay_put', 'trail_note'];

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
const pc = (x: number) => `${(100 * x).toFixed(1)}%`;
const NEED = HANDS.order.reduce((s, j) => s + HANDS.need[j], 0);
/** 모든 칸이 뜻 1로 낸다면 나올 손(사람만 센 손) */
const peopleHands = (g: Game) => COMMS.reduce((s, c) => s + Math.max(0, g.comms[c].pop - g.comms[c].away) * workShare(c), 0) - g.injured;
const t0 = Date.now();
for (const [baseName, base] of BASES.filter(([n]) => !only || n.includes(only))) {
  for (const [name, pol] of POLICIES) {
    const ms: GameMetrics[] = [];
    const pops: number[] = [];
    let shortGames = 0; let peopleShort = 0; let willShort = 0;
    const jobShort = Object.fromEntries(HANDS.order.map(j => [j, 0])) as Record<HandJob, number>;
    const slacks: number[] = []; const lows: number[] = [];
    for (let i = 0; i < N; i += 1) {
      let short = false; let byPeople = false; let byWill = false; let low = Infinity;
      const jobs = new Set<HandJob>();
      const probe = {
        onSettle: (g: Game) => {
          const h = handsNow(g);
          low = Math.min(low, h.have);
          for (const j of HANDS.order) if (h.short[j] > 0.01) jobs.add(j);
          if (HANDS.order.some(j => h.short[j] > 0.01)) {
            short = true;
            if (peopleHands(g) < NEED) byPeople = true; else byWill = true;
          }
        },
      };
      const { g, m } = playGame(`sim-${i}`, { ...base, ...pol, probe } as BotOptions);
      ms.push(m);
      const pop = COMMS.reduce((s, c) => s + g.comms[c].pop, 0);
      pops.push(pop);
      if (short) shortGames += 1;
      if (byPeople) peopleShort += 1;
      if (byWill) willShort += 1;
      for (const j of jobs) jobShort[j] += 1;
      if (Number.isFinite(low)) { lows.push(low); slacks.push(low - NEED); }
    }
    const done = ms.filter(m => m.end === 'complete').length / N;
    console.log(`${baseName.padEnd(26)} ${name.padEnd(6)} 완주 ${(100 * done).toFixed(1)}% · 끝 인구 ${mean(pops).toFixed(1)} · 죽음 ${mean(ms.map(m => m.deaths)).toFixed(2)} · 석탄최저 ${mean(ms.map(m => m.coalMin)).toFixed(1)} · 식량최저 ${mean(ms.map(m => m.foodMin)).toFixed(1)} · 도달 구간 ${mean(ms.map(m => m.segReached)).toFixed(1)}`);
    console.log(`${''.padEnd(33)} 손 몫: 일이 빈 판 ${pc(shortGames / N)}(사람 탓 ${pc(peopleShort / N)} · 뜻 탓 ${pc(willShort / N)}) · 일마다 ${HANDS.order.map(j => `${j} ${pc(jobShort[j] / N)}`).join(' ')} · 가장 적은 손 평균 ${mean(lows).toFixed(1)}(최저 ${Math.min(...lows).toFixed(1)}) · 가장 적은 여유 평균 ${mean(slacks).toFixed(1)}명`);
  }
}
console.log(`(${N}판씩, ${((Date.now() - t0) / 1000).toFixed(1)}초)`);
