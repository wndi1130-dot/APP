import { COMM_NAME } from './data';
import type { Comm } from './data';
import { lawActive } from './state';
import { gone } from './budget';
import type { Card, Game } from './state';
import type { CardView, Choice, Eff } from './cards';

/** 서류 미루기(결정 514). 구간 예산의 pushed·deferred와 따로 센다. */
export const LATE = { max: 2, margin: 2, step: 2, grow: 0.5 };
export type LateKind = 'demand' | 'favor' | 'promise_ledger' | 'ration_cut' | 'front_curtain';

export function enableLate(g: Game): void { g.lateOn = true; }

export function lateKind(card: Card): LateKind | undefined {
  switch (card.kind) {
    case 'demand': case 'favor': case 'promise_ledger': case 'ration_cut': return card.kind;
    case 'travel': return card.text === 'front_curtain' ? 'front_curtain' : undefined;
    default: return undefined;
  }
}

export function lateComm(card: Card): Comm {
  return card.kind === 'ration_cut' || card.kind === 'travel' ? 'tail' : card.comm ?? 'tail';
}

/** 손실의 크기를 반올림한다. 처지·레버·빚·원한은 바꾸지 않는다. */
export function growLateEff(e: Eff, late: number): Eff {
  if (!('v' in e)) return e;
  const harm = (['coal', 'food', 'med', 'lux', 'trust', 'rel', 'pop'].includes(e.t) && e.v < 0)
    || (['tension', 'fear', 'injured', 'fervor'].includes(e.t) && e.v > 0);
  return harm ? { ...e, v: Math.sign(e.v) * Math.round(Math.abs(e.v) * (1 + LATE.grow * late)) } : e;
}

export function lateLoss(ch: Choice, c: Comm): number {
  return Math.max(0, -ch.effs.reduce((n, e) => n + (e.t === 'rel' && e.c === c ? e.v : 0), 0));
}

/** 같은 손실이면 앞 선택지. 기한 초과는 비용으로 막힌 선택지도 포함한다. */
export function worstLateChoice(choices: Choice[], c: Comm): Choice {
  return choices.filter(ch => ch.id !== 'later').reduce((worst, ch) => lateLoss(ch, c) > lateLoss(worst, c) ? ch : worst);
}

const DEMAND_WORDS: Record<Comm, [string, string]> = {
  tail: ['다음에 오라더니 또 왔다. 이번엔 답 듣고 간다.', '두 번 미뤘다. 세 번째는 우리가 알아서 한다.'],
  medtech: ['미룬 날부터 적어 뒀다. 환자 수가 늘었다.', '두 번 미룬 것까지 적어 뒀다. 더는 묻지 않는다.'],
  guard: ['기다렸다. 대원들은 더 못 기다린다.', '두 번이다. 대원들이 열차장 말을 안 믿기 시작했다.'],
  front: ['기다려 드렸습니다. 이번엔 답을 주셔야지요.', '두 번 기다려 드렸습니다. 세 번은 어렵겠습니다.'],
  engine: ['미룬 사이에 불이 한 번 꺼질 뻔했다. 답 달라.', '두 번 미뤘다. 불은 안 기다린다. 우리도 이제 안 기다린다.'],
};
const LATER_SAY: Record<LateKind, string> = {
  demand: '지금은 재고할 문제가 아니다. 다음 회기에 다시 와라.',
  favor: '더 중요한 문제가 있다. 그 부탁은 나중에 듣겠다.',
  promise_ledger: '장부는 나중에 펼치겠다. 지금은 더 중요한 문제가 있다.',
  ration_cut: '감축은 막 섰다. 예외는 지금 재고할 문제가 아니다.',
  front_curtain: '커튼 하나로 열차를 세울 수는 없다. 더 중요한 문제가 있다.',
};

// 이름 뒤 조사는 두 갈래 표기로 둔다: 화면이 이름을 줄인 뒤 받침을 보고 푼다(S1 shortText, S2 UiFonts.josa).
function lateBody(g: Game, card: Card, v: CardView, kind: LateKind, late: number): string {
  if (!late) return v.body;
  const c = lateComm(card);
  const twice = late >= 2;
  let head: string;
  let say: string;
  switch (kind) {
    case 'demand': {
      head = twice ? '두 번 미룬 요구다.' : '지난번에 미룬 요구다.';
      say = DEMAND_WORDS[c][twice ? 1 : 0];
      // 다시 온 사건의 본문에 인용이 없을 때도 승인된 말만 붙인다.
      const body = /"[^\"]*"\s*$/.test(v.body) ? v.body.replace(/"[^\"]*"\s*$/, `"${say}"`) : `${v.body} "${say}"`;
      return `${head} ${body}`;
    }
    case 'favor':
      head = twice ? '두 번 미룬 부탁이다.' : '지난번에 미룬 부탁이다.';
      say = c === 'front'
        ? (twice ? '두 번 미루셨습니다. 이번이 마지막으로 여쭙는 겁니다.' : '기다려 드렸습니다. 이번엔 들어 주시겠지요.')
        : (twice ? '두 번 미뤘다. 이번이 마지막으로 묻는 거다.' : '기다렸다. 이번엔 들어 줄 거냐.');
      break;
    case 'promise_ledger': {
      // 1차례 대표의 말은 본문 끝 따옴표 말(cards.ts LEDGER_SAY) 그대로, 두 번째부터 그 말을 바꾼다.
      const name = g.comms[c].leader.name;
      head = twice ? `${name}이(가) 장부를 또 내밀었다.` : `${name}이(가) 미뤘던 장부를 다시 내밀었다.`;
      if (!twice) return `${head} ${v.body}`;
      say = c === 'front' ? '이번엔 회기 앞에서 펼치겠습니다.' : '이번엔 회기 앞에서 펼친다.';
      return /"[^\"]*"\s*$/.test(v.body) ? `${head} ${v.body.replace(/"[^\"]*"\s*$/, `"${say}"`)}` : `${head} ${v.body} "${say}"`;
    }
    case 'ration_cut':
      if (twice) {
        // 두 번째부터는 대표의 말을 본문 첫 따옴표 말 자리에 바꿔 넣는다(요구 카드와 같은 꼴, 120자 안).
        head = '두 번 미룬 감축 배급 요구다.';
        say = '두 번 미뤘다. 우리 칸은 더 줄일 게 없다.';
        return /"[^"]*"/.test(v.body) ? `${head} ${v.body.replace(/"[^"]*"/, `"${say}"`)}` : `${head} ${v.body} "${say}"`;
      }
      head = '미룬 감축 배급 요구다. 꼬리칸 대표가 빈 그릇을 다시 들고 왔다.';
      say = '기다리라더니 그릇만 더 비었다.';
      break;
    case 'front_curtain':
      head = twice ? '두 번 미룬 커튼 일이다.' : '미뤘던 커튼 일이다. 커튼 앞에 모인 사람이 늘었다.';
      say = twice ? '두 번 미뤘다. 커튼이 걸린 채면 그게 답인 줄 알겠다.' : '커튼은 그대로다. 우리도 그대로 서 있다.';
      break;
  }
  return `${head} ${v.body} "${say}"`;
}

/** 기존 거르개 뒤, 마지막 비용 검사 앞에서만 붙인다. 꺼진 판은 같은 보기를 돌려준다. */
export function lateView(g: Game, card: Card, v: CardView): CardView {
  const kind = g.lateOn && lateKind(card);
  if (!kind) return v;
  const late = card.late ?? 0;
  const c = lateComm(card);
  const choices = late ? v.choices.map(ch => ({ ...ch, effs: ch.effs.map(e => growLateEff(e, late)) })) : v.choices;
  const loss = Math.max(0, ...choices.map(ch => lateLoss(ch, c)));
  const say = kind === 'demand' && v.key === 'demand:engine_shift'
    ? '교대는 나중에 다시 짠다. 지금은 더 중요한 문제가 있다.' : LATER_SAY[kind];
  return { ...v, body: lateBody(g, card, v, kind, late), late, lateLeft: Math.max(0, LATE.max - late),
    choices: [...choices, { id: 'later', label: '나중에 정한다', say,
      effs: [{ t: 'rel', c, v: -(loss + LATE.margin + LATE.step * late) }], special: 'late' }] };
}

export function lateLog(g: Game, card: Card): string {
  const c = lateComm(card);
  const comm = COMM_NAME[c];
  const name = g.comms[c].leader.name;
  switch (lateKind(card)) {
    case 'demand': return `${comm}의 요구를 끝내 미뤘다. 답을 기다리던 ${comm}이(가) 등을 돌렸다.`;
    case 'favor': return `${name}의 부탁을 끝내 미뤘다. ${name}은(는) 다시 부탁하러 오지 않았다.`;
    case 'promise_ledger': return `${comm}이(가) 내민 장부를 끝내 펼치지 않았다. ${comm}은(는) 그것을 물리친 것으로 기억한다.`;
    case 'ration_cut': return '감축 배급의 예외를 끝내 정하지 않았다. 꼬리칸 그릇부터 비었다.';
    case 'front_curtain': return '커튼 일을 끝내 미뤘다. 꼬리칸은 걸린 커튼을 열차장의 답으로 들었다.';
    default: return '';
  }
}

/** 다음 구간 처음. 여행 when은 다시 굴리지 않고, 대상이 없어졌거나 요구가 이미 풀렸으면(구간 예산의 gone과 같은 식) 버린다. */
export function lateNextSeg(g: Game): void {
  if (!g.lateOn || !g.lateCards?.length) return;
  const back = g.lateCards.filter(card => {
    if (!lateKind(card) || g.comms[lateComm(card)].pop <= 0 || gone(g, card)) return false;
    if (card.kind === 'favor' && card.who && card.who !== g.comms[lateComm(card)].leader.personId) return false;
    if (card.kind === 'ration_cut' && (!lawActive(g, 'emergency_ration') || g.rationCut)) return false;
    return !g.cards.some(c => c.uid === card.uid);
  });
  g.lateCards = [];
  g.cards.unshift(...back);
}
