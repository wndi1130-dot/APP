import { describe, expect, it } from 'vitest';
import { chooseCard, createGame, createS1cGame, enableDark, PLACES, STAY, stopCrew, viewCard } from '../../src/game';
import type { Game } from '../../src/game';
import { flagged, openCase, punish } from '../../src/game/dark/cases';
import { B } from '../../src/game/dark/data';
import { actAll } from '../../src/game/dark/embers';
import { truthTick } from '../../src/game/dark/cases';
import { darkSettle } from '../../src/game/dark/hooks';
import { onDeath } from '../../src/game/death';
import { runOrder } from '../../src/game/dark/order';
import { adults, alive, nameOf } from '../../src/game/dark/state';
import { MOTIONS } from '../../src/game/motions';
import { PROFILES } from '../../src/game/state';
import type { Ember } from '../../src/game/dark/state';

// Codex J09 판정(/mnt/project-files/s1b_wip/j09_verdict.md)의 S1a 고칠 목록 회귀 테스트.

function darkGame(seed: string): Game {
  const g = createGame(seed);
  enableDark(g);
  g.seg = 4;
  return g;
}

describe('J09 2·11. 성공한 암살은 늘 수사를 연다', () => {
  function ordered(seed: string): { g: Game; exe: string } {
    const g = darkGame(seed);
    const target = adults(g, 'front', { noRep: true })[0].id;
    const exe = adults(g, 'guard', { noRep: true })[0].id;
    g.dark!.order = { target, why: 'hostile', exe: 'guard', exeId: exe, method: 'accident', at: g.seg };
    return { g, exe };
  }
  it('사고로 꾸며 들키지 않아도 사건이 열리고 실행자 단서는 없다. 들키면 실행자가 붙잡힌다', () => {
    let hidden = 0;
    let seen = 0;
    for (let i = 0; i < 200 && (hidden === 0 || seen === 0); i += 1) {
      const { g, exe } = ordered(`order-${i}`);
      runOrder(g, 'travel');
      if (g.dark!.stats.ordersOk !== 1) continue;
      expect(g.dark!.cases).toHaveLength(1);
      const c = g.dark!.cases[0];
      const s = c.sus.find(x => x.culprit)!;
      const card = g.cards.find(x => x.kind === 'dark:order_done')!;
      expect(card.n).toBe(c.id);
      const v = viewCard(g, card);
      expect(v.choices.length).toBe(3);
      if (card.text === 'hidden') {
        hidden += 1;
        expect(s.clues).toHaveLength(0);
        expect(v.body).toContain('사고라고 적혔다. 그래도 수사가 열린다.');
      } else {
        seen += 1;
        expect(s.id === exe || s.proxyFor === exe).toBe(true);
        expect(s.clues.length).toBeGreaterThanOrEqual(2);
        expect(v.body).toContain('붙잡혔다');
      }
    }
    expect(hidden).toBeGreaterThan(0);
    expect(seen).toBeGreaterThan(0);
  });
});

describe('J09 1. 진범을 벌하면 임박은 \'오지 않은 일\'로 끝난다', () => {
  it('임박을 띄운 뒤 진범을 벌하면 이동 때 카드 한 장이 나오고 아무도 다치지 않는다', () => {
    const g = darkGame('defuse');
    const d = g.dark!;
    const actor = adults(g, 'tail', { noRep: true })[0].id;
    const e: Ember = {
      id: 901, who: 'tail', actor, target: 'guard', mark: g.comms.guard.leader.personId, cause: 'fervor',
      stage: 2, imm: 3, quiet: 0, guardUntil: -1, sab: 'heating', blocked: false, born: g.seg,
    };
    d.embers.push(e);
    d.violentUsed = 1;
    const c = openCase(g, { kind: 'heating', culprit: actor, victimComm: 'front', dead: false, clock: 3, where: '앞칸', ember: e.id });
    const s = c.sus.find(x => x.culprit)!;
    punish(g, c, s, 'ration', 'summary');
    expect(d.embers.find(x => x.id === e.id)?.defused).toBe(true);
    const injured = g.injured;
    const deaths = (g.deathLog ?? []).length;
    g.cards = [];
    actAll(g);
    const cards = g.cards.filter(x => x.kind === 'dark:act');
    expect(cards).toHaveLength(1);
    expect(cards[0].text).toContain('이미 벌받은 뒤였다');
    expect(g.injured).toBe(injured);
    expect((g.deathLog ?? []).length).toBe(deaths);
    expect(d.embers.some(x => x.id === e.id)).toBe(false);
    expect(d.violentUsed).toBe(0);
  });
});

describe('J09 3. 이름 거름: 이름 풀 언어가 pl·de·cz인 사람만 군중 순위에 오른다', () => {
  const g = darkGame('names');
  const suspect = (id: string) => ({ id, culprit: false, facts: ['access' as const], clues: [], acq: false });
  const adult = (pred: (lang: string | undefined) => boolean) => PROFILES.find(p => p.age >= 16 && pred(p.name_lang))!;
  it('같은 사실이면 pl·de·cz는 표시되고 다른 풀은 언제나 빠진다', () => {
    for (const lang of ['pl', 'de', 'cz']) expect(flagged(g, suspect(adult(l => l === lang).id))).toBe(true);
    for (const lang of ['uk', 'sk', 'hu', 'lt']) expect(flagged(g, suspect(adult(l => l === lang).id))).toBe(false);
  });
  it('name_lang이 없는 프로필은 빠진다', () => {
    const p = adult(l => l === 'pl');
    const saved = p.name_lang;
    try {
      delete p.name_lang;
      expect(flagged(g, suspect(p.id))).toBe(false);
    } finally { p.name_lang = saved; }
  });
});

describe('J09 4. 처형은 유죄 판결을 받은 피고에게만', () => {
  function tried(seed: string) {
    const g = darkGame(seed);
    const c = openCase(g, { kind: 'assault', culprit: adults(g, 'tail', { noRep: true })[0].id, victimComm: 'guard', dead: false, clock: 3, where: '통로' });
    return { g, c, s: c.sus[0] };
  }
  it('판결 없이 trial로 부르거나 약식으로 부르면 아무 일도 없다', () => {
    for (const via of ['trial', 'summary'] as const) {
      const { g, c, s } = tried(`noexec-${via}`);
      const harm = g.dark!.harm;
      const deaths = (g.deathLog ?? []).length;
      expect(punish(g, c, s, 'execute', via)).toEqual([]);
      expect(g.dark!.harm).toBe(harm);
      expect((g.deathLog ?? []).length).toBe(deaths);
      expect(c.status).not.toBe('closed');
    }
  });
  it('다른 피고가 유죄면 이 사람은 처형할 수 없다', () => {
    const { g, c } = tried('noexec-other');
    expect(c.sus.length).toBeGreaterThan(1);
    const [a, b] = c.sus;
    MOTIONS.trial.onPass(g, { kind: 'motion', motion: 'trial', person: a.id, ref: c.id });
    expect(punish(g, c, b, 'execute', 'trial')).toEqual([]);
    expect(punish(g, c, a, 'execute', 'trial').length).toBeGreaterThan(0);
  });
});

describe('J09 5. 정차 암살은 둘이 같은 작업조로 나가야 한다', () => {
  function stopOrder(seed: string) {
    const g = darkGame(seed);
    const target = adults(g, 'front', { noRep: true })[0].id;
    const exe = adults(g, 'guard', { noRep: true })[0].id;
    g.dark!.order = { target, why: 'hostile', exe: 'guard', exeId: exe, method: 'stop', at: g.seg };
    g.stop = { place: PLACES[0].id, target: 'coal', stay: Object.keys(STAY)[0] as never, crewComm: 'tail', crewSize: 4, done: false, result: null };
    return { g, target, exe };
  }
  it('작업조 명단에 실행자와 대상이 붙는다', () => {
    const { g, target, exe } = stopOrder('stop-crew');
    const crew = stopCrew(g);
    expect(crew).toContain(nameOf(g, target));
    expect(crew).toContain(nameOf(g, exe));
    g.dark!.order = null;
    expect(stopCrew(g)).not.toContain(nameOf(g, target));
  });
  it('둘이 작업조에 없으면 명령은 남아 다음 정차를 기다리고, 있으면 실행된다', () => {
    const { g } = stopOrder('stop-wait');
    runOrder(g, 'stop', []);
    expect(g.dark!.order).not.toBeNull();
    expect(g.dark!.executors).toHaveLength(0);
    runOrder(g, 'stop', stopCrew(g));
    expect(g.dark!.order).toBeNull();
    expect(g.dark!.executors).toHaveLength(1);
  });
});

describe('J09 3(장인). 같은 장인을 노린 첫 4단계는 부상, 둘째부터 죽을 수 있다', () => {
  it('첫 시도는 늘 다치고 둘째는 사망 굴림을 한다', () => {
    const g = createS1cGame('artisan');
    enableDark(g);
    g.seg = 4;
    const person = g.dom!.people.find(p => p.alive && p.age >= 16)!;
    person.skill = 3;
    const id = PROFILES.find(p => p.name === person.name)!.id;
    const ember = (n: number): Ember => ({
      id: 900 + n, who: 'tail', actor: adults(g, 'tail', { noRep: true })[0].id, target: 'aide', mark: id, cause: 'fervor',
      stage: 3, imm: 4, quiet: 0, guardUntil: -1, sab: 'heating', blocked: false, born: g.seg,
    });
    const base = B.assnBase;
    B.assnBase = 5; // 사망 굴림이 있으면 반드시 죽게
    try {
      g.dark!.embers.push(ember(1));
      actAll(g);
      expect(alive(g, id)).toBe(true);
      expect(g.dark!.craftHit).toContain(id);
      g.dark!.embers.push(ember(2));
      actAll(g);
      expect(alive(g, id)).toBe(false);
    } finally { B.assnBase = base; }
  });
});

describe('J09 7. 관행은 두 번째 칸 안 죽음에 한 번 더 묻는다', () => {
  it('둘째 죽음엔 \'지난번처럼\' 카드, 셋째부터는 묻지 않는다', () => {
    const g = darkGame('practice');
    g.phase = 'prep';
    const names = adults(g, 'tail', { noRep: true }).slice(0, 3).map(p => p.name);
    const answer = () => {
      const card = g.cards.find(c => c.kind === 'dark:corpse_rule');
      expect(card).toBeTruthy();
      const v = viewCard(g, card!);
      chooseCard(g, card!.uid, 0);
      return v.body;
    };
    onDeath(g, 'tail', [names[0]]);
    darkSettle(g);
    expect(answer()).not.toContain('지난번처럼');
    onDeath(g, 'tail', [names[1]]);
    darkSettle(g);
    expect(answer()).toContain('지난번처럼');
    expect(g.dark!.fresh).toEqual([]);
    onDeath(g, 'tail', [names[2]]);
    darkSettle(g);
    expect(g.cards.some(c => c.kind === 'dark:corpse_rule')).toBe(false);
  });
});

describe('J09 6. 진실 창은 벌한 다음 구간부터 여섯 번', () => {
  it('벌한 구간엔 굴리지 않고, 다음 구간부터 revealWindow번 굴린 뒤 사라진다', () => {
    const g = darkGame('truth');
    const id = adults(g, 'tail', { noRep: true })[0].id;
    const revealP = B.revealP;
    const start = g.seg;
    try {
      // 늘 드러나는 값이어도 벌한 구간 정산엔 예고 카드가 없다
      B.revealP = 1;
      g.dark!.innocents = [{ id, comm: 'tail', seg: start, caseId: 1, how: 'punish' }];
      truthTick(g);
      expect(g.cards.some(c => c.kind === 'dark:truth')).toBe(false);
      g.seg = start + 1;
      truthTick(g);
      expect(g.cards.some(c => c.kind === 'dark:truth')).toBe(true);
      // 안 드러나는 값이면 start+1..start+revealWindow 동안 남고 그다음에 빠진다
      g.cards = [];
      B.revealP = 0;
      g.dark!.innocents = [{ id, comm: 'tail', seg: start, caseId: 1, how: 'punish' }];
      for (let s = start; s <= start + B.revealWindow; s += 1) {
        g.seg = s;
        truthTick(g);
        expect(g.dark!.innocents).toHaveLength(1);
      }
      g.seg = start + B.revealWindow + 1;
      truthTick(g);
      expect(g.dark!.innocents).toHaveLength(0);
    } finally { B.revealP = revealP; }
  });
});

describe('PR 41 리뷰 2. 관행 카드 뒤에도 밤샘을 묻는다', () => {
  it('두 번째 관행 카드에 답하면 대표 시신은 밤샘 카드를 거친다', () => {
    const g = darkGame('practice-vigil');
    g.phase = 'prep';
    const first = adults(g, 'tail', { noRep: true })[0].name;
    onDeath(g, 'tail', [first]);
    darkSettle(g);
    let card = g.cards.find(c => c.kind === 'dark:corpse_rule')!;
    chooseCard(g, card.uid, 0);
    g.cards = [];
    // 대표는 죽자마자 다음 사람이 잇는다. 밤샘을 바랄 사람인지는 죽은 때 본다.
    const rep = g.comms.engine.leader.name;
    onDeath(g, 'engine', [rep]);
    expect(g.comms.engine.leader.name).not.toBe(rep);
    darkSettle(g);
    card = g.cards.find(c => c.kind === 'dark:corpse_rule')!;
    expect(viewCard(g, card).body).toContain('지난번처럼');
    chooseCard(g, card.uid, 0);
    expect(g.cards.some(c => c.kind === 'dark:vigil' && c.who === rep)).toBe(true);
  });
});

describe('PR 41 리뷰 3. 들킨 성공 암살은 일지로 덮지 못한다', () => {
  it("들켰으면 '덮는다' 대신 '입단속한다'(공포·경비대 노출)가 나온다", () => {
    let checked = 0;
    for (let i = 0; i < 200 && checked < 2; i += 1) {
      const g = darkGame(`hush-${i}`);
      const target = adults(g, 'front', { noRep: true })[0].id;
      const exe = adults(g, 'guard', { noRep: true })[0].id;
      g.dark!.order = { target, why: 'hostile', exe: 'guard', exeId: exe, method: 'accident', at: g.seg };
      runOrder(g, 'travel');
      const card = g.cards.find(x => x.kind === 'dark:order_done');
      if (!card) continue;
      const labels = viewCard(g, card).choices.map(c => c.label);
      if (card.text === 'hidden') {
        expect(labels).toContain('덮는다');
        expect(labels).not.toContain('입단속한다');
        continue;
      }
      checked += 1;
      expect(labels).not.toContain('덮는다');
      const fear = g.fear;
      const expo = g.comms.guard.base[3];
      chooseCard(g, card.uid, labels.indexOf('입단속한다'));
      expect(g.fear).toBe(Math.min(100, fear + B.hushFear));
      expect(g.comms.guard.base[3]).toBe(expo + B.hushExpo);
      expect(g.dark!.cases.find(c => c.id === card.n)?.status).toBe('closed');
    }
    expect(checked).toBeGreaterThan(0);
  });
});
