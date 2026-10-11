// 멈춘 열차(구현명세 가, 결정 034·035·037). 석탄이 0이 되면 판이 끝나지 않고 선다. 정산은 turn.ts가 부르고, 이 파일은 상태와 셈만 쥔다.
import { COMMS, P } from './data';
import type { Comm } from './data';
import { put } from './ledger';
import { journal } from './state';
import type { Game, StrandedState } from './state';
import { addContentCard } from './content';

/** 멈춘 열차 사건. 서는 턴마다 하나씩, 이 순서로 뜬다(조건이 안 맞으면 건너뛰고 나중에). */
export const STRANDED_EVENTS = ['ev_str_lamp', 'ev_str_snow', 'ev_str_promise', 'ev_str_half_bowl'] as const;

const flagsOf = (g: Game) => (g.contentFlags ??= {});

/** 이 구간의 길이(km). 노선 자료에 없으면 기본값. */
export function segKmOf(g: Game, seg = g.seg): number {
  return g.route?.find(r => r.seg === seg)?.km ?? P.segKmDefault;
}

/** 출발역에서 석탄이 다하는 지점(km). 구간 길이 × 남은 석탄 / 드는 석탄, 1km 이상 구간 끝 전까지로 자른다. */
export function stallKm(segKm: number, coalBefore: number, need: number): number {
  if (need <= 0) return Math.max(1, segKm - 1);
  return Math.min(Math.max(1, segKm - 1), Math.max(1, Math.floor(segKm * Math.max(0, coalBefore) / need)));
}

/** 처음 석탄이 0이 된 정산에서 부른다. coalBefore는 이 정산 전 석탄, need는 이 구간에 든 석탄이다. */
export function enterStranded(g: Game, coalBefore: number, need: number): void {
  put(g, 'coal', 0, 'short');
  const segKm = segKmOf(g);
  const atKm = stallKm(segKm, coalBefore, need);
  const st: StrandedState = { since: g.seg, turns: 0, segKm, atKm, toNextKm: segKm - atKm, seen: [] };
  g.stranded = st;
  flagsOf(g).stranded = true;
  journal(g, `불이 꺼졌다. 열차가 ${atKm}km 지점에서 섰다. 다음 역까지 ${st.toNextKm}km. 창마다 입김이 서린다.`, 'dark');
}

/** 선 열차의 출발 단계. 이동 사건 대신 멈춘 열차 사건 하나를 올린다. */
export function strandedDepart(g: Game): void {
  const st = g.stranded;
  if (!st) return;
  g.lostSegments += 1;
  // 식량이 30 아래면 「반 그릇」을 앞당긴다.
  const order = g.food <= 30 ? ['ev_str_half_bowl', ...STRANDED_EVENTS.filter(id => id !== 'ev_str_half_bowl')] : [...STRANDED_EVENTS];
  for (const id of order) {
    if (st.seen.includes(id)) continue;
    if (addContentCard(g, id, false, true)) { st.seen.push(id); break; }
  }
  g.phase = 'travel';
}

/** 선 채로 한 정산을 마칠 때(settle). 이미 서 있던 열차에만 부른다. */
export function strandedSettle(g: Game): void {
  const st = g.stranded;
  if (!st) return;
  st.turns += 1;
  const flags = flagsOf(g);
  // 「레버만 내린다」: 표식을 읽어 모든 칸 배급 레버를 1로 내린다(JSON은 레버를 못 만진다).
  if (flags.ration_down_asked) {
    flags.ration_down_asked = false;
    for (const c of COMMS) g.comms[c].ration = Math.min(g.comms[c].ration, 1);
    journal(g, '솥 앞 줄이 짧아졌다. 배급 레버를 1로 내렸다.', 'bad');
  }
  // 온기는 난로가 지킨다. 석탄이 1 이상이면 한 덩이를 태우고 이번 턴 하락을 건너뛴다(석탄 1로는 달리지 못한다, P.coalRun 6).
  if (g.coal >= 1) {
    put(g, 'coal', g.coal - 1, 'stranded');
    return;
  }
  for (const c of COMMS as readonly Comm[]) {
    const base = g.comms[c].base;
    base[0] = Math.min(base[0], Math.max(P.strandedWarmFloor, base[0] - P.strandedWarmDrop));
  }
}
