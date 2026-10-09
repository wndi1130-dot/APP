import { REP_ROLE } from './data';
import { CARD_EXTENSIONS, withAfford } from './cards';
import type { CardView, Choice } from './cards';
import { DISASTER_NAME, DZ, coalOf, lenOf, warmOf } from './disaster';
import type { DisasterKind } from './disaster';
import { revertLater } from './people';
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
    { label: '석탄을 쌓아 둔다', say: '불을 미리 키워 둬라. 석탄은 이럴 때 쓰려고 있다.', effs: [{ t: 'coal', v: -DZ.prepCoal }], special: 'dz_coal', extra: [`${DISASTER_NAME[kind]} 온기 −${half}로 줄어든다`, '재난 동안 더 드는 석탄이 없다'] },
    {
      label: '칸을 모아 잔다', say: '오늘 밤은 문을 열어 두고 한 칸에 붙어 자라. 서로 체온이 난로다.',
      effs: [...HUDDLE_COMMS.map(c => ({ t: 'base' as const, c, i: 2 as const, v: DZ.huddleCrowd })), { t: 'tension', v: DZ.huddleTension }],
      special: 'dz_huddle', extra: [`${DISASTER_NAME[kind]} 온기 −${half}로 줄어든다`, '과밀은 재난이 끝나면 돌아온다'],
    },
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
  } else if (choice.special === 'dz_none') d.unprepared = true;
}

CARD_EXTENSIONS.push({ view: prepView, choose: prepChoose });
