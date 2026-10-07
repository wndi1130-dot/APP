import { describe, expect, it } from 'vitest';
import {
  DEFAULT_HEMICYCLE, assignBlocks, hemicycleBounds, layoutHemicycle, minSeatDistance, seatsPerRow,
} from '../../src/ui/seats';
import type { HemicycleOptions } from '../../src/ui/seats';

describe('반원 100석 배치', () => {
  const seats = layoutHemicycle(DEFAULT_HEMICYCLE);

  it('좌석은 정확히 100개이고 줄마다 반지름에 비례한다', () => {
    expect(seats).toHaveLength(100);
    const rows = seatsPerRow(DEFAULT_HEMICYCLE);
    expect(rows.reduce((sum, count) => sum + count, 0)).toBe(100);
    expect(rows).toEqual([...rows].sort((a, b) => a - b));
    for (let row = 0; row < DEFAULT_HEMICYCLE.rows; row += 1) {
      expect(seats.filter(seat => seat.row === row)).toHaveLength(rows[row]);
    }
  });

  it('어느 두 좌석도 겹치지 않는다(중심 거리 > 지름)', () => {
    const diameter = DEFAULT_HEMICYCLE.seatRadius * 2;
    expect(minSeatDistance(seats)).toBeGreaterThan(diameter);
    for (let i = 0; i < seats.length; i += 1) {
      for (let j = i + 1; j < seats.length; j += 1) {
        const distance = Math.hypot(seats[i].x - seats[j].x, seats[i].y - seats[j].y);
        expect(distance).toBeGreaterThan(diameter);
      }
    }
  });

  it('모든 좌석이 반원 경계 상자 안에 있고 아래쪽 반은 비어 있다', () => {
    const bounds = hemicycleBounds(DEFAULT_HEMICYCLE);
    const r = DEFAULT_HEMICYCLE.seatRadius;
    for (const seat of seats) {
      expect(seat.x - r).toBeGreaterThanOrEqual(bounds.minX - 1e-9);
      expect(seat.x + r).toBeLessThanOrEqual(bounds.maxX + 1e-9);
      expect(seat.y - r).toBeGreaterThanOrEqual(bounds.minY - 1e-9);
      expect(seat.y + r).toBeLessThanOrEqual(bounds.maxY + 1e-9);
      expect(seat.y).toBeGreaterThanOrEqual(-1e-9);
      const radius = Math.hypot(seat.x, seat.y);
      expect(radius).toBeGreaterThanOrEqual(DEFAULT_HEMICYCLE.innerRadius - 1e-9);
      expect(radius).toBeLessThanOrEqual(DEFAULT_HEMICYCLE.outerRadius + 1e-9);
    }
  });

  it('좌석은 왼쪽에서 오른쪽으로 각도 순서이고 순번이 이어진다', () => {
    seats.forEach((seat, index) => {
      expect(seat.order).toBe(index);
      if (index > 0) expect(seat.angle).toBeLessThanOrEqual(seats[index - 1].angle);
    });
    expect(seats[0].angle).toBeCloseTo(Math.PI);
    expect(seats.at(-1)?.angle).toBeCloseTo(0);
  });

  it('집단은 각도 순서로 이어진 쐐기를 차지한다', () => {
    const blocks = [
      { id: 'tail', seats: 45 }, { id: 'medtech', seats: 15 }, { id: 'guard', seats: 12 },
      { id: 'front', seats: 15 }, { id: 'engine', seats: 13 },
    ];
    const owners = assignBlocks(seats.length, blocks);
    expect(owners).toHaveLength(100);
    for (const block of blocks) {
      const indices = owners.flatMap((owner, index) => (owner === block.id ? [index] : []));
      expect(indices).toHaveLength(block.seats);
      expect(indices.at(-1)! - indices[0] + 1).toBe(block.seats);
    }
    // 앞 집단의 좌석은 모두 뒤 집단보다 왼쪽(각도가 크거나 같음)에 있다.
    const tailMin = Math.min(...seats.filter((_, index) => owners[index] === 'tail').map(seat => seat.angle));
    const medtechMax = Math.max(...seats.filter((_, index) => owners[index] === 'medtech').map(seat => seat.angle));
    expect(tailMin).toBeGreaterThanOrEqual(medtechMax);
    expect(() => assignBlocks(100, [{ id: 'tail', seats: 99 }])).toThrow();
  });

  it('다른 크기에서도 합과 겹침 조건을 지킨다', () => {
    const cases: HemicycleOptions[] = [
      { total: 100, rows: 5, innerRadius: 50, outerRadius: 150, seatRadius: 6 },
      { total: 60, rows: 4, innerRadius: 40, outerRadius: 100, seatRadius: 5 },
      { total: 7, rows: 7, innerRadius: 10, outerRadius: 70, seatRadius: 3 },
    ];
    for (const options of cases) {
      const layout = layoutHemicycle(options);
      expect(layout).toHaveLength(options.total);
      expect(minSeatDistance(layout)).toBeGreaterThan(options.seatRadius * 2);
    }
    expect(() => layoutHemicycle({ ...DEFAULT_HEMICYCLE, rows: 0 })).toThrow();
    expect(() => layoutHemicycle({ ...DEFAULT_HEMICYCLE, innerRadius: 200 })).toThrow();
  });
});
