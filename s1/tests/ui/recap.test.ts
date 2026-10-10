import { describe, expect, it } from 'vitest';
import { createS1cGame } from '../../src/game';
import { RECAP_ROWS, segRecap } from '../../src/ui/panels';

// 구간 끝 '내가 한 일' 한 장(사용자 2026-10-11).

describe('구간 끝에 내가 한 일', () => {
  it('방금 정산한 구간의 일만, 이름으로 묶어 바뀐 것을 적는다. 정산 자체는 뺀다', () => {
    const g = createS1cGame('recap-1');
    g.meterLog = [
      { seg: 1, label: '옛 일', trust: -9, tension: 0 },
      { seg: 2, label: '저탄장 수색: 운반조부터 부른다', trust: 4, tension: 0 },
      { seg: 2, label: '정차 수색', trust: 0, tension: 2 },
      { seg: 2, label: '구간 정산', trust: -1, tension: 1 },
    ];
    g.resLog = [
      { seg: 2, label: '저탄장 수색: 운반조부터 부른다', coal: 1, food: 0, med: 0, lux: 0 },
      { seg: 2, label: '정차 수색', coal: -2, food: 7, med: 13, lux: 0 },
      { seg: 2, label: '구간 정산', coal: -9, food: -10, med: 0, lux: 0 },
    ];
    expect(segRecap(g)).toEqual([
      { label: '저탄장 수색: 운반조부터 부른다', parts: ['신임 +4', '석탄 +1'] },
      { label: '정차 수색', parts: ['긴장 +2', '석탄 −2', '식량 +7', '의약품 +13'] },
    ]);
    // 집단 관계는 수치 뒤에 크게 바뀐 것부터. 관계만 바뀐 일도 한 줄이 된다.
    g.relLog = [
      { seg: 2, label: '저탄장 수색: 운반조부터 부른다', rel: { front: 2, tail: -6 } },
      { seg: 2, label: '꼬리칸 거래', rel: { tail: 5 } },
      { seg: 2, label: '구간 정산', rel: { engine: 3 } },
      { seg: 1, label: '옛 일', rel: { guard: 9 } },
    ];
    expect(segRecap(g)).toEqual([
      { label: '저탄장 수색: 운반조부터 부른다', parts: ['신임 +4', '석탄 +1', '꼬리칸 관계 −6', '앞칸 관계 +2'] },
      { label: '정차 수색', parts: ['긴장 +2', '석탄 −2', '식량 +7', '의약품 +13'] },
      { label: '꼬리칸 거래', parts: ['꼬리칸 관계 +5'] },
    ]);
  });

  it('정산 기록이 없으면(옛 저장, 첫 구간 도중) 비어 있고, 줄 수는 상한까지만이다', () => {
    const g = createS1cGame('recap-2');
    expect(segRecap(g)).toEqual([]);
    g.meterLog = [
      ...Array.from({ length: 6 }, (_, i) => ({ seg: 3, label: `일 ${i + 1}`, trust: 1, tension: 0 })),
      { seg: 3, label: '구간 정산', trust: -1, tension: 0 },
    ];
    const rows = segRecap(g);
    expect(rows.length).toBe(RECAP_ROWS);
    expect(rows[rows.length - 1].label).toBe('일 6');
  });
});
