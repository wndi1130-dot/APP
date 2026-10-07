import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  addMaterials, agendaOptions, applyMove, attachApprentice, bedNeed, bedTick, setBedOrder, createGame, createS1cGame, D, domesticForecast, domesticHaulMult,
  DOM_CARD_KINDS, forecast, hotWaterCoal, hygiene, hygieneTick, knowledgeTick, lawOpen, migrateDomestic, PENDING_TECHS, previewMove, restoreCheck,
  chooseCard, resolveLice, rollBreakdown, setBury, setFullRule, setHotWater, startRestore, techRelSides, viewCard,
} from '../../src/game';
import type { Card, Game } from '../../src/game';
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
    expect(agendaOptions(g).options.some(o => ['tech_control', 'bath_rota'].includes(o.law))).toBe(false);
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
  it('아끼기만 하는 기술 다섯은 사용자 답 전까지 복원이 막힌다', () => {
    const g = fresh();
    g.dom!.frags.engine = 5;
    for (const id of PENDING_TECHS) expect(restoreCheck(g, id).full).toBe('아직 열지 않는 기술');
    expect(startRestore(g, 'e1', 'full')).toBe(false);
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
  it('더운물 드물게는 공짜, 보통은 200명에서 석탄 0.5, 시작 위생은 앞칸 깨끗·꼬리칸 불결(16.9)', () => {
    const g = fresh();
    expect(hotWaterCoal(g)).toBe(0);
    expect(hygiene(g, 'front')).toBe('clean');
    expect(hygiene(g, 'tail')).toBe('dirty');
    expect(hygiene(g, 'engine')).toBe('normal');
    const s1a = createGame('dom');
    expect(forecast(g).coal - forecast(s1a).coal).toBeCloseTo(0, 5);
    setHotWater(g, 2);
    expect(hotWaterCoal(g)).toBeCloseTo(0.5, 5);
    expect(domesticForecast(g).coal).toBeCloseTo(0.5, 5);
    setHotWater(g, 0);
    expect(g.dom!.hotWater).toBe(1);
  });

  it('목욕 순번은 드물게도 되고 구간당 석탄 +0.25, 레버 석탄 ×1.2', () => {
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
    const rel = g.comms.tail.rel;
    g.dom!.lice = {};
    g.dom!.liceFree = { tail: g.seg + 99 };
    hygieneTick(g, []);
    expect(g.comms.tail.rel).toBe(rel);
    expect(g.dom!.lice.tail).toBeUndefined();
    g.dom!.liceFree = {};
    g.dom!.lice.tail = { at: g.seg };
    hygieneTick(g, []);
    expect(g.comms.tail.rel).toBe(rel - 1);
    resolveLice(g, 'tail', 'boil');
    expect(g.dom!.liceFree?.tail).toBe(g.seg + 3);
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
    attachApprentice(g, 'craft', 'other', true);
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
      expect(`${v.body} ${v.choices.map(c => `${c.label} ${c.say}`).join(' ')}`).not.toMatch(/소독|옷을 벗|머리를 깎|민족|종교/);
    }
  });
});
