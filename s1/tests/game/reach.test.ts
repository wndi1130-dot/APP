import { describe, expect, it } from 'vitest';
import { REACH_NOTES, reachReport } from '../../tools/reach_check';

// r8 닿음 검사: 자동 플레이로 안 나오는 사건·카드는 REACH_NOTES에 까닭이 있어야 한다.
// 끊어진 후속(그리는 곳 없는 카드, 고를 수 없는 카드)은 봇이 예외를 던져 여기서 실패한다.
describe('닿음 검사', () => {
  it('까닭 없이 안 나오는 사건·카드가 없다', () => {
    const r = reachReport(30);
    expect(r.unexpected).toEqual([]);
  }, 60_000);

  it('까닭은 있는 카드 종류에만 붙는다', () => {
    const r = reachReport(1);
    const known = new Set([...Object.keys(r.seen), ...r.unreached]);
    for (const k of Object.keys(REACH_NOTES)) expect(known.has(k), k).toBe(true);
  }, 60_000);
});
