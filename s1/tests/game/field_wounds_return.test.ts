import { describe, expect, it } from 'vitest';
import { advance, chooseCard, createGame, viewCard } from '../../src/game';
import type { Game } from '../../src/game';
import { buildDeparture } from '../../src/game/field_departure';
import { applyFieldReturn, fieldWoundOf } from '../../src/game/field_receipt';
import type { FieldWound } from '../../src/game/field_receipt';
import type { Wound, WoundBook } from '../../src/game/wounds';

// J02: 필드가 적은 부위·종류·처치·곪음을 열차가 다시 뽑지 않는다(s3_departure_receipt_contract.md 4절, 몸과 부상 4.1·4.6).

function atStop(seed: string): Game {
  const g = createGame(seed);
  for (let i = 0; i < 80 && !(g.phase === 'stop' && g.stop && !g.stop.done); i += 1) {
    if (g.cards.length) { const c = g.cards[0]; chooseCard(g, c.uid, viewCard(g, c).choices.findIndex(x => !x.disabled)); continue; }
    advance(g);
  }
  return g;
}

function returnWith(seed: string, wounds: (pid: string) => FieldWound[], bitten = false): { g: Game; who: string; rngBefore: unknown } {
  const g = atStop(seed);
  const d = buildDeparture(g, { placeId: 'sulechow_station' });
  const sent = d.roster.map(p => p.id);
  const pid = sent[1];
  const rows = wounds(pid);
  const rngBefore = structuredClone(g.rng);
  applyFieldReturn(g, d, {
    version: 5, receiptId: 'ret_a', departureId: d.departureId, stopId: d.stopId, source: 'direct', endReason: 'departed',
    place: { id: d.placeId, type: 'freight', variant: 's2_graybox' }, time: { arrive: 'D1 10:30', depart: 'D1 12:00', stayGameMinutes: 90 },
    stock: {}, items: { gained: [], lost: [] },
    people: { sent, injured: bitten ? [] : [pid], bitten: bitten ? [pid] : [], dead: [], missing: [], leftBehind: [], rescued: [], ...(rows.length ? { wounds: rows } : {}) },
    witnessed: [], placeState: { looted: 0, remainingRisk: 1 }, promises: [],
    goal: { kind: null, required: 0, earned: 0, status: 'retreat' }, extras: { documents: [], symbolCount: 0, fragments: [], coreCount: 0 },
    symbol: null, fieldPromises: [], crew: [], defense: null,
  });
  return { g, who: d.roster[1].name, rngBefore };
}

const bookOf = (g: Game, who: string): Wound[] => ((g as Game & WoundBook).wounds ?? []).filter(w => w.who === who);

describe('J02 필드 상처 그대로', () => {
  it('왼팔 골절은 씨앗과 상관없이 같은 사람·왼팔·골절로 남고 판 난수가 움직이지 않는다', () => {
    for (const seed of ['slice-seed-a', 'train-0', 'train-1', 'train-2']) {
      const { g, who, rngBefore } = returnWith(seed, pid => [{ person: pid, part: 'arm_left', kind: 'fracture', treat: { splinted: true } }]);
      const [w] = bookOf(g, who);
      expect([w.grade, w.part, w.septic, w.daysLeft]).toEqual(['fracture', 'armL', false, 6]);
      expect(w.field).toEqual([{ part: 'arm_left', kind: 'fracture', treat: { splinted: true } }]);
      expect(g.rng).toEqual(rngBefore);
    }
  });

  it('의무 지식이 곧바로 부목을 대면 가벼운 상처로 센다', () => {
    const { g, who } = returnWith('slice-seed-a', pid => [{ person: pid, part: 'arm_left', kind: 'fracture', treat: { splinted: true, quick: true } }]);
    expect(bookOf(g, who).map(w => [w.grade, w.part, w.state])).toEqual([['light', 'armL', 'light']]);
  });

  it('가장 무거운 상처 하나가 기록이 되고 나머지는 붙는다, 곪음은 그대로', () => {
    const { g, who } = returnWith('train-0', pid => [
      { person: pid, part: 'leg_right', kind: 'laceration' },
      { person: pid, part: 'torso', kind: 'embedded', festering: true },
    ]);
    const book = bookOf(g, who);
    expect(book.length).toBe(1);
    expect([book[0].grade, book[0].part, book[0].septic]).toEqual(['deep', 'torso', true]);
    expect(book[0].field?.length).toBe(2);
  });

  it('필드에서 자른 팔은 골절보다 무거운 절단으로 남고, 팔·다리가 아닌 절단은 깊은 상처로 친다', () => {
    const { g, who } = returnWith('train-0', pid => [
      { person: pid, part: 'leg_left', kind: 'fracture', treat: { splinted: true } },
      { person: pid, part: 'arm_right', kind: 'amputation', treat: { tourniquet: true } },
    ]);
    const book = bookOf(g, who);
    expect(book.map(w => [w.grade, w.part, w.bedDays])).toEqual([['amputation', 'armR', 4]]);
    expect(book[0].field?.length).toBe(2);
    expect(fieldWoundOf([{ person: 'p', part: 'torso', kind: 'amputation' }], 'p').grade).toBe('deep');
  });

  it('긁힘·찢김뿐인 부상자는 깊은 상처(카드 C), 줄이 없으면 몸통, 머리 골절은 깊은 상처', () => {
    expect(fieldWoundOf([{ person: 'p', part: 'arm_right', kind: 'laceration' }], 'p').grade).toBe('deep');
    expect(fieldWoundOf([{ person: 'p', part: 'arm_right', kind: 'laceration' }], 'p').part).toBe('armR');
    expect([fieldWoundOf([], 'p').grade, fieldWoundOf([], 'p').part]).toEqual(['deep', 'torso']);
    expect(fieldWoundOf([{ person: 'p', part: 'head_neck', kind: 'fracture' }], 'p').grade).toBe('deep');
  });

  it('물린 채 돌아온 사람은 숨은 물림 시계(2구간)에 오르고 부상자가 아니다', () => {
    const { g, who } = returnWith('slice-seed-a', () => [], true);
    expect(g.hiddenBites.map(b => [b.who, b.due - b.at])).toEqual([[who, 2]]);
    expect(bookOf(g, who)).toEqual([]);
  });
});
