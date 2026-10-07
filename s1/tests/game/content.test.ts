import { afterEach, describe, expect, it } from 'vitest';
import {
  CONTENT_EVENTS, addContentCard, chooseCard, contentFollowupTick, contentPool, createGame, fillText, josa, registerContentEvents, viewCard,
} from '../../src/game';
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

afterEach(() => { CONTENT_EVENTS.length = 0; });

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
    const name = card.names![0];
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

describe('data/events', () => {
  const list = readContentEvents() as { id: string; choices: { followups: string[]; effects: { type: string; id?: string }[] }[] }[];
  it.skipIf(list.length === 0)('검사기를 통과하고 후속 id가 모두 있다', async () => {
    expect((await validateFolder(EVENTS_DIR)).diagnostics.filter(d => d.severity === 'error')).toEqual([]);
    const ids = new Set(list.map(e => e.id));
    const refs = list.flatMap(e => e.choices.flatMap(c => [...c.followups, ...c.effects.filter(x => x.type === 'followup').map(x => x.id!)]));
    expect(refs.filter(r => !ids.has(r))).toEqual([]);
  });
});
