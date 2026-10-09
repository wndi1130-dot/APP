import assert from 'node:assert/strict';
import { COMMS, createGame, cloneGame, chooseCard, viewCard, cutComm, advance } from '../src/game';
import { enableRumor, spreadRumor, rumorSettle, setRumorBlizzard, setRumorOrder, resolveRumor } from '../src/game/rumor';
import { readSave } from '../src/ui/repro';

function fresh() {
  const g = createGame('rumor-check');
  for (const c of COMMS) g.comms[c].rel = 0;
  enableRumor(g);
  return g;
}
export const rumorChecks: Record<string, () => void> = {
  '사건 칸 즉시, 옆 칸 다음 정산, 먼 칸 그다음 정산과 한 번의 1.5배': () => {
    const g = fresh();
    spreadRumor(g, 'tail', { tail: 10, medtech: -4, front: -4 });
    assert.equal(g.comms.tail.rel, 10);
    rumorSettle(g);
    assert.equal(g.comms.medtech.rel, 0);
    assert.equal(g.comms.front.rel, 0);
    g.seg++;
    rumorSettle(g);
    assert.equal(g.comms.medtech.rel, -6);
    assert.equal(g.comms.front.rel, 0);
    g.seg++;
    rumorSettle(g);
    assert.equal(g.comms.front.rel, -6);
    assert.equal(g.cards.filter(c => c.kind === 'rumor').length, 1);
    assert(g.journal.some(j => j.text.includes('앞칸에 소문이 닿았다')));
  },
  '같은 칸 대기 소문은 큰 것 하나만 남긴다': () => {
    const g = fresh();
    spreadRumor(g, 'tail', { front: -4 });
    spreadRumor(g, 'engine', { front: 3 });
    spreadRumor(g, 'guard', { front: 8 });
    assert.equal(g.rumor!.stats.overlaps, 2);
    assert.equal(g.rumor!.queue.length, 1);
    g.seg++;
    rumorSettle(g);
    assert.equal(g.comms.front.rel, 12);
  },
  '반대 칸·절댓값 5·전역 4구간 간격': () => {
    const g = fresh();
    spreadRumor(g, 'tail', { guard: -10 });
    g.seg += 2; rumorSettle(g);
    assert.equal(g.cards.length, 0);
    spreadRumor(g, 'tail', { front: -3 });
    g.seg += 2; rumorSettle(g);
    assert.equal(g.cards.length, 0);
    spreadRumor(g, 'tail', { front: -4 });
    g.seg += 2; rumorSettle(g);
    assert.equal(g.cards.length, 1);
    spreadRumor(g, 'tail', { front: -4 });
    g.seg += 2; rumorSettle(g);
    assert.equal(g.cards.length, 1);
    spreadRumor(g, 'tail', { front: -4 });
    g.seg += 2; rumorSettle(g);
    assert.equal(g.cards.length, 2);
  },
  '눈보라의 같은 정산 도착과 부풀림 한 번': () => {
    const g = fresh();
    setRumorBlizzard(g);
    spreadRumor(g, 'tail', { tail: 4, medtech: -4, front: -4 });
    assert.equal(g.comms.tail.rel, 4);
    rumorSettle(g);
    assert.equal(g.comms.tail.rel, 4);
    assert.equal(g.comms.medtech.rel, -6);
    assert.equal(g.comms.front.rel, -6);
    assert.equal(g.rumor!.queue.length, 0);
    g.seg += 2;
    spreadRumor(g, 'tail', { front: -4 });
    assert.equal(g.rumor!.queue[0].remaining, 2);
  },
  '재배열한 탄 순서를 새 사건에 적용한다': () => {
    const g = fresh();
    assert.equal(setRumorOrder(g, ['tail', 'front', 'engine', 'guard', 'medtech']), true);
    assert.equal(setRumorOrder(g, ['tail', 'tail', 'engine', 'guard', 'medtech']), false);
    spreadRumor(g, 'tail', { front: -4, medtech: -4 });
    assert.deepEqual(g.rumor!.queue.map(q => [q.target, q.remaining]), [['front', 1], ['medtech', 2]]);
  },
  '신임 50의 사실 정정은 도착 부풀림과 남은 전파를 거둔다': () => {
    const g = fresh(); g.trust = 50;
    spreadRumor(g, 'guard', { tail: -4, engine: -4 });
    g.seg += 2; rumorSettle(g);
    const card = g.cards.find(c => c.kind === 'rumor')!;
    assert.equal(viewCard(g, card).title, '소문이 닿았다');
    assert.equal(viewCard(g, card).choices.length, 3);
    assert.equal(chooseCard(g, card.uid, 0), true);
    assert.equal(g.comms.tail.rel, -4);
    assert.equal(g.comms.engine.rel, -4);
    assert.equal(g.rumor!.queue.length, 0);
  },
  '입단속과 방치 및 낮은 신임 해명의 후속': () => {
    const g = fresh();
    spreadRumor(g, 'tail', { front: -4 });
    const id = g.rumor!.queue[0].event;
    const fear = g.fear;
    assert.equal(resolveRumor(g, id, 1), true);
    assert.equal(g.comms.tail.grudge, 1);
    assert.equal(g.fear, fear + 3);
    assert.equal(g.rumor!.queue.length, 0);
    spreadRumor(g, 'tail', { front: -4 });
    const id2 = g.rumor!.queue[0].event;
    assert.equal(resolveRumor(g, id2, 2), true);
    assert.equal(g.rumor!.queue.length, 1);
    g.trust = 49;
    assert.equal(resolveRumor(g, id2, 0), true);
    assert.equal(g.trust, 47);
    assert(g.rumor!.queue.some(q => q.size === 0));
    assert(g.journal.some(j => j.text.includes('열차장이 감춘다')));
  },
  '실제 저장 복원과 cloneGame이 대기열·간격·통계를 보존한다': () => {
    const g = fresh();
    spreadRumor(g, 'tail', { front: -4 });
    const saved = readSave(JSON.parse(JSON.stringify(g)));
    if (!saved.ok) throw new Error(saved.why);
    assert.deepEqual(saved.g.rumor, g.rumor);
    assert.deepEqual(cloneGame(g).rumor, g.rumor);
    saved.g.seg += 2; rumorSettle(saved.g);
    assert.equal(saved.g.comms.front.rel, -6);
  },
  '실제 정치 행동의 관계 변화를 지연한다': () => {
    const g = fresh();
    const f = g.comms.front.rel;
    cutComm(g, 'tail');
    assert.equal(g.comms.tail.rel, -15);
    assert.equal(g.comms.front.rel, f);
    g.seg += 2; rumorSettle(g);
    assert.equal(g.comms.front.rel, f + 7.5);
  },
  '실제 정산이 대기열을 비우고 플래그 끔에는 상태를 추가하지 않는다': () => {
    const g = fresh();
    spreadRumor(g, 'tail', { front: -4 });
    g.seg += 2; g.phase = 'council'; g.council = null;
    advance(g);
    assert.equal(g.rumor!.queue.length, 0);
    const off = createGame('off');
    assert.equal('rumor' in off, false);
  },
};
if (process.argv.includes('--run')) {
  for (const [name, check] of Object.entries(rumorChecks)) { check(); console.log(`통과: ${name}`); }
  console.log(`C1 검증 ${Object.keys(rumorChecks).length}개 통과`);
}
