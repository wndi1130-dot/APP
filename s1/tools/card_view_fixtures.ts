// 열차 턴 카드 보기 표본(결정 426 PR 7 S2 화면 앞판). S2가 S1 viewCard의 글(제목·본문·대표·대사·막힘 까닭)과
// 선택지 메타(costLines·politicsLines)를 옮길 때 맞대 볼 기준 값. S2 turn_cards.gd view가 받는 종류만 담는다.
// 규칙 코드는 읽기만 한다. 답은 모두 S1 함수가 내고, 여기서는 실제 판에서 나온 카드와 사건 기억·자원을 흔든 카드를 비추기만 한다.
// 사용: npx tsx tools/card_view_fixtures.ts [출력 경로=../s2/tests/fixtures/train/card_vectors.json]
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import * as S1 from '../src/game';
import type { Card, Comm, Game } from '../src/game';
import { tables } from './turn_port_fixtures';

const FORMAT = 'card-vectors-v1';
const SEEDS = ['card-0', 'card-1'];
const CHECKPOINTS = [6, 20, 44];
const LIMIT = 8 * 1024 * 1024;
/** S2 turn_cards.gd view가 그리는 종류. */
const KINDS = ['travel', 'info', 'need_warn', 'demand', 'favor', 'rescue', 'bitten', 'ration_cut', 'rep_sick', 'promise_ledger'];
/** 사건마다 고를 수 있는 길(cards.ts TRAVEL_EVENTS 선택지 id). */
const TRAVEL_PICKS: Record<string, string[]> = {
  tail_cold: ['fuel_front', 'blankets', 'endure'], crowd_fight: ['guard_break', 'widen', 'let_be'],
  front_curtain: ['curtain_open', 'side_front', 'call_reps'], water_tower: ['burn_melt', 'snow_melt', 'hold_on'],
  snow_drift: ['dig_all', 'dig_tail', 'plow'], abandoned_tender: ['tender_take', 'tender_pass'],
  sick_child: ['med_use', 'med_save'], ration_line: ['reshare', 'guard_line'], guard_frost: ['guard_heat', 'watch_less', 'hold_post'],
};
const plain = <T>(v: T): T => JSON.parse(JSON.stringify(v)) as T;

/** S2 view가 읽는 판의 몫만(나머지 키는 view가 보지 않는다). */
function state(g: Game) {
  return plain({
    seg: g.seg, coal: g.coal, food: g.food, med: g.med, lux: g.lux, injured: g.injured, passed: g.passed,
    eventLog: g.eventLog ?? {}, lastCrew: g.lastCrew ?? null, comms: g.comms, space: g.space ?? null, hands: g.hands ?? null,
    ...(g.lateOn !== undefined ? { lateOn: g.lateOn } : {}),
  });
}

function played(seed: string): { step: number; game: Game; seen: { game: Game; card: Card }[] } [] {
  const g = S1.createGame(seed);
  const out: { step: number; game: Game; seen: { game: Game; card: Card }[] }[] = [];
  let seen: { game: Game; card: Card }[] = [];
  for (let step = 1; step <= CHECKPOINTS[CHECKPOINTS.length - 1]; step += 1) {
    if (g.phase === 'end') break;
    for (const card of g.cards) if (KINDS.includes(card.kind)) seen.push({ game: plain(g), card: plain(card) });
    if (g.cards.length > 0) {
      const card = g.cards[0];
      const idx = S1.viewCard(g, card).choices.findIndex(c => !c.disabled);
      if (idx < 0 || !S1.chooseCard(g, card.uid, idx)) throw new Error(`Cannot choose ${card.kind}`);
    } else if (g.phase === 'stop' && g.stop && !g.stop.done) {
      S1.resolveStop(g, true);
    } else if (g.phase === 'council' && g.council && !g.council.result && S1.currentAgenda(g)) {
      if (!S1.castVote(g)) S1.advance(g);
    } else {
      if (!S1.primaryAction(g).ok) throw new Error(`Blocked in ${g.phase}`);
      S1.advance(g);
    }
    if (g.dom || g.dark) throw new Error('S1a 밖의 표본');
    if (CHECKPOINTS.includes(step)) { out.push({ step, game: plain(g), seen }); seen = []; }
  }
  return out;
}

type Row = { name: string; state: unknown; card: Card; view: unknown; costs: string[][]; pols: unknown[] };
const rows: Row[] = [];
function add(name: string, g: Game, card: Card): void {
  const v = S1.viewCard(g, card);
  rows.push({ name, state: state(g), card: plain(card), view: plain(v), costs: v.choices.map(ch => S1.costLines(ch)), pols: v.choices.map(ch => S1.politicsLines(ch)) });
}
const memo = (g: Game, key: string, pick: string, n: number) => { g.eventLog = { ...(g.eventLog ?? {}), [key]: { n, seg: Math.max(0, g.seg - 6), pick } }; };

for (const seed of SEEDS) {
  const points = played(seed);
  for (const p of points) {
    p.seen.forEach((s, i) => add(`played/${seed}/${p.step}/${i}/${s.card.kind}`, s.game, s.card));
    const base = p.game;
    const at = `${seed}/${p.step}`;
    let uid = 900;
    const card = (kind: string, more: Partial<Card> = {}): Card => ({ uid: uid++, kind, ...more });
    // 선로 사건 아홉: 처음, 지난 길마다 한 번·세 번·네 번째(worse가 세 번에서 멈춤).
    for (const [id, picks] of Object.entries(TRAVEL_PICKS)) {
      add(`travel/${at}/${id}/first`, plain(base), card('travel', { text: id }));
      for (const pick of picks) for (const n of [1, 3, 4]) {
        const g = plain(base);
        memo(g, id, pick, n);
        add(`travel/${at}/${id}/${pick}/${n}`, g, card('travel', { text: id }));
      }
    }
    // 급수탑의 눈 녹이기는 마지막 작업조 칸이 한다(조사 받침이 칸 이름마다 다르다).
    for (const c of S1.COMMS) for (const past of [null, 'snow_melt']) {
      const g = plain(base);
      g.lastCrew = c;
      if (past) memo(g, 'water_tower', past, 1);
      add(`travel/${at}/water_tower/crew-${c}/${past ?? 'first'}`, g, card('travel', { text: 'water_tower' }));
    }
    // 요구: 칸마다 처음·거절 기억·다른 기억, 난방/배급 갈래, 관계 말투, 기관실 노출 50 넘음.
    for (const c of S1.COMMS) {
      for (const [tag, heat, ration, rel] of [['mid', 2, 2, 0], ['heat4', 4, 1, 20], ['ration4', 1, 4, -20], ['low', 0, 0, -40]] as [string, number, number, number][]) {
        for (const past of [null, 'refuse', c === 'engine' ? 'shift_more' : 'heat_up']) {
          const g = plain(base);
          g.comms[c].heat = heat; g.comms[c].ration = ration; g.comms[c].rel = rel;
          if (c === 'engine') g.comms.engine.base[3] = tag === 'low' ? 80 : 20;
          if (past) memo(g, c === 'engine' && tag === 'low' ? 'demand:engine_shift' : `demand:${c}`, past, past === 'refuse' ? 2 : 1);
          add(`demand/${at}/${c}/${tag}/${past ?? 'first'}`, g, card('demand', { comm: c }));
        }
      }
    }
    // 부탁: 첫 번째와 두 번째, 의약품·사치품이 모자랄 때.
    for (const c of S1.COMMS) for (const again of [false, true]) for (const poor of [false, true]) {
      const g = plain(base);
      if (again) memo(g, `favor:${c}`, 'grant', 1);
      if (poor) { g.med = 0; g.lux = 0; }
      add(`favor/${at}/${c}/${again ? 'again' : 'first'}${poor ? '/poor' : ''}`, g, card('favor', { comm: c }));
    }
    // 부상자: 외부인 받지 않기 법, 지난 답, 몇 번째인지, 수색대원 이름.
    for (const ban of [false, true]) for (const past of [null, 'leave', 'leave_law', 'take_in', 'supplies_only']) for (const n of [1, 2, 5]) {
      if (!past && n > 1) continue;
      const g = plain(base);
      if (ban) g.passed.no_outsiders = 0; else delete g.passed.no_outsiders;
      if (past) memo(g, 'rescue', past, n);
      add(`rescue/${at}/${ban ? 'ban' : 'open'}/${past ?? 'first'}/${n}`, g, card('rescue', n === 2 ? {} : { who: '오윤' }));
    }
    // 물림: uid로 정해지는 부위 셋, 지난 답, 이름 있음/없음, 의약품 없음.
    for (const u of [0, 1, 2]) for (const past of [null, 'hide', 'leave']) {
      const g = plain(base);
      if (past) memo(g, 'bitten', past, 1);
      if (u === 2) g.med = 1;
      add(`bitten/${at}/${u}/${past ?? 'first'}`, g, { uid: 30 + u, kind: 'bitten', comm: S1.COMMS[u], ...(u === 1 ? {} : { who: '한별' }) });
    }
    // 감축 배급 요구: 처음과 다시.
    for (const past of [null, 'refuse']) {
      const g = plain(base);
      g.passed.emergency_ration = 0;
      if (past) memo(g, 'ration_cut', past, 1);
      add(`ration_cut/${at}/${past ?? 'first'}`, g, card('ration_cut', { comm: 'tail' }));
    }
    // 대표가 앓는다 / 일어났다, 의약품 없음.
    for (const c of S1.COMMS) for (const sick of [true, false]) {
      const g = plain(base);
      if (sick) { g.comms[c].sick = { since: g.seg, rep: plain(g.comms[c].leader) }; g.med = c === 'tail' ? 0 : g.med; } else delete g.comms[c].sick;
      add(`rep_sick/${at}/${c}/${sick ? 'sick' : 'up'}`, g, card('rep_sick', { comm: c }));
    }
    // 약속 장부(결과 아크, council_log.ts): 칸마다, 사치품이 모자랄 때, 대표가 앓아 측근이 나올 때.
    for (const c of S1.COMMS) for (const tag of ['ok', 'poor', 'sick'] as const) {
      const g = plain(base);
      if (tag === 'poor') g.lux = 0;
      if (tag === 'sick') g.comms[c].sick = { since: g.seg, rep: plain(g.comms[c].leader) };
      add(`promise_ledger/${at}/${c}/${tag}`, g, card('promise_ledger', { comm: c }));
    }
    // 법 요구 예고: 묶음마다 예고 순번 넷.
    for (const id of Object.keys(S1.NEEDS)) for (const n of [0, 1, 2, 3]) add(`need_warn/${at}/${id}/${n}`, plain(base), card('need_warn', { text: id, n }));
    // 알림: 제목·글이 있을 때와 없을 때.
    add(`info/${at}/full`, plain(base), card('info', { who: '알림 제목', text: '무언가 일어났다.' }));
    add(`info/${at}/bare`, plain(base), card('info'));
    // 살 수 없는 선택지: 석탄·식량·의약품·사치품 0, 레버가 이미 최대.
    for (const [id, key] of [['abandoned_tender', 'coal'], ['snow_drift', 'coal'], ['ration_line', 'food'], ['sick_child', 'med'], ['front_curtain', 'lux'], ['tail_cold', 'lux']] as [string, 'coal' | 'food' | 'med' | 'lux'][]) {
      const g = plain(base);
      g[key] = 0;
      add(`afford/${at}/${id}/${key}`, g, card('travel', { text: id }));
    }
    const maxed = plain(base);
    maxed.comms.guard.heat = 4;
    add(`afford/${at}/guard_frost/lever`, maxed, card('travel', { text: 'guard_frost' }));
  }
}

// 결정 514: 기존 입력의 순서와 내용 뒤에만 덧붙인다.
for (const c of S1.COMMS) for (const late of [0, 1, 2]) {
  for (const kind of ['demand', 'favor', 'promise_ledger']) for (const poor of [false, true]) {
    const g = S1.createGame('card-late'); S1.enableLate(g);
    if (poor) { g.med = 0; g.lux = 0; g.coal = S1.P.shiftCoal; }
    if (kind === 'demand') { g.comms[c].heat = 0; g.comms[c].ration = 0; }
    add(`late/${kind}/${c}/${late}/${poor ? 'poor' : 'base'}`, g, { uid: 1, kind, comm: c, late });
    if (kind === 'demand') {
      g.comms[c].heat = 4;
      add(`late/demand/${c}/${late}/ration`, g, { uid: 1, kind, comm: c, late });
      if (c === 'engine') {
        g.comms.engine.base[3] = 100;
        add(`late/demand/engine/${late}/${poor ? 'poor-shift' : 'shift'}`, g, { uid: 1, kind, comm: c, late });
      }
    }
  }
}
for (const late of [0, 1, 2]) for (const kind of ['ration_cut', 'travel']) for (const again of [false, true]) {
  const g = S1.createGame('card-late'); S1.enableLate(g);
  const card: Card = { uid: 1, kind, late, ...(kind === 'travel' ? { text: 'front_curtain' } : {}) };
  if (again) memo(g, kind === 'travel' ? 'front_curtain' : kind, kind === 'travel' ? 'side_front' : 'refuse', 2);
  add(`late/${kind}/${late}/${again ? 'again' : 'first'}`, g, card);
}
for (const kind of ['info', 'rescue', 'bitten']) {
  const g = S1.createGame('card-late'); S1.enableLate(g);
  add(`late/unsupported/${kind}`, g, { uid: 1, kind, comm: 'tail' });
}
add('late/old-save/off', S1.createGame('card-late-old'), { uid: 1, kind: 'favor', comm: 'front', late: 2 });

const out = resolve(process.argv.find(a => a.endsWith('.json')) ?? resolve(import.meta.dirname, '../../s2/tests/fixtures/train/card_vectors.json'));
const data = { format: FORMAT, seeds: SEEDS, checkpoints: CHECKPOINTS, kinds: KINDS,
  scope: 'S1a viewCard for the kinds S2 turn_cards.gd draws: played cards plus memo/resource variations; state is the part view reads',
  tables: tables(), cases: rows };
const bytes = Buffer.from(`${JSON.stringify(data)}\n`, 'utf8');
if (bytes.length > LIMIT) throw new Error(`F-FIXTURE-SIZE: ${bytes.length} > ${LIMIT}`);
mkdirSync(dirname(out), { recursive: true });
let identical = false;
try { identical = readFileSync(out).equals(bytes); } catch { /* 첫 실행 */ }
if (!identical) writeFileSync(out, bytes);
const kinds: Record<string, number> = {};
for (const r of rows) kinds[r.card.kind] = (kinds[r.card.kind] ?? 0) + 1;
console.log(JSON.stringify({ format: FORMAT, bytes: bytes.length, identical, cases: rows.length, kinds }));
