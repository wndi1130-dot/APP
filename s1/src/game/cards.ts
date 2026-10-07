import { COMMS, COMM_NAME, P, REP_ROLE } from './data';
import type { Comm } from './data';
import { onDeath } from './death';
import { offend } from './politics';
import { clamp, journal, pick, rnd, situation } from './state';
import type { Card, EventMemo, Game } from './state';

// 결정 카드. 수저린식: 말하는 사람, 짧은 본문, 번호 붙은 선택지. 선택지는 지금 확실한 비용과
// 고르는 즉시 생기는 정치 변화만 보여 준다(decisions.md 화면과 연출). 문장은 자리표시다.

export type Eff =
  | { t: 'coal' | 'food' | 'med' | 'lux' | 'trust' | 'tension' | 'fear' | 'injured'; v: number }
  | { t: 'rel' | 'fervor' | 'pop'; c: Comm; v: number }
  | { t: 'base'; c: Comm; i: 0 | 1 | 2 | 3; v: number }
  | { t: 'lever'; c: Comm; which: 'heat' | 'ration'; v: number }
  | { t: 'debt'; c: Comm }
  | { t: 'grudge'; c: Comm };

export interface Choice {
  /** 무엇을 하는지 짧게. 일지에 남는다 */
  label: string;
  /** 카드에 보이는 열차장의 말(프로스트펑크식 선택지, 2026-10-07 사용자). 없으면 label을 보인다 */
  say?: string;
  effs: Eff[];
  /** 효과 말고 따로 처리하는 일 */
  special?: string;
  disabled?: string;
  /** 목격자가 있는 선택 */
  witness?: boolean;
  log?: string;
  /** 효과(Eff) 밖의 비용 줄(S1c 부품·자재 등). 비용 줄 끝에 붙는다 */
  extra?: string[];
}

export interface CardView {
  title: string;
  speaker?: { name: string; role: string; comm?: Comm };
  body: string;
  choices: Choice[];
  /** 꼭 골라야 다음 단계로 간다 */
  required: boolean;
  /** 관련 칸(열차를 그 칸으로 스크롤한다) */
  focus?: Comm;
  /** 사건 기억 키. 고르면 g.eventLog에 남는다 */
  key?: string;
}

const RES_NAME: Record<string, string> = {
  coal: '석탄', food: '식량', med: '의약품', lux: '사치품', trust: '신임', tension: '긴장', fear: '공포', injured: '부상자',
};
const BASE_NAME = ['온기', '배급', '과밀', '노출'];

function sign(v: number): string {
  return v > 0 ? `+${v}` : `−${Math.abs(v)}`;
}

/** 선택지에 붙는 비용 줄(자원, 처지). */
export function costLines(choice: Choice): string[] {
  const out: string[] = [];
  for (const e of choice.effs) {
    if (e.t === 'coal' || e.t === 'food' || e.t === 'med' || e.t === 'lux' || e.t === 'injured') out.push(`${RES_NAME[e.t]} ${sign(e.v)}`);
    else if (e.t === 'base') out.push(`${COMM_NAME[e.c]} ${BASE_NAME[e.i]} ${sign(e.v)}`);
    else if (e.t === 'lever') out.push(`${COMM_NAME[e.c]} ${e.which === 'heat' ? '난방' : '배급'} ${sign(e.v)}`);
    else if (e.t === 'pop') out.push(`${COMM_NAME[e.c]} ${sign(e.v)}명`);
  }
  if (choice.extra) out.push(...choice.extra);
  return out;
}

/** 선택지에 붙는 정치 줄. 불만·지지와 신임·긴장만, 크기는 낱말로. */
export function politicsLines(choice: Choice): { text: string; tone: 'red' | 'blue' | 'gray' }[] {
  const out: { text: string; tone: 'red' | 'blue' | 'gray' }[] = [];
  for (const e of choice.effs) {
    if (e.t === 'rel') {
      const size = Math.abs(e.v) >= 8 ? '크게' : '약간';
      out.push(e.v > 0 ? { text: `${COMM_NAME[e.c]} 지지 ${size} ↑`, tone: 'blue' } : { text: `${COMM_NAME[e.c]} 불만 ${size} ↑`, tone: 'red' });
    } else if (e.t === 'trust') {
      out.push({ text: `신임 ${sign(e.v)}`, tone: e.v > 0 ? 'blue' : 'red' });
    } else if (e.t === 'tension') {
      out.push({ text: `긴장 ${sign(e.v)}`, tone: e.v > 0 ? 'red' : 'blue' });
    } else if (e.t === 'fear') {
      out.push({ text: '공포가 돈다', tone: 'gray' });
    } else if (e.t === 'fervor' && e.v > 0) {
      out.push({ text: `${COMM_NAME[e.c]} 열기 ↑`, tone: 'red' });
    } else if (e.t === 'debt') {
      out.push({ text: `${COMM_NAME[e.c]} 대표에게 빚 받음`, tone: 'blue' });
    }
  }
  return out;
}

function leader(g: Game, c: Comm): { name: string; role: string; comm: Comm } {
  return { name: g.comms[c].leader.name, role: REP_ROLE[c], comm: c };
}

function affordable(g: Game, effs: Eff[]): string | undefined {
  for (const e of effs) {
    if (e.t === 'coal' && e.v < 0 && g.coal < -e.v) return '석탄이 모자라다';
    if (e.t === 'food' && e.v < 0 && g.food < -e.v) return '식량이 모자라다';
    if (e.t === 'med' && e.v < 0 && g.med < -e.v) return '의약품이 모자라다';
    if (e.t === 'lux' && e.v < 0 && g.lux < -e.v) return '사치품이 모자라다';
    if (e.t === 'lever' && e.v > 0 && (e.which === 'heat' ? g.comms[e.c].heat : g.comms[e.c].ration) >= 4) return '이미 최대다';
  }
  return undefined;
}

function withAfford(g: Game, choices: Choice[]): Choice[] {
  return choices.map(ch => (ch.disabled ? ch : { ...ch, disabled: affordable(g, ch.effs) }));
}

// ---- 이동 사건(브리프 9장의 묶음에서 고른 것) ----
// 같은 사건이 다시 나올 수 있지만, 지난번 고른 것과 지금 처지에 따라 본문과 대가가 달라진다(2026-10-07 사용자 후기:
// 프로스트펑크처럼 발생은 하되 세부가 달라져야 한다). 한 사건은 다섯 구간 안에 다시 나오지 않는다.
interface TravelEvent { id: string; when: (g: Game) => boolean; view: (g: Game, past: EventMemo | undefined) => CardView }

/** 지난번 그 사건에서 무엇을 골랐는지에 따라 본문을 고른다. 처음이면 first. */
function again(past: EventMemo | undefined, first: string, byPick: Record<string, string>, fallback: string): string {
  if (!past) return first;
  return byPick[past.pick] ?? fallback;
}

/** 다시 나올수록 거절·방치 쪽 대가가 커진다. */
function worse(past: EventMemo | undefined, base: number, step: number): number {
  return base + step * Math.min(past?.n ?? 0, 3);
}

function kids(g: Game, c: Comm): number {
  return Math.max(2, Math.round(g.comms[c].pop * 0.18));
}

export const TRAVEL_EVENTS: TravelEvent[] = [
  {
    id: 'tail_cold', when: g => situation(g, 'tail')[0] <= 38,
    view: (g, past) => ({
      title: past ? '또 꺼진 난로' : '꺼진 난로', speaker: leader(g, 'tail'), focus: 'tail', required: true,
      body: again(past, `꼬리칸 난로가 이틀째 꺼져 있다. 아이 ${kids(g, 'tail')}명의 손끝이 하얗다. 앞칸엔 난로가 두 개다.`, {
        '앞칸 연료를 덜어 온다': '꼬리칸 난로가 또 꺼졌다. 지난번 덜어 온 연료는 사흘을 못 갔다. 앞칸은 이제 연료 상자에 자물쇠를 걸었다.',
        '담요를 나눈다': '꼬리칸 난로가 또 꺼졌다. 나눠 준 담요는 젖은 채 얼었다. 밤마다 기침 소리가 칸을 넘어온다.',
        '참으라 한다': '꼬리칸 난로가 또 꺼졌다. 아이들이 "참아라" 하는 열차장 말투를 흉내 내며 논다. 어른들은 웃지 않는다.',
      }, '꼬리칸 난로가 또 꺼졌다. 이번엔 노인 하나가 아침에 일어나지 않았다.'),
      choices: [
        {
          label: '앞칸 연료를 덜어 온다',
          say: past?.pick === '앞칸 연료를 덜어 온다' ? '자물쇠를 따라. 연료는 열차 전체의 것이다!' : '난로 두 개는 사치다. 하나를 꼬리칸으로 옮겨라!',
          effs: [{ t: 'base', c: 'tail', i: 0, v: 5 }, { t: 'base', c: 'front', i: 0, v: -5 }, { t: 'rel', c: 'tail', v: 5 }, { t: 'rel', c: 'front', v: -worse(past, 8, 3) }],
        },
        { label: '담요를 나눈다', say: past ? '창고 담요를 전부 풀어라. 젖은 건 보일러 옆에서 말려라.' : '창고 담요를 풀어라. 아이들부터 덮어 줘라.', effs: [{ t: 'lux', v: -worse(past, 1, 1) }, { t: 'rel', c: 'tail', v: 4 }] },
        { label: '참으라 한다', say: past ? '아직 아무도 얼어 죽지 않았다. 버텨라.' : '모두가 춥다. 꼬리칸만 추운 게 아니다.', effs: [{ t: 'rel', c: 'tail', v: -worse(past, 5, 3) }, { t: 'tension', v: worse(past, 2, 2) }] },
      ],
    }),
  },
  {
    id: 'crowd_fight', when: g => situation(g, 'tail')[2] >= 78,
    view: (g, past) => ({
      title: past ? '또 자리 싸움' : '자리 싸움', speaker: leader(g, 'guard'), focus: 'tail', required: true,
      body: again(past, '꼬리칸에서 누울 자리를 두고 주먹이 오갔다. 한 사람이 머리를 다쳤다.', {
        '경비대가 말린다': '또 주먹이 오갔다. 지난번 끌려갔던 사내가 이번엔 먼저 휘둘렀다. 경비대를 보는 눈이 곱지 않다.',
        '칸을 넓혀 준다': '넓혀 준 자리에도 사람이 다시 찼다. 이번엔 깨진 병이 나왔다.',
        '내버려 둔다': '또 싸움이 났다. 지난번 다친 사람은 아직 못 일어난다. 이번엔 편이 갈렸다.',
      }, '자리 싸움이 또 났다. 누가 먼저였는지 아무도 말하지 않는다.'),
      choices: [
        { label: '경비대가 말린다', say: '경비대, 떼어 놓아라! 또 주먹을 쓰면 묶어 둬라.', effs: [{ t: 'rel', c: 'tail', v: -worse(past, 3, 2) }, { t: 'tension', v: -3 }, { t: 'fear', v: 2 }] },
        { label: '칸을 넓혀 준다', say: '앞칸 짐을 치워라. 꼬리칸에도 누울 자리는 있어야 한다.', effs: [{ t: 'base', c: 'tail', i: 2, v: -5 }, { t: 'base', c: 'front', i: 2, v: 5 }, { t: 'rel', c: 'front', v: -5 }, { t: 'rel', c: 'tail', v: 3 }] },
        { label: '내버려 둔다', say: past ? '저들끼리 끝내게 둬라. 열차장은 심판이 아니다.' : '자리는 저들끼리 정하게 둬라.', effs: [{ t: 'injured', v: past ? 2 : 1 }, { t: 'tension', v: worse(past, 4, 2) }] },
      ],
    }),
  },
  {
    id: 'front_curtain', when: g => (g.eventLog?.front_curtain?.n ?? 0) < 3,
    view: (g, past) => ({
      title: past ? '다시 걸린 커튼' : '앞칸의 커튼', speaker: leader(g, 'tail'), focus: 'front', required: true,
      body: again(past, '앞칸 창에 커튼이 걸렸다. 식사 시간마다 닫힌다. 꼬리칸이 그 앞에 줄을 섰다.', {
        '커튼을 걷게 한다': '커튼은 걷혔다. 대신 앞칸이 식사를 밤으로 옮겼다. 꼬리칸이 자는 사이에 먹는다.',
        '앞칸 편을 든다': '커튼 앞 줄이 길어졌다. 누군가 커튼에 숯으로 "배부른 칸"이라고 썼다.',
        '대표 둘을 부른다': '두 대표가 한 식탁에 앉았던 일은 사흘을 못 갔다. 커튼이 다시 걸렸다.',
      }, '커튼이 또 걸렸다.'),
      choices: [
        { label: '커튼을 걷게 한다', say: past?.pick === '커튼을 걷게 한다' ? '밤에 먹든 낮에 먹든 같은 열차다. 문을 열어 둬라.' : '커튼을 걷어라. 이 열차에 숨어서 먹는 칸은 없다.', effs: [{ t: 'rel', c: 'front', v: -worse(past, 6, 2) }, { t: 'rel', c: 'tail', v: 4 }] },
        { label: '앞칸 편을 든다', say: past?.pick === '앞칸 편을 든다' ? '낙서한 자를 찾아라. 앞칸 식탁은 앞칸 일이다.' : '앞칸 식탁은 앞칸 일이다. 줄을 풀어라.', effs: [{ t: 'rel', c: 'tail', v: -worse(past, 4, 3) }, { t: 'rel', c: 'front', v: 4 }] },
        { label: '대표 둘을 부른다', say: past ? '두 대표를 다시 불러라. 이번엔 내 식탁이다.' : '두 대표를 불러라. 한 식탁에 앉혀 보겠다.', effs: [{ t: 'lux', v: -worse(past, 1, 1) }, { t: 'tension', v: -2 }, { t: 'trust', v: 1 }] },
      ],
    }),
  },
  {
    id: 'water_tower', when: g => g.seg >= 2,
    view: (g, past) => ({
      title: '얼어붙은 급수탑', speaker: leader(g, 'engine'), focus: 'engine', required: true,
      body: again(past, `급수탑 관이 얼었다. 보일러 물이 반밖에 없다. 석탄은 ${g.coal} 남았다.`, {
        '불을 피워 녹인다': `급수탑이 또 얼었다. 지난번 녹이느라 태운 석탄 얘기를 화부들이 아직 한다. 석탄은 ${g.coal} 남았다.`,
        '꼬리칸이 눈을 녹인다': '급수탑이 또 얼었다. 꼬리칸은 지난번 양동이 일로 손이 다 텄다. 이번에도 꼬리칸이냐고 묻는다.',
        '다음 역까지 버틴다': '보일러 물이 바닥 근처다. 지난번처럼 버티면 관이 탈 수 있다고 기관사가 말한다.',
      }, '급수탑이 또 얼었다.'),
      choices: [
        { label: '불을 피워 녹인다', say: '석탄을 태워서라도 관을 녹여라!', effs: [{ t: 'coal', v: -3 }] },
        { label: '꼬리칸이 눈을 녹인다', say: past?.pick === '꼬리칸이 눈을 녹인다' ? '꼬리칸이 한 번 더 한다. 장갑은 앞칸에서 걷어 줘라.' : '꼬리칸은 양동이를 들어라. 눈을 퍼다 녹인다.', effs: [{ t: 'base', c: 'tail', i: 3, v: 5 }, { t: 'rel', c: 'tail', v: -worse(past, 4, 3) }] },
        { label: '다음 역까지 버틴다', say: past?.pick === '다음 역까지 버틴다' ? '관은 안 탄다. 내가 보증한다. 간다!' : '물을 아껴라. 다음 급수탑까지 간다.', effs: [{ t: 'coal', v: -2 }, { t: 'rel', c: 'engine', v: -worse(past, 4, 2) }, ...(past?.pick === '다음 역까지 버틴다' ? [{ t: 'base' as const, c: 'engine' as const, i: 3 as const, v: 6 }] : [])] },
      ],
    }),
  },
  {
    id: 'snow_drift', when: g => g.seg >= 3,
    view: (g, past) => ({
      title: '눈더미', speaker: leader(g, 'engine'), focus: 'engine', required: true,
      body: again(past, '선로가 눈더미에 묻혔다. 삽이 열두 자루 있다.', {
        '모든 칸이 나눠 판다': '또 눈더미다. 지난번 함께 판 일을 사람들이 아직 말한다. 앞칸 몇은 벌써 삽을 들었다.',
        '꼬리칸이 판다': '또 눈더미다. 꼬리칸 사람들이 삽을 내려놓고 앉아 있다. "이번엔 앞칸 차례다."',
        '기관차로 밀어붙인다': '또 눈더미다. 지난번 밀어붙인 뒤로 앞바퀴에서 쇳소리가 난다.',
      }, '선로가 또 눈에 묻혔다.'),
      choices: [
        { label: '모든 칸이 나눠 판다', say: '모든 칸이 삽을 든다. 앞칸도 예외는 없다!', effs: [{ t: 'food', v: -3 }, { t: 'rel', c: 'front', v: past?.pick === '모든 칸이 나눠 판다' ? -1 : -3 }, { t: 'tension', v: -1 }] },
        { label: '꼬리칸이 판다', say: past?.pick === '꼬리칸이 판다' ? '앉아 있으면 열차도 선다. 꼬리칸, 일어나라.' : '꼬리칸, 삽을 들어라. 손이 제일 많은 칸이다.', effs: [{ t: 'rel', c: 'tail', v: -worse(past, 5, 3) }, ...(past?.pick === '꼬리칸이 판다' ? [{ t: 'tension' as const, v: 3 }] : [])] },
        { label: '기관차로 밀어붙인다', say: '화부들, 불을 올려라. 밀고 나간다!', effs: [{ t: 'coal', v: -worse(past, 4, 1) }, { t: 'base', c: 'engine', i: 3, v: worse(past, 4, 2) }] },
      ],
    }),
  },
  {
    id: 'abandoned_tender', when: g => g.seg >= 2 && g.coal < 80,
    view: (_g, past) => ({
      title: '측선의 탄수차', focus: 'engine', required: true,
      body: past ? '측선에 또 버려진 탄수차가 있다. 이번엔 문짝마다 손톱자국이 나 있다.' : '측선에 버려진 탄수차가 서 있다. 안에 석탄이 보인다. 주위가 너무 조용하다.',
      choices: [
        { label: '석탄을 옮긴다', say: past ? '자국은 오래된 거다. 빨리 옮기고 빠진다!' : '조용하면 좋은 거다. 다 옮겨라, 서둘러!', effs: [{ t: 'coal', v: 8 }], special: 'risk_injury' },
        { label: '지나친다', say: '너무 조용하다. 손대지 말고 지나간다.', effs: [] },
      ],
    }),
  },
  {
    id: 'sick_child', when: g => g.med >= 2,
    view: (g, past) => ({
      title: past ? '열병이 번진다' : '아이 열병', speaker: leader(g, 'medtech'), focus: 'medtech', required: true,
      body: again(past, '꼬리칸 아이 셋이 열이 난다. 해열제는 의무칸 상자에 있다.', {
        '의약품을 쓴다': `이번엔 아이 다섯이 열이 난다. 지난번 약을 받은 집 얘기가 칸에 다 퍼졌다. 의약품은 ${g.med} 남았다.`,
        '아껴 둔다': '지난번 약을 못 받은 아이가 아직 열이 안 내렸다. 엄마가 의무칸 문 앞을 떠나지 않는다.',
      }, '아이들이 또 열이 난다.'),
      choices: [
        { label: '의약품을 쓴다', say: '의약품은 약자의 것이다. 아이들에게 먼저 써라!', effs: [{ t: 'med', v: past?.pick === '의약품을 쓴다' ? -3 : -2 }, { t: 'rel', c: 'tail', v: 4 }, { t: 'rel', c: 'medtech', v: 2 }] },
        { label: '아껴 둔다', say: past?.pick === '아껴 둔다' ? '약은 살 사람에게 쓴다. 그 엄마를 문 앞에서 데려가라.' : '애들 열은 금방 내린다. 엄살 부리지 말라고 전해라!', effs: [{ t: 'rel', c: 'tail', v: -worse(past, 4, 3) }, { t: 'rel', c: 'medtech', v: -2 }, ...(past?.pick === '아껴 둔다' ? [{ t: 'trust' as const, v: -2 }] : [])] },
      ],
    }),
  },
  {
    id: 'ration_line', when: g => situation(g, 'tail')[1] < 45,
    view: (g, past) => ({
      title: '배급 줄', speaker: leader(g, 'tail'), focus: 'tail', required: true,
      body: again(past, '배급 줄 끝에서 빵이 떨어졌다. 뒤에 선 사람들이 소리친다.', {
        '다시 나눈다': `배급 줄 끝에서 또 빵이 떨어졌다. 사람들이 "지난번처럼!"을 외친다. 식량은 ${g.food} 남았다.`,
        '경비대를 세운다': '경비대가 섰던 날 이후로 배급 줄이 조용하다. 너무 조용하다. 오늘도 빵이 모자란다.',
      }, '배급 줄 끝에서 또 빵이 떨어졌다.'),
      choices: [
        { label: '다시 나눈다', say: '솥을 다시 열어라. 줄 끝까지 한 그릇씩 간다.', effs: [{ t: 'food', v: -worse(past, 4, 1) }, { t: 'rel', c: 'tail', v: 3 }] },
        { label: '경비대를 세운다', say: past?.pick === '경비대를 세운다' ? '조용하면 됐다. 경비대는 그대로 선다.' : '경비대를 줄 옆에 세워라. 질서가 먼저다.', effs: [{ t: 'fear', v: 3 }, { t: 'rel', c: 'tail', v: -3 }, { t: 'rel', c: 'guard', v: 2 }, ...(past ? [{ t: 'tension' as const, v: worse(past, 0, 2) }] : [])] },
      ],
    }),
  },
  {
    id: 'guard_frost', when: g => situation(g, 'guard')[0] < 50,
    view: (g, past) => ({
      title: '동상', speaker: leader(g, 'guard'), focus: 'guard', required: true,
      body: again(past, '지붕 경계를 서던 대원 둘이 동상을 입었다. 교대를 줄여 달라고 한다.', {
        '그대로 선다': '지난번 지붕에 섰던 대원 하나가 발가락 둘을 잃었다. 경비대가 지붕 교대를 거부하겠다고 한다.',
        '경계를 줄인다': '경계를 줄인 밤, 지붕 위로 무언가 지나갔다는 말이 돈다. 대원들이 다시 동상을 입었다.',
        '경비대 난방을 올린다': '경비칸이 따뜻해지자 다른 칸이 수군댄다. 그런데 지붕 위는 여전히 영하 서른이다.',
      }, '지붕 경계 대원들이 또 동상을 입었다.'),
      choices: [
        { label: '경비대 난방을 올린다', say: '경비칸 난로에 석탄을 더 넣어라. 지키는 사람이 얼면 끝이다.', effs: [{ t: 'lever', c: 'guard', which: 'heat', v: 1 }, { t: 'rel', c: 'guard', v: 3 }] },
        { label: '경계를 줄인다', say: '지붕 교대를 줄여라. 밤에는 창문으로 본다.', effs: [{ t: 'rel', c: 'guard', v: 2 }, { t: 'tension', v: worse(past, 2, 1) }] },
        { label: '그대로 선다', say: past?.pick === '그대로 선다' ? '거부는 없다. 지붕이 비면 다 같이 죽는다.' : '경계는 줄이지 않는다. 장갑을 두 겹 껴라.', effs: [{ t: 'rel', c: 'guard', v: -worse(past, 5, 4) }, { t: 'injured', v: 1 }] },
      ],
    }),
  },
];

/** 다섯 구간 안에 나왔던 사건은 다시 고르지 않는다. */
export const EVENT_COOLDOWN = 5;

export function drawTravelEvent(g: Game): string | null {
  const log = g.eventLog ?? {};
  const pool = TRAVEL_EVENTS.filter(e => e.when(g) && !g.recentEvents.includes(e.id) && !(log[e.id] && g.seg - log[e.id].seg < EVENT_COOLDOWN));
  if (pool.length === 0) return null;
  const id = pick(g, pool).id;
  g.recentEvents = [...g.recentEvents, id].slice(-4);
  return id;
}

export function memo(g: Game, key: string): EventMemo | undefined {
  return g.eventLog?.[key];
}

function remember(g: Game, key: string, pick: string): void {
  g.eventLog ??= {};
  const prev = g.eventLog[key];
  g.eventLog[key] = { n: (prev?.n ?? 0) + 1, seg: g.seg, pick };
}

// ---- 다른 묶음의 카드(S1c 내정, domestic/cards.ts가 등록한다) ----
export interface CardExtension {
  /** 이 묶음의 카드면 보기를 돌려주고, 아니면 null */
  view: (g: Game, card: Card) => CardView | null;
  /** 고른 뒤 special을 처리한다(효과 적용 뒤, 기억·일지 앞) */
  choose?: (g: Game, card: Card, choice: Choice) => void;
}
export const CARD_EXTENSIONS: CardExtension[] = [];

// ---- 카드 보기 ----
export function viewCard(g: Game, card: Card): CardView {
  for (const ext of CARD_EXTENSIONS) {
    const v = ext.view(g, card);
    if (v) return v;
  }
  const c = card.comm ?? 'tail';
  switch (card.kind) {
    case 'travel': {
      const def = TRAVEL_EVENTS.find(e => e.id === card.text);
      if (!def) break;
      const v = def.view(g, memo(g, def.id));
      return { ...v, key: def.id, choices: withAfford(g, v.choices) };
    }
    case 'demand': {
      const [w, r, , ex] = situation(g, c);
      if (c === 'engine' && ex > 50) {
        const past = memo(g, 'demand:engine_shift');
        return {
          title: past ? '화부 교대, 다시' : '화부 교대', speaker: leader(g, 'engine'), focus: 'engine', required: true, key: 'demand:engine_shift',
          body: again(past, `화부들이 교대 없이 삽질을 한 지 오래다. 위험 노출 ${Math.round(ex)}. 교대를 늘려 달라고 한다.`, {
            '거절한다': `화부들이 다시 왔다. 이번엔 수석 기관사도 함께다. 위험 노출 ${Math.round(ex)}.`,
            '견습생을 붙인다': `붙여 준 견습생 하나가 화상을 입었다. 화부들이 교대를 다시 요구한다. 위험 노출 ${Math.round(ex)}.`,
            '교대를 늘린다': `늘린 교대로도 모자란다. 석탄이 줄수록 삽질은 늘었다. 위험 노출 ${Math.round(ex)}.`,
          }, `화부들이 또 교대를 요구한다. 위험 노출 ${Math.round(ex)}.`),
          choices: withAfford(g, [
            { label: '교대를 늘린다', say: '교대를 늘려라. 석탄보다 화부가 먼저 쓰러지면 끝이다.', effs: [{ t: 'coal', v: -P.shiftCoal }, { t: 'base', c: 'engine', i: 3, v: -P.shiftRelief }, { t: 'rel', c: 'engine', v: 3 }] },
            { label: '견습생을 붙인다', say: past?.pick === '견습생을 붙인다' ? '견습생을 더 붙여라. 화상은 배우는 값이다.' : '꼬리칸에서 젊은 손을 데려가라. 삽질은 배우면 된다.', effs: [{ t: 'base', c: 'engine', i: 3, v: -5 }, { t: 'base', c: 'tail', i: 3, v: 3 }, { t: 'rel', c: 'tail', v: -worse(past, 2, 2) }] },
            { label: '거절한다', say: past?.pick === '거절한다' ? '수석 기관사가 와도 답은 같다. 불 앞으로 돌아가라.' : '보일러는 쉬지 않는다. 화부도 마찬가지다.', effs: [{ t: 'fervor', c: 'engine', v: 1 }, { t: 'rel', c: 'engine', v: -worse(past, P.refuseRel, 3) }] },
          ]),
        };
      }
      const s = g.comms[c];
      const which = s.heat >= 4 ? 'ration' : s.ration >= 4 ? 'heat' : w < r ? 'heat' : 'ration';
      const past = memo(g, `demand:${c}`);
      const firstBody = which === 'heat'
        ? `${COMM_NAME[c]} 온기 ${Math.round(w)}. 밤마다 사람들이 서로 붙어 잔다. 난방을 올려 달라고 한다.`
        : `${COMM_NAME[c]} 배급 ${Math.round(r)}. 그릇이 반만 찬다. 배급을 올려 달라고 한다.`;
      const refusedBody = which === 'heat'
        ? `${COMM_NAME[c]} 대표가 또 왔다. 이번엔 뒤에 칸 사람 몇이 서 있다. 온기 ${Math.round(w)}.`
        : `${COMM_NAME[c]} 대표가 빈 그릇을 들고 왔다. 지난번 거절한 날부터 그릇을 씻지 않았다고 한다. 배급 ${Math.round(r)}.`;
      return {
        title: which === 'heat' ? '난방 요구' : '배급 요구', speaker: leader(g, c), focus: c, required: true, key: `demand:${c}`,
        // 같은 요구라도 관계에 따라 말투가 다르다(정치 디테일 2.1).
        body: `${past?.pick === '거절한다' ? refusedBody : firstBody} ${s.rel >= 15 ? '말투는 부탁에 가깝다.' : s.rel <= -15 ? '답은 다음 회기 전까지 달라고 못 박는다.' : ''}`.trim(),
        choices: withAfford(g, [
          { label: which === 'heat' ? '난방을 올린다' : '배급을 올린다',
            say: which === 'heat' ? `${COMM_NAME[c]} 난로를 올려라. 밤에 얼어 죽는 사람은 없어야 한다.` : `${COMM_NAME[c]} 그릇을 채워라. 빈 그릇으로는 일 못 한다.`,
            effs: [{ t: 'lever', c, which, v: 1 }, { t: 'rel', c, v: 2 }] },
          { label: '거절한다',
            say: past?.pick === '거절한다' ? '사람을 몰고 와도 석탄은 늘지 않는다.' : which === 'heat' ? '다들 붙어 자기는 마찬가지다. 지금은 안 된다.' : '모두 반 그릇이다. 더 나올 데가 없다.',
            effs: [{ t: 'fervor', c, v: 1 }, { t: 'rel', c, v: -worse(past?.pick === '거절한다' ? past : undefined, P.refuseRel, 3) }] },
        ]),
      };
    }
    case 'favor': {
      const past = memo(g, `favor:${c}`);
      const fav = past ? FAVORS_AGAIN[c] : FAVORS[c];
      return {
        title: '사적인 부탁', speaker: leader(g, c), focus: c, required: true, body: fav.body, key: `favor:${c}`,
        choices: withAfford(g, [
          { label: '들어준다', say: past ? '이번까지다. 다음은 없다.' : '들어주지. 대신 이 일은 기억해 둬라.', effs: [...fav.cost, { t: 'debt', c }], special: 'favor_risk' },
          { label: '거절한다', say: past ? '한 번 들어줬다고 버릇이 되면 안 된다.' : '사사로운 부탁은 받지 않는다.', effs: [{ t: 'rel', c, v: past ? -4 : -3 }] },
        ]),
      };
    }
    case 'strike_warn': {
      const [, , , ex] = situation(g, 'engine');
      return {
        title: '파업 경고', speaker: leader(g, 'engine'), focus: 'engine', required: true,
        body: `"다음 역까지 답이 없으면 불을 끄겠다." 기관실 위험 노출 ${Math.round(ex)}, 배급 ${Math.round(situation(g, 'engine')[1])}.`,
        choices: withAfford(g, [
          { label: '교대를 늘린다', say: '교대를 늘리겠다. 그러니 불은 끄지 마라.', effs: [{ t: 'coal', v: -P.shiftCoal }, { t: 'base', c: 'engine', i: 3, v: -P.shiftRelief }, { t: 'rel', c: 'engine', v: 6 }] },
          { label: '기관실 배급 +1', say: '기관실 그릇을 채워라. 불 지키는 사람이 굶으면 안 된다.', effs: [{ t: 'lever', c: 'engine', which: 'ration', v: 1 }, { t: 'rel', c: 'engine', v: 5 }, { t: 'rel', c: 'medtech', v: -2 }] },
          { label: '듣기만 한다', say: '불을 끄겠다고? 그럼 다 같이 얼어 죽는 거다.', effs: [{ t: 'rel', c: 'engine', v: -3 }] },
        ]),
      };
    }
    case 'strike': {
      return {
        title: '파업', speaker: leader(g, 'engine'), focus: 'engine', required: true,
        body: '보일러 불이 낮게 깔렸다. 열차가 선다. 기관실 문 앞에 화부들이 앉아 있다.',
        choices: withAfford(g, [
          { label: '요구를 들어준다', say: '요구를 받아들인다. 당장 불을 올려라!', effs: [{ t: 'lever', c: 'engine', which: 'ration', v: 1 }, { t: 'fervor', c: 'engine', v: -1 }, { t: 'fervor', c: 'medtech', v: 1 }, { t: 'rel', c: 'engine', v: 12 }] },
          { label: '교대를 늘린다', say: '교대를 늘린다. 그러니 문 앞에서 일어나라.', effs: [{ t: 'coal', v: -P.shiftCoal }, { t: 'base', c: 'engine', i: 3, v: -P.shiftRelief }, { t: 'fervor', c: 'engine', v: -1 }, { t: 'rel', c: 'engine', v: 8 }] },
          { label: '수석 기관사를 산다', say: '수석 기관사를 따로 불러라. 줄 게 있다.', effs: [{ t: 'lux', v: -3 }], special: 'strike_bribe' },
          { label: '버틴다', say: '협박에는 굽히지 않는다. 앉아 있고 싶으면 계속 앉아 있어라.', effs: [{ t: 'tension', v: 3 }] },
        ]),
      };
    }
    case 'rescue': {
      const ban = g.passed.no_outsiders !== undefined;
      const past = memo(g, 'rescue');
      const n = past?.n ?? 0;
      const who = [
        '역사 안에 다친 사람 둘이 있다. 데려가 달라고 한다.',
        '역사 구석에 노인과 소년이 있다. 소년은 노인을 업고 여기까지 왔다고 한다.',
        '플랫폼 끝에 여자 하나가 앉아 있다. 다리를 다쳤고, 아이를 안고 있다.',
        '대합실 의자 밑에서 남자 하나가 기어 나왔다. 기관사였다고 한다. 손이 떨린다.',
      ][n % 4];
      const echo = past?.pick === '두고 온다' || past?.pick === '법대로 두고 온다' ? ' 수색대가 이번엔 먼저 묻는다. 또 두고 가느냐고.'
        : past?.pick === '데려온다' ? ` 지난번 데려온 사람들로 꼬리칸 과밀이 ${Math.round(situation(g, 'tail')[2])}이다.` : ' 꼬리칸은 이미 꽉 찼다.';
      return {
        title: '부상자', speaker: { name: card.who ?? '수색대', role: '수색대' }, required: true, key: 'rescue',
        body: ban ? `${who} 외부인 받지 않기 법이 있다.` : `${who}${echo}`,
        choices: withAfford(g, ban ? [
          { label: '법대로 두고 온다', say: '법은 법이다. 두고 와라.', effs: [{ t: 'trust', v: -1 }], witness: true },
        ] : [
          { label: '데려온다', say: '자리는 만들면 된다. 데려와라!', effs: [{ t: 'pop', c: 'tail', v: 2 }, { t: 'base', c: 'tail', i: 2, v: 3 }, { t: 'injured', v: 1 }, { t: 'rel', c: 'medtech', v: 3 }], witness: true },
          { label: '물자만 받는다', say: '가진 식량만 받아라. 사람은 태울 수 없다.', effs: [{ t: 'food', v: 3 }, { t: 'trust', v: -1 }, { t: 'rel', c: 'medtech', v: -3 }], witness: true },
          { label: '두고 온다', say: past?.pick === '두고 온다' ? '그래, 또 두고 간다. 우리 먼저 살아야 한다.' : '꼬리칸은 꽉 찼다. 문을 닫아라.', effs: [{ t: 'trust', v: -worse(past?.pick === '두고 온다' ? past : undefined, 1, 1) }, { t: 'rel', c: 'medtech', v: -3 }], witness: true },
        ]),
      };
    }
    case 'bitten': {
      const past = memo(g, 'bitten');
      const [part, partObj] = ([['팔', '팔을'], ['다리', '다리를'], ['손', '손을']] as const)[card.uid % 3];
      const echo = past?.pick === '숨겨 준다' ? ' 지난번 일 때문에 다들 상처부터 본다.' : past?.pick === '두고 온다' ? ' 지난번 역에 두고 온 사람을 다들 기억한다.' : '';
      return {
        title: '물렸다', speaker: { name: card.who ?? '수색대원', role: COMM_NAME[c] }, focus: c, required: true, key: 'bitten',
        body: `${card.who ?? '대원'}이(가) ${partObj} 물렸다. 감염 창이 닫히기 전에 잘라야 한다.${echo}`,
        choices: withAfford(g, [
          { label: `${partObj} 자른다`, say: `지금 ${partObj} 잘라라! 망설이면 늦는다.`, effs: [{ t: 'med', v: -3 }, { t: 'injured', v: 1 }, { t: 'rel', c, v: 2 }], witness: true },
          { label: '숨겨 준다', say: past?.pick === '숨겨 준다' ? '지난번엔 운이 좋았다. 이번에도 감아서 태워라.' : `아무도 못 본 거다. ${part}에 붕대를 감고 태워라.`, effs: [], special: 'hide_bite', witness: true },
          { label: '두고 온다', say: '물린 사람은 못 태운다. 미안하다고 전해라.', effs: [{ t: 'rel', c, v: -8 }, { t: 'tension', v: 2 }], special: 'leave_bitten', witness: true },
        ]),
      };
    }
    case 'bite_found': {
      const bite = (g.hiddenBites ?? []).find(b => b.who === card.who);
      const canCut = !!bite && g.seg <= bite.at;
      return {
        title: '숨긴 물림이 드러났다', speaker: leader(g, 'medtech'), focus: c, required: true, key: 'bite_found',
        body: `${card.text ?? ''} ${card.who ?? '대원'}의 붕대 아래가 검게 부었다. 열차장이 숨겨 줬다는 말이 벌써 돈다.`.trim(),
        choices: withAfford(g, [
          { label: '의무칸에서 자른다', say: '아직 늦지 않았다. 의무칸으로 옮겨 잘라라!', effs: [{ t: 'med', v: -3 }, { t: 'injured', v: 1 }, { t: 'trust', v: -3 }], special: 'bite_cut',
            ...(canCut ? {} : { disabled: '감염 창이 닫혔다' }) },
          { label: '격리한다', say: '빈 칸 끝에 따로 둬라. 마지막은 가족과 보내게 해라.', effs: [{ t: 'trust', v: -5 }, { t: 'tension', v: 2 }], special: 'bite_isolate' },
          { label: '쏜다', say: '일어나기 전에 끝내라. 내가 숨긴 일이다, 내가 책임진다.', effs: [{ t: 'trust', v: -5 }, { t: 'fear', v: 3 }, { t: 'rel', c, v: -3 }], special: 'bite_shoot', witness: true },
        ]),
      };
    }
    case 'tension_crisis': {
      return {
        title: '마지막 기회', speaker: leader(g, 'tail'), focus: 'tail', required: true,
        body: '칸마다 사람들이 모였다. 문이 잠기기 시작했다. 오늘 밤을 넘기지 못할 수도 있다.',
        choices: withAfford(g, [
          { label: '경비대를 푼다', say: '경비대를 풀어라! 문을 잠그는 자는 끌어내라.', effs: [{ t: 'fear', v: 15 }, { t: 'trust', v: -10 }, { t: 'rel', c: 'tail', v: -10 }], special: 'tension_reset' },
          { label: '창고를 연다', say: '창고를 열어라! 오늘 밤은 모두 배불리 먹는다.', effs: [{ t: 'food', v: -15 }, { t: 'coal', v: -10 }, { t: 'rel', c: 'tail', v: 8 }], special: 'tension_reset' },
          { label: '아무것도 안 한다', say: '(열차장은 아무 말도 하지 않는다.)', effs: [], special: 'revolt' },
        ]),
      };
    }
    case 'trust_crisis': {
      return {
        title: '불신임', speaker: leader(g, 'guard'), required: true,
        body: `더는 열차장을 믿지 않는다는 말이 돈다. ${Math.max(0, (g.trustCrisis ?? g.seg) - g.seg)}구간 안에 신임을 25까지 되돌리지 못하면 끌려 내려온다.`,
        choices: [{ label: '알았다', effs: [] }],
      };
    }
    case 'leash': {
      return {
        title: '목줄이 끊겼다', speaker: leader(g, c), focus: c, required: true,
        body: `${g.comms[c].leader.name}이(가) 스스로 비밀을 털어놓고 열차장이 협박했다고 말했다.`,
        choices: [{ label: '알았다', effs: [] }],
      };
    }
    case 'info': {
      return { title: card.who ?? '알림', body: card.text ?? '', required: true, choices: [{ label: '알았다', effs: [] }] };
    }
    default:
      break;
  }
  return { title: '빈 서류', body: '', required: false, choices: [{ label: '덮는다', effs: [] }] };
}

// 두 번째부터는 다른 부탁이 온다.
const FAVORS_AGAIN: Record<Comm, { body: string; cost: Eff[] }> = {
  tail: { body: '"아들이 나았다. 이번엔 조카다." 대표가 눈을 피하며 말한다. 의무칸 침상이 또 필요하다.', cost: [{ t: 'med', v: -2 }, { t: 'base', c: 'medtech', i: 2, v: 3 }] },
  medtech: { body: '"동생이 앞칸에서 쫓겨날 것 같다. 한마디만 해 달라." 의사가 처음으로 목소리를 낮춘다.', cost: [{ t: 'rel', c: 'front', v: -3 }] },
  guard: { body: '"부관 얘기, 잊지 않았겠지." 경비대장이 총을 닦으며 묻는다.', cost: [{ t: 'rel', c: 'engine', v: -2 }, { t: 'rel', c: 'tail', v: -1 }] },
  front: { body: '"손님이 또 온다. 이번엔 세 병." 앞칸 대표가 지난번처럼 웃지는 않는다.', cost: [{ t: 'lux', v: -3 }] },
  engine: { body: '"그 견습생, 쓸 만하다. 하나 더." 수석 기관사가 이번엔 이름까지 적어 왔다.', cost: [{ t: 'rel', c: 'tail', v: -3 }] },
};

const FAVORS: Record<Comm, { body: string; cost: Eff[] }> = {
  tail: { body: '"아들이 기침을 한다. 의무칸 침상 하나만." 대표가 처음으로 사적인 부탁을 한다.', cost: [{ t: 'med', v: -2 }, { t: 'base', c: 'medtech', i: 2, v: 3 }] },
  medtech: { body: '"동생이 앞칸 빈자리에 갈 수 있게 해 달라." 아무도 모르게.', cost: [{ t: 'base', c: 'front', i: 2, v: 3 }] },
  guard: { body: '"부관 자리 얘기, 다음에 내 이름도 올려 달라." 경비대장이 낮게 말한다.', cost: [{ t: 'rel', c: 'engine', v: -2 }] },
  front: { body: '"술 두 병만. 손님을 맞아야 한다." 앞칸 대표가 웃는다.', cost: [{ t: 'lux', v: -2 }] },
  engine: { body: '"견습생 하나를 꼬리칸에서 데려가고 싶다. 내가 고른 아이로."', cost: [{ t: 'rel', c: 'tail', v: -2 }] },
};

// ---- 고르기 ----
export function applyEffs(g: Game, effs: readonly Eff[]): void {
  for (const e of effs) {
    switch (e.t) {
      case 'coal': g.coal += e.v; break;
      case 'food': g.food += e.v; break;
      case 'med': g.med = Math.max(0, g.med + e.v); break;
      case 'lux': g.lux = Math.max(0, g.lux + e.v); break;
      case 'trust': g.trust = clamp(g.trust + e.v, 0, 100); break;
      case 'tension': g.tension = clamp(g.tension + e.v, 0, 100); break;
      case 'fear': g.fear = clamp(g.fear + e.v, 0, 100); break;
      case 'injured': g.injured = Math.max(0, g.injured + e.v); break;
      case 'rel': g.comms[e.c].rel = clamp(g.comms[e.c].rel + e.v, -100, 100); break;
      case 'fervor': g.comms[e.c].fervor = clamp(g.comms[e.c].fervor + e.v, 0, 3); break;
      case 'pop': g.comms[e.c].pop = Math.max(1, g.comms[e.c].pop + e.v); break;
      case 'base': g.comms[e.c].base[e.i] += e.v; break;
      case 'lever': {
        const s = g.comms[e.c];
        s[e.which] = clamp(s[e.which] + e.v, 0, 4);
        break;
      }
      case 'debt': g.comms[e.c].debt = true; break;
      case 'grudge': offend(g, e.c); break;
    }
  }
}

export function chooseCard(g: Game, uid: number, index: number): boolean {
  const card = g.cards.find(x => x.uid === uid);
  if (!card) return false;
  const view = viewCard(g, card);
  const choice = view.choices[index];
  if (!choice || choice.disabled) return false;
  g.cards = g.cards.filter(x => x.uid !== uid);
  applyEffs(g, choice.effs);
  const c = card.comm ?? 'tail';
  switch (choice.special) {
    case 'risk_injury':
      // 탄수차를 뒤질 때마다 위험이 커진다.
      if (rnd(g) < 0.3 + 0.15 * Math.min(memo(g, 'abandoned_tender')?.n ?? 0, 3)) { g.injured += 1; journal(g, '탄수차 그늘에서 무언가가 튀어나왔다. 한 사람이 다쳤다.', 'bad'); }
      break;
    case 'favor_risk':
      g.comms[c].favorCool = 4;
      if (rnd(g) < 0.15) {
        for (const o of COMMS) if (o !== c) g.comms[o].rel = clamp(g.comms[o].rel - 5, -100, 100);
        journal(g, `${g.comms[c].leader.name}의 부탁을 들어준 게 알려졌다. 공정성 시비가 붙었다.`, 'bad');
      }
      break;
    case 'strike_bribe':
      if (rnd(g) < 0.25) {
        g.comms.engine.rel = clamp(g.comms.engine.rel - 30, -100, 100);
        journal(g, '수석 기관사를 사려던 게 드러났다. 기관실이 등을 돌렸다.', 'bad');
      } else if (rnd(g) < g.comms.engine.coh) {
        g.comms.engine.fervor = 0;
        g.comms.engine.rel = clamp(g.comms.engine.rel + 5, -100, 100);
        journal(g, '수석 기관사가 화부들을 불 앞으로 돌려보냈다.', 'dark');
      } else {
        journal(g, '수석 기관사는 받았지만 화부들이 따르지 않았다.', 'bad');
      }
      break;
    case 'hide_bite':
      // 숨긴 물림은 비밀이 아니라 시한 사건이다: 2구간 안에 들키거나 칸 안에서 일어난다(body_injury 4.4).
      (g.hiddenBites ??= []).push({ who: card.who ?? '이름 모를 대원', comm: c, at: g.seg, due: g.seg + 2 });
      journal(g, `${card.who ?? '대원'}의 상처를 붕대로 감아 태웠다. 아는 사람은 수색대뿐이다.`, 'dark');
      break;
    case 'bite_cut':
      g.hiddenBites = (g.hiddenBites ?? []).filter(b => b.who !== card.who);
      journal(g, `숨겼던 ${card.who ?? '대원'}의 물린 곳을 의무칸에서 잘랐다.`, 'dark');
      break;
    case 'bite_isolate':
      for (const b of g.hiddenBites ?? []) if (b.who === card.who) b.isolated = true;
      journal(g, `${card.who ?? '대원'}을(를) 빈 칸 끝에 따로 두었다.`, 'dark');
      break;
    case 'bite_shoot':
      g.hiddenBites = (g.hiddenBites ?? []).filter(b => b.who !== card.who);
      onDeath(g, c, [card.who ?? '이름 모를 대원']);
      journal(g, `${card.who ?? '대원'}을(를) 쏘았다. 칸 사람들이 다 들었다.`, 'dark');
      break;
    case 'leave_bitten':
      // 사람을 버렸다는 증언은 적의로 남는다(body_injury 4.3).
      offend(g, c);
      g.comms[c].pop = Math.max(1, g.comms[c].pop - 1);
      g.deaths.push(card.who ?? '이름 모를 대원');
      journal(g, `${card.who ?? '대원'}을(를) 역에 두고 왔다.`, 'dark');
      break;
    case 'tension_reset':
      g.tension = 65;
      g.tensionCrisisUsed += 1;
      break;
    case 'revolt':
      g.end = 'revolt';
      g.phase = 'end';
      break;
    default:
      break;
  }
  for (const ext of CARD_EXTENSIONS) ext.choose?.(g, card, choice);
  if (view.key) remember(g, view.key, choice.label);
  const log = choice.log ?? `${view.title}: ${choice.label}.`;
  if (card.kind !== 'info' && card.kind !== 'trust_crisis' && card.kind !== 'leash') journal(g, log, choice.witness ? 'dark' : undefined);
  if (choice.witness) {
    // 목격자: 살아 돌아온 파견 인원이 자기 칸에 말한다(브리프 9장).
    const crew = g.stop?.crewComm;
    if (crew) {
      const harsh = choice.effs.some(e => e.t === 'trust' && e.v < 0) || choice.special === 'leave_bitten' || choice.special === 'hide_bite';
      g.comms[crew].rel = clamp(g.comms[crew].rel + (harsh ? -5 : 3), -100, 100);
    }
  }
  return true;
}

