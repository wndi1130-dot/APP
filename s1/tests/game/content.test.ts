import { afterEach, describe, expect, it } from 'vitest';
import {
  COMMS, COMM_NAME, CONTENT_DEALS, CONTENT_EVENTS, CONTENT_SECRETS, PROFILES, addContentCard, blocs, castVote, chooseCard, contentFollowupTick, contentPool,
  createGame, fillText, josa, openCouncil, registerContentDeals, registerContentEvents, registerContentSecrets, viewCard, voteSide,
} from '../../src/game';
import type { Game } from '../../src/game';
import { validateFolder } from '../../tools/validate';
import { EVENTS_DIR, readContentEvents } from '../../tools/content_fs';

// 콘텐츠 JSON 사건 읽는 길(content.ts).

const ev = (over: Record<string, unknown> = {}) => ({
  id: 'ev_test_stove', stage: 's1a', phase: 'travel', trigger: [{ type: 'segment', min: 1, max: 30 }], speaker: 'tail',
  body: '{person}[이/가] 꺼진 난로 앞에 앉아 있다. {community}[은/는] 기다린다.', params: ['person', 'community'], repeat: 0,
  choices: [
    { id: 'c_share', label: '석탄을 나눈다', say: '{person}, 이걸로 버텨.', effects: [{ type: 'coal', amount: -2 }, { type: 'flag', id: 'stove_shared', value: true }, { type: 'followup', id: 'ev_test_after', delay: 2 }], followups: [], witnesses: [] },
    { id: 'c_wait', label: '기다리게 한다', effects: [{ type: 'relation', target: 'tail', amount: -3 }], followups: [], witnesses: ['p_001'] },
  ],
  ...over,
});
const after = { ...ev(), id: 'ev_test_after', trigger: [{ type: 'flag', id: 'stove_shared', value: true }], body: '난로가 다시 붙었다.', params: [], choices: ev().choices.map(c => ({ ...c, effects: [], say: undefined })) };

afterEach(() => { CONTENT_EVENTS.length = 0; CONTENT_SECRETS.length = 0; CONTENT_DEALS.length = 0; });

describe('조사 고르기', () => {
  it.each([
    ['경비대', '이/가', '가'], ['기관실', '이/가', '이'], ['파블라', '을/를', '를'], ['꼬리칸', '은/는', '은'],
    ['서울', '으로/로', '로'], ['역', '으로/로', '으로'], ['역사', '으로/로', '로'], ['3', '이/가', '이'], ['2', '이/가', '가'], ['7', '으로/로', '로'],
  ])('%s[%s] → %s', (word, pair, out) => expect(josa(word, pair)).toBe(out));
  it('값이 없는 자리표시자는 그대로 둔다', () => {
    expect(fillText('{person}[이/가] {n}명을 데려왔다.', { person: '야나' })).toBe('야나가 {n}명을 데려왔다.');
  });
});

describe('콘텐츠 사건', () => {
  it('조건이 맞으면 풀에 들고, 카드는 이름과 조사를 채워 보인다', () => {
    registerContentEvents([ev(), after]);
    const g = createGame('content-1');
    expect(contentPool(g).map(e => e.id)).toEqual(['ev_test_stove']);
    addContentCard(g, 'ev_test_stove');
    const card = g.cards[g.cards.length - 1];
    const view = viewCard(g, card);
    const name = card.vals!.person;
    expect(view.body).toBe(`${name}${josa(name, '이/가')} 꺼진 난로 앞에 앉아 있다. 꼬리칸은 기다린다.`);
    expect(view.choices[0].say).toBe(`${name}, 이걸로 버텨.`);
    expect(view.choices[1].witness).toBe(true);
  });

  it('고르면 효과·깃발·미룬 후속이 돈다', () => {
    registerContentEvents([ev(), after]);
    const g = createGame('content-2');
    g.cards = [];
    addContentCard(g, 'ev_test_stove');
    const coal = g.coal;
    expect(chooseCard(g, g.cards[0].uid, 0)).toBe(true);
    expect(g.coal).toBe(coal - 2);
    expect(g.contentFlags?.stove_shared).toBe(true);
    expect(g.contentQueue).toEqual([{ id: 'ev_test_after', at: g.seg + 2 }]);
    contentFollowupTick(g);
    expect(g.cards).toEqual([]);
    g.seg += 2;
    contentFollowupTick(g);
    expect(g.cards.map(c => c.text)).toEqual(['ev_test_after']);
    // 한 번 고른 사건은 repeat 0이라 다시 안 뽑힌다.
    g.seg += 10;
    expect(contentPool(g).map(e => e.id)).not.toContain('ev_test_stove');
  });

  it('미룬 후속은 들어올 때 자기 조건을 다시 보고, 깨졌으면 올리지 않는다', () => {
    registerContentEvents([ev(), after]);
    const g = createGame('content-2b');
    g.cards = [];
    addContentCard(g, 'ev_test_stove');
    chooseCard(g, g.cards[0].uid, 0);
    g.seg += 2;
    g.contentFlags!.stove_shared = false;
    contentFollowupTick(g);
    expect(g.cards).toEqual([]);
    expect(g.contentQueue).toEqual([]);
  });

  it('값을 댈 수 없는 자리표시자(n)를 쓰는 사건은 안 뽑는다', () => {
    registerContentEvents([ev({ id: 'ev_test_count', body: '석탄 {n}포대가 남았다.', params: ['n'] })]);
    expect(contentPool(createGame('content-3'))).toEqual([]);
  });

  it('구간 진행에서도 뽑힌다', async () => {
    registerContentEvents([ev()]);
    const { playGame } = await import('../../tools/s1c_bot');
    const seen = Array.from({ length: 30 }, (_, i) => playGame(`content-play-${i}`, { s1c: false, policy: 'caretaker', dom: 'idle' }).g)
      .filter(g => g.eventLog['content:ev_test_stove']).length;
    expect(seen).toBeGreaterThan(0);
  }, 60_000);
});

// 6.9: 자리표시자 묶기, 대표·측근의 공동체, 효과 넷
const one = (effects: unknown[], over: Record<string, unknown> = {}) => ev({
  id: 'ev_test_one', body: '{person}[이/가] 다가온다.', params: ['person'],
  choices: [
    { id: 'c_yes', label: '받는다', effects, followups: [], witnesses: ['p_001'] },
    { id: 'c_no', label: '돌려보낸다', effects: [], followups: [], witnesses: [] },
  ],
  ...over,
});
const draw = (g: Game, id = 'ev_test_one') => { g.cards = []; expect(addContentCard(g, id)).toBe(true); return g.cards[0]; };

describe('자리표시자 묶기(6.9)', () => {
  it('bind로 n에 남은 석탄을 댄다', () => {
    registerContentEvents([ev({ id: 'ev_test_count', body: '석탄 {n}포대가 남았다.', params: ['n'], bind: { n: 'coal_left' } })]);
    const g = createGame('bind-n');
    const card = draw(g, 'ev_test_count');
    expect(viewCard(g, card).body).toBe(`석탄 ${Math.round(g.coal)}포대가 남았다.`);
  });

  it('person과 person2는 다른 사람이고, 대표는 빠진다', () => {
    registerContentEvents([ev({ id: 'ev_test_two', body: '{person}[과/와] {person2}[이/가] 다툰다.', params: ['person', 'person2'] })]);
    for (let i = 0; i < 10; i += 1) {
      const g = createGame(`bind-two-${i}`);
      const { person, person2 } = draw(g, 'ev_test_two').vals!;
      expect(person).not.toBe(person2);
      expect([person, person2]).not.toContain(g.comms.tail.leader.name);
    }
  });

  it('car는 그 칸이 사는 객차 이름, community는 말하는 칸', () => {
    registerContentEvents([ev({ id: 'ev_test_car', body: '{car}에서 {community}[이/가] 떤다.', params: ['car', 'community'], bind: { car: 'car:medtech' }, speaker: 'medtech' })]);
    const g = createGame('bind-car');
    const name = COMM_NAME.medtech;
    expect(viewCard(g, draw(g, 'ev_test_car')).body).toBe(`의무칸에서 ${name}${josa(name, '이/가')} 떤다.`);
  });

  it('car·n에 bind가 없거나 못 대는 값이면 안 뽑는다', () => {
    registerContentEvents([
      ev({ id: 'ev_test_nocar', body: '{car}.', params: ['car'] }),
      ev({ id: 'ev_test_next', body: '{place}.', params: ['place'], bind: { place: 'next_stop' } }),
    ]);
    expect(contentPool(createGame('bind-none'))).toEqual([]);
  });

  it('대표 사건은 community 칸의 대표가 말하고, any면 칸 하나를 고른다', () => {
    registerContentEvents([ev({ id: 'ev_test_rep', speaker: 'rep', community: 'guard' }), ev({ id: 'ev_test_any', speaker: 'rep', community: 'any' })]);
    const g = createGame('rep');
    const v = viewCard(g, draw(g, 'ev_test_rep'));
    expect(v.speaker?.name).toBe(g.comms.guard.leader.name);
    expect(v.title).toBe(COMM_NAME.guard);
    const any = draw(g, 'ev_test_any');
    expect(COMMS).toContain(any.comm);
    expect(PROFILES.find(p => p.name === any.vals!.person)?.community).toBe(any.comm);
  });

  it('측근은 그 칸의 대표 아닌 사람이 말한다', () => {
    registerContentEvents([ev({ id: 'ev_test_aide', speaker: 'aide', community: 'front' })]);
    const g = createGame('aide');
    const card = draw(g, 'ev_test_aide');
    const v = viewCard(g, card);
    expect(v.speaker?.name).toBe(card.vals!['@aide']);
    expect(v.speaker?.name).not.toBe(g.comms.front.leader.name);
    expect(PROFILES.find(p => p.name === v.speaker?.name)?.community).toBe('front');
  });

  it('세력 지도자 사건은 S1a에서 안 뽑는다', () => {
    registerContentEvents([ev({ id: 'ev_test_faction', speaker: 'faction_leader', faction: 'f_order' })]);
    expect(contentPool(createGame('faction'))).toEqual([]);
  });

  it('희생양 자리는 처지로 켠 표시가 있는 사람만 뽑는다', () => {
    registerContentEvents([ev({ id: 'ev_test_goat', bind: { person: 'scapegoat' } })]);
    const g = createGame('goat');
    expect(contentPool(g)).toEqual([]);
    const who = PROFILES.find(p => p.community === 'front' && p.name !== g.comms.front.leader.name)!;
    g.scapegoatOk = [who.id];
    expect(draw(g, 'ev_test_goat').vals!.person).toBe(who.name);
  });
});

describe('효과 넷(6.9)', () => {
  const secret = { id: 'sec_test', kind: 'lie', severity: 3, proof: 'rumor', sources: ['surveillance'], text: '{person}[은/는] 배급표를 두 장 쥐고 있다.' };

  it('secret: 정의가 없으면 안 뽑고, 있으면 쥔 사람과 단계를 남기고 높은 단계로만 오른다', () => {
    registerContentEvents([one([{ type: 'secret', id: 'sec_test', amount: 1 }]), one([{ type: 'secret', id: 'sec_test', amount: 2 }], { id: 'ev_test_proof' })]);
    const g = createGame('secret');
    expect(contentPool(g)).toEqual([]);
    registerContentSecrets([secret]);
    const card = draw(g);
    chooseCard(g, card.uid, 0);
    const who = card.vals!.person;
    expect(g.contentSecrets?.sec_test).toEqual({ level: 1, who, comm: 'tail' });
    const s = g.secrets.find(x => x.cid === 'sec_test')!;
    // 협박 무게는 정의의 severity, 소문·증거는 따로 센다.
    expect(s).toMatchObject({ about: 'tail', weight: 3, proof: 1 });
    expect(s.text).toBe(`${who}${josa(who, '은/는')} 배급표를 두 장 쥐고 있다.`);
    chooseCard(g, draw(g, 'ev_test_proof').uid, 0);
    expect(g.contentSecrets?.sec_test.level).toBe(2);
    expect(g.secrets.filter(x => x.cid === 'sec_test').map(x => [x.weight, x.proof])).toEqual([[3, 2]]);
    chooseCard(g, draw(g).uid, 0);
    expect(g.contentSecrets?.sec_test.level).toBe(2);
  });

  it('secret: 정의의 proof가 evidence면 amount 1이어도 증거로 쥔다', () => {
    registerContentSecrets([{ ...secret, proof: 'evidence' }]);
    registerContentEvents([one([{ type: 'secret', id: 'sec_test', amount: 1 }])]);
    const g = createGame('secret-proof');
    chooseCard(g, draw(g).uid, 0);
    expect(g.contentSecrets?.sec_test.level).toBe(2);
  });

  it('votes: 다음 표결 한 번에만 그 칸 표가 옮긴다', () => {
    registerContentEvents([one([{ type: 'votes', target: 'guard', amount: 3 }])]);
    const g = createGame('votes');
    chooseCard(g, draw(g).uid, 0);
    expect(g.voteShift).toEqual([{ comm: 'guard', n: 3, side: 'captain' }]);
    openCouncil(g);
    const agenda = g.council!.options[g.council!.idx];
    expect(agenda.by).toBeUndefined();
    const shifted = blocs(g, agenda).guard;
    const plain = blocs({ ...g, voteShift: undefined }, agenda).guard;
    expect(shifted.yes).toBe(Math.min(plain.yes + 3, plain.yes + plain.no + plain.und));
    expect(shifted.yes + shifted.no + shifted.und).toBe(plain.yes + plain.no + plain.und);
    castVote(g);
    expect(g.voteShift).toBeUndefined();
  });

  it('votes 쪽: captain은 열차장이 올린 안건만 찬성, AI 발의엔 효과 없음, yes·no는 그대로', () => {
    expect([voteSide({ law: 'common_kitchen', repeal: false }, 'captain'), voteSide({ law: 'common_kitchen', repeal: false, by: 'tail' }, 'captain')]).toEqual([1, 0]);
    expect([voteSide({ law: 'common_kitchen', repeal: false, by: 'tail' }, 'yes'), voteSide({ law: 'common_kitchen', repeal: false }, 'no')]).toEqual([1, -1]);
    const g = createGame('votes-no');
    openCouncil(g);
    const agenda = g.council!.options[g.council!.idx];
    const plain = blocs(g, agenda).guard;
    g.voteShift = [{ comm: 'guard', n: 2, side: 'no' }];
    const pushed = blocs(g, agenda).guard;
    expect(pushed.no).toBe(Math.min(plain.no + 2, plain.yes + plain.no + plain.und));
  });

  it('deal: 받으면 주는 것이 오고, 기한에 치르거나 못 치르면 어긴 값이 온다', () => {
    registerContentDeals([{
      id: 'deal_test', tool: 'open', from: 'engine', deadline: 2, arc_tags: [], say: '석탄을 먼저 내줘. 식량은 나중에 받겠다.',
      ask: [{ type: 'food', amount: -15 }], gives: [{ type: 'coal', amount: 10 }], breach: [{ type: 'relation', target: 'engine', amount: -10 }],
    }]);
    registerContentEvents([one([{ type: 'deal', id: 'deal_test' }])]);
    for (const pay of [true, false]) {
      const g = createGame(`deal-${pay}`);
      chooseCard(g, draw(g).uid, 0);
      const deal = g.cards[0];
      expect(deal.kind).toBe('content-deal');
      const v = viewCard(g, deal);
      expect(v.speaker?.name).toBe(g.comms.engine.leader.name);
      expect(v.body.startsWith('석탄을 먼저 내줘. 식량은 나중에 받겠다.')).toBe(true);
      expect(v.body).toContain('식량 −15');
      const coal = g.coal;
      chooseCard(g, deal.uid, 0);
      expect(g.coal).toBe(coal + 10);
      expect(g.contentDeals).toEqual([{ id: 'deal_test', comm: 'engine', due: g.seg + 2 }]);
      g.seg += 2;
      if (!pay) g.food = 5;
      const food = g.food;
      const rel = g.comms.engine.rel;
      contentFollowupTick(g);
      expect(g.contentDeals).toEqual([]);
      if (pay) expect(g.food).toBe(food - 15); else expect([g.food, g.comms.engine.rel]).toEqual([food, rel - 10]);
    }
  });

  it('chronicle: 틀, 누가, 언제, 목격자를 남긴다', () => {
    registerContentEvents([one([{ type: 'chronicle', id: 'chr_test' }])]);
    const g = createGame('chronicle');
    const card = draw(g);
    chooseCard(g, card.uid, 0);
    expect(g.chronicle).toEqual([{ template: 'chr_test', who: card.vals!.person, where: '', when: g.seg, witnesses: ['p_001'], from: 'ev_test_one.c_yes' }]);
  });

  it('모자라는 비용의 선택지는 막힌다', () => {
    registerContentEvents([one([{ type: 'coal', amount: -9999 }])]);
    const g = createGame('afford');
    expect(viewCard(g, draw(g)).choices[0].disabled).toBeTruthy();
  });
});

describe('모든 선택지가 모자랄 때', () => {
  it('막지 않고 고를 수 있게 둔다(카드에 갇히지 않는다)', () => {
    registerContentEvents([ev({
      id: 'ev_test_broke', body: '다 모자란다.', params: [], speaker: 'engine',
      choices: [
        { id: 'c_a', label: '가', effects: [{ type: 'coal', amount: -9999 }], followups: [], witnesses: [] },
        { id: 'c_b', label: '나', effects: [{ type: 'food', amount: -9999 }], followups: [], witnesses: [] },
      ],
    })]);
    const g = createGame('all-short');
    g.cards = [];
    addContentCard(g, 'ev_test_broke');
    expect(viewCard(g, g.cards[0]).choices.map(c => !!c.disabled)).toEqual([false, false]);
    expect(chooseCard(g, g.cards[0].uid, 0)).toBe(true);
  });
});

describe('자원 조건과 선택지 requires', () => {
  const eff = [{ type: 'tension', amount: 1 }];
  const pick = (over: Record<string, unknown>, ...rest: Record<string, unknown>[]) => ev({
    id: 'ev_test_res', body: '자원을 본다.', params: [], speaker: 'engine',
    choices: [
      { id: 'c_a', label: '가', effects: eff, followups: [], witnesses: [], ...over },
      { id: 'c_b', label: '나', effects: eff, followups: [], witnesses: [] },
      ...rest,
    ],
  });

  it.each([
    ['coal', 'lte', 40, 'coal', 40, true], ['coal', 'lte', 40, 'coal', 41, false], ['coal', 'gte', 3, 'coal', 2, false], ['coal', 'gte', 3, 'coal', 3, true],
    ['food', 'lte', 5, 'food', 5, true], ['medicine', 'gte', 8, 'med', 7, false], ['medicine', 'lte', 10, 'med', 10, true], ['luxury', 'gte', 5, 'lux', 4, false],
    ['symbol', 'gte', 1, 'symbols', 0, false], ['symbol', 'gte', 1, 'symbols', 1, true],
  ] as const)('트리거 resource %s %s %s: 창고 %s=%s이면 %s', (resource, operator, value, key, have, expected) => {
    registerContentEvents([ev({ id: 'ev_test_res', body: '자원을 본다.', params: [], speaker: 'engine', trigger: [{ type: 'resource', resource, operator, value }] })]);
    const g = createGame('res-cond');
    (g as unknown as Record<string, number>)[key] = have;
    expect(contentPool(g).map(e => e.id)).toEqual(expected ? ['ev_test_res'] : []);
  });

  it('requires가 모자라면 선택지를 숨기고 맞으면 보인다', () => {
    registerContentEvents([pick({ requires: [{ type: 'resource', resource: 'medicine', operator: 'gte', value: 8 }] })]);
    const g = createGame('res-req');
    g.cards = [];
    g.med = 7;
    addContentCard(g, 'ev_test_res');
    expect(viewCard(g, g.cards[0]).choices.map(c => c.label)).toEqual(['나']);
    g.med = 8;
    expect(viewCard(g, g.cards[0]).choices.map(c => c.label)).toEqual(['가', '나']);
  });

  it('숨긴 칸 뒤의 선택지도 제 효과로 돈다', () => {
    registerContentEvents([pick({ requires: [{ type: 'resource', resource: 'symbol', operator: 'gte', value: 1 }], effects: [{ type: 'coal', amount: -2 }] })]);
    const g = createGame('res-pick');
    g.cards = [];
    g.symbols = 0;
    addContentCard(g, 'ev_test_res');
    const coal = g.coal;
    const t = g.tension;
    expect(chooseCard(g, g.cards[0].uid, 0)).toBe(true);
    expect(g.coal).toBe(coal); // 숨은 '가'(석탄 −2)가 아니라 보이는 첫 칸 '나'가 돈다
    expect(g.tension).toBe(t + 1);
  });

  it('모든 선택지가 숨어야 하면 숨기지 않는다', () => {
    const need = [{ type: 'resource', resource: 'symbol', operator: 'gte', value: 9 }];
    registerContentEvents([ev({
      id: 'ev_test_res', body: '자원을 본다.', params: [], speaker: 'engine',
      choices: [
        { id: 'c_a', label: '가', requires: need, effects: eff, followups: [], witnesses: [] },
        { id: 'c_b', label: '나', requires: need, effects: eff, followups: [], witnesses: [] },
      ],
    })]);
    const g = createGame('res-all');
    g.cards = [];
    addContentCard(g, 'ev_test_res');
    expect(viewCard(g, g.cards[0]).choices.map(c => c.label)).toEqual(['가', '나']);
  });

  it('person.away의 leader_<칸>은 그 칸의 지금 대표를 보낸다', () => {
    registerContentEvents([pick({ effects: [{ type: 'person.away', target: 'leader_medtech', segments: 2 }] })]);
    const g = createGame('res-away');
    g.cards = [];
    addContentCard(g, 'ev_test_res');
    expect(chooseCard(g, g.cards[0].uid, 0)).toBe(true);
    expect(g.contentAway?.[g.comms.medtech.leader.personId]).toBe(g.seg + 2);
  });
});

describe('data/events', () => {
  const list = readContentEvents() as { id: string; choices: { followups: string[]; effects: { type: string; id?: string }[] }[] }[];
  it.skipIf(list.length === 0)('검사기를 통과하고 후속 id가 모두 있다', async () => {
    expect((await validateFolder(EVENTS_DIR)).diagnostics.filter(d => d.severity === 'error')).toEqual([]);
    const ids = new Set(list.map(e => e.id));
    const refs = list.flatMap(e => e.choices.flatMap(c => [...c.followups, ...c.effects.filter(x => x.type === 'followup').map(x => x.id!)]));
    expect(refs.filter(r => !ids.has(r))).toEqual([]);
  });
});
