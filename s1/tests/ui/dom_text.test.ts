import { describe, expect, it } from 'vitest';
import { D, FIELDS } from '../../src/game';
import { CORE_FROM, ESCORT_GAIN, FRAG_FROM } from '../../src/ui/domestic';

// 내정 화면의 짧은 풀이(사용자 2026-10-11): 전문가가 내는 효과, 조각과 코어가 나오는 길. 규칙 값과 어긋나지 않게 묶어 둔다.

describe('내정 화면의 짧은 풀이', () => {
  it('분야마다 데려가면 얻는 것이 한 줄씩 있고 규칙 값을 그대로 쓴다', () => {
    for (const f of FIELDS) expect(ESCORT_GAIN[f].length).toBeGreaterThan(0);
    expect(ESCORT_GAIN.craft).toContain(String(D.escortMaterials));
    expect(ESCORT_GAIN.engine).toContain(String(D.escortCore));
    expect(ESCORT_GAIN.med).toContain(String(D.escortInjury));
    expect(ESCORT_GAIN.expedition).toContain(String(D.escortRisk));
    expect(ESCORT_GAIN.radio).toContain(`${D.escortFrag * 100}%`);
  });

  it('조각과 코어가 나오는 길은 각각 한두 문장이다', () => {
    for (const text of [FRAG_FROM, CORE_FROM]) expect(text.length).toBeLessThan(70);
  });
});
