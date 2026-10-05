export const COMMUNITY_IDS = ['tail', 'engine', 'guard', 'medtech', 'front'] as const;
export const COMMUNITY_METRICS = ['warmth', 'ration', 'crowding', 'exposure'] as const;
export const RESOURCE_TYPES = ['coal', 'food', 'medicine', 'luxury'] as const;
export const PERSON_STATES = ['alive', 'injured', 'dead', 'away'] as const;
export const DEAL_TOOLS = ['open', 'favor', 'fetch', 'bribe', 'blackmail'] as const;

// 밸런스 미확정값은 이 파일에서만 조정한다. 인원 분포와 콘텐츠는 생성기가 공급한다.
export const STATE_LIMITS = Object.freeze({
  metric: Object.freeze({ min: 0, max: 100 }),
  resource: Object.freeze({ min: 0, max: 1_000_000 }),
  relation: Object.freeze({ min: -100, max: 100 }),
  cohesion: Object.freeze({ min: 0, max: 1 }),
  votes: Object.freeze({ min: 0, max: 100 }),
  segment: Object.freeze({ min: 0, max: Number.MAX_SAFE_INTEGER }),
  age: Object.freeze({ min: 0, max: 85 }),
});

export const INITIAL_VALUES = Object.freeze({
  seed: 's1',
  segment: 0,
  community: Object.freeze({ warmth: 50, ration: 50, crowding: 0, exposure: 0 }),
  trust: 50,
  tension: 0,
  fear: 0,
  resources: Object.freeze({ coal: 100, food: 100, medicine: 20, luxury: 10 }),
  relation: 0,
  cohesion: 0.75,
  votes: 0,
  personState: 'alive' as const,
  awaySegments: 0,
  returnState: 'alive' as const,
});

export const EFFECT_DEFAULTS = Object.freeze({
  awaySegments: 1,
  // id가 붙은 물건은 개별 물건이다. 변화량의 부호로 소유 목록에 넣거나 뺀다.
  inventoryMode: 'unique_ids' as const,
  // 거래 정의의 deadline은 개시 뒤 구간 수로 해석한다.
  deadlineMode: 'relative' as const,
  maxOpenPromisesPerGroup: 1,
});

export const COUNCIL_DEFAULTS = Object.freeze({
  totalSeats: 100,
  thresholds: Object.freeze({ normal: 51, rule: 67 }),
  participationRate: 1,
  turnoutRounding: 'floor' as const,
  promisedVotesRounding: 'floor' as const,
  cohesionModel: 'bernoulli' as const,
  defectorChoice: 'abstain' as const,
  unpromisedChoice: 'abstain' as const,
});
