import { COMM_NAME, LAWS, LOOT_NAME, P, STAY } from '../data';
import type { Comm, LawId } from '../data';
import type { PromiseState } from '../state';
import { COUNCIL_HOOKS } from '../politics';
import { addSecret, journal, lawActive, rnd } from '../state';
import type { Game } from '../state';
import { BYPRODUCT, D, FIELDS, TECHS } from './data';
import type { Field, TechId } from './data';
import { doBury, extraCarCoal, rollUsefulCar, thawMult } from './cars';
import { delegateTick, overreachTick } from './delegate';
import { hotWaterCoal, hygieneTick } from './hygiene';
import { lawTechCoal, lawTechFood, lawTechRes } from './lawtech';
import { elderTick } from './elder';
import { symbolTick } from './symbols';
import './pipe';
import { engineStall, knowledgeTick, leaveAtStop, stokingNow, strikeLine, strikeRuns } from './knowledge';
import { bedTick, domesticHeal } from './medbay';
import { refreshSit } from './sit';
import { domCard, living, personById, techMult, topSkill, variantMult } from './state';
import { addMaterials, greenhouseFood, offerRestores, payUpkeep, penaltyActive, restoreBlock, rollBreakdown, runWorkshop, upkeepCoal } from './workshop';

// S1a 차례(turn.ts)에 S1c를 잇는 훅. turn.ts는 '// S1c 내정 훅' 줄에서 이 함수들만 부른다. dom이 없으면 모두 S1a 그대로 돌려준다.

// ---- 출발 전 운영 / 정산의 석탄·식량(forecast) ----
export interface DomForecast { coal: number; food: number; foodMult: number }

/** forecast에 더할 몫. 더운물, 석탄 유지비, 붙인 칸, 고장 벌, 대체 화부, 느린 열차, 기술이 싸게 한 이상 법(7.3), 온실·가족 특혜. */
export function domesticForecast(g: Game): DomForecast {
  const d = g.dom;
  if (!d) return { coal: 0, food: 0, foodMult: 1 };
  let coal = hotWaterCoal(g) + upkeepCoal(g) + extraCarCoal(g) - lawTechCoal(g);
  if (penaltyActive(g, 'coal')) coal += 1;
  if (stokingNow(g) && techMult(g, 'e4') <= 0) coal += D.stokerCoal;
  if (!g.inStrike && topSkill(g, 'engine') === 1) coal += D.slowCoal;
  const grants = d.grants.filter(until => until >= g.seg).length * D.grantFood;
  return { coal, food: grants - greenhouseFood(g) - lawTechFood(g), foodMult: 1 };
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

/** 정차 산출 곱(고장 벌 −20%, '묻고 간다' ×0.85). */
export function domesticHaulMult(g: Game): number {
  const d = g.dom;
  if (!d) return 1;
  let m = 1;
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
    why: p.resting ? '쉬는 중' : p.pupil ? '가르치는 중' : p.writing ? '매뉴얼을 쓰는 중' : p.exempt ? '위험 업무 면제' : undefined,
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

// R2 가(감청): 회기를 열 때마다 비밀 하나를 들을 확률 +25%(7.3). 순찰 법의 귀환 검사와 따로 굴린다. J10 3번.
COUNCIL_HOOKS.push({
  open: g => {
    const m = variantMult(g, 'r2', 'a');
    if (m > 0 && rnd(g) < D.r2aSecret * m) {
      const secret = addSecret(g);
      journal(g, `무전 감청에서 ${COMM_NAME[secret.about]} 대표의 약점을 들었다.`, 'dark');
    }
  },
});

/** R2 나(열차 방송): 긴장이 오르는 구간엔 그 증가를 1 덜고, 공포는 구간마다 +1(7.3, meters가 부른다). J10 3번. */
export function domesticBroadcast(g: Game): { tensionCut: number; fear: number } {
  const m = variantMult(g, 'r2', 'b');
  return { tensionCut: D.r2bTension * m, fear: D.r2bFear * m };
}

/** 화장 땔감(4.1): S1c 판이면 시신 1구마다 목재 4가 있으면 목재로 태운다. 목재로 태운 구 수를 돌려준다(나머지는 석탄). J10 5번. */
export function domesticPyreWood(g: Game, n: number): number {
  const d = g.dom;
  if (!d || n <= 0) return 0;
  const bodies = Math.min(n, Math.floor(d.wood / D.pyreWood));
  d.wood -= bodies * D.pyreWood;
  return bodies;
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
    // 궤도 모터카(X3): 지나쳐도 '짧게'의 절반(석탄 1을 쓴다). 목표 자원이 무엇이든 그 자원으로 받는다(7.3, J10 4번).
    // 바꾸는 비율은 정차 산출과 같다: 사치품은 3분의 1, 상징물·비밀은 10에 하나(최대 2). 여기선 주사위를 굴리지 않는다.
    const m = techMult(g, 'x3');
    if (m > 0 && stop.target) {
      g.coal -= 1;
      const raw = P.haulTotal * STAY.short.mult * 0.5 * m;
      const t = stop.target;
      const amt = t === 'luxury' ? Math.round(raw / 3) : t === 'symbol' || t === 'secret' ? Math.min(2, Math.floor(raw / 10)) : Math.round(raw);
      if (t === 'coal') g.coal += amt;
      else if (t === 'food') g.food += amt;
      else if (t === 'medicine') g.med += amt;
      else if (t === 'luxury') g.lux += amt;
      else if (t === 'symbol') g.symbols += amt;
      else for (let i = 0; i < amt; i += 1) addSecret(g);
      if (amt > 0) notes.push(`궤도 모터카가 ${LOOT_NAME[t]} ${amt}을(를) 실어 왔다.`);
    }
    return notes;
  }
  const bp = BYPRODUCT[stop.place];
  if (bp) {
    const stay = stop.stay === 'short' ? 0.6 : stop.stay === 'long' ? 1.4 : 1;
    // 부산물은 체류와 S1a 산출 보정(아동 노동 등), 고장 벌, 묻기를 같이 받는다(5.2).
    const lawHaul = (Object.keys(g.passed) as LawId[]).reduce((m, law) => m * (lawTechRes(g, law).haulMult ?? 1), 1);
    const mult = stay * lawHaul * (esc?.field === 'craft' ? D.escortMaterials : 1) * domesticHaulMult(g);
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
  d.stats.techCoal += lawTechCoal(g);
  delegateTick(g);
  payUpkeep(g);
  const ws = runWorkshop(g);
  if (ws.did.length) notes.push(`공방: ${ws.did.join(', ')}.`);
  knowledgeTick(g);
  elderTick(g);
  hygieneTick(g, notes);
  symbolTick(g, notes);
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
    // 기술·의무진이 고른 복원(그들이 지정한 그 기술)을 다음 회기까지 시작했나. 다른 복원은 아무리 좋아하는 것이어도 치지 않는다(A01).
    // 지정한 기술이 없던 약속(후보가 없었거나 옛 저장)은 지킬 일이 없어 지킨 것으로 본다.
    const target = d.researchPick;
    d.researchPick = null;
    if (!target) return true;
    if (D.pickFulfil === 'complete') return d.techs[target]?.stage === 'done';
    return d.log.restores.some(r => r.id === target && r.seg >= p.due - P.promiseSegments);
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
  // 시작해도 지정은 약속을 판정할 때까지 남는다. 약속이 없어졌으면 낡은 지정도 같이 지운다.
  if (m?.cond.kind !== 'research_pick') d.researchPick = null;
  else if (!d.researchPick) d.researchPick = researchChoice(g);
}

/** 기술·의무진이 고르는 다음 복원 대상: 그들이 원하는 것 중 이 열차에서 실제로 시작할 수 있는 것(A02: 잠긴 R3나 선행·숙련이 모자란 것은 고르지 않는다). */
export function researchChoice(g: Game): TechId | null {
  const d = g.dom;
  if (!d) return null;
  const ids = (Object.keys(TECHS) as TechId[]).filter(id => TECHS[id].like.includes('medtech') && !restoreBlock(g, id));
  return ids.sort((a, b) => TECHS[a].tier - TECHS[b].tier)[0] ?? null;
}

/** 지금 걸린 「고른 복원」 약속: 의무진이 지정한 기술과 남은 구간. 화면 표시용이다. */
export function researchPromise(g: Game): { tech: TechId; left: number } | null {
  const p = g.comms.medtech.promise;
  const tech = g.dom?.researchPick;
  if (!p || p.cond.kind !== 'research_pick' || !tech) return null;
  return { tech, left: Math.max(0, p.due - g.seg) };
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
