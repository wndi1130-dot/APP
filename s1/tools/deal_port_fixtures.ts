// 의회 거래 수단의 전체 JSON 전/후(결정 426 PR 7 S2 둘째 판, 결정 433): 칸·수단마다 쓸 수 있나(toolStatus),
// 거래를 맺은 뒤(makeDeal), 거래를 안고 하는 표결, 공개 협상 약속을 판정하는 정산. 규칙은 S1에서 직접 실행한다.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import * as S1 from '../src/game';
import type { Comm, DealTool, Game, LawId } from '../src/game';
import { tables } from './turn_port_fixtures';
import { council } from './law_port_fixtures';

const SEEDS = ['deal-0', 'deal-1'];
const LIMIT = 16 * 1024 * 1024;
const plain = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T;
const TOOLS: DealTool[] = ['open', 'fetch', 'favor', 'bribe', 'blackmail', 'persuade'];

type Action = { kind: 'status' | 'deal'; comm: Comm; tool: DealTool; cond?: number; cut?: Comm } | { kind: 'cast_vote' } | { kind: 'advance' } | { kind: 'open_council'; emergency: boolean };

/** 거래가 다 열리게 손본 회기: 사치품·빚·비밀을 두고, 안건 하나를 올린다. coalLow면 석탄 위기라 난방 배당이 설득 근거가 된다. */
function table(seed: string, law: LawId, coalLow: boolean): Game {
  const g = council(seed);
  g.lux = 12;
  g.comms.engine.debt = true;
  g.comms.guard.debt = true;
  for (const c of ['tail', 'front', 'guard'] as Comm[]) S1.addSecret(g, c);
  if (coalLow) g.coal = S1.P.crisisLine - 5;
  g.council = { options: [{ law, repeal: false }], idx: 0, locked: false, deals: [], result: null };
  return g;
}

function dealVectors() {
  const cases: { name: string; action: Action; before: Game; after?: Game; out?: unknown }[] = [];
  // 묻기만 하는 칸(status)은 상태를 바꾸지 않으니 뒤 상태를 싣지 않는다(바뀌면 멈춘다).
  const add = (name: string, g: Game, action: Action, run: () => unknown) => {
    const before = plain(g);
    const out = run();
    if (g.dom || g.dark) throw new Error('S1a 밖의 표본');
    const after = plain(g);
    if (action.kind === 'status' && JSON.stringify(after) !== JSON.stringify(before)) throw new Error(`status가 상태를 바꿈: ${name}`);
    cases.push({ name, action, before, ...(action.kind === 'status' ? {} : { after }), ...(out === undefined ? {} : { out: plain(out) }) });
  };
  for (const seed of SEEDS) {
    for (const [law, coalLow] of [['heat_quota', true], ['patrol', false]] as [LawId, boolean][]) {
      const base = table(seed, law, coalLow);
      const at = `${seed}/${law}`;
      for (const c of S1.COMMS) {
        for (const tool of TOOLS) {
          const s = plain(base);
          add(`status/${at}/${c}/${tool}`, s, { kind: 'status', comm: c, tool }, () => S1.toolStatus(s, c, tool));
          if (tool === 'open') {
            const conds = S1.openConditions(base, c);
            conds.forEach((cond, i) => {
              const g = plain(base);
              const cut = cond.kind === 'cut' ? S1.OPPOSITE[c] : undefined;
              add(`deal/${at}/${c}/open${i}`, g, { kind: 'deal', comm: c, tool, cond: i, ...(cut ? { cut } : {}) }, () => S1.makeDeal(g, c, tool, i, cut));
            });
          } else {
            const g = plain(base);
            add(`deal/${at}/${c}/${tool}`, g, { kind: 'deal', comm: c, tool }, () => S1.makeDeal(g, c, tool));
          }
        }
      }
      // 이상주의 대표에게 내민 뇌물, 세 번째 협박의 소문.
      const ideal = plain(base);
      ideal.comms.front.leader.trait = 'ideal';
      add(`deal/${at}/front/bribe-ideal`, ideal, { kind: 'deal', comm: 'front', tool: 'bribe' }, () => S1.makeDeal(ideal, 'front', 'bribe'));
      const rumor = plain(base);
      rumor.blackmails = S1.P.blackmailReputation - 1;
      add(`deal/${at}/tail/blackmail-rumor`, rumor, { kind: 'deal', comm: 'tail', tool: 'blackmail' }, () => S1.makeDeal(rumor, 'tail', 'blackmail'));
      // 회기당 셋까지: 거래 셋을 안고 넷째를 묻고, 표결한다.
      const full = plain(base);
      S1.makeDeal(full, 'tail', 'open', 0);
      S1.makeDeal(full, 'engine', 'favor');
      S1.makeDeal(full, 'medtech', 'persuade');
      const four = plain(full);
      add(`status/${at}/front/bribe-fourth`, four, { kind: 'status', comm: 'front', tool: 'bribe' }, () => S1.toolStatus(four, 'front', 'bribe'));
      add(`vote/${at}/three-deals`, full, { kind: 'cast_vote' }, () => { S1.castVote(full); });
      const pool = plain(base);
      S1.makeDeal(pool, 'guard', 'favor');
      S1.makeDeal(pool, 'front', 'bribe');
      S1.makeDeal(pool, 'tail', 'blackmail');
      add(`vote/${at}/pool`, pool, { kind: 'cast_vote' }, () => { S1.castVote(pool); });
    }
    // 공개 협상 약속을 판정하는 정산: 레버·물자 조건마다 지킨 쪽과 어긴 쪽.
    const base = table(seed, 'patrol', false);
    for (const c of S1.COMMS) {
      S1.openConditions(base, c).forEach((cond, i) => {
        if (cond.now) return;
        for (const keep of [true, false]) {
          const g = plain(base);
          S1.makeDeal(g, c, 'open', i);
          const p = g.comms[c].promise;
          if (!p) return;
          p.due = g.seg;
          if (keep) {
            if (cond.kind === 'heat' || cond.kind === 'ration') g.comms[c][cond.kind] = Math.min(4, (p.baseline ?? 0) + 1);
            if (cond.kind === 'keep_ration') g.comms[c].ration = p.baseline ?? g.comms[c].ration;
          } else {
            if (cond.kind === 'heat' || cond.kind === 'ration' || cond.kind === 'keep_ration') g.comms[c][cond.kind === 'heat' ? 'heat' : 'ration'] = 0;
          }
          g.council = { options: [], idx: 0, locked: false, deals: [], result: null };
          add(`settle/${seed}/${c}/open${i}-${keep ? 'kept' : 'broken'}`, g, { kind: 'advance' }, () => { S1.advance(g); });
        }
      });
    }
  }
  // 거래로 안건 선택권을 넘겨받은 칸이 다음 회기를 열 때 안건을 고른다(openCouncil): 칸마다, 정기·비상 회기.
  for (const seed of SEEDS) {
    for (const c of S1.COMMS) {
      for (const emergency of [false, true]) {
        const g = council(seed);
        g.agendaHolder = c;
        add(`holder/${seed}/${c}/${emergency ? 'emergency' : 'regular'}`, g, { kind: 'open_council', emergency }, () => { S1.openCouncil(g, emergency); });
      }
    }
  }
  // 고르기는 원한을 빼고 센다(stance(..., false)), 같은 최고점이면 앞의 것. 그것이 갈리는 판을 찾아 둔다:
  // 원한을 셈했으면 다른 안건을 골랐을 판, 최고점이 둘 이상인 판. 회기를 열 때 원한이 줄지 않게 마지막 잘못을 미룬다.
  const scores = (g: Game, c: Comm, withGrudge: boolean) => (g.council?.options ?? []).map(o => S1.stance(g, c, o, withGrudge).score);
  const first = (xs: number[]) => xs.reduce((at, x, i) => (x > xs[at] ? i : at), 0);
  let split = 0;
  let tie = 0;
  for (const seed of [...SEEDS, 'deal-2', 'deal-3']) {
    for (const c of S1.COMMS) {
      for (const grudge of [1, S1.P.hostileGrudge]) {
        for (const tension of [0, 60]) {
          const g = council(seed);
          g.agendaHolder = c;
          g.comms[c].grudge = grudge;
          g.comms[c].lastOffense = g.session + 1;
          if (tension) g.tension = tension;
          const probe = plain(g);
          S1.openCouncil(probe, false);
          const without = scores(probe, c, false);
          if (without.length === 0) continue;
          const picked = probe.council!.idx;
          if (picked !== first(without)) throw new Error(`고르기 규칙이 다름: ${seed}/${c}`);
          const name = `${seed}/${c}/g${grudge}${tension ? '-t' + tension : ''}`;
          const splitHere = first(scores(probe, c, true)) !== picked;
          const tieHere = without.filter(x => x === without[picked]).length > 1;
          if (splitHere) split += 1;
          if (tieHere) tie += 1;
          if (splitHere || tieHere) add(`holderpick/${name}${splitHere ? '-grudge' : ''}${tieHere ? '-tie' : ''}`, g, { kind: 'open_council', emergency: false }, () => { S1.openCouncil(g, false); });
        }
      }
    }
  }
  if (split === 0) throw new Error('원한을 셈하면 갈리는 선택권 판을 못 찾음');
  if (tie === 0) throw new Error('최고점이 같은 선택권 판을 못 찾음');
  // 실제 흐름: 선택권을 거래로 사고 → 이번 안건 표결 → 다음 회기에서 그 칸이 고름 → 고른 안건 표결 → 그다음 회기.
  for (const seed of SEEDS) {
    const base = table(seed, 'patrol', false);
    const c = S1.COMMS.find(x => S1.openConditions(base, x).some(k => k.kind === 'agenda'));
    if (!c) throw new Error(`선택권 조건을 내놓는 칸이 없음: ${seed}`);
    const i = S1.openConditions(base, c).findIndex(k => k.kind === 'agenda');
    const g = plain(base);
    add(`holderflow/${seed}/1-deal`, g, { kind: 'deal', comm: c, tool: 'open', cond: i }, () => S1.makeDeal(g, c, 'open', i));
    add(`holderflow/${seed}/2-vote`, g, { kind: 'cast_vote' }, () => { S1.castVote(g); });
    add(`holderflow/${seed}/3-open`, g, { kind: 'open_council', emergency: false }, () => { S1.openCouncil(g, false); });
    add(`holderflow/${seed}/4-vote`, g, { kind: 'cast_vote' }, () => { S1.castVote(g); });
    add(`holderflow/${seed}/5-open`, g, { kind: 'open_council', emergency: false }, () => { S1.openCouncil(g, false); });
  }
  return cases;
}

export function dealPortVectors() {
  return { format: 'deal-vectors-v1', seeds: SEEDS, tools: TOOLS, tables: tables(), cases: dealVectors() };
}

function main(): void {
  const out = resolve(import.meta.dirname, '../../s2/tests/fixtures/train/deal_vectors.json');
  const data = dealPortVectors();
  const bytes = Buffer.from(`${JSON.stringify(data)}\n`, 'utf8');
  if (bytes.length > LIMIT) throw new Error(`F-FIXTURE-SIZE: ${bytes.length} > ${LIMIT}`);
  mkdirSync(dirname(out), { recursive: true });
  let identical = false;
  try { identical = readFileSync(out).equals(bytes); } catch { /* 첫 실행 */ }
  if (!identical) writeFileSync(out, bytes);
  console.log(JSON.stringify({ bytes: bytes.length, identical, cases: data.cases.length }));
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(import.meta.filename)) main();
