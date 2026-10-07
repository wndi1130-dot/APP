import { COMMS } from '../data';
import type { Comm } from '../data';
import { clamp, journal, rnd, situation } from '../state';
import type { Game } from '../state';
import { D, TECHS, TECH_IDS } from './data';
import type { TechId } from './data';
import { domCard, living } from './state';
import type { DomPerson, DomState } from './state';
import { restoreCheck, startRestore, techSides } from './workshop';

// 간부에게 맡기기(6.4). S1c에서 새로 여는 것은 공방장 하나다(의무장·기관장·경비대장은 S1c 이후).
// 열리는 조건: 정차 6번을 지남 + 공방장이 사는 공동체(기술·의무진)가 호의 이상이고 적의가 없음. 인구 조건은 S1에서 뺐다(6.4 짚을 점).
// 간부가 맡지 못하는 것(6.4): 법·협상·강압, 칸 기능과 순서, 매뉴얼·대체 불가 요구·견습생, 얼굴을 보여 주는 결정.
// 그래서 공방장은 목표치, 우선순위, 복원 대상(3단계)만 정한다. 나머지 카드는 맡겨도 열차장에게 온다.

function dom(g: Game): DomState {
  if (!g.dom) throw new Error('S1c 내정이 꺼진 판이다');
  return g.dom;
}

export function workshopChief(g: Game): DomPerson | undefined {
  return living(g).find(p => p.role === '공방장') ?? [...living(g)].filter(p => p.field === 'craft').sort((a, b) => b.skill - a.skill)[0];
}

export function delegateStatus(g: Game): { ok: boolean; why?: string } {
  if (!g.dom) return { ok: false, why: 'S1c가 꺼진 판' };
  if (g.seg - 1 < D.delegateAfter) return { ok: false, why: `정차 ${D.delegateAfter}번을 지나면 맡길 수 있다` };
  const chief = workshopChief(g);
  if (!chief) return { ok: false, why: '공방을 맡을 사람이 없다' };
  const s = g.comms[chief.comm];
  if (s.rel < 15 || s.grudge > 0) return { ok: false, why: '공방장이 사는 칸이 열차장을 따르지 않는다' };
  return { ok: true };
}

/** 맡길 수 있는 범위(6.4): 1 목표치만, 2 우선순위까지, 3 복원 대상까지. */
export function delegateTier(g: Game): number {
  const chief = workshopChief(g);
  if (!chief) return 0;
  const t2 = TECH_IDS.some(id => TECHS[id].branch === 'craft' && TECHS[id].tier === 2 && g.dom?.techs[id]?.stage === 'done');
  const t3 = TECH_IDS.some(id => TECHS[id].branch === 'craft' && TECHS[id].tier === 3 && g.dom?.techs[id]?.stage === 'done');
  if (chief.skill >= 3 || t3) return 3;
  if (chief.skill >= 2 || t2) return 2;
  return 1;
}

export function setDelegate(g: Game, on: boolean, policy?: 'ours' | 'neutral'): boolean {
  const d = dom(g);
  if (on && !delegateStatus(g).ok) return false;
  d.delegate.on = on;
  if (policy) d.delegate.policy = policy;
  journal(g, on ? `공방을 공방장에게 맡겼다(${d.delegate.policy === 'ours' ? '우리 편 먼저' : '중립'}).` : '공방을 다시 열차장이 잡는다.');
  return true;
}

function friendly(g: Game): Comm[] {
  return COMMS.filter(c => g.comms[c].rel >= 15);
}

/** 공방장이 고를 복원 대상: 방침과 성향(6.4 표). */
export function chiefPick(g: Game): TechId | null {
  const d = dom(g);
  const chief = workshopChief(g);
  const trait = chief?.trait;
  const ready = TECH_IDS.filter(id => !restoreCheck(g, id).full);
  if (ready.length === 0) return null;
  const wants: Comm[] = trait === 'family' ? ['medtech'] : trait === 'ambition' ? ['guard']
    : d.delegate.policy === 'ours' ? friendly(g)
      : [[...COMMS].sort((a, b) => situation(g, a)[0] + situation(g, a)[1] - situation(g, b)[0] - situation(g, b)[1])[0]];
  const score = (id: TechId) => {
    const v = TECHS[id].variants ? 'a' : undefined;
    const s = techSides(id, v);
    return s.like.filter(c => wants.includes(c)).length * 2 - s.dislike.filter(c => wants.includes(c)).length - TECHS[id].tier * 0.1;
  };
  return [...ready].sort((a, b) => score(b) - score(a))[0];
}

/** 정산 때 공방장 한 구간(공방이 돌기 전). 탐욕이면 맡기기와 상관없이 부품을 빼돌린다(9.3). */
export function delegateTick(g: Game): void {
  const d = dom(g);
  const chief = workshopChief(g);
  if (chief?.trait === 'greed' && d.parts >= 1 && rnd(g) < 0.1) {
    d.parts -= 1;
    const caught = rnd(g) < (d.delegate.on ? 0.1 : 0.2);
    if (caught) journal(g, `공방 부품 상자가 장부보다 가볍다. ${chief.name}의 침상 밑에서 사치품이 나왔다.`, 'dark');
  }
  if (!d.delegate.on) return;
  if (!delegateStatus(g).ok) {
    d.delegate.on = false;
    journal(g, '공방장이 장부를 내려놓았다. 공방은 다시 열차장이 잡는다.', 'bad');
    return;
  }
  const tier = delegateTier(g);
  const coward = chief?.trait === 'fear';
  d.target = coward ? 8 : 5;
  if (tier >= 2) d.order = coward ? ['parts', 'restore', 'modify'] : ['restore', 'parts', 'modify'];
  if (tier >= 3 && !d.restoring) {
    const id = chiefPick(g);
    if (id) {
      const v = TECHS[id].variants ? (d.delegate.policy === 'ours' && friendly(g).includes('front') ? 'b' : 'a') : undefined;
      if (startRestore(g, id, 'full', v)) journal(g, `공방장이 ${TECHS[id].name}을(를) 골랐다.`);
    }
  }
  if (d.delegate.policy === 'ours') {
    const fr = friendly(g);
    for (const c of COMMS) g.comms[c].rel = clamp(g.comms[c].rel + (fr.includes(c) ? (g.comms[c].rel < 35 ? 1 : 0) : -1), -100, 100);
    if (g.seg % 3 === 0 && rnd(g) < 0.3) {
      for (const c of COMMS) if (!fr.includes(c)) g.comms[c].rel = clamp(g.comms[c].rel - 3, -100, 100);
      journal(g, '공방이 늘 같은 칸 일부터 한다는 말이 돈다. 공정성 시비가 붙었다.', 'bad');
    }
  }
}

/** 열차장이 침상에 있는 동안 야심 간부가 범위를 넘는다(6.4, 10장 12번). S1a 판엔 열차장 부상이 없어 captainInBed를 켜는 곳이 아직 없다. */
export function overreachTick(g: Game): void {
  const d = dom(g);
  const chief = workshopChief(g);
  if (!d.captainInBed || !d.delegate.on || chief?.trait !== 'ambition') return;
  if (g.cards.some(c => c.kind === 'dom:officer')) return;
  domCard(g, { kind: 'dom:officer', who: chief.id });
}
