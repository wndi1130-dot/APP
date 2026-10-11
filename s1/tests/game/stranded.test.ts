import { describe, expect, it } from 'vitest';
import { advance, createGame, enterStranded, forecast, P, predictStall, stallKm, strandedSettle } from '../../src/game';
import type { Game } from '../../src/game';
import { playGame } from '../../tools/s1c_bot';

// 멈춘 열차(구현명세 가, 결정 034·035·037): 석탄이 처음 0이 되면 판이 끝나지 않고 선다.

const fresh = (seed: string): Game => { const g = createGame(seed); g.cards = []; return g; };

describe('서는 지점 셈', () => {
  it('구간 길이 × 남은 석탄 / 드는 석탄, 1km 이상 구간 끝 전까지', () => {
    expect(stallKm(30, 4, 10)).toBe(12);
    expect(stallKm(30, 0, 10)).toBe(1);
    expect(stallKm(30, 10, 10)).toBe(29); // 딱 다하는 판도 다음 역 앞 1km에서 선다
    expect(stallKm(30, 4, 0)).toBe(29);
  });

  it('출발 전 예고는 석탄이 모자랄 때만 나오고 서는 지점과 남은 길을 준다', () => {
    const g = fresh('st-predict');
    expect(predictStall(g)).toBeNull();
    g.coal = 3;
    const p = predictStall(g);
    expect(p).not.toBeNull();
    expect(p!.atKm + p!.toNextKm).toBe(p!.segKm);
    expect(p!.segKm).toBe(P.segKmDefault);
    g.stranded = { since: 1, turns: 0, segKm: 30, atKm: 5, toNextKm: 25, seen: [] };
    expect(predictStall(g)).toBeNull();
  });
});

describe('멈춤', () => {
  it('enterStranded: 석탄 0, 서는 지점·표식·일지가 남고 판은 안 끝난다', () => {
    const g = fresh('st-enter');
    g.coal = -2;
    enterStranded(g, 4, 10);
    expect(g.coal).toBe(0);
    expect(g.end).toBeNull();
    expect(g.stranded).toMatchObject({ since: g.seg, turns: 0, segKm: 30, atKm: 12, toNextKm: 18, seen: [] });
    expect(g.contentFlags?.stranded).toBe(true);
    expect(g.journal.some(j => j.text.includes('12km 지점에서 섰다'))).toBe(true);
  });

  it('선 열차는 탈 석탄이 없고 식량은 평소대로 든다', () => {
    const g = fresh('st-forecast');
    const run = forecast(g);
    enterStranded(g, 4, 10);
    const f = forecast(g);
    expect(f.coal).toBe(0);
    expect(f.food).toBe(run.food);
  });

  it('멈춘 정산은 모든 칸 온기를 P.strandedWarmDrop씩 내리되 바닥 아래로는 안 내리고, 석탄이 있으면 한 덩이를 태워 하락을 건너뛴다', () => {
    const g = fresh('st-warm');
    enterStranded(g, 4, 10);
    for (const c of Object.keys(g.comms) as (keyof Game['comms'])[]) g.comms[c].base[0] = 60;
    g.comms.tail.base[0] = P.strandedWarmFloor + 2;
    strandedSettle(g);
    expect(g.stranded!.turns).toBe(1);
    expect(g.comms.front.base[0]).toBe(60 - P.strandedWarmDrop);
    expect(g.comms.tail.base[0]).toBe(P.strandedWarmFloor);
    g.coal = 2;
    strandedSettle(g);
    expect(g.coal).toBe(1);
    expect(g.comms.front.base[0]).toBe(60 - P.strandedWarmDrop);
  });

  it('선 열차의 출발은 정차가 아니라 멈춘 열차 사건 하나이고 구간이 하나 잃는다', () => {
    const g = fresh('st-depart');
    enterStranded(g, 4, 10);
    g.phase = 'prep';
    const lost = g.lostSegments;
    advance(g);
    expect(g.phase).toBe('travel');
    expect(g.lostSegments).toBe(lost + 1);
    expect(g.cards).toHaveLength(1);
    expect(g.cards[0].text).toBe('ev_str_lamp');
    expect(g.stranded!.seen).toEqual(['ev_str_lamp']);
    g.cards = [];
    g.phase = 'prep';
    advance(g);
    expect(g.cards.map(c => c.text)).toEqual(['ev_str_snow']);
  });

  it('식량이 30 아래면 「반 그릇」이 앞당겨 뜬다', () => {
    const g = fresh('st-bowl');
    enterStranded(g, 4, 10);
    g.food = 25;
    g.phase = 'prep';
    advance(g);
    expect(g.cards.map(c => c.text)).toEqual(['ev_str_half_bowl']);
  });

  it('구간 수를 넘겨도 완주하지 않고 seg가 계속 오른다', () => {
    const g = fresh('st-past');
    g.seg = P.segments;
    enterStranded(g, 4, 10);
    g.phase = 'settle';
    advance(g);
    expect(g.end).toBeNull();
    expect(g.seg).toBe(P.segments + 1);
    expect(g.phase).toBe('prep');
  });
});

describe('판을 돌리면', () => {
  it('석탄이 0이 되어도 좌초로 끝나지 않고, 선 뒤로 정산마다 멈춘 턴이 하나씩 센다', () => {
    let dropped = false;
    const turns: number[] = [];
    let endedStrandedEarly = false;
    const { g } = playGame('st-bot-1', {
      s1c: false, policy: 'caretaker', dom: 'idle',
      probe: {
        beforePick: (gg: Game) => { if (!dropped && gg.seg >= 3) { dropped = true; gg.coal = 1; } },
        onSettle: (gg: Game) => { if (gg.stranded) turns.push(gg.stranded.turns); if (gg.end === 'stranded') endedStrandedEarly = true; },
      },
    } as never);
    expect(dropped).toBe(true);
    expect(g.stranded).toBeTruthy();
    expect(endedStrandedEarly).toBe(false);
    expect(g.end === null || g.end !== 'stranded').toBe(true);
    expect(turns.length).toBeGreaterThanOrEqual(2);
    for (let i = 1; i < turns.length; i += 1) expect(turns[i]).toBeGreaterThanOrEqual(turns[i - 1]);
    expect(turns[turns.length - 1]).toBeGreaterThanOrEqual(1);
  }, 120000);
});
