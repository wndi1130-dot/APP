import { describe, expect, it } from 'vitest';
import { agendaNeed, blocs, createGame, expected, isLawAgenda, LAWS, needTick, openCouncil } from '../../src/game';
import type { Game } from '../../src/game';
import { caretakerAgendaIdx, council } from '../../tools/s1c_bot';
import type { BotOptions } from '../../tools/s1c_bot';

// 봇(돌보는 정책)은 법 요구가 떠 있는 묶음의 법을 하나는 세운다. 고치는 것은 재는 자이고 게임의 값은 안 바뀐다.

const OPTS: BotOptions = { s1c: false, policy: 'caretaker', dom: 'idle' };
type Opt = NonNullable<Game['council']>['options'][number];
const SEEDS = ['bn-0', 'bn-1', 'bn-2', 'bn-3', 'bn-4', 'bn-5', 'bn-6', 'bn-7'];

function opened(seed: string, setup: (g: Game) => void): Game {
  const g = createGame(seed);
  setup(g);
  needTick(g, []);
  openCouncil(g);
  return g;
}
const base = (g: Game, o: Opt): number => expected(blocs(g, o, g.council!.deals)).mean - agendaNeed(o) + (isLawAgenda(o) && LAWS[o.law].tag === '가혹' ? -1.5 : 0);
/** 요구가 없을 때 옛 규칙이 고르던 번호 */
function oldIdx(g: Game): number {
  let best = -99; let idx = 0;
  g.council!.options.forEach((o, i) => {
    const sc = base(g, o) + (isLawAgenda(o) && o.repeal ? -3 : 0) + (o.forced ? 5 : 0);
    if (sc > best) { best = sc; idx = i; }
  });
  return idx;
}
const coldIdx = (g: Game): number[] => g.council!.options.flatMap((o, i) => (isLawAgenda(o) && !o.repeal && LAWS[o.law].group === '추위' ? [i] : []));
function argmax(g: Game, xs: number[]): number {
  let best = -Infinity; let at = -1;
  for (const i of xs) { const sc = base(g, g.council!.options[i]!); if (sc > best) { best = sc; at = i; } }
  return at;
}

describe('봇의 법 요구 묶음 고르기', () => {
  it('추위 요구가 떠 있고 목록에 추위 묶음의 법이 있으면 그 묶음에서 점수가 가장 높은 것을 고른다(폐지 아님)', () => {
    let checked = 0; let moved = 0; let several = 0;
    for (const s of SEEDS) {
      const g = opened(s, x => { x.coal = 45; });
      const cold = coldIdx(g);
      if (cold.length === 0) continue;
      checked += 1;
      if (cold.length > 1) several += 1;
      if (!cold.includes(oldIdx(g))) moved += 1;
      const i = caretakerAgendaIdx(g, OPTS);
      expect(cold).toContain(i);
      expect(i).toBe(argmax(g, cold));
      const o = g.council!.options[i]!;
      expect(isLawAgenda(o) && o.repeal).toBeFalsy();
    }
    expect(checked).toBeGreaterThan(0);
    expect(moved).toBeGreaterThan(0);
    expect(several).toBeGreaterThan(0);
  });

  it('강제 회기에서도 같다', () => {
    let checked = 0; let forcedSeen = 0;
    for (const s of SEEDS) {
      const g = opened(s, x => { x.coal = 15; });
      if (g.council!.options[0]?.forced) forcedSeen += 1;
      const cold = coldIdx(g);
      if (cold.length === 0) continue;
      checked += 1;
      expect(caretakerAgendaIdx(g, OPTS)).toBe(argmax(g, cold));
    }
    expect(forcedSeen).toBeGreaterThan(0);
    expect(checked).toBeGreaterThan(0);
  });

  it('고른 안건으로 실제 표결을 한다', () => {
    const g = opened('bn-0', x => { x.coal = 45; });
    const cold = coldIdx(g);
    expect(cold.length).toBeGreaterThan(0);
    const a = council(g, OPTS);
    expect(a && isLawAgenda(a) && LAWS[a.law].group).toBe('추위');
  });

  it('떠 있는 요구가 없으면 지금과 같은 안건을 고른다', () => {
    for (const s of SEEDS) {
      const g = opened(s, x => { x.coal = 100; x.food = 100; });
      expect(Object.keys(g.needs ?? {})).toEqual([]);
      expect(caretakerAgendaIdx(g, OPTS)).toBe(oldIdx(g));
    }
  });

  it('요구가 떠 있어도 목록에 그 묶음의 법이 없으면 지금과 같다', () => {
    for (const s of SEEDS) {
      const g = opened(s, x => { x.coal = 45; });
      g.council!.options = g.council!.options.filter(o => !(isLawAgenda(o) && LAWS[o.law].group === '추위'));
      if (g.council!.options.length === 0) continue;
      expect(caretakerAgendaIdx(g, OPTS)).toBe(oldIdx(g));
    }
  });

  it('재판 안건이나 배관 추인이 있으면 그것이 앞선다', () => {
    const g = opened('bn-0', x => { x.coal = 45; });
    expect(coldIdx(g).length).toBeGreaterThan(0);
    g.council!.options.push({ kind: 'motion', motion: 'pipe' } as never);
    expect(caretakerAgendaIdx(g, OPTS)).toBe(g.council!.options.length - 1);
    const h = opened('bn-0', x => { x.coal = 45; });
    h.council!.options.push({ kind: 'motion', motion: 'pipe' } as never, { kind: 'motion', motion: 'trial' } as never);
    expect(caretakerAgendaIdx(h, { ...OPTS, s1b: 'kind' })).toBe(h.council!.options.length - 1);
  });

  it('다른 정책의 봇은 바뀌지 않는다(첫 안건 그대로)', () => {
    const g = opened('bn-0', x => { x.coal = 45; });
    const first = g.council!.options[g.council!.idx];
    const a = council(g, { ...OPTS, policy: 'first' });
    expect(a).toEqual(first);
  });
});
