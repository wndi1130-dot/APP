// 기능 플래그. 지금은 자리표시 구역을 보이고 숨기는 데만 쓴다(기획서 19장).

export const FLAG_KEYS = ['S1a', 'S1b', 'S1c'] as const;
export type FlagKey = typeof FLAG_KEYS[number];
export type FeatureFlags = Readonly<Record<FlagKey, boolean>>;

export const DEFAULT_FLAGS: FeatureFlags = Object.freeze({ S1a: true, S1b: false, S1c: false });

export const FLAG_LABELS: Readonly<Record<FlagKey, string>> = Object.freeze({
  S1a: '거래',
  S1b: '어두운 길',
  S1c: '내정',
});

export function isFlagKey(value: unknown): value is FlagKey {
  return typeof value === 'string' && (FLAG_KEYS as readonly string[]).includes(value);
}

export function setFlag(flags: FeatureFlags, key: FlagKey, value: boolean): FeatureFlags {
  if (!isFlagKey(key)) throw new TypeError(`모르는 기능 플래그입니다: ${String(key)}`);
  return Object.freeze({ ...flags, [key]: value });
}

export function toggleFlag(flags: FeatureFlags, key: FlagKey): FeatureFlags {
  if (!isFlagKey(key)) throw new TypeError(`모르는 기능 플래그입니다: ${String(key)}`);
  return setFlag(flags, key, !flags[key]);
}

/** 저장본에서 읽은 값을 정리한다. 빠졌거나 참·거짓이 아닌 값은 기본값, 모르는 키는 버린다. */
export function sanitizeFlags(value: unknown): FeatureFlags {
  const source = typeof value === 'object' && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
  const result = {} as Record<FlagKey, boolean>;
  for (const key of FLAG_KEYS) {
    result[key] = typeof source[key] === 'boolean' ? source[key] as boolean : DEFAULT_FLAGS[key];
  }
  return Object.freeze(result);
}

export function enabledFlags(flags: FeatureFlags): FlagKey[] {
  return FLAG_KEYS.filter(key => flags[key]);
}
