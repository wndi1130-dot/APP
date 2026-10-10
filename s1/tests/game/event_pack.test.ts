import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  CONTENT_EVENTS, DRAW, EVENT_CHAIN_MAX, EVENT_PACK_PREFIX, TRAVEL_EVENTS, cloneGame, contentDrawInfo, contentPool, createGame, drawTravelEvent, enableEventPack,
  eventPackOn, inEventPack, noveltyOf, pressureOf, registerContentEvents, rnd, situation, travelWeight,
} from '../../src/game';
import type { Comm, Game } from '../../src/game';
import { readSave } from '../../src/ui/repro';
import { playGame } from '../../tools/s1c_bot';
import type { BotOptions } from '../../tools/s1c_bot';
import { loadContentEvents } from '../../tools/content_fs';

// 새 이동 사건 묶음(data/events/ev_b01_*.json)과 이동 사건 가중 뽑기(cards.ts DRAW). 기본 꺼짐: enableEventPack(g)를 부른 판에서만 돈다.
// 꺼진 판은 묶음 사건이 후보에 안 들고 drawTravelEvent가 원래의 균등 pick을 쓴다. 켠 판은 무게 = 기본 × 처지 압박 × 새로움 × 화자 벌점.

const DRAW0 = { ...DRAW };
beforeEach(() => { CONTENT_EVENTS.length = 0; loadContentEvents(); });
afterEach(() => { Object.assign(DRAW, DRAW0); CONTENT_EVENTS.length = 0; });

const PACK = () => CONTENT_EVENTS.filter(e => e.id.startsWith(EVENT_PACK_PREFIX));
const packIds = (g: Game) => contentPool(g).map(e => e.id).filter(inEventPack);

const CONFIGS: BotOptions[] = [
  { s1c: false, policy: 'caretaker', dom: 'idle' },
  { s1c: false, policy: 'first', dom: 'idle' },
  { s1c: true, policy: 'caretaker', dom: 'engaged' },
  { s1c: true, policy: 'first', dom: 'engaged', s1b: 'kind', disasters: true },
];
const SEEDS = ['ep-0', 'ep-1', 'ep-2', 'ep-3'];

/** 이동 사건(TS)을 풀에서 모두 닫아, drawTravelEvent의 후보가 extra뿐이게 한다 */
function closeTravelEvents(g: Game): void {
  for (const e of TRAVEL_EVENTS) g.eventLog[e.id] = { n: EVENT_CHAIN_MAX, seg: g.seg, pick: 'x', st: 'x' };
}

/** 시험용 콘텐츠 사건. trigger와 화자만 바꾼다 */
function fake(id: string, trigger: unknown[], speaker = 'tail') {
  return {
    id, stage: 's1a', phase: 'travel', trigger, speaker, body: '시험.', repeat: 0,
    choices: [{ id: 'c_a', label: '그냥 둔다', effects: [], followups: [], witnesses: [] }, { id: 'c_b', label: '본다', effects: [], followups: [], witnesses: [] }],
  };
}

describe('묶음 데이터', () => {
  it('ev_b01_ 사건이 20개 읽히고 모두 이동(travel) 단계 s1a 사건이다', () => {
    expect(PACK().length).toBe(20);
    for (const e of PACK()) { expect(e.phase).toBe('travel'); expect(e.stage).toBe('s1a'); }
  });
});

describe('꺼짐(기본)', () => {
  it('createGame과 기본 판에는 eventPack 칸이 없다', () => {
    const g = createGame('ep-fields');
    expect('eventPack' in g).toBe(false);
    expect(eventPackOn(g)).toBe(false);
    expect(JSON.stringify(g)).not.toContain('eventPack');
  });

  it('조건이 다 맞는 판에서도 contentPool에 ev_b01_ 사건이 안 든다. 켜면 든다', () => {
    const g = createGame('ep-pool');
    g.seg = 6;
    g.comms.tail.base[0] = 20; // 꼬리칸 따뜻함 낮음(frost_bird 조건)
    expect(packIds(g)).toEqual([]);
    const on = cloneGame(g);
    enableEventPack(on);
    expect(eventPackOn(on)).toBe(true);
    expect(packIds(on).length).toBeGreaterThan(0);
    // 묶음이 아닌 사건은 켜고 끔에 상관없이 같다
    registerContentEvents([fake('ev_zz_other', [{ type: 'segment', min: 1, max: 30 }])]);
    expect(contentPool(g).filter(e => !inEventPack(e.id)).map(e => e.id)).toEqual(['ev_zz_other']);
    expect(contentPool(on).filter(e => !inEventPack(e.id)).map(e => e.id)).toEqual(['ev_zz_other']);
  });

  it('끈 판을 끝까지 돌려도 ev_b01_ 카드가 한 번도 안 나온다. 켠 판은 나온다', () => {
    const offIds = new Set<string>();
    const onIds = new Set<string>();
    for (const opts of CONFIGS) {
      for (const seed of SEEDS) {
        const off = playGame(seed, opts);
        expect(off.g.eventPack).toBeUndefined();
        for (const id of Object.keys(off.m.contentById)) offIds.add(id);
        expect(JSON.stringify(off.g)).not.toContain(EVENT_PACK_PREFIX);
        expect(JSON.stringify(off.g)).not.toMatch(/ev_h\d\d_/u);
        for (const id of Object.keys(playGame(seed, { ...opts, eventPack: true }).m.contentById)) onIds.add(id);
      }
    }
    expect([...offIds].filter(inEventPack)).toEqual([]);
    expect([...onIds].filter(inEventPack).length).toBeGreaterThanOrEqual(5);
  });

  it('drawTravelEvent는 균등 pick과 같다: 난수 한 번, 고른 칸이 floor(r×길이)', () => {
    const extra = ['content:a', 'content:b', 'content:c', 'content:d', 'content:e'];
    const seen = new Set<string>();
    for (let i = 0; i < 40; i += 1) {
      const g = createGame(`ep-uniform-${i}`);
      g.seg = 6;
      closeTravelEvents(g);
      const ref = cloneGame(g);
      const r = rnd(ref);
      const id = drawTravelEvent(g, extra);
      expect(id).toBe(extra[Math.floor(r * extra.length)]);
      expect(g.rng).toEqual(ref.rng); // 난수를 한 번만 썼다
      expect(g.recentEvents.at(-1)).toBe(id);
      seen.add(id!);
    }
    expect(seen.size).toBeGreaterThan(2); // 한쪽으로 쏠리지 않는다
  });

  it('후보가 없으면 null이고 난수를 안 쓴다', () => {
    const g = createGame('ep-empty');
    g.seg = 1;
    closeTravelEvents(g);
    const ref = cloneGame(g);
    expect(drawTravelEvent(g, [])).toBeNull();
    expect(g.rng).toEqual(ref.rng);
    enableEventPack(g);
    expect(drawTravelEvent(g, [])).toBeNull();
    expect(g.rng).toEqual(ref.rng);
  });
});

describe('켜짐: 무게 = 기본 × 처지 압박 × 새로움 × 화자 벌점', () => {
  const on = (seed: string) => { const g = createGame(seed); enableEventPack(g); g.seg = 6; return g; };

  it('처지 압박은 문턱에서 벗어난 거리/20을 더해 1~pressMax로 자른다', () => {
    expect(pressureOf(0.4)).toBe(1);
    expect(pressureOf(2.5)).toBe(2.5);
    expect(pressureOf(99)).toBe(DRAW.pressMax);
    const g = on('ep-press');
    const tail = (g: Game) => situation(g, 'tail')[0];
    // tail_cold: 꼬리칸 따뜻함이 38 이하일 때, 거리 = 38 - 따뜻함
    g.comms.tail.base[0] = 20;
    const w = travelWeight(g, 'tail_cold', []);
    expect(w).toBeCloseTo(pressureOf(1 + (38 - tail(g)) / DRAW.pressDiv), 10);
    expect(w).toBeGreaterThan(1);
    // 더 추우면 더 무겁다(자르는 값까지)
    const colder = cloneGame(g);
    colder.comms.tail.base[0] = Math.max(0, g.comms.tail.base[0] - 10);
    expect(travelWeight(colder, 'tail_cold', [])).toBeGreaterThan(w);
    colder.comms.tail.base[0] = 0;
    expect(travelWeight(colder, 'tail_cold', [])).toBeLessThanOrEqual(DRAW.pressMax);
  });

  it('측선의 탄수차는 기본 무게 tenderBase가 곱해지고, 석탄이 모자랄수록 무겁다', () => {
    const g = on('ep-tender');
    g.coal = 79;
    const near = travelWeight(g, 'abandoned_tender', []);
    expect(near).toBeCloseTo(DRAW.tenderBase * pressureOf(1 + 1 / DRAW.pressDiv), 10);
    g.coal = 5;
    expect(travelWeight(g, 'abandoned_tender', [])).toBe(DRAW.tenderBase * DRAW.pressMax);
    DRAW.tenderBase = 1;
    expect(travelWeight(g, 'abandoned_tender', [])).toBe(DRAW.pressMax);
  });

  it('압박·기본값이 없는 이동 사건은 무게 1', () => {
    const g = on('ep-plain');
    const plain = TRAVEL_EVENTS.find(e => !e.pressure && !e.base)!;
    expect(plain).toBeTruthy();
    expect(travelWeight(g, plain.id, [])).toBe(1);
  });

  it('새로움: 이미 본 횟수 0은 1, 1은 seen1, 2 이상은 seen2', () => {
    expect([noveltyOf(0), noveltyOf(1), noveltyOf(2), noveltyOf(7)]).toEqual([1, DRAW.seen1, DRAW.seen2, DRAW.seen2]);
    const g = on('ep-novel');
    const plain = TRAVEL_EVENTS.find(e => !e.pressure && !e.base)!.id;
    const w0 = travelWeight(g, plain, []);
    g.eventLog[plain] = { n: 1, seg: 1, pick: 'x', st: 'x' };
    expect(travelWeight(g, plain, [])).toBeCloseTo(w0 * DRAW.seen1, 10);
    g.eventLog[plain].n = 2;
    expect(travelWeight(g, plain, [])).toBeCloseTo(w0 * DRAW.seen2, 10);
    g.eventLog[plain].n = 4;
    expect(travelWeight(g, plain, [])).toBeCloseTo(w0 * DRAW.seen2, 10);
  });

  it('화자 벌점: 직전 두 이동 사건 중 같은 칸이 화자면 speakerPenalty를 곱한다', () => {
    const g = on('ep-speaker');
    registerContentEvents([fake('ev_zz_sp', [{ type: 'segment', min: 1, max: 30 }], 'engine')]);
    const id = 'content:ev_zz_sp';
    const base = travelWeight(g, id, []);
    expect(base).toBe(1);
    expect(travelWeight(g, id, ['guard' as Comm, undefined])).toBe(base);
    expect(travelWeight(g, id, ['guard' as Comm, 'engine'])).toBe(base * DRAW.speakerPenalty);
    expect(travelWeight(g, id, [undefined])).toBe(base);
  });

  it('콘텐츠 사건의 압박은 community 조건의 lt·lte·gt·gte 거리 중 가장 큰 값이고, eq와 다른 조건은 안 센다', () => {
    const g = on('ep-content');
    const t = situation(g, 'tail');
    const e = situation(g, 'engine');
    registerContentEvents([
      fake('ev_zz_none', [{ type: 'segment', min: 1, max: 30 }]),
      fake('ev_zz_lte', [{ type: 'community', community: 'tail', metric: 'warmth', operator: 'lte', value: t[0] + 30 }]),
      fake('ev_zz_gte', [{ type: 'community', community: 'engine', metric: 'crowding', operator: 'gte', value: e[2] - 10 }], 'engine'),
      fake('ev_zz_two', [
        { type: 'community', community: 'tail', metric: 'warmth', operator: 'lt', value: t[0] + 10 },
        { type: 'community', community: 'engine', metric: 'crowding', operator: 'gt', value: e[2] - 30 },
      ]),
      fake('ev_zz_eq', [{ type: 'community', community: 'tail', metric: 'warmth', operator: 'eq', value: t[0] }]),
    ]);
    expect(contentDrawInfo(g, 'ev_zz_none')).toEqual({ pressure: 1, comm: 'tail' });
    expect(contentDrawInfo(g, 'ev_zz_lte').pressure).toBeCloseTo(1 + 30 / DRAW.pressDiv, 10);
    expect(contentDrawInfo(g, 'ev_zz_gte')).toEqual({ pressure: 1 + 10 / DRAW.pressDiv, comm: 'engine' });
    expect(contentDrawInfo(g, 'ev_zz_two').pressure).toBeCloseTo(1 + 30 / DRAW.pressDiv, 10);
    expect(contentDrawInfo(g, 'ev_zz_eq').pressure).toBe(1);
    expect(contentDrawInfo(g, 'ev_zz_missing')).toEqual({ pressure: 1 });
    // travelWeight가 같은 값을 쓴다(자르기 포함)
    expect(travelWeight(g, 'content:ev_zz_lte', [])).toBeCloseTo(pressureOf(1 + 30 / DRAW.pressDiv), 10);
    DRAW.pressMax = 1.2;
    expect(travelWeight(g, 'content:ev_zz_lte', [])).toBe(1.2);
  });

  it('실제 묶음 사건(frost_bird: 꼬리칸 따뜻함 55 이하)의 압박이 처지에서 나온다', () => {
    const g = on('ep-real');
    g.seg = 6;
    g.comms.tail.base[0] = 20;
    const v = situation(g, 'tail')[0];
    expect(contentDrawInfo(g, 'ev_b01_frost_bird')).toEqual({ pressure: 1 + (55 - v) / DRAW.pressDiv, comm: 'tail' });
  });

  it('난수를 한 번만 쓰고, 뽑힌 비율이 무게 비율을 따른다', () => {
    const base = on('ep-freq');
    closeTravelEvents(base);
    const t = situation(base, 'tail')[0];
    // heavy: 거리 40 → 무게 3, light: 조건 없음 → 무게 1. 기대 비율 0.75
    registerContentEvents([
      fake('ev_zz_heavy', [{ type: 'community', community: 'tail', metric: 'warmth', operator: 'lte', value: t + 40 }], 'engine'),
      fake('ev_zz_light', [{ type: 'segment', min: 1, max: 30 }], 'engine'),
    ]);
    const extra = ['content:ev_zz_heavy', 'content:ev_zz_light'];
    expect(travelWeight(base, extra[0], [])).toBeCloseTo(3, 10);
    let heavy = 0;
    const N = 3000;
    for (let i = 0; i < N; i += 1) {
      const g = cloneGame(base);
      g.rng = createGame(`ep-freq-${i}`).rng;
      const ref = cloneGame(g);
      rnd(ref);
      if (drawTravelEvent(g, extra) === extra[0]) heavy += 1;
      expect(g.rng).toEqual(ref.rng);
    }
    expect(heavy / N).toBeGreaterThan(0.75 - 0.04);
    expect(heavy / N).toBeLessThan(0.75 + 0.04);
  });

  it('최근 화자가 같은 칸이면 덜 뽑힌다(직전 사건이 engine이 화자인 경우)', () => {
    const base = on('ep-recent');
    closeTravelEvents(base);
    registerContentEvents([
      fake('ev_zz_e', [{ type: 'segment', min: 1, max: 30 }], 'engine'),
      fake('ev_zz_t', [{ type: 'segment', min: 1, max: 30 }], 'tail'),
      fake('ev_zz_prev', [{ type: 'segment', min: 1, max: 30 }], 'engine'),
    ]);
    base.recentEvents = ['content:ev_zz_prev'];
    const extra = ['content:ev_zz_e', 'content:ev_zz_t'];
    let e = 0;
    const N = 3000;
    for (let i = 0; i < N; i += 1) {
      const g = cloneGame(base);
      g.rng = createGame(`ep-recent-${i}`).rng;
      if (drawTravelEvent(g, extra) === extra[0]) e += 1;
    }
    const expected = DRAW.speakerPenalty / (DRAW.speakerPenalty + 1); // 1/3
    expect(e / N).toBeGreaterThan(expected - 0.04);
    expect(e / N).toBeLessThan(expected + 0.04);
  });
});

describe('저장·복원', () => {
  it('켠 판의 eventPack이 JSON 저장을 거쳐 남고, 복원한 판에서도 가중 뽑기를 쓴다', () => {
    const g = createGame('ep-save');
    enableEventPack(g);
    const copy = cloneGame(g);
    expect(copy.eventPack).toBe(true);
    const r = readSave(JSON.parse(JSON.stringify(copy)));
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(r.g.eventPack).toBe(true);
    expect(eventPackOn(r.g)).toBe(true);
    r.g.seg = 6;
    expect(packIds(r.g).length).toBeGreaterThan(0);
  });

  it('끈 판은 저장·복원을 거쳐도 eventPack이 생기지 않는다', () => {
    const r = readSave(JSON.parse(JSON.stringify(cloneGame(createGame('ep-save-off')))));
    expect(r.ok).toBe(true);
    if (r.ok) { expect('eventPack' in r.g).toBe(false); r.g.seg = 6; expect(packIds(r.g)).toEqual([]); }
  });

  it('끝까지 돌린 켠 판의 저장본이 eventPack을 가진다', () => {
    const { g } = playGame('ep-save-play', { s1c: true, policy: 'caretaker', dom: 'engaged', eventPack: true });
    const r = readSave(JSON.parse(JSON.stringify(g)));
    expect(r.ok && r.g.eventPack).toBe(true);
  });
});
