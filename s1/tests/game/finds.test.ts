import { describe, expect, it } from 'vitest';
import { COMMS, FIELDS, FINDS_MAX, createS1cGame, domesticStop, noteFind } from '../../src/game';
import { findsLine } from '../../src/ui/domestic';

// 설계도 조각·코어를 얻은 자리 기록(사용자 2026-10-11: 어디서 왔는지 안 보인다). 얻은 만큼만 적히고, 창에는 최근 셋만 나온다.

function stopAt(seed: string) {
  const g = createS1cGame(seed);
  g.stop = { place: 'factory', target: 'secret', stay: 'long', crewComm: COMMS[0], crewSize: 3, done: false, result: null };
  return g;
}

describe('조각·코어를 얻은 자리', () => {
  it('정차에서 얻은 조각·코어 수만큼 줄이 남고, 구간과 곳이 적힌다', () => {
    let frags = 0;
    let cores = 0;
    for (let i = 0; i < 40; i += 1) {
      const g = stopAt(`finds-${i}`);
      const d = g.dom!;
      const before = { f: FIELDS.reduce((n, f) => n + d.frags[f], 0), c: d.cores };
      domesticStop(g, false, 0);
      const gotF = FIELDS.reduce((n, f) => n + d.frags[f], 0) - before.f;
      const gotC = d.cores - before.c;
      const rows = d.finds ?? [];
      expect(rows.filter(r => r.what === 'frag')).toHaveLength(gotF);
      expect(rows.filter(r => r.what === 'core')).toHaveLength(gotC);
      for (const r of rows) expect(r).toMatchObject({ seg: g.seg, place: 'factory', via: 'stop' });
      for (const r of rows.filter(x => x.what === 'frag')) expect(['craft', 'engine']).toContain(r.field);
      frags += gotF;
      cores += gotC;
    }
    expect(frags).toBeGreaterThan(0);
    expect(cores).toBeGreaterThan(0);
  });

  it('지나친 정차에서는 아무것도 안 적힌다', () => {
    const g = stopAt('finds-pass');
    domesticStop(g, true, 0);
    expect(g.dom!.finds ?? []).toHaveLength(0);
  });

  it('오래된 줄부터 버리고, 창에는 그 분야의 최근 셋만 새것부터 나온다', () => {
    const g = createS1cGame('finds-line');
    const d = g.dom!;
    expect(findsLine(g, 'frag', 'engine')).toBe('');
    for (let s = 1; s <= FINDS_MAX + 3; s += 1) noteFind(d, { seg: s, place: 'factory', what: 'frag', field: s % 2 ? 'engine' : 'craft', via: 'stop' });
    noteFind(d, { seg: 99, place: 'freight', what: 'core', via: 'stop' });
    expect(d.finds).toHaveLength(FINDS_MAX);
    const line = findsLine(g, 'frag', 'engine');
    expect(line.match(/구간/g)).toHaveLength(3);
    expect(line.indexOf('15구간')).toBeLessThan(line.indexOf('13구간'));
    expect(line).not.toContain('99구간');
    expect(findsLine(g, 'core')).toContain('99구간');
    expect(findsLine(g, 'frag', 'radio')).toBe('');
  });
});
