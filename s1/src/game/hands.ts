import { COMMS, HANDS } from './data';
import type { Comm, HandJob } from './data';
import { PROFILES } from './state';
import type { Game } from './state';

// 손 몫(결정 425, carry_people.md 3.1): 열차는 손으로 굴러간다. 구간마다 손이 드는 일 다섯(화실 교대·난로와 물·보초·
// 지붕과 선로·수리, 합 74)을 칸 대표가 내는 손으로 채운다. 칸이 내는 손은 그 칸 일할 나이(16~65)의 몫에 뜻(관계·레버)을 곱한 것이고,
// 다친 사람은 빠진다. 모자라면 그 일이 덜 된다: 화실은 석탄, 난로는 칸 온기, 보초는 정차 위험, 지붕·선로는 선로 사건, 수리는 공방.
// 정산 끝에 다음 구간 몫을 셈해 g.hands에 둔다(situation·forecast·stopRisk는 그 값만 읽는다).
// 금지선: 손은 칸 대표가 내고 몫을 받는다. 이름으로 고르거나 억지로 시키는 길은 없고, 칸은 손을 거둘 수 있을 뿐이다.

export interface HandsState {
  /** 이번 구간에 칸들이 낸 손(다친 사람 뺌) */
  have: number;
  /** 일마다 빈 몫(0 다 참 ~ 1 다 빔) */
  short: Record<HandJob, number>;
}

/** 칸마다 일할 나이(16~65)의 몫. 사람 표(profiles.json)에서 처음 쓸 때 한 번 센다(state.ts와 서로 불러오므로 모듈을 읽을 때 세지 않는다). */
let share: Record<Comm, number> | undefined;
export function workShare(c: Comm): number {
  if (!share) {
    share = {} as Record<Comm, number>;
    for (const k of COMMS) {
      const all = PROFILES.filter(p => p.community === k);
      share[k] = all.length ? all.filter(p => p.age >= 16 && p.age <= 65).length / all.length : 0.75;
    }
  }
  return share[c];
}

const JOB_NAME: Record<HandJob, string> = { stoker: '화실 교대', stove: '난로와 물', watch: '지붕 보초', roof: '지붕 얼음과 선로', repair: '고칠 손' };

/** 칸 대표가 내는 뜻(0~1): 관계가 나쁠수록, 작업을 거부하는 칸일수록, 그 칸 몫(난방·배급)이 낮을수록 덜 낸다. */
export function handsWill(g: Game, c: Comm): number {
  const s = g.comms[c];
  let will = s.rel <= -40 ? (s.fervor >= 1 ? HANDS.willRefuse : HANDS.willHostile) : s.rel < -15 ? HANDS.willCold : 1;
  const lever = Math.min(s.heat, s.ration);
  if (lever <= 0) will *= HANDS.leverCut;
  else if (lever <= 1) will *= HANDS.leverLow;
  return will;
}

/** 칸이 내는 손: 자리에 있는 사람(인구 − 자리비움) × 일할 나이 몫 × 뜻. */
export function handsOffered(g: Game, c: Comm): number {
  const s = g.comms[c];
  return Math.max(0, s.pop - s.away) * workShare(c) * handsWill(g, c);
}

/** 손을 일 차례대로 나눠 빈 몫을 셈한다(화실부터 채운다). */
export function handsNow(g: Game): HandsState {
  const have = Math.max(0, COMMS.reduce((sum, c) => sum + handsOffered(g, c), 0) - g.injured);
  let left = have;
  const short = {} as Record<HandJob, number>;
  for (const j of HANDS.order) {
    const got = Math.min(HANDS.need[j], left);
    left -= got;
    short[j] = 1 - got / HANDS.need[j];
  }
  return { have, short };
}

/** 정산 끝: 다음 구간의 손 몫을 둔다. 빈 일이 있으면 결과 줄 하나. */
export function handsSettle(g: Game, notes: string[]): void {
  const h = handsNow(g);
  g.hands = h;
  const empty = HANDS.order.filter(j => h.short[j] > 0.01);
  if (empty.length) notes.push(`일손이 모자라 ${empty.map(j => JOB_NAME[j]).join('·')}이(가) 빈다.`);
}

/** 이 일이 빈 몫(정산에서 둔 값). 판 시작이나 옛 저장 판에는 없어서 0이다. */
export function handShort(g: Game, j: HandJob): number {
  return g.hands?.short[j] ?? 0;
}

/** 화실 교대가 빈 만큼 더 드는 석탄(구간 정산·예보) */
export function handsCoal(g: Game): number {
  return HANDS.stokerCoal * handShort(g, 'stoker');
}

/** 보초가 빈 만큼 정차의 기척이 커진다(예보 단계가 오른다) */
export function handsWatchMult(g: Game): number {
  return 1 + HANDS.watchRisk * handShort(g, 'watch');
}

/** 고칠 손이 빈 만큼 공방 작업량이 준다 */
export function handsWorkMult(g: Game): number {
  return 1 - HANDS.repairWork * handShort(g, 'repair');
}

/** 지붕·선로가 많이 비면 선로 사건(climate.ts TRACK_EVENTS와 같은 둘)이 더 자주 뽑힌다. */
const TRACK = ['water_tower', 'snow_drift'];
export function handsTrackBoost(g: Game, pool: string[]): string[] {
  if (handShort(g, 'roof') <= HANDS.roofOver) return pool;
  const out = [...pool];
  for (const id of TRACK) if (pool.includes(id)) for (let i = 1; i < HANDS.roofTrack; i += 1) out.push(id);
  return out;
}
