import { afterEach, describe, expect, it } from 'vitest';
import { COMMS, COMM_NAME, createS1cGame, D, LAWS, PROFILES, refreshSit, situation } from '../../src/game';
import type { Comm, Game } from '../../src/game';
import { HEAT_ALLOC_COMMS, heatAllocDeathLine, heatAllocSettle } from '../../src/game/domestic/heat_alloc';

// 「난방 배당」이 서 있는 동안의 값(결정 230·231·232·240·276). 정산마다 꼬리칸·의무진 관계 −2,
// 온기가 문턱(45) 아래인 칸(꼬리칸·의무진·경비대)마다 1할로 어른 한 사람이 죽는다. 죽은 사람은 수로만 적는다.

const OLD = { rel: D.heatAllocRel, warm: D.heatAllocWarm, death: D.heatAllocDeath };
afterEach(() => {
  D.heatAllocRel = OLD.rel; D.heatAllocWarm = OLD.warm; D.heatAllocDeath = OLD.death;
});

const fresh = (seed = 'heat-alloc'): Game => createS1cGame(seed);
const stand = (g: Game): void => { g.passed.heat_quota = g.seg; };
const warm = (g: Game, c: Comm): number => situation(g, c)[0];
/** 그 칸의 처지 온기를 v로 맞춘다(기준값만 옮긴다). */
function setWarm(g: Game, c: Comm, v: number): void {
  g.comms[c].base[0] += v - warm(g, c);
  expect(warm(g, c)).toBeCloseTo(v);
}
const allWarm = (g: Game, v: number): void => { for (const c of HEAT_ALLOC_COMMS) setWarm(g, c, v); };
const rng = (g: Game): string => JSON.stringify(g.rng);
const pops = (g: Game): Record<Comm, number> => Object.fromEntries(COMMS.map(c => [c, g.comms[c].pop])) as Record<Comm, number>;
const rels = (g: Game): Record<Comm, number> => Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel])) as Record<Comm, number>;
const byName = (name: string) => PROFILES.find(p => p.name === name);
const FORBIDDEN = ['막힌', '막혔', '잠긴', '잠겼', '격리', '가루', '분무', '소독', '씻기', '줄 세우', '머리 깎'];
const clean = (text: string): void => { for (const w of FORBIDDEN) expect(text).not.toContain(w); };

describe('값 줄', () => {
  it('관계 −2, 온기 문턱 45, 정산마다 1할', () => {
    expect(D.heatAllocRel).toBe(2);
    expect(D.heatAllocWarm).toBe(45);
    expect(D.heatAllocDeath).toBe(0.10);
  });
  it('온기 벌을 받는 세 칸에서 굴린다(꼬리칸·의무진·경비대)', () => {
    expect([...HEAT_ALLOC_COMMS]).toEqual(['tail', 'medtech', 'guard']);
  });
});

describe('법이 없으면 아무 일도 없다', () => {
  it('관계도 인구도 난수도 글도 안 바뀐다', () => {
    const g = fresh();
    allWarm(g, 10);
    D.heatAllocDeath = 1;
    const before = { rel: rels(g), pop: pops(g), rng: rng(g), journal: g.journal.length, deaths: g.deaths.length };
    const notes: string[] = [];
    heatAllocSettle(g, notes);
    expect(rels(g)).toEqual(before.rel);
    expect(pops(g)).toEqual(before.pop);
    expect(rng(g)).toBe(before.rng);
    expect(g.journal.length).toBe(before.journal);
    expect(g.deaths.length).toBe(before.deaths);
    expect(notes).toEqual([]);
  });
});

describe('관계 벌', () => {
  it('법이 서 있으면 한 번 부를 때 꼬리칸·의무진 관계가 −2, 경비대와 다른 칸은 그대로', () => {
    const g = fresh();
    stand(g);
    D.heatAllocDeath = 0;
    const before = rels(g);
    heatAllocSettle(g, []);
    const after = rels(g);
    expect(after.tail - before.tail).toBe(-2);
    expect(after.medtech - before.medtech).toBe(-2);
    for (const c of COMMS) if (c !== 'tail' && c !== 'medtech') expect(after[c]).toBe(before[c]);
  });

  it('한 정산에 한 번만 깎는다(한 번 부르면 −2, 죽음이 있어도 관계는 더 안 깎인다)', () => {
    const g = fresh();
    stand(g);
    allWarm(g, 10);
    D.heatAllocDeath = 1;
    const before = rels(g);
    heatAllocSettle(g, []);
    expect(rels(g).tail - before.tail).toBe(-2);
    expect(rels(g).medtech - before.medtech).toBe(-2);
  });

  it('폐지하면 그 정산부터 안 깎고 이미 깎인 것은 돌려주지 않는다', () => {
    const g = fresh();
    stand(g);
    D.heatAllocDeath = 0;
    const start = rels(g).tail;
    heatAllocSettle(g, []);
    heatAllocSettle(g, []);
    expect(rels(g).tail - start).toBe(-4);
    delete g.passed.heat_quota;
    heatAllocSettle(g, []);
    expect(rels(g).tail - start).toBe(-4);
  });

  it('정산 보고에 관계 줄이 한 줄 남고 금지한 낱말이 없다(세 가지를 돌려 쓴다)', () => {
    const lines = new Set<string>();
    for (let seg = 0; seg < 3; seg += 1) {
      const g = fresh();
      g.seg = seg;
      stand(g);
      D.heatAllocDeath = 0;
      const notes: string[] = [];
      heatAllocSettle(g, notes);
      expect(notes).toHaveLength(1);
      expect(notes[0]).toContain('꼬리칸·의무진 관계 −2');
      clean(notes[0]);
      lines.add(notes[0]);
    }
    expect(lines.size).toBe(3);
  });
});

describe('추운 칸의 죽음', () => {
  it('온기가 문턱 아래이고 난수가 확률보다 낮으면 그 칸 인구가 1 줄고 원인은 other', () => {
    const g = fresh();
    stand(g);
    allWarm(g, 80);
    setWarm(g, 'tail', 30);
    D.heatAllocDeath = 1;
    const before = { pop: pops(g), deaths: g.deaths.length, log: (g.deathLog ?? []).length };
    heatAllocSettle(g, []);
    expect(g.comms.tail.pop).toBe(before.pop.tail - 1);
    expect(g.comms.medtech.pop).toBe(before.pop.medtech);
    expect(g.comms.guard.pop).toBe(before.pop.guard);
    expect(g.deaths.length).toBe(before.deaths + 1);
    const log = g.deathLog ?? [];
    expect(log).toHaveLength(before.log + 1);
    expect(log[log.length - 1]).toMatchObject({ cause: 'other', comm: 'tail', name: g.deaths[g.deaths.length - 1] });
  });

  it('세 칸이 다 문턱 아래이면 칸마다 한 번씩, 최대 셋이 죽는다', () => {
    const g = fresh();
    stand(g);
    allWarm(g, 10);
    D.heatAllocDeath = 1;
    const before = g.deaths.length;
    heatAllocSettle(g, []);
    expect(g.deaths.length - before).toBe(3);
  });

  it('대표, 16살 미만, 65살 이상은 안 뽑힌다(많이 굴려도)', () => {
    const g = fresh();
    stand(g);
    D.heatAllocDeath = 1;
    D.heatAllocRel = 0;
    for (let i = 0; i < 40; i += 1) {
      allWarm(g, 10);
      heatAllocSettle(g, []);
    }
    expect(g.deaths.length).toBeGreaterThan(10);
    const leaders = COMMS.map(c => g.comms[c].leader.name);
    for (const name of g.deaths) {
      const p = byName(name);
      expect(p).toBeDefined();
      expect(p!.age).toBeGreaterThanOrEqual(16);
      expect(p!.age).toBeLessThanOrEqual(64);
      expect(leaders).not.toContain(name);
    }
    expect(new Set(g.deaths).size).toBe(g.deaths.length);
  });

  it('온기가 문턱 이상이면 난수를 안 부른다(난수 줄이 그대로)', () => {
    const g = fresh();
    stand(g);
    allWarm(g, D.heatAllocWarm);
    D.heatAllocDeath = 1;
    D.heatAllocRel = 0;
    const before = { rng: rng(g), deaths: g.deaths.length, pop: pops(g) };
    heatAllocSettle(g, []);
    expect(rng(g)).toBe(before.rng);
    expect(g.deaths.length).toBe(before.deaths);
    expect(pops(g)).toEqual(before.pop);
  });

  it('확률 0이면 아무 일 없고 난수도 안 쓴다', () => {
    const g = fresh();
    stand(g);
    allWarm(g, 10);
    D.heatAllocDeath = 0;
    D.heatAllocRel = 0;
    const before = { rng: rng(g), deaths: g.deaths.length, rel: rels(g) };
    const notes: string[] = [];
    heatAllocSettle(g, notes);
    expect(rng(g)).toBe(before.rng);
    expect(g.deaths.length).toBe(before.deaths);
    expect(rels(g)).toEqual(before.rel);
    expect(notes).toEqual([]);
  });

  it('값 줄 관계 벌과 확률이 0이면 옛 동작과 같다(법이 서 있어도)', () => {
    const g = fresh();
    stand(g);
    allWarm(g, 10);
    D.heatAllocRel = 0;
    D.heatAllocDeath = 0;
    const before = { rel: rels(g), pop: pops(g), rng: rng(g), journal: g.journal.length };
    const notes: string[] = [];
    heatAllocSettle(g, notes);
    expect({ rel: rels(g), pop: pops(g), rng: rng(g), journal: g.journal.length }).toEqual(before);
    expect(notes).toEqual([]);
  });

  it('칸에 뽑을 어른이 없으면 그 칸은 건너뛴다', () => {
    const g = fresh();
    stand(g);
    D.heatAllocRel = 0;
    D.heatAllocDeath = 1;
    allWarm(g, 80);
    setWarm(g, 'guard', 10);
    for (const p of PROFILES) if (p.community === 'guard' && p.age >= 16 && p.age <= 64) g.deaths.push(p.name);
    const before = { deaths: g.deaths.length, pop: g.comms.guard.pop };
    heatAllocSettle(g, []);
    expect(g.deaths.length).toBe(before.deaths);
    expect(g.comms.guard.pop).toBe(before.pop);
  });

  it('같은 씨앗으로 두 번 돌리면 같은 사람이 같은 정산에 죽는다', () => {
    const run = (): string[] => {
      const g = fresh('heat-alloc-same');
      stand(g);
      D.heatAllocDeath = 0.5;
      const out: string[] = [];
      for (let i = 0; i < 6; i += 1) {
        g.seg = i + 1;
        allWarm(g, 20);
        const before = g.deaths.length;
        heatAllocSettle(g, []);
        out.push(`${i}:${g.deaths.slice(before).join(',')}`);
      }
      return out;
    };
    const a = run();
    const b = run();
    expect(a).toEqual(b);
    expect(a.some(x => !x.endsWith(':'))).toBe(true);
  });
});

describe('단열이 짝이다', () => {
  it('꼬리칸 세 칸을 단열하면 온기가 문턱 위로 올라 굴림이 줄어든다', () => {
    const open = (insulated: boolean): { rng: string; rngBefore: string; deaths: number } => {
      const g = fresh('heat-alloc-ins');
      stand(g);
      D.heatAllocRel = 0;
      D.heatAllocDeath = 1;
      setWarm(g, 'medtech', 80);
      setWarm(g, 'guard', 80);
      setWarm(g, 'tail', 43);
      if (insulated) { g.dom!.insulated.push('tail1', 'tail2', 'tail3'); refreshSit(g); }
      expect(warm(g, 'tail') < D.heatAllocWarm).toBe(!insulated);
      const rngBefore = rng(g);
      heatAllocSettle(g, []);
      return { rng: rng(g), rngBefore, deaths: g.deaths.length };
    };
    const cold = open(false);
    const warmed = open(true);
    expect(cold.deaths).toBe(1);
    expect(cold.rng).not.toBe(cold.rngBefore);
    expect(warmed.deaths).toBe(0);
    expect(warmed.rng).toBe(warmed.rngBefore);
  });
});

describe('글: 죽은 사람은 수로만', () => {
  it('죽음 줄에 이름도 칸 이름도 금지한 낱말도 없다', () => {
    const names = [...PROFILES.map(p => p.name), ...Object.values(COMM_NAME)];
    for (let n = 1; n <= 5; n += 1) {
      const line = heatAllocDeathLine(n);
      clean(line);
      for (const w of names) expect(line).not.toContain(w);
    }
    expect(heatAllocDeathLine(1)).toContain('한 사람');
    expect(heatAllocDeathLine(3)).toContain('3명');
  });

  it('일지와 정산 보고에 수로 한 줄만 적히고 죽은 사람의 이름과 칸 이름은 없다', () => {
    const g = fresh();
    stand(g);
    allWarm(g, 10);
    D.heatAllocDeath = 1;
    const journalBefore = g.journal.length;
    const notes: string[] = [];
    heatAllocSettle(g, notes);
    const dead = g.deaths.slice(-3);
    expect(dead).toHaveLength(3);
    const added = g.journal.slice(journalBefore).map(j => j.text);
    expect(added).toContain(heatAllocDeathLine(3));
    expect(notes).toContain(heatAllocDeathLine(3));
    for (const text of [...added, ...notes.filter(t => !t.includes('관계'))]) {
      clean(text);
      for (const name of dead) expect(text).not.toContain(name);
      for (const w of Object.values(COMM_NAME)) expect(text).not.toContain(w);
    }
  });
});

describe('법 표', () => {
  it('미리보기 글에 새 두 줄이 있고 앞의 세 줄은 그대로다', () => {
    const changes = LAWS.heat_quota.changes;
    expect(changes.slice(0, 3)).toEqual(['난방 석탄 절반', '꼬리칸·의무진 온기 −10', '경비대 온기 −5']);
    expect(changes).toContain('서 있는 동안 정산마다 꼬리칸·의무진 관계 −2');
    expect(changes).toContain('온기 45 아래인 칸은 정산마다 1할로 한 사람을 잃는다');
    for (const line of changes) clean(line);
  });
});
