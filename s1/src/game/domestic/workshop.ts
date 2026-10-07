import { COMM_NAME, COMMS } from '../data';
import type { Comm } from '../data';
import { clamp, journal, lawActive, rnd } from '../state';
import type { Game } from '../state';
import { BRANCH_NAME, COMM_CARS, CAR_COMM, D, GREENHOUSE_SLOTS, TECHS, TECH_IDS, ZONE_WORK, prereqs, skillNeed, techPending } from './data';
import type { TechId, Upkeep, Variant } from './data';
import { domCard, refreshSit, techMult, techUsable, topSkill, zoneOf } from './state';
import type { DomState, ModKind, Task } from './state';

// 공방(6장): 작업량, 일 목록, 목표치와 우선순위, 복원(7장), 유지비(7.4), 고장(6.5), 개조(4.4).
// 공방은 정산 때 목표치와 우선순위대로 저절로 돈다. 플레이어는 바꾸고 싶을 때만 손댄다(3장).

function dom(g: Game): DomState {
  if (!g.dom) throw new Error('S1c 내정이 꺼진 판이다');
  return g.dom;
}

// ---- 작업량(6.1) ----
export function workPower(g: Game): number {
  const d = dom(g);
  const craft = topSkill(g, 'craft');
  let w = D.work * D.workSkill[craft] * ZONE_WORK[zoneOf(g, 'workshop')] * (1 + (D.w1Work - 1) * techMult(g, 'w1'));
  if (d.people.some(p => p.alive && !p.gone && p.field === 'craft' && p.pupil)) w *= D.teachWork;
  return w;
}

export function materials(g: Game): number {
  const d = dom(g);
  return d.scrap + d.wood;
}

/** 자재 상한(4.1): 창고칸마다 40. 창고를 온실로 내주면 0이다. */
export function storeCap(g: Game): number {
  const d = dom(g);
  const base = d.greenhouse === 'store' ? 0 : 1;
  return D.storeCap * (base + d.extraCars.filter(x => x === 'store').length);
}

// ---- 복원 조건(7.1, 7.2) ----
export interface RestoreCheck {
  /** 조각·사람·선행조건이 맞아 카드를 띄울 만한가(부품과 공방 자리는 빼고 본다) */
  offer: boolean;
  /** 완성판으로 시작할 수 없는 까닭 */
  full?: string;
  /** 결함판으로 시작할 수 없는 까닭(결함판이 없는 기술이면 '없다') */
  defect?: string;
  fragsNeed: number;
  defectNeed: number;
  parts: number;
  core: number;
  wood: number;
}

export function restoreCost(id: TechId): { parts: number; frags: number; defectFrags: number; core: number; wood: number; work: number } {
  const def = TECHS[id];
  if (def.tier === 0) return { parts: def.adapt?.parts ?? 0, frags: 0, defectFrags: 0, core: 0, wood: def.adapt?.wood ?? 0, work: D.adaptWork };
  return {
    parts: D.restoreParts[def.tier], frags: D.restoreFrags[def.tier], defectFrags: D.defectFrags[def.tier],
    core: def.tier === 3 ? 1 : 0, wood: 0, work: D.restoreWork[def.tier],
  };
}

export function restoreCheck(g: Game, id: TechId): RestoreCheck {
  const d = dom(g);
  const def = TECHS[id];
  const cost = restoreCost(id);
  const out: RestoreCheck = { offer: false, fragsNeed: cost.frags, defectNeed: cost.defectFrags, parts: cost.parts, core: cost.core, wood: cost.wood };
  const fail = (why: string) => { out.full = why; out.defect = why; return out; };
  if (d.techs[id]) return fail('이미 손댔다');
  if (techPending(id)) return fail('아직 열지 않는 기술');
  const pre = prereqs(id);
  if (pre.length > 0 && !pre.some(p => techUsable(g, p))) return fail(`${TECHS[pre[0]].name}부터`);
  if (topSkill(g, def.branch) < skillNeed(id)) return fail(`${['', '견습', '숙련', '장인'][skillNeed(id)]} 이상이 없다`);
  const frags = d.frags[def.branch];
  const hasDefect = cost.defectFrags < cost.frags;
  if (cost.core > d.cores) return fail('코어가 없다');
  out.offer = frags >= (hasDefect ? cost.defectFrags : cost.frags);
  const common = d.restoring ? '공방이 다른 복원 중' : d.parts < cost.parts ? '부품이 모자라다' : d.wood < cost.wood ? '목재가 모자라다' : undefined;
  out.full = frags < cost.frags ? '설계도 조각이 모자라다' : common;
  out.defect = !hasDefect ? '없다' : frags < cost.defectFrags ? '설계도 조각이 모자라다' : frags >= cost.frags ? '완성판으로 된다' : common;
  return out;
}

/** 결함판을 완성판으로 고칠 수 있나(남은 조각 + 작업 2). */
export function finishCheck(g: Game, id: TechId): string | undefined {
  const d = dom(g);
  const st = d.techs[id];
  if (!st || st.stage !== 'defective' || st.finishing) return '결함판이 아니다';
  const cost = restoreCost(id);
  if (d.frags[TECHS[id].branch] < cost.frags - cost.defectFrags) return '설계도 조각이 모자라다';
  if (d.restoring) return '공방이 다른 복원 중';
  return undefined;
}

/** 복원 시작. 원하는 쪽·싫어하는 쪽 관계는 시작할 때 바로 움직인다(결정 카드 규칙: 즉시 바뀌는 정치 변화). 취소해도 되돌리지 않는다(7.5).
 * relApplied: 카드 효과 줄이 이미 관계를 움직였다. */
export function startRestore(g: Game, id: TechId, mode: 'full' | 'defect', variant?: Variant, relApplied = false): boolean {
  const d = dom(g);
  const check = restoreCheck(g, id);
  if (mode === 'full' ? check.full : check.defect) return false;
  const def = TECHS[id];
  if (def.variants && !variant) return false;
  const cost = restoreCost(id);
  d.parts -= cost.parts;
  d.wood -= cost.wood;
  d.frags[def.branch] -= mode === 'full' ? cost.frags : cost.defectFrags;
  d.cores -= cost.core;
  d.techs[id] = { stage: 'restoring', defect: mode === 'defect', progress: 0, need: cost.work, ...(variant ? { variant } : {}) };
  d.restoring = id;
  d.log.restores.push({ seg: g.seg, id });
  if (!relApplied) {
    const sides = techRelSides(id, variant);
    for (const c of sides.like) g.comms[c].rel = clamp(g.comms[c].rel + D.techRel, -100, 100);
    for (const c of sides.dislike) g.comms[c].rel = clamp(g.comms[c].rel - D.techRel, -100, 100);
  }
  if (d.researchPick === id) d.researchPick = null;
  journal(g, `공방이 ${techTitle(g, id)} 복원을 시작했다${mode === 'defect' ? '(결함판)' : ''}.`);
  return true;
}

export function startFinish(g: Game, id: TechId): boolean {
  const d = dom(g);
  if (finishCheck(g, id)) return false;
  const cost = restoreCost(id);
  const st = d.techs[id]!;
  d.frags[TECHS[id].branch] -= cost.frags - cost.defectFrags;
  st.finishing = true;
  st.progress = 0;
  st.need = D.finishWork;
  d.restoring = id;
  journal(g, `${techTitle(g, id)}의 나머지 설계도를 맞추기 시작했다.`);
  return true;
}

/** 복원 취소: 쓴 부품은 돌아오지 않는다(7.5, 반응을 다시 굴리는 악용을 막는다). 조각은 돌아온다. */
export function cancelRestore(g: Game): void {
  const d = dom(g);
  const id = d.restoring;
  if (!id) return;
  const st = d.techs[id];
  const cost = restoreCost(id);
  if (st?.finishing) {
    d.frags[TECHS[id].branch] += cost.frags - cost.defectFrags;
    st.finishing = false;
    st.progress = 0;
  } else if (st) {
    d.frags[TECHS[id].branch] += st.defect ? cost.defectFrags : cost.frags;
    d.cores += cost.core;
    delete d.techs[id];
  }
  d.restoring = null;
  journal(g, `${TECHS[id].name} 복원을 멈췄다. 쓴 부품은 돌아오지 않는다.`, 'bad');
}

export function techTitle(g: Game, id: TechId): string {
  const def = TECHS[id];
  const v = g.dom?.techs[id]?.variant;
  return v && def.variants ? `${def.name}(${def.variants[v].name})` : def.name;
}

/** 원하는 쪽과 싫어하는 쪽(변형이면 그 변형의 것). */
export function techSides(id: TechId, variant?: Variant): { like: Comm[]; dislike: Comm[] } {
  const def = TECHS[id];
  if (def.variants && variant) return { like: def.variants[variant].like, dislike: def.variants[variant].dislike };
  return { like: def.like, dislike: def.dislike };
}

function completeRestore(g: Game, id: TechId): void {
  const d = dom(g);
  const st = d.techs[id]!;
  d.restoring = null;
  if (st.finishing) {
    st.finishing = false;
    st.stage = 'done';
    journal(g, `${techTitle(g, id)}이(가) 완성판이 됐다.`, 'good');
    refreshSit(g);
    return;
  }
  st.stage = st.defect ? 'defective' : 'done';
  const def = TECHS[id];
  const sides = techRelSides(id, st.variant);
  d.stats.restored += 1;
  if (def.tier === 3) d.stats.tier3 += 1;
  if (st.defect) d.stats.defective += 1;
  const who = [
    sides.like.length ? `${sides.like.map(c => COMM_NAME[c]).join('·')}이(가) 반긴다` : '',
    sides.dislike.length ? `${sides.dislike.map(c => COMM_NAME[c]).join('·')}은(는) 못마땅하다` : '',
  ].filter(Boolean).join(', ');
  journal(g, `${BRANCH_NAME[def.branch]}: ${techTitle(g, id)}을(를) ${st.defect ? '결함판으로 ' : ''}복원했다.${who ? ` ${who}.` : ''}`, 'good');
  if (id === 'm4') domCard(g, { kind: 'dom:give' });
  refreshSit(g);
}

/** 복원을 마칠 때 실제로 관계가 움직이는 쪽. 싫어하는 쪽이 없으면 아무도 움직이지 않는다(7.5, 기획 점검 03). */
export function techRelSides(id: TechId, variant?: Variant): { like: Comm[]; dislike: Comm[] } {
  const sides = techSides(id, variant);
  return sides.dislike.length === 0 ? { like: [], dislike: [] } : sides;
}

// ---- 개조(4.4, 6.2) ----
export interface JobCheck { ok: boolean; why?: string }

export function jobCheck(g: Game, kind: ModKind, car: string): JobCheck {
  const d = dom(g);
  if (d.job) return { ok: false, why: '개조 하나가 이미 줄에 있다' };
  if (kind === 'insulate') {
    if (!techUsable(g, 'e5')) return { ok: false, why: '단열 개조를 아직 모른다' };
    if (!CAR_COMM[car]) return { ok: false, why: '사람이 사는 칸만' };
    if (d.insulated.includes(car)) return { ok: false, why: '이미 단열했다' };
    if (d.wood < D.insulateWood) return { ok: false, why: `목재 ${D.insulateWood}이 든다` };
    return { ok: true };
  }
  if (kind === 'armor') {
    if (!techUsable(g, 'w3')) return { ok: false, why: '장갑 객차를 아직 모른다' };
    if (d.armored.includes(car)) return { ok: false, why: '이미 장갑을 댔다' };
    if (d.scrap < D.armorScrap) return { ok: false, why: `고철 ${D.armorScrap}이 든다` };
    return { ok: true };
  }
  if (!techUsable(g, 'm4')) return { ok: false, why: '온실칸을 아직 모른다' };
  if (d.greenhouse) return { ok: false, why: '온실은 하나다' };
  if (materials(g) < D.convertMaterials) return { ok: false, why: `자재 ${D.convertMaterials}이 든다` };
  return { ok: true };
}

export function startJob(g: Game, kind: ModKind, car: string): boolean {
  const d = dom(g);
  if (!jobCheck(g, kind, car).ok) return false;
  if (kind === 'insulate') d.wood -= D.insulateWood;
  else if (kind === 'armor') d.scrap -= D.armorScrap;
  else {
    // 칸 기능 바꾸기: 자재 20을 많은 쪽부터 쓴다.
    let left = D.convertMaterials;
    while (left > 0) {
      if (d.scrap >= d.wood) d.scrap -= 1; else d.wood -= 1;
      left -= 1;
    }
  }
  const need = kind === 'insulate' ? D.insulateWork : kind === 'armor' ? D.armorWork : D.convertWork;
  d.job = { kind, car, progress: 0, need };
  journal(g, `공방 개조 줄에 올렸다: ${jobTitle(kind, car)}.`);
  return true;
}

export function jobTitle(kind: ModKind, car: string): string {
  const name = CAR_NAME[car] ?? car;
  return kind === 'insulate' ? `${name} 단열` : kind === 'armor' ? `${name} 장갑` : `${name}을(를) 온실로`;
}

export const CAR_NAME: Record<string, string> = {
  tail1: '꼬리칸 1', tail2: '꼬리칸 2', tail3: '꼬리칸 3', cold: '냉동칸', store: '창고칸', medtech: '의무칸', dining: '식당칸',
  guard: '경비대칸', captain: '열차장실', front: '앞칸', workshop: '공방칸', engine: '기관실',
};

function completeJob(g: Game): void {
  const d = dom(g);
  const job = d.job!;
  d.job = null;
  if (job.kind === 'insulate') {
    d.insulated.push(job.car);
    const c = CAR_COMM[job.car];
    g.comms[c].base[0] += D.insulateWarm / COMM_CARS[c];
    journal(g, `${CAR_NAME[job.car]} 벽에 판자와 펠트를 댔다. ${COMM_NAME[c]} 온기가 오른다.`, 'good');
  } else if (job.kind === 'armor') {
    d.armored.push(job.car);
    journal(g, `${CAR_NAME[job.car]}에 철판을 댔다.`, 'good');
  } else {
    convertGreenhouse(g, job.car);
  }
  refreshSit(g);
}

/** 온실을 들인다(4.4). 내준 칸의 사람이나 물건이 밀려난다. */
function convertGreenhouse(g: Game, car: string): void {
  const d = dom(g);
  d.greenhouse = car;
  // 관계와 적의는 '칸을 내줄 곳' 카드가 고를 때 바로 움직였다(10장 8번). 여기선 처지만 바뀐다.
  if (car === 'front') {
    const s = g.comms.front;
    s.base[0] -= 15;
    s.base[2] += 20;
    journal(g, '앞칸에 유리 지붕을 얹었다. 앞칸 사람들이 다른 칸으로 흩어졌다.', 'dark');
  } else if (car === 'store') {
    const cap = storeCap(g);
    trimToCap(g, cap);
    journal(g, '창고칸을 비우고 온실로 바꿨다. 자재를 쌓을 곳이 없어졌다.', 'bad');
  } else if (car === 'cold') {
    if (g.stored > 0) {
      g.thrown += g.stored;
      if (lawActive(g, 'corpse_store')) {
        g.tension = clamp(g.tension + 5, 0, 100);
        g.trust = clamp(g.trust - 3, 0, 100);
        journal(g, `냉동칸 안치법을 지킬 수 없게 됐다. 시신 ${g.stored}구를 선로에 내놓았다.`, 'bad');
      }
      g.stored = 0;
    }
    journal(g, '냉동칸을 온실로 바꿨다.', 'good');
  } else {
    g.comms.tail.base[2] += 15;
    journal(g, '꼬리칸 하나를 비워 온실로 바꿨다. 남은 두 칸이 더 좁아졌다.', 'bad');
  }
}

export function greenhouseFood(g: Game): number {
  const d = g.dom;
  if (!d?.greenhouse) return 0;
  const slot = GREENHOUSE_SLOTS.find(s => s.car === d.greenhouse);
  return (slot?.food ?? 1.5) * techMult(g, 'm4');
}

function trimToCap(g: Game, cap: number): number {
  const d = dom(g);
  let over = d.scrap + d.wood - cap;
  if (over <= 0) return 0;
  const lost = over;
  while (over > 0) {
    if (d.scrap >= d.wood) d.scrap -= 1; else d.wood -= 1;
    over -= 1;
  }
  return lost;
}

/** 통로에 쌓기로 했으면 상한이 이만큼 는다(10장 10번 '통로에라도 쌓아라'). */
export const AISLE_CAP = 20;

/** 자재를 들인다. 상한에 처음 닿으면 '창고가 넘친다' 카드가 한 번 오고, 그 답이 뒤의 규칙이 된다(넘칠 때마다 일지 한 줄). */
export function addMaterials(g: Game, scrap: number, wood: number): { scrap: number; wood: number; lost: number } {
  const d = dom(g);
  d.scrap += scrap;
  d.wood += wood;
  const cap = storeCap(g) + (d.fullRule === 'aisle' ? AISLE_CAP : 0);
  if (d.fullRule === null) {
    if (d.scrap + d.wood > cap && !g.cards.some(c => c.kind === 'dom:full')) domCard(g, { kind: 'dom:full', n: d.scrap + d.wood - cap });
    // 카드를 고를 때까지는 버리지 않는다(통로에 임시로 둔다).
    return { scrap, wood, lost: 0 };
  }
  const lost = trimToCap(g, cap);
  if (lost > 0) journal(g, `창고가 넘쳐 자재 ${lost}을(를) ${d.fullRule === 'parts' ? '부품감만 남기고 ' : ''}선로 밖에 버렸다.`);
  return { scrap, wood, lost };
}

/** '창고가 넘친다' 카드의 답(10장 10번). 창고칸 창에서 다시 바꿀 수 있다. */
export function setFullRule(g: Game, rule: 'parts' | 'dump' | 'aisle'): void {
  const d = dom(g);
  const prev = d.fullRule;
  d.fullRule = rule;
  if (rule === 'parts' && prev !== 'parts') d.target = clamp(d.target + D.fullTarget, 0, D.targetMax);
  if (rule === 'aisle' && prev !== 'aisle') g.comms.tail.base[2] += D.fullCrowd;
  if (prev === 'aisle' && rule !== 'aisle') g.comms.tail.base[2] -= D.fullCrowd;
  trimToCap(g, storeCap(g) + (rule === 'aisle' ? AISLE_CAP : 0));
}

// ---- 공방 한 구간(6.3) ----
export function runWorkshop(g: Game): { used: number; did: string[] } {
  const d = dom(g);
  let w = workPower(g) - d.workDebt;
  d.workDebt = 0;
  if (w < 0) { d.workDebt = -w; w = 0; }
  const start = w;
  const did: string[] = [];
  for (const task of d.order) {
    if (w <= 0) break;
    if (task === 'parts') {
      let made = 0;
      while (w > 0 && d.parts < d.target && d.scrap >= D.partScrap && d.wood >= D.partWood) {
        const spend = Math.min(w, D.partWork - d.partWork);
        d.partWork += spend;
        w -= spend;
        if (d.partWork >= D.partWork - 1e-9) {
          d.partWork = 0;
          d.scrap -= D.partScrap;
          d.wood -= D.partWood;
          d.parts += 1;
          d.stats.partsMade += 1;
          made += 1;
        }
      }
      if (made > 0) did.push(`부품 ${made}`);
    } else if (task === 'restore' && d.restoring) {
      const id = d.restoring;
      const st = d.techs[id]!;
      const spend = Math.min(w, st.need - st.progress);
      st.progress += spend;
      w -= spend;
      if (st.progress >= st.need - 1e-9) { completeRestore(g, id); did.push(`${TECHS[id].name} 복원`); }
    } else if (task === 'modify' && d.job) {
      const job = d.job;
      const spend = Math.min(w, job.need - job.progress);
      job.progress += spend;
      w -= spend;
      if (job.progress >= job.need - 1e-9) { did.push(jobTitle(job.kind, job.car)); completeJob(g); }
    }
  }
  return { used: start - w, did };
}

/** 공방칸 명판에 띄울 상태(1.2, 11.1): 일하는 중, 쉬는 중, 재료 모자람. */
export function workshopState(g: Game): { now: string; mode: 'work' | 'idle' | 'short' } {
  const d = dom(g);
  for (const task of d.order) {
    if (task === 'parts' && d.parts < d.target) {
      if (d.scrap >= D.partScrap && d.wood >= D.partWood) return { now: '부품 만들기', mode: 'work' };
      if (!d.restoring && !d.job) return { now: '부품 재료가 모자라다', mode: 'short' };
    }
    if (task === 'restore' && d.restoring) return { now: `복원: ${TECHS[d.restoring].name}`, mode: 'work' };
    if (task === 'modify' && d.job) return { now: `개조: ${jobTitle(d.job.kind, d.job.car)}`, mode: 'work' };
  }
  return { now: '쉬는 중', mode: 'idle' };
}

export function setTarget(g: Game, v: number): void {
  dom(g).target = clamp(Math.round(v), 0, D.targetMax);
}

export function moveTask(g: Game, task: Task, step: -1 | 1): void {
  const d = dom(g);
  const i = d.order.indexOf(task);
  const j = i + step;
  if (i < 0 || j < 0 || j >= d.order.length) return;
  [d.order[i], d.order[j]] = [d.order[j], d.order[i]];
}

// ---- 유지비(7.4) ----
export function upkeepOf(g: Game, id: TechId): Upkeep {
  const def = TECHS[id];
  const v = g.dom?.techs[id]?.variant;
  return def.variants && v ? def.variants[v].upkeep : def.upkeep;
}

/** 지식이 끊겨 고장 난 기술은 유지비도 멈춘다(8.2). */
function running(g: Game, id: TechId): boolean {
  const st = g.dom?.techs[id];
  if (!st || st.off || !(st.stage === 'done' || st.stage === 'defective')) return false;
  return techMult(g, id) > 0 || !!st.starved;
}

/** 석탄이 아닌 유지비(부품·목재·고철)를 정산 때 낸다. 못 내면 그 기술은 결함판 효과로 돈다. 석탄 유지비는 forecast에 든다. */
export function payUpkeep(g: Game): TechId[] {
  const d = dom(g);
  const starved: TechId[] = [];
  for (const id of TECH_IDS) {
    const st = d.techs[id];
    if (!st) continue;
    st.starved = false;
    if (!running(g, id)) continue;
    const u = upkeepOf(g, id);
    const ok = d.parts >= (u.parts ?? 0) && d.wood >= (u.wood ?? 0) && d.scrap >= (u.scrap ?? 0);
    if (!ok) { st.starved = true; starved.push(id); continue; }
    d.parts -= u.parts ?? 0;
    d.wood -= u.wood ?? 0;
    d.scrap -= u.scrap ?? 0;
  }
  if (starved.length > 0 && !g.cards.some(c => c.kind === 'dom:short') && g.seg - (g.eventLog?.['dom:short']?.seg ?? -99) >= 3) {
    domCard(g, { kind: 'dom:short', text: starved.join(',') });
  }
  return starved;
}

/** 석탄으로 내는 유지비(온실 1, 냉동 보관 0.3). */
export function upkeepCoal(g: Game): number {
  let coal = 0;
  for (const id of TECH_IDS) if (running(g, id)) coal += upkeepOf(g, id).coal ?? 0;
  return coal;
}

// ---- 고장(6.5) ----
export function breakChance(g: Game): number {
  const d = dom(g);
  const defects = TECH_IDS.filter(id => d.techs[id]?.stage === 'defective').length;
  return D.breakChance + D.breakPerDefect * defects;
}

export const BREAK_LINES = ['보일러 밸브가 샜다', '연결기 핀이 부러졌다', '꼬리칸 증기관이 얼었다'] as const;

/** 고장(6.5): 부품이 2 이상이면 공방이 저절로 고치고 일지 한 줄. 모자라면 '부품이 모자란다' 카드. */
export function rollBreakdown(g: Game): void {
  if (rnd(g) >= breakChance(g)) return;
  const d = dom(g);
  d.stats.breakdowns += 1;
  const n = Math.floor(rnd(g) * 3);
  if (d.parts >= D.autoRepairParts) {
    d.parts -= D.repairParts;
    d.workDebt += D.repairWork;
    d.stats.repairs += 1;
    journal(g, `${BREAK_LINES[n]}. 공방이 부품 ${D.repairParts}로 막았다.`);
    return;
  }
  domCard(g, { kind: 'dom:short', n, text: 'break' });
}

/** 고장을 그냥 두고 달린다: 카드마다 다른 벌(6.5). */
export function breakPenalty(g: Game, n: number): void {
  const d = dom(g);
  if (n === 0) d.penalties.push({ kind: 'coal', until: g.seg + D.breakSegs - 1 });
  else if (n === 1) d.penalties.push({ kind: 'haul', until: g.seg + D.breakSegs });
  else g.comms.tail.heat = Math.max(0, g.comms.tail.heat - 1);
}

/** 다른 기술 하나를 세우고 그 부품을 돌린다(10장 3번 첫 답). 세울 것은 유지비가 가장 큰 기술. */
export function standDown(g: Game): TechId | null {
  const d = dom(g);
  const cands = TECH_IDS.filter(id => running(g, id) && (upkeepOf(g, id).parts ?? 0) > 0)
    .sort((a, b) => (upkeepOf(g, b).parts ?? 0) - (upkeepOf(g, a).parts ?? 0));
  const id = cands[0];
  if (!id) return null;
  d.techs[id]!.off = true;
  d.parts += 1;
  journal(g, `${techTitle(g, id)}을(를) 세웠다. 그 몫의 부품을 돌린다.`, 'bad');
  refreshSit(g);
  return id;
}

export function restartTech(g: Game, id: TechId): void {
  const st = dom(g).techs[id];
  if (st?.off) { st.off = false; refreshSit(g); }
}

export function penaltyActive(g: Game, kind: 'coal' | 'haul'): boolean {
  return (g.dom?.penalties ?? []).some(p => p.kind === kind && p.until >= g.seg);
}

/** '조각이 맞았다' 카드: 처음으로 복원 조건을 채운 기술마다 한 번(10장 1·2번). */
export function offerRestores(g: Game): void {
  const d = dom(g);
  for (const id of TECH_IDS) {
    if (d.offered.includes(id) || d.techs[id]) continue;
    const check = restoreCheck(g, id);
    if (!check.offer) continue;
    d.offered.push(id);
    domCard(g, { kind: 'dom:fit', text: id });
  }
}

export function commsOf(): readonly Comm[] {
  return COMMS;
}
