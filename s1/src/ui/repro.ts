import {
  COMMS, LOOT_KEYS, advance, applyMove, callEmergency, cancelRestore, castVote, chooseCard, cutComm, delegateStatus, makeDeal,
  migrateDomestic, moveTask, requestApprentice, requestManual, resolveStop, restartTech, setAgenda, setAutoLevers, setBury, setDelegate,
  setEscort, setFullRule, setHotWater, setLever, setStop, setTarget, startFinish, startJob, startRestore, supportComm, uniqueAction,
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
  kind: 's1a-repro'; v: 1; build: string; seed: string; s1c: boolean; when: string; screen?: string;
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
    case 'choose': chooseCard(g, Number(d.uid), Number(d.index)); return null;
    case 'stop-set': {
      const value = d.value ?? '';
      if (d.key === 'target' && (LOOT_KEYS as readonly string[]).includes(value)) setStop(g, { target: value as LootKey });
      else if (d.key === 'stay') setStop(g, { stay: value as StayId });
      else if (d.key === 'crewComm' && (COMMS as readonly string[]).includes(value)) setStop(g, { crewComm: value as Comm });
      else if (d.key === 'crewSize') setStop(g, { crewSize: Number(value) });
      else if (d.key === 'scout') setStop(g, { scout: value === '1' });
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
    case 'lever': setLever(g, d.comm as Comm, d.which as 'heat' | 'ration', Number(d.value)); return null;
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

/** 저장한 판을 읽는다. 예전 판에 없던 칸을 채운다. 못 읽으면 null. */
export function reviveSave(raw: unknown): Game | null {
  const g = raw as Game | null;
  if (!g || typeof g !== 'object' || g.version !== 1 || typeof g.seg !== 'number') return null;
  g.eventLog ??= {};
  g.needs ??= {};
  g.emergencyCalls ??= [];
  g.hunger ??= 0;
  g.linesSeen ??= [];
  migrateDomestic(g);
  return g;
}

export function buildId(): string {
  return typeof __BUILD__ === 'string' ? __BUILD__ : 'dev';
}

export function makeBundle(now: Game, prev: Game | null, trail: TrailEntry[], error: ReproError | null, screen?: string): ReproBundle {
  return {
    kind: 's1a-repro', v: 1, build: buildId(), seed: now.seed, s1c: !!now.dom, when: new Date().toISOString(), screen,
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
