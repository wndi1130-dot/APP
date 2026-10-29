import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { advance, chooseCard, viewCard } from '../../src/game';
import { createGame, drawPerson, isGone, PROFILES } from '../../src/game/state';
import type { Game } from '../../src/game/state';
import { crewNames } from '../../src/game/turn';
import { COMMS, COMM_NAME, REP_AGE, TRAIT_BAN } from '../../src/game/data';
import type { Comm } from '../../src/game/data';
import { nextRandom } from '../../src/core/rng';
import { enableDark, repGone } from '../../src/game/dark/state';
import { enableDomestic } from '../../src/game/domestic/state';
import {
  applyFieldReturn, BODY_SEARCH_REL, CAPTAIN_ID, checkDeparture, chooseSymbolUse, decodeFieldReceipt, judgePromises, matchDeparture, symbolOptions,
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

  it('시체 뒤지기를 본 사람이 돌아오면 그 칸이 여기는 만큼 관계가 바뀐다, 한 귀환에 칸마다 한 번(결정 423 카드 12)', () => {
    const r = read<FieldReceipt>('case3_nosymbol_kept.json');
    const row = (who: string, seen: string[]) => ({
      who, what: 'body_search', where: 'first_leg_01_sulechow', when: 'D1 10:00', why: 'searched_the_dead', witnesses: seen, template: 'body_search',
    });
    const control = createGame(SEED);
    applyFieldReturn(control, dep(), r);
    const g = createGame(SEED);
    applyFieldReturn(g, dep(), { ...r, witnessed: [row('p_151', ['p_152', 'p_122']), row('p_153', ['p_122'])] });
    expect(BODY_SEARCH_REL).toEqual({ tail: 0, medtech: -1, guard: 0, front: -1, engine: 0 });
    expect(BODY_SEARCH_REL.medtech).toBe(-1);
    expect(g.comms.medtech.rel - control.comms.medtech.rel).toBe(BODY_SEARCH_REL.medtech);
    expect(g.comms.guard.rel).toBe(control.comms.guard.rel);
    // 다른 템플릿의 목격 줄은 닿지 않는다.
    const other = createGame(SEED);
    applyFieldReturn(other, dep(), { ...r, witnessed: [{ ...row('p_151', ['p_122']), template: 'something_else' }] });
    expect(other.comms.medtech.rel).toBe(control.comms.medtech.rel);
  });

  it('시체 뒤지기를 본 사람이 돌아오지 못하면 그 칸은 모른다', () => {
    const r = read<FieldReceipt>('case3_nosymbol_kept.json');
    const people = { ...r.people, leftBehind: ['p_122'] };
    const row = { who: 'p_151', what: 'body_search', where: 'first_leg_01_sulechow', when: 'D1 10:00', why: 'searched_the_dead', witnesses: ['p_122'], template: 'body_search' };
    const control = createGame(SEED);
    applyFieldReturn(control, dep(), { ...r, people });
    const g = createGame(SEED);
    applyFieldReturn(g, dep(), { ...r, people, witnessed: [row] });
    expect(g.comms.medtech.rel).toBe(control.comms.medtech.rel);
  });

  it('필드에 남거나 사라진 사람은 떠난 사람 명단에도 들어 다음 작업조에 다시 뽑히지 않는다', () => {
    const r = read<FieldReceipt>('case3_nosymbol_kept.json');
    const name = (id: string) => PROFILES.find(p => p.id === id)!.name;
    const g = createGame(SEED);
    expect(crewNames(g, 'medtech', PROFILES.length)).toContain(name('p_122'));
    applyFieldReturn(g, dep(), { ...r, people: { ...r.people, leftBehind: ['p_122'], missing: ['p_152'] } });
    expect(g.left).toEqual([name('p_122'), name('p_152')]);
    expect(isGone(g, name('p_122'))).toBe(true);
    expect(crewNames(g, 'medtech', PROFILES.length)).not.toContain(name('p_122'));
    expect(crewNames(g, 'guard', PROFILES.length)).not.toContain(name('p_152'));
  });

  it('앞서 남겨졌던 사람이 살아서 구해져 오면 떠난 사람 명단에서 빠지고 칸 인원으로 돌아온다', () => {
    const r = read<FieldReceipt>('case3_nosymbol_kept.json');
    const who = PROFILES.find(p => p.id === r.people.rescued[0])!;
    const control = createGame(SEED);
    applyFieldReturn(control, dep(), r);
    const g = createGame(SEED);
    g.left = [who.name];
    applyFieldReturn(g, dep(), r);
    expect(g.left).toEqual([]);
    expect(isGone(g, who.name)).toBe(false);
    expect(g.comms[who.community].pop).toBe(control.comms[who.community].pop + 1);
    expect(g.fieldReturns!.records[0].lines.map(l => l.text)).toContain(`${COMM_NAME[who.community]} ${who.name}이(가) 살아서 다시 열차에 올랐다.`);
  });

  it('천·부품도 영수증으로 온다: 부품은 내정 그릇에 더하고 천은 계약만 지난다(결정 426 D②)', () => {
    const r = read<FieldReceipt>('case3_nosymbol_kept.json');
    const got = { ...r, receiptId: `${r.receiptId}_stores`, stock: { ...r.stock, cloth: 2, parts: 3 } };
    expect(decodeFieldReceipt(got).stock).toMatchObject({ cloth: 2, parts: 3 });
    const g = createGame(SEED);
    enableDomestic(g);
    const parts0 = g.dom!.parts;
    applyFieldReturn(g, dep(), got);
    expect(g.dom!.parts).toBe(parts0 + 3);
    const lost = createGame(SEED);
    enableDomestic(lost);
    applyFieldReturn(lost, dep(), { ...got, receiptId: `${r.receiptId}_lost`, stock: { ...r.stock, parts: -(parts0 + 5) } });
    expect(lost.dom!.parts).toBe(0);
  });

  it('서막 판정은 꼬리칸에 걸린 다른 약속을 지우지 않는다', () => {
    const g = createGame(SEED);
    const live = { kind: 'open', cond: { kind: 'skip_dispatch', label: '다음 파견에서 제외', now: false }, label: '다음 파견에서 제외', due: 2 };
    (g.comms.tail as any).promise = live;
    applyFieldReturn(g, dep(), read('case1_symbol_kept.json'));
    expect(g.comms.tail.promise).toEqual(live);
  });
});

describe('필드에 남겨진 대표 승계(사용자 답 2026-10-29)', () => {
  function leftReturn(g: Game, leftBehind: string[], missing: string[] = []) {
    const sent = [...leftBehind, ...missing];
    const departure: FieldDeparture = {
      ...dep(), segment: g.seg, domestic: false, promises: [],
      roster: sent.map(id => ({ id, comm: id === CAPTAIN_ID ? 'front' : PROFILES.find(p => p.id === id)!.community })),
    };
    const receipt: FieldReceipt = {
      ...read<FieldReceipt>('case3_nosymbol_kept.json'), stock: {}, fieldPromises: [],
      people: { sent, injured: [], bitten: [], dead: [], leftBehind, missing, rescued: [] },
    };
    return { departure, receipt };
  }

  it.each(['leftBehind', 'missing'] as const)('S1a 대표의 %s: 같은 칸의 새 대표, 주 난수 두 번, 일지와 자리 초기화', kind => {
    const g = createGame(SEED);
    const c = 'engine';
    const s = g.comms[c];
    const old = structuredClone(s.leader);
    const used = [...g.usedProfiles];
    const rng = nextRandom(nextRandom(g.rng).rng).rng;
    s.sick = { since: g.seg, rep: old };
    s.debt = true;
    s.promise = { kind: 'open', cond: { kind: 'skip_dispatch', label: '파견 제외', now: false }, label: '파견 제외', due: g.seg + 1, madeSession: 0 };
    const { departure, receipt } = leftReturn(g, kind === 'leftBehind' ? [old.personId] : [], kind === 'missing' ? [old.personId] : []);
    applyFieldReturn(g, departure, receipt);
    const who = PROFILES.find(p => p.id === s.leader.personId)!;
    expect(who.community).toBe(c);
    expect(who.age).toBeGreaterThanOrEqual(REP_AGE[c][0]);
    expect(who.age).toBeLessThanOrEqual(REP_AGE[c][1]);
    expect(s.leader.personId).not.toBe(old.personId);
    expect(used).not.toContain(who.id);
    expect(g.usedProfiles).toEqual([...used, who.id]);
    expect(g.left).toEqual([old.name]);
    expect(s.leader.trait).not.toBe(old.trait);
    expect(s.leader.trait).not.toBe(TRAIT_BAN[c]);
    expect(s.leader.traitShown).toBe(0);
    expect(s.sick).toBeUndefined();
    expect(s.debt).toBe(false);
    expect(s.promise).toBeNull();
    expect(g.rng).toEqual(rng);
    expect(g.journal).toContainEqual({ seg: g.seg, text: `${who.name}이(가) ${COMM_NAME[c]} 대표 자리를 이었다.`, tone: 'dark' });
    const once = JSON.stringify(g);
    expect(applyFieldReturn(g, departure, receipt).status).toBe('duplicate');
    expect(JSON.stringify(g)).toBe(once);
  });

  /** 대표가 아닌 그 칸 사람 하나. */
  const plainOf = (g: Game, c: Comm) => PROFILES.find(p => p.community === c && p.id !== g.comms[c].leader.personId)!;

  it('남겨짐과 사라짐에 함께 든 사람은 인구에서 한 번만 빠진다(묶음 점검 L2)', () => {
    const g = createGame(SEED);
    const p = plainOf(g, 'medtech');
    g.comms.medtech.pop = 5;
    const { departure, receipt } = leftReturn(g, [p.id], [p.id]);
    applyFieldReturn(g, { ...departure, roster: [departure.roster[0]] }, { ...receipt, people: { ...receipt.people, sent: [p.id] } });
    expect(g.comms.medtech.pop).toBe(4);
    expect(g.left).toEqual([p.name]);
    expect(g.leftShort).toBeUndefined();
  });

  it('하한 1에 막혀 못 뺀 사람은 적어 두고, 구조되어 와도 그만큼은 다시 더하지 않는다(묶음 점검 M1)', () => {
    const g = createGame(SEED);
    const p = plainOf(g, 'medtech');
    g.comms.medtech.pop = 1;
    const out = leftReturn(g, [p.id]);
    applyFieldReturn(g, out.departure, out.receipt);
    expect(g.comms.medtech.pop).toBe(1);
    expect(g.leftShort).toEqual({ medtech: 1 });
    expect(g.left).toEqual([p.name]);
    const back = leftReturn(g, []);
    applyFieldReturn(g, { ...back.departure, departureId: 'dep_rescue_1', stopId: 'stop_rescue_1', roster: [{ ...out.departure.roster[0] }] },
      { ...back.receipt, receiptId: 'ret_rescue_1', departureId: 'dep_rescue_1', stopId: 'stop_rescue_1', people: { ...back.receipt.people, sent: [p.id], rescued: [p.id] } });
    expect(g.left).toEqual([]);
    expect(g.comms.medtech.pop).toBe(1);
    expect(g.leftShort).toBeUndefined();
  });

  /** 첫 정차에 선 판(target_rotation.test.ts와 같은 길). */
  function atStop(seed = SEED): Game {
    const g = createGame(seed);
    for (let i = 0; i < 80 && !(g.phase === 'stop' && g.stop && !g.stop.done); i += 1) {
      if (g.cards.length) { const c = g.cards[0]; chooseCard(g, c.uid, viewCard(g, c).choices.findIndex(x => !x.disabled)); continue; }
      advance(g);
    }
    return g;
  }

  it('이번 정차가 기한인 그 칸 약속은 대표를 잇기 전에 지킴·어김으로 판정된다', () => {
    const g = atStop();
    expect(g.phase).toBe('stop');
    const c = 'engine';
    const s = g.comms[c];
    const old = structuredClone(s.leader);
    const other = (['coal', 'food', 'medicine', 'luxury'] as const).find(t => t !== g.stop!.target)!;
    s.promise = { kind: 'open', cond: { kind: 'target', label: '그 갈래를 노린다', now: false, target: other }, label: '그 갈래를 노린다', due: g.seg, madeSession: 0 };
    const broken = g.stats.promisesBroken;
    const { departure, receipt } = leftReturn(g, [old.personId]);
    applyFieldReturn(g, departure, receipt);
    expect(g.stop!.done).toBe(true);
    expect(g.stats.promisesBroken).toBe(broken + 1);
    expect(s.leader.personId).not.toBe(old.personId);
    expect(s.promise).toBeNull();
  });

  it('대표 아닌 사람은 떠난 명단에만 들어가고 대표와 난수는 그대로다', () => {
    const g = createGame(SEED);
    const who = PROFILES.find(p => p.community === 'engine' && p.id !== g.comms.engine.leader.personId)!;
    const leaders = COMMS.map(c => structuredClone(g.comms[c].leader));
    const rng = structuredClone(g.rng);
    const { departure, receipt } = leftReturn(g, [who.id]);
    applyFieldReturn(g, departure, receipt);
    expect(g.left).toEqual([who.name]);
    expect(COMMS.map(c => g.comms[c].leader)).toEqual(leaders);
    expect(g.rng).toEqual(rng);
    expect(g.journal.some(row => row.text.endsWith('대표 자리를 이었다.'))).toBe(false);
  });

  it.each(['leftBehind', 'missing'] as const)('열차장의 %s는 떠난 명단이나 대표에 영향을 주지 않는다', kind => {
    const g = createGame(SEED);
    const leaders = COMMS.map(c => structuredClone(g.comms[c].leader));
    const rng = structuredClone(g.rng);
    const { departure, receipt } = leftReturn(g, kind === 'leftBehind' ? [CAPTAIN_ID] : [], kind === 'missing' ? [CAPTAIN_ID] : []);
    applyFieldReturn(g, departure, receipt);
    expect(g.left ?? []).toEqual([]);
    expect(COMMS.map(c => g.comms[c].leader)).toEqual(leaders);
    expect(g.rng).toEqual(rng);
  });

  it.each([false, true])('함께 남겨진 사람은 후임에서 제외한다(대체 풀=%s)', fallback => {
    const g = createGame(SEED);
    const c = 'engine';
    if (fallback) g.usedProfiles = PROFILES.map(p => p.id);
    const old = structuredClone(g.comms[c].leader);
    const probe = structuredClone(g);
    probe.left = [old.name];
    // 전원을 먼저 명단에 넣지 않으면 첫 후임으로 뽑힐 사람을 함께 남긴다.
    const companion = drawPerson(probe, c, REP_AGE[c]);
    const rng = nextRandom(nextRandom(g.rng).rng).rng;
    const { departure, receipt } = leftReturn(g, [old.personId], [companion.id]);
    applyFieldReturn(g, departure, receipt);
    expect(g.left).toEqual([old.name, companion.name]);
    expect([old.personId, companion.id]).not.toContain(g.comms[c].leader.personId);
    expect(g.rng).toEqual(rng);
    expect(g.journal.filter(row => row.text.endsWith('대표 자리를 이었다.'))).toHaveLength(1);
    if (fallback) expect(g.usedProfiles).toEqual(PROFILES.map(p => p.id));
  });

  it('대체 풀은 사용한 프로필·나이 제한을 풀되 떠난 사람과 죽은 사람은 뺀다', () => {
    const g = createGame(SEED);
    const c = 'engine';
    const old = g.comms[c].leader;
    const survivor = PROFILES.find(p => p.community === c && p.age < REP_AGE[c][0])!;
    const others = PROFILES.filter(p => p.community === c && p.id !== old.personId && p.id !== survivor.id);
    g.left = others.slice(1).map(p => p.name);
    g.deaths = [others[0].name];
    g.usedProfiles = PROFILES.map(p => p.id);
    const { departure, receipt } = leftReturn(g, [old.personId]);
    applyFieldReturn(g, departure, receipt);
    expect(g.comms[c].leader.personId).toBe(survivor.id);
    expect(g.usedProfiles).toEqual(PROFILES.map(p => p.id));
  });

  it('dark 판은 하차 명령의 repGone과 같은 대표·일지·두 난수 상태를 낸다', () => {
    const g = createGame(SEED);
    enableDark(g);
    const c = 'engine';
    const old = g.comms[c].leader;
    const expected = structuredClone(g);
    expected.left = [old.name];
    repGone(expected, c, old.personId);
    const { departure, receipt } = leftReturn(g, [old.personId]);
    applyFieldReturn(g, departure, receipt);
    expect(g.comms[c].leader).toEqual(expected.comms[c].leader);
    expect(g.rng).toEqual(expected.rng);
    expect(g.dark!.rng).toEqual(expected.dark!.rng);
    expect(g.usedProfiles).toEqual(expected.usedProfiles);
    expect(g.journal).toContainEqual(expected.journal.at(-1));
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
