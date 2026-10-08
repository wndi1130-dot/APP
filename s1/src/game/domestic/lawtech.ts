import { COMMS, LAWS } from '../data';
import type { Comm, LawId, LawRes } from '../data';
import { lawActive } from '../state';
import type { Game } from '../state';
import { CAR_COMM, COMM_CARS, D, TECHS } from './data';
import type { TechId, Variant } from './data';
import { techMult, variantMult } from './state';

// 기술은 자원을 아끼지 않고 법을 바꾼다(s1c_domestic 7.3, 2026-10-07 사용자 카드 답). 어느 기술이 어느 법을 바꾸는지와 숫자는
// 내정 스레드 제안이다. 바꾸는 방식은 셋:
// - 가혹한 법의 벌을 줄인다(E1, E2, E3 나, E4, E5): 법이 처지에 준 벌(mats)을 처지 보정(refreshSit)으로 덜어 준다.
//   법을 폐지하면 벌도 덜어 줌도 같이 사라진다. 결함판이면 절반(techMult).
// - 가혹한 법에 덜 잔혹한 변형을 연다(M3 가 → 종자곡 반만 풀기, X1 → 아동 노동 짐 꾸리기만, 원래 있던 M2 → 12b): 다른 법 id로 두고
//   원래 법과 하나만 설 수 있다(laws.ts).
// - 이상 법을 사는 값을 깎는다(E3 가, M3 나, M5): 공동 난방 석탄, 공동 식당 식량, 모두를 치료 의약품.

type Pick = { tech: TechId; variant?: Variant };
const mult = (g: Game, p: Pick): number => (p.variant ? variantMult(g, p.tech, p.variant) : techMult(g, p.tech));

/** 법의 처지 벌을 덜어 주는 몫. i는 처지 칸(0 온기, 3 노출), by는 칸마다 덜어 주는 크기(완성판). 한 칸의 덜어 줌은 법의 벌을 넘지 않는다. */
const RELIEF: (Pick & { law: LawId; i: 0 | 3; by: Partial<Record<Comm, number>> })[] = [
  // E1 누설 막기: 눈 녹이기 당번의 온기 −5가 없어지고 노출 벌이 절반(앞칸 +15 → +8, 꼬리칸·의무진 +5 → +2).
  { tech: 'e1', law: 'snow_duty', i: 0, by: { tail: 5, front: 5, medtech: 5 } },
  { tech: 'e1', law: 'snow_duty', i: 3, by: { front: 7, tail: 3, medtech: 3 } },
  // E4 과열 증기: 눈 녹이기 당번의 노출 벌이 없어진다.
  { tech: 'e4', law: 'snow_duty', i: 3, by: { front: 15, tail: 5, medtech: 5 } },
  // E2 압력 조절: 난방 배당 꼬리칸·의무진 온기 −10 → −5, 경비대 −5 → 0.
  { tech: 'e2', law: 'heat_quota', i: 0, by: { tail: 5, medtech: 5, guard: 5 } },
  // E3 나 앞칸 직결: 난방 배당 아래 경비대 벌이 없어진다(앞칸 온기 +5는 아래 BONUS).
  { tech: 'e3', variant: 'b', law: 'heat_quota', i: 0, by: { guard: 5 } },
];

/** 법이 서 있을 때만 붙는 덤. E3 나: 난방 배당 아래 앞칸 온기 +5. */
const BONUS: (Pick & { law: LawId; i: 0 | 3; by: Partial<Record<Comm, number>> })[] = [
  { tech: 'e3', variant: 'b', law: 'heat_quota', i: 0, by: { front: 5 } },
];

/** 단열한 객차의 몫(E5): 그 칸이 사는 객차 중 단열한 비율만큼 난방 배당의 온기 벌을 받지 않는다. */
function insulatedShare(g: Game, c: Comm): number {
  const d = g.dom;
  if (!d) return 0;
  return Math.min(1, d.insulated.filter(car => CAR_COMM[car] === c).length / COMM_CARS[c]);
}

/** 처지 보정(refreshSit)에 법·기술 몫을 더한다. */
export function lawTechSit(g: Game, sit: Record<Comm, [number, number, number, number]>): void {
  for (const law of ['snow_duty', 'heat_quota'] as LawId[]) {
    if (!lawActive(g, law)) continue;
    const mats = LAWS[law].mats;
    for (const c of COMMS) {
      const m = mats[c];
      if (!m) continue;
      for (const i of [0, 3] as const) {
        // 벌의 크기: 온기는 깎인 만큼, 노출은 오른 만큼.
        const pen = i === 0 ? Math.max(0, -m[0]) : Math.max(0, m[3]);
        if (pen === 0) continue;
        let relief = RELIEF.filter(r => r.law === law && r.i === i).reduce((s, r) => s + (r.by[c] ?? 0) * mult(g, r), 0);
        if (law === 'heat_quota' && i === 0) relief += pen * insulatedShare(g, c);
        relief = Math.min(pen, relief);
        sit[c][i] += i === 0 ? relief : -relief;
      }
    }
  }
  for (const b of BONUS) {
    if (!lawActive(g, b.law)) continue;
    for (const c of COMMS) if (b.by[c]) sit[c][b.i] += (b.by[c] ?? 0) * mult(g, b) * (b.i === 0 ? 1 : -1);
  }
}

/** 기술로 바뀐 법의 수치(res). 지금은 M5: 모두를 치료의 의약품 소모 ×1.6 → ×1.3. */
export function lawTechRes(g: Game, law: LawId): LawRes {
  const res = LAWS[law].res;
  if (law === 'treat_all' && res.medMult !== undefined) {
    const m = techMult(g, 'm5');
    if (m > 0) return { ...res, medMult: res.medMult - (res.medMult - D.m5TreatMed) * m };
  }
  return res;
}

/** 이상 법이 덜 먹는 석탄/구간(E3 가: 공동 난방 +1.25 → +0.6). */
export function lawTechCoal(g: Game): number {
  return lawActive(g, 'common_heating') ? D.e3aHeatCoal * variantMult(g, 'e3', 'a') : 0;
}

/** 이상 법이 덜 먹는 식량/구간(M3 나 얼음 상자: 공동 식당 +5 → +3.5). */
export function lawTechFood(g: Game): number {
  return lawActive(g, 'common_kitchen') ? D.iceBoxFood * variantMult(g, 'm3', 'b') : 0;
}

/** 어느 기술이 어느 법을 바꾸나(법 미리보기 줄과 일지에 쓴다). 변형 법(종자곡 반만 풀기 등)은 법 표에 따로 있다. */
const TOUCHES: (Pick & { law: LawId; text: string })[] = [
  { tech: 'e1', law: 'snow_duty', text: '온기 벌 없음, 노출 벌 절반' },
  { tech: 'e4', law: 'snow_duty', text: '노출 벌 없음' },
  { tech: 'e2', law: 'heat_quota', text: '꼬리칸·의무진 온기 −10 → −5, 경비대 벌 없음' },
  { tech: 'e3', variant: 'b', law: 'heat_quota', text: '경비대 벌 없음, 앞칸 온기 +5' },
  { tech: 'e5', law: 'heat_quota', text: '단열한 객차는 온기 벌 없음' },
  { tech: 'e3', variant: 'a', law: 'common_heating', text: '석탄 +1.25 → +0.6/구간' },
  { tech: 'm3', variant: 'b', law: 'common_kitchen', text: '식량 +5 → +3.5/구간' },
  { tech: 'm5', law: 'treat_all', text: '의약품 소모 ×1.6 → ×1.3' },
];

/** 기술이 원래 법 대신 올릴 변형 법을 연다(laws.ts). 쓸모 줄과 봇이 읽는다. */
const OPENS: (Pick & { law: LawId; base: LawId })[] = [
  { tech: 'm3', variant: 'a', law: 'seed_half', base: 'seed_grain' },
  { tech: 'x1', law: 'child_pack', base: 'child_labor' },
  { tech: 'm2', law: 'triage_std', base: 'triage' },
];
const sameVariant = (p: Pick, v?: Variant) => !p.variant || !v || p.variant === v;

/** 이 기술(변형)이 쓸모 있으려면 서 있어야 하는 법. 변형을 정하지 않았으면 두 변형의 법을 다 돌려준다. */
export function techLaws(tech: TechId, variant?: Variant): LawId[] {
  const laws = [...TOUCHES.filter(t => t.tech === tech && sameVariant(t, variant)).map(t => t.law),
    ...OPENS.filter(o => o.tech === tech && sameVariant(o, variant)).map(o => o.base)];
  return [...new Set(laws)];
}

/** 효과가 모두 법에 걸린 기술(7.3). 그 법이 없으면 사도 쓸 데가 없다. E4(대체 화부)·M5(이)는 법 밖 효과가 있어 빠진다. */
export const LAW_ONLY_TECHS: TechId[] = ['e1', 'e2', 'e3', 'e5', 'm2', 'm3', 'x1'];

/** 이 기술을 복원할 때 쓸 변형. 법에만 걸린 기술이면 서 있는 법 쪽 변형(변형이 없으면 undefined), 그 법이 하나도 없으면 null(복원할 쓸모가 없다).
 *  법과 상관없는 기술이면 첫 변형을 돌려주고 고르는 쪽(방침·봇)이 따로 정한다. 3단계 공방장(6.4, 2f1f64e)과 봇이 같이 쓴다. */
export function usefulVariant(g: Game, tech: TechId): Variant | undefined | null {
  const vs: (Variant | undefined)[] = TECHS[tech].variants ? ['a', 'b'] : [undefined];
  if (!LAW_ONLY_TECHS.includes(tech)) return vs[0];
  // 변형 없는 기술은 찾아도 undefined다. 찾은 것과 못 찾은 것(null)을 가른다(K01 6).
  const i = vs.findIndex(v => techLaws(tech, v).some(l => lawActive(g, l)));
  return i < 0 ? null : vs[i];
}

/** 설계도와 복원 단추에 붙는 쓸모 줄(내정 7.3 함정 막기, 2026-10-07 내정 스레드). 법과 상관없는 기술이면 null. */
export function techUseLine(g: Game, tech: TechId, variant?: Variant): string | null {
  const parts = [
    ...TOUCHES.filter(t => t.tech === tech && sameVariant(t, variant)).map(t => `${LAWS[t.law].title}이(가) 서 있을 때`),
    ...OPENS.filter(o => o.tech === tech && sameVariant(o, variant)).map(o => `${LAWS[o.base].title} 대신 ${LAWS[o.law].title}을(를) 올릴 때`),
  ];
  if (parts.length === 0) return null;
  const now = techLaws(tech, variant).some(l => lawActive(g, l));
  return `쓸모: ${[...new Set(parts)].join(', ')}${now ? '(지금 서 있다)' : '(지금은 없다)'}`;
}

/** 지금 쓸 수 있는 기술이 이 법을 어떻게 바꾸는지(법 미리보기 끝에 붙는 줄). */
export function lawTechLines(g: Game, law: LawId): string[] {
  return TOUCHES.filter(t => t.law === law && mult(g, t) > 0)
    .map(t => `${TECHS[t.tech].variants && t.variant ? TECHS[t.tech].variants![t.variant].name : TECHS[t.tech].name}: ${t.text}${mult(g, t) < 1 ? '(결함판이라 절반)' : ''}`);
}

/** 기술이 막 쓸 수 있게 됐을 때 이미 서 있는 법이 바뀌면 일지 한 줄. */
export function lawTechNews(g: Game, tech: TechId): string[] {
  return TOUCHES.filter(t => t.tech === tech && lawActive(g, t.law) && mult(g, t) > 0).map(t => `${LAWS[t.law].title}이(가) 바뀐다: ${t.text}.`);
}
