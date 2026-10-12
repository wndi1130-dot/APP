import { describe, expect, it } from 'vitest';
import { createGame, createS1cGame, expectedCoalStops, lookbackLines, routeWasThin, trackLookback } from '../../src/game';
import type { Game } from '../../src/game';

// 끝 화면의 「돌이켜 보면」 줄(결정 183). 정산마다 읽어 적고, 끝날 때 한두 줄을 일지에 남긴다. 판의 값은 건드리지 않는다.

/** 단열한 칸이 하나 있는 내정 판(단열 줄이 끼어들지 않게). */
function warm(seed: string): Game {
  const g = createS1cGame(seed);
  g.dom!.insulated = ['car'];
  return g;
}

function at(g: Game, seg: number, patch: Partial<{ coal: number; food: number }> = {}): void {
  g.seg = seg;
  g.coal = patch.coal ?? 60;
  g.food = patch.food ?? 80;
  trackLookback(g);
}

function ended(g: Game, end: NonNullable<Game['end']>, seg: number): string[] {
  g.seg = seg;
  g.end = end;
  return lookbackLines(g);
}

describe('돌이켜 보면: 처음 바닥을 본 정산을 한 번만 적는다', () => {
  it('내려갔다 올라갔다 다시 내려가도 처음 것을 남긴다', () => {
    const g = createS1cGame('look-1');
    at(g, 8, { coal: 10 });
    at(g, 9, { coal: 40 });
    at(g, 10, { coal: 5 });
    expect(g.look?.low.coal).toBe(8);
    expect(g.look?.low.food).toBeUndefined();
  });

  it('내정을 끈 판에는 목재·고철 기록이 없고 오류도 나지 않는다', () => {
    const g = createGame('look-2');
    expect(g.dom).toBeUndefined();
    at(g, 4, { coal: 10 });
    expect(g.look?.low.wood).toBeUndefined();
    expect(g.look?.low.scrap).toBeUndefined();
    expect(g.look?.low.coal).toBe(4);
  });

  it('내정을 켠 판은 목재·고철이 3 이하일 때 적는다', () => {
    const g = createS1cGame('look-3');
    g.dom!.wood = 3; g.dom!.scrap = 9;
    at(g, 5);
    expect(g.look?.low.wood).toBe(5);
    expect(g.look?.low.scrap).toBeUndefined();
  });
});

describe('돌이켜 보면: 반란', () => {
  it('석탄이 8째에 바닥을 보이고 꼬리칸 난방을 9째에 내리면 줄이 둘이고 둘째는 난방 줄이다', () => {
    const g = warm('look-4');
    at(g, 8, { coal: 10 });
    g.look!.coalStops = 6;
    g.comms.tail.heat = 1;
    at(g, 9, { coal: 8 });
    const lines = ended(g, 'revolt', 10);
    expect(lines).toHaveLength(2);
    expect(lines[0]).toBe('돌이켜 보면, 8째 정산에서 석탄이 처음 바닥을 보였다.');
    expect(lines[1]).toBe('9째 정산에서 꼬리칸의 난방을 내렸다. 석탄은 아꼈고 꼬리칸은 식었다.');
  });

  it('난방을 석탄이 바닥을 보이기 전(5째)에 내렸으면 둘째 줄이 없다', () => {
    const g = warm('look-5');
    g.comms.tail.heat = 1;
    at(g, 5);
    g.look!.coalStops = 6;
    at(g, 8, { coal: 10 });
    const lines = ended(g, 'revolt', 10);
    expect(lines).toHaveLength(1);
  });

  it('바닥을 본 적이 없는 반란은 「모자란 것은 다른 데 있었다」 한 줄', () => {
    const g = warm('look-6');
    at(g, 3);
    expect(ended(g, 'revolt', 10)).toEqual(['돌이켜 보면, 석탄도 식량도 바닥을 보인 적은 없었다. 모자란 것은 다른 데 있었다.']);
  });

  it('석탄과 식량이 같은 정산이면 함께, 다른 정산이면 뒤따랐다로 쓴다', () => {
    const a = warm('look-7');
    at(a, 6, { coal: 10, food: 20 });
    expect(ended(a, 'ousted', 7)).toEqual(['돌이켜 보면, 6째 정산에서 석탄과 식량이 함께 바닥을 보였다.']);
    const b = warm('look-8');
    at(b, 6, { coal: 10 });
    at(b, 9, { coal: 10, food: 20 });
    expect(ended(b, 'ousted', 10)).toEqual(['돌이켜 보면, 6째 정산에서 석탄이 처음 바닥을 보였고, 9째 정산에서 식량이 뒤따랐다.']);
  });
});

describe('돌이켜 보면: 단열', () => {
  it('석탄이 처음 바닥을 본 정산에 단열한 칸이 없고 목재가 있었으면 단열 줄이 둘째 줄', () => {
    const g = createS1cGame('look-ins');
    g.dom!.wood = 20;
    at(g, 8, { coal: 10 });
    g.look!.coalStops = 6;
    expect(g.look?.skip.noInsulate).toBe(8);
    expect(ended(g, 'revolt', 9)[1]).toBe('그때 단열한 칸은 하나도 없었다. 식은 칸이 석탄을 더 먹었다.');
  });
});

describe('돌이켜 보면: 길이 박했던 판', () => {
  it('구간 12까지 석탄 나는 역이 1곳이면 노선 줄, 3곳이면 없다', () => {
    expect(expectedCoalStops(12)).toBeGreaterThan(2);
    const thin = warm('look-9');
    at(thin, 12, { coal: 10 });
    thin.look!.coalStops = 1;
    expect(routeWasThin(thin)).toBe(true);
    const lines = ended(thin, 'revolt', 13);
    expect(lines[1]).toContain('이 노선은 석탄이 나는 역이 드물었다.');

    const fed = warm('look-10');
    at(fed, 12, { coal: 10 });
    fed.look!.coalStops = 3;
    expect(routeWasThin(fed)).toBe(false);
    expect(ended(fed, 'revolt', 13).join(' ')).not.toContain('드물었다');
  });

  it('구간 6까지는 기댓값이 2에 못 미쳐 박했다고 보지 않는다', () => {
    expect(expectedCoalStops(6)).toBeLessThan(2);
    const g = warm('look-11');
    at(g, 6, { coal: 10 });
    expect(routeWasThin(g)).toBe(false);
  });
});

describe('돌이켜 보면: 다른 끝', () => {
  it('축출·쿠데타·열차장 실종은 바닥을 본 적이 있을 때만 첫 줄 하나', () => {
    for (const end of ['ousted', 'coup', 'lost_captain'] as const) {
      const none = createS1cGame(`look-12-${end}`);
      at(none, 5);
      expect(ended(none, end, 6)).toEqual([]);
      const some = createS1cGame(`look-13-${end}`);
      at(some, 5, { coal: 10 });
      expect(ended(some, end, 6)).toHaveLength(1);
    }
  });

  it('완주는 바닥을 본 적이 없으면 없고, 있으면 「그래도 닿았다」', () => {
    const none = createS1cGame('look-14');
    at(none, 5);
    expect(ended(none, 'complete', 24)).toEqual([]);
    const one = createS1cGame('look-15');
    at(one, 11, { coal: 10 });
    expect(ended(one, 'complete', 24)).toEqual(['돌이켜 보면, 11째 정산에서 석탄이 바닥을 보였다. 그래도 닿았다.']);
    const two = createS1cGame('look-16');
    at(two, 11, { coal: 10 });
    at(two, 17, { coal: 10, food: 20 });
    expect(ended(two, 'complete', 24)).toEqual(['돌이켜 보면, 11째 정산에서 석탄이, 17째 정산에서 식량이 바닥을 보였다. 그래도 닿았다.']);
  });

  it('좌초는 석탄이 처음 바닥을 본 정산에 곧바로 서면 첫 줄 하나뿐', () => {
    const g = createS1cGame('look-17');
    at(g, 9, { coal: 0 });
    expect(ended(g, 'stranded', 9)).toHaveLength(1);
  });
});

describe('돌이켜 보면: 글', () => {
  it('숫자는 「째 정산」 앞에만 나온다', () => {
    const lines: string[] = [];
    for (const [heat, quota] of [[1, false], [2, true]] as const) {
      const g = warm(`look-text-${heat}`);
      g.comms.tail.heat = heat;
      if (quota) g.passed.heat_quota = 7;
      at(g, 7, { coal: 10, food: 20 });
      g.look!.coalStops = 6;
      at(g, 8, { coal: 8, food: 20 });
      lines.push(...ended(g, 'revolt', 9));
    }
    expect(lines.length).toBeGreaterThan(2);
    for (const line of lines) expect(line.replace(/\d+째 정산/g, '')).not.toMatch(/\d/);
  });
});
