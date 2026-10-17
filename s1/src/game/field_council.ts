import { bump, bumpRel } from './ledger';
import { COMMS, COMM_NAME, CORPSE_LAWS } from './data';
import { MOTIONS } from './motions';
import type { MotionDef } from './motions';
import { agendaOptions, agendaTitle, isLawAgenda, sameAgenda } from './politics';
import { COUNCIL_LINK, journal } from './state';
import type { Agenda, Game, MotionAgenda } from './state';
import { FIELD, snapshot } from './field_receipt';
import type { FieldLine, FieldReturnRecord, SpecialCouncilRecord } from './field_receipt';

// 첫 귀환 뒤의 특별 회기 한 번(구현명세 S3 연결 v1 3절, 결정 290·294·303).
// 차례: 영수증 반영(field_receipt.ts) → 상징물 쓰임 고르기 → 안건 고르기 → 전망 → 표결 → 정산.
// 회기는 비상 소집처럼 열린다(회기 수에 들고 적의 시계는 한 칸 미룬다, 거래는 정규 회기와 같다). 정규 회기 3·6·9 구간 규칙은
// 건드리지 않는다: 특별 회기가 닫히면 구간 정산으로 가지 않고 연 단계로 돌아가, 그 뒤는 평소대로 흐른다.
// 「정산」은 표결이 적용한 신임·긴장·관계 값을 보여 주는 단계다. 구간 정산(turn.ts settle)을 한 번 더 돌지 않는다.
// 영수증이 없는 판은 이 길을 지나지 않으니 500판 값은 그대로다.

const sign = (n: number) => (n >= 0 ? `+${n}` : `−${-n}`);
const nameOf = (a: MotionAgenda) => (a.subject ? COMM_NAME[a.subject] : '그 칸');

/** 상징물 안건: 내건 상징물을 열차 앞에 세울지 의회가 정한다(결정 302의 내걸기를 고른 판만). */
const FIELD_SYMBOL: MotionDef = {
  need: 51,
  lean: (_g, c, a) => ({ mat: c === a.subject ? FIELD.symbolLean : 0, ideo: 0 }),
  title: a => `${nameOf(a)}의 상징물을 열차 앞에 세우기`,
  changes: (_g, a) => [
    `통과: ${nameOf(a)}과(와)의 관계 ${sign(FIELD.symbolRel)}`,
    `부결: ${nameOf(a)}과(와)의 관계 ${sign(-FIELD.symbolRel)}`,
  ],
  onPass: (g, a) => {
    if (!a.subject) return;
    if (FIELD.symbolRel) bumpRel(g, a.subject, FIELD.symbolRel, 'symbol');
    journal(g, `${nameOf(a)}의 상징물이 열차 앞에 섰다.`, 'good');
  },
  onFail: (g, a) => {
    if (!a.subject) return;
    if (FIELD.symbolRel) bumpRel(g, a.subject, -FIELD.symbolRel, 'symbol');
    journal(g, `${nameOf(a)}의 상징물은 세우지 않기로 했다. 그 칸 사람들이 말을 아낀다.`, 'bad');
  },
  rank: 'player',
};

/** 약속 안건: 목격된 약속이 돌아왔을 때(결정 301). 지켰으면 그 일을 기록에 올리고, 어겼으면 약속받은 칸이 따진다. */
const FIELD_PROMISE: MotionDef = {
  need: 51,
  lean: (_g, c, a) => ({ mat: c === a.subject ? FIELD.promiseLean : 0, ideo: 0 }),
  title: a => (a.verdict === 'kept' ? `${nameOf(a)}과(와)의 약속을 지킨 것을 기록에 올리기` : `${nameOf(a)}과(와)의 약속 어김 추궁`),
  changes: (_g, a) => a.verdict === 'kept'
    ? [`통과: 신임 ${sign(FIELD.promiseTrust)}`, '부결: 바뀌는 것 없음']
    : [`통과: 신임 ${sign(-FIELD.promiseTrust)}, ${nameOf(a)}과(와)의 관계 ${sign(FIELD.promiseRel)}`, `부결: ${nameOf(a)}과(와)의 관계 ${sign(-FIELD.promiseRel)}`],
  onPass: (g, a) => {
    if (!a.subject) return;
    if (a.verdict === 'kept') {
      if (FIELD.promiseTrust) bump(g, 'trust', FIELD.promiseTrust, 'promise');
      journal(g, `${nameOf(a)}과(와)의 약속을 지킨 일이 기록에 올랐다.`, 'good');
    } else {
      if (FIELD.promiseTrust) bump(g, 'trust', -FIELD.promiseTrust, 'promise');
      if (FIELD.promiseRel) bumpRel(g, a.subject, FIELD.promiseRel, 'promise');
      journal(g, `의회가 ${nameOf(a)}의 추궁을 받아들였다. 열차장이 약속을 어긴 것이 기록에 남는다.`, 'bad');
    }
  },
  onFail: (g, a) => {
    if (!a.subject || a.verdict === 'kept') return;
    if (FIELD.promiseRel) bumpRel(g, a.subject, -FIELD.promiseRel, 'promise');
    journal(g, `${nameOf(a)}의 추궁이 부결됐다. 그 칸은 들어 주지 않았다고 기억한다.`, 'bad');
  },
  rank: 'player',
};

Object.assign(MOTIONS, { field_symbol: FIELD_SYMBOL, field_promise: FIELD_PROMISE });

export type SpecialFrom = 'corpse' | 'symbol' | 'promise' | 'regular';
export interface SpecialCandidate { agenda: Agenda; from: SpecialFrom }

/**
 * 특별 회기 안건 후보(결정 303). 영수증에서 뽑힌 것 먼저: ① 시신(이 정차에 죽은 사람이 있고 시신 법을 올릴 수 있을 때)
 * ② 상징물(내걸기를 골랐을 때) ③ 약속(목격된 약속이 지킴이나 어김으로 돌아왔을 때, 어김을 먼저).
 * 셋보다 적으면 그 시점의 보통 안건(위기 법이 걸렸으면 그 법들)으로 채운다. 셋을 넘지 않는다.
 */
export function specialCandidates(g: Game, rec: FieldReturnRecord): SpecialCandidate[] {
  const regular = agendaOptions(g).options;
  const out: SpecialCandidate[] = [];
  if (rec.dead.length > 0) {
    const corpse = regular.find(o => isLawAgenda(o) && !o.repeal && !o.ratify && CORPSE_LAWS.includes(o.law));
    if (corpse) out.push({ agenda: corpse, from: 'corpse' });
  }
  if (rec.symbol?.use === 'hang_before_session') {
    out.push({ agenda: { kind: 'motion', motion: 'field_symbol', subject: rec.symbol.groupId, person: rec.symbol.id }, from: 'symbol' });
  }
  const told = rec.verdicts.filter(v => v.verdict !== 'unknown').sort((a, b) => (a.verdict === 'broken' ? 0 : 1) - (b.verdict === 'broken' ? 0 : 1));
  const v = told[0];
  if (v && v.verdict !== 'unknown') {
    out.push({ agenda: { kind: 'motion', motion: 'field_promise', subject: v.madeTo, person: v.id, verdict: v.verdict }, from: 'promise' });
  }
  for (const o of regular) {
    if (out.length >= 3) break;
    if (!out.some(c => sameAgenda(c.agenda, o))) out.push({ agenda: o, from: 'regular' });
  }
  return out.slice(0, 3);
}

/** 특별 회기를 연다. 첫 귀환 기록이 있고, 상징물 쓰임을 이미 골랐고, 아직 연 적이 없을 때 한 번만. 열면(또는 열지 못하면) 그 기록을 돌려준다. */
export function openSpecialCouncil(g: Game): SpecialCouncilRecord | null {
  const fr = g.fieldReturns;
  const rec = fr?.records[0];
  if (!fr || !rec || fr.special) return null;
  if (rec.symbol && !rec.symbol.use) return null;
  if (g.phase === 'council' || g.phase === 'end') return null;
  const base = { receiptId: rec.receiptId, seg: g.seg, back: g.phase, candidates: [] };
  if (g.dark?.martial) {
    fr.special = { ...base, status: 'skipped', why: '의회가 닫혀 있다' };
    journal(g, '첫 귀환을 두고 의회를 열 수 없다. 의회가 닫혀 있다.', 'dark');
    return fr.special;
  }
  // 비상 소집과 같은 회기 셈(politics.ts openCouncil의 emergency): 회기 수에 들고 적의 시계는 한 칸 미룬다.
  g.session += 1;
  for (const c of COMMS) g.comms[c].lastOffense += 1;
  const cands = specialCandidates(g, rec);
  if (cands.length === 0) {
    fr.special = { ...base, status: 'skipped', why: '올릴 안건이 없다' };
    journal(g, '첫 귀환을 두고 의회를 불렀지만 올릴 안건이 없었다.');
    return fr.special;
  }
  g.council = { options: cands.map(c => c.agenda), idx: 0, locked: false, deals: [], result: null, emergency: true, special: true };
  fr.special = {
    ...base, status: 'opened', candidates: cands.map(c => ({ title: agendaTitle(c.agenda), from: c.from })), before: snapshot(g),
  };
  g.phase = 'council';
  journal(g, `첫 귀환을 두고 특별 회기를 연다. 안건 후보 ${cands.length}개.`);
  return fr.special;
}

/** 특별 회기를 닫고 연 단계로 돌아간다(주 단추). 표결이 끝나야 닫힌다. 고른 안건과 결과, 표결 뒤의 값을 기록에 남긴다. */
export function leaveSpecialCouncil(g: Game): boolean {
  const council = g.council;
  const sp = g.fieldReturns?.special;
  if (!council?.special || g.phase !== 'council' || !sp || sp.status !== 'opened' || !council.result) return false;
  const r = council.result;
  sp.picked = agendaTitle(council.options[council.idx]);
  sp.result = { yes: r.yes, no: r.no, need: r.need, passed: r.passed };
  sp.after = snapshot(g);
  g.phase = sp.back;
  return true;
}

COUNCIL_LINK.leaveSpecial = leaveSpecialCouncil;

export type FieldStep = 'choose_symbol' | 'council' | 'done';

/**
 * 귀환 반영 뒤 다음 걸음 하나(이식 줄기와 화면이 이 함수 하나로 이어 붙인다).
 * 상징물 쓰임을 아직 안 골랐으면 'choose_symbol'(field_receipt.ts chooseSymbolUse), 고를 게 없으면 특별 회기를 열고 'council',
 * 회기가 끝났거나 열 수 없으면 'done'.
 */
export function nextFieldStep(g: Game): FieldStep {
  const fr = g.fieldReturns;
  const rec = fr?.records[0];
  if (!fr || !rec) return 'done';
  if (rec.symbol && !rec.symbol.use) return 'choose_symbol';
  if (!fr.special) return openSpecialCouncil(g)?.status === 'opened' ? 'council' : 'done';
  return g.phase === 'council' && g.council?.special ? 'council' : 'done';
}

/** 회기 전망 옆에 둘 「바뀐 이유」 줄: 첫 귀환에서 표에 닿은 상징물·약속 줄(결정 290·294, 확인 줄 13·14). 화면은 읽기만 한다. */
export function specialReasons(g: Game): FieldLine[] {
  const rec = g.fieldReturns?.records[0];
  return rec ? rec.lines.filter(l => l.k === 'promise' || l.k === 'symbol') : [];
}
