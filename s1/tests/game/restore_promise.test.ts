import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { createS1cGame, D, domesticPromise, domesticPromiseMade, NOT_YET, P, researchChoice, TECHS, techAdopted } from '../../src/game';
import type { Game, TechId } from '../../src/game';

// 시스템 통합 보고서(PR 137) A01·A02: '기술·의무진이 고른 복원' 약속은 그들이 지정한 기술을 기준으로 판정하고,
// 지정 후보는 이 열차에서 실제로 시작할 수 있는 기술 가운데서만 고른다.

const ALL = Object.keys(TECHS) as TechId[];
const likedByMed = (id: TechId): boolean =>
  TECHS[id].like.includes('medtech') || Object.values(TECHS[id].variants ?? {}).some(v => v.like.includes('medtech'));

function promised(seed = 'rp'): Game {
  const g = createS1cGame(seed);
  g.seg = 5;
  const cond = { kind: 'research_pick' as const, label: '연구 우선권', now: false, s1c: true };
  g.comms.medtech.promise = { kind: 'open', cond, label: cond.label, due: g.seg + P.promiseSegments, madeSession: 0 };
  domesticPromiseMade(g);
  return g;
}

/** 정산에서 약속을 확인하는 순간(due 구간)으로 가서 판정을 받는다. */
function judge(g: Game): boolean | null {
  const p = g.comms.medtech.promise!;
  g.seg = p.due;
  return domesticPromise(g, 'medtech', p);
}

describe('A01 고른 복원 약속은 지정한 기술로 판정한다(시작 기준)', () => {
  const before = D.pickFulfil;
  beforeEach(() => { D.pickFulfil = 'start'; });
  afterEach(() => { D.pickFulfil = before; });

  it('의무진이 좋아하는 다른 기술을 시작했다고 지킨 것이 되지 않는다', () => {
    const g = promised();
    const pick = g.dom!.researchPick!;
    expect(pick).toBeTruthy();
    const other = ALL.find(id => id !== pick && !NOT_YET.includes(id) && likedByMed(id))!;
    expect(other).toBeTruthy();
    g.dom!.log.restores.push({ seg: g.seg + 1, id: other });
    expect(judge(g)).toBe(false);
  });

  it('지정한 기술을 기간 안에 시작하면 지킨 것이다(시작하면 우선권 표시가 지워져도)', () => {
    const g = promised();
    const pick = g.dom!.researchPick!;
    g.dom!.log.restores.push({ seg: g.seg + 1, id: pick });
    g.dom!.researchPick = null; // startRestore가 하는 일
    expect(judge(g)).toBe(true);
  });

  it('기간 안에 아무것도 시작하지 않으면 깨진다', () => {
    const g = promised();
    expect(judge(g)).toBe(false);
  });

  it('값 하나(D.pickFulfil)로 "복원을 마쳐야 지킨 것"으로 바꿀 수 있다', () => {
    const g = promised();
    const pick = g.dom!.researchPick!;
    g.dom!.log.restores.push({ seg: g.seg + 1, id: pick });
    g.dom!.techs[pick] = { stage: 'restoring', defect: false, progress: 0, need: 3 };
    const before = D.pickFulfil;
    D.pickFulfil = 'complete';
    try {
      expect(judge(g)).toBe(false);
      const h = promised('rp2');
      const p2 = h.dom!.researchPick!;
      h.dom!.log.restores.push({ seg: h.seg + 1, id: p2 });
      h.dom!.techs[p2] = { stage: 'done', defect: false, progress: 3, need: 3 };
      expect(judge(h)).toBe(true);
    } finally {
      D.pickFulfil = before;
    }
  });

  it('지정한 기술이 없던 약속(옛 저장·후보 없음)은 지킨 것으로 본다', () => {
    const g = promised();
    g.dom!.researchPick = null;
    expect(judge(g)).toBe(true);
  });
});

describe('A02 약속 후보는 실행할 수 있는 기술만 된다', () => {
  it('열 수 있는 기술이 R3뿐이어도 잠긴 R3를 후보로 고르지 않는다', () => {
    const g = createS1cGame('rp-r3');
    for (const id of ALL) {
      if (id !== 'r3' && likedByMed(id)) g.dom!.techs[id] = { stage: 'done', defect: false, progress: 1, need: 1 };
    }
    expect(NOT_YET).toContain('r3');
    const pick = researchChoice(g);
    expect(pick === null || !NOT_YET.includes(pick)).toBe(true);
  });
});

describe('A01 채택 기준(사용자 2026-10-10 「완성하고 채택까지」)', () => {
  const before = D.pickFulfil;
  afterEach(() => { D.pickFulfil = before; });
  const done = (g: Game, id: TechId) => { g.dom!.techs[id] = { stage: 'done', defect: false, progress: 3, need: 3 }; };

  it('기본 기준은 채택이다', () => {
    expect(before).toBe('adopt');
  });

  it('시작만 해서는 지킨 것이 아니다', () => {
    const g = promised();
    const pick = g.dom!.researchPick!;
    g.dom!.log.restores.push({ seg: g.seg + 1, id: pick });
    g.dom!.techs[pick] = { stage: 'restoring', defect: false, progress: 0, need: 3 };
    expect(judge(g)).toBe(false);
  });

  it('완성판이고 꺼 두지 않았으면 지킨 것이다', () => {
    const g = promised();
    done(g, g.dom!.researchPick!);
    expect(judge(g)).toBe(true);
  });

  it('결함판은 채택으로 치지 않는다', () => {
    const g = promised();
    const pick = g.dom!.researchPick!;
    g.dom!.techs[pick] = { stage: 'defective', defect: true, progress: 3, need: 3 };
    expect(judge(g)).toBe(false);
  });

  it('꺼 두었거나 추인을 기다리면 채택이 아니다', () => {
    const g = promised('rp-off');
    const pick = g.dom!.researchPick!;
    done(g, pick);
    g.dom!.techs[pick]!.off = true;
    expect(techAdopted(g, pick)).toBe(false);
    g.dom!.techs[pick]!.off = false;
    g.dom!.techs[pick]!.pending = true;
    expect(techAdopted(g, pick)).toBe(false);
    g.dom!.techs[pick]!.pending = false;
    expect(techAdopted(g, pick)).toBe(true);
  });

  it('칸에 놓는 기술(온실칸·단열·장갑)은 한 칸 이상에 놓아야 채택이다', () => {
    const g = createS1cGame('rp-place');
    const d = g.dom!;
    for (const id of ['m4', 'e5', 'w3'] as TechId[]) done(g, id);
    expect([techAdopted(g, 'm4'), techAdopted(g, 'e5'), techAdopted(g, 'w3')]).toEqual([false, false, false]);
    d.greenhouse = 'store';
    d.insulated = ['tail'];
    d.armored = ['guard'];
    expect([techAdopted(g, 'm4'), techAdopted(g, 'e5'), techAdopted(g, 'w3')]).toEqual([true, true, true]);
  });

  it('완성 기준(complete)은 꺼 둔 기술도 완성으로 친다', () => {
    D.pickFulfil = 'complete';
    const g = promised('rp-c');
    const pick = g.dom!.researchPick!;
    done(g, pick);
    g.dom!.techs[pick]!.off = true;
    expect(judge(g)).toBe(true);
  });
});
