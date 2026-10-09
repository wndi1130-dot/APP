import { stageOf } from './state';
import type { Game } from './state';
import { stopView, verdictText } from './omens';
import type { RiskLevel } from './omens';
import { blizzardActive } from './disaster';
import { riskLevel, riskWhy, stopRisk } from './turn';

// 정차 장면 글(자리표시). 나중엔 브레이크 소리와 함께 옆 앞쪽에서 본 정차 장면, 수색대와 열차장이 내리는 모습으로
// 그린다(decisions.md 2026-10-07). 지금은 그 장면을 한두 문장으로 대신한다.
// 바깥 문장은 날씨와 장소 겉모습만 보여 준다. 위험은 정찰조가 본 조짐으로 따로 알린다(omens.ts).
// 수색대가 내리는 문장은 '보낸다'를 누른 뒤에 결과 서류에 뜬다. 문장과 분위기 판정은 disembark.ts에 있다
// (turn.ts가 보낸 순간의 문장을 담는데, scene.ts는 turn.ts를 읽어서 거기 두면 import 순환이 된다).

export function stopScene(g: Game): { outside: string } | null {
  const stop = g.stop;
  if (!stop) return null;
  const v = stopView(g, stop, false);
  return { outside: stop.look ?? `${v.sky} ${v.ground}` };
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
  if (!r.known || !g.stop) return { level: null, omen: null, verdict: null, why, unknown: blizzardActive(g) ? '눈 때문에 안쪽을 볼 수 없다.' : g.stop?.scoutReport ? '정찰조가 돌아오지 않아 안쪽 기척은 모른다.' : '정찰을 보내지 않으면 안쪽 기척은 모른다.' };
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
