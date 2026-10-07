import { viewCard } from '../cards';
import type { Game } from '../state';
import { logPick } from './chronicle';

// H7 자동 기록(15.1): 카드 하나를 고른 시간. 화면이 잰 ms를 고르기 행동에 실어 보내고(ui/app.ts),
// 고르기 바로 앞에서 적는다. 행동에 실렸으니 오류 재현(ui/repro.ts)으로 다시 해도 같은 기록이 남는다.

/** S1b 판에서 카드를 고르기 직전에 부른다. ms가 없거나 잴 수 없는 값이면 적지 않는다. */
export function logCardPick(g: Game, uid: number, index: number, ms: number): void {
  if (!g.dark || !Number.isFinite(ms) || ms <= 0) return;
  const card = g.cards.find(c => c.uid === uid);
  if (!card) return;
  const v = viewCard(g, card);
  const ch = v.choices[index];
  if (!ch || ch.disabled) return;
  const open = v.choices.filter(c => !c.disabled);
  const crossing = open.some(c => c.cross !== undefined);
  const chars = v.body.length + open.reduce((s, c) => s + (c.say ?? c.label).length, 0);
  logPick(g, {
    kind: card.kind, chars, ms: Math.round(ms), choices: open.length, crossing,
    picked: ch.cross !== undefined, alt: open.some(c => c.cross === undefined),
  });
}
