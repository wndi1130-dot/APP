import type { Comm } from '../data';

// S1b 어두운 길의 숫자(s1b_dark_path.md 4장·9장·10장, 시뮬레이터 s1b_dark.py의 Q). 모두 제안이다.
// 시뮬레이터(tools/s1b_sim.ts)가 --set으로 바꿔 민감도를 보므로 const 객체 하나에 모은다.

export const B = {
  // 5.3 정기 신임 표결(사용자 결정 '정기 투표', 숫자는 제안: 6차 시뮬레이션). 부결의 결과는 council.ts confFailed 한 곳.
  confEvery: 3, confPassTrust: 5, confFailTrust: 5, confFailLock: 1,
  // 4.1 불씨
  emberP: 1.0, rivalP: 0.2, emberMax: 2, violentCap: 3, quietOut: 8, harmCap: 6,
  escBase: 0.32, escLack: 0.1, escOpp: 0.1, escGuard: 0.15, escPatrol: 0.1, escMin: 0.05, escMax: 0.65,
  lackLine: 25, starveLine: 20, theftP: 0.3,
  // 4.1 사다리
  threatTension: 1, threatFear: 2, threatRel: 3,
  assaultTension: 3, assaultDeath: 0.2, assaultDeathArmory: 0.1,
  assnTension: 3, assnBase: 0.5, assnGuard: 0.2, assnGuardCap: 0.2,
  // 4.2 경비
  guardLen: 2, guardMax: 2, guardFear: 2, guardExpo: 3, guardPair: 2, confineExpo: 2,
  /** 들킨 성공 암살을 덮을 때(경비대 입막음, 제안 PR 41 리뷰) */
  hushFear: 5, hushExpo: 3,
  // 4.3 사보타주
  boilerCoal: 4, boilerBreak: 0.1, couplingCoal: 3, couplingHaul: 0.7, couplingFear: 5,
  poisonFood: 5, poisonSick: 0.2, heatingWarm: 15, heatingSegs: 2, armorCut: 0.5,
  // 4.4 수사
  clueTrue: 0.4, clueCap: 0.75, falseMult: 0.5, falseMultFear: 0.7, coldCase: 8,
  revealP: 0.1, revealWindow: 6, summaryFear: 5, summaryRel: 2,
  // 4.5 군중
  clockDeath: 2, clockInjury: 3, scapegoatDeath: 0.6, protectHurt: 0.3,
  // 4.6 암살 명령
  orderBase: 0.55, orderCap: 2, orderCaughtFail: 0.5, orderNamesChief: 0.7, execBlackmail: 0.2,
  // 9장 칸 안의 시신
  corpseRise: 0.25, vigilGuarded: 0.1, carMiss: 0.1,
  // 10.2 결과: 도착했고 죽음이 이만큼 이하면 '살렸다'
  savedDeaths: 6,
};

/** 처형을 어디서 고를 수 있나(2장 4번, 사용자 답 대기. 추천 '재판으로만'). 답이 바뀌면 이 값 하나만 고친다. */
export type ExecutionRule = 'none' | 'trial' | 'trial_and_summary';
export const EXECUTION: { rule: ExecutionRule } = { rule: 'trial' };

/** 열차 안 칸 순서(꼬리 → 기관). 사건 칸 옆 칸을 셀 때 쓴다(ui/common CARS 순서와 같다). */
export const TRAIN_ORDER: Comm[] = ['tail', 'medtech', 'guard', 'front', 'engine'];

/** 10.2 수단 점수(열차장이 고른 일의 무게). 둘째 묶음(계엄·탄압)의 값도 자리만 둔다. */
export const MEANS = {
  assn_ordered: 4, executions: 3, scapegoats: 3, frames: 3, exiles: 2, lynch_allowed: 2, summary: 2,
  trial_bought: 2, blackmail: 1, harsh_chosen: 1,
} as const;
export type MeansKey = keyof typeof MEANS;
/** 10.1 선을 넘는 선택 */
export const CROSSINGS: MeansKey[] = ['assn_ordered', 'scapegoats', 'lynch_allowed', 'exiles', 'executions', 'trial_bought', 'frames'];
/** 10.2 중대한 선택(합 아래에 숨지 않는다) */
export const GRAVE: MeansKey[] = ['assn_ordered', 'executions', 'scapegoats', 'frames'];
