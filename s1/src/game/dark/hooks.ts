import { COMMS } from '../data';
import { DEATH_HOOKS } from '../death';
import { COUNCIL_HOOKS } from '../politics';
import type { Comm } from '../data';
import { lawActive, situation } from '../state';
import type { Game } from '../state';
import { B } from './data';
import { investigate, crowdTick, topByClues, truthTick } from './cases';
import { theftTick } from './cards';
import { closeChronicle } from './chronicle';
import { corpseTick, noteDeath } from './corpses';
import { afterVote, darkCouncilOpen, trialPromises } from './council';
import { actAll, escalate, killEmber, newEmber } from './embers';
import { martialSettle } from './martial';
import { executorTick, runOrder } from './order';
import { alive, byName, darkCard, nameOf, repGone, segFull } from './state';

export { darkPowersEnd } from './martial';

// S1b가 S1a 구간 다섯 단계에 붙는 곳(3장 표). turn.ts는 이 파일의 함수만 부른다. g.dark가 없으면 모두 아무 일도 안 한다.
// 죽음(death.ts)과 의회(politics.ts)엔 훅 목록으로 붙는다. 이 파일을 불러오면 등록된다.

DEATH_HOOKS.push((g, c, names) => {
  noteDeath(g, c, names);
  // 희생양, 린치, 처형, 암살로 대표가 죽으면 그 칸이 잇는다(S1b 판에서만. S1a 죽음은 대표를 고르지 않는다).
  if (!g.dark) return;
  for (const name of names) { const p = byName(name); if (p) repGone(g, c, p.id); }
});
COUNCIL_HOOKS.push({ open: darkCouncilOpen, vote: afterVote });

/** 출발 전 운영(nextSegment 끝): 근신이 끝나고, 불씨가 한 칸 오를지 보고(오르면 임박 징후), 열린 수사에 단서가 붙는다.
 * 미룰 수 없는 임박을 먼저 센다. 수사 서류는 필수 결정이 셋이면 다음 구간으로 미룬다(1.2). */
export function darkPrep(g: Game): void {
  const d = g.dark;
  if (!d) return;
  d.confined = d.confined.filter(x => x.until >= g.seg);
  // 근신은 경비대가 지켜보는 자리라 사람마다 구간마다 노출이 붙는다(4.4 표, K02 5).
  g.comms.guard.base[3] += B.confineExpo * d.confined.length;
  escalate(g);
  // 칸이 차서 미뤄 둔 무기고 관행 카드는 자리가 나면 묻는다(폭행 임박이 판에 몇 번 없어 끝내 안 물을 수 있었다).
  if (d.armoryDue && d.armory === null && !segFull(g) && !g.cards.some(k => k.kind === 'dark:armory')) {
    d.armoryDue = false;
    darkCard(g, { kind: 'dark:armory' });
  }
  investigate(g);
  // 5.3 대권이 끝나는 구간(포고할 수 있는 마지막 구간)의 카드. 대권마다 한 번이라 이미 길을 골랐으면 다시 내지 않는다.
  if (lawActive(g, 'emergency_powers') && g.decreeLeft === 1 && d.powersPlan === undefined && !g.cards.some(k => k.kind === 'dark:powers_end')) {
    darkCard(g, { kind: 'dark:powers_end' });
  }
  // 5.4 경비대 재판: 계엄 중 재판에 넘긴 사건마다 한 장(같은 사건 카드가 떠 있으면 다시 내지 않는다).
  if (d.martial) {
    for (const c of d.cases) {
      if (c.status !== 'trial' || c.convicted || !topByClues(g, c) || g.cards.some(k => k.kind === 'dark:gtrial' && k.n === c.id)) continue;
      darkCard(g, { kind: 'dark:gtrial', comm: c.victimComm, n: c.id });
    }
  }
}

/** 이동(출발 직후, 파업으로 서도): 임박했던 일이 일어나고, 사고·밤으로 정한 명령이 실행된다. */
export function darkTravel(g: Game): void {
  if (!g.dark || g.phase === 'end') return;
  actAll(g);
  runOrder(g, 'travel');
}

/** 정차를 풀 때(resolveStop): 열차가 섰으면 하차 명령을 받은 사람이 내리고, 정차로 정한 명령이 실행된다.
 * 지나치면 서지 않으니 하차 명령은 다음 정차까지 기다린다(4.4 '다음 정차에 내려놓는다').
 * 정차 영수증에 따로 붙일 줄(정찰 약속 밖의 죽음·부상)을 돌려준다. */
export function darkStop(g: Game, went: boolean, crew: string[]): string[] {
  const d = g.dark;
  if (!d || !went) return [];
  for (const x of d.exile) {
    // 하차를 기다리는 사이 죽은 사람은 내릴 사람이 아니다(이름이 두 번 남고 인구가 두 번 깎인다).
    if (!alive(g, x.id)) continue;
    const name = nameOf(g, x.id);
    (g.left ??= []).push(name);
    g.comms[x.comm].pop = Math.max(1, g.comms[x.comm].pop - 1);
    repGone(g, x.comm, x.id);
  }
  d.exile = [];
  const line = runOrder(g, 'stop', crew);
  return line ? [line] : [];
}

/** 이번 정차에 걸려 있는 명령의 대상 이름(없으면 null). resolveStop이 같은 사람의 부상을 두 번 세지 않으려고 본다. */
export function darkStopTarget(g: Game): string | null {
  const o = g.dark?.order;
  return o && o.method === 'stop' && o.exeId ? nameOf(g, o.target) : null;
}

/** 정차 산출 배수(연결기 풀기, 보일러 고장). S1a 판이면 1. */
export function darkHaulMult(g: Game): number {
  return g.dark?.haul ?? 1;
}

/** 정산(meters 앞). 시뮬레이터 s1b_dark.py settle과 같은 순서. */
export function darkSettle(g: Game): void {
  const d = g.dark;
  if (!d) return;
  // 계엄의 유지비와 쿠데타 판정이 먼저다(S1a 정산의 신임 위기·긴장 위기보다 앞). 쿠데타로 판이 끝났으면 이후를 건너뛴다.
  martialSettle(g);
  if (g.phase === 'end') return;
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
