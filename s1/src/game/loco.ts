// 기관차 넷(결정 125·126·132). 고른 기관차 한 칸(g.loco)이 구간 석탄·붙인 칸·고장·압력·출발에 닿는 값을 돌려준다.
// 내정(domestic/)이 읽어야 해서 turn.ts를 부르지 않는다(import 순환 방지). 숫자는 data.ts의 LOCO 표.
import { D } from './domestic/data';
import { LOCO, LOCO_DEFAULT } from './data';
import type { LocoId, LocoSpec } from './data';
import { journal } from './state';
import type { Game } from './state';

/** 고른 기관차. 옛 저장과 안 고른 판은 기본(c3). */
export const locoIdOf = (g: Game): LocoId => g.loco ?? LOCO_DEFAULT;
export const locoOf = (g: Game): LocoSpec => LOCO[locoIdOf(g)];

/** 게임 시작 때 기관차를 정한다. 일대기 첫 줄에 이름(가안)을 적는다. */
export function setLoco(g: Game, id: LocoId): void {
  g.loco = id;
  journal(g, `기관차: ${LOCO[id].name}.`);
}

/** 구간마다 드는 석탄에 더하는 기관차 몫(turn.ts forecast). */
export const locoCoal = (g: Game): number => locoOf(g).coal;
/** 붙인 칸 하나가 먹는 석탄. */
export const locoCarCoal = (g: Game): number => locoOf(g).extraCarCoal ?? D.extraCarCoal;
/** 고장을 막는 데 드는 부품(손으로 고칠 때와 공방이 저절로 막을 때 모두). */
export const locoRepairParts = (g: Game): number => locoOf(g).repairParts ?? D.repairParts;
export const locoAutoRepairParts = (g: Game): number => locoOf(g).repairParts ?? D.autoRepairParts;
/** 김 빼기에 드는 석탄. */
export const locoVentCoal = (g: Game): number => locoOf(g).ventCoal ?? D.ventCoal;
/** 압력 경고가 뜨는 확률. 숙련 조건이 안 맞으면 null(안 뜬다). */
export function locoPressureChance(g: Game, engineSkill: number): number | null {
  const l = locoOf(g);
  if (l.pressureAlways) return l.pressureChance ?? D.pressureChance;
  return engineSkill === 1 ? D.pressureChance : null;
}

/** 첫 화면 「열차를 고른다」를 띄울 때인가: 아직 안 골랐고 첫 구간 출발 전이다. 옛 저장(이미 달리는 판)은 c3으로 읽고 묻지 않는다. */
export const locoUnchosen = (g: Game): boolean => g.loco === undefined && g.seg <= 1 && g.phase === 'prep';
