// 알림(쪽지)과 두 번 눌러 확정의 순수 판정. DOM을 몰라서 따로 시험한다(ui_states.md N1·N2·P5).

export type ToastKind = 'info' | 'warn';

/** 알림이 떠 있는 시간: 보통 2.6초, 경고 6초 */
export const TOAST_MS: Record<ToastKind, number> = { info: 2600, warn: 6000 };

/** 두 번 눌러 확정의 유효 시간 */
export const CONFIRM_MS = 3000;

export function toastMs(kind: ToastKind): number {
  return TOAST_MS[kind];
}

/** 새 알림이 지금 알림을 바꾸나. 떠 있는 경고는 보통 알림이 덮지 않는다. */
export function replacesToast(current: ToastKind | null, next: ToastKind): boolean {
  return !(current === 'warn' && next === 'info');
}

/** 같은 동작을 시간 안에 다시 눌렀나(첫 탭 기록 prev, 지금 now) */
export function confirmed(prev: { action: string; t: number } | null | undefined, action: string, now: number): boolean {
  return !!prev && prev.action === action && now - prev.t >= 0 && now - prev.t <= CONFIRM_MS;
}
