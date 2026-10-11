import { describe, expect, it } from 'vitest';
import { P, createGame } from '../../src/game';
import type { StrandedState, TripState } from '../../src/game';
import { followLine, trackPos, tripView, turnCost } from '../../src/ui/stranded';

// 멈춘 열차 판(결정 094): 화면은 열차가 아는 만큼만 그린다. 결과를 모르는 동안에는 예정만으로 수동차 자리를 셈한다.

const st = (over: Partial<StrandedState> = {}): StrandedState => ({
  since: 4, turns: 1, segKm: 30, atKm: 12, toNextKm: 18, seen: [], trip: null, captainAway: false, deputy: null, lostTrips: 0, snow: null, lamp: false, ...over,
});
const trip = (over: Partial<TripState> = {}): TripState => ({
  leaderGoes: false, forced: false, comm: 'tail', names: ['가', '나', '다', '라'], size: 4, distKm: 18, extends: 0,
  goTurns: 2, searchTurns: 1, backTurns: 2, plannedTurns: 5, turn: 1, phase: 'go', posKm: 15,
  baseFood: 10, foodShort: 0, foodOwed: 0, outcome: null, known: false, promise: null, ...over,
});

describe('멈춘 열차 판', () => {
  it('모르는 동안에는 예정대로 간다: 가는 길, 역, 오는 길, 때가 지남', () => {
    const s = st();
    expect(tripView(s, trip({ turn: 1 }))).toMatchObject({ phase: 'go', posKm: 15, left: 4 });
    expect(tripView(s, trip({ turn: 2 }))).toMatchObject({ phase: 'go', posKm: 18 });
    expect(tripView(s, trip({ turn: 3 }))).toMatchObject({ phase: 'search', posKm: 18 });
    expect(tripView(s, trip({ turn: 4 }))).toMatchObject({ phase: 'back', posKm: 8 });
    expect(tripView(s, trip({ turn: 6 }))).toMatchObject({ phase: 'late', posKm: null, left: 0 });
  });

  it('못 돌아옴이나 이어 감은 열차가 알기 전에는 도면에 새지 않는다', () => {
    const s = st();
    const hidden = trip({ turn: 4, outcome: 'lost', extends: 1, distKm: 33, posKm: 30, phase: 'go', known: false });
    expect(tripView(s, hidden)).toMatchObject({ phase: 'back', posKm: 8, distKm: 18 });
    expect(trackPos(s, tripView(s, hidden)).station).toBeNull();
    const known = { ...hidden, known: true };
    expect(tripView(s, known).phase).toBe('lost');
  });

  it('이어 간 것을 알면 선이 길어져 열차가 왼쪽으로 밀린다', () => {
    const s = st();
    const before = trackPos(s, null).train;
    const tv = tripView(s, trip({ known: true, extends: 1, distKm: 33, posKm: 20, phase: 'go', goTurns: 3, backTurns: 4 }));
    const pos = trackPos(s, tv);
    expect(before).toBe(40);
    expect(pos.train).toBeLessThan(before);
    expect(pos.station).not.toBeNull();
    expect(pos.cart!).toBeGreaterThan(pos.station!);
  });

  it('난로에 석탄 한 덩이가 있으면 이번 턴 온기는 안 내려간다', () => {
    const g = createGame('str');
    g.coal = 0;
    expect(turnCost(g)).toMatchObject({ tension: P.strandedTension, warm: P.strandedWarmDrop });
    g.coal = 1;
    expect(turnCost(g).warm).toBe(0);
  });

  it('원정 문턱 줄은 사람 몫과 문턱을 같이 준다', () => {
    const g = createGame('str');
    for (const c of Object.keys(g.comms) as (keyof typeof g.comms)[]) g.comms[c].rel = 0;
    expect(followLine(g)).toMatchObject({ pct: 0, line: 50, ok: false });
    for (const c of Object.keys(g.comms) as (keyof typeof g.comms)[]) g.comms[c].rel = 20;
    expect(followLine(g)).toMatchObject({ pct: 100, ok: true });
  });
});
