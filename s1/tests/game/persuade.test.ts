import { describe, expect, it } from 'vitest';
import {
  blocs, breakPromise, COMMS, createGame, currentAgenda, finishPreVote, keepPromise, LAWS, makeDeal, openCouncil, P, persuadeChance, persuadeEvidence,
  preVote, toolStatus,
} from '../../src/game';
import type { Agenda, Comm, Game, LawId } from '../../src/game';

// 설득(결정 433, 표결 전 수단 셋의 셋째): 값은 들지 않고 신임·관계·그 칸과 지킨 약속·근거로 미정을 돌린다.
// 관계가 나쁘면 잘 안 먹히고, 안 먹히면 그 칸과는 이번 회기에 다른 거래도 못 하고 관계가 조금 깎인다.

function council(seed: string, set?: (g: Game) => void): Game {
  const g = createGame(seed);
  set?.(g);
  openCouncil(g);
  if (preVote(g)) finishPreVote(g);
  return g;
}

/** 설득할 미정이 있는 칸 하나 */
function swayable(g: Game): Comm {
  const a = currentAgenda(g)!;
  const map = blocs(g, a, g.council!.deals);
  return COMMS.find(c => map[c].und > 0 && g.comms[c].grudge < P.hostileGrudge)!;
}

const law = (id: LawId): Agenda => ({ law: id, repeal: false }) as Agenda;

describe('설득', () => {
  it('확률은 관계·신임·지킨 약속을 따라 오르고 어긴 약속에 내리며, 정한 범위 안에 있다', () => {
    const g = createGame('pers-chance');
    const a = law('common_kitchen');
    const c: Comm = 'engine';
    const p0 = persuadeChance(g, c, a);
    g.comms[c].rel += 30;
    const p1 = persuadeChance(g, c, a);
    expect(p1).toBeGreaterThan(p0);
    g.trust += 20;
    expect(persuadeChance(g, c, a)).toBeGreaterThan(p1);
    const p2 = persuadeChance(g, c, a);
    g.comms[c].kept = 2;
    expect(persuadeChance(g, c, a)).toBeGreaterThan(p2);
    g.comms[c].broken = 3;
    expect(persuadeChance(g, c, a)).toBeLessThan(p2);
    g.comms[c].rel = -100;
    expect(persuadeChance(g, c, a)).toBe(P.persuadeMin);
    Object.assign(g.comms[c], { rel: 100, kept: 9, broken: 0 });
    g.trust = 100;
    expect(persuadeChance(g, c, a)).toBe(P.persuadeMax);
  });

  it('안건이 지금의 위기를 푸는 법이면 그 위기가 근거가 된다', () => {
    const g = createGame('pers-evidence');
    const food = (Object.keys(LAWS) as LawId[]).find(id => LAWS[id].crisis.includes('food'))!;
    const a = law(food);
    g.food = P.crisisLine + 10;
    expect(persuadeEvidence(g, a)).toBeNull();
    const p0 = persuadeChance(g, 'tail', a);
    g.food = P.crisisLine - 1;
    expect(persuadeEvidence(g, a)).toBe('food');
    expect(persuadeChance(g, 'tail', a)).toBeCloseTo(Math.min(P.persuadeMax, p0 + P.persuadeEvidence));
    expect(persuadeEvidence(g, { ...a, repeal: true } as Agenda)).toBeNull();
  });

  it('먹히면 그 칸의 미정이 모두 찬성으로 돌고, 꿈쩍 않는 반대는 그대로다', () => {
    for (let i = 0; i < 40; i += 1) {
      const g = council(`pers-ok-${i}`, x => { x.trust = 100; for (const c of COMMS) Object.assign(x.comms[c], { rel: 60, grudge: 0, kept: 3 }); });
      const c = swayable(g);
      if (!c) continue;
      const a = currentAgenda(g)!;
      const before = blocs(g, a, g.council!.deals)[c];
      const out = makeDeal(g, c, 'persuade');
      if (!out.ok) continue;
      const after = blocs(g, a, g.council!.deals)[c];
      expect(after.und).toBe(0);
      expect(after.yes).toBeGreaterThanOrEqual(before.yes + before.und);
      expect(after.no).toBeGreaterThanOrEqual(before.hard);
      expect(g.council!.deals.find(d => d.comm === c)?.tool).toBe('persuade');
      return;
    }
    throw new Error('먹힌 설득을 못 찾았다');
  });

  it('안 먹히면 그 칸 관계가 조금 깎이고, 그 회기엔 그 칸과 다른 거래도 못 한다', () => {
    for (let i = 0; i < 80; i += 1) {
      const g = council(`pers-no-${i}`, x => { x.trust = 10; for (const c of COMMS) Object.assign(x.comms[c], { grudge: 0, broken: 2 }); });
      const c = swayable(g);
      if (!c) continue;
      const rel0 = g.comms[c].rel;
      const out = makeDeal(g, c, 'persuade');
      if (out.ok) continue;
      expect(g.comms[c].rel).toBe(rel0 + P.persuadeFailRel);
      expect(g.council!.deals.find(d => d.comm === c)?.refused).toBe(true);
      expect(toolStatus(g, c, 'open').ok).toBe(false);
      const a = currentAgenda(g)!;
      expect(blocs(g, a, g.council!.deals)[c].und).toBe(blocs(g, a, [])[c].und);
      return;
    }
    throw new Error('안 먹힌 설득을 못 찾았다');
  });

  it('같은 회기에 다시 물어도 결과가 같다(판 난수를 쓰지 않는다)', () => {
    const make = () => council('pers-same', x => { for (const c of COMMS) x.comms[c].grudge = 0; });
    const g1 = make();
    const g2 = make();
    const c = swayable(g1);
    const r1 = makeDeal(g1, c, 'persuade');
    const r2 = makeDeal(g2, c, 'persuade');
    expect(r1.ok).toBe(r2.ok);
    expect(g1.rng).toEqual(g2.rng);
  });

  it('적대하는 칸은 설득을 듣지 않고, 화면 비용 줄에 될 듯한 몫이 보인다', () => {
    const g = council('pers-hostile', x => { for (const c of COMMS) x.comms[c].grudge = 0; });
    const c = swayable(g);
    expect(toolStatus(g, c, 'persuade').cost).toMatch(/될 듯 \d+%/);
    g.comms[c].grudge = P.hostileGrudge;
    expect(toolStatus(g, c, 'persuade').ok).toBe(false);
  });

  it('약속을 지키고 어기면 그 칸의 누계가 는다', () => {
    const g = createGame('pers-count');
    keepPromise(g, 'tail', '시험');
    keepPromise(g, 'tail', '시험');
    breakPromise(g, 'front', '시험');
    expect(g.comms.tail.kept).toBe(2);
    expect(g.comms.front.broken).toBe(1);
    expect(g.comms.engine.kept ?? 0).toBe(0);
  });
});

// 협박의 대가(결정 433): 표는 빨리 오지만 열차장 신임과 그 칸 관계가 깎이고, 비용 줄에 신임 몫이 보인다.
describe('협박의 대가', () => {
  it('누르면 신임과 그 칸 관계가 깎이고 앙금이 쌓인다', () => {
    const g = council('bm-cost', x => { x.trust = 50; for (const c of COMMS) Object.assign(x.comms[c], { grudge: 0, rel: 0 }); });
    const c = swayable(g);
    g.secrets.push({ id: 99, text: '시험 비밀', weight: 2, about: c, uses: 0 });
    expect(toolStatus(g, c, 'blackmail').cost).toBe(`비밀 1 · 신임 −${Math.abs(P.blackmailTrust)}`);
    const trust0 = g.trust;
    expect(makeDeal(g, c, 'blackmail').ok).toBe(true);
    expect(g.trust).toBe(trust0 + P.blackmailTrust);
    expect(g.comms[c].rel).toBe(P.blackmailRel);
    expect(g.comms[c].grudge).toBe(1);
  });
});
