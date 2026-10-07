import { COMMS } from '../data';
import { DEATH_HOOKS } from '../death';
import { COUNCIL_HOOKS } from '../politics';
import type { Comm } from '../data';
import { situation } from '../state';
import type { Game } from '../state';
import { B } from './data';
import { investigate, crowdTick, truthTick } from './cases';
import { theftTick } from './cards';
import { closeChronicle } from './chronicle';
import { corpseTick, noteDeath } from './corpses';
import './decree';
import { afterVote, darkCouncilOpen, trialPromises } from './council';
import { actAll, escalate, killEmber, newEmber } from './embers';
import { executorTick, runOrder } from './order';
import { darkCard, nameOf, succeedRep } from './state';

// S1b가 S1a 구간 다섯 단계에 붙는 곳(3장 표). turn.ts는 이 파일의 함수만 부른다. g.dark가 없으면 모두 아무 일도 안 한다.
// 죽음(death.ts)과 의회(politics.ts)엔 훅 목록으로 붙는다. 이 파일을 불러오면 등록된다.

DEATH_HOOKS.push((g, c, names) => noteDeath(g, c, names));
COUNCIL_HOOKS.push({ open: darkCouncilOpen, vote: afterVote });

/** 출발 전 운영(nextSegment 끝): 근신이 끝나고, 열린 수사에 단서가 붙고, 불씨가 한 칸 오를지 본다(오르면 임박 징후). */
export function darkPrep(g: Game): void {
  const d = g.dark;
  if (!d) return;
  d.confined = d.confined.filter(x => x.until >= g.seg);
  investigate(g);
  escalate(g);
}

/** 이동(출발 직후, 파업으로 서도): 임박했던 일이 일어나고, 사고·밤으로 정한 명령이 실행된다. */
export function darkTravel(g: Game): void {
  if (!g.dark || g.phase === 'end') return;
  actAll(g);
  runOrder(g, 'travel');
}

/** 정차를 풀 때(resolveStop): 하차 명령을 받은 사람이 내리고, 내렸으면 정차로 정한 명령이 실행된다. */
export function darkStop(g: Game, went: boolean, crew: string[]): void {
  const d = g.dark;
  if (!d) return;
  for (const x of d.exile) {
    const name = nameOf(g, x.id);
    (g.left ??= []).push(name);
    g.comms[x.comm].pop = Math.max(1, g.comms[x.comm].pop - 1);
    if (g.comms[x.comm].leader.personId === x.id) succeedRep(g, x.comm);
  }
  d.exile = [];
  if (went) runOrder(g, 'stop', crew);
}

/** 정차 산출 배수(연결기 풀기, 보일러 고장). S1a 판이면 1. */
export function darkHaulMult(g: Game): number {
  return g.dark?.haul ?? 1;
}

/** 정산(meters 앞). 시뮬레이터 s1b_dark.py settle과 같은 순서. */
export function darkSettle(g: Game): void {
  const d = g.dark;
  if (!d) return;
  corpseTick(g);
  crowdTick(g);
  truthTick(g);
  executorTick(g);
  theftTick(g);
  trialPromises(g);
  // 불씨가 꺼진다: 원인이 풀렸거나 8구간 조용했다(4.1).
  for (const e of [...d.embers]) {
    if (e.imm) continue;
    const [w, r] = situation(g, e.who);
    const s = g.comms[e.who];
    const solved = (e.cause === 'fervor' && s.fervor <= 1) || (e.cause === 'grudge' && s.grudge <= 1) || (e.cause === 'lack' && w >= 45 && r >= 45);
    if (solved || e.quiet >= B.quietOut) killEmber(g, e);
  }
  // 불씨가 생긴다(4.1 표). 바닥 관계(floor)와 AI '부추기기'는 둘째 묶음이다.
  const leashed = g.leashes.map(l => l.comm);
  for (const c of COMMS) {
    const s = g.comms[c];
    if (s.fervor >= 2 && d.prevFervor[c] < 2) newEmber(g, c, c === 'guard' ? 'chief' : 'guard', 'fervor');
    if (s.grudge >= 2 && d.prevGrudge[c] < 2) newEmber(g, c, 'aide', 'grudge');
    if (s.grudge >= 3 && d.prevGrudge[c] < 3) hostile(g, c);
    const [w, r] = situation(g, c);
    if (w <= B.starveLine || r <= B.starveLine) {
      d.lackStreak[c] += 1;
      if (d.lackStreak[c] >= 2) {
        d.lackStreak[c] = 0;
        newEmber(g, c, c === 'front' ? 'aide' : 'store', 'lack');
      }
    } else {
      d.lackStreak[c] = 0;
    }
    // 목줄이 끊겼다, 뇌물이 들켰다: 그 대표가 열차장을 노린다.
    if (d.prevLeash.includes(c) && !leashed.includes(c)) newEmber(g, c, 'chief', 'leash');
    if (s.disgraced && !d.prevDisgraced.includes(c)) newEmber(g, c, 'chief', 'bribe');
  }
  // 불신임 동의 조건(제안 (6)): 신임 30 아래로 2구간.
  d.lowTrust = g.trust < 30 ? d.lowTrust + 1 : 0;
  d.prevFervor = Object.fromEntries(COMMS.map(c => [c, g.comms[c].fervor])) as Record<Comm, number>;
  d.prevGrudge = Object.fromEntries(COMMS.map(c => [c, g.comms[c].grudge])) as Record<Comm, number>;
  d.prevLeash = leashed;
  d.prevDisgraced = COMMS.filter(c => g.comms[c].disgraced);
  d.haul = 1;
}

/** 적의 3이 된 칸의 대표가 다음 회기에 불신임을 올리겠다고 한다(4.6 카드, 제안 (6)). 한 대표에 한 번. */
function hostile(g: Game, c: Comm): void {
  const d = g.dark!;
  const who = g.comms[c].leader.personId;
  if (d.confLeader === who || g.cards.some(k => k.kind === 'dark:hostile')) return;
  darkCard(g, { kind: 'dark:hostile', comm: c, who });
}

/** 판이 끝날 때(어느 길로 끝나든): 일지 끝에 H7 숫자 한 줄. 두 번 불려도 한 번만 적는다. */
export function darkFinish(g: Game): void {
  if (g.dark) closeChronicle(g);
}
