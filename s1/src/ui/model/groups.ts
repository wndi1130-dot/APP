import type { CommunityId, CommunityMetric, ResourceType } from '../../core';

// 공동체와 세력의 표시 정보. 색은 어두운 바탕(#171a1d~#1e2226) 위에서
// 인접 쌍의 색각 이상 구분(OKLab ΔE ≥ 8)과 3:1 대비를 확인한 값이다.
// 반원 의석의 왼쪽 → 오른쪽 순서와 같아야 그 검증이 유효하다.

export const DUMMY_FACTION_ID = 'faction_restore';
export type GroupId = CommunityId | typeof DUMMY_FACTION_ID;

export interface GroupMeta {
  id: GroupId;
  kind: 'community' | 'faction';
  /** 칸과 표에 쓰는 짧은 이름. */
  name: string;
  /** 설명에 쓰는 이름(기획서 4장). */
  fullName: string;
  color: string;
}

/** 열차의 뒤 → 앞 순서. 홈의 열차 띠와 반원 의석이 같은 순서를 쓴다. */
export const COMMUNITY_ORDER: readonly CommunityId[] = Object.freeze(['tail', 'medtech', 'guard', 'front', 'engine']);

export const GROUP_META: Readonly<Record<GroupId, GroupMeta>> = Object.freeze({
  tail: { id: 'tail', kind: 'community', name: '꼬리칸', fullName: '꼬리칸 노동자', color: '#187e36' },
  medtech: { id: 'medtech', kind: 'community', name: '기술·의무진', fullName: '기술·의무진', color: '#d06091' },
  guard: { id: 'guard', kind: 'community', name: '경비대', fullName: '경비대', color: '#bd8928' },
  front: { id: 'front', kind: 'community', name: '앞칸', fullName: '앞칸 사람들', color: '#7264c1' },
  engine: { id: 'engine', kind: 'community', name: '기관실', fullName: '기관실 사람들', color: '#db633c' },
  faction_restore: { id: DUMMY_FACTION_ID, kind: 'faction', name: '복원파', fullName: '복원파(더미 세력)', color: '#008f90' },
});

export function groupMeta(id: string): GroupMeta {
  if (!Object.hasOwn(GROUP_META, id)) throw new Error(`모르는 집단입니다: ${id}`);
  return GROUP_META[id as GroupId];
}

/** 표시 순서: 공동체(열차 뒤 → 앞), 그다음 세력. 상태에 없는 집단은 뺀다. */
export function orderedGroupIds(present: Iterable<string>): GroupId[] {
  const set = new Set(present);
  const order: GroupId[] = [...COMMUNITY_ORDER, DUMMY_FACTION_ID];
  return order.filter(id => set.has(id));
}

export const METRIC_LABELS: Readonly<Record<CommunityMetric, string>> = Object.freeze({
  warmth: '온기',
  ration: '배급',
  crowding: '과밀',
  exposure: '위험 노출',
});

export const RESOURCE_LABELS: Readonly<Record<ResourceType, string>> = Object.freeze({
  coal: '석탄',
  food: '식량',
  medicine: '의약품',
  luxury: '사치품',
});

export const RESOURCE_ORDER: readonly ResourceType[] = Object.freeze(['coal', 'food', 'medicine', 'luxury']);

/** 처지 수치의 단계. 색만으로 읽히지 않게 화면은 늘 이 낱말을 함께 쓴다. */
export type Severity = 'good' | 'normal' | 'warning' | 'serious';

export interface MetricLevel {
  word: string;
  severity: Severity;
}

/** 0~100. 온기·배급은 낮을수록, 과밀·위험 노출은 높을수록 나쁘다. 경계값은 임시다. */
export function metricLevel(metric: CommunityMetric, value: number): MetricLevel {
  switch (metric) {
    case 'warmth':
      if (value < 34) return { word: '추움', severity: 'serious' };
      if (value < 67) return { word: '보통', severity: 'normal' };
      return { word: '따뜻함', severity: 'good' };
    case 'ration':
      if (value < 34) return { word: '모자람', severity: 'serious' };
      if (value < 67) return { word: '보통', severity: 'normal' };
      return { word: '넉넉함', severity: 'good' };
    case 'crowding':
      if (value >= 75) return { word: '과밀', severity: 'serious' };
      if (value >= 50) return { word: '붐빔', severity: 'warning' };
      return { word: '여유', severity: 'normal' };
    case 'exposure':
      if (value >= 67) return { word: '높음', severity: 'serious' };
      if (value >= 34) return { word: '보통', severity: 'normal' };
      return { word: '낮음', severity: 'normal' };
  }
}

/** 관계(−100~100)를 불만·중립·지지로 나눈다. 경계값은 임시다. */
export type Stance = 'discontent' | 'neutral' | 'support';
export const STANCE_THRESHOLD = 20;

export function relationStance(relation: number): Stance {
  if (relation <= -STANCE_THRESHOLD) return 'discontent';
  if (relation >= STANCE_THRESHOLD) return 'support';
  return 'neutral';
}

export const STANCE_LABELS: Readonly<Record<Stance, string>> = Object.freeze({
  discontent: '불만',
  neutral: '중립',
  support: '지지',
});

/** 처지에서 가장 급한 요구를 고른다(기획서 4장: 요구는 처지에서 나온다). */
export function urgentNeed(state: Record<CommunityMetric, number>): CommunityMetric {
  const badness: Record<CommunityMetric, number> = {
    warmth: 100 - state.warmth,
    ration: 100 - state.ration,
    crowding: state.crowding,
    exposure: state.exposure,
  };
  const order: CommunityMetric[] = ['warmth', 'ration', 'crowding', 'exposure'];
  return order.reduce((worst, metric) => (badness[metric] > badness[worst] ? metric : worst), order[0]);
}
