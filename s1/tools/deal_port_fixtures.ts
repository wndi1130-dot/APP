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

type Action = { kind: 'status' | 'deal'; comm: Comm; tool: DealTool; cond?: number; cut?: Comm } | { kind: 'cast_vote' } | { kind: 'advance' };

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
