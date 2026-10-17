import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { advance, agendaOptions, agendaTitle, blocs, castVote, createGame, expected, isLawAgenda, resolveStop, setAgenda, CORPSE_LAWS } from '../../src/game';
import type { Game } from '../../src/game';
import { applyFieldReturn, chooseSymbolUse, FIELD } from '../../src/game/field_receipt';
import type { FieldDeparture, FieldReceipt, SymbolUse } from '../../src/game/field_receipt';
import { leaveSpecialCouncil, nextFieldStep, openSpecialCouncil, specialCandidates, specialReasons } from '../../src/game/field_council';
import { enableDomestic } from '../../src/game/domestic/state';

// 첫 귀환 뒤 특별 회기 한 번(구현명세 S3 연결 v1 3절·6-1·6-4, 결정 290·303). 표본은 영수증 계약 시험과 같은 파일이다.
const dir = fileURLToPath(new URL('../../../s2/tests/game/fixtures/field_v4/', import.meta.url));
const read = <T>(name: string): T => JSON.parse(readFileSync(join(dir, name), 'utf8')) as T;
const CASES = ['case1_symbol_kept', 'case2_symbol_broken', 'case3_nosymbol_kept', 'case4_nosymbol_broken'] as const;
const SEED = 'slice-seed-a';
const clear = (g: Game) => { g.cards = []; };

function toStopDone(g: Game, seg: number): void {
  g.seg = seg;
  g.phase = 'prep';
  clear(g);
  advance(g); clear(g);
  advance(g); clear(g);
  resolveStop(g, true);
  clear(g);
}

function returned(receipt: string, opts: { dep?: string; use?: SymbolUse; seg?: number; domestic?: boolean } = {}): Game {
  const g = createGame(SEED);
  if (opts.domestic) enableDomestic(g);
  if (opts.seg) toStopDone(g, opts.seg);
  applyFieldReturn(g, read<FieldDeparture>(opts.dep ?? 'departure_prologue.json'), read<FieldReceipt>(`${receipt}.json`));
  if (opts.use) expect(chooseSymbolUse(g, g.fieldReturns!.records[0].receiptId, opts.use)).toBe(true);
  return g;
}

describe('특별 회기: 안건 후보(결정 303)', () => {
  it('같은 씨앗 네 사례에서 영수증 후보가 앞에 오고, 후보 묶음이 둘 이상 다르다(확인 줄 11·12)', () => {
    const sets = CASES.map(c => {
      const g = returned(c, { use: c.startsWith('case1') || c.startsWith('case2') ? 'hang_before_session' : undefined });
      expect(nextFieldStep(g)).toBe('council');
      const sp = g.fieldReturns!.special!;
      expect(sp.candidates.length).toBeGreaterThanOrEqual(2);
      expect(sp.candidates.length).toBeLessThanOrEqual(3);
      return sp.candidates;
    });
    expect(sets.map(s => s.map(c => c.from))).toEqual([
      ['symbol', 'promise', 'regular'],
      ['symbol', 'promise', 'regular'],
      ['promise', 'regular', 'regular'],
      ['promise', 'regular', 'regular'],
    ]);
    expect(sets[0][1].title).toContain('지킨 것');
    expect(sets[1][1].title).toContain('어김 추궁');
    expect(new Set(sets.map(s => JSON.stringify(s))).size).toBeGreaterThanOrEqual(2);
  });

  it('보통 안건으로 채운 자리는 그 시점 의회가 올릴 안건과 같다', () => {
    const g = returned('case3_nosymbol_kept');
    openSpecialCouncil(g);
    const regular = g.council!.options.filter((_, i) => g.fieldReturns!.special!.candidates[i].from === 'regular');
    const now = agendaOptions(g).options;
    expect(regular.length).toBe(2);
    for (const o of regular) expect(now).toContainEqual(o);
  });

  it('걸어 두기를 골랐으면 상징물 안건이 없다', () => {
    const g = returned('case1_symbol_kept', { domestic: true, use: 'hang_in_car' });
    openSpecialCouncil(g);
    expect(g.fieldReturns!.special!.candidates.map(c => c.from)).not.toContain('symbol');
  });

  it('목격자가 아무도 못 돌아왔으면 약속 안건이 없고, 한 명만 돌아왔으면 있다(결정 304)', () => {
    const none = returned('witness_none_back');
    const one = returned('witness_one_back');
    const from = (g: Game) => specialCandidates(g, g.fieldReturns!.records[0]).map(c => c.from);
    expect(from(none)).not.toContain('promise');
    expect(from(one)).toContain('promise');
  });

  it('이 정차에 죽은 사람이 있고 시신 법을 올릴 수 있으면 시신 안건이 맨 앞이다', () => {
    const g = returned('witness_one_back');
    const corpseOpen = agendaOptions(g).options.some(o => isLawAgenda(o) && !o.repeal && CORPSE_LAWS.includes(o.law));
    const cands = specialCandidates(g, g.fieldReturns!.records[0]);
    if (corpseOpen) expect(cands[0].from).toBe('corpse');
    else expect(cands.map(c => c.from)).not.toContain('corpse');
    const alive = returned('case3_nosymbol_kept');
    expect(specialCandidates(alive, alive.fieldReturns!.records[0]).map(c => c.from)).not.toContain('corpse');
  });
});

describe('특별 회기: 한 번, 차례(결정 290)', () => {
  it('상징물 쓰임을 고르기 전에는 열리지 않는다', () => {
    const g = returned('case1_symbol_kept');
    expect(nextFieldStep(g)).toBe('choose_symbol');
    expect(openSpecialCouncil(g)).toBeNull();
    expect(g.phase).not.toBe('council');
  });

  it('고른 안건으로 표결하고, 닫으면 연 단계로 돌아가며, 다시 열리지 않는다(확인 줄 10·11·15)', () => {
    const g = returned('case2_symbol_broken', { use: 'hang_before_session', seg: 2 });
    expect(g.phase).toBe('stop');
    expect(nextFieldStep(g)).toBe('council');
    expect(g.phase).toBe('council');
    expect(g.council!.special).toBe(true);
    setAgenda(g, 1);
    const r = castVote(g);
    expect(r).not.toBeNull();
    expect(r!.flips.length).toBeGreaterThanOrEqual(0);
    advance(g);
    expect(g.phase).toBe('stop');
    const sp = g.fieldReturns!.special!;
    expect(sp.picked).toContain('어김 추궁');
    expect(sp.result).toMatchObject({ passed: r!.passed, yes: r!.yes, no: r!.no });
    expect(sp.before).toBeDefined();
    expect(sp.after).toBeDefined();
    expect(nextFieldStep(g)).toBe('done');
    expect(openSpecialCouncil(g)).toBeNull();
  });

  it('표결 전에는 닫히지 않는다', () => {
    const g = returned('case3_nosymbol_kept', { seg: 2 });
    nextFieldStep(g);
    expect(leaveSpecialCouncil(g)).toBe(false);
    expect(g.phase).toBe('council');
  });

  it('정규 회기 구간 규칙은 그대로다: 닫은 뒤 회기 구간이면 정규 회기가, 아니면 구간 정산이 온다', () => {
    const off = returned('case3_nosymbol_kept', { seg: 2 });
    nextFieldStep(off); castVote(off); advance(off);
    advance(off);
    expect(off.phase).toBe('settle');

    const on = returned('case3_nosymbol_kept', { seg: 3 });
    const session = on.session;
    nextFieldStep(on); castVote(on); advance(on);
    expect(on.phase).toBe('stop');
    advance(on);
    expect(on.phase).toBe('council');
    expect(on.council!.special).toBeUndefined();
    expect(on.session).toBe(session + 2);
  });

  it('영수증이 없는 판에는 특별 회기가 없다', () => {
    const g = createGame(SEED);
    expect(openSpecialCouncil(g)).toBeNull();
    expect(nextFieldStep(g)).toBe('done');
    expect(g.fieldReturns).toBeUndefined();
  });

  it('같은 판에서 두 번째 귀환이 와도 특별 회기는 다시 열리지 않는다', () => {
    const g = returned('case3_nosymbol_kept', { seg: 2 });
    nextFieldStep(g); castVote(g); advance(g);
    const before = structuredClone(g.fieldReturns!.special);
    // 둘째 정차의 귀환: 표본은 첫 정차 id를 쓰니 정차·출발·귀환 id만 바꾼다.
    const dep2 = { ...read<FieldDeparture>('departure_skip_kept.json'), departureId: 'dep_second', stopId: 'stop_second' };
    const rec2 = { ...read<FieldReceipt>('skip_kept.json'), receiptId: 'ret_second', departureId: 'dep_second', stopId: 'stop_second' };
    expect(applyFieldReturn(g, dep2, rec2).status).toBe('applied');
    expect(nextFieldStep(g)).toBe('done');
    expect(g.fieldReturns!.special).toEqual(before);
  });

  it('전망 옆 이유 줄은 표에 닿은 약속·상징물 줄이다(확인 줄 14)', () => {
    const g = returned('case2_symbol_broken', { use: 'hang_before_session' });
    const reasons = specialReasons(g);
    expect(reasons.map(l => l.k).sort()).toEqual(['promise', 'symbol', 'symbol']);
    expect(reasons.every(l => l.comm === 'tail')).toBe(true);
  });
});

describe('특별 회기: 값 가안(확인 줄 13·17·18)', () => {
  const forecast = (g: Game, title: string) => {
    const a = g.council!.options.find(o => agendaTitle(o) === title)!;
    return expected(blocs(g, a)).mean;
  };
  it('상징물을 내걸면 그 칸 관계가 한 번 바뀌고, 같은 안건의 전망이 달라진다(13·17)', () => {
    const hung = returned('case1_symbol_kept', { use: 'hang_before_session' });
    const none = returned('case3_nosymbol_kept');
    expect(hung.comms.tail.rel - none.comms.tail.rel).toBe(FIELD.hangRel);
    nextFieldStep(hung); nextFieldStep(none);
    const kept = '꼬리칸과(와)의 약속을 지킨 것을 기록에 올리기';
    expect(forecast(hung, kept)).not.toBe(forecast(none, kept));
  });

  it('어김의 깎임이 지킴의 오름보다 크다(18, 관계)', () => {
    const base = createGame(SEED).comms.tail.rel;
    const kept = returned('case3_nosymbol_kept').comms.tail.rel - base;
    const broken = returned('case4_nosymbol_broken').comms.tail.rel - base;
    expect(kept).toBeGreaterThan(0);
    expect(-broken).toBeGreaterThan(kept);
  });
});
