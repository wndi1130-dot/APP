import { addCard } from './state';
import type { Game } from './state';

// 두고 떠난 사람의 흔적(결정 425 카드 3, carry_people.md 3.3): 서막 저탄장에 두고 떠난 사람의 분필 글씨가 뒤 정차에 한 번 보이고,
// 다시 태울 길이 한 번 열린다. 카드 글과 고른 뒤의 일은 prologue.ts('pro_trail'). turn.ts가 부르므로 turn을 부르는 파일을 불러오지 않는다.
// 금지선: 그들은 걸어서 길을 질러 왔고, 쪽지를 남기면 걸어서 뒤를 따른다(campaign_story 3.9). 가두거나 남겨 두는 그림이 아니다.

export const TRAIL = Object.freeze({
  /** 떠난 뒤 이만큼 구간이 지난 첫 정차에 한 번 뜬다(제안) */
  after: 2,
  /** 기다렸다 태우면: 불을 지펴 두고 기다리는 석탄, 꼬리칸 관계(두고 떠난 −8의 절반, 어긴 약속은 그대로) */
  coal: 2, rel: 4,
});

/** 정차 결과 뒤(turn.ts resolveStop): 흔적이 뜰 정차면 카드를 올리고 true. 이미 떴거나, 다 죽었거나 돌아왔거나, 선 열차면 false */
export function trailAfterStop(g: Game): boolean {
  const t = g.trail;
  if (!t || t.shown || g.stranded || g.seg < t.seg + TRAIL.after) return false;
  t.names = t.names.filter(n => !g.deaths.includes(n) && (g.left ?? []).includes(n));
  if (t.names.length === 0) return false;
  t.shown = true;
  addCard(g, { kind: 'pro_trail', comm: t.comm });
  return true;
}
