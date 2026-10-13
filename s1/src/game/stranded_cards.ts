// 멈춘 열차의 수동차 원정 카드(구현명세 가 5.4~5.7). 출발·귀환·못 돌아옴·이어 감 소식 넷을 그린다. 규칙은 stranded.ts가 쥔다.
import { CARD_EXTENSIONS, VIEW_FILTERS } from './cards';
import type { CardView, Choice, Eff } from './cards';
import { COMM_NAME, P, REP_ROLE } from './data';
import type { Comm } from './data';
import { josa } from './josa';
import { crewAllowed, deputyOf, returnTrip, startTrip, supportLineText, tripPlan } from './stranded';
import type { Card, Game } from './state';

const who = (c: Comm): string => `${COMM_NAME[c]}${josa(COMM_NAME[c], '이/가')}`;

function speaker(g: Game, c: Comm): { name: string; role: string; comm: Comm } {
  return { name: g.comms[c].leader.name, role: REP_ROLE[c], comm: c };
}

/** 출발·재출발 선택지. 수색대는 지지가 문턱을 넘고 칸이 넷을 낼 때만, 「내가 간다」는 늘, 마지막은 보내지 않는 길. 첫 칸은 가는 길이다(봇이 첫 칸을 고른다). */
function sendChoices(g: Game, crewLabel: string, waitLabel: string, waitSay: string, waitTension: number): Choice[] {
  const out: Choice[] = [];
  const crew = crewAllowed(g) ? tripPlan(g, 'crew') : null;
  const cap = tripPlan(g, 'captain');
  if (crew) {
    out.push({
      label: crewLabel, say: '살아서 돌아와라. 그것만 하면 된다.', effs: [], special: 'trip_go_crew',
      extra: [`${crew.total}턴 예정`, `식량 −${crew.food}`, `${COMM_NAME[crew.comm]} ${crew.names.length}명이 자리를 비운다`, `돌아오면 ${COMM_NAME[crew.comm]} 관계 +${P.tripRelCrew}`],
    });
  }
  if (cap) {
    const dep = deputyOf(g);
    out.push({
      label: '내가 간다', say: `내가 간다. 돌아올 때까지 ${who(dep)} 맡는다.`, effs: [{ t: 'rel', c: dep, v: P.tripRelDeputy }], special: 'trip_go_captain',
      extra: [`${cap.total}턴 예정`, `식량 −${cap.food}`, '열차장이 없는 동안 회기가 닫힌다'],
    });
  }
  const wait: Eff[] = waitTension > 0 ? [{ t: 'tension', v: waitTension }] : [];
  out.push({ label: waitLabel, say: waitSay, effs: wait, special: 'trip_stay' });
  return out;
}

function departView(g: Game): CardView {
  const st = g.stranded;
  const km = st?.toNextKm ?? 0;
  const crew = crewAllowed(g) ? tripPlan(g, 'crew') : null;
  const c = crew?.comm ?? deputyOf(g);
  const body = crew
    ? `다음 역까지 ${km}km다. ${COMM_NAME[crew.comm]}에서 ${crew.names.length}명이 손을 들었다. 자루 둘과 나무 상자 하나를 수동차에 싣는다. ${supportLineText(g)}`
    : `다음 역까지 ${km}km다. 수동차 하나, 자루 둘. 아무도 열차장 대신 가겠다고 나서지 않는다. ${supportLineText(g)}`;
  return {
    title: '수동차', speaker: speaker(g, c), body, focus: c, required: true,
    choices: sendChoices(g, '수색대를 보낸다', '아직 안 보낸다', '하루만 더 본다.', P.tripWaitTension),
  };
}

function returnView(g: Game, card: Card): CardView {
  const t = g.stranded?.trip;
  if (!t) return { title: '수동차', body: '수동차는 빈 선로 위에 서 있다.', choices: [{ label: '알았다', effs: [] }], required: true };
  const effs: Eff[] = [{ t: 'coal', v: P.tripCoal }];
  if (t.leaderGoes && t.forced) effs.push({ t: 'trust', v: P.tripTrustForced });
  if (!t.leaderGoes) effs.push({ t: 'rel', c: t.comm, v: P.tripRelCrew });
  if (t.promise === 'yes') {
    if (g.lux >= P.promiseLux) effs.push({ t: 'lux', v: -P.promiseLux }, { t: 'rel', c: t.comm, v: P.promiseRel });
    else effs.push({ t: 'trust', v: P.promiseBrokenTrust });
  }
  return {
    title: '수동차가 돌아왔다', speaker: speaker(g, t.comm), focus: t.comm, required: true,
    body: `◂ 수동차가 어둠 속에서 나타났다. 자루 둘이 석탄으로 불룩하다. ${card.n ?? t.turn}턴 만이다.`,
    choices: [{
      label: '불을 넣는다', effs, special: 'trip_fire',
      say: t.leaderGoes ? '불을 넣어라. 내일 아침에 간다.' : `${who(t.comm)} 해냈다. 오늘은 그 칸부터 먹는다.`,
    }],
  };
}

function lostView(g: Game, card: Card): CardView {
  const c = card.comm ?? 'tail';
  const n = (card.who ?? '').split(',').filter(Boolean).length;
  return {
    title: '돌아오지 않았다', speaker: speaker(g, c), focus: c, required: true,
    body: `돌아올 날이 지났다. 선로 끝에 아무것도 없다. ${COMM_NAME[c]} 대표가 종이에 적어 둔 이름 ${n}개를 일지에 옮긴다. ${supportLineText(g)}`,
    choices: sendChoices(g, '다시 보낸다', '기다린다', '(열차장은 종이의 이름을 본다.)', 0),
  };
}

function extendView(g: Game, card: Card): CardView {
  const c = card.comm ?? 'tail';
  return {
    title: '무전', speaker: speaker(g, c), focus: c, required: true,
    body: `무전이 짧게 왔다. 역에 석탄이 없다. ${P.extendKm}km를 더 간다. 식량 ${card.n ?? 0}이 더 든다.`,
    choices: [{ label: '알았다', say: '기다린다. 불을 아껴라.', effs: [] }],
  };
}

function view(g: Game, card: Card): CardView | null {
  switch (card.kind) {
    case 'trip_depart': return departView(g);
    case 'trip_return': return returnView(g, card);
    case 'trip_lost': return lostView(g, card);
    case 'trip_extend': return extendView(g, card);
    default: return null;
  }
}

function choose(g: Game, _card: Card, choice: Choice): void {
  switch (choice.special) {
    case 'trip_go_crew': startTrip(g, 'crew'); break;
    case 'trip_go_captain': startTrip(g, 'captain'); break;
    case 'trip_fire': returnTrip(g); break;
    default: break;
  }
}

CARD_EXTENSIONS.push({ view, choose });

// 열차장이 수동차에 올라 있으면 열차장의 명령인 선택지는 닫힌다(「경비대를 푼다」, 「선로의 눈」의 「경비대만」).
VIEW_FILTERS.push((g, card, v) => {
  if (!g.stranded?.captainAway) return v;
  const drop = (shut: (c: Choice) => boolean): CardView => {
    const choices = v.choices.filter(c => !shut(c));
    return choices.length > 0 ? { ...v, choices } : v;
  };
  if (card.kind === 'tension_crisis' || card.kind === 'protest') return drop(c => c.label === '경비대를 푼다');
  if (card.kind === 'content' && card.text === 'ev_str_snow') return drop(c => c.special === 'content:c_guard_only');
  return v;
});
