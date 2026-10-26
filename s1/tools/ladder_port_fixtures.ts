// 고조 사다리(정치 흐름 P2, #699)의 작은 사례 표: 폭동 틱(예고 없는 난장판 미룸·다시 오는 항의·들어준 뒤 낮은 문턱·이어지는 난장판),
// 항의·난장판·마지막 기회 카드의 선택지 이름과 회색, 고른 뒤의 전체 상태. 규칙은 S1에서 직접 실행한다.
// 큰 열차 턴 표본(turn_port_fixtures.ts)은 30걸음 안에 항의 사다리가 안 나와 따로 둔다(S3 연결 10-26).
// 사용: npx tsx tools/ladder_port_fixtures.ts
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import * as S1 from '../src/game';
import type { Card, Game } from '../src/game';
import { riotOf, riotTick } from '../src/game/riot';
import { tables } from './turn_port_fixtures';
import { council } from './law_port_fixtures';

const SEEDS = ['ladder-0', 'ladder-1'];
const LIMIT = 8 * 1024 * 1024;
const plain = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T;

type Action = { kind: 'riot_tick'; tension: number } | { kind: 'view'; uid: number } | { kind: 'choose'; uid: number; index: number };

/** 카드를 비운 회기 뒤 상태. 폭동 상태를 처음 값으로 둔다. */
function base(seed: string): Game {
  const g = council(seed);
  g.cards = [];
  g.council = null;
  riotOf(g);
  return g;
}

function withCard(g: Game, card: Omit<Card, 'uid'>): number {
  S1.addCard(g, card);
  return g.cards[g.cards.length - 1].uid;
}

function ladderVectors() {
  const cases: { name: string; action: Action; before: Game; after?: Game; out?: unknown }[] = [];
  const add = (name: string, g: Game, action: Action, run: () => unknown) => {
    const before = plain(g);
    const out = run();
    if (g.dom || g.dark) throw new Error('S1a 밖의 표본');
    cases.push({ name, action, before, ...(action.kind === 'view' ? {} : { after: plain(g) }), ...(out === undefined ? {} : { out: plain(out) }) });
  };
  const tick = (name: string, g: Game, tension: number) => add(name, g, { kind: 'riot_tick', tension }, () => { g.tension = tension; riotTick(g, []); });
  for (const seed of SEEDS) {
    const P = S1.P;
    // 예고 없는 난장판: 항의 문턱 아래에서 한 정산에 난장판 문턱 위로.
    const skip = base(seed);
    skip.riot!.prev = P.protestFrom - 10;
    tick(`tick/${seed}/skip`, skip, P.riotFrom + 5);
    const start = plain(skip);
    start.cards = [];
    tick(`tick/${seed}/pending-start`, start, P.riotFrom + 5);
    const calm = plain(skip);
    calm.cards = [];
    tick(`tick/${seed}/pending-calm`, calm, P.protestFrom - 5);
    tick(`tick/${seed}/riot-ongoing`, plain(start), P.riotFrom + 2);
    // 항의 문턱을 위로 넘음, 들어준 뒤 낮아진 문턱.
    const cross = base(seed);
    cross.riot!.prev = P.protestFrom - 6;
    tick(`tick/${seed}/protest-cross`, cross, P.protestFrom + 1);
    const low = base(seed);
    low.riot!.prev = P.protestFrom - 6;
    low.riot!.yieldUntil = low.seg;
    tick(`tick/${seed}/yield-line`, low, P.protestFrom - 3);
    // 물리친 항의: 풀리지 않았으면 다시 오고, 풀렸으면 안 온다.
    for (const [tag, tension] of [['again', P.protestFrom + 2], ['again-calm', P.protestFrom - 10]] as [string, number][]) {
      const g = base(seed);
      g.riot!.prev = tension;
      g.riot!.stage = tension >= P.protestFrom ? 1 : 0;
      g.riot!.ignoredAt = g.seg - 3;
      tick(`tick/${seed}/${tag}`, g, tension);
    }
    // 카드 셋 × 경비대 사이(보통·반대 이하): 선택지 이름과 회색, 고른 뒤 상태.
    const kinds: [string, Omit<Card, 'uid'>][] = [
      ['protest', { kind: 'protest', comm: 'tail', text: 'protest' }],
      ['riot', { kind: 'protest', comm: 'tail', text: 'riot' }],
      ['crisis', { kind: 'tension_crisis', comm: 'tail' }],
    ];
    for (const [tag, card] of kinds) {
      for (const cold of [false, true]) {
        const g = base(seed);
        g.tension = card.kind === 'tension_crisis' ? 100 : card.text === 'riot' ? P.riotFrom + 2 : P.protestFrom + 2;
        if (card.text === 'riot') g.riot!.stage = 2;
        if (cold) g.comms.guard.rel = -50;
        const uid = withCard(g, card);
        const at = `${seed}/${tag}${cold ? '/guard-cold' : ''}`;
        add(`view/${at}`, g, { kind: 'view', uid }, () => S1.viewCard(g, g.cards.find(c => c.uid === uid)!).choices.map(c => ({ label: c.label, ...(c.disabled ? { disabled: c.disabled } : {}) })));
        const n = S1.viewCard(g, g.cards.find(c => c.uid === uid)!).choices.length;
        for (let i = 0; i < n; i += 1) {
          // 마지막 기회 「아무것도 안 한다」는 반란 끝(회고 기록)이라 S2가 아직 받지 않는다.
          if (card.kind === 'tension_crisis' && i === 2) continue;
          const h = plain(g);
          add(`choose/${at}/${i}`, h, { kind: 'choose', uid, index: i }, () => S1.chooseCard(h, uid, i));
        }
      }
    }
    // 걸린 약속이 있는 칸을 경비로 누름.
    const p = base(seed);
    p.tension = P.protestFrom + 2;
    p.comms.tail.promise = { kind: 'open', cond: { kind: 'ration', label: '배급', now: false }, label: '배급', due: p.seg + 3, madeSession: p.session };
    const uid = withCard(p, { kind: 'protest', comm: 'tail', text: 'protest' });
    add(`choose/${seed}/protest-promise/1`, p, { kind: 'choose', uid, index: 1 }, () => S1.chooseCard(p, uid, 1));
  }
  return cases;
}

export function ladderPortVectors() {
  return { format: 'ladder-vectors-v1', seeds: SEEDS, tables: tables(), cases: ladderVectors() };
}

function main(): void {
  const out = resolve(import.meta.dirname, '../../s2/tests/fixtures/train/ladder_vectors.json');
  const data = ladderPortVectors();
  const bytes = Buffer.from(`${JSON.stringify(data)}\n`, 'utf8');
  if (bytes.length > LIMIT) throw new Error(`F-FIXTURE-SIZE: ${bytes.length} > ${LIMIT}`);
  mkdirSync(dirname(out), { recursive: true });
  let identical = false;
  try { identical = readFileSync(out).equals(bytes); } catch { /* 첫 실행 */ }
  if (!identical) writeFileSync(out, bytes);
  console.log(JSON.stringify({ bytes: bytes.length, identical, cases: data.cases.length }));
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(import.meta.filename)) main();
