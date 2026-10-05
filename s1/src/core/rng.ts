export type RngSeed = string | number;

export interface RngState {
  readonly algorithm: 'mulberry32-v1';
  readonly state: number;
}

const UINT32_SIZE = 0x1_0000_0000;
const UINT32_MAX = UINT32_SIZE - 1;
const STATE_INCREMENT = 0x6d2b79f5;
const FNV_OFFSET = 0x811c9dc5;
const FNV_PRIME = 0x01000193;

/** 양끝을 포함한 정수 구간은 최대 2^32개의 값을 가질 수 있다. */
export const MAX_RANDOM_INT_SPAN = UINT32_SIZE;

/** 문자열은 UTF-8 FNV-1a, 숫자는 안전 정수를 uint32로 정규화한다. */
export function createRng(seed: RngSeed): RngState {
  let state: number;
  if (typeof seed === 'string') {
    state = FNV_OFFSET;
    for (const byte of new TextEncoder().encode(seed)) {
      state = Math.imul(state ^ byte, FNV_PRIME) >>> 0;
    }
  } else if (typeof seed === 'number' && Number.isSafeInteger(seed)) {
    state = seed >>> 0;
  } else {
    throw new TypeError('난수 시드는 문자열이나 안전 정수여야 합니다.');
  }
  return { algorithm: 'mulberry32-v1', state };
}

/** JSON에서 복원한 상태를 검사하고 외부 객체와 분리된 사본을 만든다. */
export function restoreRng(value: unknown): RngState {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new TypeError('저장한 난수 상태는 객체여야 합니다.');
  }
  const candidate = value as Record<string, unknown>;
  if (candidate.algorithm !== 'mulberry32-v1') {
    throw new TypeError('지원하지 않는 난수 알고리즘 버전입니다.');
  }
  if (typeof candidate.state !== 'number' || !Number.isInteger(candidate.state)
    || candidate.state < 0 || candidate.state > UINT32_MAX) {
    throw new RangeError('난수 상태는 0부터 4294967295까지의 정수여야 합니다.');
  }
  return { algorithm: 'mulberry32-v1', state: candidate.state };
}

function nextUint32(rng: RngState): { value: number; rng: RngState } {
  const saved = restoreRng(rng);
  const state = (saved.state + STATE_INCREMENT) >>> 0;
  let mixed = Math.imul(state ^ (state >>> 15), state | 1);
  mixed ^= mixed + Math.imul(mixed ^ (mixed >>> 7), mixed | 61);
  return {
    value: (mixed ^ (mixed >>> 14)) >>> 0,
    rng: { algorithm: 'mulberry32-v1', state },
  };
}

/** 입력 상태를 바꾸지 않고 [0, 1) 구간의 값과 다음 상태를 반환한다. */
export function nextRandom(rng: RngState): { value: number; rng: RngState } {
  const next = nextUint32(rng);
  return { value: next.value / UINT32_SIZE, rng: next.rng };
}

/**
 * 양끝을 포함한 안전 정수 구간에서 뽑는다. 나머지 연산의 편향을 피하도록
 * 구간 너비로 나누어떨어지지 않는 끝부분을 버리고 다시 뽑는다.
 * 구간에 값이 하나뿐이어도 난수 상태는 한 번 전진한다.
 */
export function randomInt(
  rng: RngState,
  min: number,
  max: number,
): { value: number; rng: RngState } {
  if (!Number.isSafeInteger(min) || !Number.isSafeInteger(max) || min > max) {
    throw new RangeError('정수 난수의 양끝은 오름차순의 안전 정수여야 합니다.');
  }
  const span = max - min + 1;
  if (!Number.isSafeInteger(span) || span > MAX_RANDOM_INT_SPAN) {
    throw new RangeError('정수 난수 구간의 값 개수는 4294967296 이하여야 합니다.');
  }
  const limit = Math.floor(UINT32_SIZE / span) * span;
  let next = nextUint32(rng);
  while (next.value >= limit) {
    next = nextUint32(next.rng);
  }
  return { value: min + (next.value % span), rng: next.rng };
}
