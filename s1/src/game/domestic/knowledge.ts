import { COMMS } from '../data';
import type { Comm } from '../data';
import { clamp, drawPerson, journal, lawActive, rnd } from '../state';
import type { Game } from '../state';
import { D, FIELDS, TECHS, TECH_IDS } from './data';
import type { Field } from './data';
import { domCard, knowers, living, techUsable, topSkill } from './state';
import type { DomPerson, DomState } from './state';

// 지식인(8장): 견습생, 매뉴얼, 카운트다운과 좌초, 대체 불가 인력의 요구, 파업과의 연결.

function dom(g: Game): DomState {
  if (!g.dom) throw new Error('S1c 내정이 꺼진 판이다');
  return g.dom;
}

/** 그 분야를 '쥔' 공동체: 가장 높은 사람의 공동체(8.3 길드). */
export function fieldOwner(g: Game, f: Field): Comm {
  const top = [...knowers(g, f)].sort((a, b) => b.skill - a.skill)[0];
  return top?.comm ?? ({ engine: 'engine', med: 'medtech', craft: 'medtech', radio: 'guard', expedition: 'guard' } as const)[f];
}

/** 가르칠 수 있는 사람: 견습 이상이고 지금 가르치거나 쓰지 않는다. 없으면 매뉴얼. */
export function freeTeacher(g: Game, f: Field): DomPerson | 'manual' | null {
  const t = [...knowers(g, f)].filter(p => !p.pupil && !(p.writing ?? 0) && !p.learn && !p.resting).sort((a, b) => b.skill - a.skill)[0];
  if (t) return t;
  return dom(g).manuals[f] && !living(g).some(p => p.field === f && p.learn?.by === 'manual') ? 'manual' : null;
}

export function distributeBlocked(g: Game, f: Field): string | undefined {
  if (lawActive(g, 'tech_control')) return '기술 통제법이 있다';
  if (f === 'engine' && dom(g).enginePick) return '기관실이 선발권을 쥐었다';
  return undefined;
}

/** 견습생을 붙인다(8.3). from: 'guild'는 그 분야를 쥔 공동체, 'other'는 다른 공동체(분산). */
export function attachApprentice(g: Game, f: Field, from: 'guild' | 'other', quiet = false): DomPerson | null {
  const d = dom(g);
  const teacher = freeTeacher(g, f);
  if (!teacher) return null;
  if (from === 'other' && distributeBlocked(g, f)) return null;
  const owner = teacher === 'manual' ? fieldOwner(g, f) : teacher.comm;
  const comm: Comm = from === 'guild' ? owner : owner === 'tail' ? 'medtech' : 'tail';
  const prof = drawPerson(g, comm, [16, 40]);
  const cap = teacher === 'manual' ? 2 : teacher.skill;
  const person: DomPerson = {
    id: `sp${d.nextPersonId}`, name: prof.name, age: prof.age, comm, field: f, skill: 0, role: '견습생', alive: true,
    learn: { by: teacher === 'manual' ? 'manual' : teacher.id, left: teacher === 'manual' ? D.readSegs[0] : D.learnSegs[0], cap },
  };
  d.nextPersonId += 1;
  d.people.push(person);
  if (teacher !== 'manual') teacher.pupil = person.id;
  // quiet: 카드 효과 줄이 관계를 이미 움직였거나(견습생 후보), 법이 자동으로 배정했다(법 20).
  if (!quiet) g.comms[owner].rel = clamp(g.comms[owner].rel + (from === 'guild' ? D.guildRel : D.distributeRel), -100, 100);
  if (from === 'other' && f === 'engine' && g.comms.engine.rel <= -15) g.comms.engine.fervor = Math.min(3, g.comms.engine.fervor + 1);
  if (comm !== owner) d.flags.otherApprentice = true;
  d.log.apprentices.push({ seg: g.seg, field: f, other: comm !== owner });
  journal(g, `${person.name}(${comm === owner ? '같은 칸' : '다른 칸'})이(가) ${teacher === 'manual' ? '매뉴얼로' : `${teacher.name}에게`} ${FIELD_LABEL[f]}을(를) 배우기 시작했다.`);
  return person;
}

const FIELD_LABEL: Record<Field, string> = { engine: '기관', med: '의술', craft: '공작', radio: '무전', expedition: '원정' };

/** 매뉴얼을 써 줄 사람과 거절 까닭(8.4). */
export function manualWriter(g: Game, f: Field): { who?: DomPerson; why?: string } {
  const d = dom(g);
  if (d.manuals[f]) return { why: '이미 있다' };
  const who = [...knowers(g, f)].filter(p => p.skill >= 2 && !(p.writing ?? 0) && !p.resting).sort((a, b) => b.skill - a.skill)[0];
  if (!who) return { why: '숙련 이상이 없다' };
  if (f === 'engine' && g.comms.engine.rel <= -15) return { who, why: '기관실이 거절한다' };
  if (g.comms[who.comm].rel <= -40) return { who, why: '그 칸이 거절한다' };
  return { who };
}

export function startManual(g: Game, f: Field, segs: number = D.writeSegs): boolean {
  const { who, why } = manualWriter(g, f);
  if (!who || why) return false;
  who.writing = segs;
  journal(g, `${who.name}이(가) ${FIELD_LABEL[f]} 매뉴얼을 쓰기 시작했다.`);
  return true;
}

/** 분야를 아는 사람이 한 명이고, 그 분야에 기대는 기술이 있으면 대체 불가다(8.6). */
export function irreplaceable(g: Game, f: Field): DomPerson | null {
  const k = knowers(g, f);
  if (k.length !== 1) return null;
  if (!TECH_IDS.some(id => TECHS[id].branch === f && TECHS[id].tier > 0 && techUsable(g, id))) return null;
  return k[0];
}

function teacherOk(g: Game, p: DomPerson): boolean {
  const l = p.learn!;
  if (l.by === 'manual') return !!g.dom?.manuals[p.field];
  const t = g.dom?.people.find(x => x.id === l.by);
  return !!t && t.alive && !t.gone;
}

/** 멈춘 견습생을 이어 가르칠 스승(지금 단계보다 높고 손이 빈 사람), 없으면 매뉴얼(숙련까지). */
function resumeTeacher(g: Game, p: DomPerson): string | null {
  const t = knowers(g, p.field).filter(x => x.id !== p.id && x.skill > p.skill && !x.pupil && !(x.writing ?? 0) && !x.learn)
    .sort((a, b) => b.skill - a.skill)[0];
  if (t) return t.id;
  const reading = living(g).some(x => x.id !== p.id && x.field === p.field && x.learn?.by === 'manual');
  return g.dom?.manuals[p.field] && p.skill < 2 && !reading ? 'manual' : null;
}

/** 정산 때 지식 쪽 한 구간. */
export function knowledgeTick(g: Game): void {
  const d = dom(g);
  // 견습과 매뉴얼 읽기
  for (const p of living(g)) {
    const l = p.learn;
    if (!l) continue;
    if (!l.by || !teacherOk(g, p)) {
      // 스승이 견습 도중 죽거나 떠나면 그 단계에 멈춘다. 쌓은 구간은 남고, 다른 스승이나 매뉴얼이 있으면 이어서 배운다(8.3).
      if (l.by) journal(g, `${p.name}의 스승이 자리에 없다. 견습이 ${['처음', '견습', '숙련'][p.skill]} 단계에서 멈췄다.`, 'bad');
      l.by = resumeTeacher(g, p) ?? '';
      if (!l.by) continue;
      if (l.by !== 'manual') { const t = d.people.find(x => x.id === l.by); if (t) { t.pupil = p.id; l.cap = t.skill; } } else l.cap = 2;
      journal(g, `${p.name}이(가) ${l.by === 'manual' ? '매뉴얼로' : '다른 스승에게'} 견습을 잇는다.`);
    }
    // 스승이 쉬는 동안은 배우는 것도 멈춘다(8.9).
    if (l.by !== 'manual' && d.people.find(x => x.id === l.by)?.resting) continue;
    l.left -= 1;
    if (l.left > 0) continue;
    const teacher = l.by === 'manual' ? null : d.people.find(x => x.id === l.by);
    p.skill += 1;
    if (p.skill === 1) d.stats.apprentices += 1;
    journal(g, `${p.name}이(가) ${FIELD_LABEL[p.field]} ${['', '견습', '숙련', '장인'][p.skill]}이 됐다.`, 'good');
    if (p.skill < l.cap) {
      l.left = l.by === 'manual' ? D.readSegs[p.skill] : D.learnSegs[p.skill];
    } else {
      delete p.learn;
      if (teacher) delete teacher.pupil;
      p.role = p.skill >= 2 ? '숙련공' : '견습';
    }
  }
  // 매뉴얼 쓰기
  for (const p of living(g)) {
    if (!p.writing || p.resting) continue;
    p.writing -= 1;
    if (p.writing > 0) continue;
    delete p.writing;
    d.manuals[p.field] = true;
    d.stats.manuals += 1;
    if (p.field === 'engine') g.comms.engine.rel = clamp(g.comms.engine.rel + D.engineManualRel, -100, 100);
    journal(g, `${p.name}이(가) ${FIELD_LABEL[p.field]} 매뉴얼을 다 썼다.`, 'good');
  }
  // 카운트다운(8.5)
  for (const f of FIELDS) {
    if (topSkill(g, f) > 0 || d.manuals[f]) { delete d.countdown[f]; continue; }
    if (d.countdown[f] === undefined) {
      // 마지막 한 사람: 고를 게 없어 일지 한 줄(10장). 견습시킬 길이 있으면 견습생 후보가 이어서 온다.
      d.countdown[f] = D.countdown;
      journal(g, `${FIELD_LABEL[f]}을(를) 아는 마지막 사람을 잃었다. ${D.countdown}구간 뒤 그 분야 기계가 멎는다.`, 'bad');
      if (freeTeacher(g, f)) domCard(g, { kind: 'dom:pupil', text: f });
    } else if (d.countdown[f]! > 0) {
      d.countdown[f]! -= 1;
      if (d.countdown[f] === 0) journal(g, `${FIELD_LABEL[f]}을(를) 아는 사람이 없다. 그 분야 기계가 하나씩 멎었다.`, 'bad');
    }
  }
  // 기관 매뉴얼이 사라진다(8.4)
  if (d.manuals.engine && g.comms.engine.rel <= -40 && rnd(g) < D.manualLoss) {
    d.manuals.engine = false;
    domCard(g, { kind: 'dom:box' });
  }
  // 대체 불가 인력의 요구(8.6)
  for (const f of FIELDS) {
    const p = irreplaceable(g, f);
    if (!p || p.pupil) continue;
    p.lastDemand ??= g.seg;
    if (g.seg - p.lastDemand < D.demandEvery) continue;
    p.lastDemand = g.seg;
    d.flags.irreplaceable = true;
    d.stats.demands += 1;
    domCard(g, { kind: 'dom:demand', who: p.id, n: d.stats.demands % 3 });
  }
  // 법 20: 분야마다 견습생 하나는 다른 칸에서(자동 배정)
  if (lawActive(g, 'apprentice_duty')) {
    for (const f of FIELDS) {
      const learning = living(g).filter(p => p.field === f && p.learn);
      if (learning.some(p => p.comm !== fieldOwner(g, f))) continue;
      if (freeTeacher(g, f)) attachApprentice(g, f, 'other', true);
    }
  }
}

/** 파업 문턱(8.7): 기관 매뉴얼이 있으면 −15에서 −30으로. */
export function strikeLine(g: Game, base: number): number {
  return g.dom?.manuals.engine ? D.strikeRelManual : base;
}

/** 기관실 밖의 기관 숙련 이상(대체 기관사). */
export function substituteDriver(g: Game): DomPerson | undefined {
  return knowers(g, 'engine').find(p => p.comm !== 'engine' && p.skill >= 2);
}

/** 파업해도 열차가 가나(8.7): 대체 기관사가 있고 삽을 쥘 공동체를 정해 두었으면 간다. */
export function strikeRuns(g: Game): boolean {
  const d = g.dom;
  if (!d) return false;
  if (!substituteDriver(g)) return false;
  if (!d.stoker) {
    if (!g.cards.some(c => c.kind === 'dom:stoker')) domCard(g, { kind: 'dom:stoker' });
    return false;
  }
  const s = g.comms[d.stoker];
  s.base[3] += D.stokerExposure;
  g.comms.engine.rel = clamp(g.comms.engine.rel + D.stokerEngineRel, -100, 100);
  stokingSeg(g);
  journal(g, `기관실이 불을 껐지만 대체 기관사와 ${d.stoker === 'tail' ? '꼬리칸' : '다른 칸'} 화부로 열차가 간다.`, 'dark');
  return true;
}

function stokingSeg(g: Game): void {
  if (g.dom) g.dom.stokingAt = g.seg;
}
export function stokingNow(g: Game): boolean {
  return g.dom?.stokingAt === g.seg;
}

/** 기관 숙련자가 없으면 열차가 선다(8.5). 매뉴얼이 있으면 누군가 읽을 때까지 서고, 없으면 끝이다. */
export function engineStall(g: Game): 'end' | 'stall' | null {
  const d = g.dom;
  if (!d) return null;
  if (topSkill(g, 'engine') > 0) { d.stalled = false; return null; }
  if (!d.manuals.engine) return 'end';
  if (!living(g).some(p => p.field === 'engine' && p.learn)) attachApprentice(g, 'engine', 'guild', true);
  d.stalled = true;
  return 'stall';
}

/** 정차 때 떠날 수 있는 사람이 떠난다(8.6 거절 뒤). */
export function leaveAtStop(g: Game): void {
  for (const p of living(g)) {
    if (!p.leaveRisk) continue;
    if (rnd(g) < D.leaveChance) {
      p.gone = true;
      g.comms[p.comm].pop = Math.max(1, g.comms[p.comm].pop - 1);
      journal(g, `${p.name}이(가) 정차한 역에 남았다. 짐이 하나 줄었다.`, 'bad');
    }
    p.leaveRisk = false;
  }
}

export function commList(): readonly Comm[] { return COMMS; }

/** 현황판의 '견습생 붙이기' 단추: 견습생 후보 서류를 만든다(11.4). */
export function requestApprentice(g: Game, f: Field): boolean {
  if (!freeTeacher(g, f) || g.cards.some(c => c.kind === 'dom:pupil' && c.text === f)) return false;
  domCard(g, { kind: 'dom:pupil', text: f, ...(g.budget ? { ask: true } : {}) }); // ask: 구간 예산이 미루지 않는다(budget.ts)
  return true;
}

/** 현황판의 '매뉴얼 쓰게 하기' 단추: 매뉴얼 요청 서류를 만든다(10장 5번). */
export function requestManual(g: Game, f: Field): boolean {
  const { who } = manualWriter(g, f);
  if (!who || g.cards.some(c => c.kind === 'dom:manual')) return false;
  domCard(g, { kind: 'dom:manual', text: f, who: who.id, ...(g.budget ? { ask: true } : {}) });
  return true;
}