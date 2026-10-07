import { COMM_NAME, COMMS, LAWS } from '../data';
import type { Comm } from '../data';
import { MOTION_SOURCES, MOTIONS } from '../motions';
import type { MotionDef } from '../motions';
import { isLawAgenda, offend } from '../politics';
import { clamp, journal, seats, stageOf } from '../state';
import type { Agenda, Game, MotionAgenda, VoteResult } from '../state';
import { B } from './data';
import { caseById, crimeTitle, level, LEVEL_WORD, topByClues, updateFlags } from './cases';
import { closeChronicle, cross, scene } from './chronicle';
import { DEFENSE_LINES } from './lines';
import { newEmber } from './embers';
import { byId, commOf, darkCard, eun, nameOf, rivals } from './state';

// 재판(4.4)과 불신임 동의(제안 (6), 1.7)를 의회 안건 표(motions.ts)에 더한다. 입장은 stance()가 lean()에서 받아
// 관계 단계와 적의 규칙을 법과 똑같이 얹는다. 그래서 협상·뇌물·협박이 안건 종류를 몰라도 돈다.

const nameOfId = (id?: string) => (id ? byId(id)?.name ?? id : '');

/** 재판: '○○는 유죄다'(51). 입장 = 증거 단계(증거 +2, 정황 0, 소문 −2) + 피해 칸 +1, 피고 칸 −2. */
const TRIAL: MotionDef = {
  need: 51,
  lean: (g, c, a) => {
    const cs = caseById(g, a.ref);
    const s = cs?.sus.find(x => x.id === a.person);
    const lv = s ? level(s) : 0;
    const mat = (lv === 2 ? 2 : lv === 1 ? 0 : -2) + (cs && c === cs.victimComm ? 1 : 0) + (a.person && c === commOf(g, a.person) ? -2 : 0);
    return { mat: clamp(mat, -3, 3), ideo: 0 };
  },
  title: a => `${nameOfId(a.person)}${eun(nameOfId(a.person))} 유죄다`,
  changes: (g, a) => {
    const cs = caseById(g, a.ref);
    const s = cs?.sus.find(x => x.id === a.person);
    const out = [
      cs ? `${crimeTitle(g, cs)} · 증거 단계 ${s ? LEVEL_WORD[level(s)] : '소문'}` : '',
      `피고의 말: "${defenseLine(g, a)}"`,
      '통과: 벌을 고른다(배급 끊기, 근신, 하차 명령, 처형)',
      '부결: 피고가 풀리고 그 칸 관계 +3, 군중이 다음 구간에 온다',
    ];
    const pre = cs ? g.dark!.precedent[cs.kind] : undefined;
    if (pre) out.splice(1, 0, `지난번엔 ${LEVEL_WORD[pre.level]}만으로 ${pre.guilty ? '유죄' : '무죄'}를 냈다.`);
    return out.filter(Boolean);
  },
  onPass: (g, a) => verdict(g, a, true),
  onFail: (g, a) => verdict(g, a, false),
  rank: 'player',
};

/** 피고의 반론 한 줄(R3). 진범이 아니면 절반은 확인할 수 있는 사실이다(더 캐면 다른 사람을 가리키는 단서가 된다). */
export function defenseLine(g: Game, a: MotionAgenda): string {
  const cs = caseById(g, a.ref);
  const i = ((a.ref ?? 0) * 7 + (a.person?.length ?? 0)) % DEFENSE_LINES.length;
  return DEFENSE_LINES[i].replaceAll('{place}', cs?.where ?? '그곳');
}

function verdict(g: Game, a: MotionAgenda, guilty: boolean): void {
  const d = g.dark!;
  const cs = caseById(g, a.ref);
  if (!cs || !a.person) return;
  const s = cs.sus.find(x => x.id === a.person);
  if (!s) return;
  d.stats.trials += 1;
  cs.triedAt = g.session;
  const lv = level(s);
  const comm = commOf(g, s.id);
  // 선례: 같은 증거 단계에서 반대 판결이면 지난번 피고의 칸이 잣대가 바뀌었다고 본다(관계 −2).
  const pre = d.precedent[cs.kind];
  if (pre && pre.level === lv && pre.guilty !== guilty) g.comms[pre.comm].rel = clamp(g.comms[pre.comm].rel - 2, -100, 100);
  d.precedent[cs.kind] = { level: lv, guilty, comm };
  // 재판에서 표를 산 것은 가장 어두운 거래라 일대기에 따로 남는다.
  if ((g.council?.deals ?? []).some(x => x.tool === 'bribe' || x.tool === 'blackmail' || x.tool === 'favor')) {
    cross(g, 'trial_bought');
    scene(g, 'trial_bought', 3, `${g.seg}구간, ${nameOf(g, s.id)}의 재판에서 표를 샀다.`, [s.id]);
  }
  if (guilty) {
    d.stats.guilty += 1;
    darkCard(g, { kind: 'dark:punish', n: cs.id, who: s.id, comm, text: 'trial' });
    return;
  }
  d.stats.acquitted += 1;
  s.acq = true;
  g.comms[comm].rel = clamp(g.comms[comm].rel + 3, -100, 100);
  cs.status = 'open';
  if (cs.clock !== null) cs.clock = 1;
  journal(g, `${nameOf(g, s.id)}이(가) 풀려났다. 사람들은 다음 이름을 찾는다.`, 'dark');
  updateFlags(g);
}

/** 불신임 동의(51, 제안 (6)). 입장 = 관계 단계 + 지킨 약속 − 어긴 약속(법의 이념은 넣지 않는다). 찬성이 열차장 반대라
 * stance()가 더하는 관계 단계를 뒤집어 낸다(mat에 −2×단계). 적의 3 지도자가 올린 안건엔 적의 규칙이 그대로 기운다. */
const NO_CONFIDENCE: MotionDef = {
  need: 51,
  lean: (g, c) => {
    const d = g.dark!;
    const band = stageOf(g.comms[c].rel).band;
    return { mat: clamp(d.broken[c] - d.kept[c], -2, 2) - 2 * band, ideo: 0 };
  },
  title: () => '열차장 불신임',
  changes: () => ['통과: 열차장이 물러난다(판이 끝난다)', '부결: 아무 일 없다'],
  onPass: g => {
    g.end = 'ousted';
    g.phase = 'end';
    journal(g, '의회가 열차장을 끌어내렸다.', 'bad');
    closeChronicle(g);
  },
  onFail: (g, a) => {
    if (a.by) g.comms[a.by].rel = clamp(g.comms[a.by].rel - 3, -100, 100);
    journal(g, '불신임 동의가 부결됐다. 열차장은 자리를 지켰다.');
  },
  rank: 'confidence',
};

/** 비상대권 중 의회에 거는 일은 없다. 이 둘은 S1b 판에서만 안건이 된다. */
Object.assign(MOTIONS, { trial: TRIAL, no_confidence: NO_CONFIDENCE });

/** 회기마다 낼 S1b 안건 */
MOTION_SOURCES.push(g => {
  const d = g.dark;
  if (!d) return [];
  const out: MotionAgenda[] = [];
  // 불신임: 신임 30 아래로 2구간, 또는 적의 3 지도자가 올렸다(그 지도자가 아직 대표이고 조용히 처리되지 않았으면).
  const by = d.confBy && g.comms[d.confBy].leader.personId === d.confLeader ? d.confBy : null;
  if (by || d.lowTrust >= 2) {
    const raiser = by ?? [...COMMS].sort((a, b) => g.comms[a].rel - g.comms[b].rel)[0];
    out.push({ kind: 'motion', motion: 'no_confidence', by: raiser });
  }
  for (const c of d.cases) {
    if (c.status !== 'trial') continue;
    const top = topByClues(g, c);
    if (top) out.push({ kind: 'motion', motion: 'trial', person: top.id, ref: c.id, subject: c.victimComm });
  }
  return out;
});

/** 의회를 연 직후(turn.ts 훅): 재판을 걸어 둔 게 있으면 그 안건을 먼저 고른 자리에 둔다(열차장이 이미 넘긴 일).
 * 위기 법에 밀려 재판이 못 오른 사건은 군중 시계가 그 회기만큼 한 번 멈춘다(4.4 밀린 안건의 기한). */
export function darkCouncilOpen(g: Game): void {
  const d = g.dark;
  const council = g.council;
  if (!d || !council) return;
  d.councilAt = g.session;
  for (const c of d.cases.filter(x => x.status === 'trial')) {
    const i = council.options.findIndex(o => !isLawAgenda(o) && o.motion === 'trial' && o.ref === c.id);
    if (i >= 0) {
      if (!council.locked && !council.options.slice(0, i).some(o => !isLawAgenda(o) && o.motion === 'no_confidence')) council.idx = i;
      continue;
    }
    if (!c.paused && c.clock !== null) { c.paused = true; c.clock += 1; }
    if (c.promised === g.session) c.promised = g.session + 1; // 위기 법이 밀어낸 회기는 약속 위반이 아니다
  }
  // 불신임은 한 번 오르면 끝난다(통과하면 판이 끝나고, 부결이면 다시 조건이 서야 오른다).
  if (council.options.some(o => !isLawAgenda(o) && o.motion === 'no_confidence')) { d.confBy = null; d.confLeader = null; d.lowTrust = 0; }
}

/** 회기를 마친 정산: 약속한 재판이 이 회기에 열리지 않았으면 약속 위반(S1a 수치 3.1의 값). */
export function trialPromises(g: Game): void {
  const d = g.dark!;
  if (d.councilAt !== g.session) return;
  for (const c of d.cases) {
    if (c.promised !== g.session || c.triedAt === g.session) continue;
    c.promised = undefined;
    const v = c.victimComm;
    g.trust = clamp(g.trust - (seats(g)[v] >= 30 ? 12 : 8), 0, 100);
    g.comms[v].rel = clamp(g.comms[v].rel - 20, -100, 100);
    g.comms[v].fervor = Math.min(3, g.comms[v].fervor + 1);
    g.tension = clamp(g.tension + 3, 0, 100);
    g.stats.promisesBroken += 1;
    d.broken[v] += 1;
    offend(g, v);
    journal(g, `${COMM_NAME[v]}에게 약속한 재판이 열리지 않았다.`, 'bad');
  }
}

/** 표결 뒤(politics.ts 훅): 원수 두 대표가 갈렸으면 진 쪽에 20% 불씨, 위기 법 요구 없이 고른 가혹 법은 수단 1. */
export function afterVote(g: Game, agenda: Agenda, r: VoteResult): void {
  const d = g.dark;
  if (!d) return;
  if (isLawAgenda(agenda) && r.passed && !agenda.repeal && !agenda.forced && !agenda.ratify && LAWS[agenda.law].tag === '가혹') cross(g, 'harsh_chosen');
  if (r.decree) return;
  const side = (c: Comm) => Math.sign(r.byComm[c].yes - r.byComm[c].no);
  for (const a of COMMS) for (const b of COMMS) {
    if (a >= b || !rivals(a, b) || side(a) * side(b) !== -1) continue;
    const loser = (side(a) === 1) !== r.passed ? a : b;
    const winner = loser === a ? b : a;
    newEmber(g, loser, winner, 'rival', B.rivalP);
  }
}

