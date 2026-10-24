import { REP_ROLE } from './data';
import { CARD_EXTENSIONS, withAfford } from './cards';
import type { CardView, Choice } from './cards';
import { DISASTER_NAME, DZ, coalOf, lenOf, warmOf } from './disaster';
import type { DisasterKind } from './disaster';
import { revertLater } from './people';
import { foodCost, resolveStop } from './turn';
import type { Card, Game } from './state';

// 재난 대비 카드(events_disasters 4.1, 사용자 2026-10-09 20:23 '드물게 직접 죽임'). 예고 구간에 한 번, 재난을 켠 판에서만 온다.
// 고른 값은 g.disaster에 남고 disaster.ts가 읽는다. 문장은 자리표시다.

export const DISASTER_CARD_KINDS = ['disaster_prep'] as const;

const HUDDLE_COMMS = ['tail', 'front'] as const;

function prepView(g: Game, card: Card): CardView | null {
  if (card.kind !== 'disaster_prep') return null;
  const kind = (card.text === 'cold' ? 'cold' : 'blizzard') as DisasterKind;
  const warm = warmOf(kind);
  const half = warm * DZ.prepWarmMult;
  const body = kind === 'blizzard'
    ? `서쪽 하늘이 낮다. 내일부터 ${lenOf(kind)}구간 눈보라가 온다. 모든 칸 온기 −${warm}, 석탄이 구간마다 ${coalOf(kind)} 더 든다. 대비 없이 가면 밤사이 얼어 숨지는 사람이 나올 수 있다.`
    : `북쪽에서 찬 공기가 내려온다. 내일부터 ${lenOf(kind)}구간 한파가 온다. 모든 칸 온기 −${warm}, 석탄이 구간마다 ${coalOf(kind)} 더 든다. 대비 없이 가면 밤사이 얼어 숨지는 사람이 나올 수 있다.`;
  const choices: Choice[] = [
    { label: '석탄을 쌓아 둔다', say: '불을 미리 키워 둬라. 석탄은 이럴 때 쓰는 거다.', effs: [{ t: 'coal', v: -DZ.prepCoal }], special: 'dz_coal', extra: [`${DISASTER_NAME[kind]} 온기 −${half}로 줄어든다`, '재난 동안 더 드는 석탄이 없다'] },
    {
      label: '칸을 모아 잔다', say: '오늘 밤은 문을 열어 두고 한 칸에 붙어 자라. 서로 체온이 난로다.',
      effs: [...HUDDLE_COMMS.map(c => ({ t: 'base' as const, c, i: 2 as const, v: DZ.huddleCrowd })), { t: 'tension', v: DZ.huddleTension }],
      special: 'dz_huddle', extra: [`${DISASTER_NAME[kind]} 온기 −${half}로 줄어든다`, '과밀은 재난이 끝나면 원래대로 돌아간다'],
    },
    // 출발 미루기(날씨 명세 4장, DZ.wait로 끈다): 석탄과 긴장을 치르고 첫 구간을 선 채로 넘기며, 그날 같은 정차를 한 번 더 뒤진다.
    // 눈보라 예고 때만 있다(결정 338). 한파에도 두면 늘 미루기가 가장 나아진다(500판, 결정 332).
    ...(DZ.wait && kind === 'blizzard' ? [{
      label: '출발을 하루 미룬다', say: '하루 서서 기다린다. 첫날은 선 채로 넘긴다.',
      effs: [...(DZ.waitFood ? [{ t: 'food' as const, v: -Math.round(foodCost(g) * DZ.waitFood) }] : []), { t: 'coal' as const, v: -DZ.waitCoal }, { t: 'tension' as const, v: DZ.waitTension }],
      special: 'dz_wait', extra: [`${DISASTER_NAME[kind]} 첫 구간을 선 채로 넘긴다(${Math.max(1, lenOf(kind) - 1)}구간만 맞는다)`, `온기 −${half}로 줄어든다`, ...(DZ.waitSearch ? ['기다리는 날 이 정차를 같은 작업조로 한 번 더 뒤진다'] : [])],
    }] : []),
    { label: '그냥 간다', say: '예고일 뿐이다. 평소대로 간다.', effs: [], special: 'dz_none', extra: ['대비 없음'] },
  ];
  return {
    title: kind === 'blizzard' ? '눈보라 예고' : '한파 예고', required: true, key: 'disaster_prep',
    ...(kind === 'blizzard' ? { speaker: { name: g.comms.engine.leader.name, role: REP_ROLE.engine, comm: 'engine' as const } } : {}),
    body, choices: withAfford(g, choices),
  };
}

function prepChoose(g: Game, card: Card, choice: Choice): void {
  if (card.kind !== 'disaster_prep' || !g.disaster) return;
  const d = g.disaster;
  if (choice.special === 'dz_coal') d.prep = 'coal';
  else if (choice.special === 'dz_huddle') {
    d.prep = 'huddle';
    // 과밀은 효과로 이미 올렸다. 재난이 끝나는 정산(예고 구간 + 이어지는 구간 수)에 되돌린다.
    for (const c of HUDDLE_COMMS) revertLater(g, c, 2, DZ.huddleCrowd, lenOf(d.kind));
  } else if (choice.special === 'dz_wait') {
    d.prep = 'wait';
    waitSearch(g);
  }
  else if (choice.special === 'dz_none') d.unprepared = true;
}

/** 출발을 미룬 날 같은 정차를 같은 작업조로 한 번 더 뒤진다(결정 332·338, 날씨 명세 4.1 원안).
 * 위험은 따로 굴려(again) 같은 사람이 같은 운명을 두 번 받지 않는다. DZ.waitSearch 0이면 안 한다. */
function waitSearch(g: Game): void {
  // 대비 카드는 정산 때 고르니 보통 이번 구간의 정차가 아직 남아 있다. 없으면 지난 구간의 정차를 쓴다.
  const here = g.stop;
  const last = here ?? g.lastStop;
  if (!DZ.waitSearch || !last || (here && !here.done)) return;
  g.stop = { place: last.place, target: last.target ?? 'food', stay: 'normal', crewComm: last.crewComm, crewSize: last.crewSize, threat: last.threat, done: false, result: null, again: true };
  resolveStop(g, true);
  g.stop = here;
}

CARD_EXTENSIONS.push({ view: prepView, choose: prepChoose });
