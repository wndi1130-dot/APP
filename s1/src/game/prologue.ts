import { COMM_NAME, REP_ROLE } from './data';
import { CARD_EXTENSIONS } from './cards';
import type { CardView, Choice } from './cards';
import { josa } from './josa';
import { addCard, clamp, isGone, journal, PROFILES, rnd, storyOf } from './state';
import type { Card, Game } from './state';
import { breakPromise, keepPromise, setLever } from './turn';

// 서막: 볼슈틴 차고(first_leg_story 5장 '서막 흐름', 2026-10-07 18:20 사용자 결정 '서막에 한 바퀴').
// 약속 → 저탄장 수색 → 출발 → 열차 안 첫 거래가 첫 10분에 한 바퀴 돈다. S1a엔 필드가 없어서 수색은 필드 결정 카드로 대신하고,
// 몇 명을 데려오나는 주사위로 정한다. 순서와 고리는 결정이고 숫자는 제안이다.
// 시작 석탄·식량(문서의 45·55)은 첫 구간 다섯 정차의 눈금이라 S1a(24구간, 100·100)엔 옮기지 않았다.

export const PROLOGUE = Object.freeze({
  /** 저탄장에 남은 꼬리칸 운반조 */
  crew: 5,
  /** 두고 떠나면 꼬리칸 관계(예전 카드 '떠난다'의 감소, 제안) */
  leftRel: -8,
  /** 첫 거래를 거절하면 꼬리칸 관계(제안) */
  dealRefuseRel: -5,
});

/** 수색 방식마다 데려오는 사람 수와 주운 석탄(주사위 범위, 양 끝 포함). 석탄 상한 8은 예전 '기다린다'의 +8.
 * 사람부터 부르면 다섯 다 온다: 약속을 지킬 길은 열차장이 고르는 것이고, 주사위는 석탄 욕심에만 건다.
 * (처음엔 3~5명으로 뒀다가 약속한 판의 2/3가 어긴 판이 되어 4000판 완주가 43%→16%로 무너졌다.) */
const SEARCH = {
  pro_people: { label: '운반조부터 부른다', say: '자루는 버려라. 사람부터 데려온다!', people: [5, 5], coal: [0, 2] },
  pro_coal: { label: '자루도 챙긴다', say: '부르면서 자루를 끌어라. 석탄 없이는 못 간다!', people: [2, 5], coal: [3, 8] },
  pro_leave: { label: '바로 돌아선다', say: '시간이 없다. 지금 떠난다.', people: [0, 0], coal: [0, 0] },
} as const;
type SearchId = keyof typeof SEARCH;

export const PROLOGUE_CARD_KINDS = ['pro_promise', 'pro_search', 'pro_deal'] as const;

/** 새 판을 서막으로 시작한다. 앱과 봇이 부른다(테스트의 createGame은 서막 없이 바로 출발 전 운영이다). */
export function startPrologue(g: Game): void {
  // createGame의 '떠났다' 줄은 출발할 때 다시 쓴다.
  g.journal = g.journal.filter(j => !j.text.startsWith('볼슈틴 차고를 떠났다'));
  journal(g, '볼슈틴 차고, 여섯 번째 겨울 첫날 새벽. 저탄장 석탄이 바닥을 보이고, 두 호수가 얼어붙었다.');
  journal(g, '경비대가 얼음 위로 걸어오는 망자를 봤다. 출발을 앞당긴다. 저탄장엔 꼬리칸 운반조 다섯이 아직 있다.', 'bad');
  addCard(g, { kind: 'pro_promise', comm: 'tail' });
}

function roll(g: Game, [lo, hi]: readonly [number, number]): number {
  return lo + Math.floor(rnd(g) * (hi - lo + 1));
}

function range([lo, hi]: readonly [number, number], unit: string): string {
  return lo === hi ? `${lo}${unit}` : `${lo}~${hi}${unit}`;
}

/** '대표이름이/가' */
function who(g: Game): string {
  const n = g.comms.tail.leader.name;
  return n + josa(n, '이/가');
}

function speaker(g: Game): { name: string; role: string; comm: 'tail' } {
  return { name: g.comms.tail.leader.name, role: REP_ROLE.tail, comm: 'tail' };
}

function prologueView(g: Game, card: Card): CardView | null {
  switch (card.kind) {
    case 'pro_promise':
      return {
        title: '저탄장에 남은 사람들', speaker: speaker(g), focus: 'tail', required: true,
        body: `${who(g)} 열차장 앞에 섰다. "저탄장에 우리 사람 다섯이 있다. 그들을 데려오면 첫 회기에서 당신 편에 서겠다." 출발 전까지다.`,
        choices: [
          { label: '약속한다', say: '다섯 다 데려온다. 한 사람도 두고 가지 않는다.', effs: [], special: 'pro_promise', extra: ['다 데려오면 약속을 지킨 것, 하나라도 남기면 어긴 것'] },
          { label: '약속하지 않는다', say: '약속은 못 한다. 할 수 있는 만큼만 한다.', effs: [], special: 'pro_refuse', extra: ['어기는 일은 없다. 첫 거래가 무거워진다'] },
        ],
      };
    case 'pro_search': {
      const promised = card.text === 'promised';
      return {
        title: '저탄장 수색', focus: 'tail', required: true,
        body: `열차장과 동료 둘이 저탄장으로 내려간다. 망자가 얼음 한가운데를 건너오고 있다. 첫 무리가 닿기까지 길지 않다.${promised ? ' 다섯을 데려오기로 약속했다.' : ''}`,
        choices: (Object.keys(SEARCH) as SearchId[]).map((id): Choice => ({
          label: SEARCH[id].label, say: SEARCH[id].say, effs: [], special: id,
          extra: id === 'pro_leave' ? ['다섯 모두 승강장에 남는다'] : [`데려올 사람 ${range(SEARCH[id].people, '명')}`, `석탄 +${range(SEARCH[id].coal, '')}`],
        })),
      };
    }
    case 'pro_deal': {
      const kept = storyOf(g).flags.depot_promise === 'kept';
      return {
        title: '열차 안 첫 거래', speaker: speaker(g), focus: 'tail', required: true,
        body: kept
          ? `열차가 호숫가를 벗어났다. ${who(g)} 말한다. "약속을 지켰다. 그러니 하나만 청한다. 꼬리칸 난로에 석탄을 한 삽 더."`
          : `열차가 호숫가를 벗어났다. ${who(g)} 말한다. "이제 값을 치러라. 꼬리칸 난로에 한 삽 더, 배급도 한 국자 더."`,
        choices: [
          { label: '들어준다', say: kept ? '한 삽 더 넣어라.' : '난로도 배급도 한 칸씩 올린다.', effs: [], special: 'pro_deal_yes', extra: [kept ? '꼬리칸 난방 레버 +1' : '꼬리칸 난방 레버 +1 · 배급 레버 +1'] },
          { label: '거절한다', say: '지금은 못 한다. 석탄이 모자란다.', effs: [{ t: 'rel', c: 'tail', v: PROLOGUE.dealRefuseRel }], special: 'pro_deal_no' },
        ],
      };
    }
    default:
      return null;
  }
}

/** 두고 떠난 사람의 이름: 꼬리칸의 일할 나이 중 대표를 뺀 사람들. */
function leftNames(g: Game, n: number): string[] {
  const pool = PROFILES.filter(p => p.community === 'tail' && p.age >= 16 && p.age <= 65 && p.name !== g.comms.tail.leader.name && !isGone(g, p.name));
  const out: string[] = [];
  while (out.length < n && pool.length > 0) out.push(pool.splice(Math.floor(rnd(g) * pool.length), 1)[0].name);
  return out;
}

function prologueChoose(g: Game, card: Card, choice: Choice): void {
  const flags = storyOf(g).flags;
  switch (choice.special) {
    case 'pro_promise':
    case 'pro_refuse': {
      const promised = choice.special === 'pro_promise';
      if (promised) journal(g, `${COMM_NAME.tail}과(와) 약속했다: 저탄장 운반조 다섯을 데려온다.`, 'deal');
      addCard(g, { kind: 'pro_search', comm: 'tail', text: promised ? 'promised' : 'refused' });
      return;
    }
    case 'pro_people':
    case 'pro_coal':
    case 'pro_leave': {
      const def = SEARCH[choice.special];
      const back = roll(g, def.people);
      const coal = roll(g, def.coal);
      const left = PROLOGUE.crew - back;
      g.coal += coal;
      journal(g, `저탄장에서 운반조 ${back}명을 데려오고 석탄 ${coal}을(를) 실었다.`);
      if (left > 0) {
        const names = leftNames(g, left);
        (g.left ??= []).push(...names);
        g.platform = { names, near: true }; // 망자가 얼음을 건너오는 중이라 늘 가깝다(제안)
        g.comms.tail.pop = Math.max(1, g.comms.tail.pop - left);
        g.comms.tail.rel = clamp(g.comms.tail.rel + PROLOGUE.leftRel, -100, 100);
        flags.depot_left_behind = true;
        journal(g, `${names.join(', ')}${josa(names[names.length - 1] ?? '', '이/가')} 승강장에 남았다. 꼬리칸 사람들이 창에 붙어 그들을 봤다.`, 'dark');
      } else {
        flags.depot_left_behind = false;
      }
      const promised = card.text === 'promised';
      if (!promised) flags.depot_promise = 'refused';
      else if (left === 0) { flags.depot_promise = 'kept'; keepPromise(g, 'tail', '저탄장 운반조를 다 데려온다'); }
      else { flags.depot_promise = 'broken'; breakPromise(g, 'tail', '저탄장 운반조를 다 데려온다'); }
      journal(g, '볼슈틴 차고를 떠났다. 쟁기가 선로 위 망자를 밀어낸다. 라이프치히 중앙역까지 24구간.');
      return;
    }
    case 'pro_deal_yes': {
      const kept = flags.depot_promise === 'kept';
      setLever(g, 'tail', 'heat', g.comms.tail.heat + 1);
      if (!kept) setLever(g, 'tail', 'ration', g.comms.tail.ration + 1);
      journal(g, kept ? '꼬리칸 난방을 한 칸 올렸다.' : '꼬리칸 난방과 배급을 한 칸씩 올렸다.', 'deal');
      journal(g, '길잡이가 다시 말한다. 라이프치히 중앙역에 열차들이 모이고, 그 남쪽 땅엔 석탄이 묻혀 있다고.');
      return;
    }
    case 'pro_deal_no':
      journal(g, '꼬리칸의 첫 청을 거절했다.', 'bad');
      journal(g, '길잡이가 다시 말한다. 라이프치히 중앙역에 열차들이 모이고, 그 남쪽 땅엔 석탄이 묻혀 있다고.');
      return;
    default:
      return;
  }
}

CARD_EXTENSIONS.push({ view: prologueView, choose: prologueChoose });

/** 출발 레버가 걸렸을 때 한 번 더 물을 승강장의 이름들(5b.5). 출발 전에만, 없으면 null */
export function platformNote(g: Game): { names: string[]; near: boolean } | null {
  return g.phase === 'prep' && g.platform && g.platform.names.length > 0 ? g.platform : null;
}
