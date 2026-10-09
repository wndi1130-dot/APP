import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  advance, blocs, castVote, chooseCard, COMMS, createGame, createS1cGame, currentAgenda, enactLaw, finishPreVote, greenhouseFood, HUB,
  LAW_ONLY_TECHS, makeDeal, offend, openCouncil, P, PLACES, preVote, repealLaw, resolveStop, STAY, stopRisk, techLaws, techMult, TECHS,
  usefulVariant, viewCard,
} from '../../src/game';
import type { Comm, Game, StayId } from '../../src/game';
import { ballotSecret, secretStates, shownBlocs } from '../../src/ui/council';
import { h, raw } from '../../src/ui/dom';

// K01 검수(로컬 워커 아스트라, research/astra-20261008 1151880)의 '높음' 열 개. 하나씩 막는다.

function council(seed: string, set?: (g: Game) => void): Game {
  const g = createGame(seed);
  set?.(g);
  openCouncil(g);
  if (preVote(g)) finishPreVote(g);
  return g;
}

describe('K01 1: 거절당한 뇌물은 표를 움직이지 않는다', () => {
  it('이상주의 대표가 뇌물을 내보이면 쐐기도 결과도 거래 없는 것과 같다', () => {
    const g = council('k01-bribe', x => { x.lux = 50; for (const c of COMMS) x.comms[c].grudge = 0; });
    const c: Comm = 'tail';
    g.comms[c].leader.trait = 'ideal';
    const out = makeDeal(g, c, 'bribe');
    expect(out.ok).toBe(false);
    const deal = g.council!.deals.find(d => d.comm === c)!;
    expect(deal.refused).toBe(true);
    const agenda = currentAgenda(g)!;
    expect(blocs(g, agenda, g.council!.deals)[c]).toEqual(blocs(g, agenda, [])[c]);
    // 같은 판을 둘로 갈라 표결하면 결과가 같다.
    const twin: Game = JSON.parse(JSON.stringify(g));
    twin.council!.deals = [];
    expect(castVote(g)!.byComm[c]).toEqual(castVote(twin)!.byComm[c]);
  });
});

describe('K01 2: 비밀 투표 표시는 표결한 그때 방식을 따른다', () => {
  it('비밀 투표 법을 폐지하는 표결 뒤에도 비밀로 남고, 세우는 표결 뒤에도 공개로 남는다', () => {
    const a = council('k01-secret-a', x => enactLaw(x, 'secret_ballot', []));
    const ra = castVote(a)!;
    expect(ra.secret).toBe(true);
    repealLaw(a, 'secret_ballot');
    expect(ballotSecret(a)).toBe(true);

    const b = council('k01-secret-b');
    expect(castVote(b)!.secret).toBe(false);
    enactLaw(b, 'secret_ballot', []);
    expect(ballotSecret(b)).toBe(false);
  });

  it('비밀 개표는 칸별 결과가 아니라 전체 수만 켠다', () => {
    const g = council('k01-secret-seats', x => enactLaw(x, 'secret_ballot', []));
    const r = castVote(g)!;
    const map = shownBlocs(g, blocs(g, currentAgenda(g)!, g.council!.deals));
    const all = secretStates(g, map, r, r.flips.length);
    const flat = COMMS.flatMap(c => all[c]);
    expect(flat.filter(s => s === 'yes')).toHaveLength(r.yes);
    expect(flat.filter(s => s === 'no')).toHaveLength(r.no);
    for (const c of COMMS) expect(all[c].filter(s => s === 'absent')).toHaveLength(r.byComm[c].absent);
    const none = secretStates(g, map, r, 0);
    expect(COMMS.flatMap(c => none[c]).filter(s => s === 'und')).toHaveLength(r.flips.length);
    // 같은 회기면 다시 그려도 같은 자리다(난수 상태를 쓰지 않는다).
    expect(secretStates(g, map, r, r.flips.length)).toEqual(all);
  });
});

describe('K01 3: 표결 뒤 쐐기는 결과에서 되살린다', () => {
  it('표결 뒤 관계·옮긴 표가 바뀌어도 화면 쐐기는 결과와 맞는다', () => {
    const g = council('k01-shown');
    const r = castVote(g)!;
    for (const c of COMMS) g.comms[c].rel = c === 'tail' ? 90 : -90;
    g.voteShift = [{ comm: 'guard', n: 5, side: 'yes' }];
    const shown = shownBlocs(g, blocs(g, currentAgenda(g)!, g.council!.deals));
    for (const c of COMMS) {
      const fl = r.flips.filter(f => f.comm === c);
      const fy = fl.filter(f => f.yes).length;
      expect(shown[c].yes + fy, c).toBe(r.byComm[c].yes);
      expect(shown[c].no + fl.length - fy, c).toBe(r.byComm[c].no);
      expect(shown[c].und, c).toBe(fl.length);
      expect(shown[c].absent, c).toBe(r.byComm[c].absent);
    }
  });
});

describe('K01 4: 장작불이 있어도 예고한 피해 그대로', () => {
  it('정찰이 본 위험(불빛 포함) 안에서 일어난다', () => {
    let lines = 0;
    let i = 0;
    for (const place of PLACES) for (const stay of Object.keys(STAY) as StayId[]) for (let k = 0; k < 4; k += 1) {
      const g = createGame(`k01-pyre-${i++}`);
      g.phase = 'stop';
      g.stop = { place: place.id, target: 'food', stay, crewComm: 'tail', crewSize: 6, scout: true, threat: [0.8, 1, 1.4, 1.4][k], done: false, result: null };
      g.pyre = 3;
      const risk = stopRisk(g);
      expect(risk.pyre).toBe(true);
      const r = resolveStop(g, true)!;
      if (risk.maxDead > 0) { expect(r.dead.length).toBeGreaterThanOrEqual(1); expect(r.dead.length).toBeLessThanOrEqual(risk.maxDead); lines += 1; }
      else expect(r.dead).toEqual([]);
      if (risk.maxHurt > 0) { expect(r.injured.length).toBeGreaterThanOrEqual(1); expect(r.injured.length).toBeLessThanOrEqual(risk.maxHurt); }
      else expect(r.injured).toEqual([]);
    }
    expect(lines).toBeGreaterThan(0);
  });
});

describe('K01 5: 설득한 뒤 내린 사람 수와 명단이 같다', () => {
  it('신임 75~79에서 설득하면 인구도 명단도 4분의 1', () => {
    const g = createGame('k01-persuade');
    for (const c of COMMS) { g.comms[c].rel = 0; g.comms[c].grudge = 0; }
    g.comms.tail.rel = -50;
    g.seg = P.segments;
    g.phase = 'settle';
    g.cards = [];
    advance(g);
    const card = g.cards.find(x => x.kind === 'hub_split' && x.comm === 'tail')!;
    const n = g.hub!.plan!.tail!.n;
    g.trust = HUB.persuadeQuarter + 1; // 신임을 치르면 문턱 아래로 떨어진다
    const pop = g.comms.tail.pop;
    const left = g.left?.length ?? 0;
    expect(chooseCard(g, card.uid, 1)).toBe(true);
    expect(g.trust).toBeLessThan(HUB.persuadeQuarter);
    const want = Math.round(n / 4);
    expect(pop - g.comms.tail.pop).toBe(want);
    expect((g.left?.length ?? 0) - left).toBe(Math.min(want, g.hub!.plan!.tail!.names.filter(x => x !== g.comms.tail.leader.name).length));
  });
});

describe('K01 6: 변형 없는 기술도 법이 서 있으면 복원 후보', () => {
  it('찾은 undefined와 못 찾은 null을 가른다', () => {
    const tech = LAW_ONLY_TECHS.find(t => !TECHS[t].variants && techLaws(t).length > 0)!;
    expect(tech).toBeDefined();
    const g = createS1cGame('k01-variant');
    expect(usefulVariant(g, tech)).toBeNull();
    enactLaw(g, techLaws(tech)[0], []);
    expect(usefulVariant(g, tech)).toBeUndefined();
  });
});

describe('K01 7: 온실은 지금 구역만큼 낸다', () => {
  it('지금 구역의 4.3 값, 화차(창고칸)는 ×1.5', () => {
    const g = createS1cGame('k01-green');
    const d = g.dom!;
    d.techs.m4 = { stage: 'done' } as NonNullable<typeof d.techs.m4>;
    const m = techMult(g, 'm4');
    expect(m).toBeGreaterThan(0);
    d.greenhouse = 'tail3';
    expect(greenhouseFood(g) / m).toBeCloseTo(1.5);
    const move = (to: number) => { d.cars = d.cars.filter(c => c !== 'tail3'); d.cars.splice(to, 0, 'tail3'); };
    move(3);
    expect(greenhouseFood(g) / m).toBeCloseTo(2.25);
    move(0);
    expect(greenhouseFood(g) / m).toBeCloseTo(3);
    d.greenhouse = 'store';
    expect(greenhouseFood(g) / m).toBeCloseTo(2.25);
    // 창고칸을 가운데로 옮기면 이득이 생긴다(옛 코드는 2.25 그대로였다).
    d.cars = d.cars.filter(c => c !== 'store'); d.cars.splice(3, 0, 'store');
    expect(greenhouseFood(g) / m).toBeCloseTo(3.375);
  });

  it('칸을 내줄 곳 카드의 온실 산출 안내는 실제 산출과 같다(결함판이면 절반, PC 리뷰 PR 57 5번)', () => {
    const g = createS1cGame('k01-green-card');
    const d = g.dom!;
    d.techs.m4 = { stage: 'defective', defect: true } as NonNullable<typeof d.techs.m4>;
    const v = viewCard(g, { uid: 1, kind: 'dom:give' });
    const store = v.choices.find(c => c.special === 'dom:give:store')!;
    d.greenhouse = 'store';
    const real = +greenhouseFood(g).toFixed(2);
    expect(real).toBeGreaterThan(0);
    expect(store.extra).toContain(`온실 식량 +${real}/구간`);
  });
});

describe('K01 8: 비상 소집은 적의를 빨리 풀지 못한다', () => {
  it('정기 회기만 센다', () => {
    const g = createGame('k01-grudge');
    openCouncil(g);
    offend(g, 'tail');
    const grudge = g.comms.tail.grudge;
    openCouncil(g, true);
    openCouncil(g);
    expect(g.comms.tail.grudge).toBe(grudge);
    openCouncil(g);
    expect(g.comms.tail.grudge).toBe(grudge - 1);
    expect(P.grudgeDecay).toBe(2);
  });
});

describe('K01 9: 값을 못 치르는 선택지는 보기에서도 고를 때도 막힌다', () => {
  it('사치품 0이면 침상 요구를 들어줄 수 없다', () => {
    const g = createS1cGame('k01-afford');
    g.lux = 0;
    const who = g.dom!.people.find(p => p.field)!.id;
    g.cards.push({ uid: 9001, kind: 'dom:demand', who, n: 0 });
    const card = g.cards.find(x => x.uid === 9001)!;
    expect(viewCard(g, card).choices[0].disabled).toBe('사치품이 모자라다');
    expect(chooseCard(g, 9001, 0)).toBe(false);
    expect(g.cards.some(x => x.uid === 9001)).toBe(true);
    g.lux = 1;
    expect(viewCard(g, card).choices[0].disabled).toBeUndefined();
    expect(chooseCard(g, 9001, 0)).toBe(true);
    expect(g.lux).toBe(0);
  });
});

describe('K01 10: 복사해 가는 JSON은 숫자를 거르지 않는다', () => {
  it('raw 글은 소수점이 그대로, 보통 글은 정수로', () => {
    class FakeNode { kids: FakeNode[] = []; text = ''; appendChild(n: FakeNode) { this.kids.push(n); return n; } setAttribute() {} }
    const G = globalThis as Record<string, unknown>;
    const saved = { Node: G.Node, document: G.document };
    G.Node = FakeNode;
    G.document = { createElement: () => new FakeNode(), createTextNode: (t: string) => Object.assign(new FakeNode(), { text: t }) };
    try {
      const json = JSON.stringify({ medianS: 0.55, food: 2.25 });
      const kept = h('textarea', null, raw(json)) as unknown as FakeNode;
      expect(kept.kids[0].text).toBe(json);
      expect(JSON.parse(kept.kids[0].text)).toEqual({ medianS: 0.55, food: 2.25 });
      const plain = h('textarea', null, json) as unknown as FakeNode;
      expect(plain.kids[0].text).not.toBe(json);
    } finally {
      G.Node = saved.Node;
      G.document = saved.document;
    }
  });

  it('화면의 모든 textarea는 raw로 채운다', () => {
    for (const f of ['panels.ts', 'domestic.ts', 'dark.ts']) {
      const src = readFileSync(join(__dirname, '../../src/ui', f), 'utf8');
      for (const line of src.split('\n').filter(l => l.includes("h('textarea'"))) expect(line, f).toContain('raw(');
    }
  });
});
