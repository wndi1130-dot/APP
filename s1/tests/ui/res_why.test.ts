import { describe, expect, it } from 'vitest';
import { createS1cGame, forecast, viewCard } from '../../src/game';
import type { Game } from '../../src/game';
import { RES_ROWS, resRows, resUse } from '../../src/ui/panels';
import { RES_LOG_MAX, applyStep } from '../../src/ui/repro';

// 자원이 어디에 얼마 드는지와 무엇 때문에 바뀌었나(사용자 2026-10-11).

function act(g: Game): { a: string; d: Record<string, string> } {
  if (g.phase === 'stop' && g.stop && !g.stop.done) return { a: 'stop-go', d: { go: '1' } };
  for (const card of g.cards) {
    const index = viewCard(g, card).choices.findIndex(ch => !ch.disabled);
    if (index >= 0) return { a: 'choose', d: { uid: String(card.uid), index: String(index) } };
  }
  return { a: 'advance', d: {} };
}

describe('자원 까닭 창', () => {
  it('드는 곳의 합은 화면의 구간 예고와 같다', () => {
    const g = createS1cGame('res-1');
    for (const key of ['coal', 'food'] as const) {
      const use = resUse(g, key);
      expect(use.total).toBe(forecast(g)[key]);
      expect(use.rows.reduce((sum, r) => sum + r.v, 0)).toBeCloseTo(use.total, 6);
      expect(use.rows.length).toBeGreaterThan(1);
      // 큰 것부터(맨 끝의 '그 밖'은 빼고 견준다)
      const main = use.rows.filter(r => !r.label.startsWith('그 밖')).map(r => r.v);
      expect(main).toEqual([...main].sort((a, b) => b - a));
    }
    expect(resUse(g, 'coal').rows.some(r => r.label === '기관 운행')).toBe(true);
  });

  it('자원의 보이는 값이 바뀐 행동마다 한 줄이 남고, 값은 그 차이와 같다', () => {
    const g = createS1cGame('res-2');
    let rows = 0;
    for (let n = 0; n < 60 && g.phase !== 'end' && g.phase !== 'council'; n += 1) {
      const before = { coal: Math.round(g.coal), food: Math.round(g.food), med: Math.round(g.med), lux: Math.round(g.lux), len: g.resLog?.length ?? 0, seg: g.seg };
      applyStep(g, act(g));
      const d = [Math.round(g.coal) - before.coal, Math.round(g.food) - before.food, Math.round(g.med) - before.med, Math.round(g.lux) - before.lux];
      const log = g.resLog ?? [];
      if (d.every(v => v === 0)) { expect(log.length).toBe(before.len); continue; }
      rows += 1;
      const last = log[log.length - 1];
      expect([last.coal, last.food, last.med, last.lux, last.seg]).toEqual([...d, before.seg]);
      expect(last.label.length).toBeGreaterThan(0);
    }
    expect(rows).toBeGreaterThan(0);
  });

  it('준 일과 는 일을 갈라 최근 것부터 보이고, 기록은 상한까지만 남는다', () => {
    const g = createS1cGame('res-3');
    g.resLog = Array.from({ length: RES_LOG_MAX }, (_, i) => ({ seg: i + 1, label: `일 ${i + 1}`, coal: i % 2 ? -3 : 5, food: 0, med: 0, lux: 0 }));
    const { out, into } = resRows(g, 'coal');
    expect(out.length).toBe(RES_ROWS);
    expect(into.length).toBe(RES_ROWS);
    expect(out[0]).toEqual({ seg: 24, label: '일 24', v: -3 });
    expect(into[0]).toEqual({ seg: 23, label: '일 23', v: 5 });
    expect(resRows(g, 'food')).toEqual({ out: [], into: [] });
    expect(JSON.parse(JSON.stringify(g)).resLog).toEqual(g.resLog);
  });

  it('기록이 없는 판(봇 판, 옛 저장)에서는 빈 목록이다', () => {
    const g = createS1cGame('res-4');
    expect('resLog' in g).toBe(false);
    expect(resRows(g, 'med')).toEqual({ out: [], into: [] });
  });
});
