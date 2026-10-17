import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { createGame } from '../../src/game/state';
import type { Game } from '../../src/game/state';
import { enableDomestic } from '../../src/game/domestic/state';
import {
  applyFieldReturn, checkDeparture, chooseSymbolUse, decodeFieldReceipt, judgePromises, matchDeparture, symbolOptions,
} from '../../src/game/field_receipt';
import type { FieldDeparture, FieldReceipt } from '../../src/game/field_receipt';

// S3 영수증 계약 판 4(구현명세 S3 연결 v1 2절·6절). 표본은 S2 GUT(test_field_receipt.gd)도 같은 파일을 읽는다.
const dir = fileURLToPath(new URL('../../../s2/tests/game/fixtures/field_v4/', import.meta.url));
const read = <T>(name: string): T => JSON.parse(readFileSync(join(dir, name), 'utf8')) as T;
const dep = () => read<FieldDeparture>('departure_prologue.json');
const CASES = ['case1_symbol_kept', 'case2_symbol_broken', 'case3_nosymbol_kept', 'case4_nosymbol_broken'] as const;
const SEED = 'slice-seed-a';

function run(depName: string, receiptName: string, seed = SEED): { g: Game; before: Game } {
  const g = createGame(seed);
  const before = structuredClone(g);
  applyFieldReturn(g, read<FieldDeparture>(depName), read<FieldReceipt>(`${receiptName}.json`));
  return { g, before };
}

describe('필드 영수증 판 4: 계약 표본', () => {
  it('표본이 모두 계약을 지나고 출발 명세와 맞는다', () => {
    const pairs: [string, string[]][] = [
      ['departure_prologue.json', [...CASES, 'witness_none_back', 'witness_one_back']],
      ['departure_skip_kept.json', ['skip_kept']],
      ['departure_skip_broken.json', ['skip_broken']],
    ];
    for (const [d, receipts] of pairs) {
      const departure = read<FieldDeparture>(d);
      expect(() => checkDeparture(departure)).not.toThrow();
      for (const name of receipts) {
        const receipt = decodeFieldReceipt(readFileSync(join(dir, `${name}.json`), 'utf8'));
        expect(receipt.version).toBe(4);
        expect(() => matchDeparture(departure, receipt)).not.toThrow();
      }
    }
  });

  it('약속 판정은 열차가 증거로 정한다(지킴·어김·알 수 없음)', () => {
    const verdict = (d: string, r: string) => judgePromises(read(d), decodeFieldReceipt(read(`${r}.json`)))[0].verdict;
    expect(CASES.map(c => verdict('departure_prologue.json', c))).toEqual(['kept', 'broken', 'kept', 'broken']);
    expect(verdict('departure_prologue.json', 'witness_none_back')).toBe('unknown');
    expect(verdict('departure_prologue.json', 'witness_one_back')).toBe('kept');
    expect(verdict('departure_skip_kept.json', 'skip_kept')).toBe('kept');
    expect(verdict('departure_skip_broken.json', 'skip_broken')).toBe('broken');
  });

  it('계약을 어긴 영수증과 출발 명세에 안 맞는 영수증은 판을 바꾸지 않는다', () => {
    const mutations: ((r: Record<string, any>) => void)[] = [
      r => { r.version = 3; },
      r => { delete r.departureId; },
      r => { r.symbol = { id: 'sym_x', groupId: 'nobody', carriedBy: 'p_152' }; },
      r => { r.stock = { coal: 6, food: 3 }; },
      r => { r.fieldPromises[0].kind = 'oath'; },
      r => { r.fieldPromises.push(structuredClone(r.fieldPromises[0])); },
      r => { r.fieldPromises = []; },
      r => { r.fieldPromises[0].witnesses = ['p_151', 'p_151']; },
      r => { r.departureId = 'dep_other'; },
      r => { r.people.sent = ['p_151']; },
      r => { r.people.leftBehind = ['p_152']; },
      r => { r.fieldPromises[0].verdict = 'kept'; },
    ];
    for (const mutate of mutations) {
      const g = createGame(SEED);
      const before = JSON.stringify(g);
      const r = read<Record<string, any>>('case1_symbol_kept.json');
      mutate(r);
      expect(() => applyFieldReturn(g, dep(), r)).toThrow();
      expect(JSON.stringify(g)).toBe(before);
    }
  });
});

describe('필드 영수증 판 4: 판에 반영', () => {
  it('같은 귀환은 두 번 받아도, 저장했다 다시 받아도 한 번이다(확인 줄 9, T07·T08)', () => {
    const g = createGame(SEED);
    const r = read<FieldReceipt>('case1_symbol_kept.json');
    expect(applyFieldReturn(g, dep(), r).status).toBe('applied');
    const once = JSON.stringify(g);
    expect(applyFieldReturn(g, dep(), structuredClone(r)).status).toBe('duplicate');
    expect(JSON.stringify(g)).toBe(once);
    const reopened = JSON.parse(once) as Game;
    const reordered = Object.fromEntries(Object.entries(r).reverse());
    expect(applyFieldReturn(reopened, dep(), reordered).status).toBe('duplicate');
    expect(JSON.stringify(reopened)).toBe(once);
    // 같은 귀환 id에 다른 내용, 같은 정차에 다른 귀환 id는 조용히 넘기지 않는다.
    expect(() => applyFieldReturn(reopened, dep(), { ...r, stock: { coal: 9, food: 3, symbol: 1 } })).toThrow('다른 영수증');
    expect(() => applyFieldReturn(reopened, dep(), { ...r, receiptId: 'ret_again' })).toThrow('이미 반영한 정차');
    expect(JSON.stringify(reopened)).toBe(once);
  });

  it('반영 전후가 기록에 남고 물자·사람이 영수증대로 바뀐다(확인 줄 19)', () => {
    const { g, before } = run('departure_prologue.json', 'case1_symbol_kept');
    const rec = g.fieldReturns!.records[0];
    expect(rec.before.coal).toBe(before.coal);
    expect(g.coal).toBe(before.coal + 6);
    expect(g.food).toBe(before.food + 3);
    expect(g.symbols).toBe(before.symbols + 1);
    expect(g.injured).toBe(before.injured + 1);
    expect(rec.after.coal).toBe(g.coal);
    expect(rec.after.trust).toBe(g.trust);
    expect(rec.symbol).toEqual({ id: 'sym_tail_kettle', groupId: 'tail', carriedBy: 'p_152', use: null });
  });

  it('장부: 시작 + 순증감 = 잔액, 잔액보다 큰 음수는 0에서 멈추고 부족분을 적는다(T09)', () => {
    const apply = (coal: number, delta: number) => {
      const g = createGame(SEED);
      g.coal = coal;
      const r = read<Record<string, any>>('case3_nosymbol_kept.json');
      r.stock = { coal: delta };
      const rec = applyFieldReturn(g, dep(), r).record;
      return { g, line: rec.lines.find(l => l.k === 'stock')!.text };
    };
    // T09: 10에서 배정 4, 사용 1, 획득 2, 귀환 5 → 출발 배정이 없는 영수증에선 순증감 +1(5 − 4)이라 11.
    const t09 = apply(10, 1);
    expect(t09.g.coal).toBe(11);
    expect(t09.line).toBe('석탄 +1');
    const short = apply(3, -5);
    expect(short.g.coal).toBe(0);
    expect(short.line).toBe('석탄 -5 (모자라 0, 부족 2)');
    const exact = apply(5, -5);
    expect(exact.g.coal).toBe(0);
    expect(exact.line).toBe('석탄 -5');
  });

  it('네 사례: 상징물은 상징물 칸에만, 약속은 신임·관계 방향에 나타난다(6-1)', () => {
    const r = Object.fromEntries(CASES.map(c => [c, run('departure_prologue.json', c)]));
    const d = (c: typeof CASES[number], f: (g: Game) => number) => f(r[c].g) - f(r[c].before);
    const trust = (g: Game) => g.trust;
    const tail = (g: Game) => g.comms.tail.rel;
    // 지킴은 오르고 어김은 내린다.
    expect(d('case1_symbol_kept', trust)).toBeGreaterThan(0);
    expect(d('case2_symbol_broken', trust)).toBeLessThan(0);
    expect(d('case1_symbol_kept', tail)).toBeGreaterThan(0);
    expect(d('case2_symbol_broken', tail)).toBeLessThan(0);
    // 상징물 있음과 없음은 신임·관계에서 같고(쓰임을 고르기 전) 상징물 수만 다르다.
    expect(d('case1_symbol_kept', trust)).toBe(d('case3_nosymbol_kept', trust));
    expect(d('case2_symbol_broken', tail)).toBe(d('case4_nosymbol_broken', tail));
    expect(d('case1_symbol_kept', g => g.symbols)).toBe(1);
    expect(d('case3_nosymbol_kept', g => g.symbols)).toBe(0);
    // 두 칸이 같은 집단(꼬리칸)을 건드리면 기록에 두 줄로 남는다.
    const lines = r.case1_symbol_kept.g.fieldReturns!.records[0].lines.filter(l => l.comm === 'tail');
    expect(lines.map(l => l.k).sort()).toEqual(['promise', 'symbol']);
    expect(r.case2_symbol_broken.g.story?.flags.depot_promise).toBe('broken');
  });

  it('지킴의 오름이 어김의 깎임보다 작다: 관계 +5 대 −10, 신임 +2 대 −4(결정 184·407 A1)', () => {
    const kept = run('departure_prologue.json', 'case3_nosymbol_kept');
    const broken = run('departure_prologue.json', 'case4_nosymbol_broken');
    expect(kept.g.comms.tail.rel - kept.before.comms.tail.rel).toBeLessThan(broken.before.comms.tail.rel - broken.g.comms.tail.rel);
    expect(kept.g.trust - kept.before.trust).toBeLessThan(broken.before.trust - broken.g.trust);
  });

  it('목격자가 한 명도 못 돌아오면 알 수 없음: 약속 몫의 신임·관계 변화 0, 일지 한 줄(확인 줄 26, 6-7)', () => {
    const none = run('departure_prologue.json', 'witness_none_back');
    // 같은 영수증에서 약속만 뺀 짝: 죽음·남김이 만드는 변화는 이쪽과 같아야 한다.
    const control = createGame(SEED);
    const r = read<FieldReceipt>('witness_none_back.json');
    applyFieldReturn(control, { ...dep(), promises: [] }, { ...r, fieldPromises: [] });
    expect(none.g.trust).toBe(control.trust);
    for (const c of ['tail', 'guard', 'medtech'] as const) expect(none.g.comms[c].rel).toBe(control.comms[c].rel);
    expect(none.g.fieldReturns!.records[0].verdicts[0].verdict).toBe('unknown');
    expect(none.g.journal.filter(j => j.text.includes('본 사람이 아무도 돌아오지 못했다'))).toHaveLength(1);
    expect(none.g.story?.flags.depot_promise).toBe('unknown');
    // 한 명만 돌아온 짝은 돌아온 사람 기준으로 판정해 표에 닿는다.
    const one = run('departure_prologue.json', 'witness_one_back');
    expect(one.g.fieldReturns!.records[0].verdicts[0]).toMatchObject({ verdict: 'kept', witnessesBack: ['p_122'] });
    expect(one.g.trust).not.toBe(none.g.trust);
  });

  it('교대 약속: 출발 명단으로 판정이 갈리고 결과가 다르다(확인 줄 7, 6-2)', () => {
    const kept = run('departure_skip_kept.json', 'skip_kept');
    const broken = run('departure_skip_broken.json', 'skip_broken');
    expect(kept.g.fieldReturns!.records[0].verdicts[0].verdict).toBe('kept');
    expect(broken.g.fieldReturns!.records[0].verdicts[0].verdict).toBe('broken');
    expect(kept.g.trust).toBeGreaterThan(broken.g.trust);
    expect(kept.g.comms.tail.rel).toBeGreaterThan(broken.g.comms.tail.rel);
  });

  it('서막 판정은 꼬리칸에 걸린 다른 약속을 지우지 않는다', () => {
    const g = createGame(SEED);
    const live = { kind: 'open', cond: { kind: 'skip_dispatch', label: '다음 파견에서 제외', now: false }, label: '다음 파견에서 제외', due: 2 };
    (g.comms.tail as any).promise = live;
    applyFieldReturn(g, dep(), read('case1_symbol_kept.json'));
    expect(g.comms.tail.promise).toEqual(live);
  });
});

describe('상징물 쓰임 고르기(확인 줄 8, 결정 302)', () => {
  it('내정을 끈 판에서는 걸어 두기를 고를 수 없고 내걸기만 남는다', () => {
    const { g } = run('departure_prologue.json', 'case1_symbol_kept');
    const opts = symbolOptions(g, 'ret_sulechow_01');
    expect(opts.map(o => [o.use, o.ok])).toEqual([['hang_before_session', true], ['hang_in_car', false]]);
    expect(opts[1].why).toContain('내정');
    for (const o of opts) { expect(o.now.length).toBeGreaterThan(0); expect(o.later.length).toBeGreaterThan(0); }
    expect(chooseSymbolUse(g, 'ret_sulechow_01', 'hang_in_car')).toBe(false);
    expect(chooseSymbolUse(g, 'ret_sulechow_01', 'hang_before_session')).toBe(true);
    expect(g.fieldReturns!.records[0].symbol!.use).toBe('hang_before_session');
    // 한 번 고르면 바꾸지 않는다.
    expect(symbolOptions(g, 'ret_sulechow_01')).toEqual([]);
    expect(chooseSymbolUse(g, 'ret_sulechow_01', 'hang_before_session')).toBe(false);
  });

  it('내정을 켠 판에서는 칸에 걸어 둘 수 있다', () => {
    const g = createGame(SEED);
    enableDomestic(g);
    applyFieldReturn(g, dep(), read('case1_symbol_kept.json'));
    expect(symbolOptions(g, 'ret_sulechow_01').every(o => o.ok)).toBe(true);
    expect(chooseSymbolUse(g, 'ret_sulechow_01', 'hang_in_car')).toBe(true);
    expect(g.dom!.hung).toEqual(['tail']);
  });

  it('상징물이 없으면 고를 자리가 없다', () => {
    const { g } = run('departure_prologue.json', 'case3_nosymbol_kept');
    expect(symbolOptions(g, 'ret_sulechow_01')).toEqual([]);
  });
});
