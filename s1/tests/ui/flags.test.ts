import { describe, expect, it } from 'vitest';
import {
  DEFAULT_FLAGS, FLAG_KEYS, enabledFlags, isFlagKey, sanitizeFlags, setFlag, toggleFlag,
} from '../../src/ui/model/flags';

describe('기능 플래그', () => {
  it('기본값은 S1a만 켜져 있다', () => {
    expect(DEFAULT_FLAGS).toEqual({ S1a: true, S1b: false, S1c: false });
    expect(enabledFlags(DEFAULT_FLAGS)).toEqual(['S1a']);
    expect(FLAG_KEYS).toEqual(['S1a', 'S1b', 'S1c']);
  });

  it('켜고 끄면 새 객체를 돌려주고 원본은 그대로다', () => {
    const on = toggleFlag(DEFAULT_FLAGS, 'S1b');
    expect(on).toEqual({ S1a: true, S1b: true, S1c: false });
    expect(DEFAULT_FLAGS.S1b).toBe(false);
    const off = toggleFlag(on, 'S1a');
    expect(off).toEqual({ S1a: false, S1b: true, S1c: false });
    expect(toggleFlag(toggleFlag(off, 'S1c'), 'S1c')).toEqual(off);
    expect(setFlag(off, 'S1a', true)).toEqual(on);
    expect(Object.isFrozen(on)).toBe(true);
  });

  it('모르는 플래그는 거절한다', () => {
    expect(isFlagKey('S1d')).toBe(false);
    expect(() => toggleFlag(DEFAULT_FLAGS, 'S1d' as never)).toThrow();
  });

  it('저장본의 값은 정리한다: 빠진 키는 기본값, 이상한 값과 모르는 키는 버린다', () => {
    expect(sanitizeFlags({ S1b: true })).toEqual({ S1a: true, S1b: true, S1c: false });
    expect(sanitizeFlags({ S1a: 'yes', S1c: 1, S9: true })).toEqual(DEFAULT_FLAGS);
    expect(sanitizeFlags(null)).toEqual(DEFAULT_FLAGS);
    expect(sanitizeFlags([true, true])).toEqual(DEFAULT_FLAGS);
    expect(sanitizeFlags({ S1a: false, S1b: false, S1c: true })).toEqual({ S1a: false, S1b: false, S1c: true });
  });
});
