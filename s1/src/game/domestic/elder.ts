import { COMM_NAME, REP_AGE, TRAIT_BAN, TRAITS } from '../data';
import type { Comm } from '../data';
import { onDeath } from '../death';
import { drawPerson, journal, pick } from '../state';
import type { Game } from '../state';
import { D } from './data';
import type { Field } from './data';
import { attachApprentice, freeTeacher, manualWriter, startManual } from './knowledge';
import { domCard, personById } from './state';
import type { DomPerson, DomState, ElderArc } from './state';

// 늙은 장인의 마지막(s1c_domestic 8.9, 2026-10-08 사용자 아침 목록 답, 기획 점검 18번 '가'). 숫자는 제안이다.
// 판마다 수석 기관사·의무장·공방장 가운데 하나(enableDomestic이 씨앗으로 고른다)가 8~14구간에 첫 조짐을 보이고,
// 2~3구간 뒤 짙은 조짐, 그다음 구간에 쓰러져 죽는다. 조짐은 거짓말하지 않는다: 첫 조짐이 뜨면 반드시 쓰러진다.
// 첫 조짐 카드(dom:elder)에서 견습을 서두르기 · 매뉴얼 남기기 · 쉬게 두기 가운데 하나를 고른다.
// 그 사람이 아크 전에 다른 까닭(물림, 사고, 파견)으로 죽거나 열차를 떠나면 아크는 조용히 끝난다. 판에 한 번뿐이다.
// 금지선: 병명을 붙이지 않는다(늙음과 추위). 기침을 열병·감염으로 읽히게 쓰지 않고, 격리·처치 장면도 없다(16.1).

export type ElderChoice = NonNullable<ElderArc['choice']>;

/** 분야마다 첫 조짐과 짙은 조짐 한 줄(8.9). 칸 창의 한 줄이고, 얼굴 표시는 화면이 stage를 보고 그린다. */
const SIGN: Record<'engine' | 'med' | 'craft', [string, string]> = {
  engine: ['밤마다 기관실에서 기침이 들린다', '압력계를 읽는 손이 떨린다'],
  med: ['바늘을 꿰다 손을 멈춘다', '같은 처방을 두 번 묻는다'],
  craft: ['줄질을 하다 숨을 고른다', '도면을 팔 길이만큼 멀리 들고 본다'],
};
const FALL: Record<'engine' | 'med' | 'craft', string> = {
  engine: '수석 기관사가 압력계 앞에서 무릎을 꿇었다. 늙음과 추위가 겹쳤다. 일어나지 못했다.',
  med: '의무장이 바늘을 쥔 채 앉은 자리에서 숨을 거뒀다. 늙음과 추위가 겹쳤다.',
  craft: '공방장이 줄을 쥔 채 작업대 앞에서 쓰러졌다. 늙은 몸이 추위를 못 버텼다.',
};

export function elderSign(f: Field, strong: boolean): string {
  const s = SIGN[f as keyof typeof SIGN];
  return s ? s[strong ? 1 : 0] : '';
}

/** 첫 조짐에서 쓰러질 때까지 구간 수의 범위(카드 글에 쓴다): 짙은 조짐까지 2~3구간 + 다음 구간 1. */
export function elderSpan(): [number, number] {
  return [D.elderGap[0] + 1, D.elderGap[1] + 1];
}

export function elderPerson(g: Game): DomPerson | undefined {
  return personById(g, g.dom?.elder?.who);
}

function dom(g: Game): DomState {
  if (!g.dom) throw new Error('S1c 내정이 꺼진 판이다');
  return g.dom;
}

/** 그 사람이 지금 가르치고 있는 견습생(배우는 중인 살아 있는 사람). */
export function elderPupil(g: Game, p: DomPerson): DomPerson | undefined {
  const pu = personById(g, p.pupil);
  return pu && pu.alive && !pu.gone && pu.learn ? pu : undefined;
}

/** 고른 길을 못 가는 까닭(카드의 흐린 선택지). 갈 수 있으면 undefined. */
export function elderWhy(g: Game, p: DomPerson, kind: ElderChoice): string | undefined {
  if (kind === 'rest') return undefined;
  if (kind === 'pupil') {
    // 이미 가르치는 견습이 있으면 서두르고, 없으면 새로 붙인다(그 사람이 가르칠 수 있을 때만).
    if (elderPupil(g, p)) return undefined;
    return freeTeacher(g, p.field) === p ? undefined : '가르칠 틈이 없다';
  }
  const { who, why } = manualWriter(g, p.field);
  if (why) return why;
  return who === p ? undefined : '매뉴얼을 쓸 틈이 없다';
}

/** 첫 조짐 카드의 답을 적용한다. 관계 +3(쉬게 두기)은 카드 효과 줄이 이미 옮겼다. 조짐이 뜬 뒤 한 번만 받는다. */
export function chooseElder(g: Game, kind: ElderChoice): boolean {
  const d = dom(g);
  const a = d.elder;
  const p = elderPerson(g);
  if (!a || !p || a.stage !== 1 || a.choice || !p.alive || elderWhy(g, p, kind)) return false;
  if (kind === 'pupil') {
    const pu = elderPupil(g, p);
    if (pu?.learn) {
      // 남은 구간 절반, 올림. 이번 단계만 줄고 다음 단계는 평소 속도다.
      pu.learn.left = Math.max(1, Math.ceil(pu.learn.left / 2));
      journal(g, `${p.name}이(가) ${pu.name}에게 남은 날을 다 쏟기로 했다.`);
    } else if (!attachApprentice(g, p.field, 'guild', true)) {
      return false;
    }
  } else if (kind === 'manual') {
    if (!startManual(g, p.field, D.elderManualSegs)) return false;
  } else {
    p.resting = true;
    a.fall = (a.fall ?? g.seg) + D.elderRestDelay;
    journal(g, `${p.name}이(가) 일손을 놓고 쉰다. 일은 칸이 나눠 진다.`);
  }
  a.choice = kind;
  return true;
}

/** 대표가 죽었는데 아무도 잇지 않았으면 그 칸이 잇는다(S1b 판은 죽음 훅이 이어 준다, 이 함수는 그때 건너뛴다). hub.ts의 승계와 같은 모양. */
function succeedLeader(g: Game, c: Comm): void {
  const s = g.comms[c];
  const p = drawPerson(g, c, REP_AGE[c]);
  const ban = TRAIT_BAN[c];
  const traits = TRAITS.filter(t => t !== ban && t !== s.leader.trait);
  s.leader = { personId: p.id, name: p.name, age: p.age, trait: pick(g, traits), traitShown: 0 };
  s.sick = undefined;
  s.debt = false;
  s.promise = null;
  journal(g, `${p.name}이(가) ${COMM_NAME[c]} 대표 자리를 이었다.`, 'dark');
}

function fall(g: Game, a: ElderArc, p: DomPerson): void {
  a.stage = 3;
  p.alive = false;
  delete p.resting;
  const key = p.field as keyof typeof FALL;
  journal(g, FALL[key] ?? `${p.name}이(가) 쓰러졌다.`, 'bad');
  // 시신은 시신 처리 법이 정하고, 그 분야에 아는 사람이 없어지면 knowledgeTick이 다음 정산에서 카운트다운을 시작한다(8.5).
  onDeath(g, p.comm, [p.name], 'other');
  if (g.comms[p.comm].leader.name === p.name) succeedLeader(g, p.comm);
}

/** 정산 때 아크 한 걸음(knowledgeTick 다음). 한 번 부르면 한 단계만 간다. */
export function elderTick(g: Game): void {
  const a = g.dom?.elder;
  if (!a || a.stage >= 3) return;
  const p = elderPerson(g);
  if (!p || !p.alive || p.gone) { a.stage = 3; return; }
  if (a.stage === 0) {
    if (g.seg < a.first) return;
    a.stage = 1;
    a.strong = g.seg + a.gap;
    a.fall = a.strong + 1;
    journal(g, `${p.name}: ${elderSign(p.field, false)}.`, 'dark');
    domCard(g, { kind: 'dom:elder', who: p.id });
    return;
  }
  if (a.stage === 1 && g.seg >= (a.strong ?? Infinity)) {
    a.stage = 2;
    journal(g, `${p.name}: ${elderSign(p.field, true)}.`, 'dark');
    return;
  }
  if (a.stage === 2 && g.seg >= (a.fall ?? Infinity)) fall(g, a, p);
}
