import { COMM_NAME, COMMS, REP_ROLE } from './data';
import type { Comm } from './data';
import { AR, fetchOdds, placeLines, placeText, sendFetch, someOf, takeIn } from './arrivals';
import { CARD_EXTENSIONS, memo, withAfford } from './cards';
import type { CardView, Choice, Eff } from './cards';
import { stance } from './politics';
import { journal, situation } from './state';
import type { Card, Game } from './state';

// 사람이 들어오는 사건의 카드(arrivals.ts가 올린다). 선택지는 지금 확실한 비용과 고르는 즉시 생기는 정치 변화만 보인다(결정 364).
// 「건강한 사람만 골라 받기」 갈래, 들어온 사람을 따로 떼어 두는 칸이나 처치 갈래는 두지 않는다(금지선, 명세 3장).
// 글은 자리표시다.

const nums = (s: string | undefined): number[] => (s ? s.split(',').filter(x => x !== '').map(Number) : []);
const names = (s: string | undefined): string[] => (s ? s.split('|').filter(x => x !== '') : []);
/** 돌려보냄 갈래의 값(AR.turnCost를 곱한다) */
const turned = (effs: Eff[]): Eff[] => effs.map(e => ('v' in e && typeof e.v === 'number' ? { ...e, v: Math.round(e.v * AR.turnCost) } : e)) as Eff[];

/** 수색대 위험 줄(정찰 줄과 같은 꼴). 정찰로 기척을 모르면 「위험 모름」 */
function riskLine(card: Card): string {
  const danger = Number(card.vals?.danger ?? 1);
  if (card.vals?.known !== '1') return '바깥 기척 모름';
  if (danger <= 0) return '바깥이 고요하다';
  const { qd, qh } = fetchOdds(danger);
  return `한 사람당 크게 다침 ${Math.round(qh * 100)}% · 못 돌아옴 ${Math.round(qd * 100)}%`;
}

/** 「외부인 받지 않기」를 낸 쪽: 법의 이념과 물질로 법을 바라는 칸(관계는 빼고 본다). 누가 발의했는지는 저장하지 않으니 이걸로 대신한다 */
export function lawBackers(g: Game): Comm[] {
  return COMMS.filter(c => {
    const s = stance(g, c, { law: 'no_outsiders', repeal: false }, false);
    return s.ideo + s.mat > 0;
  });
}

function arrivalView(g: Game, card: Card): CardView {
  const groups = nums(card.vals?.groups);
  const hurtIn = nums(card.vals?.hurt);
  const n = groups.reduce((a, b) => a + b, 0);
  const atStop = card.text === 'stop';
  const ban = g.passed.no_outsiders !== undefined;
  const past = memo(g, 'arrival');
  const crew = names(card.vals?.crew);
  const some = someOf(groups);
  const someGroups = groups.slice(0, some);
  const someN = someGroups.reduce((a, b) => a + b, 0);
  const hurtSome = hurtIn.filter(i => i < some).length;
  const where = atStop ? '승강장 끝에' : '선로 둑에';
  const echo = past?.pick === 'turn_away' || past?.pick === 'turn_away_law' ? ' 지난번 돌려보낸 무리 이야기를 칸 사람들이 아직 한다.'
    : past?.pick === 'take_all' || past?.pick === 'take_some' ? ` 지난번 받은 사람들로 꼬리칸 과밀이 ${Math.round(situation(g, 'tail')[2])}이다.`
      : past?.pick === 'escort' ? ' 지난번 수색대를 붙여 데려온 일을 다들 기억한다.' : '';
  const body = `${where} ${n}명이 서 있다. 가족 ${groups.length}무리가 자루와 나무 상자를 졌다.${hurtIn.length ? ` 다친 사람이 ${hurtIn.length}명 있다.` : ''} 며칠을 굶었고 추위에 지쳤다. 태워 달라고 한다.${ban ? ' 외부인 받지 않기 법이 있다.' : echo}`;
  const speaker = atStop ? { name: card.who ?? '수색대', role: '수색대' } : { name: g.comms.engine.leader.name, role: REP_ROLE.engine, comm: 'engine' as Comm };
  const inj = (k: number): Eff[] => (k > 0 ? [{ t: 'injured', v: k }] : []);
  const choices: Choice[] = ban ? [
    { id: 'turn_away_law', label: '법대로 보낸다', say: '법은 법이다. 보내라.', effs: turned([{ t: 'trust', v: -1 }]), special: 'arrive_turn', witness: atStop && AR.witness > 0 },
  ] : [
    { id: 'turn_away', label: '돌려보낸다', log: `피난민 무리: ${n}명을 돌려보냈다.`, say: '자리가 없다. 갈 길을 알려 주고 보내라.', effs: turned([{ t: 'trust', v: -2 }, { t: 'rel', c: 'medtech', v: -3 }, { t: 'rel', c: 'tail', v: -2 }, { t: 'tension', v: 1 }]), special: 'arrive_turn', witness: atStop && AR.witness > 0 },
    { id: 'take_some', label: `가족 ${some}무리만 태운다`, say: '자리 나는 만큼만 태운다. 가족은 나누지 마라.', effs: [...inj(hurtSome), { t: 'trust', v: -1 }, { t: 'rel', c: 'medtech', v: 1 }, { t: 'rel', c: 'tail', v: -1 }], special: 'arrive_take_some', extra: placeLines(g, 'tail', someGroups), log: `피난민 무리: ${someN}명을 태웠다.` },
    { id: 'take_all', label: '모두 태운다', say: '다 태워라. 자리는 만든다.', effs: [...inj(hurtIn.length), { t: 'trust', v: 1 }, { t: 'rel', c: 'medtech', v: 3 }, { t: 'rel', c: 'tail', v: -2 }, { t: 'rel', c: 'front', v: -2 }], special: 'arrive_take_all', extra: placeLines(g, 'tail', groups), witness: atStop, log: `피난민 무리: ${n}명을 모두 태웠다.` },
    { id: 'escort', label: '수색대를 붙여 데려온다', log: `피난민 무리: 수색대를 붙여 ${n}명을 데려오게 했다.`, say: '수색대를 붙여라. 다음 역에서 태운다.', effs: [{ t: 'food', v: -1 }, { t: 'trust', v: 2 }, { t: 'rel', c: 'medtech', v: 2 }, { t: 'rel', c: 'tail', v: -2 }], special: 'arrive_escort',
      extra: [`수색대 ${AR.escortSize}명 · 다음 정차까지 자리 비움`, riskLine(card)], ...(crew.length < AR.escortSize ? { disabled: '보낼 사람이 없다' } : {}) },
  ];
  return { title: '피난민 무리', speaker, focus: 'tail', required: true, key: 'arrival', body, choices: withAfford(g, choices) };
}

function familyView(g: Game, card: Card): CardView {
  const c = card.comm ?? 'tail';
  const size = card.n ?? AR.familyMin;
  const hurt = Number(card.vals?.hurt ?? 0);
  const ban = g.passed.no_outsiders !== undefined;
  const crew = names(card.vals?.crew);
  const past = memo(g, 'family');
  const who = card.who ?? '수색대원';
  const echo = past?.pick === 'stay_put' ? ' 지난번 가족을 두고 온 대원이 말없이 듣고 있다.' : past?.pick === 'fetch' ? ' 지난번 데려온 가족이 이 칸에 있다.' : '';
  const backers = ban ? lawBackers(g) : [];
  return {
    title: '대원의 가족', speaker: { name: who, role: '수색대원', comm: c }, focus: c, required: true, key: 'family',
    body: `${who}이(가) 둘러본 곳에서 자기 가족을 봤다고 한다. ${size}명이다.${hurt ? ' 한 명은 다쳤다.' : ''} 밤길로 셋이 가서 데려오면 다음 역에서 만날 수 있다.${ban ? ' 외부인 받지 않기 법이 있지만, 칸 사람들은 대원의 가족은 외부인이 아니라고 말한다.' : ''}${echo}`,
    choices: withAfford(g, [
      { id: 'fetch', label: '데리러 보낸다', log: `${who}의 가족을 데리러 셋을 보냈다.`, say: '셋을 붙여 보내라. 다음 역에서 기다린다.', effs: [{ t: 'food', v: -1 }, { t: 'trust', v: 1 }, { t: 'rel', c, v: 5 }, ...backers.map(b => ({ t: 'rel' as const, c: b, v: -3 }))], special: 'family_fetch',
        extra: [`수색대 ${AR.fetchSize}명 · 다음 정차까지 자리 비움`, riskLine(card)], ...(crew.length < AR.fetchSize ? { disabled: '보낼 사람이 없다' } : {}) },
      { id: 'stay_put', label: '지금은 못 간다', log: `${who}의 가족을 지금은 데리러 가지 않았다.`, say: '지금은 못 간다. 있는 곳을 적어 둬라.', effs: [{ t: 'rel', c, v: -6 }, { t: 'tension', v: 2 }], witness: AR.witness > 0 },
    ]),
  };
}

function quarrelView(g: Game, card: Card): CardView {
  const c = card.comm ?? 'tail';
  return {
    title: '잠자리 다툼', speaker: { name: g.comms[c].leader.name, role: REP_ROLE[c], comm: c }, focus: c, required: true,
    body: `"늦게 탄 사람들이 문간과 통로에서 잔다. 먼저 있던 사람들과 자리를 두고 말이 오갔다." ${COMM_NAME[c]} 과밀 ${Math.round(situation(g, c)[2])}.`,
    choices: withAfford(g, [
      { label: '잠자리를 다시 짠다', log: `${COMM_NAME[c]}의 잠자리를 다시 짰다.`, say: '자리를 다시 짜라. 먼저 탄 사람도 늦게 탄 사람도 같은 바닥이다.', effs: [{ t: 'coal', v: -1 }, { t: 'rel', c, v: 2 }, { t: 'tension', v: -1 }] },
      { label: '알아서 하라고 둔다', log: `${COMM_NAME[c]}의 잠자리 다툼은 그 칸에 맡겼다.`, say: '바닥은 바닥이다. 알아서 나눠 자라.', effs: [{ t: 'rel', c, v: -3 }, { t: 'tension', v: 1 }] },
    ]),
  };
}

function view(g: Game, card: Card): CardView | null {
  if (!g.arrivals) return null;
  if (card.kind === 'arrival') return arrivalView(g, card);
  if (card.kind === 'family') return familyView(g, card);
  if (card.kind === 'bed_quarrel') return quarrelView(g, card);
  return null;
}

function choose(g: Game, card: Card, choice: Choice): void {
  const a = g.arrivals;
  if (!a) return;
  const groups = nums(card.vals?.groups);
  const n = groups.reduce((x, y) => x + y, 0);
  switch (choice.special) {
    case 'arrive_turn':
      a.turned += n;
      break;
    case 'arrive_take_all':
    case 'arrive_take_some': {
      const some = choice.special === 'arrive_take_all' ? groups : groups.slice(0, someOf(groups));
      const plan = takeIn(g, 'tail', some);
      a.turned += n - some.reduce((x, y) => x + y, 0);
      journal(g, `${placeText(plan)}이(가) 늘었다.`);
      break;
    }
    case 'arrive_escort':
      sendFetch(g, 'arrival', (card.vals?.comm as Comm) ?? 'tail', names(card.vals?.crew).slice(0, AR.escortSize), Number(card.vals?.danger ?? 1), groups, nums(card.vals?.hurt).length);
      journal(g, `수색대 ${AR.escortSize}명이 무리를 데리러 나갔다.`);
      break;
    case 'family_fetch': {
      const size = card.n ?? AR.familyMin;
      sendFetch(g, 'family', card.comm ?? 'tail', names(card.vals?.crew).slice(0, AR.fetchSize), Number(card.vals?.danger ?? 1), [size], Number(card.vals?.hurt ?? 0));
      journal(g, `수색대 ${AR.fetchSize}명이 대원의 가족을 데리러 밤길을 나섰다.`);
      break;
    }
    default:
      if (card.kind === 'family' && choice.id === 'stay_put') a.turned += card.n ?? 0;
      break;
  }
}

CARD_EXTENSIONS.push({ view, choose });
