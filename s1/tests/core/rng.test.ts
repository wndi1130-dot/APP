import { describe, expect, it } from 'vitest';
import {
  createRng,
  MAX_RANDOM_INT_SPAN,
  nextRandom,
  randomInt,
  restoreRng,
} from '../../src/core/rng';
import type { RngSeed, RngState } from '../../src/core/rng';

function sequence(initial: RngState, count: number) {
  const values: number[] = [];
  let rng = initial;
  for (let index = 0; index < count; index += 1) {
    const next = nextRandom(rng);
    values.push(next.value);
    rng = next.rng;
  }
  return { values, rng };
}

describe('시드 난수', () => {
  it('숫자 시드 1의 고정된 Mulberry32 수열과 상태가 유지된다', () => {
    const result = sequence(createRng(1), 6);
    expect(result.values.map(value => value * 0x1_0000_0000)).toEqual([
      2693262067, 11749833, 2265367787, 4213581821, 4159151403, 1207330352,
    ]);
    expect(result.rng).toEqual({ algorithm: 'mulberry32-v1', state: 2399460287 });
  });

  it('UTF-8 문자열 해시와 한글·이모지 시드 수열이 유지된다', () => {
    const rng = createRng('볼슈틴🚂');
    expect(rng.state).toBe(426297926);
    expect(sequence(rng, 6).values.map(value => value * 0x1_0000_0000)).toEqual([
      3073500225, 1042097436, 366163458, 1979756067, 2800728627, 1517727964,
    ]);
    expect(createRng('train').state).toBe(2018864233);
    expect(createRng('').state).toBe(2166136261);
  });

  it.each([0, 1, -1, Number.MAX_SAFE_INTEGER, '', 'train', '볼슈틴🚂'])(
    '같은 시드 %s에서 같은 수열을 재현한다', seed => {
      expect(sequence(createRng(seed), 100)).toEqual(sequence(createRng(seed), 100));
    },
  );

  it('서로 다른 예시 시드는 서로 다른 수열을 만든다', () => {
    expect(sequence(createRng(1), 20).values).not.toEqual(sequence(createRng(2), 20).values);
    expect(sequence(createRng('winter'), 20).values).not.toEqual(sequence(createRng('summer'), 20).values);
    expect(createRng('1')).not.toEqual(createRng(1));
  });

  it('음수와 큰 안전 정수 시드는 uint32로 정규화한다', () => {
    expect(createRng(-1)).toEqual(createRng(0xffff_ffff));
    expect(createRng(0x1_0000_0001)).toEqual(createRng(1));
    expect(createRng(Number.MAX_SAFE_INTEGER).state).toBe(0xffff_ffff);
  });

  it('생성 값은 0 이상 1 미만이다', () => {
    const result = sequence(createRng('range'), 10_000);
    expect(result.values.every(value => value >= 0 && value < 1)).toBe(true);
  });

  it('저장·JSON 왕복·복원 후 수열을 끊김 없이 이어 간다', () => {
    const initial = createRng('saved-run');
    const beforeSave = sequence(initial, 37);
    const parsed: unknown = JSON.parse(JSON.stringify(beforeSave.rng));
    const restored = restoreRng(parsed);
    const afterSave = sequence(restored, 63);
    expect(restored).not.toBe(parsed);
    expect([...beforeSave.values, ...afterSave.values]).toEqual(sequence(initial, 100).values);
    expect(afterSave.rng).toEqual(sequence(initial, 100).rng);
  });

  it('입력 상태와 복원 원본을 수정하지 않는다', () => {
    const rng = Object.freeze(createRng(12));
    const next = nextRandom(rng);
    const restored = restoreRng(rng);
    expect(rng).toEqual({ algorithm: 'mulberry32-v1', state: 12 });
    expect(next.rng).not.toBe(rng);
    expect(restored).not.toBe(rng);
    expect(nextRandom(rng)).toEqual(next);
  });

  it.each([NaN, Infinity, -Infinity, 1.5, Number.MAX_SAFE_INTEGER + 1, null, undefined, {}])(
    '잘못된 시드 %s를 거부한다', seed => {
      expect(() => createRng(seed as RngSeed)).toThrow();
    },
  );

  it.each([
    null,
    [],
    1,
    {},
    { algorithm: 'mulberry32-v2', state: 1 },
    { algorithm: 'mulberry32-v1', state: -1 },
    { algorithm: 'mulberry32-v1', state: 0x1_0000_0000 },
    { algorithm: 'mulberry32-v1', state: 0.5 },
    { algorithm: 'mulberry32-v1', state: NaN },
    { algorithm: 'mulberry32-v1', state: Infinity },
    { algorithm: 'mulberry32-v1', state: '1' },
  ])('알고리즘 버전이나 uint32 상태가 잘못되면 복원과 추출을 거부한다: %j', value => {
    expect(() => restoreRng(value)).toThrow();
    expect(() => nextRandom(value as RngState)).toThrow();
    expect(() => randomInt(value as RngState, 0, 10)).toThrow();
  });
});

describe('정수 난수', () => {
  it('양끝을 포함한 정수만 반환하고 같은 시드로 재현한다', () => {
    let first = createRng('integer');
    let second = createRng('integer');
    const seen = new Set<number>();
    for (let index = 0; index < 1_000; index += 1) {
      const a = randomInt(first, -2, 2);
      const b = randomInt(second, -2, 2);
      expect(a).toEqual(b);
      expect(Number.isInteger(a.value) && a.value >= -2 && a.value <= 2).toBe(true);
      seen.add(a.value);
      first = a.rng;
      second = b.rng;
    }
    expect([...seen].sort((a, b) => a - b)).toEqual([-2, -1, 0, 1, 2]);
  });

  it('나머지 편향을 만드는 끝부분은 버리고 다음 상태에서 다시 뽑는다', () => {
    const rng = Object.freeze(createRng(1));
    const result = randomInt(rng, 0, 0x8000_0000);
    expect(result.value).toBe(11749833);
    expect(result.rng).toEqual(sequence(rng, 2).rng);
    expect(rng.state).toBe(1);
  });

  it('최대 구간폭 2^32와 안전 정수 경계 근처 구간을 지원한다', () => {
    const rng = createRng(1);
    expect(MAX_RANDOM_INT_SPAN).toBe(0x1_0000_0000);
    expect(randomInt(rng, 0, MAX_RANDOM_INT_SPAN - 1).value).toBe(2693262067);
    expect(randomInt(rng, -0x8000_0000, 0x7fff_ffff).value).toBe(2693262067 - 0x8000_0000);
    expect(randomInt(rng, Number.MAX_SAFE_INTEGER - 1, Number.MAX_SAFE_INTEGER).value)
      .toBe(Number.MAX_SAFE_INTEGER);
    expect(randomInt(rng, Number.MIN_SAFE_INTEGER, Number.MIN_SAFE_INTEGER + 1).value)
      .toBe(Number.MIN_SAFE_INTEGER + 1);
  });

  it('값 하나뿐인 구간에서도 상태를 한 번 전진한다', () => {
    const rng = Object.freeze(createRng('single'));
    const result = randomInt(rng, -4, -4);
    expect(result).toEqual({ value: -4, rng: nextRandom(rng).rng });
    expect(result.rng).not.toBe(rng);
  });

  it.each([
    [2, 1],
    [0.1, 2],
    [0, 2.1],
    [NaN, 1],
    [0, Infinity],
    [-Infinity, 0],
    [Number.MIN_SAFE_INTEGER - 1, 0],
    [0, Number.MAX_SAFE_INTEGER + 1],
    [0, 0x1_0000_0000],
    [Number.MIN_SAFE_INTEGER, Number.MAX_SAFE_INTEGER],
  ])('잘못된 정수 구간 [%s, %s]을 거부한다', (min, max) => {
    expect(() => randomInt(createRng(1), min, max)).toThrow(RangeError);
  });
});
