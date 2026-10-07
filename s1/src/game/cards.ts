import { COMMS, COMM_NAME, P, REP_ROLE } from './data';
import type { Comm } from './data';
import { onDeath } from './death';
import { offend } from './politics';
import { clamp, journal, pick, rnd, situation } from './state';
import type { Card, Game } from './state';

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
  label: string;
  effs: Eff[];
  /** 효과 말고 따로 처리하는 일 */
  special?: string;
  disabled?: string;
  /** 목격자가 있는 선택 */
  witness?: boolean;
  log?: string;
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
interface TravelEvent { id: string; when: (g: Game) => boolean; view: (g: Game) => CardView }

export const TRAVEL_EVENTS: TravelEvent[] = [
  {
    id: 'tail_cold', when: g => situation(g, 'tail')[0] <= 38,
    view: g => ({
      title: '꺼진 난로', speaker: leader(g, 'tail'), focus: 'tail', required: true,
      body: '꼬리칸 난로가 이틀째 꺼져 있다. 아이들 손끝이 하얗다. 앞칸엔 난로가 두 개다.',
      choices: [
        { label: '앞칸 연료를 덜어 온다', effs: [{ t: 'base', c: 'tail', i: 0, v: 5 }, { t: 'base', c: 'front', i: 0, v: -5 }, { t: 'rel', c: 'tail', v: 5 }, { t: 'rel', c: 'front', v: -8 }] },
        { label: '담요를 나눈다', effs: [{ t: 'lux', v: -1 }, { t: 'rel', c: 'tail', v: 4 }] },
        { label: '참으라 한다', effs: [{ t: 'rel', c: 'tail', v: -5 }, { t: 'tension', v: 2 }] },
      ],
    }),
  },
  {
    id: 'crowd_fight', when: g => situation(g, 'tail')[2] >= 78,
    view: g => ({
      title: '자리 싸움', speaker: leader(g, 'guard'), focus: 'tail', required: true,
      body: '꼬리칸에서 누울 자리를 두고 주먹이 오갔다. 한 사람이 머리를 다쳤다.',
      choices: [
        { label: '경비대가 말린다', effs: [{ t: 'rel', c: 'tail', v: -3 }, { t: 'tension', v: -3 }, { t: 'fear', v: 2 }] },
        { label: '칸을 넓혀 준다', effs: [{ t: 'base', c: 'tail', i: 2, v: -5 }, { t: 'base', c: 'front', i: 2, v: 5 }, { t: 'rel', c: 'front', v: -5 }, { t: 'rel', c: 'tail', v: 3 }] },
        { label: '내버려 둔다', effs: [{ t: 'injured', v: 1 }, { t: 'tension', v: 4 }] },
      ],
    }),
  },
  {
    id: 'front_curtain', when: () => true,
    view: g => ({
      title: '앞칸의 커튼', speaker: leader(g, 'tail'), focus: 'front', required: true,
      body: '앞칸 창에 커튼이 걸렸다. 식사 시간마다 닫힌다. 꼬리칸이 그 앞에 줄을 섰다.',
      choices: [
        { label: '커튼을 걷게 한다', effs: [{ t: 'rel', c: 'front', v: -6 }, { t: 'rel', c: 'tail', v: 4 }] },
        { label: '앞칸 편을 든다', effs: [{ t: 'rel', c: 'tail', v: -4 }, { t: 'rel', c: 'front', v: 4 }] },
        { label: '대표 둘을 부른다', effs: [{ t: 'lux', v: -1 }, { t: 'tension', v: -2 }, { t: 'trust', v: 1 }] },
      ],
    }),
  },
  {
    id: 'water_tower', when: g => g.seg >= 2,
    view: g => ({
      title: '얼어붙은 급수탑', speaker: leader(g, 'engine'), focus: 'engine', required: true,
      body: '급수탑 관이 얼었다. 보일러 물이 반밖에 없다. 다음 급수탑까지는 멀다.',
      choices: [
        { label: '불을 피워 녹인다', effs: [{ t: 'coal', v: -3 }] },
        { label: '꼬리칸이 눈을 녹인다', effs: [{ t: 'base', c: 'tail', i: 3, v: 5 }, { t: 'rel', c: 'tail', v: -4 }] },
        { label: '다음 역까지 버틴다', effs: [{ t: 'coal', v: -2 }, { t: 'rel', c: 'engine', v: -4 }] },
      ],
    }),
  },
  {
    id: 'snow_drift', when: g => g.seg >= 3,
    view: g => ({
      title: '눈더미', speaker: leader(g, 'engine'), focus: 'engine', required: true,
      body: '선로가 눈더미에 묻혔다. 삽이 열두 자루 있다.',
      choices: [
        { label: '모든 칸이 나눠 판다', effs: [{ t: 'food', v: -3 }, { t: 'rel', c: 'front', v: -3 }, { t: 'tension', v: -1 }] },
        { label: '꼬리칸이 판다', effs: [{ t: 'rel', c: 'tail', v: -5 }] },
        { label: '기관차로 밀어붙인다', effs: [{ t: 'coal', v: -4 }, { t: 'base', c: 'engine', i: 3, v: 4 }] },
      ],
    }),
  },
  {
    id: 'abandoned_tender', when: g => g.seg >= 2 && g.coal < 80,
    view: () => ({
      title: '측선의 탄수차', focus: 'engine', required: true,
      body: '측선에 버려진 탄수차가 서 있다. 안에 석탄이 보인다. 주위가 너무 조용하다.',
      choices: [
        { label: '석탄을 옮긴다', effs: [{ t: 'coal', v: 8 }], special: 'risk_injury' },
        { label: '지나친다', effs: [] },
      ],
    }),
  },
  {
    id: 'sick_child', when: g => g.med >= 2,
    view: g => ({
      title: '아이 열병', speaker: leader(g, 'medtech'), focus: 'medtech', required: true,
      body: '꼬리칸 아이 셋이 열이 난다. 해열제는 의무칸 상자에 있다.',
      choices: [
        { label: '의약품을 쓴다', effs: [{ t: 'med', v: -2 }, { t: 'rel', c: 'tail', v: 4 }, { t: 'rel', c: 'medtech', v: 2 }] },
        { label: '아껴 둔다', effs: [{ t: 'rel', c: 'tail', v: -4 }, { t: 'rel', c: 'medtech', v: -2 }] },
      ],
    }),
  },
  {
    id: 'ration_line', when: g => situation(g, 'tail')[1] < 45,
    view: g => ({
      title: '배급 줄', speaker: leader(g, 'tail'), focus: 'tail', required: true,
      body: '배급 줄 끝에서 빵이 떨어졌다. 뒤에 선 사람들이 소리친다.',
      choices: [
        { label: '다시 나눈다', effs: [{ t: 'food', v: -4 }, { t: 'rel', c: 'tail', v: 3 }] },
        { label: '경비대를 세운다', effs: [{ t: 'fear', v: 3 }, { t: 'rel', c: 'tail', v: -3 }, { t: 'rel', c: 'guard', v: 2 }] },
      ],
    }),
  },
  {
    id: 'guard_frost', when: g => situation(g, 'guard')[0] < 50,
    view: g => ({
      title: '동상', speaker: leader(g, 'guard'), focus: 'guard', required: true,
      body: '지붕 경계를 서던 대원 둘이 동상을 입었다. 교대를 줄여 달라고 한다.',
      choices: [
        { label: '경비대 난방을 올린다', effs: [{ t: 'lever', c: 'guard', which: 'heat', v: 1 }, { t: 'rel', c: 'guard', v: 3 }] },
        { label: '경계를 줄인다', effs: [{ t: 'rel', c: 'guard', v: 2 }, { t: 'tension', v: 2 }] },
        { label: '그대로 선다', effs: [{ t: 'rel', c: 'guard', v: -5 }, { t: 'injured', v: 1 }] },
      ],
    }),
  },
];

export function drawTravelEvent(g: Game): string | null {
  const pool = TRAVEL_EVENTS.filter(e => e.when(g) && !g.recentEvents.includes(e.id));
  if (pool.length === 0) return null;
  const id = pick(g, pool).id;
  g.recentEvents = [...g.recentEvents, id].slice(-4);
  return id;
}

// ---- 카드 보기 ----
export function viewCard(g: Game, card: Card): CardView {
  const c = card.comm ?? 'tail';
  switch (card.kind) {
    case 'travel': {
      const def = TRAVEL_EVENTS.find(e => e.id === card.text);
      if (!def) break;
      const v = def.view(g);
      return { ...v, choices: withAfford(g, v.choices) };
    }
    case 'demand': {
      const [w, r, , ex] = situation(g, c);
      if (c === 'engine' && ex > 50) {
        return {
          title: '화부 교대', speaker: leader(g, 'engine'), focus: 'engine', required: true,
          body: `화부들이 교대 없이 삽질을 한 지 오래다. 위험 노출 ${Math.round(ex)}. 교대를 늘려 달라고 한다.`,
          choices: withAfford(g, [
            { label: '교대를 늘린다', effs: [{ t: 'coal', v: -P.shiftCoal }, { t: 'base', c: 'engine', i: 3, v: -P.shiftRelief }, { t: 'rel', c: 'engine', v: 3 }] },
            { label: '견습생을 붙인다', effs: [{ t: 'base', c: 'engine', i: 3, v: -5 }, { t: 'base', c: 'tail', i: 3, v: 3 }, { t: 'rel', c: 'tail', v: -2 }] },
            { label: '거절한다', effs: [{ t: 'fervor', c: 'engine', v: 1 }, { t: 'rel', c: 'engine', v: -P.refuseRel }] },
          ]),
        };
      }
      const s = g.comms[c];
      const which = s.heat >= 4 ? 'ration' : s.ration >= 4 ? 'heat' : w < r ? 'heat' : 'ration';
      return {
        title: which === 'heat' ? '난방 요구' : '배급 요구', speaker: leader(g, c), focus: c, required: true,
        body: which === 'heat'
          ? `${COMM_NAME[c]} 온기 ${Math.round(w)}. 밤마다 사람들이 서로 붙어 잔다. 난방을 올려 달라고 한다.`
          : `${COMM_NAME[c]} 배급 ${Math.round(r)}. 그릇이 반만 찬다. 배급을 올려 달라고 한다.`,
        choices: withAfford(g, [
          { label: which === 'heat' ? '난방을 올린다' : '배급을 올린다', effs: [{ t: 'lever', c, which, v: 1 }, { t: 'rel', c, v: 2 }] },
          { label: '거절한다', effs: [{ t: 'fervor', c, v: 1 }, { t: 'rel', c, v: -P.refuseRel }] },
        ]),
      };
    }
    case 'favor': {
      const fav = FAVORS[c];
      return {
        title: '사적인 부탁', speaker: leader(g, c), focus: c, required: true, body: fav.body,
        choices: withAfford(g, [
          { label: '들어준다', effs: [...fav.cost, { t: 'debt', c }], special: 'favor_risk' },
          { label: '거절한다', effs: [{ t: 'rel', c, v: -3 }] },
        ]),
      };
    }
    case 'strike_warn': {
      const [, , , ex] = situation(g, 'engine');
      return {
        title: '파업 경고', speaker: leader(g, 'engine'), focus: 'engine', required: true,
        body: `"다음 역까지 답이 없으면 불을 끄겠다." 기관실 위험 노출 ${Math.round(ex)}, 배급 ${Math.round(situation(g, 'engine')[1])}.`,
        choices: withAfford(g, [
          { label: '교대를 늘린다', effs: [{ t: 'coal', v: -P.shiftCoal }, { t: 'base', c: 'engine', i: 3, v: -P.shiftRelief }, { t: 'rel', c: 'engine', v: 6 }] },
          { label: '기관실 배급 +1', effs: [{ t: 'lever', c: 'engine', which: 'ration', v: 1 }, { t: 'rel', c: 'engine', v: 5 }, { t: 'rel', c: 'medtech', v: -2 }] },
          { label: '듣기만 한다', effs: [{ t: 'rel', c: 'engine', v: -3 }] },
        ]),
      };
    }
    case 'strike': {
      return {
        title: '파업', speaker: leader(g, 'engine'), focus: 'engine', required: true,
        body: '보일러 불이 낮게 깔렸다. 열차가 선다. 기관실 문 앞에 화부들이 앉아 있다.',
        choices: withAfford(g, [
          { label: '요구를 들어준다', effs: [{ t: 'lever', c: 'engine', which: 'ration', v: 1 }, { t: 'fervor', c: 'engine', v: -1 }, { t: 'fervor', c: 'medtech', v: 1 }, { t: 'rel', c: 'engine', v: 12 }] },
          { label: '교대를 늘린다', effs: [{ t: 'coal', v: -P.shiftCoal }, { t: 'base', c: 'engine', i: 3, v: -P.shiftRelief }, { t: 'fervor', c: 'engine', v: -1 }, { t: 'rel', c: 'engine', v: 8 }] },
          { label: '수석 기관사를 산다', effs: [{ t: 'lux', v: -3 }], special: 'strike_bribe' },
          { label: '버틴다', effs: [{ t: 'tension', v: 3 }] },
        ]),
      };
    }
    case 'rescue': {
      const ban = g.passed.no_outsiders !== undefined;
      return {
        title: '부상자', speaker: { name: card.who ?? '수색대', role: '수색대' }, required: true,
        body: ban ? '역사 안에 다친 사람이 있다. 외부인 받지 않기 법이 있다.' : '역사 안에 다친 사람 둘이 있다. 데려가 달라고 한다. 꼬리칸은 이미 꽉 찼다.',
        choices: withAfford(g, ban ? [
          { label: '법대로 두고 온다', effs: [{ t: 'trust', v: -1 }], witness: true },
        ] : [
          { label: '데려온다', effs: [{ t: 'pop', c: 'tail', v: 2 }, { t: 'base', c: 'tail', i: 2, v: 3 }, { t: 'injured', v: 1 }, { t: 'rel', c: 'medtech', v: 3 }], witness: true },
          { label: '물자만 받는다', effs: [{ t: 'food', v: 3 }, { t: 'trust', v: -1 }, { t: 'rel', c: 'medtech', v: -3 }], witness: true },
          { label: '두고 온다', effs: [{ t: 'trust', v: -1 }, { t: 'rel', c: 'medtech', v: -3 }], witness: true },
        ]),
      };
    }
    case 'bitten': {
      return {
        title: '물렸다', speaker: { name: card.who ?? '수색대원', role: COMM_NAME[c] }, focus: c, required: true,
        body: `${card.who ?? '대원'}이(가) 팔을 물렸다. 감염 창이 닫히기 전에 잘라야 한다.`,
        choices: withAfford(g, [
          { label: '팔을 자른다', effs: [{ t: 'med', v: -3 }, { t: 'injured', v: 1 }, { t: 'rel', c, v: 2 }], witness: true },
          { label: '숨겨 준다', effs: [], special: 'hide_bite', witness: true },
          { label: '두고 온다', effs: [{ t: 'rel', c, v: -8 }, { t: 'tension', v: 2 }], special: 'leave_bitten', witness: true },
        ]),
      };
    }
    case 'tension_crisis': {
      return {
        title: '마지막 기회', speaker: leader(g, 'tail'), focus: 'tail', required: true,
        body: '칸마다 사람들이 모였다. 문이 잠기기 시작했다. 오늘 밤을 넘기지 못할 수도 있다.',
        choices: withAfford(g, [
          { label: '경비대를 푼다', effs: [{ t: 'fear', v: 15 }, { t: 'trust', v: -10 }, { t: 'rel', c: 'tail', v: -10 }], special: 'tension_reset' },
          { label: '창고를 연다', effs: [{ t: 'food', v: -15 }, { t: 'coal', v: -10 }, { t: 'rel', c: 'tail', v: 8 }], special: 'tension_reset' },
          { label: '아무것도 안 한다', effs: [], special: 'revolt' },
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
      if (rnd(g) < 0.3) { g.injured += 1; journal(g, '탄수차 그늘에서 무언가가 튀어나왔다. 한 사람이 다쳤다.', 'bad'); }
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
      g.injured += 1;
      if (rnd(g) < 0.5) {
        g.tension = clamp(g.tension + 8, 0, 100);
        g.injured = Math.max(0, g.injured - 1);
        journal(g, `${card.who ?? '숨겨 준 대원'}이(가) 밤중에 일어났다. 칸 안에서.`, 'bad');
        onDeath(g, c, [card.who ?? '이름 모를 대원']);
      } else {
        journal(g, `${card.who ?? '대원'}의 상처는 덧나지 않았다. 아무도 모른다.`, 'dark');
      }
      break;
    case 'leave_bitten':
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

