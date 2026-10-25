import { COMMS, P } from './data';
import type { Comm } from './data';
import { onDeath } from './death';
import { refreshSit } from './domestic/sit';
import { bumpRel } from './ledger';
import { offend } from './politics';
import { addCard, clamp, isGone, journal, PROFILES, rnd, riotStart } from './state';
import type { Game, RiotState } from './state';
import { isWounded, noteInjury } from './wounds';

// 고조 사다리(정치 흐름 4장, 결정 439): 항의 → 난장판 → 마지막 기회. 단계마다 대응 넷(방치·양보·경비·계엄)이
// 사건(다음 항의·불씨), 자원, 사람(이름·관계)에 서로 다른 흔적을 남긴다. 값은 제안이고 봇으로 정한다.
export const LADDER = {
  /** 물리친 항의는 이만큼 지나도 긴장이 항의 문턱 위면 다시 온다(풀리지 않은 요구만, 6.1 sol 검수 1) */
  ignoreAgain: 3,
  /** 들어준 뒤 이 구간 동안 항의 문턱이 이만큼 낮다(「요구가 통한다」) */
  yieldDrop: 5, yieldSegs: 2,
  /** 경비로 누르면: 긴장, 공포, 경비대 관계(집행 몫), 누른 칸 불씨 배율과 기간(S1b, s1b_dark_path 5.1) */
  guardTension: -6, guardFear: 5, guardRel: -2, guardEmberMult: 2, guardEmberSegs: 6,
} as const;

/** 지금 항의 카드가 뜨는 긴장(들어준 직후엔 낮다). */
export function protestLine(g: Game): number {
  const r = g.riot;
  return P.protestFrom - (r?.yieldUntil !== undefined && g.seg <= r.yieldUntil ? LADDER.yieldDrop : 0);
}

/** 경비대가 누르는 명령을 따르나. 반대 이하면 따르지 않는다(s1b_dark_path 5.1). 따르면 null. */
export function guardRefuses(g: Game): string | null {
  return g.comms.guard.rel <= -40 ? '경비대가 따르지 않는다' : null;
}

/** 대응: 방치(물리친다·아무것도 안 한다). 풀리지 않으면 다시 온다. */
export function ladderIgnore(g: Game): void {
  riotOf(g).ignoredAt = g.seg;
}

/** 대응: 양보(들어준다·창고를 연다). 짧게 항의 문턱이 낮아진다. 반대편 칸이 시샘하는 값은 카드 효과에 있다. */
export function ladderYield(g: Game): void {
  const r = riotOf(g);
  r.yieldUntil = g.seg + LADDER.yieldSegs - 1;
  delete r.ignoredAt;
}

/** 대응: 경비(경비대를 세운다·푼다). 경비대 사람은 맨손으로 통로에 서서 사람 사이를 갈라 놓는다(가두거나 끌고 가지 않는다).
 * 누른 칸 적의 +1(지키지 않은 약속이 걸려 있으면 +1 더), 경비대 관계 −2, 공포 +5, 그 칸 불씨가 6구간 두 배(S1b). */
export function ladderGuard(g: Game, c: Comm): void {
  const r = riotOf(g);
  offend(g, c);
  if (g.comms[c].promise) {
    offend(g, c);
    journal(g, '약속을 걸어 둔 채 경비대를 세웠다. 그 칸이 따로 기억한다.', 'bad');
  }
  bumpRel(g, 'guard', LADDER.guardRel, 'ladder');
  g.fear = clamp(g.fear + LADDER.guardFear, 0, 100);
  r.guardUntil = g.seg + LADDER.guardEmberSegs - 1;
  r.guardComm = c;
  delete r.ignoredAt;
}

/** S1b 불씨 확률 배율: 경비로 누른 칸은 한동안 불씨가 잘 생긴다. */
export function ladderEmberMult(g: Game, c: Comm): number {
  const r = g.riot;
  return r?.guardComm === c && r.guardUntil !== undefined && g.seg <= r.guardUntil ? LADDER.guardEmberMult : 1;
}

// 폭동(난장판) 규칙. 긴장이 문턱을 위로 넘는 정산에 켜지고, 요구 카드에 답하면 끊긴다.
// 켜진 동안 정산마다 어른이 쓰러지고 불이 번지며 일손은 불을 끄지 못한다. 끊긴 뒤에는 새 불이 없고 일손이 불을 끈다.
// 불이 지나간 칸은 그을음과 부서진 선반이 남고, 그 칸이 이어진 집단의 처지가 판 끝까지 나빠진다(domestic/sit.ts refreshSit).
// 불로 죽는 사람은 없다. 사람은 걸어서 옆 칸으로 옮겨 가고, 칸은 열차에 남는다.

/** 시험·재기용 틈: 문턱을 P.riotFrom 대신 이 값으로 읽는다. 0이면 폭동 규칙 전체가 꺼져 옛 동작과 같다. */
export const RIOT_TUNE: { from?: number } = {};
const riotFrom = (): number => RIOT_TUNE.from ?? P.riotFrom;

export function riotOf(g: Game): RiotState {
  return (g.riot ??= riotStart());
}

/** 어른 n명이 쓰러진다. 각각 P.riotDeath의 확률로 죽고 나머지는 다친 사람으로 센다. 일지에는 수로만 적는다. */
export function riotFell(g: Game, n: number): { dead: number; hurt: number } {
  const r = riotOf(g);
  const leaders = new Set(COMMS.map(c => g.comms[c].leader.name));
  const pool = PROFILES.filter(p => p.age >= 16 && p.age <= 64 && !leaders.has(p.name) && !isGone(g, p.name) && !isWounded(g, p.name));
  let dead = 0;
  let hurt = 0;
  for (let k = 0; k < n && pool.length > 0; k += 1) {
    const [p] = pool.splice(Math.floor(rnd(g) * pool.length), 1);
    if (rnd(g) < P.riotDeath) {
      onDeath(g, p.community, [p.name], 'other', false, true);
      dead += 1;
    } else {
      g.injured += 1;
      noteInjury(g, 1, 'brawl', '난장판', { names: [p.name], comm: p.community });
      hurt += 1;
    }
    // 그 사람과 가족의 기억은 사람 기억 묶음(memory.ts)이 읽는다. 칸 관계는 건드리지 않는다.
    (g.personEvents ??= []).push({ key: 'riot_fell', who: p.id, seg: g.seg, comm: p.community });
  }
  r.fell += dead + hurt;
  r.died += dead;
  if (dead + hurt > 0) journal(g, `싸움이 번져 어른 ${dead + hurt}명이 쓰러졌다.${dead > 0 ? ` 그중 ${dead}명은 일어나지 못했다.` : ' 모두 숨은 붙어 있다.'}`, 'bad');
  return { dead, hurt };
}

/** 난장판을 끊는다(요구 카드에서 「들어준다」·「경비대를 푼다」를 고른 뒤). */
export function riotEnd(g: Game): void {
  const r = riotOf(g);
  if (r.stage !== 2) return;
  r.stage = g.tension >= P.protestFrom ? 1 : 0;
  journal(g, '난장판이 가라앉았다.', 'good');
}

// ---- 불 ----
const carsOf = (g: Game): string[] => g.dom?.cars ?? [];

function burn(r: RiotState, car: string): void {
  if (!r.fire.includes(car)) r.fire.push(car);
  if (!r.scorched.includes(car)) r.scorched.push(car);
}

/** 칸 가운데 난수로 한 칸에 불이 붙는다. 칸 순서를 모르는 판(내정이 없는 판)에는 불이 없다. */
function ignite(g: Game, r: RiotState): boolean {
  const cars = carsOf(g);
  if (cars.length === 0) return false;
  burn(r, cars[Math.floor(rnd(g) * cars.length)]);
  return true;
}

/** 불이 붙은 칸의 앞뒤 이웃(그 정산의 현재 칸 순서) 가운데 아직 안 붙은 한 칸으로 난수로 번진다. */
function spread(g: Game, r: RiotState): boolean {
  const cars = carsOf(g);
  const next: string[] = [];
  for (const f of r.fire) {
    const i = cars.indexOf(f);
    if (i < 0) continue;
    for (const j of [i - 1, i + 1]) {
      const c = cars[j];
      if (c && !r.fire.includes(c) && !next.includes(c)) next.push(c);
    }
  }
  if (next.length === 0) return false;
  burn(r, next[Math.floor(rnd(g) * next.length)]);
  return true;
}

const WALK = '사람들은 걸어서 옆 칸으로 옮겨 갔다.';

/** 정산 한 번의 폭동 틱. meters 뒤, checkEnd 앞에서 한 번 부른다. */
export function riotTick(g: Game, notes: string[]): void {
  const from = riotFrom();
  if (from <= 0) return;
  const r = riotOf(g);
  const prev = r.prev;
  const now = g.tension;
  r.prev = now;
  const ongoing = r.stage === 2;
  const line = protestLine(g);
  const crossed = !ongoing && ((prev < from && now >= from) || (!!r.pending && now >= from));
  // 항의 없이 한 정산에 난장판 문턱을 넘었으면(예고 없음) 이번엔 항의만 띄우고 다음 정산에 판정한다(정치 흐름 4.1).
  const skipped = crossed && !r.pending && prev < line;
  if (skipped) r.pending = true;
  else if (r.pending && (crossed || now < from)) delete r.pending;
  const starts = crossed && !skipped;
  const scorchedBefore = r.scorched.length;
  if (ongoing || starts) {
    if (starts) {
      r.stage = 2;
      r.riots += 1;
    }
    riotFell(g, P.riotFall);
    r.spilled += 1;
    if (starts) {
      if (ignite(g, r)) journal(g, `난장판 속에서 불이 붙었다. ${WALK} 연기는 낮게 옆으로 흩어진다.`, 'bad');
    } else if (spread(g, r)) {
      journal(g, `불이 이웃 칸으로 번졌다. ${WALK} 불붙은 칸 ${r.fire.length}.`, 'bad');
    }
    if (r.fire.length > 0) notes.push(`난장판이 이어진다. 불붙은 칸 ${r.fire.length}, 싸움 때문에 불을 끄지 못한다.`);
    else notes.push('난장판이 이어진다.');
    if (!g.cards.some(c => c.kind === 'protest')) {
      r.riotCards += 1;
      addCard(g, { kind: 'protest', comm: 'tail', text: 'riot' });
    }
  } else {
    r.stage = now >= P.protestFrom ? 1 : 0;
    if (r.fire.length > 0) {
      if (spread(g, r)) journal(g, `불이 이웃 칸으로 번졌다. ${WALK} 불붙은 칸 ${r.fire.length}.`, 'bad');
      const out = r.fire.splice(0, P.riotHands);
      journal(g, `일손이 불 ${out.length}칸을 껐다. 남은 불 ${r.fire.length}칸.${r.fire.length === 0 ? ' 불이 모두 꺼졌다. 그을음과 부서진 선반이 남았다.' : ''}`, r.fire.length === 0 ? 'good' : 'bad');
      notes.push(`일손이 불 ${out.length}칸을 껐다. 남은 불 ${r.fire.length}칸, 불이 지나간 칸 ${r.scorched.length}.`);
    }
    if (r.spilled > 0 && r.fire.length === 0) {
      notes.push(`엎어진 물건 ${r.spilled}더미를 치웠다.${r.scorched.length > 0 ? ' 그을음과 부서진 선반은 남는다.' : ''}`);
      r.spilled = 0;
    }
    // 물리친 항의: 정한 구간이 지나도 긴장이 항의 문턱 위면(풀리지 않았으면) 다시 온다. 내려갔으면 풀린 것이다.
    let again = false;
    if (r.ignoredAt !== undefined && g.seg - r.ignoredAt >= LADDER.ignoreAgain) {
      again = now >= line;
      delete r.ignoredAt;
    }
    if (((prev < line && now >= line) || skipped || again) && !g.cards.some(c => c.kind === 'protest')) {
      r.protests += 1;
      addCard(g, { kind: 'protest', comm: 'tail', text: 'protest' });
    }
  }
  if (r.scorched.length !== scorchedBefore) refreshSit(g);
}
