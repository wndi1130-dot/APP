// A1·A2 때 만든 S1 첫 뼈대(상태·의회·효과). 플레이 코드는 이 묶음을 쓰지 않는다: 규칙 기준은 src/game/이다.
// game/이 가져다 쓰는 것은 rng.ts뿐이다. 나머지는 tests/core/만 부른다. 같은 규칙을 여기서 고쳐도 플레이는 안 바뀐다.
// 의석 배분은 game/state.ts의 seats()가 기준이다(남은 의석 동률을 푸는 순서가 allocateSeats와 다르다. README 참고).
export * from './constants';
export * from './rng';
export * from './state';
export * from './council';
export * from './effects';
