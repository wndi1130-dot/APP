import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  addCard, chooseCard, COMMS, createGame, DZ, enableDark, enableDeathWeight, enableDisasters, enterMartial, PROFILES, viewCard,
} from '../../src/game';
import type { Card, CardView, DeathSlot, Game } from '../../src/game';
import { DARK_CARD_KINDS } from '../../src/game/dark/cards';
import { mobTarget, openCase } from '../../src/game/dark/cases';
import { nameOf } from '../../src/game/dark/state';
import type { Case, Ember } from '../../src/game/dark/state';

function darkGame(seed = 'choice-log'): Game {
  const g = createGame(seed);
  enableDark(g);
  return g;
}

function fresh(seed = 'choice-log-death'): Game {
  const g = createGame(seed);
  g.cards = [];
  enableDeathWeight(g);
  return g;
}

function add(g: Game, card: Omit<Card, 'uid'>): Card {
  addCard(g, card);
  return g.cards[g.cards.length - 1];
}

function ember(g: Game, patch: Partial<Ember> = {}): Ember {
  const e: Ember = {
    id: 900 + g.dark!.embers.length, who: 'tail', actor: g.comms.tail.leader.personId,
    target: 'guard', mark: g.comms.guard.leader.personId, cause: 'fervor',
    stage: 0, imm: 0, quiet: 0, guardUntil: -1, sab: 'heating', blocked: false, born: g.seg, ...patch,
  };
  g.dark!.embers.push(e);
  return e;
}

function investigation(g: Game): Case {
  return openCase(g, {
    kind: 'assault', culprit: g.comms.tail.leader.personId, victimComm: 'guard', dead: true, clock: 3, where: '통로',
  });
}

function logged(g: Game, card: Card): CardView {
  const view = viewCard(g, card);
  expect(view.choices.length, card.kind).toBeGreaterThan(0);
  for (const choice of view.choices) {
    const at = `${card.kind}/${choice.label}`;
    expect(choice.log, at).toBeTypeOf('string');
    expect(choice.log, at).not.toBe('');
    expect(choice.log, at).not.toMatch(/[:：]|옮기|옮겼|옮아/);
    expect(choice.log, at).not.toMatch(/undefined|null|NaN|\[object Object\]/);
  }
  return view;
}

const specials = (view: CardView) => view.choices.map(c => c.special);

describe('고른 선택이 남기는 일지', () => {
  it('어두운 카드 19종의 모든 선택지에 제목 머리 없는 log가 있다', () => {
    for (const kind of DARK_CARD_KINDS) {
      const g = darkGame(`choice-log-${kind}`);
      const e = ember(g, { imm: 2, sab: 'boiler' });
      const cs = investigation(g);
      if (kind === 'dark:gtrial') cs.status = 'trial';
      const view = logged(g, add(g, {
        kind, comm: 'tail', who: g.comms.tail.leader.personId, n: kind === 'dark:sign' ? e.id : cs.id,
        ...(kind === 'dark:sign' ? { text: 'imm' } : {}),
      }));
      // 빈 서류(처리 못 한 종류의 방어 갈래)로 빠지면 이 종류의 선택지를 본 것이 아니다
      expect(view.title, kind).not.toBe('빈 서류');
      expect(specials(view).some(s => s?.startsWith('dark:')), kind).toBe(true);
    }
  });

  it('지나간 기척과 닫힌 수사·군중·재판, 사보타주 뒤 알림에도 log가 있다', () => {
    const g = darkGame();
    for (const kind of ['dark:sign', 'dark:case', 'dark:mob', 'dark:gtrial', 'dark:act']) {
      logged(g, add(g, { kind, comm: 'tail', n: -1 }));
    }
    logged(g, add(g, { kind: 'dark:act', comm: 'engine', vals: { sab: 'boiler' } }));
  });

  it('묶인 징후는 같은 칸의 두 일과 서로 다른 칸, 홀로 남은 둘째 일을 구별한다', () => {
    const g = darkGame();
    const a = ember(g);
    const b = ember(g, { imm: 2, sab: 'boiler' });
    const card = add(g, { kind: 'dark:sign', n: a.id, text: 'kiche', vals: { n2: String(b.id), tier2: 'imm' } });
    const same = logged(g, card);
    expect(same.choices[1].log).toBe('꼬리칸의 첫째 일에 경비를 붙이기로 했다.');
    expect(same.choices[2].log).toBe('꼬리칸의 둘째 일에 경비를 붙이기로 했다.');
    b.who = 'engine';
    const different = logged(g, card);
    expect(different.choices[1].log).toBe('꼬리칸에 경비 두 사람을 붙이기로 했다.');
    expect(different.choices[2].log).toBe('기관실에 경비 두 사람을 붙이기로 했다.');
    g.dark!.embers = [b];
    expect(logged(g, card).choices[0].log).toBe('기관실에 경비 두 사람을 붙이기로 했다.');
  });

  it('평시·계엄 수사와 판결 뒤 벌에 log가 있다', () => {
    const g = darkGame();
    const cs = investigation(g);
    const card = add(g, { kind: 'dark:case', n: cs.id, comm: 'guard' });
    expect(logged(g, card).choices[1].log).toBe('수사를 의회 재판에 넘기기로 했다.');
    enterMartial(g, 'extend');
    expect(logged(g, card).choices[1].log).toBe('수사를 경비대 재판에 넘기기로 했다.');
    const who = cs.sus[0].id;
    const name = nameOf(g, who);
    for (const text of ['summary', 'guard', 'trial']) {
      const view = logged(g, add(g, { kind: 'dark:punish', who, n: cs.id, comm: 'guard', text }));
      for (const choice of view.choices) expect(choice.log).toContain(name);
    }
  });

  it('군중이 지목한 사람과 증인·명령 대상의 실제 이름을 log에 그대로 쓴다', () => {
    const g = darkGame();
    const person = PROFILES.find(p =>
      p.age >= 16 && ['pl', 'de', 'cz'].includes(p.name_lang ?? '')
      && !COMMS.some(c => g.comms[c].leader.personId === p.id))!;
    const cs = investigation(g);
    cs.sus = [{ id: person.id, culprit: true, facts: ['access'], clues: [{ kind: 'witness', truth: true, line: '그날 통로에서 봤다.', seg: g.seg }], acq: false }];
    expect(mobTarget(g, cs)?.id).toBe(person.id);
    const crowd = logged(g, add(g, { kind: 'dark:mob', n: cs.id, comm: 'guard' }));
    for (const choice of crowd.choices.filter(c => c.special !== 'dark:mob:promise')) {
      expect(choice.log).toContain(person.name);
    }
    // 드러나려는 일: 말하게 두는 줄은 벌받은 사람, 입을 닫는 줄은 증인
    const witness = PROFILES.find(p => p.age >= 16 && p.id !== person.id && !COMMS.some(c => g.comms[c].leader.personId === p.id))!;
    const truth = logged(g, add(g, { kind: 'dark:truth', who: person.id, text: witness.id, comm: person.community }));
    expect(truth.choices.find(c => c.special === 'dark:truth:let')?.log).toContain(person.name);
    expect(truth.choices.find(c => c.special === 'dark:truth:order')?.log).toContain(witness.name);
    expect(truth.choices.find(c => c.special === 'dark:truth:order')?.log).not.toContain(person.name);
    // 대상 이름이 드는 선택지마다(거두기·털어놓기는 이름 없음)
    const named: Record<string, string[]> = {
      'dark:hostile': ['dark:hostile:let', 'dark:hostile:order'],
      'dark:exec_threat': ['dark:threat:give', 'dark:threat:stand', 'dark:threat:order'],
      'dark:order_exe': ['dark:exe:guard', 'dark:exe:rival', 'dark:exe:bound'],
      'dark:order_method': ['dark:method:accident', 'dark:method:stop', 'dark:method:night'],
    };
    for (const [kind, want] of Object.entries(named)) {
      const view = logged(g, add(g, { kind, who: person.id, text: person.id, comm: person.community }));
      for (const s of want) expect(view.choices.find(c => c.special === s)?.log, `${kind}/${s}`).toContain(person.name);
    }
  });

  it('고르면 그 log가 일지에 그대로 한 줄로 남는다', () => {
    const g = darkGame('choice-log-journal');
    const card = add(g, { kind: 'dark:armory', comm: 'guard' });
    const view = logged(g, card);
    const idx = view.choices.findIndex(c => c.special === 'dark:armory:on');
    expect(chooseCard(g, card.uid, idx)).toBe(true);
    expect(g.journal.map(j => j.text)).toContain(view.choices[idx].log);
    expect(g.journal.some(j => j.text.startsWith('무기고 열쇠:'))).toBe(false);
  });

  it('들킨 죽음과 숨긴 죽음은 각 수습 문구를 남긴다', () => {
    const g = darkGame();
    const who = g.comms.tail.leader.personId;
    const name = nameOf(g, who);
    const seen = logged(g, add(g, { kind: 'dark:order_done', who, text: '실행자가 붙잡혔다.' }));
    expect(seen.choices[0].log).toBe(`${name}의 죽음을 두고 경비대에 입단속을 시켰다.`);
    const hidden = logged(g, add(g, { kind: 'dark:order_done', who, text: 'hidden' }));
    expect(hidden.choices[0].log).toBe(`${name}의 죽음을 보일러 일지에 사고로 적게 했다.`);
  });

  it('죽음 뒤 빈 의석·잠자리·일손과 식은 난로의 모든 선택지에 log가 있다', () => {
    const g = fresh();
    const who = g.comms.tail.leader.name;
    for (const kind of ['loss_rep', 'loss_child', 'loss_hand', 'heat_after']) {
      const view = logged(g, add(g, { kind, comm: 'tail', who, n: 2 }));
      if (kind === 'loss_hand') expect(view.choices[1].log).toBe(`${who}이(가) 하던 일을 그 칸이 나눠 지게 했다.`);
    }
  });

  it('다시 오른 요구와 고칠 길의 다섯 slot에 각각 log가 있다', () => {
    const g = fresh();
    const fixes: Record<DeathSlot, string> = {
      rep: '다음 회기 안건을 이 칸이 고르게 했다.', parent: '남은 아이를 맡은 칸에 배급을 더 줬다.',
      child: '아이들 잠자리 곁 난로에 석탄을 더 줬다.', hand: '빈 손을 메울 사람을 하나 더 먹여 가르치기로 했다.',
      heat: '난방 배당 폐지를 회기에 올리기로 했다.',
    };
    for (const slot of ['rep', 'parent', 'child', 'hand', 'heat'] as const) {
      logged(g, add(g, { kind: 'chain_push', comm: 'tail', text: slot }));
      expect(logged(g, add(g, { kind: 'chain_fix', comm: 'tail', text: slot })).choices[0].log).toBe(fixes[slot]);
    }
  });

  it('눈보라·한파의 모든 대비 선택지와 눈보라 출발 미루기에 log가 있다', () => {
    const wait = DZ.wait;
    try {
      DZ.wait = 1;
      for (const kind of ['blizzard', 'cold'] as const) {
        const g = createGame(`choice-log-${kind}`);
        enableDisasters(g);
        g.seg = 4;
        g.disaster = { kind, stage: 'warn', left: 0 };
        const view = logged(g, add(g, { kind: 'disaster_prep', text: kind }));
        expect(view.choices).toHaveLength(kind === 'blizzard' ? 4 : 3);
      }
    } finally {
      DZ.wait = wait;
    }
  });

  it('ev_b01_*·ev_h* 사건 JSON 46개의 모든 선택지에 log가 있다', () => {
    const dir = new URL('../../data/events/', import.meta.url);
    const files = readdirSync(dir).filter(file => /^ev_(?:b01_|h).*\.json$/.test(file));
    expect(files).toHaveLength(46);
    let n = 0;
    for (const file of files) {
      const event = JSON.parse(readFileSync(new URL(file, dir), 'utf8')) as { choices: { id: string; log?: string }[] };
      expect(event.choices.length, file).toBeGreaterThanOrEqual(2);
      n += event.choices.length;
      for (const choice of event.choices) {
        const at = join(file, choice.id);
        expect(choice.log, at).toBeTypeOf('string');
        expect(choice.log, at).not.toBe('');
      }
    }
    expect(n).toBe(117);
  });
});
