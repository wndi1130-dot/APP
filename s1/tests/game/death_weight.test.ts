import { afterEach, describe, expect, it } from 'vitest';
import {
  agendaOptions, chooseCard, COMM_NAME, COMMS, createGame, createS1cGame, deathSlot, DW, emergencyCost, enableDark, enableDeathWeight, fallSick, FAMILIES,
  isLawAgenda, isSessionSeg, lawActive, lawOpen, mourners, noteHeatDeath, onDeath, peopleTick, PROFILES, TRUST_BY_LEVEL, viewCard,
} from '../../src/game';
import type { Comm, Difficulty, Game, LawAgenda } from '../../src/game';
import { playGame } from '../../tools/s1c_bot';

// 죽음의 무게(결정 353·354·355, 값은 결정 367). 기본 꺼짐: enableDeathWeight(g)를 부른 판에서만 돈다.

const DW0 = { ...DW };
afterEach(() => { Object.assign(DW, DW0); });

const NEW_KINDS = ['loss_rep', 'loss_child', 'loss_hand', 'chain_push', 'chain_fix', 'heat_after'];
const byId = (id: string) => PROFILES.find(p => p.id === id)!;
const leaders = (g: Game) => COMMS.map(c => g.comms[c].leader.name);
const inFamily = (id: string) => FAMILIES.some(f => [...f.parents, ...f.children].includes(id));

/** 켠 새 판(카드 없음). */
function fresh(seed = 'dw'): Game {
  const g = createGame(seed);
  g.cards = [];
  enableDeathWeight(g);
  return g;
}

const tailFamily = FAMILIES.find(f => f.community === 'tail' && f.children.some(id => byId(id).age < 16))!;
/** 대표가 아닌 부모 하나(씨앗마다 대표가 다르다) */
const parentOf = (g: Game) => byId(tailFamily.parents.find(id => !leaders(g).includes(byId(id).name))!);
const otherParent = (g: Game) => byId(tailFamily.parents.find(id => id !== parentOf(g).id)!);
const childOf = () => byId(tailFamily.children.find(id => byId(id).age < 16)!);
/** 가족이 없는 사람(자리가 나이로만 갈린다) */
function lone(g: Game, c: Comm, test: (age: number) => boolean, skip: string[] = []) {
  return PROFILES.find(p => p.community === c && !inFamily(p.id) && test(p.age) && !leaders(g).includes(p.name) && !skip.includes(p.name))!;
}

function pick(g: Game, kind: string, label: string): void {
  const card = g.cards.find(c => c.kind === kind)!;
  expect(card, kind).toBeTruthy();
  const idx = viewCard(g, card).choices.findIndex(c => c.label === label);
  expect(idx, label).toBeGreaterThanOrEqual(0);
  expect(chooseCard(g, card.uid, idx)).toBe(true);
}

/** 다음 구간 정산의 사람 틱만 돌린다(난수 1: 앓기·내리기 없음). */
function nextSeg(g: Game): void {
  g.seg += 1;
  peopleTick(g, () => 1);
}

describe('자리 판정', () => {
  it('대표 > 부모 > 아이 > 일손 > 그 밖(65세 이상) 순서로 먼저 맞는 자리 하나', () => {
    const g = fresh('slot');
    expect(deathSlot(g, g.comms.tail.leader.name)).toBe('rep');
    expect(deathSlot(g, parentOf(g).name)).toBe('parent');
    expect(deathSlot(g, childOf().name)).toBe('child');
    expect(deathSlot(g, lone(g, 'guard', a => a >= 16 && a < 65).name)).toBe('hand');
    const old = PROFILES.find(p => p.age >= 65 && !leaders(g).includes(p.name) && !FAMILIES.some(f => f.parents.includes(p.id)))!;
    expect(deathSlot(g, old.name)).toBe('elder');
    // 앓아누운 대표도 대표 자리다(이미 leader가 아니어도)
    fallSick(g, 'guard');
    expect(deathSlot(g, g.comms.guard.sick!.rep.name)).toBe('rep');
  });

  it('한 정산에 여럿이 죽으면 카드 한 장, 부모가 아이·일손보다 먼저다', () => {
    const g = fresh('slot-many');
    const hand = lone(g, 'tail', a => a >= 16 && a < 65);
    onDeath(g, 'tail', [hand.name, parentOf(g).name]);
    const loss = g.cards.filter(c => NEW_KINDS.includes(c.kind) || c.kind === 'orphan' || c.kind === 'keepsake');
    expect(loss.map(c => c.kind)).toEqual(['orphan']);
  });
});

describe('자리별 뒷사건', () => {
  it('아이가 죽으면 빈 잠자리 한 장, 선택지 효과가 표대로이고 나중에 올 것(later)이 없다', () => {
    const g = fresh('child');
    onDeath(g, 'tail', [childOf().name]);
    const card = g.cards.find(c => c.kind === 'loss_child')!;
    const v = viewCard(g, card);
    expect(v.title).toBe('빈 잠자리');
    expect(v.choices.every(c => c.later === undefined)).toBe(true);
    expect(v.choices[0].effs).toEqual([{ t: 'coal', v: -3 }, { t: 'base', c: 'tail', i: 0, v: 3 }]);
    expect(v.choices[1].effs).toEqual([{ t: 'rel', c: 'tail', v: -4 }, { t: 'tension', v: 2 }]);
    const w0 = g.comms.tail.base[0];
    pick(g, 'loss_child', '들어준다');
    expect(g.comms.tail.base[0]).toBe(w0 + 3);
  });

  it('일손: 나눠 지면 다음 정차 작업조가 준다. 내정 판의 숙련 일손이면 둘, 아니면 하나', () => {
    const plain = fresh('hand');
    const h = lone(plain, 'guard', a => a >= 16 && a < 65);
    onDeath(plain, 'guard', [h.name]);
    pick(plain, 'loss_hand', '그 칸이 나눠 진다');
    expect(plain.crewShort).toBe(1);

    const g = createS1cGame('hand-skilled');
    g.cards = [];
    enableDeathWeight(g);
    const p = g.dom!.people.find(x => x.alive && x.age >= 16 && x.age < 65 && !leaders(g).includes(x.name) && !FAMILIES.some(f => f.parents.includes(PROFILES.find(q => q.name === x.name)?.id ?? '')))!;
    p.skill = 2;
    onDeath(g, p.comm, [p.name]);
    const v = viewCard(g, g.cards.find(c => c.kind === 'loss_hand')!);
    expect(v.choices[1].extra).toEqual(['다음 정차 작업조 −2']);
    pick(g, 'loss_hand', '그 칸이 나눠 진다');
    expect(g.crewShort).toBe(2);
  });

  it('일손: 다른 칸에서 옮기면 인원이 옮겨 간다', () => {
    const g = fresh('hand-move');
    const h = lone(g, 'guard', a => a >= 16 && a < 65);
    onDeath(g, 'guard', [h.name]);
    const before = { ...Object.fromEntries(COMMS.map(c => [c, g.comms[c].pop])) } as Record<Comm, number>;
    const card = g.cards.find(c => c.kind === 'loss_hand')!;
    expect(chooseCard(g, card.uid, 0)).toBe(true);
    const moved = COMMS.filter(c => g.comms[c].pop !== before[c]);
    expect(moved).toHaveLength(2);
    expect(g.comms.guard.pop).toBe(before.guard + 1);
  });

  it('대표: S1b 승계 훅 뒤에 빈 의석이 오고, 약속하면 그 칸 약속이 걸린다', () => {
    const g = fresh('rep-dark');
    enableDark(g);
    const old = g.comms.tail.leader.name;
    onDeath(g, 'tail', [old], 'other');
    expect(g.comms.tail.leader.name).not.toBe(old);
    const card = g.cards.find(c => c.kind === 'loss_rep')!;
    expect(card.who).toBe(old);
    expect(viewCard(g, card).body).toContain(g.comms.tail.leader.name);
    pick(g, 'loss_rep', '약속한다');
    expect(g.comms.tail.promise).toBeTruthy();
  });

  it('대표: 앓던 대표가 죽어 측근이 자리를 이으면 빈 의석이 온다', () => {
    const g = fresh('rep-sick');
    fallSick(g, 'guard');
    const rep = g.comms.guard.sick!.rep.name;
    g.cards = [];
    onDeath(g, 'guard', [rep]);
    expect(g.cards.some(c => c.kind === 'loss_rep' || c.kind === 'keepsake')).toBe(false);
    nextSeg(g);
    expect(g.comms.guard.sick).toBeUndefined();
    expect(g.cards.find(c => c.kind === 'loss_rep')?.who).toBe(rep);
  });
});

describe('난방 배당 사망(결정 354)', () => {
  it('조용한 죽음은 이름 카드를 띄우지 않고 상중은 남긴다(끈 판은 옛 동작)', () => {
    const g = fresh('quiet');
    onDeath(g, 'tail', [parentOf(g).name], 'other', false, true);
    expect(g.cards.some(c => ['orphan', 'keepsake', ...NEW_KINDS].includes(c.kind))).toBe(false);
    expect(mourners(g, 'tail')).toContain(otherParent(g).name);
    const off = createGame('quiet');
    off.cards = [];
    onDeath(off, 'tail', [parentOf(g).name], 'other', false, true);
    expect(off.cards.some(c => c.kind === 'orphan')).toBe(true);
  });

  it('난방 배당 죽음 다음에 이름 없는 식은 난로 한 장, 칸은 가장 많이 잃은 칸', () => {
    const g = fresh('heat-after');
    g.passed.heat_quota = 0;
    const a = lone(g, 'medtech', x => x >= 16 && x < 65);
    const b = lone(g, 'guard', x => x >= 16 && x < 65);
    const c2 = lone(g, 'guard', x => x >= 16 && x < 65, [b.name]);
    for (const [c, p] of [['medtech', a], ['guard', b], ['guard', c2]] as const) { onDeath(g, c, [p.name], 'other', false, true); noteHeatDeath(g, c); }
    peopleTick(g, () => 1);
    const card = g.cards.find(c => c.kind === 'heat_after')!;
    expect(card.comm).toBe('guard');
    expect(card.n).toBe(3);
    const body = viewCard(g, card).body;
    for (const p of PROFILES) expect(body.includes(p.name), p.name).toBe(false);
    for (const n of Object.values(COMM_NAME)) expect(body.includes(n), n).toBe(false);
    expect(body).toContain('난로가 식었다');
  });

  it('식은 난로에서 올리겠다고 하면 다음 회기 안건에 난방 배당 폐지가 폐지 냉각 없이 오른다', () => {
    const g = fresh('heat-agenda');
    g.passed.heat_quota = g.session;
    const a = lone(g, 'tail', x => x >= 16 && x < 65);
    onDeath(g, 'tail', [a.name], 'other', false, true);
    noteHeatDeath(g, 'tail');
    peopleTick(g, () => 1);
    const card = g.cards.find(c => c.kind === 'heat_after')!;
    g.corpseIssue = false; // 시신 안건이 위기로 먼저 서지 않게
    const isRepeal = (o: object) => 'law' in o && (o as unknown as { law: string }).law === 'heat_quota' && (o as unknown as { repeal: boolean }).repeal;
    expect(agendaOptions(g).options.some(isRepeal)).toBe(false);
    expect(chooseCard(g, card.uid, viewCard(g, card).choices.findIndex(c => c.special === 'dw_heat_agenda'))).toBe(true);
    expect(agendaOptions(g).options.some(isRepeal)).toBe(true);
  });

  it('법이 그새 내려졌으면 식은 난로가 안 뜬다', () => {
    const g = fresh('heat-gone');
    g.passed.heat_quota = 0;
    const a = lone(g, 'tail', x => x >= 16 && x < 65);
    onDeath(g, 'tail', [a.name], 'other', false, true);
    noteHeatDeath(g, 'tail');
    delete g.passed.heat_quota;
    peopleTick(g, () => 1);
    expect(g.cards.some(c => c.kind === 'heat_after')).toBe(false);
  });
});

describe('사건 줄', () => {
  it('원인 → 반발 → 고칠 길이 구간마다 한 칸씩, 거절했으면 반발 긴장 4', () => {
    const g = fresh('chain');
    onDeath(g, 'tail', [childOf().name]);
    pick(g, 'loss_child', '지금은 안 된다');
    expect(g.deathChains).toHaveLength(1);
    const t0 = g.tension;
    nextSeg(g);
    expect(g.tension - t0).toBe(DW.chainTension);
    pick(g, 'chain_push', '물리친다');
    expect(g.voteShift).toEqual([{ comm: 'tail', n: -1, side: 'captain' }]);
    nextSeg(g);
    pick(g, 'chain_fix', '값을 치르고 닫는다');
    expect(g.deathChains).toHaveLength(0);
    expect(g.deathStats!.fixed).toBe(1);
  });

  it('들어줬으면 반발 긴장 2, 그 칸 관계가 6 넘게 오르면 반발을 건너뛴다', () => {
    const g = fresh('chain-soft');
    onDeath(g, 'tail', [childOf().name]);
    pick(g, 'loss_child', '들어준다');
    const t0 = g.tension;
    nextSeg(g);
    expect(g.tension - t0).toBe(DW.chainTensionSoft);

    const h = fresh('chain-skip');
    onDeath(h, 'tail', [childOf().name]);
    pick(h, 'loss_child', '들어준다');
    h.comms.tail.rel += 7;
    nextSeg(h);
    expect(h.cards.some(c => c.kind === 'chain_push')).toBe(false);
    expect(h.cards.some(c => c.kind === 'chain_fix')).toBe(true);
  });

  it('끊김: 요구가 채워지거나 4구간이 지나면 줄이 사라진다', () => {
    const g = fresh('chain-met');
    onDeath(g, 'tail', [childOf().name]);
    pick(g, 'loss_child', '지금은 안 된다');
    g.comms.tail.heat += 1;
    nextSeg(g);
    expect(g.deathChains).toHaveLength(0);
    expect(g.cards.some(c => c.kind === 'chain_push')).toBe(false);

    const h = fresh('chain-old');
    onDeath(h, 'tail', [childOf().name]);
    pick(h, 'loss_child', '지금은 안 된다');
    h.seg += DW.chainLife;
    peopleTick(h, () => 1);
    expect(h.deathChains).toHaveLength(0);
    expect(h.deathStats!.broken).toBe(1);
  });

  it('겹침: 같은 칸 새 죽음은 새 줄을 안 열고 반발을 +2, 셋째 줄은 안 열리며, 한 구간 사건 줄 카드는 한 장', () => {
    const g = fresh('chain-overlap');
    onDeath(g, 'tail', [childOf().name]);
    pick(g, 'loss_child', '지금은 안 된다');
    g.seg += 1;
    const h = lone(g, 'tail', a => a >= 16 && a < 65);
    onDeath(g, 'tail', [h.name]);
    pick(g, 'loss_hand', '그 칸이 나눠 진다');
    expect(g.deathChains).toHaveLength(1);
    expect(g.deathChains![0].bumped).toBe(true);

    const k = lone(g, 'guard', a => a >= 16 && a < 65);
    onDeath(g, 'guard', [k.name]);
    pick(g, 'loss_hand', '그 칸이 나눠 진다');
    expect(g.deathChains).toHaveLength(2);
    const m = lone(g, 'medtech', a => a >= 16 && a < 65);
    onDeath(g, 'medtech', [m.name]);
    pick(g, 'loss_hand', '그 칸이 나눠 진다');
    expect(g.deathChains).toHaveLength(2);
    expect(g.deathChains!.some(x => x.comm === 'medtech')).toBe(false);

    const t0 = g.tension;
    nextSeg(g);
    const chainCards = g.cards.filter(c => c.kind === 'chain_push' || c.kind === 'chain_fix');
    expect(chainCards).toHaveLength(1);
    expect(chainCards[0].comm).toBe('tail');
    expect(g.tension - t0).toBe(DW.chainTension + DW.chainBump);
  });
});

describe('「배웅」 법 한 쌍', () => {
  it('첫 죽음 뒤, 시신 법이 선 뒤에만 열리고, 하나가 서면 다른 하나가 닫히며 폐지 안건이 없다', () => {
    const g = fresh('farewell-open');
    expect(lawOpen(g, 'farewell_rite')).toBe(false);
    onDeath(g, 'guard', [lone(g, 'guard', a => a >= 16 && a < 65).name]);
    expect(lawOpen(g, 'farewell_rite')).toBe(false);
    g.passed.corpse_store = 0;
    expect(lawOpen(g, 'farewell_rite')).toBe(true);
    expect(lawOpen(g, 'farewell_hands')).toBe(true);
    g.passed.farewell_rite = 0;
    expect(lawOpen(g, 'farewell_hands')).toBe(false);
    g.session = 20;
    expect(agendaOptions(g).options.some(o => 'law' in o && o.law === 'farewell_rite' && o.repeal)).toBe(false);
    // 끈 판엔 늘 닫혀 있다
    const off = createGame('farewell-open');
    off.cards = [];
    onDeath(off, 'guard', [lone(off, 'guard', a => a >= 16 && a < 65).name]);
    off.passed.corpse_store = 0;
    expect(lawOpen(off, 'farewell_rite')).toBe(false);
  });

  it('함께 보낸다: 시신 법 없는 판의 긴장 3×n이 절반(내림), 석탄 −n, 상중 3구간, 반발 긴장도 절반', () => {
    const g = fresh('rite');
    g.passed.farewell_rite = 0;
    const a = lone(g, 'guard', x => x >= 16 && x < 65);
    const b = lone(g, 'guard', x => x >= 16 && x < 65, [a.name]);
    const t0 = g.tension;
    const c0 = g.coal;
    onDeath(g, 'guard', [a.name, b.name]);
    expect(g.tension - t0).toBe(3);
    expect(c0 - g.coal).toBe(2);
    const h = fresh('rite-mourn');
    h.passed.farewell_rite = 0;
    h.passed.corpse_store = 0;
    onDeath(h, 'tail', [parentOf(h).name]);
    expect(h.mourning!.find(m => m.name === otherParent(h).name)!.until).toBe(h.seg + 3);
    h.cards = [];
    const k = fresh('rite-chain');
    k.passed.farewell_rite = 0;
    k.passed.corpse_store = 0;
    onDeath(k, 'tail', [childOf().name]);
    pick(k, 'loss_child', '지금은 안 된다');
    const t1 = k.tension;
    nextSeg(k);
    expect(k.tension - t1).toBe(Math.floor(DW.chainTension / 2));
  });

  it('손을 보내 배웅한다: 신임 깎임 절반, 그 칸 관계 벌 없음, 작업조가 준다', () => {
    const g = fresh('hands');
    g.passed.farewell_hands = 0;
    const tr = g.trust;
    onDeath(g, 'tail', [childOf().name]);
    expect(tr - g.trust).toBe(Math.floor(DW.trust / 2));
    expect(g.crewShort).toBe(1);
    const v = viewCard(g, g.cards.find(c => c.kind === 'loss_child')!);
    expect(v.choices[1].effs.some(e => e.t === 'rel')).toBe(false);
  });
});

describe('신임과 비상 소집', () => {
  it('신임 깎임은 판의 난이도(g.difficulty)를 읽는다: 쉬움 1·보통 2·어려움 3, 난이도가 없는 판(옛 저장)은 보통', () => {
    const levels: (Difficulty | undefined)[] = ['easy', 'normal', 'hard', undefined];
    const want = [1, 2, 3, 2];
    levels.forEach((lv, i) => {
      const g = fresh(`level-${lv ?? 'none'}`);
      if (lv) g.difficulty = lv;
      const tr = g.trust;
      onDeath(g, 'tail', [lone(g, 'tail', x => x >= 16 && x < 65).name]);
      expect(tr - g.trust, lv ?? 'none').toBe(want[i]);
    });
  });

  it('「손을 보내 배웅한다」의 절반 내림은 한 명씩 와도 한꺼번에 와도 같다(쉬움 1·어려움 3에서도)', () => {
    for (const [lv, two] of [['easy', 1], ['normal', 2], ['hard', 3]] as const) {
      const once = fresh(`half-${lv}-a`);
      const each = fresh(`half-${lv}-b`);
      for (const g of [once, each]) { g.difficulty = lv; g.passed.farewell_hands = 0; }
      const a = lone(once, 'tail', x => x >= 16 && x < 65);
      const b = lone(once, 'tail', x => x >= 16 && x < 65, [a.name]);
      const t1 = once.trust;
      onDeath(once, 'tail', [a.name, b.name]);
      const t2 = each.trust;
      onDeath(each, 'tail', [a.name]);
      onDeath(each, 'tail', [b.name]);
      expect(t1 - once.trust, `${lv} 한꺼번에`).toBe(two);
      expect(t2 - each.trust, `${lv} 한 명씩`).toBe(two);
    }
  });

  it('식은 난로의 약속 안건은 회기 앞 정산에서 AI가 안건을 내도 남고 폐지 냉각 예외도 지킨다', () => {
    let aiPicks = 0;
    const lost: string[] = [];
    for (let i = 0; i < 4; i += 1) {
      let law: LawAgenda['law'] | null = null;
      playGame(`dw-promise-${i}`, {
        s1c: true, policy: 'caretaker', dom: 'engaged', deathWeight: true,
        probe: {
          beforePrep: x => {
            if (!isSessionSeg(x.seg + 1) && !isSessionSeg(x.seg + 2)) return;
            if (!law || !lawActive(x, law)) { x.passed.heat_quota = x.session; law = 'heat_quota'; }
            const l = law;
            if (!x.proposals.some(p => isLawAgenda(p) && p.promise && p.law === l)) x.proposals = [{ law: l, repeal: true, promise: true }, ...x.proposals];
          },
          onSettle: x => {
            const l = law;
            if (!l || !x.proposals.some(p => p.by)) return;
            aiPicks += 1;
            if (!x.proposals.some(p => isLawAgenda(p) && p.law === l && p.repeal && p.promise)) lost.push(`${x.seed}:${x.seg}`);
          },
        },
      });
    }
    expect(aiPicks).toBeGreaterThan(0);
    expect(lost).toEqual([]);
  });

  it('신임 깎임 기본값은 보통 난이도 값이고, 쉬움 1·보통 2·어려움 3이 같은 자리에 있다(결정 376)', () => {
    expect(TRUST_BY_LEVEL).toEqual({ easy: 1, normal: 2, hard: 3 });
    expect(DW.trust).toBe(TRUST_BY_LEVEL.normal);
  });

  it('죽음마다 신임 −2, 한 구간 상한 6, 다음 구간엔 새로 센다', () => {
    const g = fresh('trust');
    const t0 = g.trust;
    const ppl = PROFILES.filter(p => p.community === 'guard' && !leaders(g).includes(p.name)).slice(0, 4).map(p => p.name);
    onDeath(g, 'guard', [ppl[0]]);
    expect(t0 - g.trust).toBe(2);
    onDeath(g, 'guard', ppl.slice(1, 4));
    expect(t0 - g.trust).toBe(DW.trustCap);
    g.seg += 1;
    const t1 = g.trust;
    onDeath(g, 'tail', [childOf().name]);
    expect(t1 - g.trust).toBe(2);
  });

  it('비상 소집 비용이 최근 6구간 죽음 수만큼 오른다', () => {
    const g = fresh('emerg');
    const base = emergencyCost(g);
    onDeath(g, 'guard', [lone(g, 'guard', a => a >= 16 && a < 65).name]);
    onDeath(g, 'tail', [childOf().name]);
    expect(emergencyCost(g)).toBe(base + 2 * DW.emerg);
    g.seg += 6;
    expect(emergencyCost(g)).toBe(base);
  });
});

describe('꺼진 판', () => {
  it('켜지 않은 판에는 새 카드·사건 줄·작업조 증감이 없고 「배웅」이 안 열린다', () => {
    for (const opts of [{ s1c: false, policy: 'caretaker', dom: 'idle' }, { s1c: true, policy: 'first', dom: 'engaged', s1b: 'kind', disasters: true }] as const) {
      for (const seed of ['dw-off-0', 'dw-off-1']) {
        const { g, m } = playGame(seed, opts);
        expect(g.deathWeight).toBeUndefined();
        expect(g.deathChains).toBeUndefined();
        expect(g.crewShort).toBeUndefined();
        for (const k of NEW_KINDS) expect(m.cards[k] ?? 0, k).toBe(0);
        expect(g.passed.farewell_rite ?? g.passed.farewell_hands).toBeUndefined();
      }
    }
  }, 60_000);

  it('켠 판도 봇이 끝까지 돌고 뒷사건 카드가 나온다', () => {
    let loss = 0;
    for (const seed of ['dw-on-0', 'dw-on-1', 'dw-on-2', 'dw-on-3']) {
      const { m } = playGame(seed, { s1c: true, policy: 'caretaker', dom: 'engaged', deathWeight: true });
      loss += NEW_KINDS.reduce((s, k) => s + (m.cards[k] ?? 0), 0);
    }
    expect(loss).toBeGreaterThan(0);
  }, 60_000);
});
