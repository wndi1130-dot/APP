import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { RUNS, runKey, runTrace, STEP_CAP } from '../golden/trace';
import type { Run, TraceRun } from '../golden/trace';

// 규칙 숫자 불변 시험. 까닭 장부로 옮기는 PR(①~④)은 trace.json을 건드리지 않고 이 시험이 그대로 통과해야 한다.
// 규칙 값을 일부러 바꾼 PR만 trace.json을 다시 뜬다. 다시 뜰 때는 반드시 옮기기 전 코드(기준 커밋)에서 뜬다:
//   GOLDEN_WRITE=<기준 커밋> npx vitest run tests/game/golden.test.ts
// 자기 가지에서 다시 뜨면 이 시험은 아무것도 증명하지 못한다.
// 예외: 규칙(src/)은 그대로 두고 길잡이(trace.ts)의 고르기만 고친 PR은 그 가지에서 다시 뜬다(src/ 차이가 0인지 먼저 본다).
// 적을 때도 비교할 때도 판이 끝까지 갔는지 먼저 본다. 상한을 다 쓰고 멈춘 판을 기준값으로 받으면 안 된다.

/** 판이 진짜로 끝났는지. 끝 갈래(완주·축출·반란 등)는 가리지 않는다. */
function expectFinished(r: Run, t: TraceRun): void {
  const at = `${runKey(r)}: 구간 ${t.seg}, 마지막 줄 ${JSON.stringify(t.rows[t.rows.length - 1]?.slice(0, 2))}`;
  expect(t.ended, `${at} — ${STEP_CAP}걸음 안에 끝나지 않았다`).toBe(true);
  expect(t.seg, `${at} — 1구간을 넘지 못했다`).toBeGreaterThan(1);
  if (r.kind === 'cx') expect(t.sawActive, `${at} — 재난을 켠 판인데 발동(active)을 한 번도 보지 못했다`).toBe(true);
}

const FILE = fileURLToPath(new URL('../golden/trace.json', import.meta.url));

describe('규칙 숫자 불변(같은 시드, 같은 고르기)', () => {
  const write = process.env.GOLDEN_WRITE;
  if (write) {
    it('기준 커밋에서 적어 둔다', () => {
      const runs = Object.fromEntries(RUNS.map(r => {
        const t = runTrace(r);
        expectFinished(r, t);
        return [runKey(r), t.rows];
      }));
      writeFileSync(FILE, `${JSON.stringify({ base: write, runs })}\n`);
      expect(existsSync(FILE)).toBe(true);
    });
    return;
  }
  const gold = JSON.parse(readFileSync(FILE, 'utf8')) as { base: string; runs: Record<string, (number | string)[][]> };
  for (const r of RUNS) {
    it(`${runKey(r)}: 구간마다 숫자가 적어 둔 것과 같다`, () => {
      const want = gold.runs[runKey(r)];
      const t = runTrace(r);
      expectFinished(r, t);
      const got = t.rows;
      expect(want, '적어 둔 것이 없다').toBeDefined();
      for (let i = 0; i < Math.max(want.length, got.length); i += 1) expect(got[i], `${i}번째 줄(구간 ${got[i]?.[0] ?? '?'}, ${got[i]?.[1] ?? '?'})`).toEqual(want[i]);
    });
  }
});
