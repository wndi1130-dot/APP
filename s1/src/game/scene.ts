import { COMMS, PLACES } from './data';
import { stageOf, totalPop } from './state';
import type { Comm } from './data';
import type { Game } from './state';

// 정차 장면 글(자리표시). 나중엔 브레이크 소리와 함께 옆 앞쪽에서 본 정차 장면, 수색대와 열차장이 내리는 모습으로
// 그린다(decisions.md 2026-10-07). 지금은 그 장면을 한두 문장으로 대신한다.
// 바깥 문장은 위험을 간접으로 알리고, 내리는 문장은 지금 처지(지지, 불신임 직전, 죄책감)에 따라 달라진다.

export const SCENE_LINES: Record<number, string[]> = {
  1: ['바람 소리뿐이다. 눈 위에 발자국이 없다.', '역사 지붕이 무너져 있다. 움직이는 것은 없다.'],
  2: ['멀리 연기가 한 줄 오른다. 누군가 있거나, 있었다.', '창문 몇 개가 안쪽에서 막혀 있다.'],
  3: ['문짝마다 긁힌 자국이 있다. 수색대가 쇠막대를 고쳐 쥔다.', '플랫폼 끝에 짐이 버려져 있다. 버린 사람은 보이지 않는다.'],
};

/** 바깥 기척이 장소 위험도보다 우선한다. 조용한 날과 무리 흔적이 있는 날. */
export const THREAT_LINES: { calm: string[]; fresh: string[] } = {
  calm: ['바람 소리뿐이다. 눈 위에 발자국이 없다.', '까마귀가 플랫폼에 앉아 있다. 놀라 날아오르지 않는다.'],
  fresh: ['눈 위에 발자국이 어지럽다. 오래되지 않았다.', '역사 안쪽에서 무언가 끌리는 소리가 난다. 수색대가 쇠막대를 고쳐 쥔다.', '선로 옆 눈이 짓이겨져 있다. 한두 명이 아니다.'],
};

export type DisembarkMood = 'triumph' | 'cornered' | 'guilt' | 'cold' | 'warm' | 'plain';

export const DISEMBARK_LINES: Record<DisembarkMood, string> = {
  triumph: '열차장이 발판에 서자 수색대가 고개를 든다. 개선장군을 맞는 얼굴들이다.',
  cornered: '열차장은 한숨을 쉬고 어깨를 늘어뜨린 채 내린다. 입김이 하얗게 번진다.',
  guilt: '열차장이 멍하니 플랫폼 너머를 본다. 수색대 하나가 어깨를 툭 치고 지나간다.',
  cold: '수색대가 말없이 내린다. 아무도 열차장을 돌아보지 않는다.',
  warm: '수색대가 서로 장비를 챙겨 주며 내린다. 조장이 열차장에게 고개를 끄덕인다.',
  plain: '문이 열리고 찬 공기가 들어온다. 수색대가 하나씩 내린다.',
};

function supportShare(g: Game): number {
  const pop = totalPop(g) || 1;
  return COMMS.reduce((sum, c) => sum + (g.comms[c].rel >= 15 ? g.comms[c].pop : 0), 0) / pop;
}

/** 내리는 장면의 분위기. 불신임 직전이 가장 먼저, 그다음 최근 죽음(죄책감), 크게 지지받음, 보낸 집단의 마음 순이다. */
export function disembarkMood(g: Game, crew: Comm): DisembarkMood {
  if (g.trust < 25 || g.tension >= 75) return 'cornered';
  const recentDeath = g.journal.some(e => e.seg >= g.seg - 1 && e.text.includes('죽었다'));
  if (recentDeath) return 'guilt';
  if (g.trust >= 70 && supportShare(g) >= 0.5) return 'triumph';
  const band = stageOf(g.comms[crew].rel).band;
  if (band < 0) return 'cold';
  if (band > 0) return 'warm';
  return 'plain';
}

export function stopScene(g: Game): { outside: string; disembark: string } | null {
  const stop = g.stop;
  if (!stop) return null;
  const place = PLACES.find(p => p.id === stop.place) ?? PLACES[0];
  const threat = stop.threat ?? 1;
  const lines = threat > 1 ? THREAT_LINES.fresh : threat < 1 ? THREAT_LINES.calm : SCENE_LINES[Math.max(1, Math.min(3, place.risk))];
  const outside = lines[(g.seg * 5 + place.id.length) % lines.length];
  return { outside, disembark: DISEMBARK_LINES[disembarkMood(g, stop.crewComm)] };
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
