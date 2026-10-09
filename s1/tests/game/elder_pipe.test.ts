import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  agendaOptions, cancelRestore, castVote, chooseCard, COMMS, createGame, createS1cGame, currentAgenda, D, domesticSettle, elderMult, elderPerson,
  elderTick, escortOptions, fieldMult, freeTeacher, isLawAgenda, knowledgeTick, motionsNow, openCouncil, personById, pipePending, runWorkshop,
  setEscort, startRestore, techMult, techRelSides, viewCard, workshopState, addCard, MOTIONS, enableDark,
} from '../../src/game';
import type { Comm, Game, Variant } from '../../src/game';
import { playGame } from '../../tools/s1c_bot';

// S1c 늙은 장인의 마지막(s1c_domestic 8.9)과 E3 배관 추인(7.3). 숫자는 제안이라 값보다 규칙의 모양을 본다.

const fresh = (seed = 'ep'): Game => createS1cGame(seed);

const rules = (JSON.parse(readFileSync(join(__dirname, '../../schema/content_rules.json'), 'utf8')) as { rules: { severity: string; terms?: string[]; patterns?: string[]; pattern_flags?: string }[] }).rules
  .filter(r => r.severity === 'error');
const bad = (text: string): boolean =>
  rules.some(r => (r.terms ?? []).some(t => text.includes(t)) || (r.patterns ?? []).some(p => new RegExp(p, r.pattern_flags ?? 'iu').test(text)));

/** 아크를 정해 둔다. */
function setArc(g: Game, role: '수석 기관사' | '의무장' | '공방장', first = 8, gap = 2): string {
  const p = g.dom!.people.find(x => x.role === role)!;
  g.dom!.elder = { who: p.id, first, gap, stage: 0 };
  return p.id;
}

/** 정산 구간을 하나 세어 아크를 한 걸음 보낸다(g.seg만 맞춘다). */
function tickAt(g: Game, seg: number): void {
  g.seg = seg;
  elderTick(g);
}

function elderCard(g: Game) {
  const card = g.cards.find(c => c.kind === 'dom:elder')!;
  return { card, view: viewCard(g, card) };
}

function pickElder(g: Game, special: string): boolean {
  const { card, view } = elderCard(g);
  const i = view.choices.findIndex(c => c.special === special);
  expect(i, special).toBeGreaterThanOrEqual(0);
  return chooseCard(g, card.uid, i);
}

describe('늙은 장인의 마지막(8.9)', () => {
  it('판마다 하나만 정해지고, 같은 시드면 같으며, 세 사람이 다 나온다. 의무장은 60세 이상', () => {
    const seen = new Set<string>();
    for (let i = 0; i < 60; i += 1) {
      const g = fresh(`arc-${i}`);
      const a = g.dom!.elder!;
      const p = elderPerson(g)!;
      seen.add(p.role);
      expect(['수석 기관사', '의무장', '공방장']).toContain(p.role);
      expect(a.first).toBeGreaterThanOrEqual(8);
      expect(a.first).toBeLessThanOrEqual(14);
      expect([2, 3]).toContain(a.gap);
      expect(a.stage).toBe(0);
      if (p.role === '의무장') {
        expect(p.age).toBeGreaterThanOrEqual(60);
        expect(g.comms.medtech.leader.age).toBe(p.age);
      }
      expect(JSON.stringify(fresh(`arc-${i}`).dom!.elder)).toBe(JSON.stringify(a));
    }
    expect([...seen].sort()).toEqual(['수석 기관사', '공방장', '의무장'].sort());
  });

  it('첫 조짐 전엔 아무 일도 없고, 첫 조짐 구간에 일지 한 줄과 카드가 선다', () => {
    const g = fresh();
    setArc(g, '공방장', 9);
    tickAt(g, 8);
    expect(g.dom!.elder!.stage).toBe(0);
    expect(g.cards.some(c => c.kind === 'dom:elder')).toBe(false);
    const n = g.journal.length;
    tickAt(g, 9);
    expect(g.dom!.elder!.stage).toBe(1);
    expect(g.cards.filter(c => c.kind === 'dom:elder')).toHaveLength(1);
    expect(g.journal.length).toBe(n + 1);
    expect(g.journal[g.journal.length - 1].text).toContain('줄질을 하다 숨을 고른다');
  });

  it('조짐은 거짓말하지 않는다: 첫 조짐 2구간 뒤 짙은 조짐, 그다음 구간에 쓰러진다(고르지 않아도)', () => {
    const g = fresh();
    const id = setArc(g, '수석 기관사', 8, 2);
    tickAt(g, 8);
    tickAt(g, 9);
    expect(g.dom!.elder!.stage).toBe(1);
    tickAt(g, 10);
    expect(g.dom!.elder!.stage).toBe(2);
    expect(g.journal[g.journal.length - 1].text).toContain('압력계를 읽는 손이 떨린다');
    expect(personById(g, id)!.alive).toBe(true);
    tickAt(g, 11);
    expect(g.dom!.elder!.stage).toBe(3);
    const p = personById(g, id)!;
    expect(p.alive).toBe(false);
    expect(g.deaths).toContain(p.name);
  });

  it('간격 3이면 쓰러짐까지 4구간', () => {
    const g = fresh();
    const id = setArc(g, '의무장', 8, 3);
    tickAt(g, 8);
    tickAt(g, 10);
    expect(g.dom!.elder!.stage).toBe(1);
    tickAt(g, 11);
    expect(g.dom!.elder!.stage).toBe(2);
    tickAt(g, 12);
    expect(personById(g, id)!.alive).toBe(false);
  });

  it('판에 한 번뿐이다: 쓰러진 뒤엔 더 부르지 않는다', () => {
    const g = fresh();
    setArc(g, '공방장', 8, 2);
    for (let s = 8; s <= 11; s += 1) tickAt(g, s);
    const deaths = g.deaths.length;
    const cards = g.cards.length;
    for (let s = 12; s <= 24; s += 1) tickAt(g, s);
    expect(g.deaths.length).toBe(deaths);
    expect(g.cards.length).toBe(cards);
  });

  it('조짐 전에 그 사람이 다른 까닭으로 죽으면 아크는 조용히 끝난다', () => {
    const g = fresh();
    const id = setArc(g, '공방장', 8);
    personById(g, id)!.alive = false;
    tickAt(g, 8);
    expect(g.dom!.elder!.stage).toBe(3);
    expect(g.cards.some(c => c.kind === 'dom:elder')).toBe(false);
  });

  it('조짐 뒤에 그 사람이 먼저 죽으면 거기서 끝난다(두 번 죽지 않는다)', () => {
    const g = fresh();
    const id = setArc(g, '수석 기관사', 8);
    tickAt(g, 8);
    personById(g, id)!.alive = false;
    const deaths = g.deaths.length;
    for (let s = 9; s <= 14; s += 1) tickAt(g, s);
    expect(g.dom!.elder!.stage).toBe(3);
    expect(g.deaths.length).toBe(deaths);
    // 카드가 남아 있어도 고를 것 없이 알리는 줄이다
    const { view } = elderCard(g);
    expect(view.choices).toHaveLength(1);
  });

  it('쓰러지면 시신 처리 법을 따르고, 수석 기관사·의무장이면 대표를 잇는다', () => {
    const g = fresh();
    setArc(g, '수석 기관사', 8);
    const old = g.comms.engine.leader.name;
    const pop = g.comms.engine.pop;
    for (let s = 8; s <= 11; s += 1) tickAt(g, s);
    expect(g.comms.engine.pop).toBe(pop - 1);
    expect(g.comms.engine.leader.name).not.toBe(old);
    expect(g.journal.some(e => e.text.includes('대표 자리를 이었다'))).toBe(true);
    expect(g.corpseIssue).toBe(true);
    const h = fresh('arc-med');
    setArc(h, '의무장', 8);
    const oldMed = h.comms.medtech.leader.name;
    for (let s = 8; s <= 11; s += 1) tickAt(h, s);
    expect(h.comms.medtech.leader.name).not.toBe(oldMed);
  });

  it('S1b를 켠 판에서도 대표 승계가 한 번만 일어난다', () => {
    const g = fresh('arc-dark');
    enableDark(g);
    setArc(g, '수석 기관사', 8);
    for (let s = 8; s <= 11; s += 1) tickAt(g, s);
    expect(g.journal.filter(e => e.text.includes('대표 자리를 이었다'))).toHaveLength(1);
  });

  it('그 분야에 아는 사람이 더는 없으면 다음 정산에서 카운트다운이 시작된다(8.5)', () => {
    const g = fresh();
    setArc(g, '공방장', 8);
    // 용접공은 공방장의 견습이다. 용접공이 없으면 마지막 사람이다.
    const welder = g.dom!.people.find(p => p.role === '용접공')!;
    welder.gone = true;
    for (let s = 8; s <= 11; s += 1) tickAt(g, s);
    knowledgeTick(g);
    expect(g.dom!.countdown.craft).toBe(D.countdown);
  });

  it('판을 끝까지 돌리면 24구간 안에 쓰러진다. JSON으로 저장해도 아크 상태가 그대로다', () => {
    let fell = 0;
    for (let i = 0; i < 6; i += 1) {
      const { g } = playGame(`arc-run-${i}`, { s1c: true, policy: 'caretaker', dom: 'engaged' });
      const a = g.dom!.elder!;
      expect(JSON.parse(JSON.stringify(g)).dom.elder).toEqual(a);
      if (g.seg >= a.first + a.gap + 3) {
        expect(a.stage).toBe(3);
        fell += 1;
      }
    }
    expect(fell).toBeGreaterThan(0);
  });

  it('저장한 판을 불러와도 이어진다(조짐 중간에 JSON 왕복)', () => {
    const g = fresh();
    const id = setArc(g, '공방장', 8);
    tickAt(g, 8);
    pickElder(g, 'dom:elder:rest');
    const h = JSON.parse(JSON.stringify(g)) as Game;
    expect(h.dom!.elder).toEqual(g.dom!.elder);
    for (let s = 9; s <= 12; s += 1) tickAt(h, s);
    expect(personById(h, id)!.alive).toBe(false);
  });

  describe('견습을 서두른다', () => {
    it('이미 가르치는 견습이 있으면 남은 구간이 절반(올림)이 되고, 그 분야 기술이 ×0.7이다', () => {
      const g = fresh();
      const id = setArc(g, '공방장', 8);
      const welder = g.dom!.people.find(p => p.role === '용접공')!;
      welder.learn!.left = 5;
      tickAt(g, 8);
      const before = fieldMult(g, 'craft');
      expect(pickElder(g, 'dom:elder:pupil')).toBe(true);
      expect(welder.learn!.left).toBe(3);
      expect(g.dom!.elder!.choice).toBe('pupil');
      expect(elderMult(g, 'craft')).toBe(D.elderPupilMult);
      // 가르치기 곱(×0.85)을 대신한다. 겹쳐서 곱하지 않는다.
      expect(before).toBeCloseTo(D.teachMult, 5);
      expect(fieldMult(g, 'craft')).toBeCloseTo(D.elderPupilMult, 5);
      // 다른 분야는 그대로다
      expect(fieldMult(g, 'engine')).toBe(1);
      expect(personById(g, id)!.pupil).toBe(welder.id);
    });

    it('남은 구간이 1이면 1로 남는다', () => {
      const g = fresh();
      setArc(g, '공방장', 8);
      const welder = g.dom!.people.find(p => p.role === '용접공')!;
      welder.learn!.left = 1;
      tickAt(g, 8);
      pickElder(g, 'dom:elder:pupil');
      expect(welder.learn!.left).toBe(1);
    });

    it('견습이 없으면 새 견습생이 붙는다', () => {
      const g = fresh();
      const id = setArc(g, '수석 기관사', 8);
      tickAt(g, 8);
      const n = g.dom!.people.length;
      const { view } = elderCard(g);
      expect(view.choices.find(c => c.special === 'dom:elder:pupil')!.disabled).toBeUndefined();
      expect(pickElder(g, 'dom:elder:pupil')).toBe(true);
      expect(g.dom!.people.length).toBe(n + 1);
      const pupil = g.dom!.people[n];
      expect(pupil.field).toBe('engine');
      expect(pupil.learn!.by).toBe(id);
      expect(personById(g, id)!.pupil).toBe(pupil.id);
      expect(fieldMult(g, 'engine')).toBeCloseTo(D.elderPupilMult, 5);
    });

    it('쓰러지면 곱이 사라진다', () => {
      const g = fresh();
      setArc(g, '수석 기관사', 8);
      tickAt(g, 8);
      pickElder(g, 'dom:elder:pupil');
      for (let s = 9; s <= 11; s += 1) tickAt(g, s);
      expect(elderMult(g, 'engine')).toBe(1);
    });
  });

  describe('매뉴얼을 남긴다', () => {
    it('2구간에 쓴다(평소 3구간)', () => {
      const g = fresh();
      const id = setArc(g, '공방장', 8);
      tickAt(g, 8);
      expect(pickElder(g, 'dom:elder:manual')).toBe(true);
      expect(personById(g, id)!.writing).toBe(D.elderManualSegs);
      expect(D.elderManualSegs).toBeLessThan(D.writeSegs);
      knowledgeTick(g);
      expect(g.dom!.manuals.craft).toBe(false);
      knowledgeTick(g);
      expect(g.dom!.manuals.craft).toBe(true);
    });

    it('기관 매뉴얼은 기관실 관계 −15 이하면 거절한다(그대로)', () => {
      const g = fresh();
      setArc(g, '수석 기관사', 8);
      g.comms.engine.rel = -20;
      tickAt(g, 8);
      const { view } = elderCard(g);
      expect(view.choices.find(c => c.special === 'dom:elder:manual')!.disabled).toBe('기관실이 거절한다');
      expect(pickElder(g, 'dom:elder:manual')).toBe(false);
      // 나머지 둘은 열려 있다
      expect(view.choices.filter(c => !c.disabled)).toHaveLength(2);
    });

    it('이미 매뉴얼이 있으면 흐리다', () => {
      const g = fresh();
      setArc(g, '의무장', 8);
      g.dom!.manuals.med = true;
      tickAt(g, 8);
      const { view } = elderCard(g);
      expect(view.choices.find(c => c.special === 'dom:elder:manual')!.disabled).toBe('이미 있다');
    });
  });

  describe('쉬게 둔다', () => {
    it('쓰러지는 때가 1구간 늦춰지고, 그 분야 ×0.85, 그 공동체 관계 +3', () => {
      const g = fresh();
      const id = setArc(g, '수석 기관사', 8, 2);
      tickAt(g, 8);
      const rel = g.comms.engine.rel;
      expect(pickElder(g, 'dom:elder:rest')).toBe(true);
      expect(g.comms.engine.rel).toBe(rel + D.elderRestRel);
      expect(g.dom!.elder!.fall).toBe(8 + 2 + 1 + D.elderRestDelay);
      expect(fieldMult(g, 'engine')).toBeCloseTo(D.elderRestMult, 5);
      tickAt(g, 10);
      tickAt(g, 11);
      expect(personById(g, id)!.alive).toBe(true);
      tickAt(g, 12);
      expect(personById(g, id)!.alive).toBe(false);
    });

    it('그동안 가르치지도 쓰이지도 않는다', () => {
      const g = fresh();
      const id = setArc(g, '공방장', 8);
      const welder = g.dom!.people.find(p => p.role === '용접공')!;
      const left = welder.learn!.left;
      tickAt(g, 8);
      pickElder(g, 'dom:elder:rest');
      const chief = personById(g, id)!;
      expect(chief.resting).toBe(true);
      knowledgeTick(g);
      expect(welder.learn!.left).toBe(left);
      expect(freeTeacher(g, 'craft')).not.toBe(chief);
      expect(escortOptions(g).find(o => o.id === id)!.why).toBe('쉬는 중');
      setEscort(g, id);
      expect(g.dom!.escort).toBeNull();
    });
  });

  describe('카드와 글', () => {
    it('세 길이 열차장의 외침이고 글자 수·금지 표현 규칙을 지킨다', () => {
      for (const role of ['수석 기관사', '의무장', '공방장'] as const) {
        const g = fresh(`txt-${role}`);
        setArc(g, role, 8);
        tickAt(g, 8);
        const { view } = elderCard(g);
        expect(view.required).toBe(true);
        expect(view.choices.map(c => c.special)).toEqual(['dom:elder:pupil', 'dom:elder:manual', 'dom:elder:rest']);
        const texts = [view.title, view.body];
        for (const c of view.choices) {
          expect(c.label.length).toBeLessThanOrEqual(15);
          expect(c.say!.length).toBeLessThanOrEqual(40);
          expect((c.say!.match(/[.!?]/g) ?? []).length).toBeLessThanOrEqual(2);
          texts.push(c.label, c.say!, ...(c.extra ?? []));
        }
        for (const t of texts) expect(bad(t), t).toBe(false);
      }
    });

    it('조짐·쓰러짐 일지에 병명이 없다(늙음과 추위)', () => {
      const lines: string[] = [];
      for (const role of ['수석 기관사', '의무장', '공방장'] as const) {
        const g = fresh(`jr-${role}`);
        setArc(g, role, 8);
        for (let s = 8; s <= 11; s += 1) tickAt(g, s);
        lines.push(...g.journal.map(e => e.text));
      }
      for (const t of lines) {
        expect(bad(t), t).toBe(false);
        expect(t).not.toMatch(/열병|감염|전염|격리|역병|발진|티푸스|이가|위생|불결|더럽/);
      }
    });
  });

  it('안 고르고 여러 번 정산해도 멈추지 않는다(봇 판 한 번)', () => {
    const { g } = playGame('arc-bot', { s1c: true, policy: 'first', dom: 'idle' });
    expect(g.phase).toBe('end');
    expect(Number.isFinite(g.coal)).toBe(true);
  });
});

// ---- E3 배관 추인 ----
function pipeGame(seed = 'pipe', variant: Variant = 'a'): Game {
  const g = fresh(seed);
  const d = g.dom!;
  d.techs.e1 = { stage: 'done', defect: false, progress: 3, need: 3 };
  d.frags.engine = 5;
  d.parts = 6;
  expect(startRestore(g, 'e3', 'full', variant)).toBe(true);
  return g;
}

/** 모든 칸의 관계를 정해 표결이 한쪽으로 가게 한다. */
function lean(g: Game, rel: number): void {
  for (const c of COMMS) { g.comms[c].rel = rel; g.comms[c].grudge = 0; }
}

function relSnap(g: Game): Record<Comm, number> {
  return Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel])) as Record<Comm, number>;
}

function pipeIndex(g: Game): number {
  return g.council!.options.findIndex(o => !isLawAgenda(o) && o.motion === 'pipe');
}

function openAndVote(g: Game, rel: number): void {
  openCouncil(g);
  g.phase = 'council';
  g.council!.idx = pipeIndex(g);
  expect(currentAgenda(g)).toMatchObject({ kind: 'motion', motion: 'pipe' });
  lean(g, rel);
  castVote(g);
}

describe('E3 배관 추인(7.3)', () => {
  it('복원을 시작해도 관계가 안 움직이고, 다음 회기에 배관 추인 안건이 오른다', () => {
    const g = fresh('pipe-start');
    const d = g.dom!;
    d.techs.e1 = { stage: 'done', defect: false, progress: 3, need: 3 };
    d.frags.engine = 5;
    d.parts = 6;
    const before = relSnap(g);
    expect(startRestore(g, 'e3', 'full', 'a')).toBe(true);
    expect(relSnap(g)).toEqual(before);
    expect(d.techs.e3!.pending).toBe(true);
    expect(pipePending(g)).toBe('a');
    expect(motionsNow(g)).toEqual([{ kind: 'motion', motion: 'pipe' }]);
    openCouncil(g);
    const i = pipeIndex(g);
    expect(i).toBeGreaterThanOrEqual(0);
    const opts = agendaOptions(g).options;
    // 법 안건보다 앞(추인 순서 자리)에 놓인다
    expect(opts.slice(0, i).every(o => !isLawAgenda(o) || !!o.ratify)).toBe(true);
    expect(MOTIONS.pipe.title({ kind: 'motion', motion: 'pipe' })).toBe('배관 추인');
    expect(MOTIONS.pipe.changes(g, { kind: 'motion', motion: 'pipe' }).join(' ')).toContain('꼬리칸까지');
  });

  it('갈래 카드로 시작해도 카드 효과 줄이 관계를 움직이지 않는다', () => {
    const g = fresh('pipe-card');
    const d = g.dom!;
    d.techs.e1 = { stage: 'done', defect: false, progress: 3, need: 3 };
    d.frags.engine = 5;
    d.parts = 6;
    addCard(g, { kind: 'dom:fork', text: 'e3', n: 0 });
    const card = g.cards[g.cards.length - 1];
    const view = viewCard(g, card);
    for (const c of view.choices) expect(c.effs).toEqual([]);
    const before = relSnap(g);
    expect(chooseCard(g, card.uid, 1)).toBe(true);
    expect(relSnap(g)).toEqual(before);
    expect(d.techs.e3!.variant).toBe('b');
    expect(d.techs.e3!.pending).toBe(true);
  });

  it('가결이면 고른 변형이 서고, 관계는 그 변형으로 한 번만 움직인다(원하는 쪽 +5, 싫어하는 쪽 −5)', () => {
    const g = pipeGame('pipe-pass', 'a');
    openCouncil(g);
    g.phase = 'council';
    g.council!.idx = pipeIndex(g);
    lean(g, 100);
    const before = relSnap(g);
    const r = castVote(g)!;
    expect(r.passed).toBe(true);
    const st = g.dom!.techs.e3!;
    expect(st.variant).toBe('a');
    expect(st.pending).toBe(false);
    expect(g.dom!.pipeFlip).toBeUndefined();
    const sides = techRelSides('e3', 'a');
    for (const c of COMMS) {
      const want = sides.like.includes(c) ? D.techRel : sides.dislike.includes(c) ? -D.techRel : 0;
      expect(Math.min(100, before[c] + want)).toBe(g.comms[c].rel);
    }
    expect(g.journal.some(e => e.text.includes('추인했다'))).toBe(true);
  });

  it('부결이면 반대 변형으로 가고, 관계는 반대 변형으로만 움직인다(양쪽에 두 번 붙지 않는다)', () => {
    const g = pipeGame('pipe-fail', 'a');
    openCouncil(g);
    g.phase = 'council';
    g.council!.idx = pipeIndex(g);
    lean(g, -100);
    const before = relSnap(g);
    const r = castVote(g)!;
    expect(r.passed).toBe(false);
    const st = g.dom!.techs.e3!;
    expect(st.variant).toBe('b');
    expect(st.pending).toBe(false);
    expect(g.dom!.pipeFlip).toBe('b');
    const sides = techRelSides('e3', 'b');
    for (const c of COMMS) {
      const want = sides.like.includes(c) ? D.techRel : sides.dislike.includes(c) ? -D.techRel : 0;
      expect(Math.max(-100, before[c] + want)).toBe(g.comms[c].rel);
    }
    expect(g.journal.some(e => e.text.includes('추인하지 않았다'))).toBe(true);
  });

  it('추인 전엔 작업을 다 해도 완성되지 않고, 추인 뒤 다음 공방 작업에서 마친다', () => {
    const g = pipeGame('pipe-hold', 'b');
    const d = g.dom!;
    const st = d.techs.e3!;
    st.progress = st.need;
    runWorkshop(g);
    expect(st.stage).toBe('restoring');
    expect(d.restoring).toBe('e3');
    expect(techMult(g, 'e3')).toBe(0);
    expect(workshopState(g).now).toBe('배관 추인을 기다린다');
    // 여러 정산이 지나도 그대로다
    for (let i = 0; i < 3; i += 1) runWorkshop(g);
    expect(st.stage).toBe('restoring');
    openAndVote(g, 100);
    expect(st.stage).toBe('restoring');
    runWorkshop(g);
    expect(st.stage).toBe('done');
    expect(d.restoring).toBeNull();
    expect(techMult(g, 'e3')).toBeGreaterThan(0);
  });

  it('복원이 회기 뒤에 끝나면 추인 결과의 변형으로 끝난다', () => {
    const g = pipeGame('pipe-late', 'a');
    openAndVote(g, -100);
    const st = g.dom!.techs.e3!;
    expect(st.variant).toBe('b');
    expect(st.stage).toBe('restoring');
    st.progress = st.need;
    runWorkshop(g);
    expect(st.stage).toBe('done');
    expect(st.variant).toBe('b');
  });

  it('복원을 취소하면 안건도 내려간다. 이미 오른 안건을 표결해도 아무 일이 없다', () => {
    const g = pipeGame('pipe-cancel', 'a');
    openCouncil(g);
    g.phase = 'council';
    const i = pipeIndex(g);
    expect(i).toBeGreaterThanOrEqual(0);
    cancelRestore(g);
    expect(motionsNow(g)).toEqual([]);
    expect(agendaOptions(g).options.some(o => !isLawAgenda(o) && o.motion === 'pipe')).toBe(false);
    g.council!.idx = i;
    lean(g, -100);
    const before = relSnap(g);
    castVote(g);
    expect(g.dom!.techs.e3).toBeUndefined();
    expect(g.dom!.pipeFlip).toBeUndefined();
    for (const c of COMMS) expect(g.comms[c].rel).toBe(before[c]);
  });

  it('부결로 반대 변형이 된 뒤엔 취소하고 다시 시작해도 그 변형으로 고정되고, 다시 표결하지 않는다', () => {
    const g = pipeGame('pipe-lock', 'a');
    openAndVote(g, -100);
    expect(g.dom!.pipeFlip).toBe('b');
    cancelRestore(g);
    g.dom!.parts = 6;
    const before = relSnap(g);
    expect(startRestore(g, 'e3', 'full', 'a')).toBe(true);
    const st = g.dom!.techs.e3!;
    expect(st.variant).toBe('b');
    expect(st.pending).toBeFalsy();
    expect(relSnap(g)).toEqual(before);
    expect(motionsNow(g)).toEqual([]);
  });

  it('회기에서 다른 안건을 골라 표결하지 않았으면 안건은 다음 회기로 이어진다', () => {
    const g = pipeGame('pipe-carry', 'a');
    openCouncil(g);
    expect(pipeIndex(g)).toBeGreaterThanOrEqual(0);
    g.council = null;
    openCouncil(g);
    expect(pipeIndex(g)).toBeGreaterThanOrEqual(0);
    expect(g.dom!.techs.e3!.pending).toBe(true);
  });

  it('저장한 판을 불러와도 추인 대기가 이어진다', () => {
    const g = pipeGame('pipe-save', 'b');
    const h = JSON.parse(JSON.stringify(g)) as Game;
    expect(h.dom!.techs.e3).toEqual(g.dom!.techs.e3);
    expect(pipePending(h)).toBe('b');
    openCouncil(h);
    expect(pipeIndex(h)).toBeGreaterThanOrEqual(0);
  });

  it('가결/부결 뒤 정산이 끝까지 돈다(domesticSettle)', () => {
    const g = pipeGame('pipe-settle', 'a');
    openAndVote(g, 100);
    const notes: string[] = [];
    domesticSettle(g, notes);
    expect(Number.isFinite(g.dom!.parts)).toBe(true);
  });

  it('다른 갈래 기술(W2 등)은 추인 없이 시작할 때 관계가 움직인다(그대로)', () => {
    const g = fresh('pipe-other');
    const d = g.dom!;
    d.techs.w1 = { stage: 'done', defect: false, progress: 3, need: 3 };
    d.frags.craft = 5;
    d.parts = 6;
    const before = relSnap(g);
    expect(startRestore(g, 'w2', 'full', 'b')).toBe(true);
    expect(d.techs.w2!.pending).toBeFalsy();
    expect(g.comms.tail.rel).toBe(before.tail + D.techRel);
    expect(g.comms.guard.rel).toBe(before.guard - D.techRel);
    expect(motionsNow(g)).toEqual([]);
  });

  it('S1a 판에는 배관 안건이 없다', () => {
    expect(motionsNow(createGame('s1a-plain'))).toEqual([]);
  });
});
