import { describe, expect, it } from 'vitest';
import { createS1cGame, D, domesticPromise, domesticPromiseMade, NOT_YET, P, researchChoice, TECHS } from '../../src/game';
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

describe('A01 고른 복원 약속은 지정한 기술로 판정한다', () => {
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
