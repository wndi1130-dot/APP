import { s } from './dom';

// 설계도 단계의 자리표시 아이콘. 뜻이 읽히는 최소한의 도형만 그린다(아이콘 판 ④a의 뜻을 따른다:
// 석탄 수레, 빵, 알약과 병, 반지, 맞잡은 손, 끊어지려는 밧줄, 주먹, 편 손, 일지 책, 서류 뭉치).

export type IconName =
  | 'coal' | 'food' | 'med' | 'lux' | 'trust' | 'tension' | 'fist' | 'hand' | 'book' | 'menu' | 'overview'
  | 'arrow' | 'back' | 'eye' | 'eyeOff' | 'secret' | 'symbol' | 'heat' | 'ration' | 'people' | 'witness'
  | 'open' | 'favor' | 'fetch' | 'bribe' | 'blackmail' | 'papers' | 'numbers' | 'lever';

const P: Record<IconName, string> = {
  coal: 'M3 9h18l-2 8H5z M6 9l2-3 3 2 3-3 3 2 2 2 M7 20a1.5 1.5 0 1 0 0.01 0 M17 20a1.5 1.5 0 1 0 0.01 0',
  food: 'M4 14c0-4 4-7 8-7s8 3 8 7c0 2-2 3-4 3H8c-2 0-4-1-4-3z M9 10l1 3 M12 9v4 M15 10l-1 3',
  med: 'M8 4h4v3H8z M7 7h6v13H7z M7 12h6 M15 13l4-4a2 2 0 0 1 3 3l-4 4a2 2 0 0 1-3-3z',
  lux: 'M12 9a6 6 0 1 0 0.01 0 M9 5l3-3 3 3-3 3z',
  trust: 'M3 12l4-4 3 2 3-2 4 3 4 3 M7 8l5 6 M10 16l3 2 3-2 3-3',
  tension: 'M2 12c3 0 4-2 7-2 M22 12c-3 0-4 2-7 2 M9 10l1 2-1 2 M15 14l-1-2 1-2 M10 9l1-2 M14 15l-1 2',
  fist: 'M7 10V7a1.5 1.5 0 0 1 3 0v3 M10 9V6a1.5 1.5 0 0 1 3 0v3 M13 9V7a1.5 1.5 0 0 1 3 0v4 M7 10H5v4c0 3 2 6 6 6h2c3 0 4-3 4-6v-3 M8 21v2h7v-2',
  hand: 'M8 12V5a1.5 1.5 0 0 1 3 0v6 M11 11V3.5a1.5 1.5 0 0 1 3 0V11 M14 11V5a1.5 1.5 0 0 1 3 0v8 M8 12l-2-2a1.5 1.5 0 0 0-2 2l4 5c1 2 2 3 5 3h1c3 0 4-3 4-6v-1 M9 21v2h7v-2',
  book: 'M4 5c3-1 6-1 8 1 2-2 5-2 8-1v14c-3-1-6-1-8 1-2-2-5-2-8-1z M12 6v14',
  menu: 'M4 7h16 M4 12h16 M4 17h16',
  overview: 'M3 9h4v6H3z M8 9h4v6H8z M13 9h4v6h-4z M18 10h3l1 2v3h-4z M2 18h20',
  arrow: 'M4 12h14 M13 6l6 6-6 6',
  back: 'M20 12H6 M11 6l-6 6 6 6',
  eye: 'M2 12s4-6 10-6 10 6 10 6-4 6-10 6S2 12 2 12z M12 9a3 3 0 1 0 0.01 0',
  eyeOff: 'M2 12s4-6 10-6 10 6 10 6-4 6-10 6S2 12 2 12z M4 4l16 16',
  secret: 'M6 4h9l3 3v13H6z M9 13h6v5H9z M10 13v-2a2 2 0 0 1 4 0v2',
  symbol: 'M6 3v18 M6 4h11l-3 4 3 4H6',
  heat: 'M12 3c2 4-2 5 0 9 1-2 3-2 3 1 0 4-2 7-5 7s-5-3-5-6c0-4 5-6 7-11z',
  ration: 'M3 12h18c0 4-4 7-9 7s-9-3-9-7z M8 8c0-2 2-2 2-4 M13 8c0-2 2-2 2-4',
  people: 'M8 8a2.5 2.5 0 1 0 0.01 0 M16 8a2.5 2.5 0 1 0 0.01 0 M3 19c0-4 2-6 5-6s5 2 5 6 M11 19c0-4 2-6 5-6s5 2 5 6',
  witness: 'M9 7a3 3 0 1 0 0.01 0 M3 21c0-5 3-8 6-8s6 3 6 8 M16 11s2-3 4-3 3 3 3 3-1 3-3 3-4-3-4-3z',
  open: 'M3 12l5-5 4 3 4-3 5 5-6 6-3-2-3 2z M14 4h7v6',
  favor: 'M3 6h18v12H3z M3 6l9 7 9-7',
  fetch: 'M4 8l8-4 8 4v9l-8 4-8-4z M12 12v9 M4 8l8 4 8-4 M18 2v4',
  bribe: 'M7 9c0-3 2-5 5-5s5 2 5 5v3c0 5-2 8-5 8s-5-3-5-8z M10 4l2-2 2 2',
  blackmail: 'M5 5h10l4 4v11H5z M9 13h6v5H9z M10 13v-2a2 2 0 0 1 4 0v2',
  papers: 'M6 6h11v14H6z M8 4h11v14 M9 10h5 M9 13h5 M9 16h3',
  numbers: 'M4 20V10 M10 20V4 M16 20v-7 M22 20H2',
  lever: 'M6 20h12 M12 20V8 M12 8l5-5 M17 3a1.5 1.5 0 1 0 0.01 0',
};

export function icon(name: IconName, cls = 'icon'): SVGSVGElement {
  return s('svg', { class: cls === 'icon' || cls.startsWith('icon ') ? cls : `icon ${cls}`, viewBox: '0 0 24 24', 'aria-hidden': 'true', fill: 'none', stroke: 'currentColor', 'stroke-width': 1.8, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' },
    s('path', { d: P[name] }));
}
