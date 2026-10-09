import { COMM_NAME } from '../data';
import type { Comm } from '../data';
import { MOTION_SOURCES, MOTIONS } from '../motions';
import type { MotionDef } from '../motions';
import { clamp, journal } from '../state';
import type { Game, MotionAgenda } from '../state';
import { D, TECHS } from './data';
import type { Variant } from './data';
import { techRelSides, techTitle } from './workshop';

// E3 난방 배관의 의회 추인(s1c_domestic 7.3, 2026-10-08 사용자 아침 목록 답, 기획 점검 19번 '가').
// 복원을 시작하면 다음 회기 안건에 '배관 추인'이 하나 오른다(그 회기 안건 자리 하나를 쓴다). 표결은 S1a 표결 그대로다.
// 가결이면 고른 변형, 부결이면 반대 변형으로 간다. 관계 ±5는 시작이 아니라 이 표결 결과가 나올 때 결과의 변형으로 움직인다.
// 추인 전엔 복원을 마쳐도 완성되지 않는다(workshop.ts). 복원을 취소하면 techs.e3가 지워져 안건도 저절로 내려간다.
// 회기에 못 올라갔거나 다른 안건을 골라 표결하지 않았으면 안건은 다음 회기로 이어진다(추정, 문서에 없다).

const other = (v: Variant): Variant => (v === 'a' ? 'b' : 'a');

/** 추인을 기다리는 E3의 고른 변형. 없으면 null. */
export function pipePending(g: Game): Variant | null {
  const st = g.dom?.techs.e3;
  return st?.pending && st.variant ? st.variant : null;
}

function variantLine(v: Variant): string {
  const def = TECHS.e3.variants![v];
  return `${def.name}: ${def.effect}`;
}

/** 표결 결과로 관계 ±5를 옮긴다: 결과의 변형에서 원하는 쪽 +5, 싫어하는 쪽 −5(7.5). */
function moveRel(g: Game, v: Variant): void {
  const sides = techRelSides('e3', v);
  for (const c of sides.like) g.comms[c].rel = clamp(g.comms[c].rel + D.techRel, -100, 100);
  for (const c of sides.dislike) g.comms[c].rel = clamp(g.comms[c].rel - D.techRel, -100, 100);
}

/** 표결이 끝났을 때 부른다. 안건이 오른 뒤에 복원이 취소됐으면 아무 일도 없다. */
export function ratifyPipe(g: Game, passed: boolean): void {
  const d = g.dom;
  const st = d?.techs.e3;
  const asked = pipePending(g);
  if (!d || !st || !asked) return;
  const result = passed ? asked : other(asked);
  st.pending = false;
  st.variant = result;
  if (!passed) d.pipeFlip = result;
  moveRel(g, result);
  const sides = techRelSides('e3', result);
  const who = [
    sides.like.length ? `${sides.like.map(c => COMM_NAME[c]).join('·')}이(가) 반긴다` : '',
    sides.dislike.length ? `${sides.dislike.map(c => COMM_NAME[c]).join('·')}은(는) 못마땅하다` : '',
  ].filter(Boolean).join(', ');
  journal(g, passed
    ? `의회가 ${techTitle(g, 'e3')} 배관을 추인했다.${who ? ` ${who}.` : ''}`
    : `의회가 추인하지 않았다. 배관은 반대쪽으로 놓는다: ${techTitle(g, 'e3')}.${who ? ` ${who}.` : ''}`, passed ? 'good' : 'bad');
}

/** 변형 하나에 대한 한 집단의 물질 몫(−2~+2): 그 변형을 좋아하면 +2, 싫어하면 −2. */
function lean(g: Game, c: Comm): { mat: number; ideo: number } {
  const v = pipePending(g);
  const def = v ? TECHS.e3.variants![v] : null;
  return { mat: def ? (def.like.includes(c) ? 2 : def.dislike.includes(c) ? -2 : 0) : 0, ideo: 0 };
}

const PIPE: MotionDef = {
  need: 51,
  lean: (g, c) => lean(g, c),
  title: () => '배관 추인',
  changes: g => {
    const v = pipePending(g);
    if (!v) return ['추인할 배관이 없다'];
    return [
      `통과: ${variantLine(v)}`,
      `부결: 반대쪽으로 놓는다. ${variantLine(other(v))}`,
      '관계 ±5는 이 표결 결과의 쪽으로 움직인다',
    ];
  },
  onPass: g => ratifyPipe(g, true),
  onFail: g => ratifyPipe(g, false),
  rank: 'ratify',
};

Object.assign(MOTIONS, { pipe: PIPE });

MOTION_SOURCES.push((g): MotionAgenda[] => (pipePending(g) ? [{ kind: 'motion', motion: 'pipe' }] : []));
