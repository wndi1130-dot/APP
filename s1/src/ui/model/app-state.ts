import { applyEffects, buildCouncilGroups } from '../../core';
import type { CouncilGroup, Effect, GameState, RngState, VoteMode } from '../../core';
import { createFlow, isCouncilSegment, nextFlow } from './flow';
import type { FlowState, Phase } from './flow';
import { DEFAULT_FLAGS } from './flags';
import type { FeatureFlags } from './flags';
import {
  DEFAULT_SEED, DUMMY_BILLS, billById, cardById, cardForPhase, createDummyGame, createDummyRoster,
  dispatchCandidates, withDummyFaction,
} from './dummy';
import { councilInputs, runCouncilVote } from './council-view';
import { GROUP_META } from './groups';
import { effectSummary } from './format';

// 화면 뼈대의 앱 상태와 상태 전이. 모두 순수 함수다(입력 상태를 바꾸지 않는다).
// 게임 규칙은 더미다. 효과 적용과 표결은 A2 core를 거친다.

export const APP_VERSION = 1;

export interface JournalEntry {
  segment: number;
  phase: Phase;
  text: string;
}

export interface PendingCard {
  id: string;
  collapsed: boolean;
}

export interface SessionVote {
  segment: number;
  billId: string;
  /** 실제로 치른 방식. 화면의 공개·비밀 전환과 별개로 일지에 남는다. */
  mode: VoteMode;
  /** 표결 직전의 집단과 난수 상태. 같은 값으로 다시 풀면 같은 결과다. */
  inputs: CouncilGroup[];
  rng: RngState;
  passed: boolean;
  yes: number;
}

export interface AppState {
  version: typeof APP_VERSION;
  seed: string;
  flags: FeatureFlags;
  dummyFaction: boolean;
  flow: FlowState;
  game: GameState;
  journal: JournalEntry[];
  card: PendingCard | null;
  /** 이번 구간에 처리한 카드 id. 다음 구간이 되면 비운다. */
  cardsDone: string[];
  voteMode: VoteMode;
  billId: string;
  sessionVote: SessionVote | null;
}

export type AdvanceBlocker = 'card' | 'vote' | 'ended';

/** 더미 규칙: 정산마다 드는 자원. */
export const DUMMY_SETTLE_EFFECTS: readonly Effect[] = Object.freeze([
  { type: 'coal', amount: -6 },
  { type: 'food', amount: -5 },
]);

/** 더미 규칙: 공개 투표는 공포를 올린다(기획서 4장). 크기는 임시. */
export const PUBLIC_VOTE_FEAR = 2;

export function createApp(seed: string = DEFAULT_SEED, flags: FeatureFlags = DEFAULT_FLAGS, dummyFaction = false): AppState {
  if (typeof seed !== 'string' || seed.trim().length === 0) throw new TypeError('시드는 빈 문자열일 수 없습니다.');
  return {
    version: APP_VERSION,
    seed,
    flags,
    dummyFaction,
    flow: createFlow(),
    game: createDummyGame(seed, dummyFaction),
    journal: [
      { segment: 1, phase: 'prep', text: '볼슈틴 차고를 떠났다. 여섯 번째 겨울, 200명이 탔다.' },
      { segment: 1, phase: 'prep', text: '기관실이 석탄 배분을 다시 따지자고 했다.' },
    ],
    card: null,
    cardsDone: [],
    voteMode: 'public',
    billId: DUMMY_BILLS[0].law.id,
    sessionVote: null,
  };
}

/** 같은 시드와 설정으로 처음부터 다시 시작한다. */
export function restartApp(app: AppState): AppState {
  return createApp(app.seed, app.flags, app.dummyFaction);
}

function log(app: AppState, text: string): AppState {
  return { ...app, journal: [...app.journal, { segment: app.flow.segment, phase: app.flow.phase, text }] };
}

export function hasSessionVote(app: AppState): boolean {
  return app.sessionVote !== null && app.sessionVote.segment === app.flow.segment;
}

export function advanceBlocker(app: AppState): AdvanceBlocker | null {
  if (app.flow.ended) return 'ended';
  if (app.card !== null) return 'card';
  if (app.flow.phase === 'council' && !hasSessionVote(app)) return 'vote';
  return null;
}

/** 파견 중인 사람의 남은 구간을 하나 줄인다. 0이 되면 A2의 person.away 규칙대로 돌아온다. */
function tickAway(game: GameState): { game: GameState; returned: string[] } {
  const effects: Effect[] = [];
  const returned: string[] = [];
  for (const person of Object.values(game.persons)) {
    if (person.state !== 'away') continue;
    const segments = Math.max(0, person.awaySegments - 1);
    effects.push({ type: 'person.away', target: person.id, segments });
    if (segments === 0) returned.push(person.id);
  }
  return { game: effects.length === 0 ? game : applyEffects(game, effects), returned };
}

function enterPhase(app: AppState): AppState {
  const { phase, segment } = app.flow;
  switch (phase) {
    case 'prep':
      return app;
    case 'travel':
    case 'stop': {
      const card = cardForPhase(phase);
      if (!card || app.cardsDone.includes(card.event.id)) return app;
      return { ...app, card: { id: card.event.id, collapsed: false } };
    }
    case 'council':
      return log(app, `회기가 열렸다. 안건은 ${billById(app.billId).title}.`);
    case 'settle': {
      let game = applyEffects(app.game, DUMMY_SETTLE_EFFECTS);
      const tick = tickAway(game);
      game = tick.game;
      let next = log({ ...app, game }, `정산: ${effectSummary(DUMMY_SETTLE_EFFECTS).join(', ')}.`);
      if (tick.returned.length > 0) next = log(next, `파견 나갔던 ${tick.returned.length}명이 돌아왔다.`);
      if (isCouncilSegment(segment) && !hasSessionVote(app)) next = log(next, '회기가 표결 없이 끝났다.');
      return next;
    }
  }
}

/** 다음 단계로. 막혀 있으면 상태를 그대로 돌려준다. */
export function advance(app: AppState): AppState {
  if (advanceBlocker(app) !== null) return app;
  const flow = nextFlow(app.flow);
  if (flow.ended) {
    return log({ ...app, flow }, `${flow.segment}구간을 모두 지났다. 판이 끝났다(더미 결말).`);
  }
  let next: AppState = { ...app, flow };
  if (flow.segment !== app.flow.segment) {
    next = { ...next, game: { ...next.game, segment: flow.segment }, cardsDone: [] };
  }
  return enterPhase(next);
}

/** 결정 카드의 선택. 효과는 A2 applyEffects로, 파견은 사람을 뽑아 person.away로 바꾼다. */
export function chooseCard(app: AppState, choiceIndex: number): AppState {
  if (app.card === null) return app;
  const card = cardById(app.card.id);
  const choice = card.event.choices[choiceIndex];
  if (!choice) throw new RangeError(`없는 선택지입니다: ${choiceIndex}`);
  const effects: Effect[] = [...choice.effects];
  const order = card.dispatch?.[choiceIndex];
  let sent: string[] = [];
  if (order) {
    sent = dispatchCandidates(app.game, order);
    for (const target of sent) effects.push({ type: 'person.away', target, segments: order.segments });
  }
  const game = applyEffects(app.game, effects);
  const summary = effectSummary(choice.effects);
  let text = `${choice.label}.`;
  if (sent.length > 0) {
    const roster = createDummyRoster(app.seed).profiles;
    text += ` 보낸 사람: ${sent.map(id => roster[id]?.name ?? id).join(', ')}.`;
  }
  if (summary.length > 0) text += ` (${summary.join(', ')})`;
  return log({ ...app, game, card: null, cardsDone: [...app.cardsDone, card.event.id] }, text);
}

export function setCardCollapsed(app: AppState, collapsed: boolean): AppState {
  if (app.card === null || app.card.collapsed === collapsed) return app;
  return { ...app, card: { ...app.card, collapsed } };
}

/** 회기의 표결. 의회 단계에서 한 번만 한다. 난수 상태를 앞으로 보내고 결과를 일지에 남긴다. */
export function castSessionVote(app: AppState): AppState {
  if (app.flow.phase !== 'council' || app.flow.ended || hasSessionVote(app)) return app;
  const bill = billById(app.billId);
  const inputs = councilInputs(app.game, bill);
  const before = app.game.rng;
  const result = runCouncilVote(inputs, bill.law.kind, app.voteMode, before);
  const effects: Effect[] = [];
  if (app.voteMode === 'public') effects.push({ type: 'fear', amount: PUBLIC_VOTE_FEAR });
  if (result.record.passed) effects.push(...bill.law.effects);
  const game = applyEffects({ ...app.game, rng: result.rng }, effects);
  const sessionVote: SessionVote = {
    segment: app.flow.segment, billId: bill.law.id, mode: app.voteMode,
    inputs: inputs.map(group => ({ ...group })), rng: { ...before },
    passed: result.record.passed, yes: result.record.yes,
  };
  const verdict = result.record.passed ? '가결' : '부결';
  const modeLabel = app.voteMode === 'public' ? '공개 투표' : '비밀 투표';
  return log(
    { ...app, game, sessionVote },
    `${bill.title} ${verdict}. 찬성 ${result.record.yes}표, 필요 ${result.record.requiredVotes}표(${modeLabel}).`,
  );
}

export function setVoteMode(app: AppState, mode: VoteMode): AppState {
  if (mode !== 'public' && mode !== 'secret') throw new TypeError(`모르는 투표 방식입니다: ${String(mode)}`);
  return app.voteMode === mode ? app : { ...app, voteMode: mode };
}

/** 안건 바꾸기. 이번 구간에 이미 표결했으면 바꾸지 않는다. */
export function setBill(app: AppState, billId: string): AppState {
  billById(billId);
  if (hasSessionVote(app) || app.billId === billId) return app;
  return { ...app, billId };
}

export function setFlags(app: AppState, flags: FeatureFlags): AppState {
  return { ...app, flags };
}

export function setDummyFaction(app: AppState, on: boolean): AppState {
  if (app.dummyFaction === on) return app;
  const game = withDummyFaction(app.game, on);
  // 집단 구성이 맞는지 A2로 확인한다(사람 중복 배정, 지도자 소속).
  buildCouncilGroups(game);
  const name = GROUP_META.faction_restore.name;
  return log({ ...app, dummyFaction: on, game }, on ? `${name}가 모였다(더미 세력).` : `${name}가 흩어졌다(더미 세력).`);
}

/** 화면에 보이는 최근 일지(새 것부터). */
export function recentJournal(app: AppState, count: number): JournalEntry[] {
  return app.journal.slice(-count).reverse();
}
