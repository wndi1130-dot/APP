import { describe, expect, it } from 'vitest';
import { advance, chooseCard, createGame, viewCard } from '../../src/game';
import type { Game } from '../../src/game';
import { enableDomestic } from '../../src/game/domestic/state';
import { bodyOf, buildDeparture, CAPTAIN_ID, hungerOf } from '../../src/game/field_departure';
import type { FieldDepartureV2 } from '../../src/game/field_departure';
import { applyFieldReturn, decodeFieldReceipt, matchDeparture } from '../../src/game/field_receipt';
import type { FieldReceipt } from '../../src/game/field_receipt';
import { PROFILES } from '../../src/game/state';
import type { WoundBook } from '../../src/game/wounds';

// 출발 계약 판 2·영수증 판 5(docs/design/briefs/s3_departure_receipt_contract.md). GDScript 맞대기는 s2/tests/politics/test_field_departure.gd.

function atStop(seed: string, domestic = false): Game {
  const g = createGame(seed);
  if (domestic) enableDomestic(g);
  for (let i = 0; i < 80 && !(g.phase === 'stop' && g.stop && !g.stop.done); i += 1) {
    if (g.cards.length) { const c = g.cards[0]; chooseCard(g, c.uid, viewCard(g, c).choices.findIndex(x => !x.disabled)); continue; }
    advance(g);
  }
  return g;
}

function receiptFor(d: FieldDepartureV2, sent: string[], extra: Partial<Record<string, unknown>> = {}): Record<string, unknown> {
  return {
    version: 5, receiptId: `ret_${d.placeId}_${d.segment}`, departureId: d.departureId, stopId: d.stopId, source: 'direct', endReason: 'departed',
    place: { id: d.placeId, type: 'freight', variant: 's2_graybox' }, time: { arrive: 'D1 10:30', depart: 'D1 12:00', stayGameMinutes: 90 },
    stock: {}, items: { gained: [], lost: [] },
    people: { sent, injured: [], bitten: [], dead: [], missing: [], leftBehind: [], rescued: [] },
    witnessed: [], placeState: { looted: 0, remainingRisk: 1 }, promises: [],
    goal: { kind: null, required: 0, earned: 0, status: 'retreat' }, extras: { documents: [], symbolCount: 0, fragments: [], coreCount: 0 },
    symbol: null, fieldPromises: [], crew: [], defense: null, ...extra,
  };
}

describe('출발 계약 판 2', () => {
  it('명단은 열차장과 명부의 사람이고, 작업조는 S1 정차의 작업조와 경비대 호위 둘이다', () => {
    const g = atStop('slice-seed-a');
    const d = buildDeparture(g, { placeId: 'sulechow_station' });
    expect(d.version).toBe(2);
    expect(d.roster[0].id).toBe(CAPTAIN_ID);
    expect(d.roster.slice(1).map(p => p.comm)).toEqual(['guard', 'medtech', 'tail']);
    const ids = [...d.roster, ...d.workCrew].map(p => p.id);
    expect(new Set(ids).size).toBe(ids.length);
    for (const id of ids.slice(1)) expect(PROFILES.some(p => p.id === id)).toBe(true);
    const carriers = d.workCrew.filter(p => p.role === 'carrier');
    expect(carriers.length).toBe(g.stop!.crewSize);
    expect(carriers.every(p => p.comm === g.stop!.crewComm)).toBe(true);
    expect(d.workCrew.filter(p => p.role === 'escort').map(p => p.comm)).toEqual(['guard', 'guard']);
  });

  it('고른 동료를 그대로 싣고, 판을 바꾸지 않는다', () => {
    const g = atStop('train-0');
    // S1 작업조 거름(CREW_BUSY)이 처음 읽을 때 빈 상처 명부를 만든다. 그 밖에는 아무것도 바뀌지 않아야 한다.
    (g as Game & WoundBook).wounds ??= [];
    const before = JSON.stringify(g);
    const pick = PROFILES.filter(p => p.community === 'engine' && p.age >= 20 && p.age <= 50).slice(0, 1).map(p => p.id);
    const d = buildDeparture(g, { placeId: 'sulechow_station', companions: pick });
    expect(d.roster.map(p => p.id)).toEqual([CAPTAIN_ID, ...pick]);
    expect(JSON.stringify(g)).toBe(before);
  });

  it('몸 능력은 같은 사람에게 늘 같고 0~10이다(카드 A)', () => {
    for (const p of PROFILES.slice(0, 40)) {
      const a = bodyOf(p.id, p.age, p.community);
      expect(bodyOf(p.id, p.age, p.community)).toEqual(a);
      for (const v of Object.values(a)) expect(v >= 0 && v <= 10).toBe(true);
    }
    expect(bodyOf(CAPTAIN_ID, 40, 'front')).toEqual({ strength: 5, melee: 3, shooting: 2, stealth: 2, search: 2 });
  });

  it('허기는 배급 레버와 굶은 구간을 읽는다(카드 B)', () => {
    const g = createGame('slice-seed-a');
    expect(hungerOf(g, 'tail')).toBe(0);
    g.comms.tail.ration = 1;
    expect(hungerOf(g, 'tail')).toBe(1);
    g.comms.tail.ration = 0;
    expect(hungerOf(g, 'tail')).toBe(2);
    g.hunger = 1;
    expect(hungerOf(g, 'guard')).toBe(1);
    g.hunger = 3;
    expect(hungerOf(g, 'guard')).toBe(2);
  });

  it('앞 귀환에 나간 사람은 근육통 1, 지쳐 돌아왔으면 휴식이 그만큼', () => {
    const g = atStop('slice-seed-a');
    const d = buildDeparture(g, { placeId: 'sulechow_station' });
    const sent = d.roster.map(p => p.id);
    const crew = sent.map(person => ({ person, exhaustion: person === sent[1] ? 2 : 0, hunger: 0, bodyUse: {}, gearBack: { hands: [], items: {} } }));
    applyFieldReturn(g, d, receiptFor(d, sent, { crew }));
    const again = buildDeparture(g, { placeId: 'sulechow_station', companions: sent.slice(1) });
    expect(again.roster.map(p => p.sore)).toEqual([1, 1, 1, 1]);
    expect(again.roster.map(p => p.rest)).toEqual([1, 2, 1, 1]);
  });
});

describe('영수증 판 5', () => {
  it('처치·끝 상태·방어 칸을 받고, 모르는 처치는 막는다', () => {
    const g = atStop('slice-seed-a', true);
    const d = buildDeparture(g, { placeId: 'sulechow_station' });
    const sent = d.roster.map(p => p.id);
    const wounds = [{ person: sent[1], part: 'arm_left', kind: 'fracture', treat: { splinted: true, quick: true } }];
    const ok = receiptFor(d, sent, { people: { sent, injured: [sent[1]], bitten: [], dead: [], missing: [], leftBehind: [], rescued: [], wounds } });
    expect(decodeFieldReceipt(ok).version).toBe(5);
    const bad = structuredClone(ok) as { people: { wounds: { treat: Record<string, unknown> }[] } };
    bad.people.wounds[0].treat = { prayed: true };
    expect(() => decodeFieldReceipt(bad)).toThrow();
  });

  it('돌아온 옷·실은 옷·남은 미끼·실은 음식 칸은 없어도 되고, 꼴이 틀리면 막는다(계약 글 3절)', () => {
    const g = atStop('slice-seed-a', true);
    const d = buildDeparture(g, { placeId: 'sulechow_station' });
    const sent = d.roster.map(p => p.id);
    const coat = { id: 'wool_coat', condition: 0.6, holes: { torso: true } };
    const crew = [{ person: sent[0], exhaustion: 0, hunger: 0, bodyUse: {}, gearBack: { hands: [], items: {}, wear: { jacket: '', hands: { id: 'work_gloves', condition: 1 }, coat } } }];
    const ok = receiptFor(d, sent, { crew, wardrobeIn: [{ id: 'denim_jacket', condition: 0.4 }], luresBack: { clockwork: 2 }, foodIn: { meat_spoiled: 1, can_dented: 2 } });
    const got = decodeFieldReceipt(ok);
    expect(got.version === 5 && got.luresBack).toEqual({ clockwork: 2 });
    expect(decodeFieldReceipt(receiptFor(d, sent)).version).toBe(5);
    const torn = (f: (r: Record<string, any>) => void) => { const r = structuredClone(ok) as Record<string, any>; f(r); return r; };
    expect(() => decodeFieldReceipt(torn(r => { r.crew[0].gearBack.wear.coat.condition = 1.5; }))).toThrow();
    expect(() => decodeFieldReceipt(torn(r => { r.crew[0].gearBack.wear = { hands: '' }; }))).toThrow();
    expect(() => decodeFieldReceipt(torn(r => { r.wardrobeIn[0].holes = { torso: false }; }))).toThrow();
    expect(() => decodeFieldReceipt(torn(r => { r.luresBack.clockwork = -1; }))).toThrow();
    expect(() => decodeFieldReceipt(torn(r => { r.foodIn.can_dented = 0.5; }))).toThrow();
  });

  it('판 2 명단: 수색대는 다 나가야 하고, 작업조는 불린 사람만, 계약 밖 사람은 안 된다', () => {
    const g = atStop('slice-seed-a');
    const d = buildDeparture(g, { placeId: 'sulechow_station' });
    const roster = d.roster.map(p => p.id);
    const called = d.workCrew.slice(0, 2).map(p => p.id);
    const r = (sent: string[]) => decodeFieldReceipt(receiptFor(d, sent)) as FieldReceipt;
    expect(() => matchDeparture(d, r([...roster, ...called]))).not.toThrow();
    expect(() => matchDeparture(d, r(roster.slice(1)))).toThrow();
    const stranger = PROFILES.find(p => ![...roster, ...d.workCrew.map(x => x.id)].includes(p.id))!.id;
    expect(() => matchDeparture(d, r([...roster, stranger]))).toThrow();
  });
});
