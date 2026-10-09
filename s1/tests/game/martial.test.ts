import { describe, expect, it } from 'vitest';
import {
  addCard, advance, callEmergency, castVote, chooseCard, COMMS, createGame, currentAgenda, emergencyStatus, enableDark, enactLaw, isGone, motionsNow, openCouncil,
  primaryAction, resolveStop, setLever, supportComm, viewCard,
} from '../../src/game';
import type { Card, Game } from '../../src/game';
import { guardTrial, openCase } from '../../src/game/dark/cases';
import { darkPrep, darkSettle } from '../../src/game/dark/hooks';
import { canExtend, darkPowersEnd, enterMartial, liftMartial, martialSettle } from '../../src/game/dark/martial';
import { playGame } from '../../tools/s1c_bot';

// S1b 둘째 묶음 PR A: 계엄 핵심(s1b_martial_impl.md 2~4장). 문 2·3·4를 부르는 쪽(내전 직전)은 PR B다.

function darkGame(seed = 'martial-test'): Game {
  const g = createGame(seed);
  enableDark(g);
  return g;
}
function add(g: Game, card: Omit<Card, 'uid'>): Card {
  addCard(g, card);
  return g.cards[g.cards.length - 1];
}
/** 증거 단계 2가 되도록 단서를 채운 사건(재판에 넘긴 상태) */
function evidenceCase(g: Game) {
  const c = openCase(g, { kind: 'assault', culprit: g.comms.tail.leader.personId, victimComm: 'guard', dead: false, clock: 3, where: '통로' });
  const s = c.sus.find(x => x.culprit) ?? c.sus[0];
  s.clues = [{ kind: 'witness', truth: true, line: '봤다.', seg: 1 }, { kind: 'foot', truth: true, line: '발자국.', seg: 1 }];
  c.status = 'trial';
  return { c, s };
}
function pick(g: Game, card: Card, label: string): void {
  const v = viewCard(g, card);
  expect(v.title).not.toBe('빈 서류');
  const i = v.choices.findIndex(x => x.label === label && !x.disabled);
  expect(i).toBeGreaterThanOrEqual(0);
  chooseCard(g, card.uid, i);
}

describe('계엄이 들어선다', () => {
  it('대권 연장 문: 경비대 외 모든 칸 적의 +1, 긴장 +10, 수단 martial 1, 포고는 계엄 기록으로', () => {
    const g = darkGame();
    g.seg = 3;
    g.passed.patrol = 1;
    g.passed.emergency_powers = 1;
    g.decreeLeft = 1;
    g.decreed = ['patrol'];
    g.trust = 60;
    g.trustCrisis = 5;
    const before = Object.fromEntries(COMMS.map(c => [c, g.comms[c].grudge]));
    const t = g.tension;
    const ration = g.comms.guard.ration;
    enterMartial(g, 'extend');
    const d = g.dark!;
    expect(d.martial).toMatchObject({ door: 'extend', since: 3, trustBefore: 60, decreed: ['patrol'], repealed: [], coupWarnAt: null, warned: false });
    for (const c of COMMS) expect(g.comms[c].grudge).toBe(c === 'guard' ? before[c] : Math.min(3, before[c] + 1));
    expect(g.tension).toBe(t + 10);
    expect(d.means.martial).toBe(1);
    expect(d.martialDoors).toEqual(['extend']);
    expect(g.passed.emergency_powers).toBeUndefined();
    expect(g.decreeLeft).toBe(0);
    expect(g.decreed).toEqual([]);
    expect(g.ratify ?? []).toEqual([]);
    expect(g.trustCrisis).toBeNull();
    expect(g.comms.guard.ration).toBe(ration + 1);
    expect(d.martial!.rationLocked).toBe(ration + 1);
    expect(d.scenes.some(s => s.key === 'martial')).toBe(true);
  });

  it('계엄 중엔 경비대 지지와 배급 레버 내리기가 막힌다', () => {
    const g = darkGame();
    enterMartial(g, 'extend');
    g.lux = 10;
    expect(supportComm(g, 'guard')).toBe('계엄 중엔 지지로 충성을 사지 못한다');
    expect(g.lux).toBe(10);
    const locked = g.dark!.martial!.rationLocked;
    setLever(g, 'guard', 'ration', locked - 1);
    expect(g.comms.guard.ration).toBe(locked);
    setLever(g, 'guard', 'ration', Math.min(4, locked + 1));
    expect(g.comms.guard.ration).toBe(Math.min(4, locked + 1));
  });

  it('S1a 판은 아무 일도 없다', () => {
    const g = createGame('plain');
    expect(darkPowersEnd(g)).toBe(false);
    expect(supportComm(g, 'guard')).not.toBe('계엄 중엔 지지로 충성을 사지 못한다');
  });
});

describe('계엄을 거둔다', () => {
  it('신임은 직전 값 −15로 돌아오고 경고가 없었으면 보너스가 있다', () => {
    const g = darkGame();
    g.trust = 70;
    enterMartial(g, 'extend');
    g.trust = 5;
    liftMartial(g, 'self');
    const d = g.dark!;
    expect(g.trust).toBe(55);
    expect(d.martial).toBeNull();
    expect(d.martialLifted).toMatchObject({ bonus: true });
    expect(d.stats.lifted).toBe(1);
    expect(d.means.martial_lifted).toBe(1);
  });
  it('쿠데타 경고가 떴으면 보너스가 없다', () => {
    const g = darkGame();
    enterMartial(g, 'extend');
    g.dark!.martial!.warned = true;
    liftMartial(g);
    expect(g.dark!.martialLifted!.bonus).toBe(false);
    expect(g.dark!.means.martial_lifted).toBeUndefined(); // 경고 뒤 거둔 계엄은 수단을 깎지 않는다
  });
  it('의회가 맡긴 계엄은 거둬도 수단 −2가 없다(들어설 때 2라서)', () => {
    const g = darkGame();
    enterMartial(g, 'council');
    liftMartial(g);
    expect(g.dark!.means.martial_lifted).toBeUndefined();
  });
});

describe('쿠데타', () => {
  it('경비대 관계 −30이면 경고 카드, 2구간 안에 못 돌리면 쿠데타로 판이 끝난다', () => {
    const g = darkGame();
    g.seg = 4;
    enterMartial(g, 'extend');
    g.comms.guard.rel = -30;
    martialSettle(g);
    const warn = g.cards.find(c => c.kind === 'dark:coup_warn');
    expect(warn).toBeTruthy();
    expect(viewCard(g, warn!).body).toContain('당직표');
    expect(g.dark!.martial!.coupWarnAt).toBe(6);
    expect(g.dark!.martial!.warned).toBe(true);
    expect(g.phase).not.toBe('end');
    g.seg = 6;
    martialSettle(g);
    expect(g.end).toBe('coup');
    expect(g.phase).toBe('end');
  });
  it('호의로 돌리면 경고가 풀린다. 경비대장의 계엄은 문턱이 한 단계 높다', () => {
    const g = darkGame();
    enterMartial(g, 'extend');
    g.comms.guard.rel = -30;
    martialSettle(g);
    expect(g.dark!.martial!.coupWarnAt).not.toBeNull();
    g.comms.guard.rel = -5; // 중립: 문턱 위지만 호의가 아니라 경고가 그대로
    martialSettle(g);
    expect(g.dark!.martial!.coupWarnAt).not.toBeNull();
    g.comms.guard.rel = 20;
    martialSettle(g);
    expect(g.dark!.martial!.coupWarnAt).toBeNull();
    const h = darkGame('captain');
    enterMartial(h, 'captain', { a: 'tail', b: 'front' });
    h.comms.guard.rel = -5; // 중립: 보통 계엄이면 경고가 없지만 경비대장의 계엄은 경고
    martialSettle(h);
    expect(h.dark!.martial!.coupWarnAt).not.toBeNull();
  });
  it('유지비: 경비대 노출·긴장·공포가 정산마다 붙고 구간 수를 센다', () => {
    const g = darkGame();
    enterMartial(g, 'extend');
    const expo = g.comms.guard.base[3];
    const t = g.tension;
    const f = g.fear;
    darkSettle(g);
    expect(g.comms.guard.base[3]).toBe(expo + 2);
    expect(g.tension).toBe(t + 2);
    expect(g.fear).toBe(f + 3);
    expect(g.dark!.stats.martialSegs).toBe(1);
  });
});

describe('대권이 끝나는 카드', () => {
  function powers(): Game {
    const g = darkGame();
    g.seg = 4;
    enactLaw(g, 'emergency_powers', []);
    g.decreeLeft = 1;
    g.decreed = ['patrol'];
    g.passed.patrol = 3;
    return g;
  }
  it('대권마다 한 번 카드가 뜨고 선택지가 셋이며 연장은 선을 넘는다', () => {
    const g = powers();
    darkPrep(g);
    const card = g.cards.find(c => c.kind === 'dark:powers_end')!;
    expect(card).toBeTruthy();
    const v = viewCard(g, card);
    expect(v.choices.map(c => c.label)).toEqual(['돌려준다', '의회에 묻는다', '연장한다']);
    expect(v.choices[2].cross).toBeDefined();
    pick(g, card, '돌려준다');
    expect(g.dark!.powersPlan).toBe('return');
    darkPrep(g);
    expect(g.cards.some(c => c.kind === 'dark:powers_end')).toBe(false);
  });
  it('경비대가 호의가 아니면 연장이 잠기고 이유가 보인다', () => {
    const g = powers();
    g.comms.guard.rel = 0;
    expect(canExtend(g)).toBe('경비대장이 고개를 젓는다.');
    darkPrep(g);
    const v = viewCard(g, g.cards.find(c => c.kind === 'dark:powers_end')!);
    expect(v.choices[2].disabled).toBe('경비대장이 고개를 젓는다.');
  });
  it('돌려준다: 대권이 끝나고 신임 +5, 포고는 추인 목록으로', () => {
    const g = powers();
    g.trust = 40;
    expect(darkPowersEnd(g)).toBe(true);
    expect(g.trust).toBe(45);
    expect(g.passed.emergency_powers).toBeUndefined();
    expect(g.ratify).toEqual(['patrol']);
  });
  it('의회에 묻는다: 대권은 끝나고 대권 연장 안건이 오른다. 통과하면 대권이 다시 서고 추인 목록이 빈다', () => {
    const g = powers();
    g.dark!.powersPlan = 'ask';
    expect(darkPowersEnd(g)).toBe(true);
    expect(g.dark!.martial).toBeNull();
    expect(g.dark!.extendAsk).toBe(true);
    expect(g.passed.emergency_powers).toBeUndefined();
    expect(motionsNow(g).map(m => m.motion)).toContain('extend_powers');
    openCouncil(g);
    g.phase = 'council';
    const first = g.council!.options[0];
    expect(first).toMatchObject({ kind: 'motion', motion: 'extend_powers' });
    for (const c of COMMS) g.comms[c].rel = 100;
    const r = castVote(g)!;
    expect(r.need).toBe(67);
    expect(g.dark!.extendAsk).toBe(false);
    if (r.passed) {
      expect(g.passed.emergency_powers).toBeDefined();
      expect(g.decreeLeft).toBeGreaterThan(0);
      expect(g.ratify).toEqual([]);
    } else {
      expect(g.ratify).toEqual(['patrol']);
    }
  });
  it('연장한다: 계엄이 서고 포고는 계엄 기록에 있다', () => {
    const g = powers();
    g.comms.guard.rel = 30;
    g.dark!.powersPlan = 'extend';
    expect(darkPowersEnd(g)).toBe(true);
    expect(g.dark!.martial?.door).toBe('extend');
    expect(g.dark!.martial?.decreed).toEqual(['patrol']);
    expect(g.ratify ?? []).toEqual([]);
  });
  it('카드를 보인 뒤 경비대가 돌아섰으면 연장은 돌려주기가 된다', () => {
    const g = powers();
    g.comms.guard.rel = -20;
    g.dark!.powersPlan = 'extend';
    darkPowersEnd(g);
    expect(g.dark!.martial).toBeNull();
    expect(g.ratify).toEqual(['patrol']);
  });
});

describe('계엄 회기', () => {
  function martialCouncil(): Game {
    const g = darkGame();
    g.seg = 6;
    g.trust = 50;
    enterMartial(g, 'extend');
    openCouncil(g);
    g.phase = 'council';
    return g;
  }
  it('법 제정·폐지만 안건이 되고 표결도 거래도 없다. 포고만 된다', () => {
    const g = martialCouncil();
    expect(g.council!.martial).toBe(true);
    expect(g.council!.locked).toBe(false);
    expect(g.council!.options.length).toBeGreaterThan(0);
    for (const o of g.council!.options) expect(o).not.toHaveProperty('motion');
    expect(castVote(g)).toBeNull();
    const guardRel = g.comms.guard.rel;
    const law = (currentAgenda(g) as { law: string; repeal: boolean });
    const r = castVote(g, true);
    expect(r?.decree).toBe(true);
    expect(g.comms.guard.rel).toBe(guardRel - 5);
    const m = g.dark!.martial!;
    expect(law.repeal ? m.repealed : m.decreed).toContain(law.law);
    expect(g.decreed ?? []).toEqual([]);
    expect(g.ratify ?? []).toEqual([]);
    expect(castVote(g, true)).toBeNull(); // 한 회기에 하나
    advance(g); // 회기를 닫는다
    expect(g.phase).toBe('settle');
    expect(g.ratify ?? []).toEqual([]);
  });
  it('회기를 그냥 닫을 수 있다', () => {
    const g = martialCouncil();
    advance(g);
    expect(g.phase).toBe('settle');
  });
  it('거두면 그 회기는 닫히고, 다음 정기 회기에 포고 추인 안건 하나가 오른다', () => {
    const g = martialCouncil();
    const agenda = currentAgenda(g) as { law: 'common_kitchen'; repeal: boolean };
    castVote(g, true);
    liftMartial(g);
    expect(g.council!.options).toEqual([]);
    advance(g);
    g.seg += 3;
    openCouncil(g);
    const first = g.council!.options.find(o => 'motion' in o && o.motion === 'ratify_decrees');
    expect(first).toBeTruthy();
    expect(agenda).toBeTruthy();
    g.phase = 'council';
    g.council!.idx = g.council!.options.indexOf(first!);
    castVote(g);
    expect(g.dark!.martialLifted).toBeUndefined();
  });
  it('포고가 없었으면 추인 안건 없이 거둔 기록만 지워진다', () => {
    const g = darkGame();
    enterMartial(g, 'extend');
    liftMartial(g);
    expect(motionsNow(g).map(m => m.motion)).not.toContain('ratify_decrees');
    expect(g.dark!.martialLifted).toBeUndefined();
  });
});

describe('경비대 재판', () => {
  it('계엄 중 재판에 넘긴 사건마다 카드 한 장. 증거 단계 2는 늘 유죄이고 처형하면 사람이 죽는다', () => {
    const g = darkGame();
    g.seg = 5;
    const { c, s } = evidenceCase(g);
    enterMartial(g, 'extend');
    darkPrep(g);
    darkPrep(g);
    const cards = g.cards.filter(k => k.kind === 'dark:gtrial');
    expect(cards).toHaveLength(1);
    const v = viewCard(g, cards[0]);
    expect(v.choices.map(x => x.label)).toEqual(['판결을 듣는다', '풀어 준다']);
    expect(v.body).toContain('증거');
    pick(g, cards[0], '판결을 듣는다');
    expect(c.convicted).toBe(s.id);
    const d = g.dark!;
    expect(d.stats.gtrials).toBe(1);
    expect(d.stats.guilty).toBe(1);
    const punishCard = g.cards.find(k => k.kind === 'dark:punish')!;
    expect(punishCard.text).toBe('guard');
    const name = (viewCard(g, punishCard).faces ?? [])[0];
    pick(g, punishCard, '처형');
    expect(isGone(g, name)).toBe(true);
    expect(d.stats.gexec).toBe(1);
    expect(d.means.guard_exec).toBe(1);
    expect(d.means.executions).toBe(1);
    expect(c.status).toBe('closed');
  });
  it('군중에게 약속한 재판은 경비대 재판으로 지킨 것이다', () => {
    const g = darkGame('gtrial-promise');
    g.seg = 5;
    const { c } = evidenceCase(g);
    c.promised = g.session + 1;
    enterMartial(g, 'extend');
    guardTrial(g, c);
    expect(c.promised).toBeUndefined();
  });
  it('증거가 모자라면 풀려난다(소문 단계)', () => {
    const g = darkGame('gtrial-free');
    g.seg = 5;
    const c = openCase(g, { kind: 'assault', culprit: g.comms.tail.leader.personId, victimComm: 'guard', dead: false, clock: 3, where: '통로' });
    c.sus.forEach(s => { s.clues = []; });
    c.status = 'trial';
    let acquitted = 0;
    for (let i = 0; i < 60; i += 1) {
      c.status = 'trial';
      c.sus.forEach(s => { s.acq = false; });
      guardTrial(g, c);
      if (c.convicted) { c.convicted = undefined; g.cards = []; } else acquitted += 1;
    }
    expect(acquitted).toBeGreaterThan(30); // 소문 단계 유죄 확률 30%
    expect(c.status).toBe('open');
    expect(g.dark!.stats.acquitted).toBe(acquitted);
  });
  it('계엄 중 수사 카드는 경비대 재판으로 보이고 밤샘 화자는 경비대장이다', () => {
    const g = darkGame();
    const c = openCase(g, { kind: 'assault', culprit: g.comms.tail.leader.personId, victimComm: 'guard', dead: false, clock: 3, where: '통로' });
    const card = add(g, { kind: 'dark:case', n: c.id, comm: 'guard' });
    expect(viewCard(g, card).choices.some(x => x.label === '재판에 넘긴다')).toBe(true);
    enterMartial(g, 'extend');
    expect(viewCard(g, card).choices.some(x => x.label === '경비대 재판에 넘긴다')).toBe(true);
    const vigil = viewCard(g, add(g, { kind: 'dark:vigil', comm: 'tail', who: '아무개' }));
    expect(vigil.speaker?.role).toBe(viewCard(g, add(g, { kind: 'dark:vigil', comm: 'guard', who: '아무개' })).speaker?.role);
    expect(vigil.choices[0].label).toBe('통행 쪽지를 써 준다');
  });
});

describe('비상 소집과 신임 위기', () => {
  /** 의회 없이 정산을 한 번 돌린다(turn.ts settle → checkEnd) */
  function settleOnce(g: Game): void {
    g.phase = 'council';
    g.council = null;
    advance(g);
  }
  it('계엄 중엔 비상 소집이 잠긴다', () => {
    const g = darkGame();
    g.seg = 4;
    g.trust = 80;
    g.phase = 'stop';
    g.stop = { done: true } as Game['stop'];
    const open = emergencyStatus(g);
    enterMartial(g, 'extend');
    const closed = emergencyStatus(g);
    expect(closed.ok).toBe(false);
    expect(closed.why).toBe('의회가 닫혀 있다');
    expect(open.why).not.toBe('의회가 닫혀 있다');
    expect(callEmergency(g)).toBe(false);
  });
  it('신임이 0이어도 계엄 중엔 신임 위기가 걸리지 않는다(평시엔 걸린다)', () => {
    const plain = darkGame('crisis-plain');
    plain.trust = 0;
    settleOnce(plain);
    expect(plain.trustCrisis).not.toBeNull();
    const g = darkGame('crisis-martial');
    enterMartial(g, 'extend');
    g.trust = 0;
    settleOnce(g);
    expect(g.trustCrisis).toBeNull();
    expect(g.cards.some(c => c.kind === 'trust_crisis')).toBe(false);
  });
  it('정산 중 쿠데타로 끝나면 다른 끝이 덮어쓰지 않는다', () => {
    const g = darkGame('coup-settle');
    enterMartial(g, 'extend');
    g.dark!.martial!.coupWarnAt = g.seg;
    g.dark!.martial!.warned = true;
    g.comms.guard.rel = -90;
    g.coal = 0;
    g.emergencyUsed = true;
    settleOnce(g);
    expect(g.end).toBe('coup');
  });
});

describe('판 돌리기', () => {
  it('계엄을 세운 채 끝까지 돌려도 막히지 않는다(포고하고 거두기도 한다)', () => {
    for (const seed of ['run1', 'run2', 'run3']) {
      const g = darkGame(seed);
      let lifted = false;
      for (let guard = 0; guard < 4000 && g.phase !== 'end'; guard += 1) {
        if (g.phase === 'prep' && g.seg === 2 && !g.dark!.martial && !lifted && g.dark!.stats.lifted === 0) enterMartial(g, 'extend');
        if (g.cards.length) { const v = viewCard(g, g.cards[0]); chooseCard(g, g.cards[0].uid, Math.max(0, v.choices.findIndex(c => !c.disabled))); continue; }
        if (g.phase === 'stop' && g.stop && !g.stop.done) { resolveStop(g, true); continue; }
        if (g.phase === 'council' && g.council && g.council.martial) {
          if (!g.council.result && g.seg >= 9 && g.dark!.martial) { liftMartial(g); lifted = true; } else castVote(g, true);
          advance(g);
          continue;
        }
        if (g.phase === 'council' && g.council && !g.council.result && currentAgenda(g)) { castVote(g); continue; }
        if (!primaryAction(g).ok) break;
        advance(g);
      }
      expect(g.phase, seed).toBe('end');
      expect(g.dark!.stats.martialSegs).toBeGreaterThan(0);
    }
  });

  it('어두운 길 봇이 새 카드를 만나도 예외 없이 끝까지 간다', () => {
    for (const seed of ['m1', 'm2', 'm3', 'm4']) {
      for (const s1b of ['kind', 'cruel'] as const) {
        const { g } = playGame(seed, { s1c: false, policy: 'caretaker', dom: 'idle', s1b });
        expect(g.phase).toBe('end');
      }
    }
  });
});
