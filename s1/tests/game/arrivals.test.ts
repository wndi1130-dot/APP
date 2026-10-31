import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import {
  addCard, AR, arrivalsAfterStop, arrivalsArrive, arrivalsSettle, arrivalsTravel, arrivedIn, ARRIVAL_CARD_KINDS, chooseCard, COMMS, createGame, crewNames,
  ARRIVAL_SIT, crowdFeverP, crowdLevel, drawGroups, enableArrivals, forecast, lawBackers, P, situation, someOf, takeIn, viewCard,
} from '../../src/game';
import type { Card, Game } from '../../src/game';
import { playGame } from '../../tools/s1c_bot';

// 사람이 들어오는 사건(arrivals.ts, 명세 6장의 시험 12개). 기본 꺼짐, 굴림은 판 씨앗 해시, 들어온 사람은 칸 인원으로만 센다.

const AR0 = { ...AR };
afterEach(() => { Object.assign(AR, AR0); });

const sum = (xs: number[]) => xs.reduce((a, b) => a + b, 0);

function on(seed: string): Game {
  const g = createGame(seed);
  enableArrivals(g);
  g.seg = 6;
  return g;
}

/** 꼬리칸 처지를 정해 둔다(값이 0~100 밖으로 잘리지 않게) */
function setTail(g: Game, warm: number, ration: number, crowd: number): void {
  const s = situation(g, 'tail');
  const b = g.comms.tail.base;
  b[0] += warm - s[0]; b[1] += ration - s[1]; b[2] += crowd - s[2];
}

function arrivalCard(g: Game, groups: number[], hurt: number[] = [], where: 'stop' | 'travel' = 'stop'): Card {
  addCard(g, { kind: 'arrival', n: sum(groups), text: where, vals: { groups: groups.join(','), hurt: hurt.join(','), crew: crewNames(g, 'tail', 2).join('|'), comm: 'tail', danger: '1', known: '0' } });
  return g.cards[g.cards.length - 1];
}

function familyCard(g: Game, size: number, danger = '1'): Card {
  addCard(g, { kind: 'family', comm: 'tail', who: crewNames(g, 'tail', 1)[0], n: size, vals: { hurt: '0', crew: crewNames(g, 'tail', 8).slice(4, 7).join('|'), danger, known: '1' } });
  return g.cards[g.cards.length - 1];
}

const pickIdx = (g: Game, card: Card, id: string) => viewCard(g, card).choices.findIndex(c => c.id === id);

describe('꺼진 판', () => {
  it('1. 끈 판은 한 판 내내 g.arrivals가 없고 사건 카드도 일지도 없다', () => {
    for (const seed of ['ar-off-0', 'ar-off-1', 'ar-off-2']) {
      const { g, m } = playGame(seed, { s1c: true, policy: 'caretaker', dom: 'engaged' });
      expect(g.seg).toBeGreaterThanOrEqual(5);
      expect(g.arrivals).toBeUndefined();
      for (const k of ARRIVAL_CARD_KINDS) expect(m.cards[k]).toBeUndefined();
      expect(g.journal.some(j => /피난민|무리를 데리러|대원의 가족|함께 탔다/.test(j.text))).toBe(false);
    }
  });

  it('1. 끈 판의 처지는 옛 식 그대로다(h 몫이 0)', () => {
    const g = createGame('ar-off-sit');
    const before = COMMS.map(c => situation(g, c));
    g.comms.tail.pop += 10;
    expect(COMMS.map(c => situation(g, c))).toEqual(before);
  });

  it('2. arrivals.ts는 게임 난수(rnd, g.rng)를 부르지 않고, 켠 판의 굴림도 g.rng를 바꾸지 않는다', () => {
    // 주석은 빼고 코드만 본다
    const code = (f: string) => readFileSync(join(__dirname, `../../src/game/${f}`), 'utf8').replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
    for (const f of ['arrivals.ts', 'arrival_cards.ts']) expect(code(f)).not.toMatch(/\brnd\b|\.rng\b/);
    AR.stopP = 1; AR.travelP = 1; AR.familyP = 1;
    const g = on('ar-rng');
    const rng = JSON.stringify(g.rng);
    expect(arrivalsTravel(g, crewNames(g, 'tail', 2))).toBe(true);
    g.cards = [];
    g.seg += AR.gap;
    expect(arrivalsAfterStop(g, 'tail', crewNames(g, 'tail', 6), '대원')).toBe(true);
    expect(JSON.stringify(g.rng)).toBe(rng);
  });
});

describe('빈도와 간격', () => {
  it('3. ①은 한 판 3번, ②는 2번을 넘지 않고 간격(4·6구간) 안에서는 뜨지 않는다', () => {
    AR.stopP = 1; AR.travelP = 1; AR.familyP = 1;
    for (const seed of ['ar-cap-0', 'ar-cap-1', 'ar-cap-2', 'ar-cap-3']) {
      const segs: Record<string, number[]> = { arrival: [], family: [] };
      playGame(seed, { s1c: true, policy: 'caretaker', dom: 'engaged', arrivals: true, probe: { beforePick: (x, card) => { if (card.kind in segs) segs[card.kind].push(x.seg); } } });
      expect(segs.arrival.length).toBeGreaterThan(0);
      expect(segs.arrival.length).toBeLessThanOrEqual(AR.cap);
      expect(segs.family.length).toBeLessThanOrEqual(AR.familyCap);
      for (const [k, gap] of [['arrival', AR.gap], ['family', AR.familyGap]] as const) {
        const s = segs[k];
        expect(s.every(x => x >= AR.fromSeg)).toBe(true);
        for (let i = 1; i < s.length; i += 1) expect(s[i] - s[i - 1]).toBeGreaterThanOrEqual(gap);
      }
    }
  });
});

describe('선택지', () => {
  it('4. ①은 네 갈래, ②는 두 갈래이고 몸 상태로 가르는 갈래가 없다', () => {
    const g = on('ar-ids');
    const a = viewCard(g, arrivalCard(g, [3, 2, 4], [1]));
    expect(a.choices.map(c => c.id)).toEqual(['turn_away', 'take_some', 'take_all', 'escort']);
    g.cards = [];
    const f = viewCard(g, familyCard(g, 4));
    expect(f.choices.map(c => c.id)).toEqual(['fetch', 'stay_put']);
    for (const ch of [...a.choices, ...f.choices]) expect(`${ch.label} ${ch.say ?? ''}`).not.toMatch(/건강|성한|멀쩡|아픈 사람|병든|골라|가려/);
    // 선택지는 지금 값만 보인다(결정 364): 나중 칸을 쓰지 않는다
    for (const ch of [...a.choices, ...f.choices]) expect(ch.later).toBeUndefined();
  });

  it('5. 외부인 받지 않기 법이 있으면 ①은 법대로 보내는 한 갈래다. ②는 그대로 두 갈래이고 법을 바라는 쪽 관계가 깎인다', () => {
    const g = on('ar-law');
    g.passed.no_outsiders = 1;
    expect(viewCard(g, arrivalCard(g, [3, 3])).choices.map(c => c.id)).toEqual(['turn_away_law']);
    g.cards = [];
    const f = viewCard(g, familyCard(g, 4));
    expect(f.choices.map(c => c.id)).toEqual(['fetch', 'stay_put']);
    const fetch = f.choices[0];
    const backers = lawBackers(g);
    expect(backers.length).toBeGreaterThan(0);
    expect(fetch.effs.filter(e => e.t === 'rel' && e.v === -3).map(e => (e as { c: string }).c)).toEqual(backers);
  });
});

describe('받은 뒤의 처지', () => {
  it('6. 모두 태우면 꼬리칸 인원 +n, 과밀 +0.75n, 배급 −0.4n, 온기 −0.25n(결정 385), 부상자 +다친 수', () => {
    const g = on('ar-all');
    setTail(g, 60, 60, 40);
    const groups = [3, 2, 4];
    const n = sum(groups);
    const pop = g.comms.tail.pop;
    const [w, r, c] = situation(g, 'tail');
    const inj = g.injured;
    const card = arrivalCard(g, groups, [0, 2]);
    expect(chooseCard(g, card.uid, pickIdx(g, card, 'take_all'))).toBe(true);
    expect(g.comms.tail.pop).toBe(pop + n);
    const [w2, r2, c2] = situation(g, 'tail');
    expect(ARRIVAL_SIT).toEqual([0.25, 0.4, 0.75]);
    expect(c2 - c).toBeCloseTo(0.75 * n);
    expect(r - r2).toBeCloseTo(0.4 * n);
    expect(w - w2).toBeCloseTo(0.25 * n);
    expect(g.injured).toBe(inj + 2);
    expect(arrivedIn(g, 'tail')).toBe(n);
  });

  it('결정 385. 돌려보내면 신임 −1·의무진 −1·꼬리칸 −1·긴장 +1이고, 돌려보냄·못 감에는 목격자 벌이 없다', () => {
    const g = on('ar-385');
    const a = viewCard(g, arrivalCard(g, [3, 3]));
    const turn = a.choices.find(c => c.id === 'turn_away')!;
    expect(turn.effs).toEqual([{ t: 'trust', v: -1 }, { t: 'rel', c: 'medtech', v: -1 }, { t: 'rel', c: 'tail', v: -1 }, { t: 'tension', v: 1 }]);
    expect(turn.witness).toBe(false);
    expect(a.choices.find(c => c.id === 'take_all')!.witness).toBe(true);
    expect(viewCard(g, familyCard(g, 3)).choices.find(c => c.id === 'stay_put')!.witness).toBe(false);
  });

  it('7. 일부는 가족 묶음 합이고 무리 절반 이상 n 미만이다(가족이 갈리지 않는다)', () => {
    for (let i = 0; i < 300; i += 1) {
      const g = createGame(`ar-some-${i}`);
      g.seg = 3 + (i % 25);
      const total = 6 + (i % 9);
      const groups = drawGroups(g, 'arr', total);
      expect(sum(groups)).toBe(total);
      expect(groups.every(k => k >= AR.groupMin && k <= AR.groupMax)).toBe(true);
      const took = sum(groups.slice(0, someOf(groups)));
      expect(took * 2).toBeGreaterThanOrEqual(total);
      expect(took).toBeLessThan(total);
    }
    const g = on('ar-some');
    setTail(g, 60, 60, 40);
    const pop = g.comms.tail.pop;
    const card = arrivalCard(g, [2, 3, 4, 2]);
    chooseCard(g, card.uid, pickIdx(g, card, 'take_some'));
    expect(g.comms.tail.pop - pop).toBe(9); // 2+3=5 < 5.5, 2+3+4=9
  });

  it('8. 받은 뒤 예고의 식량·석탄이 받은 수에 비례해 늘고, 빈속 몫은 한 번만 빠진다', () => {
    const g = on('ar-fc');
    setTail(g, 60, 60, 40);
    const f0 = forecast(g);
    takeIn(g, 'tail', [4, 4, 2]);
    const f1 = forecast(g);
    const t = g.comms.tail;
    expect(f1.food - f0.food).toBeCloseTo(10 * t.ration * P.foodPerPersonLever);
    expect(f1.coal - f0.coal).toBeCloseTo(((10 * t.heat) / 40) * P.coalHeatPerLever);
    const food = g.food;
    arrivalsSettle(g, []);
    expect(food - g.food).toBeCloseTo(10 * AR.hunger);
    arrivalsSettle(g, []);
    expect(food - g.food).toBeCloseTo(10 * AR.hunger);
  });

  it('9. 꼬리칸 과밀 85에서 14명을 받으면 「겹쳐 잠」(계단 3)이고 열병 시작 확률은 0.09다', () => {
    const g = on('ar-crowd');
    setTail(g, 60, 60, 85);
    const plan = takeIn(g, 'tail', [4, 4, 3, 3]);
    expect(plan).toEqual({ tail: 14 });
    expect(crowdLevel(g, 'tail')).toBe(3);
    expect(crowdFeverP(g, 'tail')).toBeCloseTo(0.09);
  });

  it('4장. 꼬리칸 과밀이 95 이상이면 남는 가족은 의무진 칸으로 간다', () => {
    const g = on('ar-over');
    setTail(g, 60, 60, 93);
    const plan = takeIn(g, 'tail', [3, 3, 2]);
    expect(plan.tail).toBe(3);
    expect(plan.medtech).toBe(5);
  });

  it('10. 그 칸 인원이 받기 전 아래로 내려가면 처지 몫이 0이 된다', () => {
    const g = on('ar-drop');
    setTail(g, 60, 60, 40);
    const pop = g.comms.tail.pop;
    const before = situation(g, 'tail');
    takeIn(g, 'tail', [3, 3]);
    expect(arrivedIn(g, 'tail')).toBe(6);
    g.comms.tail.pop = pop - 1;
    expect(arrivedIn(g, 'tail')).toBe(0);
    expect(situation(g, 'tail')).toEqual(before);
  });
});

describe('수색대가 데려온 가족', () => {
  it('11. 데리러 보내면 3명이 자리를 비우고 작업조에서 빠지며, 다음 정차에 가족이 탄다', () => {
    const g = on('ar-fetch');
    const card = familyCard(g, 4, '0');
    const sent = card.vals!.crew.split('|');
    const pop = g.comms.tail.pop;
    const away = g.comms.tail.away;
    expect(chooseCard(g, card.uid, pickIdx(g, card, 'fetch'))).toBe(true);
    expect(g.comms.tail.away).toBe(away + 3);
    expect(crewNames(g, 'tail', 40).some(n => sent.includes(n))).toBe(false);
    arrivalsArrive(g);
    expect(g.comms.tail.pop).toBe(pop + 4);
    expect(g.comms.tail.away).toBe(away);
    expect(g.arrivals!.pending).toBeUndefined();
    expect(crewNames(g, 'tail', 40).some(n => sent.includes(n))).toBe(true);
  });

  it('11. 셋 다 못 돌아오면 인원이 늘지 않고 일지는 수만 적는다', () => {
    const g = on('ar-lost');
    const card = familyCard(g, 4, '1000');
    const sent = card.vals!.crew.split('|');
    chooseCard(g, card.uid, pickIdx(g, card, 'fetch'));
    const pop = g.comms.tail.pop;
    arrivalsArrive(g);
    expect(g.comms.tail.pop).toBeLessThanOrEqual(pop);
    const line = g.journal.find(j => j.text.includes('돌아오지 않았다'));
    expect(line?.text).toBe('수색대 3명이 돌아오지 않았다.');
    expect(sent.some(n => line!.text.includes(n))).toBe(false);
  });
});

describe('글', () => {
  interface Rule { id: string; severity: string; scope: string; terms?: string[]; patterns?: string[]; pattern_flags?: string }
  const rules = (JSON.parse(readFileSync(join(__dirname, '../../schema/content_rules.json'), 'utf8')) as { rules: Rule[] }).rules.filter(r => r.severity === 'error');
  function bad(text: string, dialogue: boolean): string[] {
    return rules.filter(r => (r.scope !== 'dialogue' || dialogue) && ((r.terms ?? []).some(t => text.includes(t)) || (r.patterns ?? []).some(p => new RegExp(p, r.pattern_flags ?? 'iu').test(text)))).map(r => `${r.id}: ${text}`);
  }
  /** 들어온 사람을 병의 출처로 적는 글 */
  // 「옮겼다」는 병과 같은 문장일 때만 출처 말이다(「의무칸으로 옮겼다」 같은 자리 옮김은 아님).
  const SOURCE = /(병|전염)[^.]*옮(겼|기|아)|옮(겼|기|아)[^.]*(병|전염)|병을 (가져|몰고|퍼뜨)|(들어온|늦게 탄|피난민|외부인)[^.]*(열병|병에|병이|전염)|(열병|병)[^.]*(들어온|늦게 탄|피난민|외부인)/;

  it('12. 카드·일지·열병 까닭 줄에 들어온 사람을 병의 출처로 적는 글이 없고 글 규칙 오류도 없다', () => {
    const g = on('ar-text');
    const views = [];
    views.push(viewCard(g, arrivalCard(g, [3, 2, 4], [1])));
    views.push(viewCard(g, arrivalCard(g, [4, 2], [], 'travel')));
    views.push(viewCard(g, familyCard(g, 5)));
    views.push(viewCard(g, { uid: 999, kind: 'bed_quarrel', comm: 'tail' }));
    g.passed.no_outsiders = 1;
    views.push(viewCard(g, arrivalCard(g, [3, 3])), viewCard(g, familyCard(g, 3)));
    const texts: { text: string; dialogue: boolean }[] = [];
    for (const v of views) {
      texts.push({ text: v.title, dialogue: false }, { text: v.body, dialogue: true });
      for (const ch of v.choices) texts.push({ text: ch.label, dialogue: true }, ...(ch.say ? [{ text: ch.say, dialogue: true }] : []), ...(ch.extra ?? []).map(t => ({ text: t, dialogue: false })));
    }
    AR.stopP = 1; AR.travelP = 1; AR.familyP = 1;
    for (const seed of ['ar-text-0', 'ar-text-1']) {
      const { g: p } = playGame(seed, { s1c: true, policy: 'caretaker', dom: 'engaged', arrivals: true, pickRule: 'random' });
      for (const j of p.journal) texts.push({ text: j.text, dialogue: false });
    }
    const errs = texts.flatMap(t => bad(t.text, t.dialogue));
    expect(errs).toEqual([]);
    expect(texts.filter(t => SOURCE.test(t.text)).map(t => t.text)).toEqual([]);
  });
});
