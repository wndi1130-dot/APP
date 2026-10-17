import { bumpRel } from '../ledger';
import type { Comm } from '../data';
import { onDeath } from '../death';
import { noteHeatDeath } from '../death_weight';
import { isGone, journal, lawActive, PROFILES, rnd, situation } from '../state';
import type { Game, Profile } from '../state';
import { D } from './data';

// 「난방 배당」이 서 있는 동안의 값(결정 230·231·232·240·276). 법이 서 있는 정산마다
//  1) 꼬리칸·의무진 관계가 깎이고(상태 줄),
//  2) 온기가 문턱 아래인 칸에서 밤사이 어른 한 사람이 죽을 수 있다(사건 줄).
// 값은 모두 D.heatAlloc* 한 줄에 있다. 관계 벌과 확률이 0이면 옛 동작과 같다. 법을 폐지하면 그 정산부터 아무 일도 없다.

/** 온기 벌을 받는 세 칸: 이 칸마다 정산에 한 번 굴린다(합계 상한은 없다). */
export const HEAT_ALLOC_COMMS: readonly Comm[] = ['tail', 'medtech', 'guard'];

/** 관계 벌을 받는 두 칸(경비대는 안 깎는다) */
const REL_COMMS: readonly Comm[] = ['tail', 'medtech'];

/** 뽑힐 수 있는 나이: 어른(16~64). 아이와 노인은 안 뽑는다. */
const AGE_MIN = 16;
const AGE_MAX = 64;

const REL_NOTE = [
  '난방 배당표가 꼬리칸과 의무칸에 돌았다. 꼬리칸·의무진 관계 −{d}.',
  '배당표를 받은 두 칸의 말수가 줄었다. 꼬리칸·의무진 관계 −{d}.',
  '꼬리칸이 배당표를 적어 두었다. 꼬리칸·의무진 관계 −{d}.',
];

/** 죽은 사람은 수로만 적는다. 이름도 칸 이름도 쓰지 않는다(결정 240·276). */
export function heatAllocDeathLine(n: number): string {
  return n === 1 ? '불을 줄인 밤, 한 사람을 잃었다.' : `난로가 식은 칸에서 밤사이 ${n}명을 잃었다.`;
}

/** 그 칸에서 뽑힐 수 있는 사람: 어른, 대표 아님, 이미 간 사람 아님. */
function pool(g: Game, c: Comm): Profile[] {
  const leader = g.comms[c].leader.name;
  return PROFILES.filter(p => p.community === c && p.age >= AGE_MIN && p.age <= AGE_MAX && p.name !== leader && !isGone(g, p.name));
}

/**
 * 정산 한 번의 난방 배당. 법이 없으면 바로 돌아간다(난수도 안 쓴다).
 * 칸마다 온기가 문턱 아래일 때만 난수를 굴리고, 문턱 위인 칸은 난수 줄을 건드리지 않는다.
 */
export function heatAllocSettle(g: Game, notes: string[]): void {
  if (!lawActive(g, 'heat_quota')) return;
  if (D.heatAllocRel > 0) {
    for (const c of REL_COMMS) bumpRel(g, c, -D.heatAllocRel, 'heat_quota');
    notes.push(REL_NOTE[g.seg % REL_NOTE.length].replace('{d}', String(D.heatAllocRel)));
  }
  if (D.heatAllocDeath <= 0) return;
  let lost = 0;
  for (const c of HEAT_ALLOC_COMMS) {
    if (situation(g, c)[0] >= D.heatAllocWarm) continue;
    if (rnd(g) >= D.heatAllocDeath) continue;
    const people = pool(g, c);
    if (people.length === 0) continue;
    const who = people[Math.floor(rnd(g) * people.length)];
    onDeath(g, c, [who.name], 'other', false, true);
    noteHeatDeath(g, c); // 죽음의 무게(켠 판만): 같은 정산에 이름 없는 뒷사건 하나(결정 354)
    lost += 1;
  }
  if (lost > 0) {
    const line = heatAllocDeathLine(lost);
    journal(g, line, 'bad');
    notes.push(line);
  }
}
