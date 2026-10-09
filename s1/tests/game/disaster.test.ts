import { afterEach, describe, expect, it } from 'vitest';
import {
  advance, chooseCard, cloneGame, COMMS, createGame, disasterDepart, disasterSettle, DZ, enableDisasters, forecast, P, PROFILES, riskView, viewCard,
} from '../../src/game';
import type { Game } from '../../src/game';
import { readSave } from '../../src/ui/repro';
import { playGame } from '../../tools/s1c_bot';

// 재난 시제품(disaster.ts, events_disasters 4장 D1 눈보라, D2 한파). 기본 꺼짐, 켜면 예고 -> 대비 카드 -> 이어짐 -> 끝.
// 온기 감소는 active 동안만이고 끝나면 돌려준다. 정기 한파는 켠 판에서도 돈다.

const DZ0 = { ...DZ };
afterEach(() => { Object.assign(DZ, DZ0); });

const warmth = (g: Game) => COMMS.map(c => g.comms[c].base[0]);
const crowd = (g: Game) => COMMS.map(c => g.comms[c].base[2]);

function warned(seed: string, kind: 'blizzard' | 'cold' = 'blizzard'): Game {
  const g = createGame(seed);
  enableDisasters(g);
  g.seg = 4;
  g.disaster = { kind, stage: 'warn', left: 0 };
  return g;
}
function active(seed: string, kind: 'blizzard' | 'cold', extra: Partial<NonNullable<Game['disaster']>> = {}): Game {
  const g = createGame(seed);
  enableDisasters(g);
  g.seg = 5;
  g.disaster = { kind, stage: 'active', left: kind === 'blizzard' ? 2 : 3, warmDrop: 0, ...extra };
  return g;
}

describe('재난 꺼짐', () => {
  it('끈 판에는 재난 상태도 통계도 일지도 카드도 없다', () => {
    DZ.blizzardP = 1; DZ.coldP = 1;
    for (const seed of ['dz-off-0', 'dz-off-1', 'dz-off-2']) {
      const { g, m } = playGame(seed, { s1c: false, policy: 'caretaker', dom: 'idle' });
      expect(g.disasters).toBeUndefined();
      expect(g.disaster).toBeUndefined();
      expect(g.disasterStats).toBeUndefined();
      expect(g.disasterEnd).toBeUndefined();
      expect(g.disasterDeaths).toBeUndefined();
      expect(g.journal.some(j => /눈보라|한파가|찬 공기|예고를 듣고도/.test(j.text))).toBe(false);
      expect(m.cards.disaster_prep).toBeUndefined();
    }
  });

  it('끈 판은 6구간마다 정기 한파로 모든 칸 온기가 −5 된다(지금 동작 그대로)', () => {
    const g = createGame('dz-winter');
    g.seg = P.winterEvery;
    const before = warmth(g);
    advance(g);
    expect(warmth(g)).toEqual(before.map(w => w - P.winterDrop));
  });
});

describe('재난 켜짐: 흐름', () => {
  it('예고 -> 출발에 active -> left 만큼 이어짐 -> 끝, 눈보라는 2구간', () => {
    DZ.blizzardP = 1; DZ.coldP = 0;
    const { g } = playGame('dz-order', { s1c: false, policy: 'caretaker', dom: 'idle', disasters: true });
    const log = g.journal.filter(j => /서쪽 하늘이 낮다|눈보라가 시작됐다|눈보라가 그쳤다/.test(j.text));
    expect(log.length).toBeGreaterThanOrEqual(3);
    const s = log[0].seg;
    expect(log[0].text).toBe('기관장: 서쪽 하늘이 낮다. 내일은 눈보라다.');
    expect(s).toBe(DZ.fromSeg);
    expect(log.slice(1, 3).map(j => [j.seg, j.text.slice(0, 6)])).toEqual([[s + 1, '눈보라가 시'], [s + 2, '눈보라가 그']]);
    const next = log.find((j, i) => i >= 3 && j.text.includes('서쪽 하늘'));
    if (next) expect(next.seg - (s + 2)).toBeGreaterThanOrEqual(DZ.gap);
    expect(g.disasterStats!.blizzard).toBeGreaterThanOrEqual(1);
    expect(g.disasterStats!.cold).toBe(0);
  });

  it('한파는 3구간 이어지고 그치면 상태가 사라진다', () => {
    DZ.blizzardP = 0; DZ.coldP = 1;
    const { g } = playGame('dz-cold', { s1c: false, policy: 'caretaker', dom: 'idle', disasters: true });
    const log = g.journal.filter(j => /북쪽에서 찬 공기|한파가 시작됐다|한파가 물러났다/.test(j.text));
    const s = log[0].seg;
    expect(log[0].text).toBe('무전: 북쪽에서 찬 공기가 내려온다.');
    expect(log.slice(1, 3).map(j => [j.seg, j.text.slice(0, 5)])).toEqual([[s + 1, '한파가 시'], [s + 3, '한파가 물']]);
  });

  it('정기 한파는 재난을 켠 판에서도 돈다', () => {
    const g = createGame('dz-winter-on');
    enableDisasters(g);
    g.seg = P.winterEvery;
    const before = warmth(g);
    advance(g);
    expect(warmth(g)).toEqual(before.map(w => w - P.winterDrop));
    expect(g.journal.some(j => j.text.startsWith('추위가 한 단계 깊어졌다'))).toBe(true);
  });

  it('온기: active가 되면 눈보라 −5, 한파 −8을 모든 칸에서 빼고, 끝나면 같은 양을 돌려준다(정기 한파와 섞이지 않는다)', () => {
    for (const [kind, drop, len] of [['blizzard', 5, 2], ['cold', 8, 3]] as const) {
      const g = createGame(`dz-warm-${kind}`);
      enableDisasters(g);
      g.seg = P.winterEvery; // 정기 한파가 겹치는 구간
      g.disaster = { kind, stage: 'warn', left: 0, unprepared: true };
      const before = warmth(g);
      advance(g); // 출발
      expect(g.disaster).toMatchObject({ kind, stage: 'active', left: len, warmDrop: drop });
      expect(warmth(g)).toEqual(before.map(w => w - P.winterDrop - drop));
      // 이어지는 동안은 더 깎지 않고, 끝나는 정산에서 재난 몫만 돌려준다
      DZ.deathP = 0;
      for (let i = 0; i < len; i += 1) { expect(g.disaster?.stage).toBe('active'); disasterSettle(g); }
      expect(g.disaster).toBeUndefined();
      expect(g.disasterEnd).toBe(g.seg);
      expect(warmth(g)).toEqual(before.map(w => w - P.winterDrop));
      expect(g.journal.some(j => j.text === (kind === 'blizzard' ? '눈보라가 그쳤다.' : '한파가 물러났다.'))).toBe(true);
    }
  });

  it('석탄: active 구간마다 눈보라 +1, 한파 +1이 더 들고, 석탄을 쌓아 뒀으면 면제', () => {
    const base = forecast(createGame('dz-coal')).coal;
    expect(forecast(active('dz-coal', 'blizzard')).coal).toBeCloseTo(base + DZ.blizzardCoal, 10);
    expect(forecast(active('dz-coal', 'cold')).coal).toBeCloseTo(base + DZ.coldCoal, 10);
    const off = createGame('dz-coal');
    expect(forecast(off).coal).toBe(base);
    expect(forecast(active('dz-coal', 'cold', { prep: 'coal' })).coal).toBe(base);
    expect(forecast(active('dz-coal', 'blizzard', { prep: 'huddle' })).coal).toBeCloseTo(base + DZ.blizzardCoal, 10);
    expect(DZ.blizzardCoal).toBe(1);
    expect(DZ.coldCoal).toBe(1);
    expect(DZ.prepCoal).toBe(2);
  });

  it('눈보라 active 동안 정차 위험 보기는 모른다, 한파나 평소엔 정찰 결과가 보인다', () => {
    const g = createGame('dz-risk');
    enableDisasters(g);
    g.phase = 'stop';
    g.stop = { place: 'depot', target: 'food', stay: 'normal', crewComm: 'tail', crewSize: 4, scout: true, threat: 1, done: false, result: null };
    expect(riskView(g).level).not.toBeNull();
    g.disaster = { kind: 'cold', stage: 'active', left: 2 };
    expect(riskView(g).level).not.toBeNull();
    g.disaster = { kind: 'blizzard', stage: 'warn', left: 0 };
    expect(riskView(g).level).not.toBeNull();
    g.disaster = { kind: 'blizzard', stage: 'active', left: 2 };
    const v = riskView(g);
    expect(v.level).toBeNull();
    expect(v.unknown).toBe('눈 때문에 안쪽을 볼 수 없다.');
  });

  it('재난 상태는 저장·복원에 그대로 들어간다', () => {
    const g = active('dz-save', 'cold', { prep: 'coal', warmDrop: 4, died: true });
    g.disasterStats = { blizzard: 1, cold: 2 };
    g.disasterEnd = 4;
    g.disasterDeaths = 1;
    const r = readSave(JSON.parse(JSON.stringify(cloneGame(g))));
    expect(r.ok).toBe(true);
    if (r.ok) {
      expect(r.g.disaster).toEqual({ kind: 'cold', stage: 'active', left: 3, prep: 'coal', warmDrop: 4, died: true });
      expect([r.g.disasters, r.g.disasterStats, r.g.disasterEnd, r.g.disasterDeaths]).toEqual([true, { blizzard: 1, cold: 2 }, 4, 1]);
    }
  });
});

describe('재난 대비 카드', () => {
  function withCard(seed: string, kind: 'blizzard' | 'cold' = 'blizzard') {
    DZ.blizzardP = kind === 'blizzard' ? 1 : 0; DZ.coldP = kind === 'cold' ? 1 : 0;
    const g = createGame(seed);
    enableDisasters(g);
    g.seg = 3;
    disasterSettle(g); // 예고를 굴린다
    expect(g.disaster?.stage).toBe('warn');
    const card = g.cards.find(c => c.kind === 'disaster_prep')!;
    expect(card).toBeTruthy();
    return { g, card };
  }

  it('예고에 카드가 하나 오고, 세 선택지가 보인다', () => {
    const { g, card } = withCard('dz-card');
    const v = viewCard(g, card);
    expect(v.required).toBe(true);
    expect(v.choices.map(c => c.label)).toEqual(['석탄을 쌓아 둔다', '칸을 모아 잔다', '그냥 간다']);
    expect(g.cards.filter(c => c.kind === 'disaster_prep')).toHaveLength(1);
  });

  it('석탄을 쌓아 둔다: 석탄 −2, 재난 석탄 면제, 온기 감소 절반, 안 죽는다', () => {
    const { g, card } = withCard('dz-card-coal');
    const coal = g.coal;
    expect(chooseCard(g, card.uid, 0)).toBe(true);
    expect(g.coal).toBe(coal - DZ.prepCoal);
    expect(g.disaster).toMatchObject({ prep: 'coal' });
    expect(g.disaster?.unprepared).toBeUndefined();
    expect(forecast(g).coal).toBe(forecast(createGame('dz-card-coal')).coal);
    const before = warmth(g);
    disasterDepart(g);
    expect(warmth(g)).toEqual(before.map(w => w - DZ.blizzardWarm / 2));
    DZ.deathP = 1;
    for (let i = 0; i < 2; i += 1) disasterSettle(g);
    expect(g.deaths).toEqual([]);
  });

  it('칸을 모아 잔다: 꼬리칸·앞칸 과밀 +10, 긴장 +2, 온기 감소 절반, 재난이 끝나면 과밀이 돌아온다', () => {
    const { g, card } = withCard('dz-card-huddle', 'cold');
    const cr = crowd(g);
    const tension = g.tension;
    expect(chooseCard(g, card.uid, 1)).toBe(true);
    expect(g.disaster).toMatchObject({ prep: 'huddle' });
    expect(g.tension).toBe(tension + DZ.huddleTension);
    expect(forecast(g).coal).toBeCloseTo(forecast(createGame('dz-card-huddle')).coal + DZ.coldCoal, 10);
    expect(crowd(g)).toEqual(COMMS.map((c, i) => cr[i] + (c === 'tail' || c === 'front' ? DZ.huddleCrowd : 0)));
    const before = warmth(g);
    disasterDepart(g);
    expect(warmth(g)).toEqual(before.map(w => w - DZ.coldWarm / 2));
    expect((g.tempBase ?? []).filter(t => t.i === 2 && t.v === DZ.huddleCrowd).map(t => t.c).sort()).toEqual(['front', 'tail']);
    expect((g.tempBase ?? []).every(t => t.until === g.seg + DZ.coldLen)).toBe(true);
  });

  it('그냥 간다: 값 없음, unprepared, 온기는 전부 깎인다', () => {
    const { g, card } = withCard('dz-card-none');
    const coal = g.coal, tension = g.tension, cr = crowd(g);
    expect(chooseCard(g, card.uid, 2)).toBe(true);
    expect(g.disaster?.unprepared).toBe(true);
    expect([g.coal, g.tension, crowd(g)]).toEqual([coal, tension, cr]);
    const before = warmth(g);
    disasterDepart(g);
    expect(warmth(g)).toEqual(before.map(w => w - DZ.blizzardWarm));
  });

  it('카드를 안 고르고 출발하면 대비하지 않은 것이고, 카드는 사라진다', () => {
    const { g } = withCard('dz-card-skip');
    disasterDepart(g);
    expect(g.disaster?.unprepared).toBe(true);
    expect(g.cards.some(c => c.kind === 'disaster_prep')).toBe(false);
  });

  it('끈 판에선 예고가 와도 카드가 오지 않는다(상태가 없다)', () => {
    const g = createGame('dz-card-off');
    g.seg = 3;
    disasterSettle(g);
    expect(g.cards).toEqual([]);
    expect(g.disaster).toBeUndefined();
  });
});

describe('재난 사망', () => {
  const named = (g: Game) => new Set(COMMS.map(c => g.comms[c].leader.name));

  it('대비하지 않은 재난은 한 명만 죽고, 일지 원인 줄과 기존 죽음 길(사망 목록·유품 카드)을 탄다', () => {
    DZ.deathP = 1;
    const g = active('dz-death', 'cold', { unprepared: true });
    g.disasterDeaths = 0;
    disasterSettle(g);
    expect(g.deaths).toHaveLength(1);
    const name = g.deaths[0];
    expect(g.journal.some(j => j.text.startsWith('예고를 듣고도 그냥 갔다.') && j.text.includes(name) && j.text.endsWith('밤사이 얼어 숨졌다.'))).toBe(true);
    expect(g.deathLog?.[0]).toMatchObject({ name, cause: 'warned' });
    expect(g.journal.some(j => j.text.includes('죽었다'))).toBe(true); // onDeath의 줄
    disasterSettle(g);
    disasterSettle(g);
    expect(g.deaths).toHaveLength(1); // 재난 하나에 한 명
    expect(g.disasterDeaths).toBe(1);
    expect(g.disaster).toBeUndefined();
  });

  it('판 전체 재난 사망은 상한(2)을 넘지 않는다', () => {
    DZ.deathP = 1;
    const g = createGame('dz-cap');
    enableDisasters(g);
    for (let k = 0; k < 4; k += 1) {
      g.seg = 5 + k * 3;
      g.disaster = { kind: 'cold', stage: 'active', left: 1, unprepared: true, warmDrop: 0 };
      disasterSettle(g);
    }
    expect(g.disasterDeaths).toBe(DZ.deathCap);
    expect(g.deaths).toHaveLength(DZ.deathCap);
  });

  it('대비한 재난, 확률 0이면 아무도 죽지 않는다', () => {
    DZ.deathP = 1;
    const a = active('dz-prepped', 'cold', { prep: 'coal' });
    for (let i = 0; i < 3; i += 1) disasterSettle(a);
    expect(a.deaths).toEqual([]);
    DZ.deathP = 0;
    const b = active('dz-p0', 'cold', { unprepared: true });
    for (let i = 0; i < 3; i += 1) disasterSettle(b);
    expect(b.deaths).toEqual([]);
  });

  it('온기가 가장 낮은 칸에서 고르고, 대표와 12세 미만은 뽑지 않는다(여러 시드)', () => {
    DZ.deathP = 1;
    for (let i = 0; i < 60; i += 1) {
      const g = active(`dz-who-${i}`, 'blizzard', { unprepared: true });
      const cold = COMMS[i % COMMS.length];
      for (const c of COMMS) g.comms[c].base[0] = c === cold ? 5 : 70;
      g.seg = 5 + i;
      disasterSettle(g);
      expect(g.deaths).toHaveLength(1);
      const p = PROFILES.find(x => x.name === g.deaths[0])!;
      expect(p.community, `seed ${i}`).toBe(cold);
      expect(p.age).toBeGreaterThanOrEqual(DZ.deathMinAge);
      expect(named(g).has(p.name)).toBe(false);
    }
  });

  it('S1b 측근(부대표·배급장)도 뽑지 않는다', async () => {
    const { enableDark } = await import('../../src/game');
    DZ.deathP = 1;
    for (let i = 0; i < 20; i += 1) {
      const g = active(`dz-staff-${i}`, 'blizzard', { unprepared: true });
      enableDark(g);
      g.seg = 6 + i;
      for (const c of COMMS) g.comms[c].base[0] = c === 'guard' ? 5 : 70;
      disasterSettle(g);
      const p = PROFILES.find(x => x.name === g.deaths[0])!;
      expect([g.dark!.staff.deputy, g.dark!.staff.ration]).not.toContain(p.id);
    }
  });

  it('봇 판 전체에서 재난 사망은 2명 이하이고 대비를 안 하면(never) 일어날 수 있다', () => {
    DZ.blizzardP = 0.3; DZ.coldP = 0.3; DZ.deathP = 1;
    let deaths = 0;
    for (let i = 0; i < 12; i += 1) {
      const { g, m } = playGame(`dz-bot-${i}`, { s1c: false, policy: 'caretaker', dom: 'idle', disasters: true, prep: 'never' });
      expect(g.disasterDeaths ?? 0).toBeLessThanOrEqual(DZ.deathCap);
      expect(m.disasterDeaths).toBe(g.disasterDeaths);
      deaths += m.disasterDeaths;
    }
    expect(deaths).toBeGreaterThan(0);
  });
});
