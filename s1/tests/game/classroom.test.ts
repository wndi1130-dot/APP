import { describe, expect, it } from 'vitest';
import { createS1cGame, enactLaw, lawTechRes, repealLaw, restoreCost, workPower } from '../../src/game';
import type { Game } from '../../src/game';
import { addWound } from '../../src/game/wounds';
import type { WoundGrade } from '../../src/game/wounds';
import {
  chooseSide, childHaul, childSettle, classroomLine, eduLookLines, engineLearn, halved, handsNote, healCut, saveRestore, workBonus,
} from '../../src/game/domestic/classroom';

// 수업과 아동 노동(결정 205·207·208·209·214·223·224). 숫자는 명세의 값이고, 글은 규칙의 모양만 본다.

const fresh = (seed = 'cls'): Game => createS1cGame(seed);
const stand = (g: Game, ...laws: Parameters<typeof enactLaw>[1][]): void => { for (const l of laws) enactLaw(g, l, []); };
const rel = (g: Game): number => g.comms.medtech.rel;

describe('아동 노동의 값', () => {
  it('산출 배수 1.15, 짐 꾸리기는 1.1 그대로이고, 수업이 같이 서면 덤이 반이다', () => {
    const g = fresh();
    expect(lawTechRes(g, 'child_labor').haulMult).toBe(1.15);
    expect(lawTechRes(g, 'child_pack').haulMult).toBe(1.1);
    stand(g, 'child_labor');
    expect(childHaul(g, 'child_labor', 1.15)).toBeCloseTo(1.15);
    stand(g, 'edu_letters');
    expect(halved(g)).toBe(true);
    expect(childHaul(g, 'child_labor', 1.15)).toBeCloseTo(1.075);
    expect(childHaul(g, 'child_pack', 1.1)).toBeCloseTo(1.05);
  });

  it('세워도 의무진 관계는 바로 안 깎이고, 정산마다 1씩 깎이다 폐지하면 멈춘다', () => {
    const g = fresh();
    const r0 = rel(g);
    stand(g, 'child_labor');
    expect(rel(g)).toBe(r0);
    const notes: string[] = [];
    childSettle(g, notes);
    childSettle(g, notes);
    expect(rel(g)).toBe(r0 - 2);
    expect(notes).toHaveLength(2);
    repealLaw(g, 'child_labor');
    childSettle(g, notes);
    expect(rel(g)).toBe(r0 - 2);
  });

  it('반반이면 정산마다 0.5씩 깎인다', () => {
    const g = fresh();
    stand(g, 'edu_letters', 'child_labor');
    const r0 = rel(g);
    childSettle(g, []);
    expect(rel(g)).toBeCloseTo(r0 - 0.5);
  });

  it('짐 줄: 아동 노동만, 수업만, 반반이 다르게 적히고 아이 이름이 없다', () => {
    const a = fresh();
    stand(a, 'child_labor');
    expect(handsNote(a)).toContain('+15%');
    const b = fresh();
    stand(b, 'edu_letters');
    expect(handsNote(b)).toMatch(/\+0%|어른만/);
    const c = fresh();
    stand(c, 'edu_letters', 'child_labor');
    expect(handsNote(c)).toContain('반나절만');
    expect(handsNote(c)).toContain('+7.5%');
  });
});

describe('공방 곁', () => {
  it('일 +1(반반이면 +0.5)이 모든 곱셈 뒤에 얹힌다', () => {
    const g = fresh();
    const base = workPower(g);
    stand(g, 'edu_trade');
    chooseSide(g, 'workshop');
    expect(workBonus(g)).toBe(1);
    expect(workPower(g)).toBeCloseTo(base + 1);
    stand(g, 'child_labor');
    expect(workPower(g)).toBeCloseTo(base + 0.5);
  });

  it('곁을 안 골랐거나 의무칸 곁이면 일이 안 는다', () => {
    const g = fresh();
    const base = workPower(g);
    stand(g, 'edu_trade');
    expect(workPower(g)).toBeCloseTo(base);
    chooseSide(g, 'med');
    expect(workPower(g)).toBeCloseTo(base);
  });

  it('복원 목재·고철은 넷에 하나 덜(올림), 0은 0, 1 아래로는 안 내려가고 부품·조각은 그대로다', () => {
    const g = fresh();
    stand(g, 'edu_trade');
    chooseSide(g, 'workshop');
    expect([saveRestore(g, 4), saveRestore(g, 10), saveRestore(g, 1), saveRestore(g, 0)]).toEqual([3, 8, 1, 0]);
    const raw = restoreCost('w1');
    const cut = restoreCost('w1', g);
    expect(cut.parts).toBe(raw.parts);
    expect(cut.frags).toBe(raw.frags);
    expect(cut.wood).toBeLessThanOrEqual(raw.wood);
    expect(cut.scrap).toBeLessThanOrEqual(raw.scrap);
  });

  it('반반이면 여덟에 하나 덜: 10은 9, 4는 그대로', () => {
    const g = fresh();
    stand(g, 'edu_trade', 'child_labor');
    chooseSide(g, 'workshop');
    expect([saveRestore(g, 10), saveRestore(g, 4)]).toEqual([9, 4]);
  });
});

describe('의무칸 곁', () => {
  const days = (g: Game, grade: WoundGrade, i: number) =>
    addWound(g, { who: `시험${i}`, comm: 'tail', from: 'stop', where: '시험', grade, part: 'armL', septic: false }).daysLeft;

  it('깊은 상처와 골절만 하루 먼저 낫고 가벼운 상처는 그대로다', () => {
    const plain = fresh('cls-med');
    const taught = fresh('cls-med');
    stand(taught, 'edu_letters');
    chooseSide(taught, 'med');
    expect(days(taught, 'deep', 1)).toBe(days(plain, 'deep', 1) - 1);
    expect(days(taught, 'fracture', 2)).toBe(days(plain, 'fracture', 2) - 1);
    expect(days(taught, 'light', 3)).toBe(days(plain, 'light', 3));
  });

  it('반반이면 상처 둘에 하나만 앞당겨진다', () => {
    const g = fresh();
    stand(g, 'edu_letters', 'child_labor');
    chooseSide(g, 'med');
    const cuts = [1, 2, 3, 4].map(id => healCut(g, 'deep', id));
    expect(cuts.reduce((a, b) => a + b, 0)).toBe(2);
  });
});

describe('엔진의 가르침과 글과 셈', () => {
  it('견습 한 단계가 한 구간 먼저이고 바닥은 2구간이다', () => {
    const g = fresh();
    expect(engineLearn(g, 'engine', 4, 0)).toBe(4);
    stand(g, 'edu_engine');
    expect([engineLearn(g, 'engine', 4, 0), engineLearn(g, 'engine', 2, 0), engineLearn(g, 'engine', 1, 0)]).toEqual([3, 2, 1]);
    expect(engineLearn(g, 'medical', 4, 0)).toBe(4);
  });

  it('글줄에 아이 이름이 없고 곁 글이 선다', () => {
    const g = fresh();
    stand(g, 'edu_letters');
    chooseSide(g, 'workshop');
    expect(classroomLine(g)).toContain('공방 곁');
    const all = [classroomLine(g), handsNote(g), ...eduLookLines(g)].join('');
    expect(all).not.toMatch(/못 배운/);
  });
});
