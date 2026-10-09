import type { Comm, Game } from '../game';

// S1b 계엄 중 경비대 배급 레버 잠금(game/turn.ts setLever)의 화면 쪽. widgets.ts가 부르는 잎 모듈이라 다른 ui 파일을 불러오지 않는다
// (ui/dark.ts는 names.ts를 거쳐 widgets.ts로 이어져 순환이 된다).

/** 계엄 중 경비대 배급 레버를 올린 값 아래로 내릴 수 없는 이유. 게임(turn.ts setLever)은 글 없이 값만 그대로 둔다. 아니면 null. */
export function darkLeverWhy(g: Game, c: Comm, which: 'heat' | 'ration', value: number): string | null {
  const lock = g.dark?.martial;
  if (!lock || c !== 'guard' || which !== 'ration' || Math.round(value) >= lock.rationLocked) return null;
  return '계엄 중엔 경비대 배급을 계엄이 올린 값 아래로 못 내린다.';
}

/** 레버 밑줄: 잠긴 칸을 보인다(계엄 중 경비대 배급) */
export function darkLeverFloor(g: Game, c: Comm, which: 'heat' | 'ration'): number {
  const lock = g.dark?.martial;
  return lock && c === 'guard' && which === 'ration' ? lock.rationLocked : 0;
}
