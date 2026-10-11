import { P } from './data';
import type { Comm } from './data';
import { situation } from './state';
import type { Game } from './state';

// 과밀이 병으로 이어지는 고리(결정 060 덧붙임). 과밀 값은 situation(g, c)[2](0~100)이고, 낱말 네 단의 문턱 60·80·95는
// 지금 코드가 이미 쓰는 문턱이다(관계 깎임 60, 위생 점수 80·95). 열병이 시작될 확률(domestic/hygiene.ts)과 상처가 곪을 확률(wounds.ts)이
// 같은 계단 ×0, ×1, ×1.25, ×1.5를 읽어서 화면의 「병 위험」 낱말 하나가 두 규칙을 같이 말한다.

export type CrowdLevel = 0 | 1 | 2 | 3;

export const CROWD_WORD = ['넉넉', '꽉 참', '비좁음', '겹쳐 잠'] as const;
export const SICK_WORD = ['병 위험 낮음', '병 위험 보통', '병 위험 높음', '병 위험 매우 높음'] as const;

export function crowdLevelOf(crowd: number): CrowdLevel {
  return crowd >= P.crowdFrom[2] ? 3 : crowd >= P.crowdFrom[1] ? 2 : crowd >= P.crowdFrom[0] ? 1 : 0;
}

export function crowdLevel(g: Game, c: Comm): CrowdLevel {
  return crowdLevelOf(situation(g, c)[2]);
}

/** 병 위험 배수(0, 1, 1.25, 1.5). 열병과 곪음이 같이 읽는다. */
export function sickMult(g: Game, c: Comm): number {
  return P.crowdMult[crowdLevel(g, c)];
}

/** 이 칸이 이번 구간에 과밀 때문에 열병이 시작될 확률(0~1). 이 카드와 이는 따로 굴린다. */
export function crowdFeverP(g: Game, c: Comm): number {
  return P.crowdFever * sickMult(g, c);
}

/** 이 칸 사람이 다쳤을 때 곪을 확률에 더해지는 몫(0~1). */
export function crowdSepticP(g: Game, c: Comm): number {
  return P.crowdSeptic * sickMult(g, c);
}

/** 화면 줄: 「비좁음 · 병 위험 높음」 */
export function crowdLine(g: Game, c: Comm): string {
  const l = crowdLevel(g, c);
  return `${CROWD_WORD[l]} · ${SICK_WORD[l]}`;
}
