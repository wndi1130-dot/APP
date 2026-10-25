import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { CONTENT_EVENTS, contentPool, createGame, enableClimate, enableEventPack, rowAt, SEASON_ROWS, seasonHolds, TRAVEL_EVENTS } from '../../src/game';
import type { DisasterState, Game, Weather } from '../../src/game';
import { loadContentEvents } from '../../tools/content_fs';

// 사건의 눈·얼음 조건이 계절표를 읽는다(코디네이터 10-25 차례 1, 계절표 night_freeze·snow 칸).
// 기온 꺼진 판은 늘 참이라 옛 판(늘 겨울)과 골든은 그대로다. 켠 판은 서막 3~16구간(늦가을)에 얼음·눈 사건이 안 뜬다.

beforeEach(() => { CONTENT_EVENTS.length = 0; loadContentEvents(); });
afterEach(() => { CONTENT_EVENTS.length = 0; });

const FROST = ['ev_b01_frozen_switch', 'ev_b01_window_ice', 'ev_h02_burst_crates', 'ev_h03_roof_ice', 'ev_h06_split_pipe', 'ev_b01_frost_bird'];
const SNOW = ['ev_h08_white_wind', 'ev_str_snow'];
// 늦가을 선로 시련(결정 447 카드 2): 젖은 낙엽, 불어난 개울, 젖은 석탄, 새는 지붕, 안개 속 신호
const BARE = ['ev_h13_wet_leaves', 'ev_h14_swollen_creek', 'ev_h15_wet_coal', 'ev_h16_leaking_roof', 'ev_h17_fog_signal'];

function at(seg: number, on: boolean, weather?: Weather): Game {
  const g = createGame(`season-ev-${seg}`);
  if (on) enableClimate(g);
  enableEventPack(g);
  g.seg = seg;
  if (weather) g.lastStop = { ...(g.stop ?? {}), weather } as Game['lastStop'];
  return g;
}

const travel = (id: string) => TRAVEL_EVENTS.find(e => e.id === id)!;

describe('seasonHolds: 계절표 칸', () => {
  it('기온 꺼진 판은 모든 구간에서 참이다', () => {
    for (let seg = 1; seg <= SEASON_ROWS.length; seg += 1) {
      const g = at(seg, false);
      expect(seasonHolds(g, 'frost')).toBe(true);
      expect(seasonHolds(g, 'snow')).toBe(true);
    }
  });

  it('켠 판은 그 구간의 night_freeze·snow 칸과 같다(한파·결빙 없을 때)', () => {
    for (let seg = 1; seg <= SEASON_ROWS.length; seg += 1) {
      const g = at(seg, true);
      expect(seasonHolds(g, 'frost'), `${seg}구간 frost`).toBe(rowAt(seg).night_freeze);
      expect(seasonHolds(g, 'snow'), `${seg}구간 snow`).toBe(rowAt(seg).snow);
    }
  });

  it('늦가을 구간이라도 한파가 닥쳤거나 한파 날씨이거나 선로가 얼었으면 얼음이 선다(눈은 아니다)', () => {
    expect(rowAt(5).night_freeze).toBe(false);
    const d = at(5, true);
    d.disasters = true;
    d.disaster = { kind: 'cold', stage: 'active', left: 1 } as DisasterState;
    expect(seasonHolds(d, 'frost')).toBe(true);
    expect(seasonHolds(d, 'snow')).toBe(false);
    expect(seasonHolds(at(5, true, 'cold_front'), 'frost')).toBe(true);
    expect(seasonHolds(at(5, true, 'sleet'), 'frost')).toBe(false);
    const f = at(5, true);
    f.freeze = 1;
    expect(seasonHolds(f, 'frost')).toBe(true);
  });

  it('bare는 얼음도 눈도 없을 때다. 꺼진 판(늘 겨울)은 늘 거짓, 한파·결빙이 닥치면 늦가을에도 거짓', () => {
    for (let seg = 1; seg <= SEASON_ROWS.length; seg += 1) {
      expect(seasonHolds(at(seg, false), 'bare'), `${seg}구간 꺼짐`).toBe(false);
      const row = rowAt(seg);
      expect(seasonHolds(at(seg, true), 'bare'), `${seg}구간`).toBe(!row.night_freeze && !row.snow);
    }
    expect(seasonHolds(at(5, true), 'bare')).toBe(true);
    expect(seasonHolds(at(5, true, 'cold_front'), 'bare')).toBe(false);
    const f = at(5, true);
    f.freeze = 1;
    expect(seasonHolds(f, 'bare')).toBe(false);
  });
});

describe('사건 데이터', () => {
  it('얼음 사건은 frost, 눈 사건은 snow, 늦가을 선로 시련은 bare 조건을 단다', () => {
    for (const [ids, needs] of [[FROST, 'frost'], [SNOW, 'snow'], [BARE, 'bare']] as const) {
      for (const id of ids) {
        const ev = CONTENT_EVENTS.find(e => e.id === id);
        expect(ev, id).toBeDefined();
        expect(ev!.trigger).toContainEqual({ type: 'season', needs });
      }
    }
  });

  it('계절 조건을 단 사건은 기온 켠 서막에서도 뜰 구간이 남는다(구간 범위와 칸이 겹친다)', () => {
    for (const ev of CONTENT_EVENTS) {
      const s = ev.trigger.find(c => c.type === 'season');
      if (!s || s.type !== 'season') continue;
      const range = ev.trigger.find(c => c.type === 'segment');
      const [lo, hi] = range && range.type === 'segment' ? [range.min, range.max] : [1, SEASON_ROWS.length];
      const holds = (r: (typeof SEASON_ROWS)[number]) => s.needs === 'snow' ? r.snow : s.needs === 'bare' ? !r.night_freeze && !r.snow : r.night_freeze;
      const segs = SEASON_ROWS.filter(r => r.seg >= lo && r.seg <= hi && holds(r));
      expect(segs.length, ev.id).toBeGreaterThanOrEqual(3);
    }
  });
});

describe('뽑기', () => {
  it('얼어붙은 분기기는 켠 판 늦가을(5구간)엔 안 들고, 밤 결빙(18구간)엔 든다. 꺼진 판은 5구간에도 든다', () => {
    const ids = (g: Game) => contentPool(g).map(e => e.id);
    expect(ids(at(5, true))).not.toContain('ev_b01_frozen_switch');
    expect(ids(at(18, true))).toContain('ev_b01_frozen_switch');
    expect(ids(at(5, false))).toContain('ev_b01_frozen_switch');
  });

  it('늦가을 선로 시련은 켠 판 늦가을(5구간)에만 든다. 밤 결빙(18구간)과 꺼진 판에는 안 든다', () => {
    const ids = (g: Game) => contentPool(g).map(e => e.id);
    for (const id of BARE) {
      expect(ids(at(5, true)), id).toContain(id);
      expect(ids(at(18, true)), id).not.toContain(id);
      expect(ids(at(5, false)), id).not.toContain(id);
    }
  });

  it('흰 바람은 첫눈 뒤(22구간)에만 든다', () => {
    const ids = (g: Game) => contentPool(g).map(e => e.id);
    expect(ids(at(18, true))).not.toContain('ev_h08_white_wind');
    expect(ids(at(22, true))).toContain('ev_h08_white_wind');
  });

  it('급수탑은 얼음이 서는 구간, 눈더미는 눈이 쌓인 구간에만 후보다. 꺼진 판은 그대로', () => {
    expect(travel('water_tower').when(at(5, true))).toBe(false);
    expect(travel('water_tower').when(at(2, true))).toBe(true);
    expect(travel('water_tower').when(at(17, true))).toBe(true);
    expect(travel('water_tower').when(at(5, false))).toBe(true);
    expect(travel('snow_drift').when(at(18, true))).toBe(false);
    expect(travel('snow_drift').when(at(22, true))).toBe(true);
    expect(travel('snow_drift').when(at(5, false))).toBe(true);
  });

  it('경비대 지붕 보초는 늦가을엔 찬비에 젖고, 얼음이 서는 구간과 꺼진 판에선 동상이다. 값은 같다', () => {
    const view = (g: Game) => travel('guard_frost').view(g, undefined);
    const autumn = view(at(5, true));
    const frost = view(at(18, true));
    expect(autumn.title).toBe('젖은 보초');
    expect(autumn.body).not.toMatch(/동상|영하/u);
    expect(frost.title).toBe('동상');
    expect(view(at(5, false)).title).toBe('동상');
    expect(autumn.choices.map(c => c.effs)).toEqual(frost.choices.map(c => c.effs));
  });
});
