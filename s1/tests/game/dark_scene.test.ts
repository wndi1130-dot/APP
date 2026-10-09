import { describe, expect, it } from 'vitest';
import { advance, castVote, chooseCard, createGame, currentAgenda, enableDark, primaryAction, resolveStop, startPrologue, viewCard } from '../../src/game';
import type { Game } from '../../src/game';
import { devScene } from '../../src/game/dark/martial';
import { coupLeft, darkSupportWhy, liftAsk, liftPreview } from '../../src/ui/dark';
import { darkLeverFloor, darkLeverWhy } from '../../src/ui/dark_lock';
import { applyStep } from '../../src/ui/repro';

// S1b 계엄 화면의 순수 부분(ui/dark.ts)과 시험 시작 상태(game/dark/martial.ts devScene). 앱의 newGame과 같은 순서로 판을 만든다.

function sceneGame(scene: string, seed = 'scene-test'): Game {
  const g = createGame(seed);
  enableDark(g);
  startPrologue(g);
  expect(devScene(g, scene)).toBe(true);
  return g;
}

/** 카드를 첫 열린 선택지로 넘기며 다음 출발 전 운영이나 회기까지 간다. until이 참이 되면 멈춘다. */
function run(g: Game, until: (g: Game) => boolean): void {
  for (let guard = 0; guard < 400 && g.phase !== 'end' && !until(g); guard += 1) {
    if (g.cards.length) {
      const card = g.cards[0];
      const v = viewCard(g, card);
      chooseCard(g, card.uid, Math.max(0, v.choices.findIndex(c => !c.disabled)));
      continue;
    }
    if (g.phase === 'stop' && g.stop && !g.stop.done) { resolveStop(g, true); continue; }
    if (!primaryAction(g).ok) break;
    advance(g);
  }
}

describe('시험 시작 상태', () => {
  it('scene=powers: 비상대권이 선 채 시작하고, 서막 뒤 첫 출발 전 운영에 대권이 끝나는 카드가 온다', () => {
    const g = sceneGame('powers');
    expect(g.passed.emergency_powers).toBeDefined();
    expect(g.comms.guard.rel).toBeGreaterThanOrEqual(15); // 연장 문이 열린다
    expect(g.cards.some(c => c.kind === 'dark:powers_end')).toBe(false); // 서막 서류가 먼저다
    run(g, x => x.seg >= 2 && x.phase === 'prep' && x.cards.some(c => c.kind === 'dark:powers_end'));
    expect(g.seg).toBe(2);
    expect(g.decreeLeft).toBe(1);
    const card = g.cards.find(c => c.kind === 'dark:powers_end')!;
    const v = viewCard(g, card);
    const extend = v.choices.find(c => c.special === 'dark:powers:extend')!;
    expect(extend.disabled).toBeUndefined();
  });

  it('scene=martial: 계엄 중으로 시작하고 첫 회기가 계엄 회기다', () => {
    const g = sceneGame('martial');
    expect(g.dark!.martial).toMatchObject({ door: 'extend' });
    expect(g.dark!.martialDoors).toEqual(['extend']);
    run(g, x => x.phase === 'council');
    expect(g.phase).toBe('council');
    expect(g.council!.martial).toBe(true);
    expect(currentAgenda(g)).toBeTruthy();
  });

  it('모르는 이름이거나 S1b가 꺼진 판이면 아무 것도 바꾸지 않는다', () => {
    const g = createGame('scene-none');
    expect(devScene(g, 'powers')).toBe(false); // g.dark 없음
    enableDark(g);
    expect(devScene(g, 'nope')).toBe(false);
    expect(g.dark!.martial).toBeNull();
  });
});

describe('계엄 화면의 계산', () => {
  it('쿠데타 경고의 남은 구간은 오늘을 포함한다', () => {
    const g = sceneGame('martial');
    expect(coupLeft(g)).toBeNull();
    g.dark!.martial!.coupWarnAt = g.seg + 2;
    expect(coupLeft(g)).toBe(3);
    g.dark!.martial!.coupWarnAt = g.seg;
    expect(coupLeft(g)).toBe(1);
  });

  it('경비대 지지는 계엄 중에만 게임의 거절 글로 막히고, 판은 바뀌지 않는다', () => {
    const g = sceneGame('martial');
    const lux = g.lux;
    expect(darkSupportWhy(g, 'guard')).toBe('계엄 중엔 지지로 충성을 사지 못한다');
    expect(darkSupportWhy(g, 'tail')).toBeNull();
    expect(g.lux).toBe(lux);
    expect(darkSupportWhy(sceneGame('powers'), 'guard')).toBeNull();
  });

  it('경비대 배급 레버는 계엄이 올린 값 아래로 못 내린다는 이유와 눈금이 선다', () => {
    const g = sceneGame('martial');
    const lock = g.dark!.martial!.rationLocked;
    expect(darkLeverFloor(g, 'guard', 'ration')).toBe(lock);
    expect(darkLeverFloor(g, 'guard', 'heat')).toBe(0);
    expect(darkLeverFloor(g, 'tail', 'ration')).toBe(0);
    expect(darkLeverWhy(g, 'guard', 'ration', lock - 1)).toMatch(/못 내린다/);
    expect(darkLeverWhy(g, 'guard', 'ration', lock)).toBeNull();
    expect(darkLeverWhy(g, 'tail', 'ration', 0)).toBeNull();
  });

  it('거두기 미리보기는 신임이 계엄 직전 −15로 돌아오는 것을 사본에서 보인다', () => {
    const g = sceneGame('martial');
    run(g, x => x.phase === 'council');
    expect(liftPreview(g)).not.toBeNull();
    const trustBefore = g.dark!.martial!.trustBefore;
    expect(liftPreview(g)!.trust).toBe(Math.max(0, trustBefore - 15));
    expect(liftAsk(g)).toContain('한 번 더 누르면 계엄을 거둔다');
    expect(g.dark!.martial).not.toBeNull(); // 미리보기는 판을 바꾸지 않는다
  });

  it('dark-lift 행동은 계엄을 거두고 그 회기를 닫는다. 계엄 회기가 아니면 이유를 돌려준다', () => {
    const g = sceneGame('martial');
    expect(applyStep(g, { a: 'dark-lift', d: {} })).toBe('계엄 회기에만 거둘 수 있다'); // 아직 출발 전 운영
    run(g, x => x.phase === 'council');
    expect(applyStep(g, { a: 'dark-lift', d: {} })).toBeNull();
    expect(g.dark!.martial).toBeNull();
    expect(g.council!.options).toEqual([]);
    expect(primaryAction(g).ok).toBe(true);
    expect(g.dark!.martialLifted).toBeDefined();
  });

  it('계엄 회기에서 포고하면 결과가 서고 닫을 수 있다', () => {
    const g = sceneGame('martial');
    run(g, x => x.phase === 'council');
    castVote(g, true);
    expect(g.council!.result?.decree).toBe(true);
  });
});
