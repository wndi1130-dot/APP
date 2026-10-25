import { afterEach, describe, expect, it } from 'vitest';
import {
  advance, CL, CLIMATE_LINES, climateDepart, climateSettle, COMMS, createGame, disasterSettle, DZ, enableClimate, enableDisasters,
  foodCost, forecast, resolveStop, freezeDepart, freezeTrackBoost, heatCost, outsideView, PLACES, predictStall, rowAt, segTemp, stageAt, tempMult,
} from '../../src/game';
import type { Game, Weather } from '../../src/game';
import { playGame } from '../../tools/s1c_bot';

// 바깥 기온과 결빙(coord fun/구현명세_바깥기온_결빙_v1 5장 1~12, 결정 351·357·370). 값은 가안이라 CL을 바꾼 시험은 끝날 때 되돌린다.
// 계절표는 season_table.json 한 벌(서막 (나)): 1~2구간 이른 한파(첫 추위), 3구간부터 늦가을, 17구간부터 다시 첫 추위.

const CL0 = structuredClone(CL);
const DZ0 = { ...DZ };
afterEach(() => { Object.assign(CL, structuredClone(CL0)); Object.assign(DZ, DZ0); });

const warmth = (g: Game) => COMMS.map(c => g.comms[c].base[0]);
const texts = (g: Game) => g.journal.map(j => j.text);

/** 기온 켠 판을 seg 구간 출발 직전(prep)에 세운다. outside는 그 구간 앞의 적용 단계. weather는 떠나는 정차(lastStop)의 날씨 */
function at(seed: string, seg: number, weather?: Weather, on = true): Game {
  const g = createGame(seed);
  if (on) enableClimate(g);
  g.seg = seg;
  if (on) g.outside = stageAt(seg - 1);
  g.phase = 'prep';
  g.cards = [];
  if (weather) g.lastStop = { weather } as Game['lastStop'];
  return g;
}

/** 출발 한 번(advance가 depart를 부른다) */
function go(g: Game): void {
  advance(g);
  expect(g.phase).toBe('travel');
}

describe('climate', () => {
  it('1 끈 판은 heatCost·forecast·일지가 지금과 같고 기온 함수는 아무것도 안 한다', () => {
    const a = createGame('cl-off');
    const b = createGame('cl-off');
    expect(heatCost(a)).toBe(heatCost(b));
    expect(tempMult(a)).toBe(1);
    expect(outsideView(a)).toBeNull();
    expect(climateDepart(a)).toBeNull();
    climateSettle(a);
    expect('climate' in a || 'outside' in a || 'freeze' in a).toBe(false);
    // 끈 판의 6구간 출발은 정기 한파 그대로
    const w = at('cl-off-6', 6, undefined, false);
    const before = warmth(w);
    go(w);
    expect(warmth(w)).toEqual(before.map(x => x - 5));
    expect(texts(w)).toContain('추위가 한 단계 깊어졌다. 모든 칸 온기 −5.');
    expect(texts(w).some(t => CLIMATE_LINES.includes(t))).toBe(false);
  });

  it('2 stageAt은 계절표대로 3·17구간에서만 바뀌고 씨앗과 무관하다', () => {
    const seq = Array.from({ length: 24 }, (_, i) => stageAt(i + 1));
    expect(seq).toEqual([1, 1, ...Array(14).fill(0), ...Array(8).fill(1)]);
    const changes = seq.map((s, i) => (i > 0 && s !== seq[i - 1] ? i + 1 : 0)).filter(Boolean);
    expect(changes).toEqual([3, 17]);
    // 서막의 표시 기온: 이른 한파는 영하, 늦가을 낮은 영상, 첫 구간 끝은 다시 영하
    expect(segTemp(1)).toBeLessThan(0);
    for (let seg = 3; seg <= 16; seg += 1) expect(segTemp(seg), `seg ${seg}`).toBeGreaterThan(0);
    expect(segTemp(24)).toBeLessThan(0);
    expect(segTemp(99)).toBe(segTemp(24));
    for (const seed of ['cl-s1', 'cl-s2']) {
      const g = createGame(seed);
      enableClimate(g);
      expect(g.outside).toBe(1);
    }
  });

  it('3 tempMult는 단계마다 약안 곱이고, heatCost에 한 번만 들어 forecast·predictStall이 그대로 따른다', () => {
    expect(CL.mult).toEqual([0.8, 0.9, 1, 1.1, 1.25, 1.4]);
    const g = createGame('cl-mult');
    enableClimate(g);
    g.outside = 2;
    const base = heatCost(g);
    const f1 = forecast(g).coal;
    for (let st = 0; st < CL.mult.length; st += 1) {
      g.outside = st;
      expect(tempMult(g)).toBe(CL.mult[st]);
      expect(heatCost(g)).toBeCloseTo(base * CL.mult[st], 9);
      expect(forecast(g).coal - f1).toBeCloseTo(base * (CL.mult[st] - 1), 9);
    }
    // 석탄이 모자라면 predictStall이 같은 forecast로 판단한다(곱을 두 번 넣지 않는다)
    g.outside = 2;
    const need1 = forecast(g).coal;
    g.outside = 5;
    g.coal = (need1 + forecast(g).coal) / 2;
    expect(predictStall(g)).not.toBeNull();
    g.outside = 2;
    expect(predictStall(g)).toBeNull();
  });

  it('4 하강 전 정차까지 다음 하강이 새지 않는다(예고 없음)', () => {
    const g = at('cl-quiet', 17);
    const fBefore = forecast(g).coal;
    // 17구간 출발 직전: 적용 단계는 아직 늦가을(0), 석탄 예고도 늦가을 값
    expect(g.outside).toBe(0);
    expect(tempMult(g)).toBe(0.8);
    const v = outsideView(g)!;
    expect(Object.keys(v).sort()).toEqual(['delta', 'freezing', 'name', 'stage', 'temp']);
    expect(v).toMatchObject({ stage: 0, name: '늦가을', delta: null, freezing: false });
    // 기온 켠 판을 한 판 돌려도 일지에 앞날 낱말이나 다음 단계 이름이 미리 나오지 않는다
    const { g: p } = playGame('cl-quiet-play', { s1c: false, policy: 'caretaker', dom: 'idle', climate: true });
    const cl = p.journal.filter(j => CLIMATE_LINES.includes(j.text) || j.text.startsWith('바깥 '));
    for (const j of cl) expect(j.text).not.toMatch(/곧|내일|다음|머지않아|앞으로/);
    expect(forecast(g).coal).toBe(fBefore);
  });

  it('5 하강 출발은 모든 칸 온기를 단계 차×5만큼 옮기고, 기온 켠 판에는 정기 한파 줄이 없다', () => {
    for (const [seg, diff] of [[3, -1], [17, 1]] as const) {
      const g = at(`cl-warm-${seg}`, seg);
      const before = warmth(g);
      go(g);
      expect(warmth(g), `seg ${seg}`).toEqual(before.map(x => x - 5 * diff));
      expect(g.outside).toBe(stageAt(seg));
    }
    for (const seg of [6, 12, 18, 24]) {
      const g = at(`cl-nowinter-${seg}`, seg);
      go(g);
      expect(texts(g)).not.toContain('추위가 한 단계 깊어졌다. 모든 칸 온기 −5.');
    }
  });

  it('6 단계가 바뀐 출발에만 글 한 줄과 수 한 줄이 남고, 연달은 두 글의 인칭이 다르다', () => {
    const same = at('cl-lines-0', 6);
    const n0 = same.journal.length;
    go(same);
    expect(same.journal.slice(n0).some(j => CLIMATE_LINES.includes(j.text) || j.text.startsWith('바깥 '))).toBe(false);
    const g = at('cl-lines-17', 17);
    const n = g.journal.length;
    go(g);
    const fresh = g.journal.slice(n);
    const i = fresh.findIndex(j => CLIMATE_LINES.includes(j.text));
    expect(i).toBeGreaterThanOrEqual(0);
    expect(fresh[i + 1].text).toBe('바깥 0°. 모든 칸 온기 −5, 난방 석탄 ×0.9.');
    expect(fresh[i].tone).toBe('bad');
    const up = at('cl-lines-3', 3);
    go(up);
    expect(texts(up)).toContain('바깥 5°. 모든 칸 온기 +5, 난방 석탄 ×0.8.');
    // 한 판 안에서 날씨 글의 인칭이 번갈아 든다(CLIMATE_LINES는 [1인칭, 3인칭] 쌍을 이어 붙인 것)
    const { g: p } = playGame('cl-voice', { s1c: false, policy: 'caretaker', dom: 'idle', climate: true });
    const voices = p.journal.filter(j => CLIMATE_LINES.includes(j.text)).map(j => CLIMATE_LINES.indexOf(j.text) % 2);
    expect(voices.length).toBeGreaterThanOrEqual(3);
    for (let k = 1; k < voices.length; k += 1) expect(voices[k]).not.toBe(voices[k - 1]);
  });

  it('7 결빙 참: 진눈깨비 정차에서 하강, 젖은 단계(늦가을)에서 하강, 진눈깨비 정차에서 한파가 닥침', () => {
    CL.table = [[1, 1], [5, 2]]; // 젖지 않은 단계끼리의 하강을 만든다(진눈깨비 정차라서 언다)
    const a = at('cl-fz-a', 5, 'sleet');
    go(a);
    expect(a.freeze).toBe(1);
    expect(texts(a)).toContain('선로 결빙: 석탄 +1, 식량 +반나절.');
    CL.table = structuredClone(CL0.table);
    const b = at('cl-fz-b', 17, 'snow'); // 늦가을(0, 젖음)에서 떠나 첫 추위(1)로: 늘 언다
    go(b);
    expect(b.freeze).toBe(1);
    // 진눈깨비 정차, 단계는 그대로인데 재난 한파가 이번 출발에 닥친다
    DZ.blizzardP = 0; DZ.coldP = 1; DZ.lead = 1;
    const c = at('cl-fz-c', 7, 'sleet');
    enableDisasters(c);
    c.seg = 6;
    disasterSettle(c);
    c.seg = 7;
    expect(c.disaster).toMatchObject({ kind: 'cold', stage: 'warn' });
    c.cards = [];
    go(c);
    expect(c.disaster?.stage).toBe('active');
    expect(c.freeze).toBe(1);
    expect(c.climateStats!.freezes).toBe(1);
  });

  it('8 결빙 거짓: 젖지 않은 정차에서 하강, 진눈깨비인데 하강·한파 없음, 오르는 출발', () => {
    CL.table = [[1, 1], [5, 2]]; // 젖지 않은 단계(첫 추위)에서 추위로
    for (const w of ['snow', 'fog', 'overcast', 'clear'] as Weather[]) {
      const g = at(`cl-nofz-${w}`, 5, w);
      go(g);
      expect(g.freeze, w).toBe(0);
    }
    CL.table = structuredClone(CL0.table);
    const flat = at('cl-nofz-flat', 7, 'sleet');
    go(flat);
    expect(flat.freeze).toBe(0);
    const up = at('cl-nofz-up', 3, 'sleet');
    go(up);
    expect(up.freeze).toBe(0);
    // 결빙만 끄는 스위치(500판 D줄)
    CL.freezeOn = 0;
    const off = at('cl-nofz-off', 17, 'sleet');
    go(off);
    expect(off.freeze).toBe(0);
    // freezeDepart는 바뀜 정보가 없으면(꺼진 판) 아무것도 안 한다
    const plain = createGame('cl-nofz-plain');
    freezeDepart(plain, null, true);
    expect('freeze' in plain).toBe(false);
  });

  it('9 결빙 구간 forecast: 석탄 +1·식량 +foodCost×0.5, 한파와 겹치면 석탄 +2, 정산 장부에 결빙 줄', () => {
    const g = createGame('cl-fc');
    enableClimate(g);
    const f0 = forecast(g);
    g.freeze = 1;
    const f1 = forecast(g);
    expect(f1.coal - f0.coal).toBeCloseTo(1, 9);
    expect(f1.food - f0.food).toBeCloseTo(foodCost(g) * 0.5, 9);
    enableDisasters(g);
    g.disaster = { kind: 'cold', stage: 'active', left: 2 };
    expect(forecast(g).coal - f0.coal).toBeCloseTo(2, 9);
    // 정산이 결빙 몫을 장부에 '결빙' 까닭으로 적는다
    const s = at('cl-ledger', 17, 'sleet');
    go(s);
    expect(s.freeze).toBe(1);
    for (let guard = 0; guard < 50 && s.phase !== 'settle'; guard += 1) {
      if (s.cards.length) s.cards = [];
      if (s.phase === 'stop' && s.stop && !s.stop.done) resolveStop(s, false);
      else advance(s);
    }
    expect(s.phase).toBe('settle');
    expect((s.ledger ?? []).some(r => r.k === 'coal' && r.why === 'freeze')).toBe(true);
    expect((s.ledger ?? []).some(r => r.k === 'food' && r.why === 'freeze')).toBe(true);
  });

  it('10 결빙 구간 이동 사건 후보에 급수탑·눈더미가 두 번 들고, 정산 뒤 결빙 끝 글과 함께 한 번으로 돌아온다', () => {
    const g = createGame('cl-track');
    enableClimate(g);
    const pool = ['water_tower', 'snow_drift', 'other'];
    expect(freezeTrackBoost(g, pool)).toEqual(pool);
    g.freeze = 1;
    const boosted = freezeTrackBoost(g, pool);
    expect(boosted.filter(id => id === 'water_tower')).toHaveLength(2);
    expect(boosted.filter(id => id === 'snow_drift')).toHaveLength(2);
    expect(boosted.filter(id => id === 'other')).toHaveLength(1);
    // 쿨다운 따위로 후보에 없던 것은 넣지 않는다
    expect(freezeTrackBoost(g, ['other'])).toEqual(['other']);
    climateSettle(g);
    expect(g.freeze).toBe(0);
    expect(CLIMATE_LINES).toContain(g.journal.at(-1)!.text);
    expect(g.journal.at(-1)!.tone).toBe('good');
    expect(freezeTrackBoost(g, pool)).toEqual(pool);
  });

  it('11 기온 켬·끔에서 눈보라 두 단계 예고 글과 정산이 같다(결정 338 그대로). 서막엔 계절표가 눈보라를 막는다', () => {
    DZ.blizzardP = 1; DZ.coldP = 0; DZ.lead = 2;
    // 계절표가 눈보라를 허락하는 구간이면(서막 다음 막) 기온 켠 판도 같은 두 단계 예고를 낸다. 서막 줄 하나를 잠시 허락으로 바꿔 본다.
    const row = rowAt(DZ.fromSeg + DZ.lead);
    const runBlocked = (() => {
      const g = createGame('cl-dz');
      enableDisasters(g);
      enableClimate(g);
      g.seg = DZ.fromSeg;
      disasterSettle(g);
      return g.disaster;
    })();
    expect(runBlocked).toBeUndefined();
    row.blizzard = true;
    const run = (on: boolean) => {
      const g = createGame('cl-dz');
      enableDisasters(g);
      if (on) enableClimate(g);
      g.seg = DZ.fromSeg;
      disasterSettle(g);
      const a = { ...g.disaster };
      g.seg += 1;
      disasterSettle(g);
      return { a, b: { ...g.disaster }, lines: g.journal.map(j => j.text), cards: g.cards.map(c => c.kind) };
    };
    try {
      expect(run(true)).toEqual(run(false));
    } finally {
      row.blizzard = false;
    }
  });

  it('12 저장 뒤 불러와도 기온 칸이 같고, 날씨 글에 장소 이름이 없다', () => {
    const g = at('cl-save', 17, 'sleet');
    go(g);
    const back = JSON.parse(JSON.stringify(g)) as Game;
    expect([back.climate, back.outside, back.freeze, back.climateChange, back.climateVoice, back.climateStats])
      .toEqual([g.climate, g.outside, g.freeze, g.climateChange, g.climateVoice, g.climateStats]);
    expect(outsideView(back)).toEqual(outsideView(g));
    const names = PLACES.map(p => p.name);
    for (const t of CLIMATE_LINES) for (const n of names) expect(t.includes(n), `${t} / ${n}`).toBe(false);
  });
});
