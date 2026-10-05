import type { Effect } from '../../core';
import { GROUP_META, METRIC_LABELS, RESOURCE_LABELS } from './groups';

/** 부호가 있는 수. 빼기는 타이포그래피 빼기표(U+2212)를 쓴다. */
export function signed(value: number): string {
  if (value > 0) return `+${value}`;
  if (value < 0) return `−${Math.abs(value)}`;
  return '0';
}

function groupName(id: string): string {
  return Object.hasOwn(GROUP_META, id) ? GROUP_META[id as keyof typeof GROUP_META].name : id;
}

/**
 * 선택지 아래에 보여줄 효과 미리보기. 숨은 수치(공포, 결속도, 약속표)와
 * 흐름 효과(플래그, 후속 사건, 거래, 일대기)는 보여주지 않으므로 null이다.
 */
export function effectLabel(effect: Effect): string | null {
  switch (effect.type) {
    case 'coal': case 'food': case 'medicine': case 'luxury':
      return `${RESOURCE_LABELS[effect.type]} ${signed(effect.amount)}`;
    case 'community.warmth': case 'community.ration': case 'community.crowding': case 'community.exposure': {
      const metric = effect.type.slice('community.'.length) as keyof typeof METRIC_LABELS;
      return `${groupName(effect.target)} ${METRIC_LABELS[metric]} ${signed(effect.amount)}`;
    }
    case 'relation':
      return `${groupName(effect.target)} 관계 ${signed(effect.amount)}`;
    case 'trust':
      return `신임 ${signed(effect.amount)}`;
    case 'tension':
      return `긴장 ${signed(effect.amount)}`;
    default:
      return null;
  }
}

export function effectSummary(effects: readonly Effect[]): string[] {
  return effects.map(effectLabel).filter((label): label is string => label !== null);
}

export function percent(value: number): string {
  return `${Math.round(value * 100)}%`;
}
