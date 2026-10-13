import { COMMS, P } from './data';
import { onDeath } from './death';
import { refreshSit } from './domestic/sit';
import { addCard, isGone, journal, PROFILES, rnd, riotStart } from './state';
import type { Game, RiotState } from './state';
import { isWounded, noteInjury } from './wounds';

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
  const starts = !ongoing && prev < from && now >= from;
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
    if (prev < P.protestFrom && now >= P.protestFrom && !g.cards.some(c => c.kind === 'protest')) {
      r.protests += 1;
      addCard(g, { kind: 'protest', comm: 'tail', text: 'protest' });
    }
  }
  if (r.scorched.length !== scorchedBefore) refreshSit(g);
}
