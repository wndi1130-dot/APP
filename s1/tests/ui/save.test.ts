import { describe, expect, it } from 'vitest';
import { buildCouncilGroups, resolveCouncilVote } from '../../src/core';
import {
  advance, advanceBlocker, castSessionVote, chooseCard, createApp, setDummyFaction, setVoteMode,
} from '../../src/ui/model/app-state';
import type { AppState } from '../../src/ui/model/app-state';
import { toggleFlag } from '../../src/ui/model/flags';
import {
  MemoryStorage, SAVE_KEY, clearSave, loadApp, parseSave, peekSave, saveApp, serializeApp,
} from '../../src/ui/model/save';
import type { StorageLike } from '../../src/ui/model/save';

function playTo(app: AppState, segment: number, phase: AppState['flow']['phase']): AppState {
  let next = app;
  for (let step = 0; step < 200; step += 1) {
    if (next.flow.segment === segment && next.flow.phase === phase) return next;
    if (next.card) next = chooseCard(next, 0);
    else if (advanceBlocker(next) === 'vote') next = castSessionVote(next);
    else next = advance(next);
  }
  throw new Error('목표 단계에 닿지 못했다');
}

class ThrowingStorage implements StorageLike {
  getItem(): string | null { throw new DOMException('blocked', 'SecurityError'); }
  setItem(): void { throw new DOMException('full', 'QuotaExceededError'); }
  removeItem(): void { throw new DOMException('blocked', 'SecurityError'); }
}

describe('저장 한 슬롯', () => {
  it('시드를 포함해 저장하고 그대로 되살린다', () => {
    const storage = new MemoryStorage();
    let app = playTo(createApp('round-trip-seed'), 3, 'council');
    app = setVoteMode(app, 'secret');
    app = { ...app, flags: toggleFlag(app.flags, 'S1c') };
    const saved = saveApp(storage, app, 1_700_000_000_000);
    expect(saved).toEqual({
      ok: true,
      value: { seed: 'round-trip-seed', segment: 3, phase: 'council', ended: false, savedAt: 1_700_000_000_000 },
    });
    const loaded = loadApp(storage);
    expect(loaded.ok).toBe(true);
    if (!loaded.ok) return;
    expect(loaded.value.app).toEqual(app);
    expect(loaded.value.app.seed).toBe('round-trip-seed');
    expect(loaded.value.app.game.rng).toEqual(app.game.rng);
    expect(loaded.value.summary.savedAt).toBe(1_700_000_000_000);
  });

  it('불러온 판은 같은 난수로 이어 간다: 저장 전과 같은 표결 결과가 나온다', () => {
    const storage = new MemoryStorage();
    const app = playTo(createApp('same-future'), 6, 'council');
    saveApp(storage, app);
    const loaded = loadApp(storage);
    if (!loaded.ok) throw new Error(loaded.message);
    const direct = castSessionVote(app);
    const resumed = castSessionVote(loaded.value.app);
    expect(resumed.sessionVote).toEqual(direct.sessionVote);
    expect(resumed.game).toEqual(direct.game);
    const vote = (state: AppState) => resolveCouncilVote(buildCouncilGroups(state.game), {
      kind: 'normal', mode: 'public', rng: state.game.rng,
    });
    expect(vote(resumed)).toEqual(vote(direct));
  });

  it('더미 세력과 파견 상태도 그대로 남는다', () => {
    const storage = new MemoryStorage();
    const app = setDummyFaction(playTo(createApp('faction-seed'), 2, 'settle'), true);
    expect(Object.values(app.game.persons).some(person => person.state === 'away')).toBe(true);
    saveApp(storage, app);
    const loaded = loadApp(storage);
    expect(loaded.ok && loaded.value.app).toEqual(app);
  });

  it('비어 있거나 깨진 저장본은 오류로 알린다', () => {
    const storage = new MemoryStorage();
    expect(loadApp(storage)).toMatchObject({ ok: false, error: 'empty' });
    storage.setItem(SAVE_KEY, '{not json');
    expect(loadApp(storage)).toMatchObject({ ok: false, error: 'corrupt' });
    const app = createApp();
    const envelope = JSON.parse(serializeApp(app, 1));
    storage.setItem(SAVE_KEY, JSON.stringify({ ...envelope, version: 99 }));
    expect(loadApp(storage)).toMatchObject({ ok: false, error: 'corrupt' });
    const brokenRng = { ...envelope, app: { ...envelope.app, game: { ...envelope.app.game, rng: { algorithm: 'other', state: 1 } } } };
    storage.setItem(SAVE_KEY, JSON.stringify(brokenRng));
    expect(loadApp(storage)).toMatchObject({ ok: false, error: 'corrupt' });
    const emptySeed = { ...envelope, app: { ...envelope.app, seed: ' ' } };
    expect(() => parseSave(JSON.stringify(emptySeed))).toThrow();
    const badFlow = { ...envelope, app: { ...envelope.app, flow: { segment: 4, phase: 'council', ended: false } } };
    expect(() => parseSave(JSON.stringify(badFlow))).toThrow();
    const ghostMember = structuredClone(envelope);
    ghostMember.app.game.groups.tail.members.push('p_nobody');
    expect(() => parseSave(JSON.stringify(ghostMember))).toThrow();
  });

  it('플래그 값은 정리해서 읽는다', () => {
    const app = createApp();
    const envelope = JSON.parse(serializeApp(app, 1));
    envelope.app.flags = { S1a: 'on', S1b: true, S9: true };
    expect(parseSave(JSON.stringify(envelope)).app.flags).toEqual({ S1a: true, S1b: true, S1c: false });
  });

  it('저장소가 없거나 예외를 던져도 앱은 멈추지 않는다', () => {
    const app = createApp();
    expect(saveApp(null, app)).toMatchObject({ ok: false, error: 'unavailable' });
    expect(loadApp(null)).toMatchObject({ ok: false, error: 'unavailable' });
    const throwing = new ThrowingStorage();
    expect(saveApp(throwing, app)).toMatchObject({ ok: false, error: 'write_failed' });
    expect(loadApp(throwing)).toMatchObject({ ok: false, error: 'unavailable' });
    expect(clearSave(throwing)).toMatchObject({ ok: false, error: 'write_failed' });
  });

  it('지우면 다시 비어 있다', () => {
    const storage = new MemoryStorage();
    saveApp(storage, createApp('to-clear'));
    expect(peekSave(storage)).toMatchObject({ ok: true, value: { seed: 'to-clear', segment: 1, phase: 'prep' } });
    expect(clearSave(storage)).toEqual({ ok: true, value: null });
    expect(peekSave(storage)).toMatchObject({ ok: false, error: 'empty' });
  });
});
