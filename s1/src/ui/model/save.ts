import {
  COMMUNITY_IDS, COMMUNITY_METRICS, PERSON_STATES, RESOURCE_TYPES, buildCouncilGroups, cloneGameState, restoreRng,
} from '../../core';
import type { GameState } from '../../core';
import { APP_VERSION } from './app-state';
import type { AppState, JournalEntry, PendingCard, SessionVote } from './app-state';
import { assertFlow, isPhase } from './flow';
import type { Phase } from './flow';
import { sanitizeFlags } from './flags';
import { DUMMY_BILLS, DUMMY_CARDS } from './dummy';
import { DUMMY_FACTION_ID } from './groups';

// 저장은 한 슬롯(기획서 2장: 되돌리기 없음). 시드를 함께 남겨 같은 판을 처음부터 다시 할 수 있다.
// 저장소 접근은 사생활 보호 모드나 막힌 저장소에서 예외를 던질 수 있어 모두 try/catch로 감싼다.

export const SAVE_KEY = 's1a.save.v1';
export const SAVE_FORMAT = 's1a-save';

export interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

export type SaveErrorCode = 'unavailable' | 'empty' | 'corrupt' | 'write_failed';
export type SaveResult<T> =
  | { ok: true; value: T }
  | { ok: false; error: SaveErrorCode; message: string };

export interface SaveSummary {
  seed: string;
  segment: number;
  phase: Phase;
  ended: boolean;
  savedAt: number;
}

const MESSAGES: Readonly<Record<SaveErrorCode, string>> = Object.freeze({
  unavailable: '이 브라우저에선 저장소를 쓸 수 없다.',
  empty: '저장한 판이 없다.',
  corrupt: '저장본을 읽을 수 없다.',
  write_failed: '저장하지 못했다.',
});

function fail<T>(error: SaveErrorCode, detail?: string): SaveResult<T> {
  return { ok: false, error, message: detail ? `${MESSAGES[error]} (${detail})` : MESSAGES[error] };
}

export function browserStorage(): StorageLike | null {
  try {
    const storage = (globalThis as { localStorage?: StorageLike }).localStorage;
    return storage ?? null;
  } catch {
    return null;
  }
}

// --- 검사 도우미 ---

type Json = Record<string, unknown>;

function object(value: unknown, name: string): Json {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw new TypeError(`${name}: 객체가 아니다`);
  return value as Json;
}

function finite(value: unknown, name: string): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) throw new TypeError(`${name}: 수가 아니다`);
  return value;
}

function integer(value: unknown, name: string, min = 0): number {
  const number = finite(value, name);
  if (!Number.isSafeInteger(number) || number < min) throw new RangeError(`${name}: ${min} 이상의 정수가 아니다`);
  return number;
}

function text(value: unknown, name: string): string {
  if (typeof value !== 'string') throw new TypeError(`${name}: 문자열이 아니다`);
  return value;
}

function strings(value: unknown, name: string): string[] {
  if (!Array.isArray(value)) throw new TypeError(`${name}: 배열이 아니다`);
  return value.map((item, index) => text(item, `${name}[${index}]`));
}

function bool(value: unknown, name: string): boolean {
  if (typeof value !== 'boolean') throw new TypeError(`${name}: 참·거짓이 아니다`);
  return value;
}

/** 저장본의 게임 상태 모양을 확인하고 A2의 의회 집단 규칙(중복 배정, 지도자 소속)도 검사한다. */
export function assertGameState(value: unknown): GameState {
  const game = object(value, 'game');
  integer(game.segment, 'game.segment');
  const rng = restoreRng(game.rng);
  const communities = object(game.communities, 'game.communities');
  for (const id of COMMUNITY_IDS) {
    const community = object(communities[id], `game.communities.${id}`);
    for (const metric of COMMUNITY_METRICS) finite(community[metric], `game.communities.${id}.${metric}`);
  }
  for (const key of ['trust', 'tension', 'fear'] as const) finite(game[key], `game.${key}`);
  const resources = object(game.resources, 'game.resources');
  for (const type of RESOURCE_TYPES) finite(resources[type], `game.resources.${type}`);
  for (const key of ['symbols', 'secrets', 'acquiredSymbols', 'chronicle'] as const) strings(game[key], `game.${key}`);
  const persons = object(game.persons, 'game.persons');
  for (const [id, raw] of Object.entries(persons)) {
    const person = object(raw, `game.persons.${id}`);
    if (person.id !== id) throw new Error(`game.persons.${id}: id가 키와 다르다`);
    if (!COMMUNITY_IDS.includes(person.community as never)) throw new Error(`game.persons.${id}: 모르는 공동체`);
    if (!PERSON_STATES.includes(person.state as never)) throw new Error(`game.persons.${id}: 모르는 상태`);
    integer(person.awaySegments, `game.persons.${id}.awaySegments`);
    if (person.returnState !== 'alive' && person.returnState !== 'injured') throw new Error(`game.persons.${id}: 귀환 상태`);
    if (person.age !== undefined) integer(person.age, `game.persons.${id}.age`);
  }
  const groups = object(game.groups, 'game.groups');
  for (const [id, raw] of Object.entries(groups)) {
    const group = object(raw, `game.groups.${id}`);
    if (group.id !== id) throw new Error(`game.groups.${id}: id가 키와 다르다`);
    strings(group.members, `game.groups.${id}.members`);
    for (const key of ['relation', 'cohesion', 'votes'] as const) finite(group[key], `game.groups.${id}.${key}`);
    if (group.leaderId !== undefined) text(group.leaderId, `game.groups.${id}.leaderId`);
  }
  object(game.flags, 'game.flags');
  for (const key of ['followups', 'deals', 'promises'] as const) {
    if (!Array.isArray(game[key])) throw new TypeError(`game.${key}: 배열이 아니다`);
  }
  const state = cloneGameState({ ...(game as unknown as GameState), rng });
  buildCouncilGroups(state);
  return state;
}

function assertJournal(value: unknown): JournalEntry[] {
  if (!Array.isArray(value)) throw new TypeError('journal: 배열이 아니다');
  return value.map((raw, index) => {
    const entry = object(raw, `journal[${index}]`);
    if (!isPhase(entry.phase)) throw new Error(`journal[${index}]: 모르는 단계`);
    return { segment: integer(entry.segment, `journal[${index}].segment`, 1), phase: entry.phase, text: text(entry.text, `journal[${index}].text`) };
  });
}

function assertCard(value: unknown): PendingCard | null {
  if (value === null) return null;
  const card = object(value, 'card');
  const id = text(card.id, 'card.id');
  if (!DUMMY_CARDS.some(candidate => candidate.event.id === id)) throw new Error(`card: 모르는 카드 ${id}`);
  return { id, collapsed: bool(card.collapsed, 'card.collapsed') };
}

function assertVoteMode(value: unknown, name: string): 'public' | 'secret' {
  if (value !== 'public' && value !== 'secret') throw new Error(`${name}: 모르는 투표 방식`);
  return value;
}

function assertBillId(value: unknown, name: string): string {
  const id = text(value, name);
  if (!DUMMY_BILLS.some(bill => bill.law.id === id)) throw new Error(`${name}: 모르는 안건 ${id}`);
  return id;
}

function assertSessionVote(value: unknown): SessionVote | null {
  if (value === null) return null;
  const vote = object(value, 'sessionVote');
  if (!Array.isArray(vote.inputs)) throw new TypeError('sessionVote.inputs: 배열이 아니다');
  const inputs = vote.inputs.map((raw, index) => {
    const group = object(raw, `sessionVote.inputs[${index}]`);
    text(group.id, `sessionVote.inputs[${index}].id`);
    for (const key of ['population', 'present'] as const) integer(group[key], `sessionVote.inputs[${index}].${key}`);
    for (const key of ['cohesion', 'promisedVotes'] as const) finite(group[key], `sessionVote.inputs[${index}].${key}`);
    return { ...group } as unknown as SessionVote['inputs'][number];
  });
  return {
    segment: integer(vote.segment, 'sessionVote.segment', 1),
    billId: assertBillId(vote.billId, 'sessionVote.billId'),
    mode: assertVoteMode(vote.mode, 'sessionVote.mode'),
    inputs,
    rng: restoreRng(vote.rng),
    passed: bool(vote.passed, 'sessionVote.passed'),
    yes: integer(vote.yes, 'sessionVote.yes'),
  };
}

/** 저장본의 앱 상태를 검사해 새 객체로 되살린다. 틀리면 예외를 던진다. */
export function assertAppState(value: unknown): AppState {
  const app = object(value, 'app');
  if (app.version !== APP_VERSION) throw new Error(`app.version: ${String(app.version)}은 지원하지 않는다`);
  const seed = text(app.seed, 'app.seed');
  if (seed.trim().length === 0) throw new Error('app.seed: 비어 있다');
  const flow = object(app.flow, 'app.flow');
  const flowState = { segment: flow.segment, phase: flow.phase, ended: flow.ended } as AppState['flow'];
  assertFlow(flowState);
  const game = assertGameState(app.game);
  const dummyFaction = bool(app.dummyFaction, 'app.dummyFaction');
  if (Object.hasOwn(game.groups, DUMMY_FACTION_ID) !== dummyFaction) throw new Error('app.dummyFaction: 집단 구성과 맞지 않는다');
  return {
    version: APP_VERSION,
    seed,
    flags: sanitizeFlags(app.flags),
    dummyFaction,
    flow: { ...flowState },
    game,
    journal: assertJournal(app.journal),
    card: assertCard(app.card),
    cardsDone: strings(app.cardsDone, 'app.cardsDone'),
    voteMode: assertVoteMode(app.voteMode, 'app.voteMode'),
    billId: assertBillId(app.billId, 'app.billId'),
    sessionVote: assertSessionVote(app.sessionVote),
  };
}

export function serializeApp(app: AppState, savedAt: number): string {
  return JSON.stringify({ format: SAVE_FORMAT, version: APP_VERSION, savedAt, app });
}

export function parseSave(raw: string): { app: AppState; savedAt: number } {
  const envelope = object(JSON.parse(raw), 'save');
  if (envelope.format !== SAVE_FORMAT) throw new Error('save.format: 이 게임의 저장본이 아니다');
  if (envelope.version !== APP_VERSION) throw new Error(`save.version: ${String(envelope.version)}은 지원하지 않는다`);
  return { app: assertAppState(envelope.app), savedAt: finite(envelope.savedAt, 'save.savedAt') };
}

function summary(app: AppState, savedAt: number): SaveSummary {
  return { seed: app.seed, segment: app.flow.segment, phase: app.flow.phase, ended: app.flow.ended, savedAt };
}

export function saveApp(storage: StorageLike | null, app: AppState, now: number = Date.now()): SaveResult<SaveSummary> {
  if (!storage) return fail('unavailable');
  try {
    storage.setItem(SAVE_KEY, serializeApp(app, now));
    return { ok: true, value: summary(app, now) };
  } catch (error) {
    return fail('write_failed', error instanceof Error ? error.name : undefined);
  }
}

function readRaw(storage: StorageLike | null): SaveResult<string> {
  if (!storage) return fail('unavailable');
  let raw: string | null;
  try {
    raw = storage.getItem(SAVE_KEY);
  } catch {
    return fail('unavailable');
  }
  return raw === null ? fail('empty') : { ok: true, value: raw };
}

export function loadApp(storage: StorageLike | null): SaveResult<{ app: AppState; summary: SaveSummary }> {
  const raw = readRaw(storage);
  if (!raw.ok) return raw;
  try {
    const parsed = parseSave(raw.value);
    return { ok: true, value: { app: parsed.app, summary: summary(parsed.app, parsed.savedAt) } };
  } catch (error) {
    return fail('corrupt', error instanceof Error ? error.message : undefined);
  }
}

export function peekSave(storage: StorageLike | null): SaveResult<SaveSummary> {
  const loaded = loadApp(storage);
  return loaded.ok ? { ok: true, value: loaded.value.summary } : loaded;
}

export function clearSave(storage: StorageLike | null): SaveResult<null> {
  if (!storage) return fail('unavailable');
  try {
    storage.removeItem(SAVE_KEY);
    return { ok: true, value: null };
  } catch (error) {
    return fail('write_failed', error instanceof Error ? error.name : undefined);
  }
}

/** 테스트와 저장소가 없는 환경에서 쓰는 메모리 저장소. */
export class MemoryStorage implements StorageLike {
  private readonly items = new Map<string, string>();
  getItem(key: string): string | null {
    return this.items.has(key) ? this.items.get(key) as string : null;
  }
  setItem(key: string, value: string): void {
    this.items.set(key, String(value));
  }
  removeItem(key: string): void {
    this.items.delete(key);
  }
}
