import { describe, expect, it, vi } from 'vitest';
import { createGame, drain, resolveStop } from '../../src/game';
import type { LootKey } from '../../src/game/data';

// 결정 257: 정차에서 얻는 석탄은 (예전 셈 × 0.85)를 한 번 반올림한 정수이고, 식량·의약품은 그대로다.
// 같은 씨앗을 배수 1000(예전 셈을 소수 셋째 자리까지 드러낸다)과 지금 값으로 두 번 돌려 견준다.
const haul = vi.hoisted(() => ({ coal: undefined as number | undefined }));
vi.mock('../../src/game/data', async importOriginal => {
  const m = await importOriginal<typeof import('../../src/game/data')>();
  return { ...m, P: { ...m.P, get coalHaul() { return haul.coal ?? m.P.coalHaul; } } };
});

function runStop(seed: string, target: LootKey, coalHaul?: number) {
  haul.coal = coalHaul;
  const g = createGame(seed);
  g.phase = 'stop';
  g.stop = { place: 'factory', target, stay: 'normal', crewComm: 'tail', crewSize: 4, scout: true, threat: 1, done: false, result: null };
  drain(g);
  const r = resolveStop(g, true)!;
  const ledgerCoal = drain(g).filter(x => x.k === 'coal' && x.why === 'stop.loot').reduce((s, x) => s + x.d, 0);
  return { gains: r.gains, ledgerCoal };
}

describe('정차에서 얻는 석탄 15% 덜(결정 257)', () => {
  it('석탄만 (예전 셈 × 0.85)를 한 번 반올림한 정수로 줄고, 식량·의약품은 그대로이며, 영수증과 장부의 석탄이 같다', () => {
    let shrunk = 0;
    for (const target of ['coal', 'food', 'medicine'] as const) for (let k = 0; k < 30; k += 1) {
      const seed = `coal-haul-${target}-${k}`;
      const old = runStop(seed, target, 1000);
      const now = runStop(seed, target);
      const before = (old.gains.coal ?? 0) / 1000;
      expect(now.gains.coal ?? 0, seed).toBe(Math.round(before * 0.85));
      expect(now.gains.food, seed).toBe(old.gains.food);
      expect(now.gains.medicine, seed).toBe(old.gains.medicine);
      expect(now.ledgerCoal, seed).toBe(now.gains.coal ?? 0);
      if ((now.gains.coal ?? 0) < Math.round(before)) shrunk += 1;
    }
    haul.coal = undefined;
    expect(shrunk).toBeGreaterThan(0);
  });
});
