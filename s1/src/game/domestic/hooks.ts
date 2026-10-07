import { LAWS, P, STAY } from '../data';
import type { Comm, LawId } from '../data';
import type { PromiseState } from '../state';
import { journal, rnd } from '../state';
import type { Game } from '../state';
import { BYPRODUCT, D, FIELDS, TECHS } from './data';
import type { Field, TechId } from './data';
import { doBury, extraCarCoal, rollUsefulCar, thawMult } from './cars';
import { delegateTick, overreachTick } from './delegate';
import { hotWaterCoal, hygieneTick } from './hygiene';
import { engineStall, knowledgeTick, leaveAtStop, stokingNow, strikeLine, strikeRuns } from './knowledge';
import { bedTick, domesticHeal } from './medbay';
import { domCard, living, personById, refreshSit, techMult, topSkill, variantMult } from './state';
import { addMaterials, greenhouseFood, offerRestores, payUpkeep, penaltyActive, rollBreakdown, runWorkshop, upkeepCoal } from './workshop';

// S1a 차례(turn.ts)에 S1c를 잇는 훅. turn.ts는 '// S1c 내정 훅' 줄에서 이 함수들만 부른다. dom이 없으면 모두 S1a 그대로 돌려준다.

// ---- 아끼기만 하는 기술(1.1, 사용자 답 대기) ----
/** 달리기 석탄을 줄이는 기술과 그 양. E1·E2는 PENDING_TECHS라 복원되지 않아 지금은 0이다. 답이 오면 그대로 켜진다. */
export const SAVING_EFFECTS: { id: TechId; runCoal?: number; foodMult?: number; haulMult?: number }[] = [
  { id: 'e1', runCoal: 0.5 },
  { id: 'e2', runCoal: 1 },
  { id: 'e4', runCoal: 1.5 },
  { id: 'm3', foodMult: 0.9 },
  { id: 'x1', haulMult: 1.1 },
];

export function techSavings(g: Game): { coal: number; foodMult: number; haulMult: number } {
  let coal = 0;
  let foodMult = 1;
  let haulMult = 1;
  for (const e of SAVING_EFFECTS) {
    const m = techMult(g, e.id);
    if (m <= 0) continue;
    coal += (e.runCoal ?? 0) * m;
    foodMult *= 1 - (1 - (e.foodMult ?? 1)) * m;
    haulMult *= 1 + ((e.haulMult ?? 1) - 1) * m;
  }
  coal += 0.3 * variantMult(g, 'e3', 'b');
  return { coal, foodMult, haulMult };
}

// ---- 출발 전 운영 / 정산의 석탄·식량(forecast) ----
export interface DomForecast { coal: number; food: number; foodMult: number }

/** forecast에 더할 몫. 더운물, 석탄 유지비, 붙인 칸, 고장 벌, 대체 화부, 느린 열차, 기술 절약, 온실·가족 특혜. */
export function domesticForecast(g: Game): DomForecast {
  const d = g.dom;
  if (!d) return { coal: 0, food: 0, foodMult: 1 };
  const save = techSavings(g);
  let coal = hotWaterCoal(g) + upkeepCoal(g) + extraCarCoal(g) - save.coal;
  if (penaltyActive(g, 'coal')) coal += 1;
  if (stokingNow(g) && techMult(g, 'e4') <= 0) coal += D.stokerCoal;
  if (!g.inStrike && topSkill(g, 'engine') === 1) coal += D.slowCoal;
  const grants = d.grants.filter(until => until >= g.seg).length * D.grantFood;
  return { coal, food: grants - greenhouseFood(g), foodMult: save.foodMult };
}

// ---- 출발(이동 단계) ----
/** 파업 문턱: 기관 매뉴얼이 있으면 −15에서 −30으로(8.7). */
export function domesticStrikeLine(g: Game, base: number): number {
  return g.dom ? strikeLine(g, base) : base;
}

/** 파업해도 대체 기관사와 화부로 열차가 가나(8.7). */
export function domesticStrikeRuns(g: Game): boolean {
  return !!g.dom && strikeRuns(g);
}

/** 출발할 때: 기관 숙련자가 없으면 선다(8.5), 고장 판정(6.5), 느린 열차의 압력 경고(8.7). 'end'면 판이 끝난다. */
export function domesticDepart(g: Game): 'end' | 'stall' | null {
  const d = g.dom;
  if (!d) return null;
  const stall = engineStall(g);
  if (stall) return stall;
  rollBreakdown(g);
  if (topSkill(g, 'engine') === 1 && rnd(g) < D.pressureChance && !g.cards.some(c => c.kind === 'dom:pressure')) domCard(g, { kind: 'dom:pressure' });
  return null;
}

// ---- 정차 ----
/** 정차 위험 곱(8.8 전문가 동행, W2, R1). */
export function domesticRiskMult(g: Game): { injury: number; death: number } {
  const d = g.dom;
  if (!d) return { injury: 1, death: 1 };
  const w2a = variantMult(g, 'w2', 'a');
  const w2b = variantMult(g, 'w2', 'b');
  let injury = (1 - 0.15 * w2a) * (1 - 0.1 * w2b);
  let death = injury * (1 - 0.15 * techMult(g, 'r1'));
  if (g.stop?.stay === 'long') { injury *= 1 - 0.1 * w2b; death *= 1 - 0.1 * w2b; }
  const esc = personById(g, d.escort);
  if (esc?.field === 'med') injury *= D.escortInjury;
  if (esc?.field === 'expedition') { injury *= D.escortRisk; death *= D.escortRisk; }
  return { injury, death };
}

/** 정차 산출 곱(고장 벌 −20%, '묻고 간다' ×0.85, 아끼는 기술 X1). */
export function domesticHaulMult(g: Game): number {
  const d = g.dom;
  if (!d) return 1;
  let m = techSavings(g).haulMult;
  if (penaltyActive(g, 'haul')) m *= 0.8;
  if (d.bury && g.stop?.stay === 'long' && g.stored > 0) m *= D.buryHaul;
  return m;
}

/** 전문가 데려가기(8.8): 정차 준비에서 한 명. 가르치는 사람과 쓰는 사람은 못 간다. */
export function escortOptions(g: Game): { id: string; label: string; last: boolean; why?: string }[] {
  if (!g.dom) return [];
  return living(g).filter(p => p.skill >= 1).map(p => ({
    id: p.id, label: `${p.name}(${fieldLabel(p.field)} ${['', '견습', '숙련', '장인'][p.skill]})`,
    last: living(g).filter(x => x.field === p.field && x.skill >= 1).length === 1,
    why: p.pupil ? '가르치는 중' : p.writing ? '매뉴얼을 쓰는 중' : p.exempt ? '위험 업무 면제' : undefined,
  }));
}

function fieldLabel(f: Field): string {
  return ({ engine: '기관', med: '의료', craft: '공작', radio: '통신', expedition: '원정' } as const)[f];
}

export function setEscort(g: Game, id: string | null): void {
  if (!g.dom) return;
  const opt = escortOptions(g).find(o => o.id === id);
  g.dom.escort = opt && !opt.why ? id : null;
}

/** 정차를 마친 뒤: 부산물, 설계도 조각, 코어, 쓸 만한 칸, 데려간 전문가의 위험, 묻기, X3. */
export function domesticStop(g: Game, passed: boolean, crewDead: number): string[] {
  const d = g.dom;
  if (!d || !g.stop) return [];
  const notes: string[] = [];
  const stop = g.stop;
  const esc = personById(g, d.escort);
  d.escort = null;
  if (passed) {
    d.bury = false;
    // 궤도 모터카(X3): 지나쳐도 '짧게'의 절반(석탄 1).
    const m = techMult(g, 'x3');
    if (m > 0 && stop.target) {
      g.coal -= 1;
      const amt = Math.round(P.haulTotal * STAY.short.mult * 0.5 * m * (stop.target === 'coal' || stop.target === 'food' ? 1 : 0));
      if (stop.target === 'coal') g.coal += amt; else if (stop.target === 'food') g.food += amt;
      if (amt > 0) notes.push(`궤도 모터카가 ${amt}을(를) 실어 왔다.`);
    }
    return notes;
  }
  const bp = BYPRODUCT[stop.place];
  if (bp) {
    const stay = stop.stay === 'short' ? 0.6 : stop.stay === 'long' ? 1.4 : 1;
    // 부산물은 체류와 S1a 산출 보정(아동 노동 등), 고장 벌, 묻기를 같이 받는다(5.2). 아끼는 기술(X1)은 빼고 본다.
    const lawHaul = (Object.keys(g.passed) as LawId[]).reduce((m, law) => m * (LAWS[law].res.haulMult ?? 1), 1);
    const mult = stay * lawHaul * (esc?.field === 'craft' ? D.escortMaterials : 1) * domesticHaulMult(g) / Math.max(0.01, techSavings(g).haulMult);
    const scrap = Math.round(bp.scrap * mult);
    const wood = Math.round(bp.wood * mult);
    addMaterials(g, scrap, wood);
    let p = bp.frag * (stop.target === 'secret' ? 2 : 1);
    if (esc?.field === 'radio' && stop.target === 'secret') p += D.escortFrag;
    if (rnd(g) < p) {
      const pool: Field[] = bp.branches === 'any' ? [...FIELDS] : bp.branches;
      const f = pool[Math.floor(rnd(g) * pool.length)];
      d.frags[f] += 1;
      notes.push(`${fieldLabel(f)} 설계도 조각을 찾았다.`);
    }
    if (bp.core > 0 && stop.stay === 'long' && rnd(g) < bp.core * (esc?.field === 'engine' ? D.escortCore : 1)) {
      d.cores += 1;
      notes.push('기계 코어 하나를 떼어 왔다.');
    }
    if (scrap + wood > 0) notes.push(`자재: 고철 ${scrap}, 목재 ${wood}.`);
  }
  // 데려간 전문가는 수색대원 한 명과 같은 위험(8.8): 대원이 죽은 정차에서 머릿수만큼의 몫.
  if (esc && crewDead > 0 && rnd(g) < crewDead / (stop.crewSize + 1)) {
    esc.alive = false;
    journal(g, `${esc.name}이(가) 돌아오지 못했다.`, 'bad');
  }
  doBury(g);
  rollUsefulCar(g);
  leaveAtStop(g);
  offerRestores(g);
  return notes;
}

// ---- 정산 ----
/** 의약품 소모 곱(M5). */
export function domesticMedMult(g: Game): number {
  return g.dom ? 1 - 0.15 * techMult(g, 'm5') : 1;
}

export function domesticHealRate(g: Game, heal: number): number {
  return domesticHeal(g, heal);
}

export function domesticThawMult(g: Game): number {
  return thawMult(g);
}

/** 정산 때 내정 한 구간: 공방장, 유지비, 공방, 지식, 위생, 침상, 복원 카드, 처지 보정, 기록. */
export function domesticSettle(g: Game, notes: string[]): void {
  const d = g.dom;
  if (!d) return;
  domesticPromiseMade(g);
  d.stats.hotCoal += hotWaterCoal(g);
  d.stats.techCoal += techSavings(g).coal;
  delegateTick(g);
  payUpkeep(g);
  const ws = runWorkshop(g);
  if (ws.did.length) notes.push(`공방: ${ws.did.join(', ')}.`);
  knowledgeTick(g);
  hygieneTick(g, notes);
  bedTick(g);
  overreachTick(g);
  if (!d.delegate.on || d.restoring) offerRestores(g);
  d.penalties = d.penalties.filter(p => p.until >= g.seg);
  d.grants = d.grants.filter(until => until > g.seg);
  for (const p of d.people) if (p.exempt && (p.lastDemand ?? 0) + D.demandEvery < g.seg) p.exempt = false;
  refreshSit(g);
}

/** S1c 협상 조건 둘의 이행(9.2). 돌려주는 값이 null이면 S1a 규칙대로 본다. */
export function domesticPromise(g: Game, c: Comm, p: PromiseState): boolean | null {
  const d = g.dom;
  if (!d) return null;
  if (p.cond.kind === 'apprentice_pick') {
    // 다음 기관 견습생을 기관실이 고른다: 약속한 뒤 다른 칸 기관 견습생을 붙이지 않았으면 지킨 것이다.
    const since = d.log.apprentices.filter(a => a.field === 'engine' && a.seg >= p.due - P.promiseSegments);
    d.enginePick = false;
    return !since.some(a => a.other);
  }
  if (p.cond.kind === 'research_pick') {
    // 기술·의무진이 고른 복원을 다음 회기까지 시작했나.
    const since = d.log.restores.filter(r => r.seg >= p.due - P.promiseSegments);
    const ok = since.some(r => TECHS[r.id].like.includes(c) || (TECHS[r.id].variants && Object.values(TECHS[r.id].variants!).some(v => v.like.includes(c))));
    d.researchPick = null;
    return ok;
  }
  return null;
}

/** 약속을 걸 때(협상 조건이 S1c 것이면): 선발권과 우선권을 켠다. promise가 생긴 뒤 처음 부르는 쪽에서 한 번. */
export function domesticPromiseMade(g: Game): void {
  const d = g.dom;
  if (!d) return;
  const e = g.comms.engine.promise;
  d.enginePick = e?.cond.kind === 'apprentice_pick';
  const m = g.comms.medtech.promise;
  if (m?.cond.kind === 'research_pick' && !d.researchPick) d.researchPick = researchChoice(g);
}

/** 기술·의무진이 고르는 다음 복원 대상: 그들이 원하는 것 중 조건이 맞는 것. */
export function researchChoice(g: Game): TechId | null {
  const d = g.dom;
  if (!d) return null;
  const ids = (Object.keys(TECHS) as TechId[]).filter(id => !d.techs[id] && TECHS[id].like.includes('medtech'));
  return ids.sort((a, b) => TECHS[a].tier - TECHS[b].tier)[0] ?? null;
}

/** 압력 경고(8.7, N13): 두 단계다. 첫 경고를 무시하면 다음이 마지막 경고, 그것도 무시하면 반드시 터진다.
 * 확률로 터지지 않는다(조짐은 약속). 김을 빼면 처음으로 돌아간다(석탄은 카드 효과로 뺀다). */
export function resolvePressure(g: Game, vent: boolean): boolean {
  const d = g.dom;
  if (!d) return false;
  if (vent) { d.pressureStage = 0; return false; }
  if ((d.pressureStage ?? 0) >= 1) {
    journal(g, '보일러가 터졌다. 기관차를 잃었다.', 'bad');
    return true;
  }
  d.pressureStage = 1;
  return false;
}
