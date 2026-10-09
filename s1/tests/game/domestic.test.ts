import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  addMaterials, agendaOptions, isLawAgenda, applyMove, attachApprentice, bedNeed, bedTick, setBedOrder, createGame, createS1cGame, D, domesticForecast, domesticHaulMult,
  DOM_CARD_KINDS, knowledgeMult, secondPath, topSkill, forecast, hotWaterCoal, hotWaterShare, hygiene, hygieneScore, hygieneTick, situation, LAWS, hygieneWhy, resolveTyphus, startTyphus, WASH_NAME, knowledgeTick, lawOpen, migrateDomestic, previewMove, restoreCheck,
  advance, delegateTick, workshopChief, autoLeverStatus, bedOverflow, burnPyre, P, setAutoLevers, chooseCard, coldCap, openCouncil, resolveStop, takeAltPlace, PLACES, resolveLice, rollBreakdown, setBury, setFullRule, setHotWater, startRestore, storeCap, techMult, TECHS, techRelSides, viewCard,
} from '../../src/game';
import type { Card, Game, TechId } from '../../src/game';
import { playGame } from '../../tools/s1c_bot';

// S1c 내정(s1c_domestic.md 개정판)의 규칙 확인. 숫자는 제안이라 값보다 규칙의 모양을 본다.

function fresh(seed = 'dom'): Game {
  return createS1cGame(seed);
}

describe('S1c 판 한 판', () => {
  it('내정을 켜고도 끝까지 돌고, 같은 시드면 같은 판이며, JSON으로 저장된다', () => {
    for (let i = 0; i < 12; i += 1) {
      const { g } = playGame(`dom-${i}`, { s1c: true, policy: i % 2 ? 'first' : 'caretaker', dom: i % 3 ? 'engaged' : 'idle' });
      expect(g.phase).toBe('end');
      expect(Number.isFinite(g.coal) && Number.isFinite(g.dom!.parts)).toBe(true);
      expect(JSON.parse(JSON.stringify(g))).toEqual(g);
    }
    const a = playGame('same', { s1c: true, policy: 'caretaker', dom: 'engaged' }).g;
    const b = playGame('same', { s1c: true, policy: 'caretaker', dom: 'engaged' }).g;
    expect(JSON.stringify(a)).toBe(JSON.stringify(b));
  });

  it('S1a 판엔 dom이 없고, S1c 법은 열리지 않는다', () => {
    const g = createGame('s1a');
    expect(g.dom).toBeUndefined();
    for (const law of ['tech_control', 'apprentice_duty', 'triage_std', 'bath_rota', 'hands_first'] as const) expect(lawOpen(g, law)).toBe(false);
    expect(agendaOptions(g).options.some(o => isLawAgenda(o) && ['tech_control', 'bath_rota'].includes(o.law))).toBe(false);
  });

  it('예전 저장 판을 불러오면 새 칸을 채운다', () => {
    const g = fresh();
    const d = g.dom as unknown as Record<string, unknown>;
    delete d.cars; delete d.bedOrder; delete d.log; delete d.fullRule;
    migrateDomestic(g);
    expect(g.dom!.cars.length).toBe(11);
    expect(g.dom!.bedOrder).toBeNull();
    expect(g.dom!.log.restores).toEqual([]);
  });
});

describe('기술', () => {
  it('옛 아끼는 기술 다섯은 7.3 개편 뒤 풀렸다(법을 바꾸는 효과)', () => {
    const g = fresh();
    g.dom!.frags.engine = 5;
    expect(restoreCheck(g, 'e1').full).toBeUndefined();
    expect(startRestore(g, 'e1', 'full')).toBe(true);
  });

  it('3단계 둘째 길: 그 분야 숙련 + 살아 있는 공작 장인(7.1). 공방장을 잃으면 ×0.7', () => {
    const g = fresh();
    expect(topSkill(g, 'craft')).toBe(3);
    expect(topSkill(g, 'radio')).toBe(2);
    expect(secondPath(g, 'r3')).toBe(true);
    expect(knowledgeMult(g, 'radio', 3)).toBe(1);
    for (const p of g.dom!.people) if (p.field === 'craft' && p.skill === 3) p.alive = false;
    expect(secondPath(g, 'r3')).toBe(false);
    expect(knowledgeMult(g, 'radio', 3)).toBe(D.knowledgeLow);
    g.dom!.techs.x2 = { stage: 'done', defect: false, progress: 0, need: 0 } as NonNullable<Game['dom']>['techs']['x2'];
    expect(restoreCheck(g, 'x3').full).toContain('공작 장인');
  });

  it('싫어하는 쪽이 없는 기술은 관계를 주지 않는다(기획 점검 03)', () => {
    expect(techRelSides('m1')).toEqual({ like: [], dislike: [] });
    expect(techRelSides('m2').dislike).toEqual(['tail']);
    const g = fresh();
    const before = g.comms.medtech.rel;
    expect(startRestore(g, 'm1', 'full')).toBe(true);
    expect(g.comms.medtech.rel).toBe(before);
  });

  it('고장: 부품이 2 이상이면 저절로 고치고 일지 한 줄, 모자라면 카드', () => {
    const g = fresh();
    D.breakChance = 1;
    try {
      g.dom!.parts = 4;
      rollBreakdown(g);
      expect(g.dom!.parts).toBe(2);
      expect(g.cards.some(c => c.kind === 'dom:short')).toBe(false);
      g.dom!.parts = 1;
      rollBreakdown(g);
      expect(g.cards.some(c => c.kind === 'dom:short')).toBe(true);
    } finally {
      D.breakChance = 0.1;
    }
  });

  it('창고가 넘치면 카드는 판에 한 번, 그 뒤는 고른 답대로 일지에만', () => {
    const g = fresh();
    addMaterials(g, 30, 30);
    expect(g.cards.filter(c => c.kind === 'dom:full').length).toBe(1);
    g.cards = [];
    setFullRule(g, 'dump');
    expect(g.dom!.scrap + g.dom!.wood).toBe(D.storeCap);
    addMaterials(g, 10, 0);
    expect(g.cards.some(c => c.kind === 'dom:full')).toBe(false);
    expect(g.dom!.scrap + g.dom!.wood).toBe(D.storeCap);
  });
});

describe('위생과 침상', () => {
  it('더운물 드물게는 공짜, 보통은 200명에서 석탄 0.5, 시작 위생은 앞칸 깨끗·꼬리칸 보통(16.9, 과밀 문턱 80/95)', () => {
    const g = fresh();
    expect(hotWaterCoal(g)).toBe(0);
    expect(hygiene(g, 'front')).toBe('clean');
    expect(hygiene(g, 'tail')).toBe('normal');
    expect(hygiene(g, 'engine')).toBe('normal');
    // 과밀 80이면 −1, 95면 −2(J10 W1). 시작 꼬리칸은 80 아래라 판 시작부터 '씻을 물 없음'이 아니다.
    expect(situation(g, 'tail')[2]).toBeLessThan(80);
    g.comms.tail.base[2] = 80;
    expect(hygieneScore(g, 'tail')).toBe(-1);
    g.comms.tail.base[2] = 95;
    expect(hygieneScore(g, 'tail')).toBe(-2);
    const s1a = createGame('dom');
    expect(forecast(g).coal - forecast(s1a).coal).toBeCloseTo(0, 5);
    setHotWater(g, 2);
    expect(hotWaterCoal(g)).toBeCloseTo(0.5, 5);
    expect(domesticForecast(g).coal).toBeCloseTo(0.5, 5);
    setHotWater(g, 0);
    expect(g.dom!.hotWater).toBe(1);
  });

  it('더운물 고루 나누기는 드물게도 되고 구간당 석탄 +0.25, 레버 석탄 ×1.2', () => {
    const g = fresh();
    g.passed.bath_rota = g.session;
    setHotWater(g, 0);
    expect(g.dom!.hotWater).toBe(1);
    expect(hotWaterCoal(g)).toBeCloseTo(0.25, 5);
    setHotWater(g, 2);
    expect(hotWaterCoal(g)).toBeCloseTo(0.6 + 0.25, 5);
  });

  it('불결해도 이가 돌 때만 관계가 깎이고, 이가 사라진 칸은 3구간 동안 다시 안 생긴다', () => {
    const g = fresh();
    g.comms.tail.base[2] = 85;
    const rel = g.comms.tail.rel;
    g.dom!.lice = {};
    g.dom!.liceFree = { tail: g.seg + 99 };
    hygieneTick(g, []);
    expect(g.comms.tail.rel).toBe(rel);
    expect(g.dom!.lice.tail).toBeUndefined();
    g.dom!.liceFree = {};
    g.dom!.lice.tail = { at: g.seg };
    const notes: string[] = [];
    hygieneTick(g, notes);
    expect(g.comms.tail.rel).toBe(rel - 1);
    // 관계가 움직인 까닭을 적는다(J10 W8).
    expect(notes).toContain('꼬리칸 관계 −1: 씻을 물이 모자라 불만.');
    resolveLice(g, 'tail', 'boil');
    expect(g.dom!.liceFree?.tail).toBe(g.seg + 3);
  });

  it('이 카드는 4구간부터 온다: 1~3구간엔 불결한 칸에도 이가 안 돈다(16.3, 16.1 가)', () => {
    const g = fresh();
    g.comms.tail.base[2] = 85;
    g.dom!.lice = {};
    D.liceDirty = 1;
    try {
      for (const seg of [1, 2, 3]) {
        g.seg = seg;
        hygieneTick(g, []);
        expect(g.dom!.lice.tail, `구간 ${seg}`).toBeUndefined();
      }
      g.seg = 4;
      hygieneTick(g, []);
      expect(g.dom!.lice.tail).toBeDefined();
      // 이가 돈 일지 줄 끝에 까닭 줄이 붙는다(J10 W6).
      expect(g.journal.some(l => /꼬리칸에 이가 돈다\. \(보일러에서 가장 멂 · 과밀 85 · 온기 \d+ · 몫 0\)/.test(l.text))).toBe(true);
    } finally {
      D.liceDirty = 0.1;
    }
  });

  it('뒤 구역 −1은 자리에 붙는다: 꼬리칸 객차 하나를 가운데로 올리면 몫이 2/3만 깎인다(16.2)', () => {
    const g = fresh();
    expect(hotWaterShare(g, 'tail')).toBe(0);
    setHotWater(g, 2);
    expect(hotWaterShare(g, 'tail')).toBe(1);
    expect(hotWaterShare(g, 'medtech')).toBe(2);
    const cars = g.dom!.cars;
    const i = cars.indexOf('tail1');
    [cars[3], cars[i]] = [cars[i], cars[3]];
    expect(hotWaterShare(g, 'tail')).toBeCloseTo(2 - 2 / 3, 5);
    expect(hygieneWhy(g, 'tail')).toMatch(/^보일러에서 먼 칸이 있음 · 과밀 \d+ · 온기 \d+ · 몫 1$/);
  });

  it('화면 글은 물 사정으로 부르고 까닭 줄은 조건만 적는다(16.3 보이는 법)', () => {
    const g = fresh();
    expect(WASH_NAME[hygiene(g, 'tail')]).toBe('빠듯');
    g.comms.tail.base[2] = 85;
    expect(WASH_NAME[hygiene(g, 'tail')]).toBe('없음');
    expect(WASH_NAME[hygiene(g, 'front')]).toBe('넉넉');
    const why = hygieneWhy(g, 'tail');
    expect(why).toMatch(/^보일러에서 가장 멂 · 과밀 85 · 온기 \d+ · 몫 0$/);
    expect(why).not.toMatch(/[.]\d|불결|더러/);
  });

  it('열병: 의무칸이면 번지지 않고, 따로 눕히면 번짐 절반·회복 25%이며 관계·공포 벌은 없다(16.5)', () => {
    const g = fresh();
    g.med = 100;
    const rel = g.comms.tail.rel;
    const fear = g.fear;
    startTyphus(g, 'tail', 4);
    resolveTyphus(g, 'tail', 'apart');
    expect(g.dom!.typhus[0].apart).toBe(true);
    expect(g.comms.tail.rel).toBe(rel);
    expect(g.fear).toBe(fear);
    expect(D.typhusSpreadApart).toBeCloseTo(D.typhusSpread / 2, 5);
    expect(D.typhusRecoverApart).toBe(0.25);
    expect(D.typhusRecover).toBe(0.4);
    // 번질 조건을 다 열어도(과밀 문턱 0, 확률 1) 의무칸으로 옮긴 열병은 번지지 않고, 따로 눕힌 열병은 번진다.
    const spreads = (pick: 'bay' | 'apart'): boolean => {
      const h = fresh('bay');
      h.med = 100;
      startTyphus(h, 'tail', 4);
      resolveTyphus(h, 'tail', pick);
      const keep = [D.typhusSpread, D.typhusSpreadApart, D.typhusSpreadCrowd];
      D.typhusSpread = 1; D.typhusSpreadApart = 1; D.typhusSpreadCrowd = 0;
      try {
        h.seg += 1;
        hygieneTick(h, []);
      } finally {
        [D.typhusSpread, D.typhusSpreadApart, D.typhusSpreadCrowd] = keep;
      }
      return h.dom!.typhus.some(t => t.comm === 'medtech');
    };
    expect(spreads('bay')).toBe(false);
    expect(spreads('apart')).toBe(true);
  });

  it('위생 두 법은 판 시작부터 열리고, 21가 이름은 더운물 고루 나누기다(J10 W2·W3)', () => {
    const g = fresh();
    expect(g.dom!.flags.lice).toBeFalsy();
    expect(lawOpen(g, 'bath_rota')).toBe(true);
    expect(lawOpen(g, 'hands_first')).toBe(true);
    g.passed.bath_rota = g.session;
    expect(lawOpen(g, 'hands_first')).toBe(false);
    expect(LAWS.bath_rota.title).toBe('더운물 고루 나누기');
    expect(LAWS.hands_first.changes.join(' ')).toContain('더운물 고루 나누기가 닫힌다');
    expect(JSON.stringify(LAWS)).not.toContain('목욕 순번');
  });

  it('열병은 이웃이 아니라 과밀 70 이상인 칸 어디로든 번질 수 있다(J10 W4)', () => {
    const h = fresh('spread');
    h.med = 100;
    for (const c of ['medtech', 'guard', 'front', 'engine'] as const) h.comms[c].base[2] = 10;
    h.comms.front.base[2] = 90;
    startTyphus(h, 'tail', 4);
    resolveTyphus(h, 'tail', 'apart');
    const keep = D.typhusSpreadApart;
    D.typhusSpreadApart = 1;
    try {
      h.seg += 1;
      hygieneTick(h, []);
    } finally {
      D.typhusSpreadApart = keep;
    }
    expect(h.dom!.typhus.map(t => t.comm).sort()).toEqual(['front', 'tail']);
    expect(D.typhusSpread).toBe(0.1);
    expect(D.typhusSpreadApart).toBe(0.05);
  });

  it('위생 카드에 공동체가 없으면 꼬리칸으로 떨어지지 않고 멈춘다(J10 W9)', () => {
    const g = fresh();
    expect(() => viewCard(g, { uid: 99, kind: 'dom:lice' } as Card)).toThrow();
    expect(() => viewCard(g, { uid: 99, kind: 'dom:typhus' } as Card)).toThrow();
    const v = viewCard(g, { uid: 99, kind: 'dom:lice', comm: 'guard' } as Card);
    expect(v.choices.find(c => c.label === '버틴다')?.say).toBe('석탄을 아껴야 한다. 며칠만 버텨 다오.');
  });

  it('옛 저장의 격리 열병은 따로 눕힌 것으로 이어진다', () => {
    const g = fresh();
    g.dom!.typhus = [{ comm: 'tail', patients: ['가'], quarantined: true, bay: false, at: 1 } as never];
    migrateDomestic(g);
    expect(g.dom!.typhus[0]).toEqual({ comm: 'tail', patients: ['가'], apart: true, bay: false, at: 1 });
  });

  it('침상이 처음 넘칠 때만 침상 카드가 온다', () => {
    const g = fresh();
    g.injured = 6;
    bedTick(g);
    expect(g.cards.some(c => c.kind === 'dom:bed')).toBe(false);
    g.injured = 7;
    expect(bedNeed(g)).toBe(7);
    bedTick(g);
    bedTick(g);
    expect(g.cards.filter(c => c.kind === 'dom:bed').length).toBe(1);
    g.cards = [];
    setBedOrder(g, 'sick');
    bedTick(g);
    expect(g.cards.length).toBe(0);
  });
});

describe('지식', () => {
  it('스승이 견습 도중 떠나면 멈추고, 다른 스승이 있으면 잇는다', () => {
    const g = fresh();
    const pupil = attachApprentice(g, 'med', 'guild', true)!;
    expect(pupil.learn).toBeDefined();
    const teacher = g.dom!.people.find(p => p.id === pupil.learn!.by)!;
    const left = pupil.learn!.left;
    teacher.alive = false;
    knowledgeTick(g);
    // 의료엔 약사(견습)가 있어 견습까지는 잇는다. 오를 수 있는 끝이 약사의 단계로 낮아진다.
    const pharmacist = g.dom!.people.find(p => p.role === '약사')!;
    expect(pupil.learn?.by).toBe(pharmacist.id);
    expect(pupil.learn?.cap).toBe(1);
    expect(pupil.learn?.left).toBe(left - 1);
    // 약사마저 떠나면 멈추고, 쌓은 구간은 남는다.
    pharmacist.gone = true;
    knowledgeTick(g);
    expect(pupil.learn?.by).toBe('');
    expect(pupil.learn?.left).toBe(left - 1);
  });

  it('다른 칸 견습생이 붙으면 기술 통제법이 열린다', () => {
    const g = fresh();
    expect(lawOpen(g, 'tech_control')).toBe(false);
    // 공방장은 시작부터 용접공을 가르치느라 비어 있지 않다(8.1). 기관으로 본다.
    attachApprentice(g, 'engine', 'other', true);
    expect(lawOpen(g, 'tech_control')).toBe(true);
    expect(lawOpen(g, 'apprentice_duty')).toBe(false);
  });
});

describe('칸', () => {
  it('꼬리칸 한 칸을 가운데로 올리면 꼬리칸 온기 +3.3, 관계 +5, 석탄이 든다', () => {
    const g = fresh();
    const order = ['workshop', 'front', 'captain', 'guard', 'dining', 'tail1', 'medtech', 'store', 'cold', 'tail2', 'tail3'];
    const pv = previewMove(g, order);
    expect(pv.warm.tail).toBeCloseTo(10 / 3, 3);
    expect(pv.rel.tail).toBe(D.moveUpRel);
    expect(pv.rel.medtech).toBe(D.moveDownRel);
    expect(pv.coal).toBeGreaterThan(0);
    // 화물역 정차가 아니면 옮길 수 없다
    expect(applyMove(g, order)).toBe(false);
  });

  it("'묻고 간다'는 길게 머물 때만, 산출 ×0.85", () => {
    const g = fresh();
    g.stored = 4;
    g.phase = 'stop';
    g.stop = { place: 'houses', target: 'food', stay: 'normal', crewComm: 'tail', crewSize: 4, done: false, result: null };
    setBury(g, true);
    expect(g.dom!.bury).toBe(false);
    g.stop.stay = 'long';
    setBury(g, true);
    expect(g.dom!.bury).toBe(true);
    expect(domesticHaulMult(g)).toBeCloseTo(D.buryHaul, 5);
  });
});

// ---- 카드 글 ----
const rules = (JSON.parse(readFileSync(join(__dirname, '../../schema/content_rules.json'), 'utf8')) as { rules: { severity: string; terms?: string[]; patterns?: string[]; pattern_flags?: string }[] }).rules
  .filter(r => r.severity === 'error');
function bad(text: string): boolean {
  return rules.some(r => (r.terms ?? []).some(t => text.includes(t)) || (r.patterns ?? []).some(p => new RegExp(p, r.pattern_flags ?? 'iu').test(text)));
}

describe('압력 경고(8.7, N13)', () => {
  it('첫 경고를 무시하면 마지막 경고가 오고, 그것도 무시하면 반드시 터진다. 김을 빼면 처음으로', () => {
    const pick = (g: Game, label: string) => {
      g.cards.push({ uid: 900 + g.cards.length, kind: 'dom:pressure' } as Card);
      const card = g.cards[g.cards.length - 1];
      const view = viewCard(g, card);
      const i = view.choices.findIndex(c => c.label === label);
      expect(chooseCard(g, card.uid, i)).toBe(true);
      return view;
    };
    const g = fresh('pressure');
    expect(pick(g, '그대로 간다').title).toBe('압력 경고');
    expect(g.phase).not.toBe('end');
    expect(pick(g, '김을 뺀다').title).toBe('마지막 압력 경고');
    expect(pick(g, '그대로 간다').title).toBe('압력 경고');
    expect(g.phase).not.toBe('end');
    expect(pick(g, '그대로 간다').title).toBe('마지막 압력 경고');
    expect(g.phase).toBe('end');
  });
});

describe('내정 카드 글', () => {
  it('모든 내정 카드: 선택지 이름 15자, 열차장의 말 40자·두 문장 이내, 금지 표현 없음', () => {
    const g = fresh();
    g.stored = 2;
    const cards: Omit<Card, 'uid'>[] = [
      { kind: 'dom:fit', text: 'm1' }, { kind: 'dom:fit', text: 'm2' }, { kind: 'dom:fork', text: 'e3' }, { kind: 'dom:fork', text: 'w2' },
      { kind: 'dom:fork', text: 'm3' }, { kind: 'dom:fork', text: 'r2' }, { kind: 'dom:short', text: 'break', n: 0 }, { kind: 'dom:short', text: 'm4' },
      { kind: 'dom:pupil', text: 'engine' }, { kind: 'dom:manual', text: 'engine', who: 'sp1' }, { kind: 'dom:demand', who: 'sp7', n: 0 },
      { kind: 'dom:demand', who: 'sp7', n: 1 }, { kind: 'dom:demand', who: 'sp7', n: 2 }, { kind: 'dom:car', n: 0 }, { kind: 'dom:car', n: 1 },
      { kind: 'dom:give' }, { kind: 'dom:box' }, { kind: 'dom:full', n: 5 }, { kind: 'dom:bed', n: 8 }, { kind: 'dom:officer', who: 'sp5' },
      { kind: 'dom:lice', comm: 'tail' }, { kind: 'dom:typhus', comm: 'tail', n: 4 }, { kind: 'dom:stoker' }, { kind: 'dom:pressure' },
      { kind: 'dom:elder', who: 'sp1' }, { kind: 'dom:elder', who: 'sp3' }, { kind: 'dom:elder', who: 'sp5' },
    ];
    const kinds = new Set(cards.map(c => c.kind));
    for (const k of DOM_CARD_KINDS) expect(kinds.has(k), k).toBe(true);
    const problems: string[] = [];
    cards.forEach((c, i) => {
      const v = viewCard(g, { uid: 1000 + i, ...c });
      expect(v.choices.length, c.kind).toBeGreaterThanOrEqual(2);
      for (const t of [v.title, v.body]) if (bad(t)) problems.push(`${c.kind} 금지: ${t}`);
      for (const ch of v.choices) {
        if (ch.label.length > 15) problems.push(`${c.kind} 이름 길이: ${ch.label}`);
        if (!ch.say) problems.push(`${c.kind} 말 없음: ${ch.label}`);
        else if (ch.say.length > 40 || (ch.say.match(/[.!?]/g) ?? []).length > 2) problems.push(`${c.kind} 말 길이: ${ch.say}`);
        if (bad(ch.label) || bad(ch.say ?? '')) problems.push(`${c.kind} 금지: ${ch.label}`);
      }
    });
    expect(problems).toEqual([]);
  });

  it('이와 열병 카드는 원인을 생활 조건으로 쓰고 사람이나 집단을 원인으로 쓰지 않는다', () => {
    const g = fresh();
    const lice = viewCard(g, { uid: 1, kind: 'dom:lice', comm: 'tail' });
    expect(lice.body).toMatch(/담요|빨래/);
    for (const v of [lice, viewCard(g, { uid: 2, kind: 'dom:typhus', comm: 'tail', n: 4 })]) {
      expect(`${v.body} ${v.choices.map(c => `${c.label} ${c.say}`).join(' ')}`).not.toMatch(/소독|옷을 벗|머리를 깎|민족|종교|문을 닫|가둬|격리|에서 옮/);
    }
  });
});

describe('M3 나 얼음 상자(7.3, main facf39c)', () => {
  it('창고칸 자재 상한 40 → 34, 냉동칸 안치는 6 그대로, 공동 식당이면 식량 1.5/구간 덜 든다', () => {
    const g = createS1cGame('icebox');
    const before = { cap: storeCap(g), cold: coldCap(g), food: domesticForecast(g).food };
    g.dom!.techs.m3 = { stage: 'done', defect: false, variant: 'b', progress: 0, need: 0 } as NonNullable<Game['dom']>['techs']['m3'];
    expect(storeCap(g)).toBe(before.cap - D.iceBoxCap);
    expect(coldCap(g)).toBe(before.cold);
    expect(domesticForecast(g).food).toBe(before.food);
    g.passed.common_kitchen = g.session;
    expect(domesticForecast(g).food).toBeCloseTo(before.food - D.iceBoxFood * techMult(g, 'm3'));
    expect(TECHS.m3.variants!.b.upkeep).toEqual({});
  });
});


describe('J10 1~4: 값이 틀리거나 효과가 없던 것', () => {
  const done = (g: Game, id: TechId, variant?: 'a' | 'b') => {
    g.dom!.techs[id] = { stage: 'done', defect: false, progress: 0, need: 0, ...(variant ? { variant } : {}) } as NonNullable<Game['dom']>['techs'][TechId];
  };
  const toStop = (g: Game) => {
    g.phase = 'prep';
    g.cards = [];
    advance(g); g.cards = [];
    advance(g); g.cards = [];
    expect(g.phase).toBe('stop');
  };

  it('1. 이 카드에서 옷을 삶으면 석탄이 정확히 2 준다', () => {
    const g = fresh();
    g.dom!.lice.tail = { at: g.seg };
    g.cards.push({ uid: 900, kind: 'dom:lice', comm: 'tail' } as Card);
    const view = viewCard(g, g.cards[g.cards.length - 1]);
    const coal = g.coal;
    expect(chooseCard(g, 900, view.choices.findIndex(c => c.label === '옷을 삶는다'))).toBe(true);
    expect(coal - g.coal).toBe(2);
    expect(g.dom!.lice.tail).toBeUndefined();
  });

  it('2. 따로 눕힌 열병 환자는 침상에 들지 않는다', () => {
    const g = fresh();
    g.injured = 4;
    startTyphus(g, 'tail', 4);
    resolveTyphus(g, 'tail', 'apart');
    expect(bedNeed(g)).toBe(4);
    expect(bedOverflow(g)).toBe(0);
    const h = fresh();
    h.injured = 4;
    startTyphus(h, 'tail', 4);
    resolveTyphus(h, 'tail', 'bay');
    expect(bedOverflow(h)).toBe(2);
  });

  it('3. R3은 아직 복원할 수 없다', () => {
    const g = fresh();
    done(g, 'r2', 'a');
    expect(restoreCheck(g, 'r3').full).toBe('아직 이 열차에서 못 쓴다');
    expect(restoreCheck(g, 'r3').offer).toBe(false);
  });

  it('3. R2 가(감청): 회기를 열 때 비밀을 들을 수 있다', () => {
    const g = fresh('r2a');
    done(g, 'r2', 'a');
    const keep = D.r2aSecret;
    D.r2aSecret = 1;
    try {
      const before = g.secrets.length;
      openCouncil(g);
      expect(g.secrets.length).toBe(before + 1);
      expect(g.journal.some(l => l.text.includes('무전 감청'))).toBe(true);
    } finally {
      D.r2aSecret = keep;
    }
  });

  it('3. R2 나(열차 방송): 공포 +1, 긴장 증가가 1 준다', () => {
    const run = (on: boolean) => {
      const g = fresh('r2b');
      if (on) done(g, 'r2', 'b');
      g.comms.tail.rel = -50;
      g.fear = 30;
      g.phase = 'prep';
      advance(g); g.cards = [];
      advance(g); g.cards = [];
      resolveStop(g, false); g.cards = [];
      while (g.phase !== 'prep' && g.phase !== 'end' && g.phase !== 'council') { advance(g); g.cards = []; }
      return g;
    };
    const off = run(false);
    const on = run(true);
    expect(on.fear).toBeGreaterThan(off.fear);
    expect(on.tension).toBeLessThan(off.tension);
  });

  it('3. X2(핸드카): 장소 후보가 하나 더 있고, 정찰 전에 한 번 바꾼다', () => {
    const g = fresh('x2');
    done(g, 'x2');
    toStop(g);
    const alt = g.dom!.altPlace;
    expect(alt).toBeTruthy();
    expect(alt).not.toBe(g.stop!.place);
    takeAltPlace(g);
    expect(g.stop!.place).toBe(alt);
    expect(g.dom!.altPlace).toBeNull();
    const h = fresh('x2');
    toStop(h);
    expect(h.dom!.altPlace).toBeNull();
  });

  it('4. X3(궤도 모터카): 지나쳐도 목표 자원이 무엇이든 그 자원으로 받는다', () => {
    const g = fresh('x3');
    done(g, 'x3');
    toStop(g);
    g.stop!.target = 'medicine';
    const med = g.med;
    const coal = g.coal;
    resolveStop(g, false);
    expect(g.med - med).toBe(Math.round(P.haulTotal * 0.6 * 0.5));
    expect(coal - g.coal).toBeGreaterThanOrEqual(1);
    expect(PLACES.length).toBeGreaterThan(1);
  });
});

describe('J10 5~13: 문서 규칙', () => {
  it('7. 용접공은 공방장의 견습으로 시작해 숙련(4구간) → 장인(6구간)으로 큰다', () => {
    const g = fresh();
    const chief = g.dom!.people.find(p => p.role === '공방장')!;
    const welder = g.dom!.people.find(p => p.role === '용접공')!;
    expect(welder.learn).toEqual({ by: chief.id, left: 4, cap: 3 });
    expect(chief.pupil).toBe(welder.id);
    expect(lawOpen(g, 'tech_control')).toBe(false);
    for (let i = 0; i < 10; i += 1) knowledgeTick(g);
    expect(welder.skill).toBe(3);
    expect(welder.learn).toBeUndefined();
  });

  it('5. 화장은 목재 4가 있으면 목재로, 없으면 석탄 1', () => {
    const g = fresh();
    g.pyre = 3;
    g.dom!.wood = 9;
    const coal = g.coal;
    burnPyre(g);
    expect(g.dom!.wood).toBe(1);
    expect(coal - g.coal).toBe(1);
  });

  it('6. 배급장이 장부를 내려놓은 뒤엔 관계 +20부터 다시 맡긴다', () => {
    const g = createGame('ration');
    g.seg = 10;
    g.comms.front.rel = 16;
    g.comms.front.grudge = 0;
    expect(autoLeverStatus(g).ok).toBe(true);
    g.autoDropped = true;
    expect(autoLeverStatus(g).ok).toBe(false);
    expect(autoLeverStatus(g).why).toContain('+20');
    g.comms.front.rel = 20;
    setAutoLevers(g, true);
    expect(g.autoLevers).toBe(true);
    expect(g.autoDropped).toBe(false);
    g.comms.front.rel = 16;
    expect(autoLeverStatus(g).ok).toBe(true);
  });
  it('9. 이상주의 공방장은 우선 방침이어도 꼬리칸 단열 하나를 끼워 넣는다', () => {
    const g = fresh('ideal');
    const chief = workshopChief(g)!;
    chief.trait = 'ideal';
    g.dom!.techs.e5 = { stage: 'done', defect: false, progress: 0, need: 0 } as NonNullable<Game['dom']>['techs']['e5'];
    g.dom!.wood = 30;
    g.dom!.delegate = { on: true, policy: 'ours' };
    g.seg = 10;
    g.comms[chief.comm].rel = 40;
    const rel = g.comms.tail.rel;
    delegateTick(g);
    expect(g.dom!.job?.kind).toBe('insulate');
    expect(g.dom!.job?.car.startsWith('tail')).toBe(true);
    expect(g.comms.tail.rel).toBeGreaterThan(rel - 2);
  });

  it('11. 열병 카드에 앓는 사람 이름이 나온다', () => {
    const g = fresh();
    startTyphus(g, 'tail', 2);
    const names = g.dom!.typhus[0].patients;
    const view = viewCard(g, g.cards.find(c => c.kind === 'dom:typhus')!);
    for (const n of names) expect(view.body).toContain(n);
  });
});
