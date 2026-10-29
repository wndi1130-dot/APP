import { afterEach, describe, expect, it } from 'vitest';
import {
  addCard, advance, applyEffs, budgetNextSeg, budgetPass, chooseCard, cloneGame, COMMS, createGame,
  drawTravelEvent, enableBudget, enableDark, enableLate, enactLaw, journal,
  P, repealLaw, TRAVEL_EVENTS, VIEW_FILTERS, viewCard,
} from '../../src/game';
import type { Card, Choice, Eff, Game } from '../../src/game';
import { growLateEff, LATE, lateComm, lateKind, lateLog, lateLoss, lateNextSeg, worstLateChoice } from '../../src/game/late';
import { noteBroken } from '../../src/game/council_log';
import { readSave } from '../../src/ui/repro';
import { playGame } from '../../tools/s1c_bot';
import type { BotOptions } from '../../tools/s1c_bot';

const LATE0 = { ...LATE };
const filters = VIEW_FILTERS.length;
afterEach(() => { Object.assign(LATE, LATE0); VIEW_FILTERS.splice(filters); });
const BASE: BotOptions = { s1c: true, policy: 'caretaker', dom: 'engaged' };
const templates: Omit<Card, 'uid'>[] = [
  { kind: 'demand', comm: 'tail' }, { kind: 'favor', comm: 'front' },
  { kind: 'promise_ledger', comm: 'engine' }, { kind: 'ration_cut' },
  { kind: 'travel', text: 'front_curtain' },
];
function fresh(): Game { const g = createGame('late'); enableLate(g); return g; }
function add(g: Game, patch: Omit<Card, 'uid'>): Card {
  const card = { uid: g.nextCardUid++, ...patch };
  g.cards.push(card);
  return card;
}
function later(g: Game, card: Card): void {
  expect(chooseCard(g, card.uid, viewCard(g, card).choices.findIndex(c => c.id === 'later'))).toBe(true);
}

describe('서류 미루기 켜기와 보기', () => {
  it('기본 상태·보기·저장에 새 필드가 없고 꺼진 판은 late 값을 무시한다', () => {
    const g = createGame('late-off');
    const before = JSON.stringify(g);
    for (const patch of templates) {
      const card = { uid: 1, ...patch };
      const v = viewCard(g, card);
      expect(v.choices.some(c => c.id === 'later')).toBe(false);
      expect(v).not.toHaveProperty('late');
      expect(v).not.toHaveProperty('lateLeft');
      expect(viewCard(g, { ...card, late: 2 })).toEqual(v);
    }
    expect(JSON.stringify(g)).toBe(before);
    expect(g).not.toHaveProperty('lateOn');
    expect(g).not.toHaveProperty('lateCards');
    const r = readSave(JSON.parse(before));
    expect(r.ok).toBe(true);
    if (r.ok) { expect(r.g).not.toHaveProperty('lateOn'); expect(r.g).not.toHaveProperty('lateCards'); }
  });

  it.each(templates)('$kind는 맨 아래 한 줄만 붙이고 기존 선택 번호와 상태를 보존한다', patch => {
    const g = createGame('late-view');
    const card = { uid: 1, ...patch };
    const off = viewCard(g, card);
    enableLate(g);
    const before = JSON.stringify(g);
    const v = viewCard(g, card);
    expect(v.choices.slice(0, -1)).toEqual(off.choices);
    expect(v.choices.at(-1)).toMatchObject({ id: 'later', label: '나중에 정한다', special: 'late' });
    expect(v).toMatchObject({ late: 0, lateLeft: LATE.max });
    expect(JSON.stringify(g)).toBe(before);
  });

  it('다른 여행 사건과 즉시 처리·알림 카드에는 미루기가 없다', () => {
    const g = fresh();
    const cards: Card[] = [
      ...TRAVEL_EVENTS.filter(e => e.id !== 'front_curtain').map(e => ({ uid: 1, kind: 'travel', text: e.id })),
      ...['bitten', 'bite_found', 'rescue', 'need_warn', 'strike_warn', 'strike', 'info', 'protest', 'tension_crisis', 'trust_crisis'].map(kind => ({ uid: 1, kind })),
    ];
    for (const card of cards) {
      expect(lateKind(card)).toBeUndefined();
      expect(viewCard(g, card).choices.some(c => c.id === 'later')).toBe(false);
    }
  });

  it('열차장 말은 요구 두 갈래를 가르고 재조회에도 커진 값이 중복 적용되지 않는다', () => {
    const g = fresh();
    const card = add(g, { kind: 'demand', comm: 'engine', late: 1 });
    g.comms.engine.base[3] = 100;
    expect(viewCard(g, card).choices.at(-1)?.say).toBe('교대는 나중에 다시 짠다. 지금은 더 중요한 문제가 있다.');
    g.comms.engine.base[3] = 0;
    const v = viewCard(g, card);
    expect(v.choices.at(-1)?.say).toBe('지금은 재고할 문제가 아니다. 다음 회기에 다시 와라.');
    expect(viewCard(g, card)).toEqual(v);
  });

  it('대상 칸의 커진 관계 손실보다 큰 벌이고 다시 미룰수록 커진다', () => {
    const g = fresh();
    for (const patch of templates) {
      let previous = 0;
      for (let late = 0; late <= LATE.max; late++) {
        const card = { uid: 1, ...patch, late };
        const v = viewCard(g, card);
        const worst = Math.max(...v.choices.slice(0, -1).map(c => lateLoss(c, lateComm(card))));
        const penalty = lateLoss(v.choices.at(-1)!, lateComm(card));
        expect(penalty).toBe(worst + LATE.margin + LATE.step * late);
        expect(penalty).toBeGreaterThan(worst);
        expect(penalty).toBeGreaterThan(previous);
        previous = penalty;
      }
    }
  });

  it('해로운 숫자만 크기의 반올림으로 키우고 나머지 효과는 보존한다', () => {
    const negative: Eff[] = [
      ...(['coal', 'food', 'med', 'lux', 'trust'] as const).map(t => ({ t, v: -3 })),
      { t: 'rel', c: 'tail', v: -3 }, { t: 'pop', c: 'tail', v: -3 },
    ];
    const positive: Eff[] = [
      ...(['tension', 'fear', 'injured'] as const).map(t => ({ t, v: 3 })), { t: 'fervor', c: 'tail', v: 3 },
    ];
    for (const e of negative) expect(growLateEff(e, 1)).toEqual({ ...e, v: -5 });
    for (const e of positive) expect(growLateEff(e, 1)).toEqual({ ...e, v: 5 });
    const unchanged: Eff[] = [
      ...negative.map(e => ({ ...e, v: 3 })), ...positive.map(e => ({ ...e, v: -3 })),
      { t: 'base', c: 'tail', i: 3, v: 3 }, { t: 'lever', c: 'tail', which: 'heat', v: -1 },
      { t: 'debt', c: 'tail' }, { t: 'grudge', c: 'tail' },
    ];
    for (const e of unchanged) expect(growLateEff(e, 2)).toEqual(e);
  });

  it('커진 비용을 못 내면 기존 비용 검사가 막는다', () => {
    const g = fresh();
    g.comms.engine.base[3] = 100;
    g.coal = P.shiftCoal;
    const card = add(g, { kind: 'demand', comm: 'engine' });
    expect(viewCard(g, card).choices[0].disabled).toBeUndefined();
    card.late = 1;
    expect(viewCard(g, card).choices[0].disabled).toBe('석탄이 모자라다');
    expect(chooseCard(g, card.uid, 0)).toBe(false);
  });

  it('두 번 꼴과 칸별 승인 대사만 붙이고 요구의 끝 인용을 바꾼다', () => {
    const g = fresh();
    const demand = viewCard(g, { uid: 1, kind: 'demand', comm: 'front', late: 2 });
    expect(demand.body).toMatch(/^두 번 미룬 요구다\./);
    expect(demand.body).toContain('두 번 기다려 드렸습니다. 세 번은 어렵겠습니다.');
    expect((demand.body.match(/"/g) ?? []).length).toBe(2);
    expect(viewCard(g, { uid: 1, kind: 'favor', comm: 'front', late: 2 }).body).toContain('두 번 미루셨습니다. 이번이 마지막으로 여쭙는 겁니다.');
    expect(viewCard(g, { uid: 1, kind: 'promise_ledger', comm: 'front', late: 2 }).body).toContain('이번엔 회기 앞에서 펼치겠습니다.');
  });

  it('1차례 장부에는 T7 첫머리와 T14 대표 대사를 그대로 붙인다', () => {
    const g = fresh();
    const says = [
      '한 번만 더 어겨 봐라. 꼬리칸은 다시는 약속 안 받는다.',
      '어긴 게 둘이다. 셋째면 기술·의무진은 약속을 받지 않는다.',
      '두 번이다. 한 번 더면 경비대는 약속을 안 받는다.',
      '두 번은 넘어갔습니다. 한 번 더 어기시면 앞칸은 약속을 받지 않겠습니다.',
      '두 번 샜다. 한 번 더 새면 기관실은 약속을 안 받는다.',
    ];
    COMMS.forEach((comm, i) => {
      const body = viewCard(g, { uid: 1, kind: 'promise_ledger', comm, late: 1 }).body;
      expect(body).toContain('미뤘던 장부를 다시 내밀었다.');
      expect(body.endsWith(`"${says[i]}"`)).toBe(true);
    });
  });
});

describe('보관·복귀·중복 방지', () => {
  it('미루면 uid·기억·예산 pushed를 보존하고 관계 벌만 준다', () => {
    const g = fresh();
    const card = add(g, { kind: 'demand', comm: 'tail', pushed: 1 });
    const before = cloneGame(g);
    const penalty = viewCard(g, card).choices.at(-1)!.effs;
    later(g, card);
    applyEffs(before, penalty);
    expect(g.comms).toEqual(before.comms);
    expect(g.eventLog).toEqual(before.eventLog);
    expect(g.journal).toEqual(before.journal);
    expect(g.cards).toEqual([]);
    expect(g.lateCards).toEqual([{ ...card, late: 1 }]);
    expect(g.deferred).toBeUndefined();
  });

  it('실제 다음 구간에서 미룬 순서로 예산 복귀 카드보다 앞에 온다', () => {
    const g = fresh();
    enableBudget(g);
    const demand = add(g, { kind: 'demand', comm: 'tail' });
    const favor = add(g, { kind: 'favor', comm: 'front' });
    later(g, demand); later(g, favor);
    g.deferred = [{ uid: g.nextCardUid++, kind: 'keepsake', comm: 'tail', who: '가' }];
    g.phase = 'settle';
    g.seg = 3;
    advance(g);
    expect(g.seg).toBe(4);
    expect(g.cards.slice(0, 2).map(c => c.uid)).toEqual([demand.uid, favor.uid]);
    expect(g.lateCards).toEqual([]);
    expect(g.deferred?.some(c => (c.late ?? 0) > 0)).toBe(false);
    g.budget!.picked = 99;
    budgetPass(g);
    expect(g.cards.slice(0, 2).map(c => c.uid)).toEqual([demand.uid, favor.uid]);
  });

  it('없어진 칸·교체된 부탁 대표·내려간 감축법은 조용히 버린다', () => {
    const g = fresh();
    g.lateCards = [
      { uid: 1, kind: 'demand', comm: 'tail', late: 1 },
      { uid: 2, kind: 'favor', comm: 'front', who: 'former-rep', late: 1 },
      { uid: 3, kind: 'ration_cut', late: 1 },
    ];
    g.comms.tail.pop = 0;
    const log = [...g.journal];
    lateNextSeg(g);
    expect(g.cards).toEqual([]);
    expect(g.journal).toEqual(log);
  });

  it('부탁은 미룬 순간 대표 id를 보관하고 재활성화해도 보관함을 비우지 않는다', () => {
    const g = fresh();
    const card = add(g, { kind: 'favor', comm: 'front' });
    later(g, card);
    expect(g.lateCards![0].who).toBe(g.comms.front.leader.personId);
    enableLate(g);
    expect(g.lateCards).toHaveLength(1);
    lateNextSeg(g);
    expect(g.cards[0].uid).toBe(card.uid);
  });

  it('여행 when·최근 사건·난수를 다시 굴리지 않는다', () => {
    const g = fresh();
    const card = { uid: 1, kind: 'travel', text: 'front_curtain', late: 1 };
    g.lateCards = [card];
    g.eventLog.front_curtain = { n: 3, seg: g.seg, pick: 'side_front' };
    g.recentEvents = ['front_curtain'];
    const rng = cloneGame(g).rng;
    lateNextSeg(g);
    expect(g.cards).toEqual([card]);
    expect(g.rng).toEqual(rng);
  });

  it('예산 복귀만으로는 플레이어 보관함이 돌아오지 않는다', () => {
    const g = fresh(); enableBudget(g);
    const card = add(g, { kind: 'favor', comm: 'tail' });
    later(g, card); budgetNextSeg(g);
    expect(g.cards).toEqual([]);
    expect(g.lateCards).toHaveLength(1);
  });

  it('정산의 demand·favor 새 뽑기는 플레이어 보관함도 본다', () => {
    let spawnedDemand = 0; let spawnedFavor = 0;
    for (let i = 0; i < 20; i++) {
      const g = createGame(`late-dup-${i}`);
      g.phase = 'council';
      for (const c of COMMS) { g.comms[c].rel = 30; g.comms[c].demandCool = 0; g.comms[c].favorCool = 0; }
      g.comms.tail.base[0] = -30;
      const off = cloneGame(g);
      enableLate(g);
      g.lateCards = [{ uid: 900, kind: 'demand', comm: 'tail', late: 1 }, { uid: 901, kind: 'favor', comm: 'front', late: 1 }];
      advance(off); advance(g);
      spawnedDemand += Number(off.cards.some(c => c.kind === 'demand'));
      spawnedFavor += Number(off.cards.some(c => c.kind === 'favor'));
      expect(g.cards.some(c => c.kind === 'demand' || c.kind === 'favor')).toBe(false);
    }
    expect(spawnedDemand).toBeGreaterThan(0); expect(spawnedFavor).toBeGreaterThan(0);
  });

  it('어두운 길에서 대표를 불러도 미뤄 둔 demand를 복제하지 않는다', () => {
    const g = fresh(); enableDark(g);
    g.dark!.embers.push({ id: 900, who: 'tail', actor: g.comms.tail.leader.personId, target: 'guard', mark: g.comms.guard.leader.personId,
      cause: 'fervor', stage: 0, imm: 0, quiet: 0, guardUntil: -1, sab: 'heating', blocked: false, born: g.seg });
    g.lateCards = [{ uid: 901, kind: 'demand', comm: 'tail', late: 1 }];
    const card = add(g, { kind: 'dark:sign', n: 900 });
    const idx = viewCard(g, card).choices.findIndex(c => c.special === 'dark:call');
    const off = cloneGame(g); delete off.lateOn;
    expect(chooseCard(off, card.uid, idx)).toBe(true);
    expect(off.cards.some(c => c.kind === 'demand')).toBe(true);
    expect(chooseCard(g, card.uid, idx)).toBe(true);
    expect(g.cards.some(c => c.kind === 'demand')).toBe(false);
  });

  it('미뤄 둔 커튼은 여행 뽑기에서 제외한다', () => {
    let seen = 0;
    for (let i = 0; i < 150; i++) {
      const off = createGame(`late-travel-${i}`);
      const on = cloneGame(off); enableLate(on);
      on.lateCards = [{ uid: 1, kind: 'travel', text: 'front_curtain', late: 1 }];
      if (drawTravelEvent(off) === 'front_curtain') seen++;
      expect(drawTravelEvent(on)).not.toBe('front_curtain');
    }
    expect(seen).toBeGreaterThan(0);
  });

  it('감축법 폐지는 보관함의 사본도 지우고 다른 서류는 남긴다', () => {
    const g = fresh(); g.food = 35; enactLaw(g, 'emergency_ration', []);
    later(g, g.cards.find(c => c.kind === 'ration_cut')!);
    g.lateCards!.push({ uid: 999, kind: 'favor', comm: 'front', late: 1 });
    repealLaw(g, 'emergency_ration');
    expect(g.cards.some(c => c.kind === 'ration_cut')).toBe(false);
    expect(g.lateCards!.map(c => c.kind)).toEqual(['favor']);
  });

  it('미룬 약속 장부가 있어도 위반 누계와 협상 닫힘은 진행된다', () => {
    const g = fresh(); g.comms.tail.broken = 2; noteBroken(g, 'tail');
    later(g, g.cards.find(c => c.kind === 'promise_ledger')!);
    g.comms.tail.broken = 3; noteBroken(g, 'tail');
    expect(g.comms.tail.openClosed).toBe(true);
    expect(g.lateCards).toHaveLength(1);
  });
});

describe('기한 초과·저장·봇', () => {
  it.each(templates)('$kind의 세 번째 미루기는 커진 최악 선택 + 벌 + 승인 일지와 같다', patch => {
    const g = fresh(); g.passed.emergency_ration = 1;
    const card = add(g, { ...patch, late: LATE.max });
    const v = viewCard(g, card);
    const expected = cloneGame(g);
    const worst = patch.kind === 'travel' ? 'side_front' : 'refuse';
    const idx = v.choices.findIndex(c => c.id === worst || (patch.kind === 'promise_ledger' && c.special === 'ledger_refuse'));
    expect(chooseCard(expected, card.uid, idx)).toBe(true);
    applyEffs(expected, v.choices.at(-1)!.effs);
    journal(expected, lateLog(g, card), 'bad');
    later(g, card);
    expect(g).toEqual(expected);
    expect(g.eventLog[v.key ?? '']?.pick).not.toBe('later');
    if (patch.kind === 'promise_ledger') expect(g.comms.engine.grudge).toBeGreaterThan(0);
    if (patch.kind === 'ration_cut') expect(g.rationCut?.pick).toBe('refuse');
  });

  it('최악 선택의 동률은 앞 선택지이고 자동 처리도 확장 특수 처리를 실행한다', () => {
    const g = fresh(); const card = add(g, { kind: 'favor', comm: 'tail', late: 2 });
    VIEW_FILTERS.push((_g, c, v) => c.uid === card.uid ? { ...v, choices: v.choices.map(ch => ({ ...ch, effs: [], disabled: undefined })) } : v);
    const v = viewCard(g, card);
    expect(worstLateChoice(v.choices, 'tail').special).toBe('favor_risk');
    later(g, card);
    expect(g.comms.tail.favorCool).toBe(4);
    expect(g.eventLog['favor:tail'].pick).toBe('grant');
  });

  it('최악 선택은 대상 칸만 비교하며 막힌 선택지도 자동 처리한다', () => {
    const choices: Choice[] = [{ label: 'first', effs: [{ t: 'rel', c: 'front', v: -50 }] },
      { label: 'second', disabled: 'cost', effs: [{ t: 'rel', c: 'tail', v: -4 }] },
      { label: 'third', effs: [{ t: 'rel', c: 'tail', v: -4 }] }];
    expect(worstLateChoice(choices, 'tail')).toBe(choices[1]);
    const g = fresh(); const card = add(g, { kind: 'promise_ledger', comm: 'tail', late: 2 });
    VIEW_FILTERS.push((_g, c, v) => c.uid === card.uid ? { ...v, choices: v.choices.map(ch => ch.special === 'ledger_refuse' ? { ...ch, disabled: 'cost' } : ch) } : v);
    later(g, card);
    expect(g.comms.tail.grudge).toBeGreaterThan(0);
    expect(g.cards).toEqual([]);
  });

  it('저장·읽기 왕복 뒤에도 횟수·대표·순서·본문·효과와 다음 복귀가 같다', () => {
    const g = fresh();
    for (const patch of templates) { const card = add(g, patch); later(g, card); }
    const saved = JSON.stringify(g);
    const r = readSave(JSON.parse(saved));
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(r.g.lateCards).toEqual(g.lateCards);
    expect(r.g.lateOn).toBe(true);
    expect(r.g.lateCards!.map(c => viewCard(r.g, c))).toEqual(g.lateCards!.map(c => viewCard(g, c)));
    lateNextSeg(g); lateNextSeg(r.g);
    expect(r.g.cards).toEqual(g.cards);
  });

  it.each([false, true])('기준 봇은 later를 고르지 않고 off와 끝 상태가 같다(scoreCards=%s)', scoreCards => {
    const off = playGame('late-bot', { ...BASE, scoreCards }).g;
    let seen = 0;
    const on = playGame('late-bot', { ...BASE, scoreCards, late: true, probe: {
      beforePick: (_g, _card, view, idx) => { if (view.choices.some(c => c.id === 'later')) seen++; expect(view.choices[idx].id).not.toBe('later'); },
    } }).g;
    const { lateOn: _on, ...rest } = on;
    expect(seen).toBeGreaterThan(0);
    expect(rest).toEqual(off);
  });

  it('lateAlways 봇은 미루기가 있는 카드마다 미룬다', () => {
    let seen = 0;
    playGame('late-bot', { ...BASE, lateAlways: true, probe: {
      beforePick: (_g, _card, view, idx) => { if (view.choices.some(c => c.id === 'later')) { seen++; expect(view.choices[idx].id).toBe('later'); } },
    } });
    expect(seen).toBeGreaterThan(0);
  });
});
