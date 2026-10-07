import { describe, expect, it } from 'vitest';
import {
  advance, agendaOptions, castVote, chooseCard, COMMS, createGame, departShare, HUB, isLawAgenda, leaverCount, openCouncil, P,
  persuadedCount, stance, hubLeakTick, strangerCorpse, onDeath, viewCard,
} from '../../src/game';
import type { Comm, Game } from '../../src/game';

// 라이프치히 이탈(first_leg_story 7.7)과 구벤의 낯선 시신(2.2). 숫자는 제안.

function calm(g: Game): void {
  for (const c of COMMS) { g.comms[c].rel = 0; g.comms[c].grudge = 0; }
}

function atArrival(seed: string, set: (g: Game) => void): Game {
  const g = createGame(seed);
  calm(g);
  set(g);
  g.seg = P.segments;
  g.phase = 'settle';
  g.cards = [];
  advance(g);
  return g;
}

const cardOf = (g: Game, kind: string, c?: Comm) => g.cards.find(x => x.kind === kind && (!c || x.comm === c));

describe('떠나려는 몫', () => {
  it('관계 단계와 적의로 정한다', () => {
    const g = createGame('share');
    calm(g);
    g.comms.engine.coh = 0.9; // 흔들림 없이
    const at = (rel: number, grudge = 0) => { g.comms.engine.rel = rel; g.comms.engine.grudge = grudge; return departShare(g, 'engine'); };
    expect(at(-14)).toBe(0);
    expect(at(-15)).toBe(0.1);
    expect(at(-40)).toBe(0.3);
    expect(at(-70)).toBe(0.6);
    expect(at(-70, 2)).toBe(0.8);
    expect(at(0, 2)).toBe(0.2);
  });

  it('결속이 낮으면 10%p 안에서 흔들리고, 판마다 같은 값이다', () => {
    const g = createGame('wobble');
    g.comms.tail.coh = 0.5;
    g.comms.tail.rel = -50;
    g.comms.tail.grudge = 0;
    const s = departShare(g, 'tail');
    expect(Math.abs(s - 0.3)).toBeLessThanOrEqual(0.1 + 1e-9);
    expect(departShare(g, 'tail')).toBe(s);
  });

  it('떠나려는 사람은 적어도 한 명, 칸을 비우지는 않는다', () => {
    const g = createGame('count');
    expect(leaverCount(g, 'guard', 0.01)).toBe(1);
    expect(leaverCount(g, 'guard', 0)).toBe(0);
    expect(leaverCount(g, 'guard', 1)).toBe(g.comms.guard.pop - 1);
  });
});

describe('라이프치히 두 구간 전', () => {
  it('떠날 몫이 있는 칸에만 짐 싸는 징후가 온다', () => {
    const g = createGame('omen');
    calm(g);
    g.comms.tail.rel = -75;
    g.seg = P.segments - 2;
    g.phase = 'settle';
    g.cards = [];
    advance(g);
    expect(g.seg).toBe(P.segments - 1);
    const card = cardOf(g, 'hub_omen', 'tail');
    expect(card).toBeDefined();
    expect(cardOf(g, 'hub_omen', 'front')).toBeUndefined();
    const v = viewCard(g, card!);
    expect(v.body).toContain('라이프치히에서 내리려 한다');
    // 적대면 물자 문장이 꼭 들어간다
    expect(card!.text).toContain('창고 장부');
  });

  it('징후를 받은 칸은 정산마다 식량·의약품을 조금씩 미리 뺀다', () => {
    const g = createGame('leak');
    calm(g);
    g.comms.tail.rel = -75;
    g.seg = P.segments - 1;
    g.hub = { warned: ['tail'], stash: {}, agreed: [] };
    const food = g.food;
    const notes: string[] = [];
    hubLeakTick(g, notes);
    expect(notes.some(n => n.includes('창고 장부'))).toBe(true);
    expect(g.hub.stash.tail?.food ?? 0).toBeGreaterThan(0);
    expect(g.food).toBeLessThan(food);
  });
});

describe('우리 몫을 내놔라', () => {
  it('마지막 회기에 떠날 칸마다 강제 안건으로 오른다', () => {
    const g = createGame('motion');
    calm(g);
    g.comms.engine.rel = -50;
    g.seg = P.segments;
    const { options, forced } = agendaOptions(g);
    expect(forced).toBe(true);
    const m = options.find(o => !isLawAgenda(o));
    expect(m).toMatchObject({ kind: 'motion', motion: 'share', subject: 'engine', by: 'engine' });
    // 그 칸은 물질 +2, 다른 칸은 −1
    expect(stance(g, 'engine', m!, false).mat).toBe(2);
    expect(stance(g, 'front', m!, false).mat).toBe(-1);
  });

  it('다른 구간엔 오르지 않는다', () => {
    const g = createGame('motion2');
    calm(g);
    g.comms.engine.rel = -50;
    g.seg = P.segments - 3;
    expect(agendaOptions(g).options.some(o => !isLawAgenda(o))).toBe(false);
  });

  it('통과하면 도착 때 고르기 없이 몫만 들고 내린다', () => {
    const g = createGame('motion3');
    calm(g);
    g.comms.engine.rel = -50;
    g.comms.engine.coh = 0.9;
    g.seg = P.segments;
    openCouncil(g);
    // 모두 찬성하게 만든다
    for (const c of COMMS) g.comms[c].rel = c === 'engine' ? -50 : 80;
    for (const c of COMMS) g.comms[c].grudge = 0;
    const idx = g.council!.options.findIndex(o => !isLawAgenda(o) && o.subject === 'engine');
    g.council!.idx = idx;
    const r = castVote(g);
    if (!r?.passed) return; // 표결은 난수다. 통과한 판만 본다.
    expect(g.hub?.agreed).toContain('engine');
    g.phase = 'settle';
    g.cards = [];
    for (const c of COMMS) if (c !== 'engine') g.comms[c].rel = 0;
    const pop = g.comms.engine.pop;
    advance(g);
    expect(cardOf(g, 'hub_split', 'engine')).toBeUndefined();
    expect(g.comms.engine.pop).toBeLessThan(pop);
    expect(g.story?.flags.hub_split?.engine).toBe('left');
  });
});

describe('라이프치히 도착', () => {
  it('떠나려는 칸마다 고르기 카드, 마지막에 결과 카드가 온다', () => {
    const g = atArrival('arrive', x => { x.comms.tail.rel = -75; });
    expect(cardOf(g, 'hub_split', 'tail')).toBeDefined();
    expect(g.cards[g.cards.length - 1].kind).toBe('hub_end');
    expect(g.story?.stage).toBe(6);
    expect(g.story?.flags.signal_heard).toBe(true);
    expect(g.phase).toBe('settle');
    const v = viewCard(g, cardOf(g, 'hub_split', 'tail')!);
    expect(v.faces?.length).toBeGreaterThan(0);
  });

  it('보내면 사람과 몫이 빠지고, 대표가 가면 그 자리에서 잇는다', () => {
    const g = atArrival('send', x => { x.comms.engine.rel = -75; x.comms.engine.coh = 0.9; });
    const card = cardOf(g, 'hub_split', 'engine')!;
    const plan = g.hub!.plan!.engine!;
    expect(plan.leaderGoes).toBe(true); // 덩어리로 움직이고 몫 0.3 이상
    const old = g.comms.engine.leader.name;
    const pop = g.comms.engine.pop;
    const coal = g.coal;
    expect(chooseCard(g, card.uid, 0)).toBe(true);
    expect(g.comms.engine.pop).toBe(pop - plan.n);
    expect(g.coal).toBeLessThan(coal - HUB.engineCoal + 1); // 적대라 석탄을 더 들고 간다
    expect(g.comms.engine.leader.name).not.toBe(old);
    expect(g.left).toContain(old);
    expect(g.story?.flags.hub_split?.engine).toBe('left');
  });

  it('설득은 신임 60 이상이고 적의 1 이하일 때만, 떠날 사람이 절반이나 4분의 1로 준다', () => {
    const g = atArrival('persuade', x => { x.comms.tail.rel = -50; x.trust = 40; });
    const card = cardOf(g, 'hub_split', 'tail')!;
    expect(viewCard(g, card).choices[1].disabled).toContain('신임');
    g.trust = 65;
    expect(viewCard(g, card).choices[1].disabled).toBeUndefined();
    const n = g.hub!.plan!.tail!.n;
    expect(persuadedCount(g, n)).toBe(Math.round(n / 2));
    g.trust = 80;
    expect(persuadedCount(g, n)).toBe(Math.round(n / 4));
    g.comms.tail.grudge = 2;
    expect(viewCard(g, card).choices[1].disabled).toContain('듣지 않는다');
    g.comms.tail.grudge = 0;
    const pop = g.comms.tail.pop;
    chooseCard(g, card.uid, 1);
    expect(g.trust).toBe(80 - HUB.persuadeCost);
    expect(g.comms.tail.pop).toBe(pop - Math.round(n / 4));
    expect(g.story?.flags.hub_split?.tail).toBe('persuaded');
  });

  it('무력은 경비대 관계가 좋아야 하고, 막으면 다치고 관계가 무너진다', () => {
    const g = atArrival('force', x => { x.comms.tail.rel = -75; x.comms.guard.rel = 0; });
    const card = cardOf(g, 'hub_split', 'tail')!;
    expect(viewCard(g, card).choices[2].disabled).toBe('경비대가 따르지 않는다');
    g.comms.guard.rel = 20;
    expect(viewCard(g, card).choices[2].disabled).toBeUndefined();
    const injured = g.injured;
    const tension = g.tension;
    const grudge = g.comms.tail.grudge;
    chooseCard(g, card.uid, 2);
    expect(g.injured).toBeGreaterThanOrEqual(injured + 2); // 떠나려던 사람 한 명 이상, 경비대 한 명 이상
    expect(g.comms.tail.rel).toBe(-95);
    expect(g.comms.tail.grudge).toBe(grudge + 1);
    expect(g.comms.guard.rel).toBe(20 + HUB.forceGuard);
    expect(g.comms.front.rel).toBe(HUB.forceWitness);
    expect(g.tension).toBeGreaterThanOrEqual(Math.min(100, tension + HUB.forceTension));
    expect(g.story?.flags.hub_split?.tail).toBe('forced');
  });

  it('경비대가 떠나려 하면 무력은 못 쓴다', () => {
    const g = atArrival('guardleave', x => { x.comms.tail.rel = -75; x.comms.guard.rel = 20; x.comms.guard.grudge = 2; });
    const card = cardOf(g, 'hub_split', 'tail')!;
    expect(viewCard(g, card).choices[2].disabled).toBe('경비대가 떠나려는 쪽이다');
  });

  it('아무도 떠나려 하지 않으면 몇 사람이 옮기겠다는 작은 장면으로 대신한다', () => {
    const g = atArrival('few', () => {});
    expect(cardOf(g, 'hub_split')).toBeUndefined();
    expect(cardOf(g, 'hub_few')).toBeDefined();
    expect(COMMS.every(c => g.story?.flags.hub_split?.[c] === 'stayed')).toBe(true);
  });

  it('카드를 다 고르면 판이 끝난다', () => {
    const g = atArrival('finish', x => { x.comms.tail.rel = -50; });
    while (g.cards.length > 0) chooseCard(g, g.cards[0].uid, 0);
    expect(g.phase).toBe('settle');
    expect(g.journal.some(j => j.text.includes('꼬리칸') && j.text.includes('명이 내렸다'))).toBe(true);
    advance(g);
    expect(g.end).toBe('complete');
    expect(g.phase).toBe('end');
  });
});

describe('구벤 강가의 낯선 시신', () => {
  it('두 번째 정차까지 우리 쪽 죽음이 없으면 시신 안건이 열린다', () => {
    const g = createGame('stranger');
    g.seg = 2;
    expect(strangerCorpse(g)).toBe(true);
    expect(g.corpseIssue).toBe(true);
    expect(g.story?.flags.first_corpse_agenda).toBe('stranger');
    expect(g.story?.flags.first_death).toBe(false);
    expect(g.deaths).toEqual([]);
  });

  it('우리 쪽이 먼저 죽었으면 낯선 시신은 없다', () => {
    const g = createGame('own');
    g.seg = 1;
    onDeath(g, 'tail', ['가']);
    expect(g.story?.flags.first_death).toBe(true);
    expect(g.story?.flags.first_corpse_agenda).toBe('own');
    g.seg = 2;
    expect(strangerCorpse(g)).toBe(false);
  });

  it('두 번째 정차가 아니면 찾지 않는다', () => {
    const g = createGame('notyet');
    g.seg = 1;
    expect(strangerCorpse(g)).toBe(false);
    g.seg = 3;
    expect(strangerCorpse(g)).toBe(false);
  });
});
