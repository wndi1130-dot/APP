import { describe, expect, it } from 'vitest';
import { advance, chooseCard, createGame, crewNames, enableDark, viewCard } from '../../src/game';
import type { Game } from '../../src/game';
import { corpseTick } from '../../src/game/dark/corpses';
import { B } from '../../src/game/dark/data';
import { actAll, busyIds, freeGuards, postGuard } from '../../src/game/dark/embers';
import { exeOptions, runOrder } from '../../src/game/dark/order';
import { darkPrep } from '../../src/game/dark/hooks';
import { adults, nameOf } from '../../src/game/dark/state';
import type { Ember } from '../../src/game/dark/state';
import { familyOf } from '../../src/game/people';
import { PROFILES } from '../../src/game/state';

// K02 판정(/mnt/project-files/s1b_wip/k02_verdict.md)에서 S1b를 켜기 전에 꼭 고칠 셋(1·2·5).

function darkGame(seed: string): Game {
  const g = createGame(seed);
  enableDark(g);
  g.seg = 4;
  return g;
}

function ember(g: Game, over: Partial<Ember>): Ember {
  const actor = adults(g, 'tail', { noRep: true })[0].id;
  const e: Ember = {
    id: 900 + g.dark!.embers.length, who: 'tail', actor, target: 'guard', mark: g.comms.guard.leader.personId, cause: 'fervor',
    stage: 2, imm: 0, quiet: 0, guardUntil: -1, sab: 'poison', blocked: false, born: g.seg, ...over,
  };
  g.dark!.embers.push(e);
  return e;
}

describe('K02 1. 시신에게 물린 사람', () => {
  it('바로 카드가 나오고, 숨긴 물림의 문장과 신임 벌점이 없다', () => {
    let seen = 0;
    for (let i = 0; i < 40 && seen === 0; i += 1) {
      const g = darkGame(`corpse-bite-${i}`);
      g.cards = [];
      const dead = PROFILES.filter(p => p.community === 'tail').find(p => (familyOf(g, p.name)?.others ?? []).some(o => o.age >= 16))!;
      g.dark!.unchecked = [{ comm: 'tail', name: dead.name, p: 1, cold: false, burn: false }];
      corpseTick(g);
      const bite = g.hiddenBites?.[0];
      if (!bite) continue;
      seen += 1;
      const card = g.cards.find(k => k.kind === 'bite_found' && k.who === bite.who)!;
      expect(card.text).toBe('corpse');
      const v = viewCard(g, card);
      expect(v.title).toBe('시신에게 물렸다');
      expect(v.body).not.toContain('숨겨');
      for (const ch of v.choices) {
        expect(ch.effs.some(e => e.t === 'trust')).toBe(false);
        expect(ch.say ?? '').not.toContain('숨긴');
      }
      expect(v.choices[0].disabled).toBeUndefined();
      const trust = g.trust;
      expect(chooseCard(g, card.uid, 0)).toBe(true);
      expect(g.trust).toBe(trust);
      expect(g.hiddenBites ?? []).toEqual([]);
    }
    expect(seen).toBe(1);
  });

  it('드러났는데 아무도 처리하지 않은 물림은 기한에 끝난다', () => {
    const g = darkGame('corpse-bite-stale');
    const who = nameOf(g, adults(g, 'tail', { noRep: true })[1].id);
    g.hiddenBites = [{ who, comm: 'tail', at: g.seg - 2, due: g.seg, found: true }];
    g.cards = [];
    g.phase = 'council'; g.council = null;
    advance(g);
    expect((g.hiddenBites ?? []).some(b => b.who === who)).toBe(false);
  });
});

describe('K02 2. 사람이 다친 식량 오염은 바로 수사', () => {
  it('앓아누운 사람이 나면 시계 3으로 사건이 열리고 카드는 알았다 하나, 안 다치면 고르는 수사 그대로', () => {
    let sick = 0;
    let quiet = 0;
    for (let i = 0; i < 80 && (sick === 0 || quiet === 0); i += 1) {
      const g = darkGame(`poison-${i}`);
      g.cards = [];
      ember(g, { imm: 2, sab: 'poison' });
      const injured = g.injured;
      actAll(g);
      const card = g.cards.find(k => k.kind === 'dark:act')!;
      const v = viewCard(g, card);
      if (g.injured > injured) {
        sick += 1;
        const c = g.dark!.cases.at(-1)!;
        expect(c.clock).toBe(B.clockInjury);
        expect(c.status).toBe('open');
        expect(v.choices.map(ch => ch.label)).toEqual(['알았다']);
        expect(card.text).toContain('수사가 열린다');
      } else {
        quiet += 1;
        expect(g.dark!.cases).toHaveLength(0);
        expect(v.choices.map(ch => ch.label)).toContain('수사를 연다');
      }
    }
    expect(sick).toBeGreaterThan(0);
    expect(quiet).toBeGreaterThan(0);
  });
});

describe('K02 5. 경비와 근신은 사람을 묶는다', () => {
  it('경비를 서는 둘은 작업조와 명령 실행자에서 빠진다', () => {
    const g = darkGame('guard-bind');
    const e = ember(g, { imm: 2, sab: 'boiler' });
    expect(postGuard(g, e)).toBe(true);
    expect(e.guardIds).toHaveLength(B.guardPair);
    const names = e.guardIds!.map(id => nameOf(g, id));
    expect(crewNames(g, 'guard', 40).some(n => names.includes(n))).toBe(false);
    const target = adults(g, 'front', { noRep: true })[0].id;
    expect(e.guardIds).not.toContain(exeOptions(g, target).guard.id);
    expect(freeGuards(g).some(id => e.guardIds!.includes(id))).toBe(false);
  });

  it('경비대 사람이 모자라면 경비를 못 붙이고 카드에 보인다', () => {
    const g = darkGame('guard-short');
    const free = freeGuards(g);
    g.dark!.confined = free.slice(1).map(id => ({ id, until: g.seg + 4 }));
    const e = ember(g, { imm: 2, sab: 'boiler' });
    expect(postGuard(g, e)).toBe(false);
    g.cards = [{ uid: 7001, kind: 'dark:sign', comm: 'tail', n: e.id, text: 'imm' }];
    const v = viewCard(g, g.cards[0]);
    const guard = v.choices.find(ch => ch.special === 'dark:guard');
    if (guard) expect(guard.disabled).toBe('경비대에 남은 사람이 모자라다');
  });

  it('근신한 사람은 작업조와 실행자에서 빠지고, 이미 받은 명령은 근신이 끝날 때까지 기다린다', () => {
    const g = darkGame('confine-bind');
    const exe = adults(g, 'guard', { noRep: true })[0].id;
    const target = adults(g, 'front', { noRep: true })[0].id;
    g.dark!.confined = [{ id: exe, until: g.seg + 3 }];
    expect(busyIds(g)).toContain(exe);
    expect(crewNames(g, 'guard', 40)).not.toContain(nameOf(g, exe));
    expect(exeOptions(g, target).guard.id).not.toBe(exe);
    g.dark!.order = { target, why: 'hostile', exe: 'guard', exeId: exe, method: 'accident', at: g.seg };
    runOrder(g, 'travel');
    expect(g.dark!.order).not.toBeNull();
    expect(g.dark!.stats.ordersOk ?? 0).toBe(0);
  });

  it('근신은 사람마다 구간마다 경비대 노출 +2', () => {
    const g = darkGame('confine-expo');
    const ids = adults(g, 'tail', { noRep: true }).slice(0, 2).map(p => p.id);
    g.dark!.confined = ids.map(id => ({ id, until: g.seg + 4 }));
    const expo = g.comms.guard.base[3];
    darkPrep(g);
    expect(g.comms.guard.base[3]).toBe(expo + 2 * B.confineExpo);
    expect(B.confineExpo).toBe(2);
  });
});
