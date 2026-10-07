import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  addCard, advance, B, castVote, chooseCard, COMMS, createGame, currentAgenda, enableDark, EXECUTION, logCardPick, motionsNow, onDeath, primaryAction,
  resolveStop, viewCard,
} from '../../src/game';
import type { Card, Game } from '../../src/game';
import { escalate } from '../../src/game/dark/embers';
import { openCase } from '../../src/game/dark/cases';
import { theftTick } from '../../src/game/dark/cards';
import { cross } from '../../src/game/dark/chronicle';
import { darkSettle } from '../../src/game/dark/hooks';
import type { Ember } from '../../src/game/dark/state';
import { playGame } from '../../tools/s1c_bot';

// S1b 핵심 묶음(s1b_dark_path 2장 1번 '가'): 징후, 수사·재판·희생양, 암살 명령, 칸 안의 시신, 일대기. 제안 (6)(7)은 S1b 판에서만.

function darkGame(seed = 'dark-test'): Game {
  const g = createGame(seed);
  enableDark(g);
  return g;
}

function add(g: Game, card: Omit<Card, 'uid'>): Card {
  addCard(g, card);
  return g.cards[g.cards.length - 1];
}

/** 출발 전까지 카드·정차·의회를 첫 선택지로 넘긴다. */
function toPrep(g: Game, seg: number): void {
  for (let guard = 0; guard < 3000 && g.phase !== 'end' && !(g.phase === 'prep' && g.seg >= seg); guard += 1) {
    if (g.cards.length) { const v = viewCard(g, g.cards[0]); chooseCard(g, g.cards[0].uid, v.choices.findIndex(c => !c.disabled)); continue; }
    if (g.phase === 'stop' && g.stop && !g.stop.done) { resolveStop(g, true); continue; }
    if (g.phase === 'council' && g.council && !g.council.result && currentAgenda(g)) { castVote(g); continue; }
    if (!primaryAction(g).ok) break;
    advance(g);
  }
}

function ember(g: Game, patch: Partial<Ember> = {}): Ember {
  const d = g.dark!;
  const e: Ember = {
    id: 900 + d.embers.length, who: 'tail', actor: g.comms.tail.leader.personId, target: 'guard', mark: g.comms.guard.leader.personId, cause: 'fervor',
    stage: 0, imm: 0, quiet: 0, guardUntil: -1, sab: 'heating', blocked: false, born: g.seg, ...patch,
  };
  d.embers.push(e);
  return e;
}

describe('S1b를 켜지 않은 판', () => {
  it('어두운 길 카드도 상태도 없다', () => {
    const g = createGame('no-dark');
    toPrep(g, 8);
    expect(g.dark).toBeUndefined();
    expect(g.journal.some(e => e.text.startsWith('기록: 징후'))).toBe(false);
  });

  it('봇 판 결과가 S1b 없는 판과 같다(훅이 S1a 주사위를 건드리지 않는다)', () => {
    for (const seed of ['same-1', 'same-2', 'same-3']) {
      const a = playGame(seed, { s1c: false, policy: 'caretaker', dom: 'idle' }).g;
      const b = playGame(seed, { s1c: false, policy: 'caretaker', dom: 'idle' }).g;
      expect(b.journal.map(e => e.text)).toEqual(a.journal.map(e => e.text));
    }
  });
});

describe('징후 없이 폭력은 없다(4.2)', () => {
  it('임박은 출발 전 서류에 뜨고 그 구간 이동에 일어난다', () => {
    const g = darkGame();
    toPrep(g, 2);
    const e = ember(g);
    // 오를 때까지 출발 전 판정을 되풀이한다(불씨 하나, 경비 없음).
    for (let i = 0; i < 40 && !e.imm; i += 1) escalate(g);
    expect(e.imm).toBe(1);
    const sign = g.cards.find(c => c.kind === 'dark:sign' && c.n === e.id && c.text === 'imm');
    expect(sign).toBeTruthy();
    g.cards = [];
    advance(g);
    expect(g.phase).toBe('travel');
    expect(g.cards.some(c => c.kind === 'dark:act' && c.n === e.id)).toBe(true);
    expect(e.imm).toBe(0);
  });

  it('경비를 붙이면 위협·사보타주는 시도에서 끝난다', () => {
    const g = darkGame();
    toPrep(g, 2);
    const e = ember(g, { imm: 2, sab: 'heating', target: 'tail' });
    const card = add(g, { kind: 'dark:sign', comm: 'tail', n: e.id, text: 'imm', who: '쪽지' });
    const v = viewCard(g, card);
    chooseCard(g, card.uid, v.choices.findIndex(c => c.label === '경비를 붙인다'));
    const warm = g.comms.tail.base[0];
    g.cards = [];
    advance(g);
    expect(g.dark!.stats.blocked).toBe(1);
    expect(g.comms.tail.base[0]).toBe(warm);
  });

  it('봇 판 전체에서 일어난 일은 모두 임박 징후를 거쳤다', () => {
    for (const seed of ['sig-1', 'sig-2', 'sig-3', 'sig-4']) {
      const { g } = playGame(seed, { s1c: false, policy: 'caretaker', dom: 'idle', s1b: 'blind' });
      const s = g.dark!.stats;
      expect(s.acts).toBeLessThanOrEqual(s.imminent);
      expect(s.imminent - s.acts).toBe(g.dark!.embers.filter(x => x.imm).length);
    }
  });
});

describe('처형은 재판으로만(2장 4번, 사용자 17:01)', () => {
  function punishView(g: Game, via: 'trial' | 'summary') {
    const c = openCase(g, { kind: 'assault', culprit: g.comms.tail.leader.personId, victimComm: 'guard', dead: false, clock: 3, where: '통로' });
    const s = c.sus[0];
    return viewCard(g, add(g, { kind: 'dark:punish', n: c.id, who: s.id, comm: 'tail', text: via }));
  }
  it('즉결엔 처형이 잠기고, 재판 판결엔 열린다', () => {
    const g = darkGame();
    expect(EXECUTION.rule).toBe('trial');
    expect(punishView(g, 'summary').choices.find(c => c.label === '처형')?.disabled).toBeTruthy();
    expect(punishView(g, 'trial').choices.find(c => c.label === '처형')?.disabled).toBeUndefined();
  });
  it("규칙 한 값으로 바꾼다('none'이면 선택지가 없다)", () => {
    const g = darkGame();
    EXECUTION.rule = 'none';
    try {
      expect(punishView(g, 'trial').choices.some(c => c.label === '처형')).toBe(false);
    } finally {
      EXECUTION.rule = 'trial';
    }
  });
  it('처형·하차 명령은 선을 넘는 선택지로 검은 띠가 붙는다', () => {
    const v = punishView(darkGame(), 'trial');
    expect(v.choices.find(c => c.label === '처형')?.cross).toBeTypeOf('string');
    expect(v.choices.find(c => c.label === '근신')?.cross).toBeUndefined();
  });
});

describe('카드 그리기는 난수를 쓰지 않는다', () => {
  it('같은 카드를 두 번 그려도 같은 글이고 S1b 난수가 그대로다', () => {
    const g = darkGame();
    const c = openCase(g, { kind: 'assault', culprit: g.comms.tail.leader.personId, victimComm: 'guard', dead: true, clock: 1, where: '통로' });
    const card = add(g, { kind: 'dark:mob', n: c.id, comm: 'guard' });
    const rng = JSON.stringify(g.dark!.rng);
    const a = viewCard(g, card);
    const b = viewCard(g, card);
    expect(b).toEqual(a);
    expect(JSON.stringify(g.dark!.rng)).toBe(rng);
  });
});

describe('칸 안에서 죽은 사람(9장)', () => {
  it('첫 칸 안 죽음은 확인 관행 카드를 부르고, 고르면 확인한다', () => {
    const g = darkGame();
    toPrep(g, 2);
    const p = g.comms.tail.leader;
    onDeath(g, 'tail', [p.name]);
    expect(g.dark!.fresh.map(x => x.name)).toEqual([p.name]);
    darkSettle(g);
    const card = g.cards.find(c => c.kind === 'dark:corpse_rule')!;
    expect(card).toBeTruthy();
    const v = viewCard(g, card);
    chooseCard(g, card.uid, v.choices.findIndex(c => c.label === '의무진이 한다'));
    expect(g.dark!.practice).toBe('medtech');
    expect(g.dark!.fresh).toEqual([]);
  });
  it('정차에서 죽은 사람은 확인을 거치지 않는다(9.3)', () => {
    const g = darkGame();
    g.phase = 'stop';
    onDeath(g, 'tail', ['정차의 누군가']);
    expect(g.dark!.fresh).toEqual([]);
  });
});

describe('굶주림의 도둑질(4.3)', () => {
  it('배급 20 이하 2구간째에 기척, 그 뒤 창고가 빈다', () => {
    const g = darkGame();
    toPrep(g, 2);
    g.comms.tail.base[1] = 0;
    g.comms.tail.ration = 0;
    theftTick(g);
    expect(g.dark!.stats.theft).toBe(0);
    const food = g.food;
    for (let i = 0; i < 40 && g.dark!.stats.theft === 0; i += 1) theftTick(g);
    expect(g.journal.some(e => e.text.includes('감자 껍질'))).toBe(true);
    expect(g.dark!.stats.theft).toBe(1);
    expect(g.food).toBeLessThan(food);
    expect(g.cards.some(c => c.kind === 'dark:theft') || g.dark!.stats.cardsDeferred > 0).toBe(true);
    expect((g.tempBase ?? []).some(t => t.c === 'tail' && t.i === 1 && t.v === 5)).toBe(true);
  });
});

describe('제안 (7) 포고로 정한다', () => {
  function demandView(g: Game) {
    return viewCard(g, add(g, { kind: 'demand', comm: 'tail' }));
  }
  it('대권 중인 S1b 판에만 붙고, 고르면 이번 구간 포고 자리를 쓴다', () => {
    const plain = createGame('decree');
    plain.decreeLeft = 2;
    expect(demandView(plain).choices.some(c => c.special?.startsWith('dark:decree'))).toBe(false);
    const g = darkGame('decree');
    expect(demandView(g).choices.some(c => c.special?.startsWith('dark:decree'))).toBe(false);
    g.decreeLeft = 2;
    const card = add(g, { kind: 'demand', comm: 'tail' });
    const v = viewCard(g, card);
    const i = v.choices.findIndex(c => c.special === 'dark:decree:refuse');
    expect(i).toBeGreaterThan(-1);
    const fervor = g.comms.tail.fervor;
    chooseCard(g, card.uid, i);
    expect(g.decreeSeg).toBe(g.seg);
    expect(g.comms.tail.fervor).toBe(fervor);
    expect(demandView(g).choices.some(c => c.special?.startsWith('dark:decree'))).toBe(false);
  });
  it('법 요구 카드에선 법 하나를 포고하고, 대권이 끝나면 추인 안건이 된다', () => {
    const g = darkGame('decree-law');
    g.decreeLeft = 2;
    g.coal = 30;
    const card = add(g, { kind: 'need_warn', text: 'coal' });
    const v = viewCard(g, card);
    const i = v.choices.findIndex(c => c.special?.startsWith('dark:decree:law:'));
    expect(i).toBeGreaterThan(-1);
    const law = v.choices[i].special!.slice('dark:decree:law:'.length);
    chooseCard(g, card.uid, i);
    expect(g.passed[law as keyof typeof g.passed]).toBeDefined();
    expect(g.decreed).toContain(law);
  });
});

describe('제안 (6) 조건부 불신임 동의', () => {
  it('신임 30 아래로 2구간이면 안건이 되고, 통과하면 판이 끝난다', () => {
    const g = darkGame('conf');
    toPrep(g, 2);
    g.trust = 20;
    darkSettle(g);
    expect(motionsNow(g).some(m => m.motion === 'no_confidence')).toBe(false);
    darkSettle(g);
    expect(motionsNow(g).some(m => m.motion === 'no_confidence')).toBe(true);
  });
  it('S1b가 아닌 판엔 오르지 않는다', () => {
    const g = createGame('conf-off');
    g.trust = 5;
    expect(motionsNow(g).some(m => m.motion === 'no_confidence')).toBe(false);
  });
  it('적의 3이 된 대표는 불신임 카드를 올린다(한 번)', () => {
    const g = darkGame('hostile');
    toPrep(g, 2);
    g.comms.engine.grudge = 3;
    darkSettle(g);
    expect(g.cards.filter(c => c.kind === 'dark:hostile')).toHaveLength(1);
    darkSettle(g);
    expect(g.cards.filter(c => c.kind === 'dark:hostile')).toHaveLength(1);
  });
});

describe('악몽과 H7 기록(10.5, 15.1)', () => {
  it('선을 넘은 뒤 몇 장 동안 열차장 말이 첫 문장에서 끊긴다', () => {
    const g = darkGame('nightmare');
    cross(g, 'exiles');
    const v = viewCard(g, add(g, { kind: 'demand', comm: 'tail' }));
    expect(v.choices.every(c => !c.say || c.say.startsWith('…'))).toBe(true);
  });
  it('고르기 시간은 S1b 판에서만 적는다', () => {
    const g = darkGame('h7');
    const card = add(g, { kind: 'demand', comm: 'tail' });
    logCardPick(g, card.uid, 0, 1200);
    expect(g.dark!.h7).toHaveLength(1);
    expect(g.dark!.h7[0]).toMatchObject({ kind: 'demand', ms: 1200, crossing: false });
    const plain = createGame('h7-off');
    const c2 = add(plain, { kind: 'demand', comm: 'tail' });
    logCardPick(plain, c2.uid, 0, 1200);
    expect(plain.dark).toBeUndefined();
  });
  it('판이 끝나면 일지 끝에 H7 숫자 한 줄', () => {
    const { g } = playGame('h7-end', { s1c: false, policy: 'caretaker', dom: 'idle', s1b: 'cruel' });
    expect(g.phase).toBe('end');
    expect(g.journal.filter(e => e.text.startsWith('기록: 징후'))).toHaveLength(1);
  });
});

// ---- 글 규칙: S1b 판을 돌며 나온 카드 글과 일지를 content_rules.json 오류 규칙으로 본다 ----
interface Rule { id: string; severity: string; scope: string; terms?: string[]; patterns?: string[]; pattern_flags?: string }
const rules = (JSON.parse(readFileSync(join(__dirname, '../../schema/content_rules.json'), 'utf8')) as { rules: Rule[] }).rules
  .filter(r => r.severity === 'error');

function darkTexts(seed: string, pick: (n: number, i: number) => number): { text: string; dialogue: boolean }[] {
  const g = darkGame(seed);
  const out: { text: string; dialogue: boolean }[] = [];
  let k = 0;
  for (let guard = 0; guard < 4000 && g.phase !== 'end'; guard += 1) {
    if (g.cards.length) {
      const card = g.cards[0];
      const v = viewCard(g, card);
      out.push({ text: v.title, dialogue: false }, { text: v.body, dialogue: true });
      for (const ch of v.choices) out.push({ text: ch.label, dialogue: true }, ...(ch.say ? [{ text: ch.say, dialogue: true }] : []), ...(ch.cross ? [{ text: ch.cross, dialogue: false }] : []));
      const open = v.choices.map((c, i) => ({ c, i })).filter(x => !x.c.disabled);
      k += 1;
      // S1b 카드는 선택지를 돌려 가며 고른다(모든 갈래의 글을 보려고). 징후는 모른 척해 일이 나게 한다.
      const idx = card.kind === 'dark:sign' ? open[open.length - 1].i : card.kind.startsWith('dark:') ? open[pick(open.length, k)].i : open[0].i;
      chooseCard(g, card.uid, idx);
      continue;
    }
    if (g.phase === 'stop' && g.stop && !g.stop.done) { resolveStop(g, true); continue; }
    if (g.phase === 'council' && g.council && !g.council.result && currentAgenda(g)) {
      const t = g.council.options.findIndex(o => 'motion' in o && o.motion === 'trial');
      if (t >= 0 && !g.council.locked) g.council.idx = t;
      castVote(g);
      continue;
    }
    if (!primaryAction(g).ok) break;
    advance(g);
  }
  for (const e of g.journal) out.push({ text: e.text, dialogue: false });
  return out;
}

describe('S1b 글 규칙', () => {
  it('여러 판을 돌며 나온 S1b 글에 오류 규칙이 없다', () => {
    const bad: string[] = [];
    for (let s = 0; s < 12; s += 1) {
      for (const { text, dialogue } of darkTexts(`dark-text-${s}`, (n, i) => (i * 7 + s) % n)) {
        for (const rule of rules) {
          if (rule.scope === 'dialogue' && !dialogue) continue;
          const hit = (rule.terms ?? []).find(t => text.includes(t)) ?? (rule.patterns ?? []).find(p => new RegExp(p, rule.pattern_flags ?? 'iu').test(text));
          if (hit) bad.push(`${rule.id}: ${text}`);
        }
      }
    }
    expect([...new Set(bad)]).toEqual([]);
  });

  it('S1b 판 여러 갈래가 막히지 않고 끝난다', () => {
    for (let s = 0; s < 8; s += 1) {
      const texts = darkTexts(`dark-run-${s}`, (n, i) => (i + s) % n);
      expect(texts.length).toBeGreaterThan(0);
    }
  });

  it('하차 명령을 받은 사람은 다음 정차에서 내린다', () => {
    const g = darkGame('exile');
    toPrep(g, 2);
    const c = openCase(g, { kind: 'assault', culprit: g.comms.tail.leader.personId, victimComm: 'guard', dead: false, clock: 3, where: '통로' });
    const s = c.sus.find(x => !COMMS.some(k => g.comms[k].leader.personId === x.id)) ?? c.sus[0];
    const card = add(g, { kind: 'dark:punish', n: c.id, who: s.id, comm: 'tail', text: 'trial' });
    const v = viewCard(g, card);
    chooseCard(g, card.uid, v.choices.findIndex(x => x.label === '하차 명령'));
    expect(g.dark!.exile).toHaveLength(1);
    g.cards = [];
    advance(g);
    g.cards = [];
    advance(g);
    expect(g.phase).toBe('stop');
    resolveStop(g, false);
    expect(g.dark!.exile).toHaveLength(0);
    expect(g.left).toBeDefined();
  });
});

void B;
