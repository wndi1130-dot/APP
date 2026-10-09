import { describe, expect, it } from 'vitest';
import { CONFIRM_MS, confirmed, replacesToast, toastMs } from '../../src/ui/notice';

// 알림 바꿈 규칙과 두 번 눌러 확정(ui_states.md N1·N2·P5).

describe('알림', () => {
  it('보통 알림은 2.6초, 경고는 6초', () => {
    expect(toastMs('info')).toBe(2600);
    expect(toastMs('warn')).toBe(6000);
  });

  it('떠 있는 경고는 보통 알림이 덮지 않는다', () => {
    expect(replacesToast('warn', 'info')).toBe(false);
  });

  it('나머지 조합은 새 알림이 바꾼다', () => {
    expect(replacesToast(null, 'info')).toBe(true);
    expect(replacesToast(null, 'warn')).toBe(true);
    expect(replacesToast('info', 'info')).toBe(true);
    expect(replacesToast('info', 'warn')).toBe(true);
    expect(replacesToast('warn', 'warn')).toBe(true);
  });
});

describe('두 번 눌러 확정', () => {
  const first = { action: 'restart', t: 1000 };

  it('첫 탭이 없으면 확정이 아니다', () => {
    expect(confirmed(null, 'restart', 1500)).toBe(false);
    expect(confirmed(undefined, 'restart', 1500)).toBe(false);
  });

  it('3초 안에 같은 동작을 다시 누르면 확정', () => {
    expect(confirmed(first, 'restart', 1200)).toBe(true);
    expect(confirmed(first, 'restart', 1000 + CONFIRM_MS)).toBe(true);
  });

  it('3초가 지나면 다시 첫 탭이다', () => {
    expect(confirmed(first, 'restart', 1000 + CONFIRM_MS + 1)).toBe(false);
  });

  it('다른 동작을 누르면 확정이 아니다', () => {
    expect(confirmed(first, 'new-seed', 1200)).toBe(false);
  });
});
