import { describe, expect, it } from 'vitest';
import { allocateSeats, createRng } from '../../src/core';
import {
  councilInputs, marksForGroup, projectCouncil, projectionMarks, recordMarks, runCouncilVote,
} from '../../src/ui/model/council-view';
import { DUMMY_BILLS, DUMMY_POPULATIONS, createDummyGame, withDummyFaction } from '../../src/ui/model/dummy';
import { applyEffects } from '../../src/core';

const normalBill = DUMMY_BILLS.find(bill => bill.law.kind === 'normal')!;
const ruleBill = DUMMY_BILLS.find(bill => bill.law.kind === 'rule')!;

describe('의회 화면 계산', () => {
  it('더미 인구(꼬리칸 90, 앞칸 30, 기술·의무진 30, 경비대 25, 기관실 25)를 A2 allocateSeats로 나눈다', () => {
    const game = createDummyGame('council-view');
    const inputs = councilInputs(game, normalBill);
    expect(inputs.map(group => [group.id, group.population])).toEqual([
      ['tail', DUMMY_POPULATIONS.tail], ['medtech', DUMMY_POPULATIONS.medtech], ['guard', DUMMY_POPULATIONS.guard],
      ['front', DUMMY_POPULATIONS.front], ['engine', DUMMY_POPULATIONS.engine],
    ]);
    const seats = allocateSeats(inputs).map(group => group.seats);
    expect(seats).toEqual([45, 15, 12, 15, 13]);
    expect(seats.reduce((sum, value) => sum + value, 0)).toBe(100);
  });

  it('표결 전 예상은 의석을 찬성·반대·미정·부재로 빠짐없이 나눈다', () => {
    const game = createDummyGame('council-view');
    for (const bill of DUMMY_BILLS) {
      const projection = projectCouncil(councilInputs(game, bill), bill.law.kind);
      for (const group of projection.groups) {
        expect(group.yes + group.no + group.undecided + group.absent).toBe(group.seats);
      }
      const { yes, no, undecided, absent } = projection.totals;
      expect(yes + no + undecided + absent).toBe(100);
    }
    expect(projectCouncil(councilInputs(game, normalBill), 'normal').required).toBe(51);
    expect(projectCouncil(councilInputs(game, ruleBill), 'rule').required).toBe(67);
  });

  it('파견 중인 사람은 그 집단의 표에서 빠져 부재가 된다', () => {
    const game = createDummyGame('council-view');
    const away = applyEffects(game, ['p_tail_010', 'p_tail_011', 'p_tail_012', 'p_tail_013'].map(target => ({
      type: 'person.away' as const, target, segments: 2,
    })));
    const tail = projectCouncil(councilInputs(away, normalBill), 'normal').groups[0];
    expect(tail).toMatchObject({ id: 'tail', seats: 45, population: 90, present: 86, available: 43, absent: 2 });
  });

  it('공개 투표는 집단별 기록을, 비밀 투표는 합계만 남긴다. 같은 난수면 합계는 같다', () => {
    const game = createDummyGame('council-view');
    const inputs = councilInputs(game, normalBill);
    const rng = createRng('vote');
    const open = runCouncilVote(inputs, 'normal', 'public', rng);
    const hidden = runCouncilVote(inputs, 'normal', 'secret', rng);
    expect(open.record.mode).toBe('public');
    expect(hidden.record.mode).toBe('secret');
    expect('groups' in hidden.record).toBe(false);
    for (const key of ['yes', 'no', 'abstain', 'absent', 'passed'] as const) {
      expect(hidden.record[key]).toBe(open.record[key]);
    }
    expect(hidden.rng).toEqual(open.rng);
  });

  it('좌석 표시는 의석 수와 같고, 비밀 투표에선 집단별 찬반을 그리지 않는다', () => {
    const game = createDummyGame('council-view');
    const inputs = councilInputs(game, normalBill);
    const projection = projectCouncil(inputs, 'normal');
    const before = projectionMarks(projection);
    expect(before).toHaveLength(100);
    expect(before.filter(mark => mark === 'yes')).toHaveLength(projection.totals.yes);
    const rng = createRng('marks');
    const open = recordMarks(runCouncilVote(inputs, 'normal', 'public', rng).record, projection);
    const hidden = recordMarks(runCouncilVote(inputs, 'normal', 'secret', rng).record, projection);
    expect(open).toHaveLength(100);
    expect(hidden).toHaveLength(100);
    expect(hidden.some(mark => mark === 'yes' || mark === 'no' || mark === 'abstain')).toBe(false);
    expect(hidden.filter(mark => mark === 'unknown')).toHaveLength(100 - projection.totals.absent);
    expect(() => marksForGroup({ yes: 3 }, 4)).toThrow();
  });

  it('더미 세력을 넣으면 세력원은 세력 의석으로 센다', () => {
    const game = withDummyFaction(createDummyGame('council-view'), true);
    const projection = projectCouncil(councilInputs(game, normalBill), 'normal');
    expect(projection.groups.map(group => group.id)).toEqual(['tail', 'medtech', 'guard', 'front', 'engine', 'faction_restore']);
    expect(projection.groups.map(group => group.population)).toEqual([80, 26, 25, 30, 25, 14]);
    expect(projection.groups.reduce((sum, group) => sum + group.seats, 0)).toBe(100);
    const back = withDummyFaction(game, false);
    expect(Object.keys(back.groups)).toEqual(['tail', 'medtech', 'guard', 'front', 'engine']);
    expect(back.groups.tail.members).toHaveLength(90);
  });
});
