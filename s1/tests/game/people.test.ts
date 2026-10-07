import { writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  advance, birthSeg, blocs, castVote, chooseCard, COMMS, createGame, currentAgenda, FAMILIES, fallSick, makeDeal, mourners, onDeath,
  openCouncil, peopleCardRecent, peopleTick, pickVictims, primaryAction, PROFILES, resolveStop, toolStatus, viewCard,
} from '../../src/game';
import type { Game } from '../../src/game';

// 사람의 무게(2026-10-07 사용자가 고른 묶음, politics_detail 6장). 숫자는 제안이다.

const name = (id: string) => PROFILES.find(p => p.id === id)!;
const tailFamily = FAMILIES.find(f => f.community === 'tail' && f.children.some(id => name(id).age < 16))!;

function pickChoice(g: Game, kind: string, label: string) {
  const card = g.cards.find(c => c.kind === kind)!;
  const idx = viewCard(g, card).choices.findIndex(c => c.label === label);
  expect(idx, label).toBeGreaterThanOrEqual(0);
  expect(chooseCard(g, card.uid, idx)).toBe(true);
}

describe('A1 유품과 남은 사람', () => {
  it('아이를 남긴 부모가 죽으면 남은 아이 카드가 오고, 맡긴 칸이 판 끝 일지에 남는다', () => {
    const g = createGame('orphan');
    const parent = name(tailFamily.parents[0]).name;
    onDeath(g, 'tail', [parent]);
    const card = g.cards.find(c => c.kind === 'orphan')!;
    expect(card.who).toBe(parent);
    const view = viewCard(g, card);
    expect(view.body).toContain(parent);
    expect(view.body).toContain('열차장의 말을 기다린다');
    pickChoice(g, 'orphan', '앞칸 집에 맡긴다');
    expect(Object.values(g.raised ?? {})).toContain('front');
    // 남은 가족은 상중이다.
    expect(mourners(g, 'tail')).toContain(name(tailFamily.parents[1]).name);
  });

  it('그 밖의 죽음엔 외투와 장화 카드가 오고, 나눈 온기는 2구간 뒤 돌아간다', () => {
    const g = createGame('keepsake');
    const lone = PROFILES.find(p => p.community === 'guard' && !FAMILIES.some(f => [...f.parents, ...f.children].includes(p.id)) && p.name !== g.comms.guard.leader.name)!;
    onDeath(g, 'guard', [lone.name]);
    expect(g.cards.some(c => c.kind === 'keepsake')).toBe(true);
    const w0 = g.comms.guard.base[0];
    pickChoice(g, 'keepsake', '그 칸에 나눈다');
    expect(g.comms.guard.base[0]).toBe(w0 + 2);
    g.seg += 2;
    peopleTick(g, () => 1);
    expect(g.comms.guard.base[0]).toBe(w0);
  });

  it('상중인 사람은 회기에 빠진다', () => {
    const g = createGame('mourn-vote');
    g.seg = 3;
    openCouncil(g);
    const agenda = currentAgenda(g)!;
    const before = blocs(g, agenda, [])[tailFamily.community].absent;
    onDeath(g, 'tail', [name(tailFamily.parents[0]).name]);
    const after = blocs(g, agenda, [])[tailFamily.community].absent;
    expect(after).toBeGreaterThanOrEqual(before);
    expect(mourners(g, 'tail').length).toBeGreaterThan(0);
  });
});

describe('A2 대표의 몸', () => {
  it('처지가 30 아래로 이어지면 대표가 앓고 측근이 나온다. 측근과는 빚·뇌물이 안 통하고, 약을 보내면 돌아온다', () => {
    const g = createGame('sick');
    const rep = g.comms.tail.leader.name;
    g.comms.tail.base[1] = 10;
    g.comms.tail.debt = true;
    peopleTick(g, () => 0);
    peopleTick(g, () => 0);
    expect(g.comms.tail.sick?.rep.name).toBe(rep);
    expect(g.comms.tail.leader.name).not.toBe(rep);
    expect(g.cards.some(c => c.kind === 'rep_sick')).toBe(true);
    g.seg = 3;
    openCouncil(g);
    expect(toolStatus(g, 'tail', 'favor').ok).toBe(false);
    expect(toolStatus(g, 'tail', 'bribe').ok).toBe(false);
    pickChoice(g, 'rep_sick', '약을 보낸다');
    expect(g.comms.tail.leader.name).toBe(rep);
    expect(g.comms.tail.sick).toBeUndefined();
  });

  it('3구간 안에 안 일어나면 측근이 대표 자리를 잇는다', () => {
    const g = createGame('sick-succeed');
    fallSick(g, 'guard');
    g.comms.guard.base[0] = 5;
    const proxy = g.comms.guard.leader.name;
    g.seg += 3;
    peopleTick(g, () => 1);
    expect(g.comms.guard.sick).toBeUndefined();
    expect(g.comms.guard.leader.name).toBe(proxy);
  });

  it('겁·가족 성향의 대표 대신엔 야심·탐욕 쪽 측근이 나온다', () => {
    const g = createGame('sick-trait');
    g.comms.tail.leader.trait = 'family';
    fallSick(g, 'tail');
    expect(['ambition', 'greed']).toContain(g.comms.tail.leader.trait);
  });
});

describe('A3 내리겠다는 노인', () => {
  it('식량이 바닥이면 한 번 온다. 본문 첫 줄이 노인 스스로 정한 일임을 말하고, 보내면 열차에서 사라진다', () => {
    const g = createGame('elder');
    g.food = 10;
    peopleTick(g, () => 1);
    const card = g.cards.find(c => c.kind === 'elder')!;
    expect(viewCard(g, card).body.startsWith(`${card.who}이(가) 스스로 정했다`)).toBe(true);
    const pop = g.comms[card.comm!].pop;
    pickChoice(g, 'elder', '작별을 치른다');
    expect(g.comms[card.comm!].pop).toBe(pop - 1);
    expect(g.left).toContain(card.who);
    expect(g.deaths).not.toContain(card.who);
    g.cards = [];
    peopleTick(g, () => 1);
    expect(g.cards.some(c => c.kind === 'elder')).toBe(false);
  });
});

describe('A4 출산', () => {
  it('판의 약 40%에서 8~18구간 사이에 한 번 온다', () => {
    let n = 0;
    for (let i = 0; i < 2000; i += 1) {
      const s = birthSeg(`birth-${i}`);
      if (s === null) continue;
      n += 1;
      expect(s).toBeGreaterThanOrEqual(8);
      expect(s).toBeLessThanOrEqual(18);
    }
    expect(n / 2000).toBeGreaterThan(0.35);
    expect(n / 2000).toBeLessThan(0.45);
  });

  function birthGame() {
    for (let i = 0; ; i += 1) {
      const seed = `born-${i}`;
      const at = birthSeg(seed);
      if (at === null) continue;
      const g = createGame(seed);
      g.seg = at;
      peopleTick(g, () => 1);
      if (g.cards.some(c => c.kind === 'birth')) return g;
    }
  }

  it('따뜻한 데서 낳으면 바로 이름 카드가 붙는다', () => {
    const g = birthGame();
    const c = g.born!.comm;
    const pop = g.comms[c].pop;
    pickChoice(g, 'birth', '의무칸으로 옮긴다');
    expect(g.comms[c].pop).toBe(pop + 1);
    expect(g.cards[0].kind).toBe('naming');
  });

  it('추운 칸에서 낳으면 약한 아이: 의약품으로 3구간을 버티면 이름 카드, 못 내면 일지 한 줄', () => {
    const g = birthGame();
    const c = g.born!.comm;
    g.comms[c].base[0] = 10;
    pickChoice(g, 'birth', '그 칸에서 낳는다');
    expect(g.born!.weak).toBe(true);
    expect(g.cards.some(x => x.kind === 'naming')).toBe(false);
    for (let i = 0; i < 3; i += 1) { g.seg += 1; peopleTick(g, () => 1); }
    expect(g.cards.some(x => x.kind === 'naming')).toBe(true);

    const h = birthGame();
    h.comms[h.born!.comm].base[0] = 10;
    pickChoice(h, 'birth', '그 칸에서 낳는다');
    h.med = 0;
    h.seg += 1;
    peopleTick(h, () => 1);
    expect(h.born!.lost).toBe(true);
    expect(h.journal.at(-1)!.text).toContain('겨울을 넘기지 못했다');
  });
});

describe('카드 수', () => {
  it('사람 카드가 막 오면 이동 사건을 쉰다', () => {
    const g = createGame('people-recent');
    expect(peopleCardRecent(g)).toBe(false);
    onDeath(g, 'tail', [name(tailFamily.parents[0]).name]);
    expect(peopleCardRecent(g)).toBe(true);
  });

  it('한 판에서 사람 카드가 몇 장 오는지(자동 플레이 200판)', () => {
    const count: Record<string, number> = {};
    let births = 0;
    for (let i = 0; i < 200; i += 1) {
      const g = createGame(`people-${i}`);
      for (let guard = 0; guard < 2000 && g.phase !== 'end'; guard += 1) {
        if (g.cards.length > 0) {
          const card = g.cards[0];
          count[card.kind] = (count[card.kind] ?? 0) + 1;
          chooseCard(g, card.uid, viewCard(g, card).choices.findIndex(c => !c.disabled));
          continue;
        }
        if (g.phase === 'stop' && g.stop && !g.stop.done) { resolveStop(g, true); continue; }
        if (g.phase === 'council' && g.council && !g.council.result && currentAgenda(g)) {
          for (const c of COMMS) if (toolStatus(g, c, 'open').ok) makeDeal(g, c, 'open', 0);
          castVote(g);
          continue;
        }
        if (!primaryAction(g).ok) break;
        advance(g);
      }
      if (g.born) births += 1;
    }
    const per = (k: string) => (count[k] ?? 0) / 200;
    // 제안 빈도: 유품 판당 2~3장 안팎, 대표 앓음 많아야 2, 노인 많아야 1, 출산은 판의 40% 남짓(판이 일찍 끝나면 덜).
    expect(per('orphan') + per('keepsake')).toBeGreaterThan(0.8);
    expect(per('rep_sick')).toBeLessThanOrEqual(2);
    expect(per('elder')).toBeLessThanOrEqual(1);
    expect(births / 200).toBeLessThan(0.45);
    writeFileSync(join(tmpdir(), 'people_counts.json'), JSON.stringify({ per: Object.fromEntries(Object.keys(count).map(k => [k, per(k)])), births: births / 200 }, null, 1));
  });
});

describe('누가 죽나(기획 점검 01 2.6)', () => {
  it('굶주림 사망은 판마다 다른 사람이고, 노인과 아이가 더 자주 쓰러진다', () => {
    const first = new Set<string>();
    let weak = 0;
    for (let i = 0; i < 200; i += 1) {
      const g = createGame(`victim-${i}`);
      const [p] = pickVictims(g, 1, 'hunger', () => { const v = ((i * 7919 + first.size * 104729) % 1000) / 1000; return v; });
      first.add(p.name);
      if (p.age >= 65 || p.age <= 10) weak += 1;
    }
    expect(first.size).toBeGreaterThan(20);
    const share = PROFILES.filter(p => p.age >= 65 || p.age <= 10).length / PROFILES.length;
    expect(weak / 200).toBeGreaterThan(share);
  });

  it('다쳐서 죽는 사람은 파견 나이다', () => {
    const g = createGame('victim-wound');
    let k = 0;
    for (const p of pickVictims(g, 10, 'wound', () => ((k++ * 37) % 100) / 100)) expect(p.age >= 16 && p.age <= 65).toBe(true);
  });
});
