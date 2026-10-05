import { describe, expect, it } from 'vitest';
import {
  PUBLIC_VOTE_FEAR, advance, advanceBlocker, castSessionVote, chooseCard, createApp, restartApp, setBill,
  setCardCollapsed, setDummyFaction, setVoteMode,
} from '../../src/ui/model/app-state';
import type { AppState } from '../../src/ui/model/app-state';
import { DUMMY_BILLS, createDummyRoster } from '../../src/ui/model/dummy';

function step(app: AppState): AppState {
  if (app.card) return chooseCard(app, 0);
  if (app.flow.phase === 'council' && advanceBlocker(app) === 'vote') return castSessionVote(app);
  return advance(app);
}

describe('앱 상태 전이(더미 규칙)', () => {
  it('같은 시드면 같은 시작 상태, 다른 시드면 다른 사람들이다', () => {
    expect(createApp('alpha')).toEqual(createApp('alpha'));
    expect(createApp('alpha').game.rng).not.toEqual(createApp('beta').game.rng);
    expect(createDummyRoster('alpha')).toEqual(createDummyRoster('alpha'));
    expect(createDummyRoster('alpha').profiles).not.toEqual(createDummyRoster('beta').profiles);
    expect(() => createApp('  ')).toThrow();
  });

  it('더미 인구는 200명이고 아이와 노인이 섞여 있다', () => {
    const { persons } = createDummyRoster('ages');
    expect(persons).toHaveLength(200);
    const children = persons.filter(person => (person.age ?? 0) <= 15).length;
    const elders = persons.filter(person => (person.age ?? 0) >= 65).length;
    expect(children).toBeGreaterThan(10);
    expect(elders).toBeGreaterThan(5);
  });

  it('이동과 정차에선 결정 카드가 올라오고, 고르기 전엔 넘어가지 않는다', () => {
    let app = advance(createApp());
    expect(app.flow.phase).toBe('travel');
    expect(app.card).toEqual({ id: 'ev_dummy_tail_stove', collapsed: false });
    expect(advanceBlocker(app)).toBe('card');
    expect(advance(app)).toBe(app);
    app = setCardCollapsed(app, true);
    expect(app.card?.collapsed).toBe(true);
    const coal = app.game.resources.coal;
    app = chooseCard(app, 0);
    expect(app.card).toBeNull();
    expect(app.game.resources.coal).toBe(coal - 8);
    expect(app.game.communities.tail.warmth).toBe(36);
    expect(app.journal.at(-1)?.text).toContain('석탄을 내준다');
    app = advance(app);
    expect(app.flow.phase).toBe('stop');
    expect(app.card?.id).toBe('ev_dummy_freight_stop');
  });

  it('정차에서 사람을 보내면 이름이 일지에 남고, 정산마다 귀환까지 남은 구간이 준다', () => {
    let app = advance(chooseCard(advance(createApp('dispatch')), 2));
    app = chooseCard(app, 0);
    const away = Object.values(app.game.persons).filter(person => person.state === 'away');
    expect(away).toHaveLength(4);
    expect(away.every(person => person.community === 'tail' && person.awaySegments === 2)).toBe(true);
    const names = createDummyRoster('dispatch').profiles;
    for (const person of away) expect(app.journal.at(-1)?.text).toContain(names[person.id].name);
    app = advance(app);
    expect(app.flow.phase).toBe('settle');
    expect(Object.values(app.game.persons).filter(person => person.awaySegments === 1)).toHaveLength(4);
    // 2구간 정차는 통과한다. 2구간 정산에서 돌아온다.
    while (!(app.flow.segment === 2 && app.flow.phase === 'stop')) app = step(app);
    app = chooseCard(app, 1);
    app = advance(app);
    expect(Object.values(app.game.persons).filter(person => person.state === 'away')).toHaveLength(0);
    expect(app.journal.at(-1)?.text).toContain('돌아왔다');
  });

  it('의회는 3구간에 열리고, 표결 전엔 넘어가지 않으며 표결은 한 번이다', () => {
    let app = createApp('council');
    while (app.flow.phase !== 'council') {
      expect(app.flow.segment).toBeLessThanOrEqual(3);
      app = app.card ? chooseCard(app, 1) : advance(app);
    }
    expect(app.flow.segment).toBe(3);
    expect(advanceBlocker(app)).toBe('vote');
    const fear = app.game.fear;
    const voted = castSessionVote(app);
    expect(voted.sessionVote).toMatchObject({ segment: 3, mode: 'public' });
    expect(voted.game.rng).not.toEqual(app.game.rng);
    expect(voted.game.fear).toBe(fear + PUBLIC_VOTE_FEAR);
    expect(castSessionVote(voted)).toBe(voted);
    expect(setBill(voted, DUMMY_BILLS[1].law.id)).toBe(voted);
    expect(advanceBlocker(voted)).toBeNull();
    expect(advance(voted).flow).toEqual({ segment: 3, phase: 'settle', ended: false });
  });

  it('비밀 투표는 공포를 올리지 않는다(더미 규칙)', () => {
    let app = setVoteMode(createApp('secret'), 'secret');
    while (app.flow.phase !== 'council') app = app.card ? chooseCard(app, 1) : advance(app);
    const voted = castSessionVote(app);
    expect(voted.game.fear).toBe(app.game.fear);
    expect(voted.journal.at(-1)?.text).toContain('비밀 투표');
  });

  it('한 판은 24구간에서 끝난다', () => {
    let app = createApp('full-run');
    for (let index = 0; index < 400 && !app.flow.ended; index += 1) app = step(app);
    expect(app.flow).toEqual({ segment: 24, phase: 'settle', ended: true });
    expect(advanceBlocker(app)).toBe('ended');
    expect(app.journal.filter(entry => entry.text.includes('회기가 열렸다'))).toHaveLength(8);
  });

  it('처음부터는 같은 시드와 설정으로 다시 시작한다', () => {
    let app = setDummyFaction(createApp('again'), true);
    for (let index = 0; index < 12; index += 1) app = step(app);
    const fresh = restartApp(app);
    expect(fresh.seed).toBe('again');
    expect(fresh.flow).toEqual({ segment: 1, phase: 'prep', ended: false });
    expect(fresh.dummyFaction).toBe(true);
    expect(fresh.game).toEqual(createApp('again', app.flags, true).game);
  });
});
