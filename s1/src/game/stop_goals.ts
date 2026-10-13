export const STOP_GOALS = ['coal', 'food', 'medicine', 'materials'] as const;
export type StopGoal = typeof STOP_GOALS[number];
export type GoalStatus = 'done' | 'part' | 'retreat' | 'failed';
export type StopEnd = 'departed' | 'limit' | 'wiped';

export const GOAL_NAME: Record<StopGoal, string> = {
  coal: '석탄', food: '식량', medicine: '의약품', materials: '자재',
};
// 추정: 출발 전에 고정할 달성량이며 추천 부족량과는 별개다.
export const GOAL_AMOUNT: Readonly<Record<StopGoal, number>> = {
  coal: 12, food: 12, medicine: 4, materials: 6,
};
// 추정: 명세 값 표의 추천값이다. 장소 추첨이나 난수를 사용하지 않는다.
export const GOAL_SUGGEST = {
  forecastSegments: 2, medicine: 8, materials: 10, materialWeight: 5,
  placeBuffer: 25, targetMultiplier: 3,
} as const;

export interface GoalStock {
  coal: number;
  food: number;
  medicine: number;
  wood: number;
  scrap: number;
  parts?: number;
}
export interface GoalSuggestion {
  stock: GoalStock;
  consumption: { coal: number; food: number };
  weights: { coal: number; food: number; medicine: number; wood: number; scrap: number };
  materialNeed?: number;
  selected?: string | null;
}

export function isStopGoal(value: unknown): value is StopGoal {
  return typeof value === 'string' && STOP_GOALS.some(goal => goal === value);
}

function nonnegative(value: number): number {
  if (!Number.isFinite(value) || value < 0) throw new Error('수량은 유한한 0 이상 값이어야 한다');
  return value;
}

/** 장소 산출이 없는 선택은 제외하고, 유효한 수동 선택을 먼저 보존한다. */
export function suggestGoal(input: GoalSuggestion): StopGoal | undefined {
  const weights: Record<StopGoal, number> = {
    coal: nonnegative(input.weights.coal), food: nonnegative(input.weights.food),
    medicine: nonnegative(input.weights.medicine),
    materials: (nonnegative(input.weights.wood) + nonnegative(input.weights.scrap)) * GOAL_SUGGEST.materialWeight,
  };
  const valid = STOP_GOALS.filter(goal => weights[goal] > 0);
  if (isStopGoal(input.selected) && weights[input.selected] > 0) return input.selected;
  const required: Record<StopGoal, number> = {
    coal: Math.max(1, nonnegative(input.consumption.coal) * GOAL_SUGGEST.forecastSegments),
    food: Math.max(1, nonnegative(input.consumption.food) * GOAL_SUGGEST.forecastSegments),
    medicine: GOAL_SUGGEST.medicine,
    materials: Math.max(GOAL_SUGGEST.materials, nonnegative(input.materialNeed ?? 0)),
  };
  const stock: Record<StopGoal, number> = {
    coal: nonnegative(input.stock.coal), food: nonnegative(input.stock.food),
    medicine: nonnegative(input.stock.medicine),
    materials: nonnegative(input.stock.wood) + nonnegative(input.stock.scrap),
  };
  const score = (goal: StopGoal): number => Math.max(0, required[goal] - stock[goal]) / required[goal]
    * weights[goal] / (weights[goal] + GOAL_SUGGEST.placeBuffer);
  // 동점은 목록 순서로 남긴다. 부품·덤의 양은 점수에 들어가지 않는다.
  const deficient = valid.some(goal => score(goal) > 0);
  return valid.reduce<StopGoal | undefined>((best, goal) => {
    const value = deficient ? score(goal) : weights[goal];
    const previous = best === undefined ? -1 : deficient ? score(best) : weights[best];
    return value > previous ? goal : best;
  }, undefined);
}

/** 소비 뒤 장부 대신 이번 정차의 획득만 센다. 자재에는 부품을 넣지 않는다. */
export function goalStatus(
  goal: StopGoal | null, required: number, gains: Partial<GoalStock>, end: StopEnd = 'departed',
): GoalStatus {
  nonnegative(required);
  if (end === 'wiped') return 'failed';
  if (goal === null) return 'retreat';
  const earned = goal === 'materials'
    ? nonnegative(gains.wood ?? 0) + nonnegative(gains.scrap ?? 0)
    : nonnegative(gains[goal] ?? 0);
  if (earned >= required) return 'done';
  return earned > 0 ? 'part' : 'retreat';
}

/** 총량을 먼저 반올림하고 목재를 반올림한 나머지를 고철로 보존한다. */
export function splitMaterials(total: number, woodWeight: number, scrapWeight: number): { wood: number; scrap: number } {
  const amount = Math.round(nonnegative(total));
  const sum = nonnegative(woodWeight) + nonnegative(scrapWeight);
  if (!Number.isSafeInteger(amount)) throw new Error('자재 총량이 너무 크다');
  if (sum === 0) {
    if (amount > 0) throw new Error('산출이 없는 장소에 자재를 배분할 수 없다');
    return { wood: 0, scrap: 0 };
  }
  const wood = Math.round(amount * woodWeight / sum);
  return { wood, scrap: amount - wood };
}
