import { describe, expect, it, vi } from 'vitest';
import { D } from '../../src/game/domestic/data';
import type { Field } from '../../src/game/domestic/data';
import { FIELD_BONUS, FIELD_GATE, fieldBenefit, fieldGate, fieldReady } from '../../src/game/domestic/field_benefits';
import type { FieldWorker } from '../../src/game/domestic/field_benefits';

const worker = (field: Field, id = 'worker_a', skill = 1): FieldWorker => ({ id, field, skill, alive: true });

describe('분야 혜택 준비', () => {
  it('기관 상한은 법과 자동 레버에도 같다', () => {
    expect(Object.keys(FIELD_GATE)).toHaveLength(5);
    expect(Object.keys(FIELD_BONUS)).toEqual(['engine', 'med', 'radio', 'expedition']);
    const people = Object.freeze([Object.freeze(worker('engine'))]);
    for (const mode of ['manual', 'auto'] as const) {
      expect(fieldGate([], { field: 'engine', requestedHeat: 3, mode })).toMatchObject({ value: 2, allowed: false });
      expect(fieldGate([], { field: 'engine', requestedHeat: 1, lawFloor: 4, mode })).toMatchObject({ value: 2, requested: 4 });
      expect(fieldGate(people, { field: 'engine', requestedHeat: 3, mode })).toMatchObject({ value: 3, allowed: true });
      expect(fieldGate(people, { field: 'engine', requestedHeat: 3, operationCap: 1, mode }).value).toBe(1);
    }
    for (const missing of [{ alive: false }, { gone: true }, { resting: true }, { treating: true }, { skill: 0 }, { aboard: false }]) {
      expect(fieldReady('engine', [{ ...worker('engine'), ...missing }])).toBe(false);
    }
    const request = { field: 'engine' as const, baseCost: 10, round: (value: number) => Math.round(value * 10) / 10 };
    expect(fieldBenefit(people, request)).toMatchObject({ before: 10, after: 9.8 });
    expect(fieldBenefit(people, request).benefit).toBeCloseTo(0.2);
    expect(fieldBenefit([...people, worker('engine', 'worker_b')], request)).toEqual(fieldBenefit(people, request));
    expect(fieldBenefit([], request).benefit).toBe(0);
    expect(fieldBenefit(people, { ...request, baseCost: 1, round: Math.round }).benefit).toBe(0);
  });

  it('의료 부재는 새 회복 단축만 막는다', () => {
    const newRecord = { field: 'med' as const, baseDays: 9, requestedDays: 6, floor: 3, newRecord: true, grade: 'deep' as const };
    expect(fieldGate([], newRecord)).toMatchObject({ value: 9, allowed: false });
    expect(fieldGate([worker('med')], newRecord)).toMatchObject({ value: 6, allowed: true });
    expect(fieldGate([], { ...newRecord, newRecord: false, requestedDays: 4 }).value).toBe(4);
    expect(fieldGate([], { ...newRecord, newRecord: false, requestedDays: 1 }).value).toBe(1);
    expect(fieldGate([], { ...newRecord, grade: 'light' }).value).toBe(6);
    const request = { ...newRecord, classroomDays: 2 };
    expect(fieldBenefit([worker('med')], request)).toEqual({ before: 7, after: 6, benefit: 1 });
    expect(fieldBenefit([], request)).toEqual({ before: 9, after: 9, benefit: 0 });
    expect(fieldBenefit([worker('med')], { ...request, baseDays: 3 })).toEqual({ before: 3, after: 3, benefit: 0 });
    expect(fieldBenefit([worker('med')], { ...request, newRecord: false, baseDays: 4 })).toEqual({ before: 4, after: 4, benefit: 0 });
    expect(fieldBenefit([worker('med')], { ...request, newRecord: false, baseDays: 1 })).toEqual({ before: 1, after: 1, benefit: 0 });
    expect(fieldBenefit([worker('med'), worker('med', 'worker_b')], request).benefit).toBe(1);
    expect(fieldBenefit([worker('med')], { ...request, grade: 'fracture' }).benefit).toBe(1);
  });

  it('통신 부재는 정찰 비용 전에 막힌다', () => {
    const cost = vi.fn();
    const damage = vi.fn();
    const random = vi.fn();
    const scout = (people: FieldWorker[]) => {
      if (!fieldGate(people, { field: 'radio' }).allowed) return;
      cost(); damage(); random();
    };
    scout([]);
    expect(cost).not.toHaveBeenCalled();
    expect(damage).not.toHaveBeenCalled();
    expect(random).not.toHaveBeenCalled();
    scout([worker('radio')]);
    expect(cost).toHaveBeenCalledOnce();
    const request = { field: 'radio' as const, baseYield: 100, scoutMultiplier: 0.7, round: Math.round };
    expect(fieldBenefit([worker('radio')], request)).toEqual({ before: 70, after: 75, benefit: 5 });
    expect(fieldBenefit([worker('radio')], { ...request, scoutMultiplier: 0.98 })).toEqual({ before: 98, after: 100, benefit: 2 });
    expect(fieldBenefit([worker('radio')], { ...request, scoutMultiplier: 1 }).benefit).toBe(0);
    expect(fieldBenefit([], request).benefit).toBe(0);
  });

  it('원정 부재는 실제 명단 한 자리 감소다', () => {
    const request = { field: 'expedition' as const, teamIds: ['worker_a', 'worker_b', 'worker_c'], availableIds: ['worker_a', 'worker_b', 'worker_c'] };
    const missing = fieldGate([], request);
    expect(missing.teamIds).toEqual(['worker_a', 'worker_b']);
    expect(missing.value).toBe(missing.teamIds.length);
    expect(new Set(missing.teamIds).size).toBe(missing.value);
    expect(fieldGate([worker('expedition')], request).teamIds).toEqual(request.teamIds);
    expect(fieldGate([worker('expedition', 'worker_other')], request).teamIds).toEqual(missing.teamIds);
    expect(fieldGate([], { ...request, teamIds: ['worker_a'] })).toMatchObject({ teamIds: ['worker_a'], value: 1, allowed: true });
    expect(fieldGate([], { ...request, availableIds: [] })).toMatchObject({ teamIds: [], value: 0, allowed: false });
    expect(fieldGate([{ ...worker('expedition'), alive: false }], { ...request, teamIds: ['worker_a'] }).allowed).toBe(false);
    expect(fieldGate([], { ...request, teamIds: ['worker_a', 'worker_a'] }).teamIds).toEqual(['worker_a']);
    const benefit = { field: 'expedition' as const, earned: 100, teamIds: request.teamIds, round: Math.round };
    expect(fieldBenefit([worker('expedition')], benefit)).toEqual({ before: 100, after: 103, benefit: 3 });
    expect(fieldBenefit([worker('expedition', 'worker_other')], benefit).benefit).toBe(0);
    expect(fieldBenefit([worker('expedition')], { ...benefit, earned: 1 }).benefit).toBe(0);
    expect(request.teamIds).toHaveLength(3);
  });

  it('공작은 기존 숙련과 둘째 길을 따른다', () => {
    expect(fieldGate([], { field: 'craft', tech: 'w1', manual: true }).allowed).toBe(false);
    expect(fieldGate([worker('craft')], { field: 'craft', tech: 'w1' }).allowed).toBe(true);
    expect(fieldGate([worker('craft')], { field: 'craft', tech: 'w3' }).allowed).toBe(false);
    expect(fieldGate([worker('craft', 'worker_a', 3)], { field: 'craft', tech: 'w3' }).allowed).toBe(true);
    const second = [worker('med', 'worker_a', 2), worker('craft', 'worker_b', 3)];
    expect(fieldGate(second, { field: 'craft', tech: 'm4' }).allowed).toBe(true);
    expect(fieldGate([{ ...second[0] }, { ...second[1], resting: true }], { field: 'craft', tech: 'm4' }).allowed).toBe(false);
    expect(fieldGate([{ ...second[0], treating: true }, second[1]], { field: 'craft', tech: 'm4' }).allowed).toBe(false);
    const request = { field: 'craft' as const, multiplier: 1.25, classroomWork: 0.5, restoreAllowed: true };
    const measured = fieldBenefit([worker('craft', 'worker_a', 3)], request);
    expect(measured.before).toBe(D.work * D.workSkill[0] * request.multiplier + 0.5);
    expect(measured.after).toBe(D.work * D.workSkill[3] * request.multiplier + 0.5);
    expect(measured.benefit).toBe(measured.after - measured.before);
    expect(fieldBenefit([], request).benefit).toBe(0);
    expect(fieldBenefit(second, { ...request, restoreAllowed: false })).toEqual({ before: 0, after: 0, benefit: 0 });
    expect(FIELD_BONUS).not.toHaveProperty('craft');
  });
});
