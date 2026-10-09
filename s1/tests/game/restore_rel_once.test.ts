import { describe, expect, it } from 'vitest';
import { cancelRestore, chooseCard, COMMS, createS1cGame, restartTech, restartWhy, standDown, startRestore, techRelSides, viewCard } from '../../src/game';
import type { Comm, Game } from '../../src/game';

describe('7.5 취소 악용: 같은 기술을 다시 시작해도 관계가 또 움직이지 않는다', () => {
  it('M5를 시작·취소해도 꼬리칸 +5는 한 번뿐', () => {
    const g = createS1cGame('rel-once');
    g.dom!.wood = 20;
    const tail0 = g.comms.tail.rel;
    const med0 = g.comms.medtech.rel;
    for (let i = 0; i < 3; i++) {
      expect(startRestore(g, 'm5', 'full')).toBe(true);
      cancelRestore(g);
    }
    expect(g.comms.tail.rel).toBe(tail0 + 5);
    expect(g.comms.medtech.rel).toBe(med0 - 5);
    expect(g.dom!.wood).toBe(14); // 목재는 매번 든다
  });

  it('변형을 오가도 관계는 쌓이지 않고 지금 변형 한 번 몫만 남는다(PC 리뷰 PR 57 1번)', () => {
    // E3은 관계가 시작이 아니라 추인 표결 때 움직여서(7.3, elder_pipe.test.ts) 양쪽이 있는 변형 기술 R2로 본다.
    const g = r2Game('rel-variant');
    const rel0 = rels(g);
    const go = (v: 'a' | 'b') => { expect(startRestore(g, 'r2', 'full', v)).toBe(true); cancelRestore(g); };
    go('a'); go('a'); go('b'); go('a'); go('b'); go('a');
    expect(diff(g, rel0)).toEqual(once('a'));
    go('b');
    expect(diff(g, rel0)).toEqual(once('b'));
  });

  it('갈래 카드 미리보기도 되돌림을 셈한 순증만 보인다', () => {
    const g = r2Game('rel-preview');
    expect(startRestore(g, 'r2', 'full', 'a')).toBe(true);
    cancelRestore(g);
    const v = viewCard(g, { uid: 1, kind: 'dom:fork', text: 'r2', n: 0 });
    const effs = (i: number) => Object.fromEntries(v.choices[i].effs.map(e => [(e as { c: Comm }).c, (e as { v: number }).v]));
    expect(effs(0)).toEqual({}); // 가를 다시: 그대로
    const want: Record<string, number> = {};
    for (const [c, n] of Object.entries(once('b'))) want[c] = n - (once('a')[c as Comm] ?? 0);
    for (const [c, n] of Object.entries(once('a'))) if (!(c in want)) want[c] = -n;
    for (const c of Object.keys(want)) if (want[c] === 0) delete want[c];
    expect(effs(1)).toEqual(want);
  });

  it('옛 저장(변형 칸 없는 시작 기록)은 이미 움직인 것으로 본다', () => {
    const g = r2Game('rel-old-save');
    g.dom!.log.restores.push({ seg: 0, id: 'r2' });
    const rel0 = rels(g);
    expect(startRestore(g, 'r2', 'full', 'a')).toBe(true);
    expect(diff(g, rel0)).toEqual({});
  });

  it('갈래 카드를 연 채 다른 복원을 먼저 시작하면 갈래는 못 고르고 관계도 안 움직인다(PC 리뷰 PR 57 2번)', () => {
    const g = r2Game('fork-busy');
    g.dom!.wood = 20;
    g.cards.push({ uid: 999, kind: 'dom:fork', text: 'r2', n: 0 });
    expect(startRestore(g, 'm5', 'full')).toBe(true);
    const rel0 = rels(g);
    const v = viewCard(g, g.cards.find(c => c.uid === 999)!);
    expect(v.choices[0].disabled).toBeTruthy();
    expect(v.choices[1].disabled).toBeTruthy();
    expect(chooseCard(g, 999, 0)).toBe(false);
    const later = v.choices.findIndex(c => c.label === '나중에');
    expect(later).toBeGreaterThanOrEqual(0);
    expect(chooseCard(g, 999, later)).toBe(true);
    expect(diff(g, rel0)).toEqual({});
    expect(g.dom!.restoring).toBe('m5');
  });
});

function r2Game(seed: string): Game {
  const g = createS1cGame(seed);
  const d = g.dom!;
  d.parts = 80; d.frags.radio = 10;
  d.techs.r1 = { stage: 'done' } as NonNullable<typeof d.techs.r1>;
  return g;
}

function rels(g: Game): Record<Comm, number> {
  return Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel])) as Record<Comm, number>;
}

function diff(g: Game, before: Record<Comm, number>): Partial<Record<Comm, number>> {
  const out: Partial<Record<Comm, number>> = {};
  for (const c of COMMS) if (g.comms[c].rel !== before[c]) out[c] = g.comms[c].rel - before[c];
  return out;
}

/** 그 변형을 한 번 시작했을 때의 관계 몫 */
function once(v: 'a' | 'b'): Partial<Record<Comm, number>> {
  const s = techRelSides('r2', v);
  const out: Partial<Record<Comm, number>> = {};
  for (const c of s.like) out[c] = (out[c] ?? 0) + 5;
  for (const c of s.dislike) out[c] = (out[c] ?? 0) - 5;
  return out;
}

describe('세웠다 다시 돌리기로 부품이 늘지 않는다(PC 리뷰 PR 57 3번)', () => {
  it('세울 때 받은 부품 1을 다시 돌릴 때 낸다', () => {
    const g = createS1cGame('stand-restart');
    const d = g.dom!;
    d.techs.m3 = { stage: 'done', variant: 'a' } as NonNullable<typeof d.techs.m3>;
    d.techs.r1 = { stage: 'done' } as NonNullable<typeof d.techs.r1>;
    d.techs.r2 = { stage: 'done', variant: 'a' } as NonNullable<typeof d.techs.r2>;
    d.parts = 0;
    const id = standDown(g);
    expect(id).not.toBeNull();
    expect(d.parts).toBe(1);
    d.parts = 0;
    expect(restartWhy(g, id!)).toBeTruthy();
    restartTech(g, id!);
    expect(d.techs[id!]!.off).toBe(true);
    d.parts = 1;
    restartTech(g, id!);
    expect(d.techs[id!]!.off).toBe(false);
    expect(d.parts).toBe(0);
  });
});
