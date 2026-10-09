import {
  COMMS, CREW_COMMS, LOOT_KEYS, canLift, liftMartial, advance, applyMove, callEmergency, cancelRestore, castVote, chooseCard, cutComm, delegateStatus, makeDeal,
  migrateDomestic, moveTask, requestApprentice, requestManual, resolveStop, restartTech, setAgenda, setSpace, setAutoLevers, setBury, setDelegate,
  setEscort, setFullRule, setHotWater, setLever, setStop, setTarget, takeAltPlace, startFinish, startJob, startRestore, supportComm, uniqueAction, logCardPick,
} from '../game';
import type { Comm, Field, Game, LootKey, ModKind, StayId, Task, TechId, Variant } from '../game';

// 오류 재현 묶음(r8 출시 실무 3): 시드, 최근 행동, 직전 저장, 지금 저장, 오류를 한 덩어리 JSON으로.
// 판을 바꾸는 행동은 모두 applyStep을 거친다. 그래서 직전 저장에 마지막 행동을 다시 하면 같은 판(같은 오류)이 나온다.
// 난수 상태가 저장에 들어 있어(state.ts rng) 다시 해도 같은 수가 나온다.

/** 판을 바꾸는 행동 하나. a는 화면 단추의 data-action, d는 그 단추의 data-* 값. */
export interface Step { a: string; d: Record<string, string> }

export interface TrailEntry extends Step { seg: number; phase: string; t: number }

export interface ReproError { msg: string; stack?: string; step?: Step; t: number }

export interface ReproBundle {
  kind: 's1a-repro'; v: 1; build: string; seed: string; s1c: boolean; s1b?: boolean; when: string; screen?: string;
  trail: TrailEntry[]; error: ReproError | null; prev: Game | null; now: Game;
}

export const TRAIL_MAX = 40;

/** DOMStringMap 같은 것을 저장할 수 있는 평범한 객체로. */
export function plainData(d: Record<string, string | undefined>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(d)) if (v !== undefined) out[k] = v;
  return out;
}

/** 판을 바꾸는 행동을 한다. 띄울 알림 글이 있으면 돌려준다. 모르는 행동이면 던진다. */
export function applyStep(g: Game, s: Step): string | null {
  const d = s.d;
  switch (s.a) {
    case 'advance': advance(g); return null;
    case 'emergency': callEmergency(g); return null;
    case 'choose':
      if (d.ms) logCardPick(g, Number(d.uid), Number(d.index), Number(d.ms)); // S1b H7
      chooseCard(g, Number(d.uid), Number(d.index));
      return null;
    case 'stop-set': {
      const value = d.value ?? '';
      if (d.key === 'target' && (LOOT_KEYS as readonly string[]).includes(value)) setStop(g, { target: value as LootKey });
      else if (d.key === 'stay') setStop(g, { stay: value as StayId });
      else if (d.key === 'crewComm' && (COMMS as readonly string[]).includes(value)) setStop(g, { crewComm: value as Comm });
      else if (d.key === 'crewSize') setStop(g, { crewSize: Number(value) });
      else if (d.key === 'scout') setStop(g, { scout: value === '1' });
      else if (d.key === 'place' && value === 'alt') takeAltPlace(g);
      return null;
    }
    case 'stop-go': resolveStop(g, d.go === '1'); return null;
    case 'auto-levers': setAutoLevers(g, !g.autoLevers); return null;
    case 'agenda': {
      const council = g.council;
      if (!council) return null;
      const n = council.options.length;
      setAgenda(g, (council.idx + Number(d.step) + n) % n);
      return null;
    }
    case 'deal': return makeDeal(g, d.comm as Comm, d.tool as Parameters<typeof makeDeal>[2]).text;
    case 'deal-cond': return makeDeal(g, d.comm as Comm, 'open', Number(d.index), (d.cut || undefined) as Comm | undefined).text;
    case 'vote':
    case 'decree': castVote(g, s.a === 'decree'); return null;
    case 'comm-act': {
      const c = d.comm as Comm;
      return d.act === 'support' ? supportComm(g, c) : d.act === 'cut' ? cutComm(g, c) : uniqueAction(g, c);
    }
    case 'dark-lift': { // S1b 계엄 회기에서 계엄을 거둔다(그 회기는 liftMartial이 닫는다)
      const why = canLift(g);
      if (why) return why;
      liftMartial(g, 'self');
      return null;
    }
    case 'lever': setLever(g, d.comm as Comm, d.which as 'heat' | 'ration', Number(d.value)); return null;
    case 'space': return setSpace(g, Number(d.step), (COMMS as readonly string[]).includes(d.giver ?? '') ? d.giver as Comm : undefined);
    // ---- S1c 내정 ----
    case 'dom-restore':
      return startRestore(g, d.id as TechId, d.mode === 'defect' ? 'defect' : 'full', (d.variant || undefined) as Variant | undefined) ? null : '지금은 시작할 수 없다';
    case 'dom-cancel': cancelRestore(g); return null;
    case 'dom-finish': return startFinish(g, d.id as TechId) ? null : '지금은 고칠 수 없다';
    case 'dom-restart': restartTech(g, d.id as TechId); return null;
    case 'dom-order': moveTask(g, d.task as Task, d.step === '-1' ? -1 : 1); return null;
    case 'dom-delegate':
      return setDelegate(g, d.on === '1', (d.policy || undefined) as 'ours' | 'neutral' | undefined) ? null : delegateStatus(g).why ?? '맡길 수 없다';
    case 'dom-apprentice': return requestApprentice(g, d.field as Field) ? '견습생 후보 서류가 쌓였다.' : '가르칠 사람이 없거나 서류가 이미 있다.';
    case 'dom-manual': return requestManual(g, d.field as Field) ? '매뉴얼 요청 서류가 쌓였다.' : '써 줄 사람이 없거나 서류가 이미 있다.';
    case 'dom-hot': setHotWater(g, Number(d.value)); return null;
    case 'dom-target': setTarget(g, Number(d.value)); return null;
    case 'dom-full': setFullRule(g, d.rule as 'parts' | 'dump' | 'aisle'); return null;
    case 'dom-job': return startJob(g, d.kind as ModKind, d.car ?? '') ? null : '개조를 올릴 수 없다';
    case 'dom-escort': setEscort(g, d.id || null); return null;
    case 'dom-bury': setBury(g, d.on === '1'); return null;
    case 'dom-move-apply': return applyMove(g, (d.order ?? '').split(',').filter(Boolean)) ? null : '입환할 수 없다';
    default: throw new Error(`모르는 행동: ${s.a}`);
  }
}

// ---- 저장 판 읽기(A2 코드 구조 점검 5번) ----
// 칸을 더하기만 했으면 판 번호를 그대로 두고 fillDefaults에 ??=로 채운다.
// 칸을 지우거나 이름·뜻을 바꾸면 SAVE_VERSION을 올리고 MIGRATE에 그 한 단계를 더한다(Game.version 타입도 같이).

/** 이 빌드가 쓰는 저장 판 번호 */
export const SAVE_VERSION = 1;

/** 판 번호 v의 저장을 v+1로 옮기는 단계. 아직 판 번호를 올린 적이 없어 비어 있다. */
const MIGRATE: Record<number, (g: Record<string, unknown>) => void> = {};

const PHASES: readonly string[] = ['prep', 'travel', 'stop', 'council', 'settle', 'end'];

export type SaveRead = { ok: true; g: Game } | { ok: false; why: string };

const isObj = (v: unknown): v is Record<string, unknown> => !!v && typeof v === 'object' && !Array.isArray(v);
const isNum = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v);

/** 판이 곧바로 읽는 뼈대가 다 있나. 처음 판부터 있던 칸만 본다(나중에 더한 칸은 fillDefaults가 채운다). 문제가 있으면 까닭. */
function shapeProblem(g: Record<string, unknown>): string | null {
  if (typeof g.seed !== 'string' || g.seed === '') return '시드가 없다';
  if (!isObj(g.rng) || !isNum(g.rng.state)) return '난수 상태가 없다';
  if (!isNum(g.seg) || g.seg < 0 || !Number.isInteger(g.seg)) return '구간 번호가 이상하다';
  if (typeof g.phase !== 'string' || !PHASES.includes(g.phase)) return `모르는 단계: ${String(g.phase)}`;
  for (const k of ['coal', 'food', 'med', 'trust', 'tension']) if (!isNum(g[k])) return `수치가 이상하다: ${k}`;
  if (!isObj(g.comms)) return '공동체 칸이 없다';
  for (const c of COMMS) {
    const st = g.comms[c];
    if (!isObj(st) || !isNum(st.pop) || !isNum(st.rel)) return `공동체가 이상하다: ${c}`;
  }
  for (const k of ['cards', 'journal']) if (!Array.isArray(g[k])) return `목록이 없다: ${k}`;
  if (!isObj(g.passed)) return '통과한 법 칸이 없다';
  if (g.dom !== undefined && !isObj(g.dom)) return '내정 칸이 이상하다';
  return null;
}

/** 판 번호는 그대로인데 나중에 더한 칸을 채운다. */
function fillDefaults(g: Game): void {
  g.eventLog ??= {};
  g.needs ??= {};
  g.emergencyCalls ??= [];
  g.hunger ??= 0;
  g.linesSeen ??= [];
  // 기관실은 작업조로 못 낸다(6.4). 그 전에 저장한 열린 정차가 기관실을 골라 뒀으면 경비대로 바꾼다.
  if (g.stop && !g.stop.done && !CREW_COMMS.includes(g.stop.crewComm)) g.stop.crewComm = 'guard';
  migrateDomestic(g);
}

/** 저장한 판을 읽는다: 판 번호 확인, 판 번호별 옮기기, 뼈대 검사, 나중에 더한 칸 채우기. 못 읽으면 까닭을 돌려준다. */
export function readSave(raw: unknown): SaveRead {
  if (!isObj(raw)) return { ok: false, why: '판 자료가 아니다' };
  const v = raw.version;
  if (!isNum(v) || !Number.isInteger(v) || v < 1) return { ok: false, why: '판 번호가 없다' };
  if (v > SAVE_VERSION) return { ok: false, why: `더 새 빌드에서 저장한 판이다(판 번호 ${v})` };
  try {
    for (let at = v; at < SAVE_VERSION; at += 1) {
      const up = MIGRATE[at];
      if (!up) return { ok: false, why: `판 번호 ${at}에서 옮기는 길이 없다` };
      up(raw);
      raw.version = at + 1;
    }
    const why = shapeProblem(raw);
    if (why) return { ok: false, why };
    const g = raw as unknown as Game;
    fillDefaults(g);
    return { ok: true, g };
  } catch (e) {
    return { ok: false, why: `읽다 멈췄다: ${e instanceof Error ? e.message : String(e)}` };
  }
}

/** 저장한 판을 읽는다. 못 읽으면 null(까닭은 readSave). */
export function reviveSave(raw: unknown): Game | null {
  const r = readSave(raw);
  return r.ok ? r.g : null;
}

export function buildId(): string {
  return typeof __BUILD__ === 'string' ? __BUILD__ : 'dev';
}

export function makeBundle(now: Game, prev: Game | null, trail: TrailEntry[], error: ReproError | null, screen?: string): ReproBundle {
  return {
    kind: 's1a-repro', v: 1, build: buildId(), seed: now.seed, s1c: !!now.dom, s1b: !!now.dark, when: new Date().toISOString(), screen,
    trail: trail.slice(-TRAIL_MAX), error, prev, now,
  };
}

export interface ReplayResult {
  /** 직전 저장에 마지막 행동을 다시 해서 지금 저장과 같아졌나 */
  same: boolean;
  /** 다시 하다 던진 오류 */
  thrown?: Error;
  /** 지금 저장과 다른 맨 위 칸 */
  diff: string[];
  last?: TrailEntry;
  replayed?: Game;
}

/** 직전 저장에 마지막 행동을 다시 한다. 오류 묶음이면 같은 오류가 다시 나는지, 아니면 지금 저장과 같은지 본다. */
export function replayBundle(b: ReproBundle): ReplayResult {
  const last = b.trail[b.trail.length - 1];
  const prev = reviveSave(structuredClone(b.prev));
  if (!prev || !last) return { same: false, diff: ['직전 저장이나 행동 기록이 없다'], last };
  const g = structuredClone(prev);
  try {
    applyStep(g, last);
  } catch (e) {
    return { same: false, thrown: e as Error, diff: [], last, replayed: g };
  }
  const now = reviveSave(structuredClone(b.now));
  const diff = now ? Object.keys({ ...now, ...g }).filter(k => JSON.stringify((g as unknown as Record<string, unknown>)[k]) !== JSON.stringify((now as unknown as Record<string, unknown>)[k])) : ['지금 저장을 못 읽었다'];
  return { same: diff.length === 0, diff, last, replayed: g };
}

// ---- 화면 ----
// 메뉴 창(panels.ts)이 묶음을 꺼내 갈 곳. app.ts가 판을 시작할 때 채운다.
let source: (() => ReproBundle) | null = null;
let lastError: () => ReproError | null = () => null;

export function setReproSource(make: () => ReproBundle, error: () => ReproError | null): void {
  source = make;
  lastError = error;
}

export function reproText(): string {
  return source ? JSON.stringify(source()) : '';
}

export function reproError(): ReproError | null {
  return lastError();
}
