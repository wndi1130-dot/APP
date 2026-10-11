import { describe, expect, it } from 'vitest';
import { FIELDS, TECH_IDS, createS1cGame, restoreCheck } from '../../src/game';
import type { Card, TechState } from '../../src/game';
import { BRANCH_SHORT, recommendTech } from '../../src/ui/domestic';

// 기술 화면의 「먼저」 리본(사용자 2026-10-11: 처음에 무엇부터 할지 모르겠다). 권하는 기술은 하나뿐이고 상태를 바꾸지 않는다.

const done: TechState = { stage: 'done', defect: false, progress: 3, need: 3 };

describe('기술 화면: 먼저 리본', () => {
  it('가지 이름은 두 글자다', () => {
    for (const f of FIELDS) expect(BRANCH_SHORT[f]).toHaveLength(2);
  });

  it('새 판에서는 지금 바로 되고 싫어하는 칸이 없는 응급 처치를 권한다', () => {
    const g = createS1cGame('rec-new');
    const before = JSON.stringify(g);
    const rec = recommendTech(g)!;
    expect(rec.id).toBe('m1');
    expect(restoreCheck(g, rec.id).full).toBeFalsy();
    expect(rec.why.length).toBeLessThanOrEqual(30);
    expect(JSON.stringify(g)).toBe(before);
  });

  it('「설계도가 맞았다」 서류가 와 있으면 그 기술이 먼저다', () => {
    const g = createS1cGame('rec-fit');
    g.cards.push({ uid: 9999, kind: 'dom:fit', text: 'e5' } as Card);
    expect(recommendTech(g)!.id).toBe('e5');
  });

  it('복원 중이거나 이미 셋을 되살렸으면 권하지 않는다', () => {
    const g = createS1cGame('rec-none');
    g.dom!.restoring = 'm1';
    g.dom!.techs.m1 = { stage: 'restoring', defect: false, progress: 0, need: 3 };
    expect(recommendTech(g)).toBeNull();
    const g2 = createS1cGame('rec-three');
    for (const id of TECH_IDS.slice(0, 3)) g2.dom!.techs[id] = { ...done };
    expect(recommendTech(g2)).toBeNull();
  });

  it('지금 되는 것이 없으면 조각이 가장 모인 가지의 다음 기술과 모자란 조각 수를 말한다', () => {
    const g = createS1cGame('rec-frag');
    const d = g.dom!;
    d.parts = 0;
    d.wood = 0;
    for (const f of FIELDS) d.frags[f] = 0;
    d.frags.radio = 1;
    d.techs.r1 = { ...done };
    const rec = recommendTech(g)!;
    expect(rec.id).toBe('r2');
    expect(rec.why).toContain('통신 조각 1개');
  });
});
