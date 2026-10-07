import { COMMS } from './data';
import { stageOf, totalPop } from './state';
import type { Comm } from './data';
import type { Game } from './state';
import { stopView, verdictText } from './omens';
import type { RiskLevel } from './omens';
import { riskLevel, riskWhy, stopRisk } from './turn';

// 정차 장면 글(자리표시). 나중엔 브레이크 소리와 함께 옆 앞쪽에서 본 정차 장면, 수색대와 열차장이 내리는 모습으로
// 그린다(decisions.md 2026-10-07). 지금은 그 장면을 한두 문장으로 대신한다.
// 바깥 문장은 날씨와 장소 겉모습만 보여 준다. 위험은 정찰조가 본 조짐으로 따로 알린다(omens.ts).
// 내리는 문장은 지금 처지(지지, 불신임 직전, 죄책감)에 따라 달라진다.

export type DisembarkMood = 'triumph' | 'cornered' | 'guilt' | 'grief' | 'cold' | 'warm' | 'plain';

export const DISEMBARK_LINES: Record<DisembarkMood, string> = {
  triumph: '열차장이 발판에 서자 수색대가 고개를 든다. 개선장군을 맞는 얼굴들이다.',
  cornered: '열차장은 한숨을 쉬고 어깨를 늘어뜨린 채 내린다. 입김이 하얗게 번진다.',
  guilt: '열차장이 마지막 계단에서 멈춰 멍하니 플랫폼 너머를 본다. 수색대 하나가 어깨를 툭 치고 지나간다.',
  grief: '열차장이 문 앞에서 한 박자 멈췄다가 내린다. 창가에 늘 앉던 자리 하나가 비어 있다.',
  cold: '수색대가 말없이 내린다. 아무도 열차장을 돌아보지 않는다.',
  warm: '수색대가 서로 장비를 챙겨 주며 내린다. 조장이 열차장에게 고개를 끄덕인다.',
  plain: '문이 열리고 찬 공기가 들어온다. 수색대가 하나씩 내린다.',
};

function supportShare(g: Game): number {
  const pop = totalPop(g) || 1;
  return COMMS.reduce((sum, c) => sum + (g.comms[c].rel >= 15 ? g.comms[c].pop : 0), 0) / pop;
}

/** 내리는 장면의 분위기. 불신임 직전이 가장 먼저, 그다음 열차장이 고른 죽음(죄책감, 목격자가 있으면 3구간),
 * 그 밖의 이름 있는 죽음(애도), 크게 지지받음, 보낸 집단의 마음 순이다. 둘이 겹치면 죄책감이 앞선다. */
export function disembarkMood(g: Game, crew: Comm): DisembarkMood {
  if (g.trust < 25 || g.tension >= 75) return 'cornered';
  const log = g.deathLog ?? [];
  if (log.some(d => d.cause !== 'other' && g.seg - d.seg < (d.witness ? 3 : 2))) return 'guilt';
  if (log.some(d => d.cause === 'other' && g.seg - d.seg < 2)) return 'grief';
  if (g.trust >= 70 && supportShare(g) >= 0.5) return 'triumph';
  const band = stageOf(g.comms[crew].rel).band;
  if (band < 0) return 'cold';
  if (band > 0) return 'warm';
  return 'plain';
}

export function stopScene(g: Game): { outside: string; disembark: string } | null {
  const stop = g.stop;
  if (!stop) return null;
  const v = stopView(g, stop, false);
  return { outside: stop.look ?? `${v.sky} ${v.ground}`, disembark: DISEMBARK_LINES[disembarkMood(g, stop.crewComm)] };
}

export interface RiskView {
  /** 약속 단계. 정찰 안 하면 null */
  level: RiskLevel | null;
  /** 정찰조가 본 조짐 */
  omen: string | null;
  /** 해석 말. 이 말이 약속이다 */
  verdict: string | null;
  why: string[];
  unknown: string | null;
}

/** 정차 화면의 위험 글: 정찰조가 본 조짐과 해석(2026-10-07 사용자). 준비를 바꾸면 해석만 다시 계산되고 조짐은 그대로다. */
export function riskView(g: Game): RiskView {
  const r = stopRisk(g);
  const why = riskWhy(r);
  if (!r.known || !g.stop) return { level: null, omen: null, verdict: null, why, unknown: '정찰하지 않으면 안쪽 기척은 모른다.' };
  const v = stopView(g, g.stop, r.horde);
  const level = riskLevel(r);
  return { level, omen: v.omen, verdict: verdictText(level, v.sign), why, unknown: null };
}

/** 관계 단계를 사람 말로. 열차장(플레이어)을 어떻게 보는지. */
export const RELATION_LINES: Record<string, string> = {
  헌신: '열차장이 가자는 곳이라면 지옥이라도 따라갈 것이다.',
  지지: '열차장을 믿고 따른다.',
  호의: '열차장에게 호의적이다. 아직은.',
  중립: '열차장을 지켜보고 있다.',
  회의: '열차장에게 불만을 품고 있다.',
  반대: '불만이 커져 대놓고 반대한다.',
  적대: '불만이 극에 달했다. 열차장을 끌어내릴 틈만 본다.',
};

export function relationLine(rel: number): string {
  return RELATION_LINES[stageOf(rel).name] ?? '';
}
