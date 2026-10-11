import { describe, expect, it } from 'vitest';
import { isKeyLine, logGroups } from '../../src/ui/journal';

// 일지 접기(사용자 2026-10-11): 구간별로 묶고, 묶음마다 중요한 줄만 보이고 나머지는 수로 센다.

const J = [
  { seg: 1, text: '가' },
  { seg: 1, text: '나', tone: 'bad' as const },
  { seg: 2, text: '다', tone: 'good' as const },
  { seg: 2, text: '라', tone: 'deal' as const },
  { seg: 2, text: '마', tone: 'dark' as const },
  { seg: 3, text: '바' },
];

describe('일지 묶음', () => {
  it('거래, 선을 넘은 일, 나쁜 일만 중요한 줄이다', () => {
    expect(J.filter(isKeyLine).map(e => e.text)).toEqual(['나', '라', '마']);
  });

  it('새 구간이 위로 오고, 접힌 묶음은 중요한 줄만 보이며 나머지를 센다', () => {
    const gs = logGroups(J, []);
    expect(gs.map(g => g.seg)).toEqual([3, 2, 1]);
    expect(gs.map(g => g.lines.map(e => e.text))).toEqual([[], ['마', '라'], ['나']]);
    expect(gs.map(g => g.more)).toEqual([1, 1, 1]);
  });

  it('펼친 묶음은 그 구간 줄을 다 보인다', () => {
    const g2 = logGroups(J, [2]).find(g => g.seg === 2)!;
    expect(g2.open).toBe(true);
    expect(g2.lines.map(e => e.text)).toEqual(['마', '라', '다']);
    expect(g2.more).toBe(0);
  });

  it('줄을 잃지 않는다', () => {
    const gs = logGroups(J, []);
    expect(gs.reduce((n, g) => n + g.lines.length + g.more, 0)).toBe(J.length);
  });
});
