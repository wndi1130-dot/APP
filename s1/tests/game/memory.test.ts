import { describe, expect, it } from 'vitest';
import { createGame } from '../../src/game';
import type { Game } from '../../src/game';
import { CAPTAIN_ID, decodeFieldReceipt } from '../../src/game/field_receipt';
import type { FieldDeparture, FieldReceipt } from '../../src/game/field_receipt';
import {
  cuesOf, departureMemory, dispatchNote, kinLine, kinOf, memoriesOf, memoryFromReturn, memoryTestimonies, memoryTick, spendRefusal, stanceOf,
} from '../../src/game/memory';
import { peopleTick } from '../../src/game/people';
import { PROFILES } from '../../src/game/state';

// 사람 기억(J13, 결정 439 카드 1·2). 칸 관계 위에 사람 한 명의 기억을 따로 두고, 본 사람이 안 돌아오면 아무도 모른다.

// 꼬리칸 가족 f_001의 아버지와 어머니, 다른 꼬리칸 가족의 어른 둘.
const DAD = 'p_030';
const MOM = 'p_016';
const MATE = 'p_090';
const MATE2 = 'p_045';
const name = (id: string) => PROFILES.find(p => p.id === id)!.name;

const departure: FieldDeparture = {
  version: 1, departureId: 'dep_sulechow_3', stopId: 'stop_3', placeId: 'sulechow_station', segment: 3,
  roster: [{ id: DAD, comm: 'tail' }, { id: MATE, comm: 'tail' }, { id: MATE2, comm: 'tail' }], promises: [],
};

type Row = { who: string; what: string; witnesses: string[]; template?: string };

function receipt(id: string, rows: Row[], people: Partial<Record<'dead' | 'missing' | 'leftBehind' | 'rescued', string[]>> = {}): FieldReceipt {
  return decodeFieldReceipt({
    version: 4, receiptId: id, departureId: departure.departureId, stopId: departure.stopId, source: 'direct', endReason: 'departed',
    place: { id: departure.placeId, type: 'freight', variant: 's2_graybox' }, time: { arrive: 'D1 10:30', depart: 'D1 12:00', stayGameMinutes: 90 },
    stock: {}, items: { gained: [], lost: [] },
    people: { sent: [DAD, MATE, MATE2], injured: [], bitten: [], dead: [], missing: [], leftBehind: [], rescued: [], ...people },
    witnessed: rows.map(r => ({ who: r.who, what: r.what, where: 'station_street', when: 'D1 11:00', why: 'field', witnesses: r.witnesses, ...(r.template ? { template: r.template } : {}) })),
    placeState: { looted: 0, remainingRisk: 1 }, promises: [],
    goal: { kind: null, required: 0, earned: 0, status: 'retreat' }, extras: { documents: [], symbolCount: 0, fragments: [], coreCount: 0 },
    symbol: null, fieldPromises: [],
  });
}

function game(): Game {
  const g = createGame('memory-seed');
  g.seg = 3;
  return g;
}

describe('사람 기억: 개인 경험을 칸 관계 위에 따로 둔다', () => {
  it('열차장이 잡힘에서 떼어 준 사람은 칸 관계가 나빠도 개인 단계가 good이고, 칸 값은 그대로다', () => {
    const g = game();
    g.comms.tail.rel = -40;
    const before = { rel: g.comms.tail.rel, trust: g.trust, tension: g.tension };
    memoryFromReturn(g, departure, receipt('r1', [{ who: CAPTAIN_ID, what: `freed_${DAD}`, witnesses: [DAD], template: 'rescued_from_grab' }]));
    expect(stanceOf(g, DAD)).toBe('good');
    expect(departureMemory(g, DAD)).toEqual({ stance: 'good', cues: ['saved_me'] });
    expect({ rel: g.comms.tail.rel, trust: g.trust, tension: g.tension }).toEqual(before);
    expect(dispatchNote(g, DAD)).toEqual({ volunteer: true, refuse: null });
  });

  it('같은 귀환을 두 번 거둬도 기억은 한 번이다', () => {
    const g = game();
    const r = receipt('r2', [{ who: CAPTAIN_ID, what: `freed_${DAD}`, witnesses: [DAD], template: 'rescued_from_grab' }]);
    memoryFromReturn(g, departure, r);
    expect(memoryFromReturn(g, departure, r)).toEqual([]);
    expect(memoriesOf(g, DAD)).toHaveLength(1);
  });

  it('동료가 구한 일은 열차장 단계에 닿지 않고 그 동료를 가리키는 기억 키로만 남는다', () => {
    const g = game();
    memoryFromReturn(g, departure, receipt('r3', [{ who: MATE, what: `carried_${DAD}`, witnesses: [DAD, MATE], template: 'carried_back' }]));
    expect(stanceOf(g, DAD)).toBeNull();
    expect(cuesOf(g, DAD)).toEqual([`saved_by:${MATE}`]);
  });

  it('치료받은 일은 가볍고 짧게 남는다', () => {
    const g = game();
    memoryFromReturn(g, departure, receipt('r4', [{ who: CAPTAIN_ID, what: `treated_${DAD}`, witnesses: [DAD], template: 'treated_by' }]));
    expect(stanceOf(g, DAD)).toBeNull();
    expect(dispatchNote(g, DAD).volunteer).toBe(false);
    g.seg += 4;
    expect(memoriesOf(g, DAD)).toHaveLength(0);
  });
});

describe('사람 기억: 출발 화면의 협조(카드 2 「가」)', () => {
  it('두고 갈 뻔한 일과 손 든 사람을 쏜 일을 본 사람은 까닭이 보이는 거절을 한 기억에 한 번씩 한다', () => {
    const g = game();
    memoryFromReturn(g, departure, receipt('r5', [
      { who: CAPTAIN_ID, what: `left_${DAD}`, witnesses: [DAD], template: 'left_behind_survived' },
      { who: CAPTAIN_ID, what: 'shot_surrendered_raider', witnesses: [DAD, MATE] },
    ]));
    expect(stanceOf(g, DAD)).toBe('bad');
    expect(stanceOf(g, MATE)).toBeNull(); // 본 것 하나(−2)는 문턱 아래: 칸 관계를 그대로 쓴다
    const first = dispatchNote(g, DAD).refuse;
    expect(first).not.toBeNull();
    spendRefusal(g, DAD);
    const second = dispatchNote(g, DAD).refuse;
    expect(second).not.toBeNull();
    expect(second).not.toBe(first);
    spendRefusal(g, DAD);
    expect(dispatchNote(g, DAD).refuse).toBeNull();
    expect(stanceOf(g, DAD)).toBe('bad'); // 거절을 다 써도 기억은 지워지지 않는다
  });

  it('돌아오지 않은 사람의 본 기억은 남지 않는다', () => {
    const g = game();
    memoryFromReturn(g, departure, receipt('r6', [{ who: CAPTAIN_ID, what: 'shot_surrendered_raider', witnesses: [MATE] }], { dead: [MATE] }));
    expect(memoriesOf(g, MATE)).toHaveLength(0);
  });
});

describe('사람 기억: 목격하지 못한 사실은 모른다', () => {
  it('본 동료가 돌아오면 가족은 들어서 알고, 그 동료 이름으로 말한다', () => {
    const g = game();
    memoryFromReturn(g, departure, receipt('r7', [{ who: DAD, what: 'bitten_arm_left', witnesses: [MATE, CAPTAIN_ID] }], { dead: [DAD] }));
    expect(kinOf(g, DAD)).toBe(MOM);
    const kin = memoriesOf(g, MOM)[0];
    expect(kin).toMatchObject({ kind: 'lost_kin', how: 'told', from: [MATE], chiefNear: true });
    const line = kinLine(g, MOM)!;
    expect(line).toContain(name(MATE));
    expect(line).not.toMatch(/물렸|두고/);
    expect(memoriesOf(g, MATE).map(m => m.kind)).toEqual(['saw_fall']);
  });

  it('열차장 혼자 본 죽음은 가족이 모르고, 모른다고 말한다', () => {
    const g = game();
    memoryFromReturn(g, departure, receipt('r8', [{ who: DAD, what: 'bitten_torso', witnesses: [CAPTAIN_ID] }], { dead: [DAD] }));
    const kin = memoriesOf(g, MOM)[0];
    expect(kin.how).toBe('unknown');
    expect(kin.chiefNear).toBeUndefined();
    const line = kinLine(g, MOM)!;
    expect(line).toContain('아무도');
    expect(line).not.toMatch(/물렸|두고|열차장님이 옆/);
  });

  it('곁에서 본 동료도 돌아오지 못했으면 그렇게 말하고 「돌아온 사람이 없다」고는 하지 않는다', () => {
    const g = game();
    memoryFromReturn(g, departure, receipt('r9', [{ who: DAD, what: 'bitten_leg_left', witnesses: [MATE] }], { dead: [DAD, MATE] }));
    expect(memoriesOf(g, MOM)[0]).toMatchObject({ how: 'unknown', seenByGone: true });
    expect(kinLine(g, MOM)).toBe('곁에 있던 사람도 돌아오지 못했어요.');
  });

  it('남겨진 일은 함께 돌아온 동료가 전하고, 가족의 열차장 값이 깎인다', () => {
    const g = game();
    memoryFromReturn(g, departure, receipt('r10', [], { leftBehind: [DAD] }));
    const kin = memoriesOf(g, MOM)[0];
    expect(kin).toMatchObject({ how: 'told', detail: 'left', weight: -2 });
    expect(kin.from.sort()).toEqual([MATE, MATE2].sort());
    expect(kinLine(g, MOM)).toBe('살아 있었대요. 두고 왔대요.');
  });
});

describe('사람 기억: 정차 사람 장면과 열차 안 사건', () => {
  it('동료가 한 약탈은 열차장 단계에 닿지 않는다', () => {
    const g = game();
    memoryFromReturn(g, departure, receipt('r11', [{ who: MATE, what: 'signal_box_b', witnesses: [DAD, MATE], template: 'resident_robbed' }]));
    const m = memoriesOf(g, DAD)[0];
    expect(m).toMatchObject({ kind: 'saw_resident_robbed', about: MATE });
    expect(stanceOf(g, DAD)).toBeNull();
    expect(memoriesOf(g, MATE)).toHaveLength(0); // 한 사람 자신은 본 사람으로 세지 않는다
  });

  it('열차 안 사건 줄은 정산 때 그 사람의 기억이 되고 비워진다', () => {
    const g = game();
    g.personEvents = [{ key: 'riot_fell', who: MATE, seg: 3, comm: 'tail', by: 'chief' }];
    peopleTick(g, () => 0.99);
    expect(memoriesOf(g, MATE)).toMatchObject([{ kind: 'event', detail: 'riot_fell', about: CAPTAIN_ID }]);
    expect(g.personEvents).toEqual([]);
    memoryTick(g);
    expect(memoriesOf(g, MATE)).toHaveLength(1);
  });

  it('회고 증언은 그 기억을 가진 사람이 말하고, 무뎌지면 차가운 쪽이다', () => {
    const g = game();
    memoryFromReturn(g, departure, receipt('r12', [
      { who: CAPTAIN_ID, what: `freed_${DAD}`, witnesses: [DAD], template: 'rescued_from_grab' },
      { who: CAPTAIN_ID, what: 'shot_surrendered_raider', witnesses: [MATE2] },
    ]));
    const warm = memoryTestimonies(g);
    expect(warm.map(t => t.pid)).toEqual([DAD, MATE2]);
    expect(warm[0].line).toBe('그날 저를 끌어낸 손이 열차장 손이었어요.');
    expect(g.chronicle?.map(c => c.template)).toEqual(['s3.saved_me', 's3.saw_shot_surrendered']);
  });
});
