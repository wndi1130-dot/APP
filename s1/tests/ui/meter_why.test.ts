import { describe, expect, it } from 'vitest';
import { cloneGame, createS1cGame, viewCard } from '../../src/game';
import type { Game } from '../../src/game';
import { METER_ROWS, meterRows } from '../../src/ui/panels';
import { METER_LOG_MAX, applyStep, stepLabel } from '../../src/ui/repro';

// 신임·긴장이 무엇 때문에 바뀌었나(사용자 2026-10-11): 화면에서 한 행동마다 보이는 값의 차이와 그 일의 이름을 남긴다.

/** 서류가 있으면 고를 수 있는 첫 칸을 고르고 없으면 넘긴다. 한 행동을 돌려준다. */
function act(g: Game): { a: string; d: Record<string, string> } {
  if (g.phase === 'stop' && g.stop && !g.stop.done) return { a: 'stop-go', d: { go: '1' } };
  for (const card of g.cards) {
    const index = viewCard(g, card).choices.findIndex(ch => !ch.disabled);
    if (index >= 0) return { a: 'choose', d: { uid: String(card.uid), index: String(index) } };
  }
  return { a: 'advance', d: {} };
}

describe('신임·긴장의 까닭 기록', () => {
  it('신임이나 긴장의 보이는 값이 바뀐 행동마다 한 줄이 남고, 값은 그 차이와 같다', () => {
    const g = createS1cGame('why-1');
    let rows = 0;
    for (let n = 0; n < 60 && g.phase !== 'end' && g.phase !== 'council'; n += 1) {
      const before = { trust: Math.round(g.trust), tension: Math.round(g.tension), len: g.meterLog?.length ?? 0, seg: g.seg };
      const step = act(g);
      const label = stepLabel(g, step);
      applyStep(g, step);
      const dt = Math.round(g.trust) - before.trust;
      const dn = Math.round(g.tension) - before.tension;
      const log = g.meterLog ?? [];
      if (dt === 0 && dn === 0) { expect(log.length).toBe(before.len); continue; }
      rows += 1;
      const last = log[log.length - 1];
      expect([last.trust, last.tension, last.seg]).toEqual([dt, dn, before.seg]);
      expect([label, '구간 정산']).toContain(last.label);
      expect(last.label.length).toBeGreaterThan(0);
    }
    expect(rows).toBeGreaterThan(0);
  });

  it('서류를 고른 줄은 서류 제목과 고른 말로 적힌다', () => {
    const g = createS1cGame('why-2');
    for (let n = 0; n < 40 && !g.cards.length; n += 1) applyStep(g, act(g));
    const card = g.cards[0];
    expect(card).toBeDefined();
    const label = stepLabel(g, { a: 'choose', d: { uid: String(card.uid), index: '0' } });
    expect(label).toMatch(/.+: .+/);
  });

  it('기록은 최근 것만 남고(상한), 창에는 그 수치가 움직인 줄만 최근 것부터 뜬다', () => {
    const g = createS1cGame('why-3');
    g.meterLog = Array.from({ length: METER_LOG_MAX }, (_, i) => ({ seg: i + 1, label: `일 ${i + 1}`, trust: i % 2 ? -1 : 0, tension: i % 2 ? 0 : 2 }));
    const trust = meterRows(g, 'trust');
    expect(trust.length).toBe(METER_ROWS);
    expect(trust[0]).toEqual({ seg: 12, label: '일 12', v: -1 });
    expect(trust.every(r => r.v !== 0)).toBe(true);
    expect(meterRows(g, 'tension')[0]).toEqual({ seg: 11, label: '일 11', v: 2 });
    // 한 줄 더 남기면 가장 옛 줄이 밀려난다
    const next = cloneGame(g);
    next.trust = Math.round(next.trust);
    next.meterLog = [...next.meterLog!, { seg: 13, label: '일 13', trust: 1, tension: 0 }].slice(-METER_LOG_MAX);
    expect(next.meterLog.length).toBe(METER_LOG_MAX);
    expect(next.meterLog[0].seg).toBe(2);
  });

  it('기록이 없는 판(봇 판, 옛 저장)에서는 빈 목록이다', () => {
    const g = createS1cGame('why-4');
    expect('meterLog' in g).toBe(false);
    expect(meterRows(g, 'trust')).toEqual([]);
  });

  it('저장·복원(JSON)을 거쳐도 남는다', () => {
    const g = createS1cGame('why-5');
    for (let n = 0; n < 60 && !(g.meterLog?.length) && g.phase !== 'end'; n += 1) applyStep(g, act(g));
    expect(g.meterLog?.length).toBeGreaterThan(0);
    expect(JSON.parse(JSON.stringify(g)).meterLog).toEqual(g.meterLog);
  });
});
