import { describe, expect, it } from 'vitest';
import { createGame, enableDark, PLACES, resolveStop, STAY } from '../../src/game';
import type { Game } from '../../src/game';
import { level, openCase, punish, PUNISH_PROOF_REL } from '../../src/game/dark/cases';
import type { Punish } from '../../src/game/dark/cases';
import { adults, byId, nameOf } from '../../src/game/dark/state';
import type { Clue, Suspect } from '../../src/game/dark/state';

// K02 판정(/mnt/project-files/s1b_wip/k02_verdict.md)의 남은 높음 둘(3·4).

function darkGame(seed: string): Game {
  const g = createGame(seed);
  enableDark(g);
  g.seg = 4;
  return g;
}

describe('K02 3. 정차 암살의 목격자와 정차 영수증', () => {
  function stopOrder(seed: string) {
    const g = darkGame(seed);
    const target = adults(g, 'front', { noRep: true })[0].id;
    const exe = adults(g, 'guard', { noRep: true })[0].id;
    g.dark!.order = { target, why: 'hostile', exe: 'guard', exeId: exe, method: 'stop', at: g.seg };
    g.stop = { place: PLACES[0].id, target: 'coal', stay: Object.keys(STAY)[0] as never, crewComm: 'tail', crewSize: 4, done: false, result: null };
    return { g, target, exe };
  }

  it('정차 결과에 정찰 약속 밖의 죽음이나 부상이 한 줄로 붙는다', () => {
    const kinds = new Set<string>();
    for (let i = 0; i < 30; i += 1) {
      const { g, target } = stopOrder(`k02-3-note-${i}`);
      const res = resolveStop(g, true)!;
      expect(g.dark!.order).toBeNull();
      const lines = res.notes.filter(n => n.startsWith('정찰 약속 밖의'));
      expect(lines).toHaveLength(1);
      expect(lines[0]).toContain(nameOf(g, target));
      kinds.add(lines[0].startsWith('정찰 약속 밖의 죽음') ? 'dead' : 'hurt');
    }
    expect(kinds).toEqual(new Set(['dead', 'hurt']));
  });

  it('성공하면 장면의 목격자는 같이 나간 사람의 프로필 id이고, 죽은 대상은 빠진다', () => {
    let ok = 0;
    for (let i = 0; i < 30 && ok === 0; i += 1) {
      const { g, target, exe } = stopOrder(`k02-3-wit-${i}`);
      resolveStop(g, true);
      const s = g.dark!.scenes.find(x => x.key === 'order');
      if (!s) continue;
      ok += 1;
      expect(s.witnesses.length).toBeGreaterThan(0);
      for (const id of s.witnesses) expect(byId(id)).toBeDefined();
      expect(s.witnesses).not.toContain(target);
      expect(s.witnesses).toContain(exe);
    }
    expect(ok).toBe(1);
  });

  it('지나치면 명령은 남고 영수증에 줄이 없다', () => {
    const { g } = stopOrder('k02-3-pass');
    const res = resolveStop(g, false)!;
    expect(g.dark!.order).not.toBeNull();
    expect(res.notes.some(n => n.startsWith('정찰 약속 밖의'))).toBe(false);
  });
});

describe('K02 4. 벌의 반응은 증거 단계를 따른다', () => {
  const clue = (kind: Clue['kind'], truth: boolean): Clue => ({ kind, truth, line: `${kind} 단서 줄`, seg: 4 });
  const CLUES: Record<0 | 1 | 2, Clue[]> = {
    0: [],
    1: [clue('foot', false)],
    2: [clue('item', true), clue('witness', true)],
  };

  function punished(lv: 0 | 1 | 2, how: Punish) {
    const g = darkGame(`k02-4-${lv}-${how}`);
    const actor = adults(g, 'tail', { noRep: true })[0].id;
    const c = openCase(g, { kind: 'heating', culprit: actor, victimComm: 'front', dead: false, clock: 3, where: '앞칸' });
    const s = c.sus.find(x => x.culprit) as Suspect;
    s.proxyFor = undefined; // 시킨 사람 굴림을 빼서 관계 값만 본다
    s.clues = [...CLUES[lv]];
    expect(level(s)).toBe(lv);
    const tail = g.comms.tail.rel;
    const front = g.comms.front.rel;
    const journal = g.journal.length;
    const lines = punish(g, c, s, how, 'trial');
    return { g, lines, tail: g.comms.tail.rel - tail, front: g.comms.front.rel - front, journal: g.journal.slice(journal).map(j => j.text) };
  }

  it('배급 처벌: 소문 −5, 정황 −3, 증거 −2', () => {
    expect([0, 1, 2].map(lv => punished(lv as 0 | 1 | 2, 'ration').tail)).toEqual([-5, -3, -2]);
  });

  it('하차: 소문 −12, 정황 −8, 증거 −4', () => {
    expect([0, 1, 2].map(lv => punished(lv as 0 | 1 | 2, 'exile').tail)).toEqual([-12, -8, -4]);
  });

  it('증거로 벌하면 피해 칸 관계가 오르고, 소문·정황이면 그대로다', () => {
    expect(punished(2, 'confine').front).toBe(PUNISH_PROOF_REL);
    expect(punished(1, 'confine').front).toBe(0);
    expect(punished(0, 'confine').front).toBe(0);
  });

  it('소문으로 벌하면 억울하다는 일지 줄이 남고, 다른 단계엔 없다', () => {
    expect(punished(0, 'ration').journal.some(t => t.includes('억울하다'))).toBe(true);
    expect(punished(1, 'ration').journal.some(t => t.includes('억울하다'))).toBe(false);
    expect(punished(2, 'ration').journal.some(t => t.includes('억울하다'))).toBe(false);
  });

  it('결과 줄에 무엇을 보고 벌했는지 단계와 단서 한 줄이 붙는다', () => {
    expect(punished(0, 'ration').lines).toContain('근거(소문): 단서는 없었다. 사람들이 그렇게 말했을 뿐이다.');
    expect(punished(1, 'ration').lines).toContain('근거(정황): foot 단서 줄');
    expect(punished(2, 'ration').lines).toContain('근거(증거): witness 단서 줄');
  });
});
