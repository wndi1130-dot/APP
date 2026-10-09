import { COMMS } from './data';
import type { Comm } from './data';
import { onDeath } from './death';
import { josa } from './josa';
import { hash } from './omens';
import { addCard, isGone, journal, PROFILES, situation } from './state';
import type { Game, Profile } from './state';

// 재난 시제품(docs/design/briefs/events_disasters.md 4장 D1 눈보라, D2 한파). 기본은 꺼져 있다.
// 켜는 길: enableDisasters(g). 꺼진 판은 이 파일의 어떤 함수도 상태를 만들거나 난수를 쓰지 않는다.
// 굴림은 판 씨앗으로 만든 해시라 난수 흐름(g.rng)을 건드리지 않는다(켠 판과 끈 판이 재난 말고는 같은 길로 간다).
// 정기 한파(P.winterEvery)는 계절이 깊어지는 시계로 그대로 두고, 재난은 그 위에 얹는다.
// 숫자는 시제품 값(제안)이고 시뮬로 다시 잰다. tools/s1c_sim.ts의 --dz=키:값으로 바꿀 수 있다.

export type DisasterKind = 'blizzard' | 'cold';
export interface DisasterState {
  kind: DisasterKind;
  stage: 'warn' | 'active';
  left: number;
  /** 대비 카드에서 고른 것. 절반으로 덜 깎인다 */
  prep?: 'coal' | 'huddle';
  /** 대비하지 않고 갔다(그냥 간다를 골랐거나 카드를 안 골랐다). 이어지는 동안 사람이 죽을 수 있다 */
  unprepared?: boolean;
  /** 시작할 때 모든 칸 온기에서 뺀 양. 끝날 때 같은 양을 돌려준다 */
  warmDrop?: number;
  /** 이 재난에서 이미 한 명이 죽었다 */
  died?: boolean;
}

export const DZ = {
  /** 정산마다 눈보라가 걸릴 확률, 한파가 걸릴 확률(한 구간에 하나만) */
  blizzardP: 0.07, coldP: 0.06,
  /** active로 이어지는 구간 수 */
  blizzardLen: 2, coldLen: 3,
  /** active 동안만 모든 칸 기준 온기에서 빼는 값(끝나면 돌려준다) */
  blizzardWarm: 5, coldWarm: 8,
  /** active 구간마다 더 드는 석탄 */
  blizzardCoal: 1, coldCoal: 1,
  /** 이 구간부터 굴린다 / 재난이 끝난 뒤 이만큼 구간이 지나야 다시 굴린다 */
  fromSeg: 3, gap: 2,
  /** 대비 카드: 석탄을 쌓아 두는 값, 칸을 모아 잘 때 꼬리칸·앞칸 과밀과 긴장, 대비하면 온기 감소에 곱하는 값 */
  prepCoal: 2, huddleCrowd: 10, huddleTension: 2, prepWarmMult: 0.5,
  /** 대비하지 않고 간 재난: active 구간마다 한 명이 죽을 확률, 판 전체 재난 사망 상한(재난 하나에 많아야 한 명) */
  deathP: 0.25, deathCap: 2,
  /** 이 나이 미만은 고르지 않는다 */
  deathMinAge: 12,
};

export const DISASTER_NAME: Record<DisasterKind, string> = { blizzard: '눈보라', cold: '한파' };
const WARN_LINE: Record<DisasterKind, string> = {
  blizzard: '기관장: 서쪽 하늘이 낮다. 내일은 눈보라다.',
  cold: '무전: 북쪽에서 찬 공기가 내려온다.',
};
const END_LINE: Record<DisasterKind, string> = { blizzard: '눈보라가 그쳤다.', cold: '한파가 물러났다.' };

export const lenOf = (k: DisasterKind): number => (k === 'blizzard' ? DZ.blizzardLen : DZ.coldLen);
export const warmOf = (k: DisasterKind): number => (k === 'blizzard' ? DZ.blizzardWarm : DZ.coldWarm);
export const coalOf = (k: DisasterKind): number => (k === 'blizzard' ? DZ.blizzardCoal : DZ.coldCoal);

/** 판에 재난을 켠다. S1a·S1b·S1c 어느 판에든 얹을 수 있다. */
export function enableDisasters(g: Game): void {
  g.disasters = true;
  g.disasterStats = { blizzard: 0, cold: 0 };
  g.disasterDeaths = 0;
}

export function disasterOn(g: Game): boolean {
  return !!g.disasters;
}

/** 지금 눈보라가 몰아치는 중인가(정차 위험 보기가 가려진다) */
export function blizzardActive(g: Game): boolean {
  return g.disaster?.kind === 'blizzard' && g.disaster.stage === 'active';
}

/** 이번 구간에 재난이 더 얹는 석탄(forecast가 읽는다). 출발 때 active가 되니 예고 상태도 센다. 재난이 없거나 석탄을 쌓아 뒀으면 0 */
export function disasterCoal(g: Game): number {
  return g.disasters && g.disaster && g.disaster.prep !== 'coal' ? coalOf(g.disaster.kind) : 0;
}

/** 출발 때: 예고 상태면 대비를 가려 active로 넘기고 모든 칸 온기를 깎는다(끝나면 돌려준다). 꺼진 판에선 아무 일도 안 한다. */
export function disasterDepart(g: Game): void {
  const d = g.disaster;
  if (!g.disasters || !d || d.stage !== 'warn') return;
  // 대비 카드를 안 고르고 넘어왔으면 대비하지 않은 것으로 본다.
  if (!d.prep && !d.unprepared) d.unprepared = true;
  g.cards = g.cards.filter(c => c.kind !== 'disaster_prep');
  d.stage = 'active';
  d.left = lenOf(d.kind);
  const drop = warmOf(d.kind) * (d.prep ? DZ.prepWarmMult : 1);
  d.warmDrop = drop;
  for (const c of COMMS) g.comms[c].base[0] -= drop;
  const name = DISASTER_NAME[d.kind];
  journal(g, `${name}${josa(name, '이/가')} 시작됐다. 모든 칸 온기 −${drop}${d.prep === 'coal' ? '.' : `, ${d.left}구간 동안 구간마다 석탄 +${coalOf(d.kind)}.`}`, 'bad');
}

/** 온기가 가장 낮은 칸에서, 대표와 이름 있는 인물(대표의 원래 자리, S1b 측근)과 어린아이를 뺀 사람 하나를 조건만으로 고른다. */
export function disasterVictim(g: Game): { comm: Comm; person: Profile } | null {
  const rank = [...COMMS].sort((a, b) => situation(g, a)[0] - situation(g, b)[0] || COMMS.indexOf(a) - COMMS.indexOf(b));
  const named = new Set<string>(COMMS.flatMap(c => [g.comms[c].leader.name, g.comms[c].sick?.rep.name ?? '']));
  const staff = g.dark ? [g.dark.staff.deputy, g.dark.staff.ration] : [];
  for (const c of rank) {
    const pool = PROFILES.filter(p => p.community === c && !isGone(g, p.name) && p.age >= DZ.deathMinAge && !named.has(p.name) && !staff.includes(p.id));
    if (pool.length === 0) continue;
    return { comm: c, person: pool[hash(`${g.seed}|${g.seg}|dz-who`) % pool.length] };
  }
  return null;
}

/** 정산 끝: active 구간이면 대비하지 않은 재난의 밤 사고를 굴리고, 구간을 하나 지나 보내고, 다 지났으면 끝내 온기를 돌려준다. 재난이 없으면 굴린다. */
export function disasterSettle(g: Game): void {
  if (!g.disasters) return;
  const d = g.disaster;
  if (d?.stage === 'active') {
    if (d.unprepared && !d.died && (g.disasterDeaths ?? 0) < DZ.deathCap && hash(`${g.seed}|${g.seg}|dz-death`) / 4294967296 < DZ.deathP) {
      const v = disasterVictim(g);
      if (v) {
        d.died = true;
        g.disasterDeaths = (g.disasterDeaths ?? 0) + 1;
        journal(g, `예고를 듣고도 그냥 갔다. ${v.person.name}${josa(v.person.name, '이/가')} 밤사이 얼어 숨졌다.`, 'bad');
        // 열차장이 알고 고른 결과라 죄책감 쪽 'warned'로 남긴다(death.ts). 그 뒤는 다른 죽음과 같은 길(유품 카드, 시신 처리)이다.
        onDeath(g, v.comm, [v.person.name], 'warned');
      }
    }
    d.left -= 1;
    if (d.left <= 0) {
      for (const c of COMMS) g.comms[c].base[0] += d.warmDrop ?? 0;
      journal(g, END_LINE[d.kind], 'good');
      g.disasterEnd = g.seg;
      delete g.disaster;
    }
    return;
  }
  if (d) return; // 예고 중
  if (g.seg < DZ.fromSeg || g.seg - (g.disasterEnd ?? -99) < DZ.gap) return;
  const r = hash(`${g.seed}|${g.seg}|disaster`) / 4294967296;
  const kind: DisasterKind | null = r < DZ.blizzardP ? 'blizzard' : r < DZ.blizzardP + DZ.coldP ? 'cold' : null;
  if (!kind) return;
  g.disaster = { kind, stage: 'warn', left: 0 };
  (g.disasterStats ??= { blizzard: 0, cold: 0 })[kind] += 1;
  journal(g, WARN_LINE[kind], 'bad');
  addCard(g, { kind: 'disaster_prep', text: kind });
}

