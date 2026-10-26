// S1a 법 하나씩의 전체 JSON 전/후(결정 426 PR 7 S2 첫 판): 통과·폐지, 그 안건의 표결, 법이 선 채 정산 한 번,
// 비상식량감축법 뒤 꼬리칸 요구 카드의 답 셋. 규칙은 S1에서 직접 실행한다. 비상대권(정치 흐름 몫)은 뺀다.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import * as S1 from '../src/game';
import type { Game, LawId } from '../src/game';
import { tables } from './turn_port_fixtures';

const SEEDS = ['law-0', 'law-1'];
const LIMIT = 16 * 1024 * 1024;
const plain = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T;

/** S2가 받는 법: S1a 법(S1c·배웅 빼고)에서 비상대권을 뺀 것. */
export const PORTED_LAWS: LawId[] = S1.LAW_IDS.filter(l => !S1.S1C_LAWS.includes(l) && !S1.FAREWELL_LAWS.includes(l) && l !== 'emergency_powers');

type Action = { kind: 'enact' | 'repeal'; law: LawId } | { kind: 'cast_vote' } | { kind: 'advance' } | { kind: 'choose_card'; uid: number; index: number };

/** 판을 둘째 회기의 의회까지 돌린 상태(카드·정차는 turn_port_fixtures의 play와 같은 길로 고른다). */
export function council(seed: string): Game {
  const g = S1.createGame(seed);
  for (let step = 0; step < 200; step += 1) {
    if (g.cards.length > 0) {
      const card = g.cards[0];
      const index = S1.viewCard(g, card).choices.findIndex(c => !c.disabled);
      if (index < 0 || !S1.chooseCard(g, card.uid, index)) throw new Error(`선택 불가: ${seed}/${step}/${card.kind}`);
    } else if (g.phase === 'stop' && g.stop && !g.stop.done) {
      S1.resolveStop(g, true);
    } else if (g.phase === 'council' && g.council && !g.council.result) {
      if (g.session >= 2) break;
      if (!S1.castVote(g)) S1.advance(g);
    } else {
      if (!S1.primaryAction(g).ok) throw new Error(`진행 불가: ${seed}/${step}/${g.phase}`);
      S1.advance(g);
    }
    if (g.dom || g.dark) throw new Error('S1a 밖의 표본');
  }
  if (g.phase !== 'council' || g.cards.length > 0) throw new Error(`F-INPUT-MISSING: ${seed} 둘째 회기`);
  return g;
}

/** 안건 하나만 올린 회기. */
function withAgenda(g: Game, law: LawId, repeal: boolean): Game {
  g.council = { options: [{ law, repeal }], idx: 0, locked: false, deals: [], result: null };
  return g;
}

/** 법을 세우고 그 법이 낸 카드는 거둔 상태(정산·폐지의 출발점). 폐지 냉각을 넘긴 회기로 둔다. */
function standing(base: Game, law: LawId): Game {
  const g = plain(base);
  S1.enactLaw(g, law, []);
  g.cards = g.cards.filter(c => c.kind !== 'ration_cut');
  g.session += S1.P.repealCool + 1;
  return g;
}

function lawVectors() {
  const cases: { name: string; action: Action; before: Game; after: Game }[] = [];
  const add = (name: string, g: Game, action: Action, run: () => void) => {
    const before = plain(g);
    run();
    if (g.dom || g.dark) throw new Error('S1a 밖의 표본');
    cases.push({ name, action, before, after: plain(g) });
  };
  for (const seed of SEEDS) {
    const base = council(seed);
    const full = seed === SEEDS[0];
    for (const law of PORTED_LAWS) {
      if (!S1.lawActive(base, law)) {
        const g = plain(base);
        add(`enact/${seed}/${law}`, g, { kind: 'enact', law }, () => S1.enactLaw(g, law, []));
      }
      const up = standing(base, law);
      add(`repeal/${seed}/${law}`, up, { kind: 'repeal', law }, () => S1.repealLaw(up, law));
      if (!full) continue;
      if (!S1.lawActive(base, law)) {
        const v = withAgenda(plain(base), law, false);
        add(`vote/${seed}/${law}`, v, { kind: 'cast_vote' }, () => { S1.castVote(v); });
      }
      const r = withAgenda(standing(base, law), law, true);
      add(`vote-repeal/${seed}/${law}`, r, { kind: 'cast_vote' }, () => { S1.castVote(r); });
      // 법이 선 채 정산 한 번: 턴이 그 법의 res를 읽는다.
      const s = standing(base, law);
      s.council = { options: [], idx: 0, locked: false, deals: [], result: null };
      add(`settle/${seed}/${law}`, s, { kind: 'advance' }, () => { S1.advance(s); });
    }
    // 수업과 같이 선 아동 노동: 한 번짜리 벌을 반으로 세우고, 내릴 때 반만 거둔다(결정 205).
    const edu = plain(base);
    edu.passed.edu_letters = 0;
    add(`enact/${seed}/child_labor+edu`, edu, { kind: 'enact', law: 'child_labor' }, () => S1.enactLaw(edu, 'child_labor', []));
    const eduUp = plain(edu);
    eduUp.session += S1.P.repealCool + 1;
    add(`repeal/${seed}/child_labor+edu`, eduUp, { kind: 'repeal', law: 'child_labor' }, () => S1.repealLaw(eduUp, 'child_labor'));
    // 비상식량감축법 뒤 꼬리칸 요구(결정 091·430): 답 셋, 꼬리칸을 뺀 채 정산, 답을 되돌리는 폐지.
    const cut = plain(base);
    cut.food = 30;
    S1.enactLaw(cut, 'emergency_ration', []);
    const card = cut.cards.find(c => c.kind === 'ration_cut');
    if (!card) throw new Error('F-INPUT-MISSING: ration_cut card');
    const picks = S1.viewCard(cut, card).choices.length;
    for (let index = 0; index < picks; index += 1) {
      const g = plain(cut);
      add(`card/${seed}/ration_cut/${index}`, g, { kind: 'choose_card', uid: card.uid, index }, () => { S1.chooseCard(g, card.uid, index); });
      const after = plain(g);
      after.session += S1.P.repealCool + 1;
      add(`repeal/${seed}/emergency_ration+pick${index}`, after, { kind: 'repeal', law: 'emergency_ration' }, () => S1.repealLaw(after, 'emergency_ration'));
      if (!full) continue;
      const settle = plain(g);
      settle.council = { options: [], idx: 0, locked: false, deals: [], result: null };
      add(`settle/${seed}/emergency_ration+pick${index}`, settle, { kind: 'advance' }, () => { S1.advance(settle); });
    }
    const late = plain(cut);
    late.session += S1.P.repealCool + 1;
    add(`repeal/${seed}/emergency_ration+unanswered`, late, { kind: 'repeal', law: 'emergency_ration' }, () => S1.repealLaw(late, 'emergency_ration'));
  }
  return cases;
}

export function lawPortVectors() {
  return { format: 'law-vectors-v1', seeds: SEEDS, laws: PORTED_LAWS, tables: tables(), cases: lawVectors() };
}

function main(): void {
  const out = resolve(import.meta.dirname, '../../s2/tests/fixtures/train/law_vectors.json');
  const data = lawPortVectors();
  const bytes = Buffer.from(`${JSON.stringify(data)}\n`, 'utf8');
  if (bytes.length > LIMIT) throw new Error(`F-FIXTURE-SIZE: ${bytes.length} > ${LIMIT}`);
  mkdirSync(dirname(out), { recursive: true });
  let identical = false;
  try { identical = readFileSync(out).equals(bytes); } catch { /* 첫 실행 */ }
  if (!identical) writeFileSync(out, bytes);
  console.log(JSON.stringify({ bytes: bytes.length, identical, laws: data.laws.length, cases: data.cases.length }));
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(import.meta.filename)) main();
