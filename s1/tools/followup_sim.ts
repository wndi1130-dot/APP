// 콘텐츠 사건의 예약 후속(followup)이 예약한 구간보다 먼저 일반 추첨으로 나온 판과, 같은 사건 카드가 두 장 든 판을 센다.
// 결정 100 기준 봇(새 판 깃발 + 기온 레버)과, 후속을 예약하는 선택지가 보이면 늘 그것을 고르는 팔. 파일은 쓰지 않는다.
// 사용: npx tsx tools/followup_sim.ts [판 수=300] [--seed-prefix=sim-]
import { pathToFileURL } from 'node:url';
import { CONTENT_CARD_KIND, CONTENT_EVENTS } from '../src/game/content';
import type { Card, Game } from '../src/game';
import { NEW_GAME_FLAGS, playGame } from './s1c_bot';
import type { BotOptions, BotProbe } from './s1c_bot';

const BASE: BotOptions = { s1c: true, policy: 'caretaker', dom: 'engaged', ...NEW_GAME_FLAGS, climateLevers: true };
const ARMS = ['base', 'follow'] as const;
type Arm = typeof ARMS[number];

/** 후속을 예약하는 선택지: 'content:<선택지 id>'(사건 id와 함께) */
function schedulingChoices(): Set<string> {
  return new Set(CONTENT_EVENTS.flatMap(ev => ev.choices.filter(ch => ch.effects.some(e => e.type === 'followup')).map(ch => `${ev.id}|content:${ch.id}`)));
}

const held = (g: Game, id: string) => [...g.cards, ...(g.lateCards ?? []), ...(g.deferred ?? [])]
  .filter((c: Card) => c.kind === CONTENT_CARD_KIND && c.text === id).length;

export function followupGame(seed: string, arm: Arm, scheduling: Set<string>) {
  let scheduled = 0, early = 0, double = 0;
  const probe: BotProbe = {
    beforePick: (g, card, view, idx) => {
      if (card.kind !== CONTENT_CARD_KIND || !card.text) return;
      // 같은 사건이 아직 예약 큐에 있는데 카드로 나왔다 = 예약한 구간보다 먼저 일반 추첨으로 들었다.
      if ((g.contentQueue ?? []).some(q => q.id === card.text)) early += 1;
      if (held(g, card.text) >= 2) double += 1;
      if (scheduling.has(`${card.text}|${view.choices[idx]?.special ?? ''}`)) scheduled += 1;
    },
  };
  const forcePick: BotOptions['forcePick'] = arm === 'follow'
    ? (_g, card, view, open) => card.kind === CONTENT_CARD_KIND ? open.find(i => scheduling.has(`${card.text}|${view.choices[i].special ?? ''}`)) : undefined
    : undefined;
  const { m } = playGame(seed, { ...BASE, probe, ...(forcePick ? { forcePick } : {}) });
  return { scheduled, early, double, end: m.end };
}

export function followupSim(games: number, prefix: string) {
  const scheduling = schedulingChoices();
  const arms = Object.fromEntries(ARMS.map(arm => {
    let scheduledGames = 0, earlyGames = 0, doubleGames = 0, earlyPicks = 0, doublePicks = 0, scheduledPicks = 0, finished = 0;
    for (let i = 0; i < games; i++) {
      const r = followupGame(`${prefix}${i}`, arm, scheduling);
      if (r.scheduled > 0) scheduledGames += 1;
      if (r.early > 0) earlyGames += 1;
      if (r.double > 0) doubleGames += 1;
      scheduledPicks += r.scheduled; earlyPicks += r.early; doublePicks += r.double;
      if (r.end === 'complete') finished += 1;
    }
    return [arm, { games, scheduledGames, earlyGames, doubleGames, scheduledPicks, earlyPicks, doublePicks, finished }];
  }));
  return { schedulingChoices: scheduling.size, arms };
}

if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  const games = Number(process.argv.find(a => /^\d+$/.test(a)) ?? 300);
  const prefix = process.argv.find(a => a.startsWith('--seed-prefix='))?.slice(14) ?? 'sim-';
  console.log(JSON.stringify(followupSim(games, prefix), null, 2));
}
