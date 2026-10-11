import { describe, expect, it } from 'vitest';
import {
  advance, chooseCard, COMMS, createGame, enterStranded, isSessionSeg, P, startTrip, strandedSettle, supportShare, tripPlan, tripTick, viewCard,
} from '../../src/game';
import type { Game } from '../../src/game';
import { playGame } from '../../tools/s1c_bot';

// 멈춘 열차 나(구현명세 가 3.4~3.9, 7절 5~11): 수동차 원정.

const stranded = (seed: string): Game => {
  const g = createGame(seed);
  g.cards = [];
  enterStranded(g, 4, 10);
  return g;
};
/** 칸마다 관계를 정한다. 지지 문턱(관계 15 이상인 칸의 인구 비율)을 맞추려고 쓴다. */
const rels = (g: Game, v: number) => { for (const c of COMMS) g.comms[c].rel = v; };
const lastCard = (g: Game, kind: string) => g.cards.find(c => c.kind === kind);
/** settle이 하는 순서대로 한 정산: 멈춘 정산, 그 뒤에 원정 한 턴. */
const step = (g: Game) => { strandedSettle(g); tripTick(g); };

/** 시드를 훑어 첫 역의 갈래가 원하는 쪽으로 난 판을 찾는다. */
function seedFor(want: 'lost' | 'extend' | 'coal'): string {
  for (let i = 0; i < 400; i += 1) {
    const seed = `trip-${want}-${i}`;
    const g = stranded(seed);
    rels(g, 30);
    g.stranded!.toNextKm = 15;
    startTrip(g, 'crew');
    const t = g.stranded!.trip!;
    step(g); // 첫 역에 닿는 턴
    const got = t.outcome === 'lost' ? 'lost' : t.outcome === 'coal' ? 'coal' : t.extends > 0 ? 'extend' : null;
    if (got === want) return seed;
  }
  throw new Error(`갈래를 못 찾았다: ${want}`);
}

describe('원정을 짠다', () => {
  it('15km·4명은 가는 1턴+뒤지는 1턴+오는 2턴=4턴에 식량 8, 30km는 6턴에 12', () => {
    const g = stranded('trip-plan');
    rels(g, 30);
    g.stranded!.toNextKm = 15;
    expect(tripPlan(g, 'crew')).toMatchObject({ size: 4, goTurns: 1, searchTurns: 1, backTurns: 2, total: 4, food: 8 });
    g.stranded!.toNextKm = 30;
    expect(tripPlan(g, 'crew')).toMatchObject({ goTurns: 2, backTurns: 3, total: 6, food: 12 });
  });

  it('등불을 걸면 오는 턴이 하나 준다(최소 1)', () => {
    const g = stranded('trip-lamp');
    rels(g, 30);
    g.stranded!.toNextKm = 15;
    g.contentFlags!.stranded_lamp = true;
    expect(tripPlan(g, 'crew')).toMatchObject({ backTurns: 1, total: 3 });
    expect(g.stranded!.lamp).toBe(true);
    g.stranded!.toNextKm = 5;
    expect(tripPlan(g, 'crew')!.backTurns).toBe(1);
  });

  it('열차장이 타면 지원자는 셋이고, 지지가 문턱 아래면 떠밀린 길이다', () => {
    const g = stranded('trip-captain');
    rels(g, -20);
    expect(supportShare(g)).toBeLessThan(P.supportLine);
    const plan = tripPlan(g, 'captain')!;
    expect(plan).toMatchObject({ size: 4, leaderGoes: true, forced: true });
    expect(plan.names).toHaveLength(3);
    rels(g, 30);
    expect(tripPlan(g, 'captain')!.forced).toBe(false);
  });
});

describe('출발 카드', () => {
  const choices = (g: Game) => viewCard(g, lastCard(g, 'trip_depart')!).choices.map(c => c.label);

  it('지지가 50% 미만이면 「수색대를 보낸다」가 없고, 이상이면 셋이 다 있다', () => {
    const g = stranded('trip-card');
    g.phase = 'prep';
    rels(g, -20);
    advance(g);
    expect(choices(g)).toEqual(['내가 간다', '아직 안 보낸다']);
    const h = stranded('trip-card-2');
    h.phase = 'prep';
    rels(h, 30);
    advance(h);
    expect(choices(h)).toEqual(['수색대를 보낸다', '내가 간다', '아직 안 보낸다']);
  });

  it('「아직 안 보낸다」는 긴장 +2이고 다음 턴 같은 카드가 또 뜬다', () => {
    const g = stranded('trip-wait');
    g.phase = 'prep';
    rels(g, 30);
    advance(g);
    const tension = g.tension;
    const waitIdx = viewCard(g, lastCard(g, 'trip_depart')!).choices.findIndex(c => c.special === 'trip_stay');
    g.cards = g.cards.filter(c => c.kind === 'trip_depart');
    expect(chooseCard(g, g.cards[0].uid, waitIdx)).toBe(true);
    expect(g.tension).toBe(tension + P.tripWaitTension);
    expect(g.stranded!.trip).toBeNull();
    g.cards = [];
    g.phase = 'prep';
    advance(g);
    expect(lastCard(g, 'trip_depart')).toBeTruthy();
  });
});

describe('갈래(첫 역)', () => {
  it('못 돌아옴·이어 감·석탄 있음이 시드로 갈린다', () => {
    for (const want of ['lost', 'extend', 'coal'] as const) expect(seedFor(want)).toBeTruthy();
  });

  it('이어 감: 거리 +15(30km), 곱절 식량은 열차가 알 때 낸다, 셋째 역은 이어 감이 없다', () => {
    const g = stranded(seedFor('extend'));
    rels(g, 30);
    g.stranded!.toNextKm = 15;
    const food0 = g.food;
    startTrip(g, 'crew');
    const t = g.stranded!.trip!;
    const taken = food0 - g.food;
    expect(taken).toBe(8);
    step(g);
    expect(t.distKm).toBe(30);
    expect(t.goTurns).toBe(2);
    expect(t.foodOwed).toBe(taken); // 총 식량이 ×2가 되도록 기본 몫만큼 더
    let mostExtends = 0;
    for (let i = 0; i < 300; i += 1) {
      const h = stranded(`trip-ext-${i}`);
      rels(h, 30);
      startTrip(h, 'crew');
      const tt = h.stranded!.trip!;
      for (let k = 0; k < 40 && h.stranded?.trip === tt && tt.outcome === null; k += 1) step(h);
      mostExtends = Math.max(mostExtends, tt.extends);
    }
    expect(mostExtends).toBeLessThanOrEqual(2);
  });

  it('무전(r3)이 있으면 이어 감을 바로 알려 카드가 뜨고 식량을 낸다', () => {
    const g = stranded(seedFor('extend'));
    rels(g, 30);
    g.stranded!.toNextKm = 15;
    g.dom = { techs: { r3: { stage: 'done' } } } as never;
    startTrip(g, 'crew');
    const food = g.food;
    step(g);
    expect(lastCard(g, 'trip_extend')).toBeTruthy();
    expect(g.stranded!.trip!.known).toBe(true);
    expect(g.food).toBeLessThan(food);
  });
});

describe('돌아왔을 때', () => {
  /** 석탄 갈래를 끝까지 돌려 귀환 카드까지 간다. */
  function backWithCoal(mode: 'crew' | 'captain', rel: number): Game {
    for (let i = 0; i < 400; i += 1) {
      const g = stranded(`trip-back-${mode}-${i}`);
      rels(g, rel);
      g.stranded!.toNextKm = 15;
      startTrip(g, mode);
      for (let k = 0; k < 30 && g.stranded?.trip && !lastCard(g, 'trip_return') && !g.end; k += 1) step(g);
      if (lastCard(g, 'trip_return') && g.stranded!.trip!.extends === 0) return g;
    }
    throw new Error('석탄 갈래를 못 찾았다');
  }

  it('수색대가 석탄 30을 들고 오면 그 칸 관계 +4, 다시 달린다', () => {
    const g = backWithCoal('crew', 30);
    const comm = g.stranded!.trip!.comm;
    const rel = g.comms[comm].rel;
    const coal = g.coal;
    g.cards = g.cards.filter(c => c.kind === 'trip_return');
    expect(chooseCard(g, g.cards[0].uid, 0)).toBe(true);
    expect(g.coal).toBe(coal + P.tripCoal);
    expect(g.comms[comm].rel).toBe(Math.min(100, rel + P.tripRelCrew));
    expect(g.stranded).toBeNull();
    expect(g.contentFlags?.stranded).toBe(false);
  });

  it('떠밀려 나간 열차장은 신임 +5, 스스로 간 열차장은 0', () => {
    const forced = backWithCoal('captain', -20);
    expect(forced.stranded!.trip!.forced).toBe(true);
    const trust = forced.trust;
    forced.cards = forced.cards.filter(c => c.kind === 'trip_return');
    chooseCard(forced, forced.cards[0].uid, 0);
    expect(forced.trust).toBe(trust + P.tripTrustForced);
    const free = backWithCoal('captain', 30);
    expect(free.stranded!.trip!.forced).toBe(false);
    const trust2 = free.trust;
    free.cards = free.cards.filter(c => c.kind === 'trip_return');
    chooseCard(free, free.cards[0].uid, 0);
    expect(free.trust).toBe(trust2);
  });

  it('돌아올 사람의 몫을 약속했으면 사치품 2를 내주고 그 칸 관계 +4, 못 주면 신임 −8', () => {
    const g = backWithCoal('crew', 30);
    g.stranded!.trip!.promise = 'yes';
    g.lux = 5;
    const view = viewCard(g, lastCard(g, 'trip_return')!);
    expect(view.choices[0].effs).toContainEqual({ t: 'lux', v: -P.promiseLux });
    g.lux = 0;
    expect(viewCard(g, lastCard(g, 'trip_return')!).choices[0].effs).toContainEqual({ t: 'trust', v: P.promiseBrokenTrust });
  });

  it('눈을 치우지 않았으면 다시 달릴 때 석탄 −2', () => {
    const g = backWithCoal('crew', 30);
    g.stranded!.snow = 'none';
    const coal = g.coal;
    g.cards = g.cards.filter(c => c.kind === 'trip_return');
    chooseCard(g, g.cards[0].uid, 0);
    expect(g.coal).toBe(coal + P.tripCoal - 2);
  });
});

describe('못 돌아옴', () => {
  it('수색대: 인구 −4, 관계 −8, 긴장 +8, 공포 +5, 죽음 기록 넷, 다시 보낼 수 있다', () => {
    const g = stranded(seedFor('lost'));
    rels(g, 30);
    g.stranded!.toNextKm = 15;
    startTrip(g, 'crew');
    const t = g.stranded!.trip!;
    const { comm, names } = t;
    for (let k = 0; k < 30 && g.stranded?.trip; k += 1) {
      const before = { pop: g.comms[comm].pop, rel: g.comms[comm].rel, tension: g.tension, fear: g.fear, deaths: g.deathLog?.length ?? 0 };
      step(g);
      if (!g.stranded?.trip) {
        expect(g.comms[comm].pop).toBe(Math.max(1, before.pop - names.length));
        expect(g.comms[comm].rel).toBe(before.rel + P.tripLostRel);
        // 죽음 자체가 긴장·공포를 더 올릴 수 있어 이 값 이상이다.
        expect(g.tension).toBeGreaterThanOrEqual(Math.min(100, before.tension + P.tripLostTension));
        expect(g.fear).toBeGreaterThanOrEqual(Math.min(100, before.fear + P.tripLostFear));
        expect((g.deathLog?.length ?? 0) - before.deaths).toBe(names.length);
      }
    }
    expect(g.stranded!.lostTrips).toBe(1);
    const card = lastCard(g, 'trip_lost')!;
    expect(viewCard(g, card).choices.map(c => c.label)).toEqual(['다시 보낸다', '내가 간다', '기다린다']);
    expect(g.end).toBeNull();
  });

  it('열차장이 탔으면 판이 lost_captain으로 끝난다', () => {
    const g = stranded(seedFor('lost'));
    rels(g, 30);
    g.stranded!.toNextKm = 15;
    startTrip(g, 'captain');
    for (let k = 0; k < 30 && g.stranded?.trip; k += 1) step(g);
    expect(g.end).toBe('lost_captain');
    expect(g.phase).toBe('end');
    expect(g.journal.some(j => j.text.includes('수동차 자국만 남았다'))).toBe(true);
  });

  it('정산 안에서 끝나면 끝 글이 일지 마지막이고 그 뒤 틱이 돌지 않는다', () => {
    const g = stranded(seedFor('lost'));
    rels(g, 30);
    g.stranded!.toNextKm = 15;
    startTrip(g, 'captain');
    for (let k = 0; k < 40 && !g.end; k += 1) {
      g.cards = [];
      g.phase = 'travel';
      advance(g);
    }
    expect(g.end).toBe('lost_captain');
    expect(g.journal[g.journal.length - 1].text).toContain('수동차 자국만 남았다');
    const turn = g.stranded!.trip?.turn;
    const len = g.journal.length;
    strandedSettle(g);
    expect(g.stranded!.trip?.turn).toBe(turn);
    expect(g.journal.length).toBeGreaterThanOrEqual(len);
  });
});

describe('열차장이 없는 동안', () => {
  it('회기 구간에 회기가 안 열리고, 돌아온 뒤 다음 정차 뒤에 한 번 열린다', () => {
    const g = stranded('trip-council');
    rels(g, 30);
    while (!isSessionSeg(g.seg)) g.seg += 1;
    startTrip(g, 'captain');
    expect(g.stranded!.captainAway).toBe(true);
    g.phase = 'travel';
    advance(g);
    expect(g.phase).toBe('settle');
    expect(g.councilOwed).toBe(true);
    expect(g.council).toBeFalsy();
    g.stranded!.captainAway = false;
    g.stranded!.trip = null;
    g.cards = [];
    g.phase = 'travel';
    g.seg += 1; // 회기 구간이 아닌 다음 구간
    while (isSessionSeg(g.seg)) g.seg += 1;
    advance(g);
    expect(g.phase).toBe('council');
    expect(g.councilOwed).toBe(false);
  });

  it('긴장 위기의 「경비대를 푼다」와 눈의 「경비대만」이 닫힌다', () => {
    const g = stranded('trip-shut');
    rels(g, 30);
    g.cards = [{ uid: 1, kind: 'tension_crisis', comm: 'tail' }];
    expect(viewCard(g, g.cards[0]).choices.map(c => c.label)).toContain('경비대를 푼다');
    g.stranded!.captainAway = true;
    expect(viewCard(g, g.cards[0]).choices.map(c => c.label)).not.toContain('경비대를 푼다');
    g.cards = [{ uid: 2, kind: 'content', text: 'ev_str_snow', comm: 'engine' }];
    expect(viewCard(g, g.cards[0]).choices.map(c => c.special)).not.toContain('content:c_guard_only');
    g.stranded!.captainAway = false;
    expect(viewCard(g, g.cards[0]).choices.map(c => c.special)).toContain('content:c_guard_only');
  });

  it('원정이 나가 있는 칸의 지원자는 정산이 자리비움을 0으로 되돌려도 다시 센다', () => {
    const g = stranded('trip-away');
    rels(g, 30);
    startTrip(g, 'crew');
    const t = g.stranded!.trip!;
    g.phase = 'travel';
    advance(g);
    expect(g.comms[t.comm].away).toBe(t.names.length);
  });
});

describe('판을 돌리면', () => {
  it('석탄이 바닥나도 원정이 돌고 판이 터지지 않는다(돌봄 봇, 내정 켬)', () => {
    let dropped = false;
    const kinds = new Set<string>();
    const { g } = playGame('trip-bot-1', {
      s1c: true, policy: 'caretaker', dom: 'engaged',
      probe: {
        beforePick: (gg: Game) => { if (!dropped && gg.seg >= 3) { dropped = true; gg.coal = 1; } for (const c of gg.cards) kinds.add(c.kind); },
      },
    } as never);
    expect(dropped).toBe(true);
    expect(kinds.has('trip_depart')).toBe(true);
    expect(g.end === null || g.phase === 'end').toBe(true);
  }, 120000);
});
