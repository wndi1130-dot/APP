import { readdirSync, readFileSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  addCard, advance, BUDGET, budgetNextSeg, budgetPass, CARD_GRADE, chooseCard, cloneGame, createGame, createS1cGame, DARK_CARD_KINDS, DISASTER_CARD_KINDS, DOM_CARD_KINDS,
  enableBudget, enableDark, FAMILIES, gradeOf, HUB_CARD_KINDS, onDeath, PEOPLE_KINDS, PROFILES, PROLOGUE_CARD_KINDS, S1A_CARD_KINDS, TRAVEL_EVENTS, viewCard,
} from '../../src/game';
import { BUDGET_HOOK } from '../../src/game/state';
import type { Game } from '../../src/game';
import { readSave } from '../../src/ui/repro';
import { playGame } from '../../tools/s1c_bot';
import type { BotOptions } from '../../tools/s1c_bot';

// 카드 구간 예산(budget.ts, events_disasters 3.1). 기본 꺼짐. 켜면 한 구간에 고르는 카드가 BUDGET.perSeg(3)장을 넘지 않게
// 등급이 낮은 카드부터 g.deferred로 뺀다. 1·2등급은 안 미루고, 3·4등급은 돌아오고, 5~7등급은 두 번 밀리면 일지 한 줄이 된다.

const BUDGET0 = { ...BUDGET };
afterEach(() => { Object.assign(BUDGET, BUDGET0); vi.restoreAllMocks(); });

const kinds = (g: Game) => g.cards.map(c => c.kind);
const deferredKinds = (g: Game) => (g.deferred ?? []).map(c => c.kind);

/** 구간 예산을 켠 새 판. 카드는 addCard로 올린다. */
function fresh(seed = 'budget'): Game {
  const g = createGame(seed);
  enableBudget(g);
  return g;
}
/** 이미 n장 골랐다고 친다(chooseCard가 센 것과 같은 장부) */
function picked(g: Game, n: number): void {
  g.budget!.seg = g.seg;
  g.budget!.picked = n;
}

describe('예산 꺼짐', () => {
  const CONFIGS: BotOptions[] = [
    { s1c: false, policy: 'caretaker', dom: 'idle' },
    { s1c: false, policy: 'first', dom: 'idle' },
    { s1c: true, policy: 'caretaker', dom: 'engaged' },
    { s1c: true, policy: 'first', dom: 'engaged', s1b: 'kind', disasters: true },
  ];

  it('끈 판에는 장부도 미룬 카드도 pushed·ask 표시도 없다', () => {
    for (const opts of CONFIGS) {
      for (const seed of ['bg-off-0', 'bg-off-1']) {
        const { g, m } = playGame(seed, opts);
        expect(g.budget).toBeUndefined();
        expect(g.deferred).toBeUndefined();
        expect(g.cards.every(c => c.pushed === undefined && c.ask === undefined)).toBe(true);
        expect(g.journal.some(j => j.text.includes('흐지부지'))).toBe(false);
        expect(m.budget).toBeUndefined();
      }
    }
  });

  it('상한을 아주 크게 켠 판은 끈 판과 한 판 전체가 같다(켜는 것만으로 난수·일지·카드를 안 건드린다)', () => {
    for (const opts of CONFIGS) {
      for (const seed of ['bg-same-0', 'bg-same-1', 'bg-same-2']) {
        const off = playGame(seed, opts).g;
        BUDGET.perSeg = 1e9;
        const on = playGame(seed, { ...opts, budget: true }).g;
        BUDGET.perSeg = BUDGET0.perSeg;
        expect(on.budget?.stats).toEqual({ deferred: {}, faded: {}, dropped: {} });
        // 남은 카드의 ask 표시(예산을 켠 판에서만 붙는다)는 빼고 비교한다
        const strip = (x: Game) => JSON.stringify({ ...x, budget: undefined, deferred: undefined, cards: x.cards.map(({ ask: _a, ...c }) => c) });
        expect(strip(on)).toBe(strip(off));
      }
    }
  });
});

describe('등급표', () => {
  it('카드 종류 목록에 있는 모든 kind가 표에 있고, 표에 남는 kind도 없다', () => {
    const known = new Set<string>([
      ...S1A_CARD_KINDS, ...PEOPLE_KINDS, ...DOM_CARD_KINDS, ...DISASTER_CARD_KINDS, ...HUB_CARD_KINDS, ...PROLOGUE_CARD_KINDS, ...DARK_CARD_KINDS,
      'content', 'content-deal',
    ]);
    for (const k of known) expect(CARD_GRADE[k], `등급표에 없다: ${k}`).toBeTruthy();
    for (const k of Object.keys(CARD_GRADE)) expect(known.has(k), `목록에 없는 kind가 표에 있다: ${k}`).toBe(true);
  });

  it('src/game 전체에서 카드를 올리는 줄(addCard·darkCard·domCard·addPeopleCard·unshift)의 kind가 모두 표에 있다', () => {
    const root = fileURLToPath(new URL('../../src/game/', import.meta.url));
    const files: string[] = [];
    const walk = (dir: string) => {
      for (const f of readdirSync(dir)) {
        const p = join(dir, f);
        if (statSync(p).isDirectory()) walk(p); else if (p.endsWith('.ts')) files.push(p);
      }
    };
    walk(root);
    const found = new Set<string>();
    const consts: Record<string, string> = { CONTENT_CARD_KIND: 'content', CONTENT_DEAL_KIND: 'content-deal' };
    for (const f of files) {
      for (const line of readFileSync(f, 'utf8').split('\n')) {
        if (!/(addCard|darkCard|domCard|addPeopleCard|unshift)\(/.test(line)) continue;
        for (const m of line.matchAll(/kind: '([^']+)'/g)) found.add(m[1]);
        for (const m of line.matchAll(/kind: (CONTENT_[A-Z_]+)/g)) found.add(consts[m[1]]);
      }
      // 이미 올린 카드의 kind를 바꾸는 줄(people.ts afterDeath)
      for (const m of readFileSync(f, 'utf8').matchAll(/\.kind = '([^']+)'/g)) found.add(m[1]);
    }
    expect(found.size).toBeGreaterThan(40);
    for (const k of found) expect(CARD_GRADE[k], `카드를 올리는 kind가 등급표에 없다: ${k}`).toBeTruthy();
  });

  it('브리프 등급: 재난 1, 시계 달린 위기 2, 사람 사건 3, 내정 필수 4, 요구·부탁 5, 내정 선택 6, 이동 사건 7', () => {
    expect(gradeOf('disaster_prep')).toBe(1);
    for (const k of ['tension_crisis', 'trust_crisis', 'need_warn', 'strike_warn', 'strike', 'bite_found', 'dark:mob']) expect(gradeOf(k), k).toBe(2);
    for (const k of ['orphan', 'keepsake', 'rep_sick', 'elder', 'birth', 'naming']) expect(gradeOf(k), k).toBe(3);
    for (const k of ['dom:fork', 'dom:short', 'dom:demand', 'dom:box', 'dom:full', 'dom:bed', 'dom:officer', 'dom:lice', 'dark:armory']) expect(gradeOf(k), k).toBe(4);
    for (const k of ['demand', 'favor']) expect(gradeOf(k), k).toBe(5);
    for (const k of ['dom:fit', 'dom:pupil', 'dom:give']) expect(gradeOf(k), k).toBe(6);
    for (const k of ['travel', 'content']) expect(gradeOf(k), k).toBe(7);
  });

  it('미뤄도 안전하지 않다고 본 카드는 브리프 등급이 3~7이어도 2로 둔다', () => {
    for (const [k, r] of Object.entries(CARD_GRADE)) {
      if (r.brief) { expect(r.grade, k).toBe(2); expect(r.safe, k).toBe(false); expect(r.brief, k).toBeGreaterThanOrEqual(3); }
      if (r.grade <= 2) expect(r.safe, k).toBe(false);
      if (r.grade >= 3) expect(r.safe, k).toBe(true);
    }
    for (const k of ['rescue', 'bitten']) expect(CARD_GRADE[k].brief).toBe(3);
  });

  it('모르는 kind는 등급 2로 보고 한 번만 경고한다', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    expect(gradeOf('zz_new_kind')).toBe(2);
    expect(gradeOf('zz_new_kind')).toBe(2);
    expect(warn).toHaveBeenCalledTimes(1);
    expect(String(warn.mock.calls[0][0])).toContain('zz_new_kind');
    // 모르는 카드는 미루지 않는다
    const g = fresh('bg-unknown');
    picked(g, 3);
    addCard(g, { kind: 'zz_new_kind' });
    expect(kinds(g)).toEqual(['zz_new_kind']);
  });
});

describe('상한', () => {
  it('고른 수 + 대기 카드가 상한을 넘으면 등급이 큰 카드부터, 같으면 나중에 온 카드부터 뺀다', () => {
    const g = fresh('bg-cap');
    addCard(g, { kind: 'keepsake', comm: 'tail', who: '가' });
    addCard(g, { kind: 'demand', comm: 'engine' });
    addCard(g, { kind: 'favor', comm: 'front' });
    addCard(g, { kind: 'travel', text: TRAVEL_EVENTS[0].id });
    addCard(g, { kind: 'travel', text: TRAVEL_EVENTS[1].id });
    expect(kinds(g)).toEqual(['keepsake', 'demand', 'favor']);
    expect(deferredKinds(g)).toEqual(['travel', 'travel']);
    expect(g.budget!.stats.deferred).toEqual({ 7: 2 });
    // 이미 한 장 골랐으면 두 자리뿐이다: 등급 5 둘 중 나중 것이 빠진다
    const h = fresh('bg-cap2');
    picked(h, 1);
    addCard(h, { kind: 'keepsake', comm: 'tail', who: '가' });
    addCard(h, { kind: 'demand', comm: 'engine' });
    addCard(h, { kind: 'favor', comm: 'front' });
    expect(kinds(h)).toEqual(['keepsake', 'demand']);
    expect(deferredKinds(h)).toEqual(['favor']);
  });

  it('chooseCard가 고른 수를 세고, 구간이 바뀌면 장부가 0으로 돌아간다', () => {
    const g = fresh('bg-count');
    addCard(g, { kind: 'info', who: '가', text: '나' });
    addCard(g, { kind: 'info', who: '다', text: '라' });
    expect(chooseCard(g, g.cards[0].uid, 0)).toBe(true);
    expect(g.budget!.picked).toBe(1);
    addCard(g, { kind: 'info', who: '마', text: '바' });
    addCard(g, { kind: 'keepsake', comm: 'tail', who: '가' });
    addCard(g, { kind: 'demand', comm: 'tail' });
    // 고른 1 + 대기 info 2 = 3. 3등급 keepsake가 넘쳐서 빠지고, 그 뒤 demand도 빠진다
    expect(kinds(g)).toEqual(['info', 'info']);
    expect(deferredKinds(g).sort()).toEqual(['demand', 'keepsake']);
    g.cards = [];
    g.comms.tail.base = [10, 10, 10, 10]; // 요구가 아직 풀리지 않았다
    g.seg += 1;
    budgetNextSeg(g);
    expect(g.budget!.picked).toBe(0);
    expect(kinds(g)).toEqual(['keepsake', 'demand']);
  });

  it('chooseCard가 맨 앞에 붙이는 카드(출산 뒤 이름)도 예산을 본다', () => {
    const g = fresh('bg-front');
    const mother = PROFILES.find(p => p.gender === 'female' && p.community === 'tail')!.name;
    picked(g, 2);
    addCard(g, { kind: 'birth', comm: 'tail', who: mother });
    g.born = { comm: 'tail', mother, weak: false, left: 0 };
    expect(chooseCard(g, g.cards[0].uid, 0)).toBe(true); // 의무칸으로 옮긴다: 이름 카드가 맨 앞에 붙는다
    expect(g.budget!.picked).toBe(3);
    expect(kinds(g)).toEqual([]);
    expect(deferredKinds(g)).toEqual(['naming']);
  });

  it('S1b·S1c·재난까지 켠 자동 플레이 내내, 상한을 넘은 때는 대기 카드가 전부 미룰 수 없는 카드뿐이다', () => {
    const orig = BUDGET_HOOK.onAdd!;
    let checks = 0;
    BUDGET_HOOK.onAdd = g => {
      orig(g);
      checks += 1;
      const used = g.budget!.seg === g.seg ? g.budget!.picked : 0;
      if (used + g.cards.length > BUDGET.perSeg) {
        for (const c of g.cards) expect(gradeOf(c.kind) <= 2 || c.ask === true, `${c.kind}가 상한을 넘은 채 남았다`).toBe(true);
      }
    };
    try {
      for (const opts of [
        { s1c: true, policy: 'caretaker', dom: 'engaged', budget: true },
        { s1c: false, policy: 'first', dom: 'idle', budget: true, s1b: 'kind', disasters: true },
      ] as BotOptions[]) {
        for (const seed of ['bg-run-0', 'bg-run-1', 'bg-run-2']) playGame(seed, opts);
      }
    } finally {
      BUDGET_HOOK.onAdd = orig;
    }
    expect(checks).toBeGreaterThan(200);
  });
});

describe('등급 1·2는 안 미룬다', () => {
  it('상한을 넘어도 1·2등급은 모두 대기에 남고, 3등급 이상만 빠진다', () => {
    const g = fresh('bg-pinned');
    for (const k of ['need_warn', 'strike_warn', 'tension_crisis', 'bite_found', 'disaster_prep', 'info']) addCard(g, { kind: k, comm: 'tail', text: 'x' });
    expect(g.cards.length).toBe(6);
    expect(g.deferred).toEqual([]);
    addCard(g, { kind: 'keepsake', comm: 'tail', who: '가' });
    addCard(g, { kind: 'travel', text: TRAVEL_EVENTS[0].id });
    expect(g.cards.length).toBe(6);
    expect(deferredKinds(g).sort()).toEqual(['keepsake', 'travel']);
  });

  it('미뤄도 말이 안 되는 정차 카드(rescue·bitten)도 안 미룬다', () => {
    const g = fresh('bg-stop');
    picked(g, 3);
    addCard(g, { kind: 'rescue', comm: 'tail', who: '가' });
    addCard(g, { kind: 'bitten', comm: 'tail', who: '나' });
    expect(kinds(g)).toEqual(['rescue', 'bitten']);
  });

  it('단추로 직접 청한 서류(ask)는 안 미룬다. askExempt를 0으로 두면 등급 6처럼 미룬다', () => {
    const g = fresh('bg-ask');
    picked(g, 3);
    addCard(g, { kind: 'dom:pupil', text: 'engine', ask: true });
    expect(kinds(g)).toEqual(['dom:pupil']);
    BUDGET.askExempt = 0;
    budgetPass(g);
    expect(deferredKinds(g)).toEqual(['dom:pupil']);
  });
});

describe('3·4등급은 돌아온다', () => {
  it('미뤄도 사라지지 않고 몇 구간이 지나도 다음 구간 맨 앞으로 돌아온다(일지 한 줄도 없다)', () => {
    const g = fresh('bg-keep');
    for (let i = 0; i < 4; i += 1) {
      picked(g, 3);
      if (i === 0) addCard(g, { kind: 'dom:full', n: 3 });
      budgetPass(g);
      expect(deferredKinds(g)).toEqual(['dom:full']);
      expect(g.cards).toEqual([]);
      g.seg += 1;
      budgetNextSeg(g);
      expect(kinds(g)).toEqual(['dom:full']);
      picked(g, 3); // 그 구간도 이미 찼다
      budgetPass(g);
    }
    expect(g.budget!.stats.faded).toEqual({});
    expect(g.journal.some(j => j.text.includes('흐지부지'))).toBe(false);
    expect(g.budget!.stats.deferred[4]).toBeGreaterThanOrEqual(4);
  });

  it('advance로 구간이 넘어갈 때 미뤄 둔 카드가 새 구간의 다른 카드보다 앞에 온다', () => {
    const g = fresh('bg-front-seg');
    g.phase = 'settle';
    g.seg = 3;
    picked(g, 3);
    addCard(g, { kind: 'keepsake', comm: 'tail', who: '가' });
    addCard(g, { kind: 'dom:bed', n: 4 });
    expect(g.cards).toEqual([]);
    expect(deferredKinds(g)).toEqual(['keepsake', 'dom:bed']);
    advance(g);
    expect(g.seg).toBe(4);
    expect(g.deferred).toEqual([]);
    // 등급이 높은(숫자가 작은) 카드가 앞이다: 사람 사건(3) 다음 내정 필수(4)
    expect(kinds(g).slice(0, 2)).toEqual(['keepsake', 'dom:bed']);
  });

  it('같은 자리의 새 카드가 또 올라오면 미뤄 둔 카드에 합친다(창고 넘침이 구간마다 쌓이지 않는다)', () => {
    const g = fresh('bg-merge');
    picked(g, 3);
    addCard(g, { kind: 'dom:full', n: 3 });
    expect(deferredKinds(g)).toEqual(['dom:full']);
    g.seg += 1;
    picked(g, 3);
    addCard(g, { kind: 'dom:full', n: 9 });
    expect(g.cards).toEqual([]);
    expect(g.deferred!.length).toBe(1);
    expect(g.deferred![0].n).toBe(9);
  });
});

describe('돌아오는 장수 상한(returnMax)', () => {
  it('구간 처음에 returnMax장만 돌아오고 나머지는 한 구간 더 미룬다: 3·4등급은 남고, 5~7등급은 두 번째 밀림이라 일지가 된다', () => {
    const saved = BUDGET.returnMax;
    BUDGET.returnMax = 2; // 기본은 99(끔). 이 시험만 2로 켠다
    try {
    const g = fresh('bg-return');
    picked(g, 3);
    addCard(g, { kind: 'keepsake', comm: 'tail', who: '가' });
    addCard(g, { kind: 'dom:full', n: 3 });
    addCard(g, { kind: 'dom:bed', n: 4 });
    addCard(g, { kind: 'favor', comm: 'front' });
    expect(deferredKinds(g)).toEqual(['keepsake', 'dom:full', 'dom:bed', 'favor']);
    g.seg += 1;
    budgetNextSeg(g);
    expect(kinds(g)).toEqual(['keepsake', 'dom:full']); // 등급 순으로 앞의 둘
    expect(deferredKinds(g)).toEqual(['dom:bed']); // 4등급은 한 구간 더
    expect(g.budget!.stats.faded).toEqual({ 5: 1 }); // 부탁(5)은 두 번째 밀림: 흐지부지
    expect(g.journal.at(-1)!.text).toContain('흐지부지');
    g.cards = [];
    g.seg += 1;
    budgetNextSeg(g);
    expect(kinds(g)).toEqual(['dom:bed']);
    BUDGET.returnMax = 99;
    const h = fresh('bg-return99');
    picked(h, 3);
    for (const k of ['keepsake', 'dom:full', 'dom:bed']) addCard(h, { kind: k, ...(k === 'keepsake' ? { comm: 'tail' as const, who: '가' } : { n: 3 }) });
    h.seg += 1;
    budgetNextSeg(h);
    expect(kinds(h)).toEqual(['keepsake', 'dom:full', 'dom:bed']);
    } finally { BUDGET.returnMax = saved; }
  });
});

describe('5~7등급은 두 번 밀리면 일지 한 줄', () => {
  it('첫 번째는 다음 구간으로, 두 번째는 일지 "○○ 얘기는 흐지부지됐다"로 바뀌고 사라진다', () => {
    const g = fresh('bg-fade');
    const ev = TRAVEL_EVENTS[0];
    picked(g, 3);
    addCard(g, { kind: 'travel', text: ev.id });
    expect(deferredKinds(g)).toEqual(['travel']);
    expect(g.deferred![0].pushed).toBe(1);
    g.seg += 1;
    budgetNextSeg(g);
    expect(kinds(g)).toEqual(['travel']);
    expect(g.budget!.stats.faded).toEqual({});
    picked(g, 3); // 이 구간도 찼다: 두 번째로 밀린다
    budgetPass(g);
    expect(g.cards).toEqual([]);
    expect(g.deferred).toEqual([]);
    expect(g.budget!.stats.faded).toEqual({ 7: 1 });
    const title = viewCard(g, { uid: 0, kind: 'travel', text: ev.id }).title;
    expect(g.journal.at(-1)!.text).toBe(`${title} 얘기는 흐지부지됐다.`);
    // 구간이 또 넘어가도 돌아오지 않는다
    g.seg += 1;
    budgetNextSeg(g);
    expect(g.cards).toEqual([]);
  });

  it('요구(5)·부탁(5)·내정 선택(6)도 같다', () => {
    for (const card of [{ kind: 'favor', comm: 'front' as const }, { kind: 'dom:give' }, { kind: 'dom:fit', text: 'e1' }]) {
      const g = createS1cGame('bg-fade-all');
      enableBudget(g);
      picked(g, 3);
      addCard(g, card);
      g.seg += 1;
      budgetNextSeg(g);
      picked(g, 3);
      budgetPass(g);
      expect(g.cards, card.kind).toEqual([]);
      expect(g.deferred, card.kind).toEqual([]);
      expect(g.budget!.stats.faded[String(gradeOf(card.kind))], card.kind).toBe(1);
      expect(g.journal.at(-1)!.text, card.kind).toContain('흐지부지');
    }
  });
});

describe('대상이 사라지면 버린다', () => {
  const tailParent = FAMILIES.find(f => f.community === 'tail' && f.children.some(id => PROFILES.find(p => p.id === id)!.age < 16))!;
  const nm = (id: string) => PROFILES.find(p => p.id === id)!.name;

  it('남은 아이 카드: 아이가 모두 없어졌으면 조용히 버린다', () => {
    const g = fresh('bg-orphan');
    picked(g, 3);
    onDeath(g, 'tail', [nm(tailParent.parents[0])]);
    expect(deferredKinds(g)).toEqual(['orphan']);
    for (const id of tailParent.children) if (PROFILES.find(p => p.id === id)!.age < 16) g.deaths.push(nm(id));
    g.seg += 1;
    budgetNextSeg(g);
    expect(g.cards).toEqual([]);
    expect(g.deferred).toEqual([]);
    expect(g.budget!.stats.dropped).toEqual({ 3: 1 });
    expect(g.journal.some(j => j.text.includes('흐지부지'))).toBe(false);
  });

  it('남은 아이가 살아 있으면 그대로 돌아온다', () => {
    const g = fresh('bg-orphan-alive');
    picked(g, 3);
    onDeath(g, 'tail', [nm(tailParent.parents[0])]);
    g.seg += 1;
    budgetNextSeg(g);
    expect(kinds(g)).toEqual(['orphan']);
  });

  it('노인·출산·이름 카드: 그 사람이 죽었거나 내렸으면 버린다', () => {
    const g = fresh('bg-people');
    picked(g, 3);
    const [a, b, c] = PROFILES.filter(p => p.community === 'tail').slice(10, 13).map(p => p.name);
    g.born = { comm: 'tail', mother: b, weak: false, left: 0 };
    addCard(g, { kind: 'elder', comm: 'tail', who: a });
    addCard(g, { kind: 'birth', comm: 'tail', who: b });
    addCard(g, { kind: 'naming', comm: 'tail', who: c });
    expect(deferredKinds(g)).toEqual(['elder', 'birth', 'naming']);
    g.deaths.push(a);
    (g.left ??= []).push(b);
    g.deaths.push(c);
    g.seg += 1;
    budgetNextSeg(g);
    expect(g.cards).toEqual([]);
    expect(g.budget!.stats.dropped).toEqual({ 3: 3 });
  });

  it('앓던 대표가 일어났으면 대표 카드를 버리고, 요구가 풀렸으면 요구 카드를 버린다', () => {
    const g = fresh('bg-resolved');
    picked(g, 3);
    g.comms.tail.sick = { since: 1, rep: g.comms.tail.leader };
    addCard(g, { kind: 'rep_sick', comm: 'tail' });
    addCard(g, { kind: 'demand', comm: 'tail' });
    expect(deferredKinds(g)).toEqual(['rep_sick', 'demand']);
    g.comms.tail.sick = undefined;
    g.comms.tail.base = [90, 90, 10, 10];
    g.seg += 1;
    budgetNextSeg(g);
    expect(g.cards).toEqual([]);
    expect(g.budget!.stats.dropped).toEqual({ 3: 1, 5: 1 });
  });

  it('요구가 아직 풀리지 않았으면 돌아온다', () => {
    const g = fresh('bg-demand-open');
    picked(g, 3);
    g.comms.tail.base = [10, 90, 10, 10];
    addCard(g, { kind: 'demand', comm: 'tail' });
    g.seg += 1;
    budgetNextSeg(g);
    expect(kinds(g)).toEqual(['demand']);
  });

  it('내정 카드: 대체 불가 인력이 없어졌거나 복원이 이미 시작됐으면 버린다', () => {
    const g = createS1cGame('bg-dom');
    enableBudget(g);
    picked(g, 3);
    const p = g.dom!.people.find(x => x.alive && !x.gone)!;
    addCard(g, { kind: 'dom:demand', who: p.id, n: 0 });
    addCard(g, { kind: 'dom:officer', who: p.id });
    addCard(g, { kind: 'dom:fit', text: 'e1' });
    expect(deferredKinds(g)).toEqual(['dom:demand', 'dom:officer', 'dom:fit']);
    p.alive = false;
    g.dom!.techs.e1 = { stage: 'restoring' } as never;
    g.seg += 1;
    budgetNextSeg(g);
    expect(g.cards).toEqual([]);
    expect(g.budget!.stats.dropped).toEqual({ 4: 2, 6: 1 });
  });
});

describe('저장과 복원', () => {
  it('미뤄 둔 카드와 장부가 JSON 저장을 거쳐 그대로 돌아오고, 이어서 돌아온다', () => {
    const g = fresh('bg-save');
    const ev = TRAVEL_EVENTS[0];
    picked(g, 3);
    addCard(g, { kind: 'keepsake', comm: 'tail', who: '가' });
    addCard(g, { kind: 'travel', text: ev.id });
    expect(deferredKinds(g)).toEqual(['keepsake', 'travel']);
    const r = readSave(JSON.parse(JSON.stringify(cloneGame(g))));
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(r.g.deferred).toEqual(g.deferred);
    expect(r.g.budget).toEqual(g.budget);
    expect(r.g.deferred![1].pushed).toBe(1);
    // 복원한 판에서 구간이 넘어가면 돌아온다
    r.g.seg += 1;
    budgetNextSeg(r.g);
    expect(r.g.cards.map(c => c.kind)).toEqual(['keepsake', 'travel']);
    // 복원한 판에서도 두 번 밀리면 일지가 된다
    picked(r.g, 3);
    budgetPass(r.g);
    expect(r.g.cards).toEqual([]);
    expect(r.g.deferred!.map(c => c.kind)).toEqual(['keepsake']); // 3등급은 다시 미뤄지기만 한다
    expect(r.g.journal.at(-1)!.text).toContain('흐지부지'); // 7등급은 일지 한 줄
  });

  it('예산을 켜고 저장한 옛 판에 deferred가 없으면 빈 목록으로 채운다. 끈 판은 아무것도 안 채운다', () => {
    const g = fresh('bg-save2');
    const raw = JSON.parse(JSON.stringify(cloneGame(g)));
    delete raw.deferred;
    delete raw.budget.stats;
    const r = readSave(raw);
    expect(r.ok && r.g.deferred).toEqual([]);
    expect(r.ok && r.g.budget?.stats).toEqual({ deferred: {}, faded: {}, dropped: {} });
    const off = readSave(JSON.parse(JSON.stringify(cloneGame(createGame('bg-save3')))));
    expect(off.ok && off.g.deferred).toBeUndefined();
    expect(off.ok && off.g.budget).toBeUndefined();
    expect(readSave({ ...JSON.parse(JSON.stringify(createGame('bg-save4'))), deferred: 'x' }).ok).toBe(false);
  });
});

describe('자동 플레이로 본 효과', () => {
  it('내정을 켠 판에서 한 구간에 카드를 4장 넘게 고르는 구간이 줄고, 미룬 카드가 등급별로 센다', () => {
    const opts: BotOptions = { s1c: true, policy: 'caretaker', dom: 'engaged' };
    let offBig = 0; let onBig = 0; let segs = 0;
    const deferred: Record<string, number> = {};
    for (let i = 0; i < 60; i += 1) {
      const off = playGame(`bg-eff-${i}`, opts).m;
      const on = playGame(`bg-eff-${i}`, { ...opts, budget: true }).m;
      offBig += off.cardsPerSeg[4];
      onBig += on.cardsPerSeg[4];
      segs += off.cardsPerSeg.reduce((a, b) => a + b, 0);
      for (const [k, v] of Object.entries(on.budget!.deferred)) deferred[k] = (deferred[k] ?? 0) + v;
    }
    expect(segs).toBeGreaterThan(1000);
    expect(onBig).toBeLessThan(offBig * 0.8);
    expect(Object.keys(deferred).length).toBeGreaterThan(0);
  }, 60_000);

  it('S1b를 켠 판도 예산을 켜고 끝까지 돈다(어두운 길 카드는 안 미룬다)', () => {
    for (const seed of ['bg-dark-0', 'bg-dark-1']) {
      const { g } = playGame(seed, { s1c: true, policy: 'caretaker', dom: 'engaged', s1b: 'kind', budget: true });
      expect(g.end).not.toBeNull();
      expect((g.deferred ?? []).every(c => !c.kind.startsWith('dark:') || c.kind === 'dark:armory')).toBe(true);
    }
    const g = createGame('bg-dark-enable');
    enableDark(g);
    enableBudget(g);
    expect(g.budget).toBeTruthy();
  });
});
