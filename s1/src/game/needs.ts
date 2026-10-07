import { LAWS, LAW_IDS } from './data';
import type { LawId } from './data';
import { addCard, clamp, journal, lawActive } from './state';
import type { Game } from './state';

// 법 요구(2026-10-07 사용자 후기, 프로스트펑크 2식): 문제가 생겼는데 그 문제를 다루는 법이 없으면
// 먼저 "이런 법이 필요하다는 목소리가 커진다"고 예고하고, 기한까지 어느 법이든 정하지 않으면 구간마다 손해가 난다.
// 같은 묶음의 어느 법이든 통과하면 요구가 풀린다. 숫자는 제안(시험값)이다.

export const NEED_IDS = ['coal', 'food', 'corpse', 'med'] as const;
export type NeedId = typeof NEED_IDS[number];

export interface NeedState {
  /** 요구가 시작된 구간 */
  since: number;
  /** 이 구간의 정산까지 법이 없으면 손해가 시작된다 */
  due: number;
  /** 손해가 난 횟수 */
  hits: number;
  /** 열차장이 기한 안에 정하겠다고 약속했다(기한 +1, 어기면 신임 −8·긴장 +5) */
  promised?: boolean;
}

/** 약속을 어기면 한 번 잃는 것(제안). */
export const NEED_PROMISE = { trust: 8, tension: 5 } as const;

interface NeedDef {
  group: string;
  title: string;
  open: (g: Game) => boolean;
  warn: string;
  hit: string;
  apply: (g: Game, hits: number) => void;
}

/** 예고에서 손해까지. 회기가 3구간마다라 기한 안에 정기 회기가 한 번은 들어온다. */
export const NEED_GRACE = 3;

export const NEEDS: Record<NeedId, NeedDef> = {
  coal: {
    group: '추위', title: '난방을 정하는 법', open: g => g.coal <= 50,
    warn: '석탄 더미가 눈에 띄게 줄었다. 칸마다 "누가 얼마나 때는지 정하자"는 말이 돈다.',
    hit: '난방을 정한 법이 없어 칸마다 제멋대로 난로를 땐다.',
    apply: (g, n) => { g.coal -= 3 + n; g.tension = clamp(g.tension + 3, 0, 100); },
  },
  food: {
    group: '식량', title: '배급을 정하는 법', open: g => g.food <= 50,
    warn: '식량 상자가 가벼워졌다. 배급 줄에서 "정해진 몫을 달라"는 소리가 커진다.',
    hit: '배급을 정한 법이 없어 줄에서 주먹이 오가고 몇 상자가 사라졌다.',
    apply: (g, n) => { g.food = Math.max(0, g.food - (3 + n)); g.tension = clamp(g.tension + 3, 0, 100); },
  },
  corpse: {
    group: '시신', title: '시신을 다루는 법', open: g => g.corpseIssue,
    warn: '시신이 칸 끝에 덮여 있다. 어떻게 할지 정해 달라는 말이 모든 칸에서 나온다.',
    hit: '정한 법이 없어 사람들이 알아서 시신을 선로에 던진다. 무리가 냄새를 따라온다.',
    apply: (g) => { g.thrown += 1; g.tension = clamp(g.tension + 3, 0, 100); },
  },
  med: {
    group: '의료', title: '치료 순서를 정하는 법', open: g => g.injured >= 4,
    warn: '의무칸 침상이 찼다. 누구부터 치료할지 정해 달라고 의무진이 묻는다.',
    hit: '치료 순서를 정한 법이 없어 침상을 두고 다툼이 났다. 의무진이 지쳐 간다.',
    apply: (g, n) => { g.comms.medtech.rel = clamp(g.comms.medtech.rel - (3 + n), -100, 100); g.tension = clamp(g.tension + 2, 0, 100); },
  },
};

export function needLaws(id: NeedId): LawId[] {
  return LAW_IDS.filter(l => LAWS[l].group === NEEDS[id].group);
}

/** 이 법이 풀 수 있는 지금의 요구. */
export function needOf(g: Game, law: LawId): { id: NeedId; state: NeedState } | null {
  for (const id of NEED_IDS) {
    const state = g.needs?.[id];
    if (state && LAWS[law].group === NEEDS[id].group) return { id, state };
  }
  return null;
}

/** 정산 때 부른다: 요구를 열고, 기한이 지난 요구에 손해를 주고, 풀린 요구를 닫는다. */
export function needTick(g: Game, notes: string[]): void {
  g.needs ??= {};
  for (const id of NEED_IDS) {
    const def = NEEDS[id];
    const settled = needLaws(id).some(l => lawActive(g, l));
    const state = g.needs[id];
    if (settled || !def.open(g)) {
      if (state && settled) journal(g, `${def.title}이 정해지자 요구가 잦아들었다.`, 'good');
      if (state && settled && state.promised && state.hits === 0) {
        g.trust = clamp(g.trust + 3, 0, 100);
        journal(g, '열차장이 약속을 지켰다.', 'good');
      }
      delete g.needs[id];
      continue;
    }
    if (!state) {
      g.needs[id] = { since: g.seg, due: g.seg + NEED_GRACE, hits: 0 };
      addCard(g, { kind: 'need_warn', text: id });
      journal(g, `${def.title}이 필요하다는 목소리가 커진다(${NEED_GRACE}구간 안에).`, 'bad');
      continue;
    }
    if (g.seg < state.due) continue;
    if (state.promised && state.hits === 0) {
      g.trust = clamp(g.trust - NEED_PROMISE.trust, 0, 100);
      g.tension = clamp(g.tension + NEED_PROMISE.tension, 0, 100);
      notes.push('열차장이 약속을 어겼다.');
      journal(g, `${def.title}을 정하겠다던 열차장의 약속은 지켜지지 않았다.`, 'bad');
    }
    def.apply(g, state.hits);
    if (state.hits === 0) addCard(g, { kind: 'info', who: '기한이 지났다', text: `${def.hit} 법을 정할 때까지 구간마다 되풀이된다.` });
    state.hits += 1;
    g.trust = clamp(g.trust - 2, 0, 100);
    notes.push(def.hit);
    journal(g, def.hit, 'bad');
  }
}
