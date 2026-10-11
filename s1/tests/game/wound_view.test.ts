import { describe, expect, it } from 'vitest';
import { createGame } from '../../src/game';
import { addWound, GRADE_NAME, unnamedInjured, woundView } from '../../src/game/wounds';

// 의료 화면에 넘기는 읽기 전용 값: 명부를 바꾸지 않고, 판 난수도 쓰지 않는다.

const fresh = (seed: string) => { const g = createGame(seed); g.cards = []; return g; };

describe('woundView', () => {
  it('활성 기록을 사람·부위·등급·남은 구간·치료 자리로 준다', () => {
    const g = fresh('wv-1');
    addWound(g, { who: '가', comm: 'tail', from: 'stop', where: '시험', grade: 'fracture', part: 'legL', septic: false, cuts: 0 });
    addWound(g, { who: '나', comm: 'guard', from: 'stop', where: '시험', grade: 'light', part: 'armR', septic: false, cuts: 0 });
    const rows = woundView(g);
    expect(rows.map(r => r.who)).toEqual(['가', '나']);
    expect(rows[0]).toMatchObject({ partName: '왼다리', grade: 'fracture', gradeName: '골절', daysLeft: 8, care: 'bed', septic: false, medPerDay: 0.5 });
    expect(rows[1]).toMatchObject({ partName: '오른팔', gradeName: GRADE_NAME.light, daysLeft: 1, care: 'up', medPerDay: 0 });
    expect(woundView(g, 'guard').map(r => r.who)).toEqual(['나']);
  });

  it('부르는 것만으로 상태·부상자 수·난수가 바뀌지 않는다', () => {
    const g = fresh('wv-2');
    addWound(g, { who: '가', comm: 'tail', from: 'stop', where: '시험', grade: 'deep', part: 'torso', septic: true });
    const before = JSON.stringify(g);
    woundView(g); unnamedInjured(g);
    expect(JSON.stringify(g)).toBe(before);
  });

  it('나은 기록은 빠지고, 이름 없는 부상자는 g.injured에서 명부를 뺀 수다', () => {
    const g = fresh('wv-3');
    g.injured = 3;
    expect(unnamedInjured(g)).toBe(3);
    expect(woundView(g)).toEqual([]);
    const w = addWound(g, { who: '가', comm: 'tail', from: 'stop', where: '시험', grade: 'light', part: 'torso', septic: false });
    expect(unnamedInjured(g)).toBe(0);
    g.injured = 3;
    expect(unnamedInjured(g)).toBe(2);
    w.state = 'healed';
    expect(woundView(g)).toEqual([]);
  });
});
