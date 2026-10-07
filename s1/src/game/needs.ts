import { LAWS, LAW_IDS } from './data';
import type { LawId } from './data';
import { COMMS } from './data';
import type { Comm } from './data';
import { addCard, clamp, isGone, journal, lawActive, PROFILES } from './state';
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
  /** 예고 글. 상황 열쇠(얼마나 바닥인지, 몇 번째 요구인지)로 고른다. */
  warn: string[];
  /** 손해 글. 1회째 다툼, 2회째 누가 다친다(이름), 3회째부터 그 칸 대표가 들고 온다(기획 점검 01 2.4). */
  hit: [string, (who: string) => string, (rep: string) => string, string];
  /** 2회째 손해에서 다치는 사람이 나오는 칸 */
  hurtComm: Comm;
  apply: (g: Game, hits: number) => void;
}

/** 예고에서 손해까지. 회기가 3구간마다라 기한 안에 정기 회기가 한 번은 들어온다. */
export const NEED_GRACE = 3;

export const NEEDS: Record<NeedId, NeedDef> = {
  coal: {
    group: '추위', title: '난방을 정하는 법', open: g => g.coal <= 50, hurtComm: 'tail',
    warn: [
      '석탄 더미가 눈에 띄게 줄었다. 칸마다 "누가 얼마나 때는지 정하자"는 말이 돈다.',
      '화부가 석탄 더미에 분필로 줄을 그었다. 그 줄 아래로 내려가면 누가 먼저 끄느냐로 싸움이 난다.',
      '밤마다 난로 앞에서 말다툼이 난다. 남은 석탄을 누가 정할 거냐고 다들 열차장 쪽을 본다.',
    ],
    hit: [
      '난방을 정한 법이 없어 칸마다 제멋대로 난로를 땐다.',
      who => `난로 차례를 두고 다투다 ${who}이(가) 꺼진 칸에서 손가락에 동상을 입었다.`,
      rep => `${rep}이(가) 난방 순번을 다음 회기 거래 조건으로 들고 오겠다고 한다.`,
      '정한 사람이 없으니 석탄은 목소리 큰 칸으로 간다.',
    ],
    apply: (g, n) => { g.coal -= 3 + n; g.tension = clamp(g.tension + 3, 0, 100); },
  },
  food: {
    group: '식량', title: '배급을 정하는 법', open: g => g.food <= 50, hurtComm: 'tail',
    warn: [
      '식량 상자가 가벼워졌다. 배급 줄에서 "정해진 몫을 달라"는 소리가 커진다.',
      '배급 줄이 길어졌다. 국자를 쥔 사람이 누구 편인지 다들 지켜본다.',
      '창고 문 앞에 밤새 누가 서 있었다. 몫을 정해 달라는 쪽지가 문에 붙었다.',
    ],
    hit: [
      '배급을 정한 법이 없어 줄에서 주먹이 오가고 몇 상자가 사라졌다.',
      who => `배급 줄에서 밀치다 ${who}이(가) 넘어져 크게 다쳤다. 상자 몇 개가 또 사라졌다.`,
      rep => `${rep}이(가) 사라진 상자 목록을 들고 왔다. 다음 회기에 따지겠다고 한다.`,
      '정해진 몫이 없으니 줄 앞에 선 사람이 많이 가져간다.',
    ],
    apply: (g, n) => { g.food = Math.max(0, g.food - (3 + n)); g.tension = clamp(g.tension + 3, 0, 100); },
  },
  corpse: {
    group: '시신', title: '시신을 다루는 법', open: g => g.corpseIssue, hurtComm: 'guard',
    warn: [
      '시신이 칸 끝에 덮여 있다. 어떻게 할지 정해 달라는 말이 모든 칸에서 나온다.',
      '덮어 둔 시신 옆에서 아무도 자려 하지 않는다. 누가 치울지 정해 달라고 한다.',
    ],
    hit: [
      '정한 법이 없어 사람들이 알아서 시신을 선로에 던진다. 무리가 냄새를 따라온다.',
      who => `밤에 시신을 내던지다 ${who}이(가) 발판에서 미끄러져 다쳤다. 냄새가 뒤를 따른다.`,
      rep => `${rep}이(가) "시신은 누가 치우느냐"를 다음 회기 첫 말로 꺼내겠다고 한다.`,
      '선로 뒤로 던진 것들이 또 늘었다. 무리가 따라붙는 거리가 줄었다.',
    ],
    apply: (g) => { g.thrown += 1; g.tension = clamp(g.tension + 3, 0, 100); },
  },
  med: {
    group: '의료', title: '치료 순서를 정하는 법', open: g => g.injured >= 4, hurtComm: 'medtech',
    warn: [
      '의무칸 침상이 찼다. 누구부터 치료할지 정해 달라고 의무진이 묻는다.',
      '의무칸 바닥에도 사람이 눕기 시작했다. 의무장이 순서를 정해 달라고 한다.',
    ],
    hit: [
      '치료 순서를 정한 법이 없어 침상을 두고 다툼이 났다. 의무진이 지쳐 간다.',
      who => `침상 다툼을 말리던 ${who}이(가) 밀려 넘어졌다. 의무진이 한 손을 잃었다.`,
      rep => `${rep}이(가) 이대로는 손을 놓겠다고 한다. 다음 회기에 답을 달라고 한다.`,
      '순서가 없으니 목소리 큰 쪽이 먼저 침상에 눕는다.',
    ],
    apply: (g, n) => { g.comms.medtech.rel = clamp(g.comms.medtech.rel - (3 + n), -100, 100); g.tension = clamp(g.tension + 2, 0, 100); },
  },
};

/** 손해 글. 2회째엔 그 칸 사람 하나가 다친다(부상 +1). */
function needHit(g: Game, id: NeedId, hits: number): string {
  const def = NEEDS[id];
  if (hits === 0) return def.hit[0];
  if (hits === 1) {
    const who = PROFILES.find(p => p.community === def.hurtComm && !isGone(g, p.name) && p.age >= 16 && !COMMS.some(c => g.comms[c].leader.name === p.name)
      && (hashName(`${g.seed}:${id}`) + p.name.length) % 3 === 0)
      ?? PROFILES.find(p => p.community === def.hurtComm && !isGone(g, p.name) && p.age >= 16);
    g.injured += 1;
    return def.hit[1](who?.name ?? '한 사람');
  }
  if (hits === 2) return def.hit[2](g.comms[def.hurtComm].leader.name);
  return hits % 2 === 1 ? def.hit[3] : def.hit[0];
}

function hashName(s: string): number {
  let x = 7;
  for (let i = 0; i < s.length; i += 1) x = (x * 31 + s.charCodeAt(i)) >>> 0;
  return x;
}

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
      addCard(g, { kind: 'need_warn', text: id, n: (g.needAsked ??= {})[id] ?? 0 });
      g.needAsked[id] = (g.needAsked[id] ?? 0) + 1;
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
    const hit = needHit(g, id, state.hits);
    if (state.hits === 0) addCard(g, { kind: 'info', who: '기한이 지났다', text: `${hit} 법을 정할 때까지 손해가 이어진다.` });
    state.hits += 1;
    g.trust = clamp(g.trust - 2, 0, 100);
    notes.push(hit);
    journal(g, hit, 'bad');
  }
}
