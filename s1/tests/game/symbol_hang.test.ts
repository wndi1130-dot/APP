import { describe, expect, it } from 'vitest';
import { COMMS, createGame, createS1cGame, domesticSettle, hangSymbol, hangWhy, symbolTick, SYM, unhangSymbol } from '../../src/game';
import type { Game } from '../../src/game';
import { applyStep, readSave } from '../../src/ui/repro';

// 상징물 걸기(제안): 내정을 켠 판에서 칸에 걸면 결속이 구간마다 조금 오르고, 내리거나 잃으면 한 번 크게 깎인다.
const near = (a: number, b: number) => expect(a).toBeCloseTo(b, 9);

function withSymbols(n: number, seed = 'sym-hang'): Game {
  const g = createS1cGame(seed);
  g.symbols = n;
  return g;
}

describe('상징물 걸기: 걸 수 있는 조건', () => {
  it('상징물이 0이면 못 건다', () => {
    const g = withSymbols(0);
    expect(hangWhy(g, 'engine')).toBeTruthy();
    expect(hangSymbol(g, 'engine')).toBe(false);
    expect(g.dom!.hung).toEqual([]);
  });

  it('한 칸에는 하나만 걸린다', () => {
    const g = withSymbols(3);
    expect(hangSymbol(g, 'engine')).toBe(true);
    expect(hangWhy(g, 'engine')).toContain('이미');
    expect(hangSymbol(g, 'engine')).toBe(false);
    expect(g.dom!.hung).toEqual(['engine']);
  });

  it('안 건 상징물이 있어야 건다: 가진 수만큼만', () => {
    const g = withSymbols(2);
    expect(hangSymbol(g, 'engine')).toBe(true);
    expect(hangSymbol(g, 'guard')).toBe(true);
    expect(hangWhy(g, 'front')).toBeTruthy();
    expect(hangSymbol(g, 'front')).toBe(false);
    expect(g.dom!.hung).toEqual(['engine', 'guard']);
  });

  it('걸거나 내려도 상징물 개수는 그대로다', () => {
    const g = withSymbols(2);
    hangSymbol(g, 'engine');
    expect(g.symbols).toBe(2);
    unhangSymbol(g, 'engine');
    expect(g.symbols).toBe(2);
  });
});

describe('상징물 걸기: 정산', () => {
  it('걸린 칸만 정산마다 결속이 cohPerSeg씩 오른다', () => {
    const g = withSymbols(1);
    hangSymbol(g, 'tail');
    const before = Object.fromEntries(COMMS.map(c => [c, g.comms[c].coh]));
    const rel = g.comms.tail.rel;
    symbolTick(g, []);
    symbolTick(g, []);
    near(g.comms.tail.coh, before.tail + 2 * SYM.cohPerSeg);
    for (const c of COMMS) if (c !== 'tail') expect(g.comms[c].coh).toBe(before[c]);
    expect(g.comms.tail.rel).toBe(rel);
  });

  it('domesticSettle 안에서 불린다', () => {
    const g = withSymbols(1);
    hangSymbol(g, 'tail');
    const notes: string[] = [];
    g.symbols = 0; // 모자라게 된 채 정산하면 내려간다: 정산 훅이 symbolTick을 부른다는 증거
    domesticSettle(g, notes);
    expect(g.dom!.hung).toEqual([]);
    expect(notes.some(n => n.includes('상징물'))).toBe(true);
  });

  it('결속은 1을 넘지 않는다', () => {
    const g = withSymbols(1);
    g.comms.engine.coh = 0.995;
    hangSymbol(g, 'engine');
    symbolTick(g, []);
    expect(g.comms.engine.coh).toBe(1);
  });

  it('난수를 쓰지 않는다', () => {
    const g = withSymbols(2);
    hangSymbol(g, 'tail');
    hangSymbol(g, 'front');
    const rng = JSON.stringify(g.rng);
    symbolTick(g, []);
    expect(JSON.stringify(g.rng)).toBe(rng);
  });
});

describe('상징물 걸기: 내림과 잃음', () => {
  it('내리면 그 칸 결속·관계가 한 번 깎이고 일지가 남는다', () => {
    const g = withSymbols(1);
    hangSymbol(g, 'guard');
    const coh = g.comms.guard.coh;
    const rel = g.comms.guard.rel;
    const logs = g.journal.length;
    expect(unhangSymbol(g, 'guard')).toBe(true);
    near(g.comms.guard.coh, coh - SYM.lossCoh);
    expect(g.comms.guard.rel).toBe(rel - SYM.lossRel);
    expect(g.journal.length).toBe(logs + 1);
    expect(g.dom!.hung).toEqual([]);
    expect(unhangSymbol(g, 'guard')).toBe(false); // 걸려 있지 않으면 아무 일도 없다
    near(g.comms.guard.coh, coh - SYM.lossCoh);
  });

  it('결속·관계는 범위 밖으로 내려가지 않는다', () => {
    const g = withSymbols(1);
    hangSymbol(g, 'tail');
    g.comms.tail.coh = 0.03;
    g.comms.tail.rel = -99;
    unhangSymbol(g, 'tail');
    expect(g.comms.tail.coh).toBe(0);
    expect(g.comms.tail.rel).toBe(-100);
  });

  it('g.symbols가 줄면 나중에 건 칸부터 넘친 만큼 내려가고 깎인다', () => {
    const g = withSymbols(3);
    hangSymbol(g, 'engine');
    hangSymbol(g, 'guard');
    hangSymbol(g, 'front');
    g.symbols = 1; // 사건에서 둘을 내줬다
    const b = Object.fromEntries(COMMS.map(c => [c, { coh: g.comms[c].coh, rel: g.comms[c].rel }]));
    const notes: string[] = [];
    symbolTick(g, notes);
    expect(g.dom!.hung).toEqual(['engine']);
    expect(notes.length).toBe(2);
    for (const c of ['guard', 'front'] as const) {
      near(g.comms[c].coh, b[c].coh - SYM.lossCoh);
      expect(g.comms[c].rel).toBe(b[c].rel - SYM.lossRel);
    }
    near(g.comms.engine.coh, b.engine.coh + SYM.cohPerSeg); // 남은 칸은 깎이지 않고 오른다
    expect(g.comms.engine.rel).toBe(b.engine.rel);
  });

  it('상징물이 0이 되면 모두 내려간다', () => {
    const g = withSymbols(1);
    hangSymbol(g, 'tail');
    g.symbols = 0;
    symbolTick(g, []);
    expect(g.dom!.hung).toEqual([]);
  });
});

describe('상징물 걸기: 저장과 이주', () => {
  it('JSON 저장·복원 뒤에도 걸린 채 이어진다', () => {
    const g = withSymbols(2);
    hangSymbol(g, 'front');
    hangSymbol(g, 'tail');
    const r = readSave(JSON.parse(JSON.stringify(g)));
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(r.g.dom!.hung).toEqual(['front', 'tail']);
    const before = r.g.comms.front.coh;
    symbolTick(r.g, []);
    near(r.g.comms.front.coh, before + SYM.cohPerSeg);
  });

  it('옛 저장(hung 없음)은 빈 목록으로 이어진다', () => {
    const g = withSymbols(1);
    const raw = JSON.parse(JSON.stringify(g));
    delete raw.dom.hung;
    const r = readSave(raw);
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(r.g.dom!.hung).toEqual([]);
    expect(hangSymbol(r.g, 'tail')).toBe(true);
  });

  it('새 내정 판은 빈 목록으로 시작한다', () => {
    expect(createS1cGame('sym-new').dom!.hung).toEqual([]);
  });
});

describe('상징물 걸기: 화면 입력 경로(applyStep)', () => {
  it('dom-hang으로 걸고 내린다', () => {
    const g = withSymbols(1);
    expect(applyStep(g, { a: 'dom-hang', d: { comm: 'engine', on: '1' } })).toBeNull();
    expect(g.dom!.hung).toEqual(['engine']);
    const coh = g.comms.engine.coh;
    expect(applyStep(g, { a: 'dom-hang', d: { comm: 'engine', on: '0' } })).toBeNull();
    expect(g.dom!.hung).toEqual([]);
    near(g.comms.engine.coh, coh - SYM.lossCoh);
  });

  it('걸기가 안 되면 까닭 글을 돌려준다', () => {
    const g = withSymbols(0);
    const why = applyStep(g, { a: 'dom-hang', d: { comm: 'engine', on: '1' } });
    expect(why).toBe(hangWhy(g, 'engine'));
    expect(g.dom!.hung).toEqual([]);
  });
});

describe('상징물 걸기: 내정을 끈 판', () => {
  it('아무 일도 없다', () => {
    const g = createGame('sym-off');
    g.symbols = 3;
    const coh = g.comms.engine.coh;
    expect(g.dom).toBeUndefined();
    expect(hangWhy(g, 'engine')).toBeTruthy();
    expect(hangSymbol(g, 'engine')).toBe(false);
    expect(unhangSymbol(g, 'engine')).toBe(false);
    const notes: string[] = [];
    symbolTick(g, notes);
    expect(notes).toEqual([]);
    expect(g.comms.engine.coh).toBe(coh);
    expect(g.dom).toBeUndefined();
  });
});
