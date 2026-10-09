import { COMMS } from './data';
import { stageOf, totalPop } from './state';
import type { Comm } from './data';
import type { Game, StopResult } from './state';
import { resolveStop } from './turn';

// 수색대가 내리는 문장(정차 장면). 분위기는 지금 처지로 정한다. '보낸다'를 누른 순간의 문장을 결과에 담는다(sendStop).

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

/** 정차를 푼다(resolveStop)와 같고, 보냈으면 누른 순간의 처지로 내리는 문장을 결과에 담는다(사용자 2026-10-09: 문장은 보낸 다음에).
 * 결과를 적용하면 신임·죽음 기록이 바뀌어서 먼저 정한다. turn.ts는 공유 파일이라 여기서 감싼다. */
export function sendStop(g: Game, go: boolean): StopResult | null {
  const stop = g.stop;
  const line = go && stop && !stop.done && stop.target ? DISEMBARK_LINES[disembarkMood(g, stop.crewComm)] : undefined;
  const r = resolveStop(g, go);
  if (r && line && !r.passed) r.disembark = line;
  return r;
}
