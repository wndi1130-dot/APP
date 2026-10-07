import { describe, expect, it } from 'vitest';
import { addCard, chooseCard, cloneGame, COMMS, createGame, createS1cGame, enableDark, lawActive, MOTIONS, onDeath, viewCard } from '../../src/game';
import type { Card, Game, MotionAgenda } from '../../src/game';
import { crowdTick, eligible, exposeOrderLines, openCase, punish, truthTick } from '../../src/game/dark/cases';
import { afterVote, darkCouncilOpen } from '../../src/game/dark/council';
import { corpseTick, darkPyreWeights, darkStoredWeight, vigil } from '../../src/game/dark/corpses';
import { actAll, escalate } from '../../src/game/dark/embers';
import { darkSettle } from '../../src/game/dark/hooks';
import { dropOrder, runOrder } from '../../src/game/dark/order';
import { adults } from '../../src/game/dark/state';
import type { Ember } from '../../src/game/dark/state';

// S1b 정적 리뷰의 '반드시 고칠 것' 11개(/mnt/project-files/s1b_wip/claude_review.md)의 회귀 테스트.

function darkGame(seed = 'fix'): Game {
  const g = createGame(seed);
  enableDark(g);
  g.seg = 3;
  return g;
}

function add(g: Game, card: Omit<Card, 'uid'>): Card {
  addCard(g, card);
  return g.cards[g.cards.length - 1];
}

function ember(g: Game, patch: Partial<Ember>): Ember {
  const d = g.dark!;
  const e: Ember = {
    id: 900 + d.embers.length, who: 'tail', actor: adults(g, 'tail', { noRep: true })[d.embers.length].id, target: 'guard', mark: g.comms.guard.leader.personId,
    cause: 'fervor', stage: 0, imm: 0, quiet: 0, guardUntil: -1, sab: 'heating', blocked: false, born: g.seg, ...patch,
  };
  d.embers.push(e);
  return e;
}

/** 죄 없이 벌받은 사람 하나와, 그 일을 말하려는 증인을 둔 판. 입막음 명령을 걸어 둔다. */
function heldTruth(seed: string): { g: Game; innocent: string; witness: string } {
  const g = darkGame(seed);
  const d = g.dark!;
  const [innocent, witness] = adults(g, 'tail', { noRep: true });
  d.innocents.push({ id: innocent.id, comm: 'tail', seg: g.seg, caseId: 1, how: 'punish' });
  for (let i = 0; i < 200 && !g.cards.some(c => c.kind === 'dark:truth'); i += 1) truthTick(g);
  const card = g.cards.find(c => c.kind === 'dark:truth')!;
  card.text = witness.id;
  g.comms.guard.rel = 30;
  const v = viewCard(g, card);
  chooseCard(g, card.uid, v.choices.findIndex(c => c.label === '조용히 처리한다'));
  d.order = { ...d.order!, exe: 'guard', exeId: adults(g, 'guard', { noRep: true })[0].id, method: 'night' };
  g.cards = [];
  return { g, innocent: innocent.id, witness: witness.id };
}

describe('1. 입막음', () => {
  it('명령이 걸린 동안엔 진실이 굴러가지 않고 창도 다시 열리지 않는다', () => {
    const { g, innocent } = heldTruth('hold');
    const x = g.dark!.innocents.find(y => y.id === innocent)!;
    expect(x.held).toBe(true);
    const seg = x.seg;
    for (let i = 0; i < 100; i += 1) truthTick(g);
    expect(g.cards.some(c => c.kind === 'dark:truth')).toBe(false);
    expect(g.dark!.innocents.find(y => y.id === innocent)?.seg).toBe(seg);
    expect(g.dark!.stats.revealed).toBe(0);
  });

  it('성공하면 묻히고, 실패하면 바로 드러난다', () => {
    let ok = 0;
    let fail = 0;
    for (let i = 0; i < 40; i += 1) {
      const { g, innocent } = heldTruth(`run-${i}`);
      runOrder(g, 'travel');
      expect(g.dark!.innocents.some(y => y.id === innocent)).toBe(false);
      if (g.dark!.stats.ordersOk === 1) { ok += 1; expect(g.dark!.stats.revealed).toBe(0); }
      else { fail += 1; expect(g.dark!.stats.revealed).toBe(1); }
    }
    expect(ok).toBeGreaterThan(0);
    expect(fail).toBeGreaterThan(0);
  });

  it('명령을 거두면 바로 드러난다', () => {
    const { g, innocent } = heldTruth('drop');
    dropOrder(g);
    expect(g.dark!.stats.revealed).toBe(1);
    expect(g.dark!.innocents.some(y => y.id === innocent)).toBe(false);
  });
});

describe('2·3. 측근이 시킨 사람을 댄 뒤', () => {
  it('이미 벌받은 측근은 다시 피고가 되지 않는다', () => {
    let reopened = 0;
    for (let i = 0; i < 40; i += 1) {
      const g = darkGame(`proxy-${i}`);
      const c = openCase(g, { kind: 'assault', culprit: g.comms.tail.leader.personId, victimComm: 'guard', dead: false, clock: 3, where: '통로' });
      const proxy = c.sus.find(s => s.culprit)!;
      if (!proxy.proxyFor) continue;
      punish(g, c, proxy, 'ration', 'trial');
      if (c.status !== 'open') continue;
      reopened += 1;
      expect(eligible(g, c).some(s => s.id === proxy.id)).toBe(false);
      expect(eligible(g, c).some(s => s.id === g.comms.tail.leader.personId)).toBe(true);
    }
    expect(reopened).toBeGreaterThan(0);
  });

  it('열차장이 시킨 일은 한 사건에서 한 번만 드러난다', () => {
    const g = darkGame('expose');
    const c = openCase(g, { kind: 'order', culprit: adults(g, 'guard', { noRep: true })[0].id, victimComm: 'tail', dead: true, clock: 2, where: '통로', own: true });
    g.trust = 60;
    expect(exposeOrderLines(g, c)).toHaveLength(1);
    expect(g.trust).toBe(40);
    expect(exposeOrderLines(g, c)).toHaveLength(0);
    expect(g.trust).toBe(40);
  });
});

describe('4. 죽은 대표', () => {
  it('S1b 판에서 대표가 죽으면 그 칸이 잇는다', () => {
    const g = darkGame('rep');
    const old = g.comms.tail.leader.name;
    onDeath(g, 'tail', [old], 'chosen');
    expect(g.comms.tail.leader.name).not.toBe(old);
    expect(g.journal.some(e => e.text.includes('꼬리칸 대표 자리를 이었다'))).toBe(true);
  });
  it('S1a 판은 그대로다', () => {
    const g = createGame('rep-off');
    const old = g.comms.tail.leader.name;
    onDeath(g, 'tail', [old]);
    expect(g.comms.tail.leader.name).toBe(old);
  });
});

describe('5. 시신은 한 번만 굴린다', () => {
  function stored(seed: string): Game {
    const g = darkGame(seed);
    g.passed.corpse_store = { seg: 1 } as never;
    expect(lawActive(g, 'corpse_store')).toBe(true);
    g.dark!.practice = 'guard';
    return g;
  }
  it('밤샘 카드가 뜬 시신은 S1a 냉동칸 굴림에서 빠지고, 밤샘 굴림이 일어나면 냉동칸 수에서도 빠진다', () => {
    let rose = 0;
    for (let i = 0; i < 60; i += 1) {
      const g = stored(`vigil-${i}`);
      const p = adults(g, 'tail', { noRep: true }).find(x => !!x)!;
      onDeath(g, 'tail', [p.name]);
      expect(g.stored).toBe(1);
      g.dark!.fresh = [{ comm: 'tail', name: p.name }];
      // 밤샘을 청하게 이름 있는 인물로 다룬다.
      g.dark!.staff.deputy = p.id;
      darkSettle(g);
      const card = g.cards.find(c => c.kind === 'dark:vigil');
      if (!card) continue;
      expect(darkStoredWeight(g, g.stored)).toBe(0);
      vigil(g, { comm: 'tail', name: p.name }, 'allow');
      expect(darkStoredWeight(g, g.stored)).toBe(0);
      g.cards = [];
      darkSettle(g);
      if (g.dark!.stats.risen === 1) { rose += 1; expect(g.stored).toBe(0); }
      else expect(darkStoredWeight(g, g.stored)).toBe(0);
    }
    expect(rose).toBeGreaterThan(0);
  });

  it('냉동칸이 비면 확인 수도 0으로 돌아가 새 시신을 빼먹지 않는다', () => {
    const g = stored('reset');
    g.dark!.checkedStored = 3;
    g.stored = 0;
    expect(darkStoredWeight(g, 0)).toBe(0);
    g.stored = 1;
    expect(darkStoredWeight(g, 1)).toBe(1);
  });
});

describe('6. 구간당 필수 결정 셋', () => {
  it('같은 구간의 징후 둘은 쪽지 한 장에 묶이고, 고르면 둘 다 경비를 붙일 수 있다', () => {
    const g = darkGame('pair');
    const a = ember(g, { who: 'tail' });
    const b = ember(g, { who: 'engine', actor: adults(g, 'engine', { noRep: true })[0].id, sab: 'boiler' });
    for (let i = 0; i < 80 && !(a.imm && b.imm); i += 1) escalate(g);
    expect(a.imm && b.imm).toBeTruthy();
    const signs = g.cards.filter(c => c.kind === 'dark:sign');
    expect(signs).toHaveLength(1);
    expect(g.dark!.seg.n).toBe(1);
    const v = viewCard(g, signs[0]);
    expect(v.body.split('\n')).toHaveLength(2);
    chooseCard(g, signs[0].uid, v.choices.findIndex(c => c.label === '둘 다 경비를 붙인다'));
    expect(a.guardUntil).toBeGreaterThanOrEqual(g.seg);
    expect(b.guardUntil).toBeGreaterThanOrEqual(g.seg);
  });

  it('무기고 카드는 필수 결정이 셋이면 안 뜬다', () => {
    const g = darkGame('armory');
    g.dark!.seg = { at: g.seg, n: 3 };
    const e = ember(g, { stage: 2 });
    for (let i = 0; i < 80 && !e.imm; i += 1) escalate(g);
    expect(e.imm).toBe(3);
    expect(g.cards.some(c => c.kind === 'dark:armory')).toBe(false);
  });
});

describe('7. 폭행·암살 임박은 한 번에 하나', () => {
  it('다른 불씨가 폭행 임박이면 사보타주 위로 못 오른다', () => {
    const g = darkGame('busy');
    ember(g, { stage: 2, imm: 3 });
    const e = ember(g, { stage: 2, who: 'engine', actor: adults(g, 'engine', { noRep: true })[0].id });
    for (let i = 0; i < 60; i += 1) escalate(g);
    expect(e.imm).toBe(0);
    expect(e.quiet).toBeGreaterThan(0);
  });
});

describe('8. 불신임', () => {
  const conf: MotionAgenda = { kind: 'motion', motion: 'no_confidence', by: 'tail' };
  const byComm = Object.fromEntries(COMMS.map(c => [c, { yes: 0, no: 0 }]));
  it('목록에 오르기만 하고 다른 안건을 고르면 조건이 남는다. 표결해야 지운다', () => {
    const g = darkGame('conf');
    g.dark!.confBy = 'tail';
    g.dark!.confLeader = g.comms.tail.leader.personId;
    g.council = { options: [conf], idx: 0, locked: false, deals: [], result: null } as never;
    darkCouncilOpen(g);
    expect(g.dark!.confBy).toBe('tail');
    afterVote(g, { kind: 'motion', motion: 'trial' }, { yes: 0, no: 0, absent: 0, passed: false, byComm } as never);
    expect(g.dark!.confBy).toBe('tail');
    MOTIONS.no_confidence.onFail(g, conf);
    afterVote(g, conf, { yes: 0, no: 0, absent: 0, passed: false, byComm } as never);
    expect(g.dark!.confBy).toBeNull();
  });
  it('통과하면 다른 끝과 같은 길로 끝난다(끝 일지와 H7 한 줄)', () => {
    const g = darkGame('ousted');
    MOTIONS.no_confidence.onPass(g, conf);
    expect(g.phase).toBe('end');
    expect(g.end).toBe('ousted');
    expect(g.journal.filter(e => e.text === '의회가 열차장을 끌어내렸다.')).toHaveLength(1);
    expect(g.journal.filter(e => e.text.startsWith('기록: 징후'))).toHaveLength(1);
    const before = JSON.stringify(g);
    afterVote(g, conf, { yes: 0, no: 0, absent: 0, passed: true, byComm } as never);
    expect(JSON.stringify(g)).toBe(before);
  });
});

describe('9·10. 처형과 무죄', () => {
  it('처형은 피해 사건으로 센다', () => {
    const g = darkGame('exec');
    const c = openCase(g, { kind: 'assault', culprit: adults(g, 'tail', { noRep: true })[0].id, victimComm: 'guard', dead: false, clock: 3, where: '통로' });
    const harm = g.dark!.harm;
    punish(g, c, c.sus.find(s => !s.culprit) ?? c.sus[0], 'execute', 'trial');
    expect(g.dark!.harm).toBe(harm + 1);
  });

  it('무죄가 나면 군중은 다음 구간에 온다(같은 구간 정산엔 안 온다)', () => {
    const g = darkGame('acquit');
    const c = openCase(g, { kind: 'assault', culprit: adults(g, 'tail', { noRep: true })[0].id, victimComm: 'guard', dead: true, clock: 3, where: '통로' });
    c.opened = g.seg - 1;
    c.status = 'trial';
    const s = c.sus[0];
    MOTIONS.trial.onFail(g, { kind: 'motion', motion: 'trial', person: s.id, ref: c.id });
    crowdTick(g);
    expect(g.cards.some(k => k.kind === 'dark:mob')).toBe(false);
    g.seg += 1;
    crowdTick(g);
    expect(g.cards.some(k => k.kind === 'dark:mob')).toBe(true);
  });
});

describe('11. 하차 명령은 열차가 설 때', () => {
  it('지나치면 기다리고, 서면 내린다', async () => {
    const { darkStop } = await import('../../src/game/dark/hooks');
    const g = darkGame('exile');
    const p = adults(g, 'tail', { noRep: true })[0];
    g.dark!.exile.push({ id: p.id, comm: 'tail' });
    const copy = cloneGame(g);
    darkStop(copy, false, []);
    expect(copy.dark!.exile).toHaveLength(1);
    darkStop(g, true, []);
    expect(g.dark!.exile).toHaveLength(0);
    expect(g.left).toContain(p.name);
  });

  it('기다리는 사이 죽은 사람은 내리지 않는다(이름·인구가 두 번 깎이지 않는다)', async () => {
    const { darkStop } = await import('../../src/game/dark/hooks');
    const g = darkGame('exile-dead');
    const p = adults(g, 'tail', { noRep: true })[0];
    g.dark!.exile.push({ id: p.id, comm: 'tail' });
    onDeath(g, 'tail', [p.name]);
    const pop = g.comms.tail.pop;
    const left = (g.left ?? []).filter(n => n === p.name).length;
    darkStop(g, true, []);
    expect(g.comms.tail.pop).toBe(pop);
    expect((g.left ?? []).filter(n => n === p.name).length).toBe(left);
    expect(g.dark!.exile).toHaveLength(0);
  });
});

describe('S1b 고침 재점검의 낮은 틈', () => {
  it('칸이 차서 못 물은 무기고 카드는 다음 출발 전에 묻는다', async () => {
    const { darkPrep } = await import('../../src/game/dark/hooks');
    const g = darkGame('armory-due');
    g.dark!.armoryDue = true;
    darkPrep(g);
    expect(g.cards.some(c => c.kind === 'dark:armory')).toBe(true);
    expect(g.dark!.armoryDue).toBe(false);
  });

  it('앓던 대표가 죽으면 되살아나 자리에 앉지 않는다', async () => {
    const { fallSick, recover } = await import('../../src/game/people');
    const g = createGame('sick-dead');
    const rep = g.comms.front.leader;
    fallSick(g, 'front');
    const proxy = g.comms.front.leader;
    onDeath(g, 'front', [rep.name]);
    recover(g, 'front', '처지가 나아지자');
    expect(g.comms.front.leader.name).toBe(proxy.name);
    expect(g.comms.front.sick).toBeUndefined();
    expect(g.journal.some(e => e.text === `${proxy.name}이(가) 앞칸 대표 자리를 이었다.`)).toBe(true);
  });
});

describe('재확인: 장작불 대기는 냉동칸·살던 칸 몫으로 나눠 굴린다', () => {
  function burn(seed: string): Game {
    const g = darkGame(seed);
    g.passed.corpse_burn = { seg: 1 } as never;
    expect(lawActive(g, 'corpse_burn')).toBe(true);
    return g;
  }
  it('냉동칸이 차서 살던 칸에 둔 시신은 확인을 마치면 일어나지 않는다', () => {
    const g = burn('pyre-kin');
    // 냉동칸 6구는 예전에 확인했고, 이번 구간에 둘이 죽어 살던 칸으로 넘쳤다.
    g.pyre = 6;
    g.pyreKin = { tail: 2 };
    g.dark!.checkedPyre = 6;
    g.dark!.fresh = [{ comm: 'tail', name: 'a' }, { comm: 'tail', name: 'b' }];
    expect(darkPyreWeights(g, 6, 2)).toEqual({ cold: 0, kin: 0 });
    // 정산에서 둘을 확인한 뒤
    g.dark!.fresh = [];
    g.dark!.checkedPyre = 8;
    expect(darkPyreWeights(g, 6, 2)).toEqual({ cold: 0, kin: 0 });
  });
  it('냉동칸의 확인 안 된 시신은 넘친 시신의 확인 대기에 밀려 굴림에서 빠지지 않는다', () => {
    const g = burn('pyre-cold');
    g.dark!.checkedPyre = 5;
    g.dark!.fresh = [{ comm: 'tail', name: 'a' }];
    expect(darkPyreWeights(g, 6, 1)).toEqual({ cold: 1, kin: 0 });
  });
  it('확인 안 한 시신이 일어날 때 냉동칸이 비었으면 살던 칸 몫에서 치운다', () => {
    const g = burn('pyre-rise');
    g.pyre = 0;
    g.pyreKin = { tail: 1 };
    const crowd = g.comms.tail.base[2];
    g.dark!.practice = 'guard';
    g.dark!.unchecked = [{ comm: 'tail', name: 'a', p: 1, cold: true, burn: true }];
    corpseTick(g);
    expect(g.dark!.stats.risen).toBe(1);
    expect(g.pyreKin.tail).toBe(0);
    expect(g.comms.tail.base[2]).toBeLessThan(crowd);
  });
});

describe('용의자 후보 칸(J10 W 묶음과 같이 본 cases.ts)', () => {
  it('꼬리칸을 늘 넣지 않는다: 보일러 사건이면 사건 칸·옆 칸·원수 칸에서만 오른다', () => {
    for (let i = 0; i < 30; i += 1) {
      const g = darkGame(`sus-${i}`);
      const culprit = adults(g, 'engine', { noRep: true })[0].id;
      const c = openCase(g, { kind: 'boiler', culprit, victimComm: 'engine', dead: false, clock: 3, where: '탄수차' });
      const comms = c.sus.map(s => adults(g, 'tail').some(p => p.id === s.id) ? 'tail' : 'other');
      expect(comms, `시드 ${i}`).not.toContain('tail');
    }
  });

  it('꼬리칸이 사건에 닿으면(옆 칸) 후보에 오를 수 있다', () => {
    let tail = 0;
    for (let i = 0; i < 30; i += 1) {
      const g = darkGame(`sus-m-${i}`);
      const culprit = adults(g, 'medtech', { noRep: true })[0].id;
      const c = openCase(g, { kind: 'assault', culprit, victimComm: 'medtech', dead: false, clock: 3, where: '통로' });
      if (c.sus.some(s => adults(g, 'tail').some(p => p.id === s.id))) tail += 1;
    }
    expect(tail).toBeGreaterThan(0);
  });
});

describe('장갑 객차와 사보타주(J10 13번)', () => {
  it('꼬리칸 객차를 모두 장갑하면 난방 사보타주의 온기 피해가 절반', () => {
    const hit = (armored: boolean) => {
      const g = createS1cGame('armor');
      enableDark(g);
      g.seg = 3;
      if (armored) g.dom!.armored = ['tail1', 'tail2', 'tail3'];
      const before = g.comms.tail.base[0];
      ember(g, { who: 'tail', target: 'tail', mark: 'tail', sab: 'heating', imm: 2 });
      actAll(g);
      return before - g.comms.tail.base[0];
    };
    expect(hit(false)).toBe(15);
    expect(hit(true)).toBe(8);
  });
});
