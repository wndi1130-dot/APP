import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { advance, castVote, createGame, resolveStop } from '../../src/game';
import type { Game } from '../../src/game';
import { applyFieldReturn, chooseSymbolUse } from '../../src/game/field_receipt';
import type { FieldDeparture, FieldReceipt } from '../../src/game/field_receipt';
import { nextFieldStep } from '../../src/game/field_council';
import { arrivalSummary, endCard, finishSlice, secondStationReached } from '../../src/game/field_arrival';
import { pickFirst } from '../../tools/slice_vectors';

// 둘째 역 도착 화면과 끝 카드(구현명세 S3 연결 v1 5절, 결정 297, 확인 줄 19·22·23·24).
const dir = fileURLToPath(new URL('../../../s2/tests/game/fixtures/field_v4/', import.meta.url));
const read = <T>(name: string): T => JSON.parse(readFileSync(join(dir, name), 'utf8')) as T;
// 조각은 서류를 한 장씩 띄우고 고르기 전엔 못 가므로, 걸음 앞뒤에 서류마다 첫 고를 수 있는 선택지를 고른다(slice_vectors.ts와 같다).
const step = (g: Game) => { pickFirst(g); advance(g); pickFirst(g); };

/** 첫 정차(2구간)에서 필드를 마치고 돌아와 특별 회기까지 끝낸 판을 둘째 역까지 달린다. */
function slice(receipt: string, hang = false): Game {
  const g = createGame('slice-seed-a');
  g.seg = 2;
  step(g); step(g);
  resolveStop(g, true);
  pickFirst(g);
  const rec = applyFieldReturn(g, read<FieldDeparture>('departure_prologue.json'), read<FieldReceipt>(`${receipt}.json`)).record;
  if (hang) chooseSymbolUse(g, rec.receiptId, 'hang_before_session');
  expect(nextFieldStep(g)).toBe('council');
  castVote(g);
  step(g); // 특별 회기를 닫고 정차로
  expect(g.phase).toBe('stop');
  expect(secondStationReached(g)).toBe(false);
  for (let i = 0; i < 12 && !secondStationReached(g) && g.phase !== 'end'; i += 1) step(g);
  return g;
}

describe('둘째 역 도착', () => {
  it('첫 귀환 뒤 다음 정차에 닿으면 도착 화면이 차례대로 나온다(22·23)', () => {
    const g = slice('case2_symbol_broken', true);
    expect(secondStationReached(g)).toBe(true);
    expect(g.seg).toBe(3);
    const s = arrivalSummary(g)!;
    expect(s.map(x => x.k)).toEqual(['arrive', 'people', 'stock', 'warm', 'symbol', 'promise', 'council']);
    expect(s.every(x => x.lines.length > 0)).toBe(true);
    expect(s.find(x => x.k === 'symbol')!.lines.join(' ')).toContain('내걸었다');
    expect(s.find(x => x.k === 'promise')!.lines.join(' ')).toContain('어겼다');
    expect(s.find(x => x.k === 'council')!.lines[0]).toMatch(/가결|부결/);
    expect(s.find(x => x.k === 'people')!.lines.join(' ')).toContain('꼬리칸');
  });

  it('물자 줄은 첫 귀환 반영 직전과 지금을 견준다(19)', () => {
    const g = slice('case3_nosymbol_kept');
    const rec = g.fieldReturns!.records[0];
    const coal = arrivalSummary(g)!.find(x => x.k === 'stock')!.lines[0];
    // 화면은 소수 첫째 자리까지 적는다.
    expect(coal).toContain(`${Math.round(rec.before.coal * 10) / 10}`);
    expect(coal).toContain(`${Math.round(g.coal * 10) / 10}`);
  });

  it('「계속」이면 끝 카드로 닫히고 더 나아가지 않는다(24)', () => {
    const g = slice('case3_nosymbol_kept');
    expect(endCard(g).lines.length).toBeGreaterThan(0);
    expect(finishSlice(g)).toBe(true);
    expect(g.phase).toBe('end');
    expect(g.end).toBe('slice');
    expect(g.fieldReturns!.arrived).toEqual({ seg: 3 });
    const before = JSON.stringify(g);
    step(g);
    expect(JSON.stringify(g)).toBe(before);
    expect(finishSlice(g)).toBe(false);
  });

  it('끝 카드는 필드에 남기고 온 사람도 돌아오지 못한 수로 센다(결정 147·183)', () => {
    const left = slice('case2_symbol_broken', true);
    const rec = left.fieldReturns!.records[0];
    expect(rec.dead).toEqual([]);
    expect(rec.leftCount).toBe(1);
    expect(endCard(left).lines[1]).toBe('1명이 돌아오지 못했다.');
    // 죽은 사람과 남긴 사람은 한 수로 묶는다. 이름은 끝 카드에 없다.
    rec.dead = ['가'];
    rec.leftCount = 2;
    expect(endCard(left).lines[1]).toBe('3명이 돌아오지 못했다.');
    // 남긴 수 칸이 없는 옛 기록은 보관한 영수증에서 다시 센다(남겨짐 1명).
    rec.dead = [];
    delete rec.leftCount;
    expect(endCard(left).lines[1]).toBe('1명이 돌아오지 못했다.');
    // 영수증도 못 읽으면 죽은 사람만 센다.
    left.fieldReturns!.applied[rec.receiptId] = '';
    expect(endCard(left).lines[1]).toBe('나간 사람은 모두 열차로 돌아왔다.');
    const all = slice('case3_nosymbol_kept');
    expect(all.fieldReturns!.records[0].leftCount).toBeUndefined();
    expect(endCard(all).lines[1]).toBe('나간 사람은 모두 열차로 돌아왔다.');
  });

  it('첫 정차 자리에서는 끝낼 수 없고, 영수증 없는 판에는 도착 화면이 없다', () => {
    const plain = createGame('slice-seed-a');
    expect(secondStationReached(plain)).toBe(false);
    expect(arrivalSummary(plain)).toBeNull();
    expect(finishSlice(plain)).toBe(false);
  });
});
