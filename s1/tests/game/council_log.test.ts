import { describe, expect, it } from 'vitest';
import {
  ARC, blocs, breakPromise, castVote, chooseCard, COMMS, createGame, currentAgenda, expected, finishPreVote, LOG_MAX, logVote, noteHeld,
  openCouncil, preVote, toolStatus, viewCard, voteWhy,
} from '../../src/game';
import type { Comm, CouncilLogRow, Game } from '../../src/game';

// 회기 기록부·개표 설명·결과 아크(정치 흐름 설계 2·3장, 결정 439, 6.1 sol 검수 2·3).

function council(seed: string, set?: (g: Game) => void): Game {
  const g = createGame(seed);
  set?.(g);
  openCouncil(g);
  if (preVote(g)) finishPreVote(g);
  return g;
}

const row = (n: number): CouncilLogRow => ({
  session: n, seg: n, title: `안건 ${n}`, kind: 'enact', by: 'chief', passed: true, yes: 60, no: 30, absent: 0, need: 51, exp: { mean: 55, min: 40, max: 70 },
});

describe('개표', () => {
  it('확보 표가 필요 표를 넘으면 늘 가결, 될 수 있는 표가 모자라면 늘 부결이다(80판)', () => {
    let checked = 0;
    for (let i = 0; i < 80; i += 1) {
      const g = council(`log-inv-${i}`);
      const a = currentAgenda(g);
      if (!a) continue;
      const est = expected(blocs(g, a, g.council!.deals));
      const r = castVote(g);
      if (!r) continue;
      checked += 1;
      expect(r.yes).toBeGreaterThanOrEqual(est.min);
      expect(r.yes).toBeLessThanOrEqual(est.max);
      if (est.min >= r.need) expect(r.passed).toBe(true);
      if (est.max < r.need) expect(r.passed).toBe(false);
    }
    expect(checked).toBeGreaterThan(40);
  });

  it('표결마다 기록부에 한 줄이 남고, 최근 줄만 남는다', () => {
    const g = council('log-row');
    const r = castVote(g)!;
    const last = g.councilLog!.at(-1)!;
    expect(last.yes).toBe(r.yes);
    expect(last.passed).toBe(r.passed);
    expect(last.exp.min).toBeLessThanOrEqual(last.exp.max);
    for (let i = 0; i < LOG_MAX + 5; i += 1) logVote(g, row(i));
    expect(g.councilLog!.length).toBe(LOG_MAX);
    expect(g.councilLog![0].session).toBe(5);
  });

  it('개표 설명은 미정·대표 몫만 말하고 차이가 한 석 아래면 없다', () => {
    const g = council('log-why');
    const a = currentAgenda(g)!;
    const map = blocs(g, a, []);
    const even = {} as Record<Comm, { und: number; pool: number }>;
    for (const c of COMMS) even[c] = { und: 0, pool: 0 };
    const c = COMMS.find(x => map[x].und >= 4);
    expect(c).toBeTruthy();
    if (!c) return;
    map[c].score = 0; // 찬성 몫 50%
    const none = { ...even };
    for (const x of COMMS) map[x].und = x === c ? map[x].und : 0;
    for (const x of COMMS) map[x].pool = 0;
    none[c] = { und: Math.round(map[c].und / 2), pool: 0 };
    expect(voteWhy(map, none)).toBeNull();
    const all = { ...even, [c]: { und: map[c].und, pool: 0 } };
    const text = voteWhy(map, all)!;
    expect(text).toContain(`미정 ${map[c].und}석 가운데 ${map[c].und}석이 찬성했다`);
    expect(text).not.toMatch(/꿈쩍|부재/);
  });
});

describe('결과 아크', () => {
  it('약속을 두 번 어기면 장부 카드가 오고, 세 번이면 그 칸과 공개 협상이 닫힌다', () => {
    const g = createGame('arc-ledger');
    const c: Comm = 'engine';
    breakPromise(g, c, '하나');
    expect(g.cards.some(k => k.kind === 'promise_ledger')).toBe(false);
    breakPromise(g, c, '둘');
    const card = g.cards.find(k => k.kind === 'promise_ledger' && k.comm === c);
    expect(card).toBeTruthy();
    const view = viewCard(g, card!);
    expect(view.choices.map(x => x.label)).toEqual(['사과하고 갚는다', '물리친다']);
    breakPromise(g, c, '셋');
    expect(g.comms[c].openClosed).toBe(true);
    // 닫힌 칸은 공개 협상 단추가 까닭과 함께 막힌다(다른 칸은 그대로)
    const h = council('arc-ledger-council', x => { x.comms[c].openClosed = true; x.comms[c].grudge = 0; x.comms[c].rel = 30; });
    const st = toolStatus(h, c, 'open');
    if (st.why !== '이미 거래했다' && st.why !== '살 표가 없다' && st.why !== '남은 반대는 꿈쩍 않는다') {
      expect(st.ok).toBe(false);
      expect(st.why).toBe('약속을 세 번 어겼다');
    }
  });

  it('장부를 물리치면 적의가 하나 오른다', () => {
    const g = createGame('arc-refuse');
    const c: Comm = 'medtech';
    g.comms[c].broken = ARC.ledgerAt - 1;
    breakPromise(g, c, '둘');
    const grudge = g.comms[c].grudge;
    const card = g.cards.find(k => k.kind === 'promise_ledger')!;
    expect(chooseCard(g, card.uid, 1)).toBe(true);
    expect(g.comms[c].grudge).toBe(Math.min(3, grudge + 1));
  });

  it('넘긴 안건이 이어 두 번 떨어지면 그 칸 관계가 깎이고, 가결되면 셈이 지워진다', () => {
    const g = createGame('arc-held');
    const c: Comm = 'front';
    const rel = g.comms[c].rel;
    noteHeld(g, c, false);
    expect(g.comms[c].rel).toBe(rel);
    noteHeld(g, c, true);
    noteHeld(g, c, false);
    expect(g.comms[c].rel).toBe(rel);
    noteHeld(g, c, false);
    expect(g.comms[c].rel).toBe(rel + ARC.heldRel);
    expect(g.comms[c].heldFails).toBe(0);
  });
});
