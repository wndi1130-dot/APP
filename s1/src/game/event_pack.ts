import type { Game } from './state';

// 새 이동 사건 묶음(data/events/ev_b01_*.json)과 이동 사건 가중 뽑기(cards.ts DRAW). 기본 꺼짐: enableEventPack(g)를 부른 판에서만 돈다.
// 꺼진 판: id가 EVENT_PACK_PREFIX로 시작하는 콘텐츠 사건은 후보에 안 들어가고(content.ts contentPool), 이동 사건은 원래의 균등 뽑기다(cards.ts drawTravelEvent).
// 켠 판: 새 사건이 후보에 들고, 이동 사건을 처지 압박·새로움·화자 벌점이 든 가중치로 뽑는다.
// 이 파일은 상태를 만들거나 난수를 쓰는 함수가 enableEventPack 하나뿐이고 그것도 난수는 안 쓴다.

/** 새 이동 사건 묶음의 id 머리말 */
export const EVENT_PACK_PREFIX = 'ev_b01_';

/** 판에 새 이동 사건 묶음과 가중 뽑기를 켠다. S1a·S1b·S1c 어느 판에든 얹을 수 있다. */
export function enableEventPack(g: Game): void {
  g.eventPack = true;
}

export function eventPackOn(g: Game): boolean {
  return !!g.eventPack;
}

/** 어려워진 사건 묶음(H01~H10과 후속, 기획 30장)의 id 모양. ev_h01_low_fire, ev_h02_sour_pot 처럼 ev_h와 두 자리 숫자로 시작한다 */
const HARD_PACK_ID = /^ev_h\d\d_/u;

/** 이 콘텐츠 사건 id가 묶음 소속이면 true */
export const inEventPack = (id: string): boolean => id.startsWith(EVENT_PACK_PREFIX) || HARD_PACK_ID.test(id);
