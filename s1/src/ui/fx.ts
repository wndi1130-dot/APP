import { COMMS, P, standings } from '../game';
import type { Comm, Game } from '../game';

// 선택하면 위 막대에서 바뀐 수치가 눈에 따라온다(2026-10-07 사용자: "위에 변하는 거 이펙트를 강하게").
// 규칙은 presentation_motion 5b.6(62c9af0·f27aabe)을 따른다. 계산은 안 바꾸고 보이기만 한다.
// - 변화량은 보이는 값의 차이: 반올림한 새 값 − 반올림한 옛 값. 0이면 꼬리표도 없다.
// - 색은 좋고 나쁨이 아니라 재질: 늘어남은 호박색 빛, 줄어듦은 그을음. 파랑은 지지 의석, 빨강은 불만 의석이 늘 때와
//   자원이 부족 선 아래로 갈 때만 쓴다.
// - 선을 넘을 때만 세게: 선 넘은 칸 하나만 흔들리고 '주의'·'위험'이 찍힌다. 위 막대 전체는 안 흔든다.
// - 크게 바뀔 때(신임·긴장 5 이상, 자원 지금 값의 20% 이상)는 꼬리표와 부풂만 키운다.
// - 진동은 나쁜 쪽 선 넘음과 죽음에만, 한 번 40ms. 메뉴의 '진동'으로 끈다(동작 감소 설정과 따로).

export type FxKey = 'trust' | 'tension' | 'coal' | 'food' | 'med' | 'lux';
export type FxWord = '주의' | '위험';

/** 칸 하나의 변화(모두 보이는 정수) */
export interface FxCell {
  v: number;
  from: number;
  to: number;
  /** 크게 바뀜: 꼬리표·부풂을 키운다 */
  big: boolean;
  /** 부족 선 아래로 내려감(자원만): 이때만 빨강 */
  red: boolean;
  /** 나쁜 쪽으로 선을 넘었으면 그 단계 글자 */
  word: FxWord | null;
  /** 좋은 쪽으로 선을 넘어 돌아옴: 글자가 벗겨지듯 사라진다 */
  peel: FxWord | null;
}

export interface Fx {
  id: number;
  d: Partial<Record<FxKey, FxCell>>;
  rel: Partial<Record<Comm, number>>;
  /** 불만·지지 의석 변화 */
  seats: { unrest: number; support: number };
  /** 선 넘음 박자를 쓰는 칸 하나(가장 무거운 것). 이 칸만 흔들리고 글자가 찍힌다 */
  heavy: FxKey | null;
  /** 진동할 일(나쁜 쪽 선 넘음, 죽음) */
  buzz: boolean;
  /** 날아가는 꼬리표 순서(최대 셋): 선 넘는 칸 → 나머지 */
  fly: FxKey[];
}

export interface FxSnap { v: Record<FxKey, number>; rel: Record<Comm, number>; deaths: number; unrest: number; support: number }

export const FX_MS = 2200;
/** 꼬리표가 결과 줄에서 칸까지 나는 시간(긴 판) */
export const FX_FLY_MS = 350;
const KEYS: FxKey[] = ['trust', 'tension', 'coal', 'food', 'med', 'lux'];

export function fxSnap(g: Game): FxSnap {
  const st = standings(g);
  return {
    v: { trust: g.trust, tension: g.tension, coal: g.coal, food: g.food, med: g.med, lux: g.lux },
    rel: Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel])) as Record<Comm, number>,
    deaths: g.deaths.length,
    unrest: st.unrest,
    support: st.support,
  };
}

/** 보이는 값의 단계: 0 괜찮음, 1 주의, 2 위험. 신임 45·30 아래, 긴장 50·70 위, 석탄·식량 부족 선 아래·0, 의약품 0. */
export function fxLevel(key: FxKey, shown: number): 0 | 1 | 2 {
  switch (key) {
    case 'trust': return shown < 30 ? 2 : shown < 45 ? 1 : 0;
    case 'tension': return shown > 70 ? 2 : shown > 50 ? 1 : 0;
    case 'coal':
    case 'food': return shown <= 0 ? 2 : shown < P.crisisLine ? 1 : 0;
    case 'med': return shown <= 0 ? 2 : 0;
    default: return 0;
  }
}

const WORD: Record<1 | 2, FxWord> = { 1: '주의', 2: '위험' };

let nextId = 1;
/** 고르기 전과 뒤를 견줘 보일 변화. 보이는 값이 그대로면 안 보인다. 아무것도 안 바뀌었으면 null */
export function fxDiff(before: FxSnap, g: Game): Fx | null {
  const after = fxSnap(g);
  const d: Fx['d'] = {};
  let heavy: FxKey | null = null;
  let heavyLevel = 0;
  for (const k of KEYS) {
    const from = Math.round(before.v[k]);
    const to = Math.round(after.v[k]);
    const v = to - from;
    if (v === 0) continue;
    const l0 = fxLevel(k, from);
    const l1 = fxLevel(k, to);
    const resource = k !== 'trust' && k !== 'tension';
    const big = resource ? Math.abs(v) >= 0.2 * Math.max(1, Math.abs(from)) : Math.abs(v) >= 5;
    const cell: FxCell = { v, from, to, big, red: resource && l1 > l0, word: null, peel: l1 < l0 ? WORD[l0 as 1 | 2] : null };
    if (l1 > l0 && l1 > heavyLevel) { heavy = k; heavyLevel = l1; }
    d[k] = cell;
  }
  if (heavy) d[heavy]!.word = WORD[heavyLevel as 1 | 2];
  const rel: Fx['rel'] = {};
  for (const c of COMMS) {
    const v = Math.round(after.rel[c]) - Math.round(before.rel[c]);
    if (v !== 0) rel[c] = v;
  }
  const seats = { unrest: after.unrest - before.unrest, support: after.support - before.support };
  const died = after.deaths > before.deaths;
  if (Object.keys(d).length === 0 && Object.keys(rel).length === 0 && !seats.unrest && !seats.support && !died) return null;
  const changed = KEYS.filter(k => d[k]);
  const fly = [...changed.filter(k => d[k]!.word || d[k]!.red), ...changed.filter(k => !d[k]!.word && !d[k]!.red)].slice(0, 3);
  return { id: nextId++, d, rel, seats, heavy, buzz: !!heavy || died, fly };
}

/** 꼬리표 글: 부호와 정수 */
export function fxText(v: number): string {
  return v > 0 ? `+${v}` : `−${Math.abs(v)}`;
}

/** 칸의 재질 클래스: 늘어남은 호박색 빛, 줄어듦은 그을음, 부족 선 아래로 가면 빨강 */
export function fxTone(cell: FxCell): string {
  return cell.red ? 'fx-red' : cell.v > 0 ? 'fx-up' : 'fx-down';
}

// ---- 진동(5b.6 '진동'): 설정 하나로 끈다. 브라우저에만 남는 개인 설정이다 ----
const VIBRATE_KEY = 's1a.vibrate';
let vibrate: boolean | null = null;
let lastBuzz = -Infinity;

export function vibrateOn(): boolean {
  if (vibrate === null) {
    try {
      vibrate = globalThis.localStorage?.getItem(VIBRATE_KEY) !== '0';
    } catch {
      vibrate = true;
    }
  }
  return vibrate;
}

export function setVibrate(on: boolean): void {
  vibrate = on;
  try {
    globalThis.localStorage?.setItem(VIBRATE_KEY, on ? '1' : '0');
  } catch {
    // 저장 못 해도 이번 창에선 따른다.
  }
}

/** 40ms 한 번. 앞 진동 뒤 1초 안에 오는 진동은 버린다. 떨었으면 true */
export function buzz(now: number): boolean {
  if (!vibrateOn() || now - lastBuzz < 1000) return false;
  lastBuzz = now;
  globalThis.navigator?.vibrate?.(40);
  return true;
}
