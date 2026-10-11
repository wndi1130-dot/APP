import { describe, expect, it } from 'vitest';
import { chooseCard, createGame, crewPreview, exposeMult, forecast, P, situation, tailIdle } from '../../src/game';
import type { Game } from '../../src/game';

// 결정 059·060: 꼬리칸을 버리는 길에 값이 붙는다. 손 빠짐(작업 거부 중이면 석탄이 더 든다),
// 쌓이는 진압(마지막 기회의 되돌림 값이 오르고 공포가 긴장 오름을 늦추지 않는다), 노출이 다치게 한다.

const fresh = (seed: string): Game => { const g = createGame(seed); g.cards = []; return g; };

function crisis(g: Game, index: number): void {
  const uid = g.nextCardUid++;
  g.cards.push({ uid, kind: 'tension_crisis', comm: 'tail' });
  expect(chooseCard(g, uid, index)).toBe(true);
}

describe('손 빠짐(059 가)', () => {
  it('꼬리칸이 작업을 거부 중일 때만 구간 석탄이 P.tailIdleCoal만큼 더 든다', () => {
    const g = fresh('tc-idle');
    const calm = forecast(g).coal;
    g.comms.tail.fervor = 1; g.comms.tail.rel = -30;
    expect(tailIdle(g)).toBe(false);
    expect(forecast(g).coal).toBe(calm);
    g.comms.tail.rel = -40;
    expect(tailIdle(g)).toBe(true);
    expect(forecast(g).coal - calm).toBeCloseTo(P.tailIdleCoal, 6);
  });
});

describe('쌓이는 진압(059 나)', () => {
  it('마지막 기회로 긴장을 되돌리는 값이 쓸 때마다 P.crisisStep씩 오른다', () => {
    const g = fresh('tc-crisis');
    g.tension = 100;
    crisis(g, 0);
    expect(g.tension).toBe(P.crisisBase);
    g.tension = 100;
    crisis(g, 1);
    expect(g.tension).toBe(P.crisisBase + P.crisisStep);
    expect(g.tensionCrisisUsed).toBe(2);
  });
});

describe('노출이 다치게 한다(060 가)', () => {
  it('노출 50까지는 1배, 그 위로 점마다 P.exposeHurt가 붙고 정차 카드 미리 보기에 나온다', () => {
    const g = fresh('tc-expo');
    g.comms.tail.base[3] = 50 - situation(g, 'tail')[3] + g.comms.tail.base[3];
    expect(exposeMult(g, 'tail')).toBe(1);
    g.comms.tail.base[3] += 20;
    expect(exposeMult(g, 'tail')).toBeCloseTo(1 + 20 * P.exposeHurt, 6);
    expect(crewPreview(g, 'tail').risk).toBeCloseTo(1 + 20 * P.exposeHurt, 6);
  });

  it('꼬리칸만 보내면 노출이 시작값 60을 넘어 한계 P.crewCap까지 실제로 오른다', () => {
    const g = fresh('tc-cap');
    expect(g.comms.tail.base[3]).toBeLessThan(P.crewCap);
    expect(crewPreview(g, 'tail').to).toBeGreaterThan(crewPreview(g, 'tail').from);
  });
});
