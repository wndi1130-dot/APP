import { describe, expect, it } from 'vitest';
import { cloneGame, createGame } from '../../src/game';
import type { Game } from '../../src/game';
import { SAVE_VERSION, applyStep, makeBundle, readSave, replayBundle, reviveSave } from '../../src/ui/repro';
import type { Step, TrailEntry } from '../../src/ui/repro';

// 오류 재현 묶음(r8 출시 실무 3): 직전 저장에 마지막 행동을 다시 하면 같은 판이 나와야 한다.

/** app.ts의 step처럼: 사본에 하고, 기록을 남기고, 바꿔 끼운다. */
function run(g: Game, steps: Step[]) {
  const trail: TrailEntry[] = [];
  let prev: Game | null = null;
  for (const st of steps) {
    const next = cloneGame(g);
    trail.push({ ...st, seg: g.seg, phase: g.phase, t: 0 });
    prev = g;
    applyStep(next, st);
    g = next;
  }
  return { g, prev, trail };
}

describe('오류 재현 묶음', () => {
  it('직전 저장에 마지막 행동을 다시 하면 지금 저장과 같다', () => {
    let g = createGame('repro-1');
    const steps: Step[] = [];
    // 서류가 있으면 첫 선택지를 고르고, 없으면 다음으로 넘긴다. JSON을 거쳐도 같은지 본다.
    for (let i = 0; i < 40 && g.phase !== 'end'; i += 1) {
      const card = g.cards[0];
      const st: Step = card ? { a: 'choose', d: { uid: String(card.uid), index: '0' } } : { a: 'advance', d: {} };
      if (g.phase === 'council' && !card) st.a = 'vote';
      const r = run(g, [st]);
      steps.push(st);
      const b = JSON.parse(JSON.stringify(makeBundle(r.g, r.prev, r.trail, null)));
      const back = replayBundle(b);
      expect(back.thrown).toBeUndefined();
      expect(back.diff).toEqual([]);
      g = r.g;
    }
    expect(steps.length).toBeGreaterThan(10);
  });

  it('행동이 던지면 다시 할 때도 같은 오류가 난다', () => {
    const g = createGame('repro-2');
    const bad: Step = { a: '없는-행동', d: {} };
    const b = makeBundle(g, g, [{ ...bad, seg: g.seg, phase: g.phase, t: 0 }], { msg: '모르는 행동: 없는-행동', step: bad, t: 0 });
    const back = replayBundle(JSON.parse(JSON.stringify(b)));
    expect(back.thrown?.message).toBe('모르는 행동: 없는-행동');
  });

  it('레버와 거래도 같은 길로 간다', () => {
    const g = createGame('repro-3');
    const r = run(g, [{ a: 'lever', d: { comm: 'tail', which: 'ration', value: '2' } }]);
    expect(r.g.comms.tail.ration).toBe(2);
    expect(() => applyStep(cloneGame(g), { a: 'deal', d: { comm: 'tail', tool: 'bribe' } })).not.toThrow();
  });

  it('꼬리칸 공간 레버도 같은 길로 간다(6.4)', () => {
    const g = createGame('repro-4');
    const r = run(g, [{ a: 'space', d: { giver: 'front', step: '0' } }, { a: 'space', d: { step: '1' } }]);
    expect(r.g.space).toEqual({ step: 1, giver: 'front' });
    expect(applyStep(cloneGame(g), { a: 'space', d: { step: '1' } })).toBe('공간을 내줄 칸을 먼저 골라라');
  });
});

// 저장 판 읽기(A2 코드 구조 점검 5번): 뼈대 검사, 판 번호, 나중에 더한 칸 채우기.
describe('저장 판 읽기', () => {
  const json = (g: Game) => JSON.parse(JSON.stringify(g)) as Record<string, unknown>;

  it('정상 판은 그대로 읽고, 나중에 더한 칸이 빠진 옛 판은 채워 읽는다', () => {
    const g = createGame('save-1');
    const r = readSave(json(g));
    expect(r.ok && r.g).toEqual(g);
    const old = json(g);
    delete old.eventLog;
    delete old.linesSeen;
    const o = readSave(old);
    expect(o.ok).toBe(true);
    if (o.ok) expect([o.g.eventLog, o.g.linesSeen]).toEqual([{}, []]);
  });

  it('뼈대가 빠진 판은 까닭과 함께 못 읽는다', () => {
    const g = createGame('save-2');
    expect(readSave({ version: 1, seg: 1 })).toEqual({ ok: false, why: '시드가 없다' });
    expect(readSave(null).ok).toBe(false);
    expect(readSave([]).ok).toBe(false);
    const broken: [string, (x: Record<string, unknown>) => void][] = [
      ['난수 상태가 없다', x => { delete x.rng; }],
      ['모르는 단계: lunch', x => { x.phase = 'lunch'; }],
      ['수치가 이상하다: coal', x => { x.coal = null; }],
      ['공동체가 이상하다: guard', x => { delete (x.comms as Record<string, unknown>).guard; }],
      ['목록이 없다: cards', x => { x.cards = {}; }],
    ];
    for (const [why, hurt] of broken) {
      const x = json(g);
      hurt(x);
      expect(readSave(x), why).toEqual({ ok: false, why });
    }
    expect(reviveSave({ version: 1, seg: 1 })).toBeNull();
  });

  it('판 번호가 없거나 이 빌드보다 새 판이면 못 읽는다', () => {
    const x = json(createGame('save-3'));
    x.version = SAVE_VERSION + 1;
    expect(readSave(x)).toEqual({ ok: false, why: `더 새 빌드에서 저장한 판이다(판 번호 ${SAVE_VERSION + 1})` });
    delete x.version;
    expect(readSave(x)).toEqual({ ok: false, why: '판 번호가 없다' });
  });
});
