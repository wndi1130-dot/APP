import { describe, expect, it } from 'vitest';
import { advance, castVote, chooseCard, COMMS, currentAgenda, primaryAction, resolveStop, sendScouts, viewCard } from '../../src/game';
import type { Game } from '../../src/game';
import { newGame } from '../../src/ui/domestic';
import { reviveSave } from '../../src/ui/repro';

// 앱의 「내정 켠 새 판」과 같은 newGame으로 시작해 서막·사건·죽음의 무게 기본값을 그대로 둔 채 자동으로 진행한다(검수 PR 395 보통 6).
// 재난 상태를 직접 넣지 않고 실제 진행으로 예고 → 발동을 만나고, 발동 중 정차에 정찰을 보낸 뒤 저장 → 되살리기 한 판이
// 원래 판과 같은 숫자로 끝까지 이어지는지 본다. 초기 플래그 시험(domestic_ui)과 엔진 골든은 각자 범위를 그대로 지킨다.

const STEP_CAP = 3000;

/** 고르기 규칙: 카드는 열린 첫 선택지, 정차는 바로 끝내고, 의회는 표결, 나머지는 출발. 판이 막히면 까닭을 돌려준다. */
function step(g: Game): string | null {
  if (g.cards.length > 0) {
    const card = g.cards[0];
    const i = viewCard(g, card).choices.findIndex(c => !c.disabled);
    if (i < 0) return `열린 선택지가 없는 카드 ${card.kind}`;
    chooseCard(g, card.uid, i);
    return null;
  }
  if (g.phase === 'stop' && g.stop && !g.stop.done) { resolveStop(g, true); return null; }
  if (g.phase === 'council' && g.council && !g.council.result && currentAgenda(g)) { castVote(g); return null; }
  const pa = primaryAction(g);
  if (!pa.ok) return `출발 막힘: ${pa.why}`;
  advance(g);
  return null;
}

/** 규칙이 내는 숫자 한 줄(골든 snap과 같은 열에 재난 상태를 더함). */
const snap = (g: Game) => [
  g.seg, g.phase, g.trust, g.tension, g.coal, g.food, g.med, g.lux,
  ...COMMS.flatMap(c => [g.comms[c].rel, g.comms[c].pop]),
  g.rng.state, g.journal.length, g.injured, JSON.stringify(g.disaster ?? null),
];

describe('새 판 흐름(재난·정찰·정차·저장 재개)', () => {
  it('내정 켠 새 판이 실제 진행으로 재난을 만나고, 발동 중 정차에 정찰을 보낸 뒤 저장해 되살린 판이 끝까지 같은 숫자로 간다', () => {
    let done = false;
    for (let s = 0; s < 10 && !done; s += 1) {
      const g = newGame(`flow-${s}`, true, false);
      expect(g.disasters, '새 판은 재난을 켠 채 시작한다').toBe(true);
      const stages = new Set<string>();
      let n = 0;
      for (; n < STEP_CAP && g.phase !== 'end'; n += 1) {
        if (g.disaster) stages.add(g.disaster.stage);
        const atActiveStop = g.phase === 'stop' && g.stop && !g.stop.done && !g.stop.scoutReport && g.disaster?.stage === 'active';
        if (!atActiveStop) {
          const why = step(g);
          expect(why, `flow-${s} 구간 ${g.seg}`).toBeNull();
          continue;
        }
        // 발동 중 정차: 정찰을 실제로 보낸다.
        const rep = sendScouts(g);
        expect(rep, `flow-${s} 정찰 보고`).not.toBeNull();
        expect(g.stop!.scoutReport).toBeDefined();
        // 결과를 정하기 전에 저장하고(앱의 save와 같은 JSON) 되살린다.
        const h = reviveSave(JSON.parse(JSON.stringify(g)));
        expect(h, '저장본을 읽지 못했다').not.toBeNull();
        expect(snap(h!)).toEqual(snap(g));
        // 같은 정차 결과가 나야 한다(피해 명단, 산출, 난수 흐름).
        const ra = resolveStop(g, true)!;
        const rb = resolveStop(h!, true)!;
        expect(ra).toBeTruthy();
        expect(rb).toEqual(ra);
        expect(snap(h!)).toEqual(snap(g));
        // 끝까지 같은 고르기로 나란히 돌린다.
        // 위에서 정차 단계로 좁혀진 타입을 풀어 준다(정차 뒤 판은 다시 움직인다).
        for (let m = 0; m < STEP_CAP && (g.phase as string) !== 'end'; m += 1) {
          if (g.disaster) stages.add(g.disaster.stage);
          expect(step(g)).toBeNull();
          expect(step(h!)).toBeNull();
          expect(snap(h!), `flow-${s} 되살린 판이 ${m}걸음째 어긋났다`).toEqual(snap(g));
        }
        expect(h!.phase).toBe('end');
        done = true;
      }
      expect(g.phase, `flow-${s}: ${STEP_CAP}걸음 안에 끝나지 않았다`).toBe('end');
      if (done) {
        // 예고 단계를 거쳐 발동에 닿았다(예고 횟수 통계는 발동했다는 뜻이 아니라서 단계를 직접 본다).
        expect(stages.has('brewing')).toBe(true);
        expect(stages.has('active')).toBe(true);
      }
    }
    expect(done, '앞 10개 시드 안에서 재난 발동 중 정차를 만나지 못했다').toBe(true);
  }, 60_000);
});
