import { COMM_NAME } from './data';
import type { Comm } from './data';
import { journal } from './state';
import type { Game, MotionAgenda, MotionId } from './state';

// 법이 아닌 안건(s1b_dark_path 12.3). 통과하면 바로 일이 일어나고 끝난다. 입장은 stance()가 lean()에서 받아
// 관계 단계와 적의 규칙을 법과 똑같이 얹는다. S1b는 재판, 휴전 서약, 계엄 요청 같은 안건을 이 표에 더한다.

export type MotionRank = 'crisis' | 'ratify' | 'confidence' | 'ai' | 'player';

export interface MotionDef {
  need: 51 | 67;
  /** 그 집단의 입장 가운데 물질·이념 몫(−2~+2씩) */
  lean: (g: Game, c: Comm, a: MotionAgenda) => { mat: number; ideo: number };
  title: (a: MotionAgenda) => string;
  /** 표결 전에 보여 주는 바뀌는 것 */
  changes: (g: Game, a: MotionAgenda) => string[];
  onPass: (g: Game, a: MotionAgenda) => void;
  onFail: (g: Game, a: MotionAgenda) => void;
  /** 안건 순서: crisis > ratify > confidence > ai > player */
  rank: MotionRank;
}

const hubOf = (g: Game) => (g.hub ??= { warned: [], stash: {}, agreed: [] });

/** S1b(dark/council.ts)가 재판·불신임을 불러올 때 더한다. 그래서 타입은 모든 MotionId를 품되 값은 share부터 시작한다. */
export const MOTIONS = {
  // 라이프치히 마지막 회기(first_leg_story 7.7). 통과하면 몫을 들고 평화롭게 떠나고, 부결되면 허브에서 몰래 가져가려 한다.
  share: {
    need: 51,
    lean: (_g, c, a) => ({ mat: c === a.subject ? 2 : -1, ideo: 0 }),
    title: a => `${a.subject ? COMM_NAME[a.subject] : ''} 몫 나누기`,
    changes: (_g, a) => [
      `통과: ${a.subject ? COMM_NAME[a.subject] : '그 칸'}의 떠날 사람이 1인당 몫만 들고 라이프치히에서 내린다`,
      '부결: 라이프치히에서 몰래 더 가져가려 한다. 그때 보낼지, 설득할지, 막을지 고른다',
    ],
    onPass: (g, a) => {
      if (!a.subject) return;
      const hub = hubOf(g);
      if (!hub.agreed.includes(a.subject)) hub.agreed.push(a.subject);
      journal(g, `${COMM_NAME[a.subject]}이(가) 라이프치히에서 몫을 받아 내리기로 했다.`);
    },
    onFail: (g, a) => {
      if (!a.subject) return;
      journal(g, `${COMM_NAME[a.subject]}의 몫 요구가 부결됐다. 그 칸 사람들이 말을 아낀다.`, 'bad');
    },
    rank: 'crisis',
  },
} as Record<MotionId, MotionDef>;

/** 회기마다 안건을 내는 곳(hub.ts 등이 등록한다). 돌려준 안건은 rank 순서대로 법 안건 앞뒤에 놓인다. */
export const MOTION_SOURCES: ((g: Game) => MotionAgenda[])[] = [];

export function motionsNow(g: Game): MotionAgenda[] {
  return MOTION_SOURCES.flatMap(f => f(g));
}
