import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  chooseCard, COMMS, createGame, PLACES, disasterDepart, disasterSettle, DZ, enableDisasters, foodCost, forecast, pickWeather, viewCard,
} from '../../src/game';
import type { Game } from '../../src/game';
import { backdrop } from '../../src/ui/backdrop';
import { playGame } from '../../tools/s1c_bot';

// 날씨 명세(구현명세_날씨_v1) 2·4장 추천안: 두 구간 앞에 「나빠진다」만, 한 구간 앞에 종류와 대비 카드, 끝나기 한 구간 앞에도 알림.
// 눈보라 대비 카드에 「출발을 하루 미룬다」(결정 338). DZ.lead·DZ.wait 스위치로 두고, 끈 동작은 disaster.test.ts가 지킨다.

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
  it('기본값: 예고 두 단계(결정 312), 출발 미루기는 켜고 B 값과 한 번 더 뒤지기(결정 332·338)', () => {
    expect([DZ0.lead, DZ0.wait, DZ0.waitFood, DZ0.waitCoal, DZ0.waitTension, DZ0.waitSearch]).toEqual([2, 1, 0, 2, 1, 1]);
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

  it('눈보라 예고가 뜬 정차에는 대비 카드 넷째 선택지로 있고, 끄면 없다', () => {
    const g = warned('dzl-card', 'blizzard');
    const card = g.cards.find(c => c.kind === 'disaster_prep')!;
    expect(viewCard(g, card).choices.map(c => c.label)).toEqual(['석탄을 쌓아 둔다', '칸을 모아 잔다', '출발을 하루 미룬다', '그냥 간다']);
    DZ.wait = 0;
    expect(viewCard(g, card).choices.map(c => c.label)).toEqual(['석탄을 쌓아 둔다', '칸을 모아 잔다', '그냥 간다']);
  });

  it('눈보라 예고가 없는 정차에는 단추가 없다: 예고 없는 정차엔 대비 카드가 없고, 한파 예고 카드에는 미루기가 없다', () => {
    DZ.blizzardP = 0; DZ.coldP = 0;
    const calm = createGame('dzl-calm');
    enableDisasters(calm);
    calm.seg = DZ.fromSeg;
    disasterSettle(calm);
    expect(calm.disaster).toBeUndefined();
    expect(calm.cards.some(c => c.kind === 'disaster_prep')).toBe(false);
    const cold = warned('dzl-card-cold', 'cold');
    const card = cold.cards.find(c => c.kind === 'disaster_prep')!;
    expect(viewCard(cold, card).choices.map(c => c.label)).toEqual(['석탄을 쌓아 둔다', '칸을 모아 잔다', '그냥 간다']);
  });

  it('석탄·긴장을 치르고(배급은 안 든다), 첫 구간을 선 채로 넘겨 한 구간 덜 맞고, 온기 감소는 절반이다', () => {
    for (const [kind, len, warm] of [['blizzard', DZ.blizzardLen, DZ.blizzardWarm]] as const) {
      const g = warned(`dzl-wait-${kind}`, kind);
      const card = g.cards.find(c => c.kind === 'disaster_prep')!;
      const [food, coal, tension] = [g.food, g.coal, g.tension];
      const day = Math.round(foodCost(g) * DZ.waitFood);
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

  it('미룬 날 이번 정차를 같은 작업조로 한 번 더 뒤진다', () => {
    const g = warned('dzl-search', 'blizzard');
    const place = PLACES.find(p => p.loot.food > 0)!;
    g.stop = { place: place.id, target: 'food', stay: 'normal', crewComm: 'tail', crewSize: 4, threat: 1, done: true, result: null };
    const stays = () => g.journal.filter(j => j.text.startsWith(`${place.name}에 `) && j.text.includes('머물렀다')).length;
    const before = stays();
    const card = g.cards.find(c => c.kind === 'disaster_prep')!;
    expect(chooseCard(g, card.uid, 2)).toBe(true);
    expect(stays()).toBe(before + 1);
    expect(g.stop).toMatchObject({ place: place.id, done: true });
    expect(g.stop?.again).toBeUndefined();
    DZ.waitSearch = 0;
    const h = warned('dzl-search', 'blizzard');
    h.stop = { place: place.id, target: 'food', stay: 'normal', crewComm: 'tail', crewSize: 4, threat: 1, done: true, result: null };
    expect(chooseCard(h, h.cards.find(c => c.kind === 'disaster_prep')!.uid, 2)).toBe(true);
    expect(h.journal.filter(j => j.text.includes('머물렀다')).length).toBe(0);
  });

  it('봇 정책: 한파에는 미룰 수 없어 늘 미루기가 날씨 읽기(눈보라만 미룸)와 같아진다', () => {
    DZ.blizzardP = 0.5; DZ.coldP = 0.5;
    const wait = playGame('dzl-bot', { s1c: false, policy: 'caretaker', dom: 'idle', disasters: true, prep: 'wait' }).m;
    expect(wait.prep.wait).toBeGreaterThan(0);
    const read = playGame('dzl-bot', { s1c: false, policy: 'caretaker', dom: 'idle', disasters: true, prep: 'read' }).m;
    expect(read.prep).toEqual(wait.prep);
    expect(read.prep.coal + read.prep.huddle).toBeGreaterThan(0);
  });
});
