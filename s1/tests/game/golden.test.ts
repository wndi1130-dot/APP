import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { RUNS, runKey, trace } from '../golden/trace';

// 규칙 숫자 불변 시험. 까닭 장부로 옮기는 PR(①~④)은 trace.json을 건드리지 않고 이 시험이 그대로 통과해야 한다.
// 규칙 값을 일부러 바꾼 PR만 trace.json을 다시 뜬다. 다시 뜰 때는 반드시 옮기기 전 코드(기준 커밋)에서 뜬다:
//   GOLDEN_WRITE=<기준 커밋> npx vitest run tests/game/golden.test.ts
// 자기 가지에서 다시 뜨면 이 시험은 아무것도 증명하지 못한다.

const FILE = fileURLToPath(new URL('../golden/trace.json', import.meta.url));

describe('규칙 숫자 불변(같은 시드, 같은 고르기)', () => {
  const write = process.env.GOLDEN_WRITE;
  if (write) {
    it('기준 커밋에서 적어 둔다', () => {
      const runs = Object.fromEntries(RUNS.map(r => [runKey(r), trace(r)]));
      writeFileSync(FILE, `${JSON.stringify({ base: write, runs })}\n`);
      expect(existsSync(FILE)).toBe(true);
    });
    return;
  }
  const gold = JSON.parse(readFileSync(FILE, 'utf8')) as { base: string; runs: Record<string, (number | string)[][]> };
  for (const r of RUNS) {
    it(`${runKey(r)}: 구간마다 숫자가 적어 둔 것과 같다`, () => {
      const want = gold.runs[runKey(r)];
      const got = trace(r);
      expect(want, '적어 둔 것이 없다').toBeDefined();
      for (let i = 0; i < Math.max(want.length, got.length); i += 1) expect(got[i], `${i}번째 줄(구간 ${got[i]?.[0] ?? '?'}, ${got[i]?.[1] ?? '?'})`).toEqual(want[i]);
    });
  }
});
