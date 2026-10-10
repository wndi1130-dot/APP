import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { COMMS, LAWS, P } from '../src/game';
import { algoVectors, calcVectors, dataTables, recordGame } from '../tools/s3_record';

// S3 맞대기 기록(tools/s3_record.ts). GDScript 이식이 이 기록을 기준으로 삼으므로, 기록이 시드만으로 정해지는지와
// 기록에 담긴 값이 스스로 맞는지를 본다.

describe('S3 판 기록', () => {
  it('같은 시드와 같은 플레이 규칙이면 같은 기록이다', () => {
    expect(JSON.stringify(recordGame('same', true))).toBe(JSON.stringify(recordGame('same', true)));
    expect(JSON.stringify(recordGame('same', false))).not.toBe(JSON.stringify(recordGame('same', true)));
  });

  it('판이 끝까지 가고, 걸음마다 번호와 난수 상태가 있다', () => {
    for (const [seed, deal] of [['seed-0', true], ['seed-1', false], ['seed-2', true]] as const) {
      const r = recordGame(seed, deal);
      expect(r.end.kind).not.toBeNull();
      expect(r.steps[0].act).toBe('new');
      expect(r.steps.at(-1)?.phase).toBe('end');
      r.steps.forEach((s, i) => {
        expect(s.i).toBe(i);
        expect(Number.isInteger(s.rng) && s.rng >= 0 && s.rng <= 0xffff_ffff).toBe(true);
        expect(s.pop).toHaveLength(COMMS.length);
        expect([s.coal, s.food, s.med, s.trust, s.tension].every(Number.isFinite)).toBe(true);
      });
      expect(r.votes.length).toBeGreaterThan(0);
    }
  });

  it('개표 기록은 쐐기에서 다시 셀 수 있다', () => {
    for (const v of recordGame('seed-0', true).votes) {
      const drawn = v.blocs.reduce((sum, b) => sum + b.und + b.pool, 0);
      expect(v.flips).toHaveLength(drawn);
      const yes = v.blocs.reduce((sum, b) => sum + b.yes, 0) + v.flips.filter(f => f[1]).length;
      expect(v.yes).toBe(yes);
      expect(v.passed).toBe(v.yes >= v.need);
      expect(v.yes + v.no + v.absent).toBe(100);
      expect(v.byComm.reduce((sum, c) => sum + c[0], 0)).toBe(v.yes);
      // 뽑은 표가 있으면 난수가 나아갔다.
      expect(v.rngAfter !== v.rngBefore).toBe(drawn > 0);
    }
  });

  it('JSON으로 내도 값이 그대로다', () => {
    const r = recordGame('json', false);
    expect(JSON.parse(JSON.stringify(r))).toEqual(r);
  });
});

describe('S3 계산 표본', () => {
  const v = calcVectors() as {
    rng: { seed: string | number; start: number; draws: { state: number; u32: number; value: number }[]; ints: { min: number; max: number; value: number }[] }[];
    seats: { pop: number[]; seats: number[] }[];
    split: { score: number; split: number[] }[];
    votes: unknown[];
  };

  it('두 번 만들어도 같다', () => {
    expect(JSON.stringify(calcVectors())).toBe(JSON.stringify(v));
  });

  it('난수 표본: 뽑은 값은 uint32 정수이고 정수 뽑기는 구간 안이다', () => {
    // 빈 글자 시드는 FNV-1a의 시작값 그대로다.
    expect(v.rng.find(r => r.seed === '')?.start).toBe(0x811c9dc5);
    for (const r of v.rng) {
      for (const d of r.draws) {
        expect(Number.isInteger(d.u32) && d.u32 >= 0 && d.u32 <= 0xffff_ffff).toBe(true);
        expect(d.value).toBe(d.u32 / 0x1_0000_0000);
      }
      for (const n of r.ints) expect(n.value >= n.min && n.value <= n.max).toBe(true);
    }
    // 숫자 시드는 uint32로 접힌다.
    expect(v.rng.find(r => r.seed === 4294967296)?.start).toBe(0);
    expect(v.rng.find(r => r.seed === -1)?.start).toBe(0xffff_ffff);
  });

  it('의석 표본: 늘 100석이고 사람이 없는 칸도 0명 판에선 20석씩이다', () => {
    for (const s of v.seats) expect(s.seats.reduce((a, b) => a + b, 0)).toBe(100);
    expect(v.seats.find(s => s.pop.every(p => p === 0))?.seats).toEqual([20, 20, 20, 20, 20]);
  });

  it('찬반 몫은 합이 1이고, 실제 판의 개표가 들어 있다', () => {
    for (const s of v.split) expect(s.split.reduce((a, b) => a + b, 0)).toBeCloseTo(1, 12);
    expect(v.votes.length).toBeGreaterThan(0);
  });
});

describe('S3 알고리즘 표본(S2와 같이 보는 파일)', () => {
  // GDScript 이식(s2/game/politics)의 GUT 시험이 읽는 파일이다. 난수나 의석 셈법이 바뀌면 여기서 먼저 걸린다.
  // 다시 뽑기: npx tsx tools/s3_dump.ts vectors ../s2/tests/game/fixtures/s3/calc_algo.json --only=algo
  it('넣어 둔 calc_algo.json이 지금 규칙으로 다시 만든 것과 같다', () => {
    const path = fileURLToPath(new URL('../../s2/tests/game/fixtures/s3/calc_algo.json', import.meta.url));
    expect(JSON.parse(readFileSync(path, 'utf8'))).toEqual(JSON.parse(JSON.stringify(algoVectors())));
  });
});

describe('S3 수치 표', () => {
  it('data.ts의 값이 그대로 담기고 JSON으로 되살아난다', () => {
    const t = dataTables();
    expect(t.tables.P).toEqual(P);
    expect(t.tables.LAWS).toEqual(LAWS);
    expect(t.tables.COMMS).toEqual(COMMS);
    expect(JSON.parse(JSON.stringify(t.tables))).toEqual(t.tables);
    expect(t.skipped).toEqual([]);
  });
});
