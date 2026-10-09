import { afterEach, describe, expect, it } from 'vitest';
import { newGame, notePrologue, prologueDone } from '../../src/ui/domestic';

// 서막 건너뛰기(first_leg_story 5장, 제안): 서막을 한 번 끝낸 브라우저에만 '서막 없이 새 판'이 보인다.

const store = new Map<string, string>();
const fake = { getItem: (k: string) => store.get(k) ?? null, setItem: (k: string, v: string) => void store.set(k, v) };

describe('서막 건너뛰기', () => {
  afterEach(() => { store.clear(); delete (globalThis as { localStorage?: unknown }).localStorage; });

  it('서막 없이 연 판은 서막 카드가 없고 서막을 거치지 않은 판이다', () => {
    const with_ = newGame('skip-1', false);
    const without = newGame('skip-1', false, false, false);
    expect(with_.cards.some(c => c.kind.startsWith('pro_'))).toBe(true);
    expect(without.cards.some(c => c.kind.startsWith('pro_'))).toBe(false);
    expect(without.story?.flags.depot_promise).toBeUndefined();
  });

  it('서막을 지나 2구간에 들어선 판만 서막 클리어를 남긴다', () => {
    (globalThis as { localStorage?: unknown }).localStorage = fake;
    const g = newGame('skip-2', false);
    notePrologue(g);
    expect(prologueDone()).toBe(false); // 아직 서막 중
    g.seg = 2;
    notePrologue(g);
    expect(prologueDone()).toBe(false); // 서막 약속이 없는 판(서막 안 거침)은 남기지 않는다
    g.story!.flags.depot_promise = 'kept';
    notePrologue(g);
    expect(prologueDone()).toBe(true);
  });

  it('저장소가 막혀도 깨지지 않는다', () => {
    (globalThis as { localStorage?: unknown }).localStorage = { getItem: () => { throw new Error('막힘'); }, setItem: () => { throw new Error('막힘'); } };
    const g = newGame('skip-3', false);
    g.seg = 3;
    g.story!.flags.depot_promise = 'kept';
    expect(() => notePrologue(g)).not.toThrow();
    expect(prologueDone()).toBe(false);
  });
});
