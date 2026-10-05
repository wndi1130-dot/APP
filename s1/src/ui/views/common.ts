import type { CommunityId, RngState } from '../../core';
import type { AppState } from '../model/app-state';
import type { DummyProfile } from '../model/dummy';
import type { FlagKey } from '../model/flags';
import { GROUP_META } from '../model/groups';
import type { GroupId, Severity } from '../model/groups';
import type { SaveSummary } from '../model/save';
import { cx, h, pct } from '../dom';
import type { Child } from '../dom';

export type CarId = CommunityId | 'dining' | 'captain' | 'workshop';
export type Screen = 'home' | 'council' | 'captain' | 'debug' | `community:${CommunityId}`;
export type Panel = 'factions' | 'menu' | null;
export type EnterAnimation = 'screen' | 'card' | 'panel' | 'menu' | null;

export interface UiState {
  screen: Screen;
  panel: Panel;
  captainTab: 'journal' | 'people';
  /** 회기가 아닐 때 해 보는 모의 표결. 상태의 난수를 쓰지 않고 그 순간의 사본으로 푼다. */
  mockVote: { rng: RngState; billId: string } | null;
  confirmReset: boolean;
  toast: string | null;
  /** 이번 그리기에서만 들어오는 움직임을 줄 요소. */
  enter: EnterAnimation;
  slot: SaveSummary | null;
}

export interface View {
  app: AppState;
  ui: UiState;
  profiles: Readonly<Record<string, DummyProfile>>;
}

export function chip(id: GroupId | string, extra?: string): HTMLSpanElement {
  const color = Object.hasOwn(GROUP_META, id) ? GROUP_META[id as GroupId].color : 'var(--neutral)';
  return h('span', { class: cx('chip', extra), style: `--chip:${color}`, 'aria-hidden': 'true' });
}

export function meter(value: number, severity: Severity | 'plain', label?: string): HTMLSpanElement {
  return h('span', { class: cx('meter', `meter--${severity}`), role: label ? 'img' : null, 'aria-label': label ?? null },
    h('span', { class: 'meter__fill', style: `width:${pct(value)}` }));
}

const STUB_TEXT: Readonly<Record<FlagKey, string>> = Object.freeze({ S1a: 'S1a 자리', S1b: 'S1b 자리', S1c: 'S1c 자리' });

/** 기능 플래그로 켜고 끄는 자리표시. 꺼져 있으면 아무것도 그리지 않는다. */
export function stub(view: View, flag: FlagKey, text: string, extra?: string): HTMLElement | null {
  if (!view.app.flags[flag]) return null;
  return h('div', { class: cx('stub', extra), 'data-flag': flag },
    h('span', { class: 'stub__flag' }, STUB_TEXT[flag]), h('span', { class: 'stub__text' }, text));
}

export function button(
  label: string,
  action: string,
  options: { variant?: 'primary' | 'secondary' | 'quiet'; data?: Record<string, string>; disabled?: boolean; extra?: string; ariaLabel?: string; pressed?: boolean; test?: string } = {},
): HTMLButtonElement {
  const attrs: Record<string, string | boolean | null> = {
    type: 'button',
    class: cx('btn', `btn--${options.variant ?? 'secondary'}`, options.extra),
    'data-action': action,
    disabled: options.disabled ?? false,
    'aria-label': options.ariaLabel ?? null,
    'aria-pressed': options.pressed === undefined ? null : String(options.pressed),
    'data-test': options.test ?? null,
  };
  for (const [key, value] of Object.entries(options.data ?? {})) attrs[`data-${key}`] = value;
  return h('button', attrs, label);
}

/** 두세 개 중 하나를 고르는 묶음 단추. */
export function segmented(
  name: string,
  action: string,
  dataKey: string,
  options: readonly { value: string; label: string; test?: string }[],
  current: string,
  extra?: string,
): HTMLDivElement {
  return h('div', { class: cx('seg', extra), role: 'group', 'aria-label': name },
    options.map(option => h('button', {
      type: 'button',
      class: cx('seg__item', option.value === current && 'is-on'),
      'data-action': action,
      [`data-${dataKey}`]: option.value,
      'aria-pressed': String(option.value === current),
      'data-test': option.test ?? null,
    }, option.label)));
}

export function screenTitle(title: Child, meta?: string | null, ...extra: (HTMLElement | null)[]): HTMLElement {
  return h('div', { class: 'screen-head' },
    h('h1', { class: 'screen-head__title' }, title),
    meta ? h('span', { class: 'screen-head__meta' }, meta) : null,
    h('span', { class: 'screen-head__spacer' }),
    extra);
}

export const KOREAN_ORDINALS = ['첫', '두', '세', '네', '다섯', '여섯', '일곱', '여덟', '아홉', '열'];

/** 콘텐츠 가이드 2장: 때는 '○번째 겨울, ○구간째'로 쓴다. 첫 런은 여섯 번째 겨울. */
export function worldTime(segment: number, winter = 6): string {
  const ordinal = KOREAN_ORDINALS[winter - 1] ?? String(winter);
  return `${ordinal} 번째 겨울, ${segment}구간째`;
}
