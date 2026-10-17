import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { advance, castVote, createGame, resolveStop } from '../../src/game';
import type { Game } from '../../src/game';
import { applyFieldReturn, chooseSymbolUse } from '../../src/game/field_receipt';
import type { FieldDeparture, FieldReceipt } from '../../src/game/field_receipt';
import { nextFieldStep } from '../../src/game/field_council';
import { finishSlice, secondStationReached } from '../../src/game/field_arrival';
import { readSave } from '../../src/ui/repro';

// 단일 칸 자동 저장의 열차 쪽(결정 296, 확인 줄 9·20). S1은 행동마다 한 칸에 덮어쓴다(ui/app.ts). 여기서는 그 저장 글을
// 끝마다 읽어 되살려도 같은 판으로 이어지는지 본다. 더 이른 지점으로 가는 길(불러오기)은 S1에 없다.
const dir = fileURLToPath(new URL('../../../s2/tests/game/fixtures/field_v4/', import.meta.url));
const read = <T>(name: string): T => JSON.parse(readFileSync(join(dir, name), 'utf8')) as T;
const dep = () => read<FieldDeparture>('departure_prologue.json');
const receipt = () => read<FieldReceipt>('case2_symbol_broken.json');
const clear = (g: Game) => { g.cards = []; };
const step = (g: Game) => { clear(g); advance(g); clear(g); };

/** 저장 칸에 쓰고(JSON) 앱을 다시 열어 읽는다. */
function reopen(g: Game): Game {
  const r = readSave(JSON.parse(JSON.stringify(g)));
  if (!r.ok) throw new Error(r.why);
  return r.g;
}

function atStop(): Game {
  const g = createGame('slice-seed-a');
  g.seg = 2;
  step(g); step(g);
  resolveStop(g, true);
  clear(g);
  return g;
}

describe('단일 칸 자동 저장: 열차 쪽', () => {
  it('귀환 반영 직후 껐다 켜고 같은 영수증을 또 받아도 한 번이다(9, T07·T08)', () => {
    const once = atStop();
    applyFieldReturn(once, dep(), receipt());
    const g = reopen(once);
    expect(applyFieldReturn(g, dep(), receipt()).status).toBe('duplicate');
    expect(JSON.stringify(g)).toBe(JSON.stringify(reopen(once)));
  });

  it('반영 앞 저장에서 다시 시작해 받으면 반영 뒤 저장과 같은 끝 상태다(T08)', () => {
    const before = atStop();
    const a = reopen(before);
    const b = reopen(before);
    applyFieldReturn(a, dep(), receipt());
    applyFieldReturn(reopen(b), dep(), receipt());
    applyFieldReturn(b, dep(), receipt());
    expect(JSON.stringify(reopen(a))).toBe(JSON.stringify(reopen(b)));
  });

  it('상징물 쓰임을 고르기 전, 특별 회기 도중, 회기 뒤에 껐다 켜도 같은 자리에서 이어진다(20)', () => {
    let g = atStop();
    applyFieldReturn(g, dep(), receipt());
    g = reopen(g);
    expect(nextFieldStep(g)).toBe('choose_symbol');
    chooseSymbolUse(g, g.fieldReturns!.records[0].receiptId, 'hang_before_session');
    expect(nextFieldStep(g)).toBe('council');
    g = reopen(g);
    expect(g.phase).toBe('council');
    expect(g.council!.special).toBe(true);
    expect(nextFieldStep(g)).toBe('council');
    castVote(g);
    g = reopen(g);
    step(g);
    expect(g.phase).toBe('stop');
    g = reopen(g);
    expect(nextFieldStep(g)).toBe('done');
    expect(g.fieldReturns!.special!.result).toBeDefined();
  });

  it('둘째 역 도착과 끝 카드도 저장을 지나 그대로다(24)', () => {
    let g = atStop();
    applyFieldReturn(g, dep(), read<FieldReceipt>('case3_nosymbol_kept.json'));
    nextFieldStep(g); castVote(g); step(g);
    for (let i = 0; i < 12 && !secondStationReached(g); i += 1) { step(g); g = reopen(g); }
    expect(secondStationReached(reopen(g))).toBe(true);
    finishSlice(g);
    g = reopen(g);
    expect(g.phase).toBe('end');
    expect(g.end).toBe('slice');
    expect(finishSlice(g)).toBe(false);
  });

  it('필드 귀환 기록이 깨진 저장은 읽지 않는다', () => {
    const g = atStop();
    applyFieldReturn(g, dep(), receipt());
    const raw = JSON.parse(JSON.stringify(g));
    raw.fieldReturns.applied = null;
    expect(readSave(raw).ok).toBe(false);
  });
});
