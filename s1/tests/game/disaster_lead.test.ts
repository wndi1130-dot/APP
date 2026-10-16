import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  chooseCard, COMMS, createGame, disasterDepart, disasterSettle, DZ, enableDisasters, foodCost, forecast, pickWeather, viewCard,
} from '../../src/game';
import type { Game } from '../../src/game';
import { backdrop } from '../../src/ui/backdrop';
import { playGame } from '../../tools/s1c_bot';

// 날씨 명세(구현명세_날씨_v1) 2·4장 추천안: 두 구간 앞에 「나빠진다」만, 한 구간 앞에 종류와 대비 카드, 끝나기 한 구간 앞에도 알림.
// 대비 카드에 「출발을 하루 미룬다」. 사용자 답 전이라 DZ.lead·DZ.wait 스위치로 두고, 끈 동작은 disaster.test.ts가 지킨다.

const DZ0 = { ...DZ };
afterEach(() => { Object.assign(DZ, DZ0); });
beforeEach(() => { DZ.lead = 2; DZ.wait = 1; });

const warmth = (g: Game) => COMMS.map(c => g.comms[c].base[0]);

function brewing(seed: string, kind: 'blizzard' | 'cold'): Game {
  DZ.blizzardP = kind === 'blizzard' ? 1 : 0; DZ.coldP = kind === 'cold' ? 1 : 0;
  const g = createGame(seed);
  enableDisasters(g);
  g.seg = DZ.fromSeg;
  disasterSettle(g);
  return g;
}

describe('두 구간 앞 예고', () => {
  it('기본값: 예고 두 단계는 켜고(결정 312), 출발 미루기는 꺼 둔다(결정 313)', () => {
    expect([DZ0.lead, DZ0.wait]).toEqual([2, 0]);
  });

  it('두 구간 앞은 종류를 말하지 않고 카드도 없다, 한 구간 앞에 종류와 대비 카드가 온다', () => {
    for (const kind of ['blizzard', 'cold'] as const) {
      const g = brewing(`dzl-brew-${kind}`, kind);
      expect(g.disaster).toMatchObject({ kind, stage: 'brewing' });
      expect(g.journal.at(-1)!.text).toBe('기관장: 지평선이 무겁다. 날이 나빠지겠다.');
      expect(g.journal.at(-1)!.text).not.toMatch(/눈보라|한파|찬 공기/);
      expect(g.cards.some(c => c.kind === 'disaster_prep')).toBe(false);
      expect(forecast(g).coal).toBe(forecast(createGame(`dzl-brew-${kind}`)).coal); // 두 구간 앞에는 석탄이 더 들지 않는다
      g.seg += 1;
      disasterSettle(g);
      expect(g.disaster).toMatchObject({ kind, stage: 'warn' });
      expect(g.cards.filter(c => c.kind === 'disaster_prep')).toHaveLength(1);
    }
  });

  it('판 흐름: 두 구간 앞 -> 한 구간 앞 -> 시작 -> 끝나기 하루 전 알림 -> 끝', () => {
    DZ.blizzardP = 1; DZ.coldP = 0;
    const { g } = playGame('dzl-order', { s1c: false, policy: 'caretaker', dom: 'idle', disasters: true });
    const log = g.journal.filter(j => /지평선이 무겁다|서쪽 하늘이 낮다|눈보라가 시작됐다|바람이 잦아든다|눈보라가 그쳤다/.test(j.text));
    const s = log[0].seg;
    expect(s).toBe(DZ.fromSeg);
    expect(log.slice(0, 5).map(j => [j.seg - s, j.text.slice(0, 6)])).toEqual([
      [0, '기관장: 지'], [1, '기관장: 서'], [2, '눈보라가 시'], [2, '바람이 잦아'], [3, '눈보라가 그'],
    ]);
  });

  it('두 구간 앞 정차는 앞머리 날씨다: 눈보라는 흐림, 한파는 한파 전조(겉은 갠 하늘), 하늘은 내려앉는다', () => {
    const b = brewing('dzl-wx-b', 'blizzard');
    const c = brewing('dzl-wx-c', 'cold');
    expect(pickWeather(b)).toBe('overcast');
    expect(pickWeather(c)).toBe('cold_front');
    c.stop = null;
    expect(backdrop(c, 'cold_front')).toMatchObject({ sky: 'clear', omen: true });
    expect(backdrop(b, 'overcast')).toMatchObject({ sky: 'overcast', omen: true });
  });
});

describe('출발을 하루 미룬다', () => {
  function warned(seed: string, kind: 'blizzard' | 'cold'): Game {
    const g = brewing(seed, kind);
    g.seg += 1;
    disasterSettle(g);
    return g;
  }

  it('대비 카드에 넷째 선택지로 있고, 끄면 없다', () => {
    const g = warned('dzl-card', 'blizzard');
    const card = g.cards.find(c => c.kind === 'disaster_prep')!;
    expect(viewCard(g, card).choices.map(c => c.label)).toEqual(['석탄을 쌓아 둔다', '칸을 모아 잔다', '출발을 하루 미룬다', '그냥 간다']);
    DZ.wait = 0;
    expect(viewCard(g, card).choices.map(c => c.label)).toEqual(['석탄을 쌓아 둔다', '칸을 모아 잔다', '그냥 간다']);
  });

  it('하루치 배급·석탄·긴장을 치르고, 첫 구간을 선 채로 넘겨 한 구간 덜 맞고, 온기 감소는 절반이다', () => {
    for (const [kind, len, warm] of [['blizzard', DZ.blizzardLen, DZ.blizzardWarm], ['cold', DZ.coldLen, DZ.coldWarm]] as const) {
      const g = warned(`dzl-wait-${kind}`, kind);
      const card = g.cards.find(c => c.kind === 'disaster_prep')!;
      const [food, coal, tension] = [g.food, g.coal, g.tension];
      const day = Math.round(foodCost(g));
      expect(chooseCard(g, card.uid, 2)).toBe(true);
      expect([g.food, g.coal, g.tension]).toEqual([food - day, coal - DZ.waitCoal, tension + DZ.waitTension]);
      expect(g.disaster).toMatchObject({ prep: 'wait' });
      expect(g.disaster?.unprepared).toBeUndefined();
      const before = warmth(g);
      disasterDepart(g);
      expect(g.disaster).toMatchObject({ stage: 'active', left: len - 1 });
      expect(warmth(g)).toEqual(before.map(w => w - warm * DZ.prepWarmMult));
      expect(g.journal.some(j => j.text.startsWith('출발을 하루 미뤘다.'))).toBe(true);
      DZ.deathP = 1;
      for (let i = 0; i < len - 1; i += 1) disasterSettle(g);
      expect(g.disaster).toBeUndefined();
      expect(g.deaths).toEqual([]);
    }
  });

  it('봇 정책: 늘 미루기와 날씨 읽기(눈보라만 미룸)가 돈다', () => {
    DZ.blizzardP = 0.5; DZ.coldP = 0.5;
    const wait = playGame('dzl-bot', { s1c: false, policy: 'caretaker', dom: 'idle', disasters: true, prep: 'wait' }).m;
    // 하루치를 못 치르는 판(막힌 선택지)에서는 돌봄 정책으로 넘어간다.
    expect(wait.prep.wait).toBeGreaterThan(0);
    expect(wait.prep.wait).toBeGreaterThanOrEqual(wait.prep.coal + wait.prep.huddle);
    const read = playGame('dzl-bot', { s1c: false, policy: 'caretaker', dom: 'idle', disasters: true, prep: 'read' }).m;
    expect(read.prep.wait + read.prep.coal + read.prep.huddle).toBeGreaterThan(0);
  });
});
