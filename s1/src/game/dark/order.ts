import { COMM_NAME, COMMS } from '../data';
import type { Comm } from '../data';
import { onDeath } from '../death';
import { familyOf } from '../people';
import { offend } from '../politics';
import { clamp, CREW_EXTRAS, journal } from '../state';
import type { Game } from '../state';
import { B } from './data';
import { caseById, caught, coverUp, exposeOrderLines, openCase, settleTruth } from './cases';
import { cross, scene } from './chronicle';
import { newEmber } from './embers';
import {
  adults, alive, commOf, darkCard, dpick, dr, isRep, nameOf, rivalOf,
} from './state';
import type { Order, OrderExe, OrderMethod, OrderWhy } from './state';

// 4.6 암살 명령, 4.7 정차를 이용한 죽음. 메뉴가 아니라 상황 카드의 '조용히 처리한다'에서만 열린다(1.3).
// 판당 두 번. 대상은 그 카드에 나온 사람뿐이다. 성공해도 늘 수사가 열리고(사고로 꾸며도 사람이 죽었다, 4.6), 실행자는 평생 약점을 쥔다.

export const EXE_BONUS: Record<OrderExe, number> = { guard: 0.1, rival: 0.1, bound: -0.1 };
export const METHOD: Record<OrderMethod, { bonus: number; caught: number }> = {
  accident: { bonus: -0.1, caught: 0.2 }, stop: { bonus: 0.1, caught: 0.3 }, night: { bonus: 0, caught: 0.4 },
};

/** 이번 판에 아직 '조용히 처리한다'를 고를 수 있나 */
export function orderOpen(g: Game, target: string): boolean {
  const d = g.dark;
  return !!d && d.ordersUsed < B.orderCap && !d.order && target !== 'chief' && alive(g, target);
}

/** 대상이 쥔 역할과 막고 있는 일 한 줄(4.6, 숫자 없이) */
export function roleLine(g: Game, target: string, why: OrderWhy): string {
  const c = commOf(g, target);
  const name = nameOf(g, target);
  const craft = (g.dom?.people ?? []).find(p => p.alive && p.name === name && p.skill >= 3);
  const lose = craft ? ` ${craft.role}이(가) 죽으면 그 손을 아는 사람이 없다.` : '';
  if (why === 'hostile') return `${name}이(가) 있는 한 ${COMM_NAME[c]} 표는 움직이지 않는다.${lose}`;
  if (why === 'silence') return `${name}이(가) 입을 열면 열차장이 시킨 일이 드러난다.${lose}`;
  return `${name}이(가) 말하면 벌받은 사람이 죄가 없었다는 게 드러난다.${lose}`;
}

/** 대상의 경비(측근 0, 대표 −10, 경비대장 −20) */
function guardOf(g: Game, target: string): number {
  if (target === g.comms.guard.leader.personId) return 0.2;
  return isRep(g, target) ? 0.1 : 0;
}

/** 실행자 후보와 막힌 까닭 */
export function exeOptions(g: Game, target: string): Record<OrderExe, { id?: string; why?: string }> {
  const tc = commOf(g, target);
  const guardPool = adults(g, 'guard', { noRep: true, except: [target] });
  const rc = rivalOf(tc);
  const rivalPool = rc ? adults(g, rc, { noRep: true, except: [target] }) : [];
  const bound = COMMS.filter(c => c !== tc && (g.comms[c].debt || g.leashes.some(l => l.comm === c)))
    .map(c => g.comms[c].leader.personId).filter(id => id !== target && alive(g, id));
  return {
    guard: g.comms.guard.rel < 15 ? { why: '경비대가 열차장을 따르지 않는다' } : guardPool.length ? { id: guardPool[0].id } : { why: '보낼 사람이 없다' },
    rival: !rc ? { why: '원수가 없다' } : rivalPool.length ? { id: rivalPool[0].id } : { why: '보낼 사람이 없다' },
    bound: bound.length ? { id: bound[0] } : { why: '빚지거나 목줄이 걸린 사람이 없다' },
  };
}

export function successP(g: Game, o: Order): number {
  const exe = o.exe ? EXE_BONUS[o.exe] : 0;
  const m = o.method ? METHOD[o.method].bonus : 0;
  return clamp(B.orderBase + exe + m - guardOf(g, o.target), 0.15, 0.85);
}

/** 실행자의 대사(숫자 대신, 4.6) */
export function exeVoice(p: number): string {
  if (p >= 0.65) return '어렵지 않습니다.';
  if (p >= 0.45) return '해 보겠습니다.';
  return '장담은 못 합니다.';
}

/** '조용히 처리한다'를 골랐다: 명령을 세우고 실행자 카드. 선을 넘는다. */
export function startOrder(g: Game, target: string, why: OrderWhy): void {
  const d = g.dark!;
  d.ordersUsed += 1;
  d.stats.orders += 1;
  d.order = { target, why };
  cross(g, 'assn_ordered');
  darkCard(g, { kind: 'dark:order_exe', who: target, comm: commOf(g, target) }, false);
}

export function setExe(g: Game, exe: OrderExe): boolean {
  const d = g.dark!;
  const o = d.order;
  if (!o) return false;
  const opt = exeOptions(g, o.target)[exe];
  if (!opt.id) return false;
  o.exe = exe;
  o.exeId = opt.id;
  darkCard(g, { kind: 'dark:order_method', who: o.target, comm: commOf(g, o.target) }, false);
  return true;
}

/** 방법을 정한다. 사고·밤은 다음 이동에서, 정차는 다음에 작업조를 내보내는 정차에서 한다. */
export function setMethod(g: Game, method: OrderMethod): void {
  const o = g.dark!.order;
  if (!o) return;
  o.method = method;
  o.at = g.seg;
}

/** 명령을 거둔다(실행자·방법 카드에서). 이미 넘은 선은 남는다. 입을 막으려던 진실은 그대로 드러난다. */
export function dropOrder(g: Game): void {
  const ref = g.dark!.order?.ref;
  g.dark!.order = null;
  journal(g, '열차장이 말을 거뒀다. 실행자는 아무 말도 듣지 못한 척했다.', 'dark');
  if (ref) journal(g, settleTruth(g, ref, true), 'bad');
}

/** 이동이나 정차에서 명령이 실행된다. 결과 카드를 돌려준다. */
export function runOrder(g: Game, where: 'travel' | 'stop', witnesses: string[] = []): void {
  const d = g.dark!;
  const o = d.order;
  if (!o || !o.method || !o.exeId) return;
  if ((where === 'stop') !== (o.method === 'stop')) return;
  const name = nameOf(g, o.target);
  const exe = o.exeId;
  if (!alive(g, o.target) || !alive(g, exe)) {
    d.order = null;
    journal(g, `${name}을(를) 두고 한 말은 일이 되지 않았다.`, 'dark');
    // 입을 막으려던 사람이 이미 없으면 진실도 묻히고, 실행자가 없어 일이 안 됐으면 그 사람이 말한다.
    if (o.ref) { const line = settleTruth(g, o.ref, alive(g, o.target)); if (line) journal(g, line, 'bad'); }
    return;
  }
  // 정차 암살은 둘이 같은 작업조로 나가야 한다(J09 5). 아니면 명령은 다음 정차를 기다린다.
  if (where === 'stop' && !(witnesses.includes(name) && witnesses.includes(nameOf(g, exe)))) return;
  d.order = null;
  const tc = commOf(g, o.target);
  const ok = dr(g) < successP(g, o);
  d.executors.push({ id: exe, comm: commOf(g, exe), seg: g.seg });
  const fam = familyOf(g, name)?.others[0]?.name;
  if (ok) {
    d.stats.ordersOk += 1;
    d.harm += 1;
    if (o.ref) settleTruth(g, o.ref, false); // 입을 막았다: 그 진실은 묻힌다
    const rep = isRep(g, o.target);
    onDeath(g, tc, [name], 'chosen'); // 대표였으면 죽음 훅(hooks.ts)이 승계한다
    if (rep) {
      // 순교자 효과(4.6): 대상 칸 관계 −10, 열기 +1. 승계자는 대개 더 과격하다.
      const s = g.comms[tc];
      s.rel = clamp(s.rel - 10, -100, 100);
      s.fervor = Math.min(3, s.fervor + 1);
    }
    // 수사는 늘 열린다(4.6, J09 2번). 사고·정차로 꾸며 들키지 않으면 '사고라고 적혔다'로 시작하고 실행자 단서 없이 연다.
    // 들키면 실패 갈래처럼 그 자리에서 붙잡히고, 붙잡힌 실행자는 70%로 열차장을 댄다(J09 11번).
    const detected = dr(g) < METHOD[o.method].caught;
    const place = o.method === 'stop' ? '정차' : o.method === 'accident' ? '탄수차 승강대' : '통로';
    scene(g, 'order', 4, `${g.seg}구간, ${place}에서 ${COMM_NAME[tc]} ${name}의 죽음을 명령했다.`, [o.target], witnesses.length ? witnesses : undefined);
    const hidden = o.method !== 'night' && !detected;
    if (hidden) journal(g, o.method === 'stop' ? `${name}이(가) 정차에서 돌아오지 않았다. 사고라고 적혔다.` : `${name}이(가) ${place}에서 떨어졌다. 사고라고 적혔다.`, 'dark');
    const c = openCase(g, { kind: 'order', culprit: exe, victimComm: tc, victim: o.target, dead: true, clock: B.clockDeath, where: place, own: true });
    let line = '';
    if (detected) {
      caught(g, c);
      line = `${nameOf(g, exe)}이(가) 그 자리에서 붙잡혔다.`;
      if (dr(g) < B.orderNamesChief) line += ` ${exposeOrderLines(g, c).join(' ')}`;
    }
    darkCard(g, { kind: 'dark:order_done', who: o.target, comm: tc, n: c.id, text: hidden ? 'hidden' : line, ...(fam ? { vals: { kin: fam } } : {}) });
    return;
  }
  // 실패: 대상이 다치고 수사가 열린다. 실행자 50%로 붙잡히고, 붙잡히면 70%로 열차장을 댄다.
  g.injured += 1;
  d.harm += 1;
  const c = openCase(g, { kind: 'order', culprit: exe, victimComm: tc, victim: o.target, dead: false, clock: B.clockInjury, where: o.method === 'stop' ? '정차' : '통로', own: true });
  let line = `${name}이(가) 다쳤다. 살아남았다. 수사가 열린다.`;
  if (dr(g) < B.orderCaughtFail) {
    caught(g, c);
    line += ` ${nameOf(g, exe)}이(가) 그 자리에서 붙잡혔다.`;
    if (dr(g) < B.orderNamesChief) line += ` ${exposeOrderLines(g, c).join(' ')}`;
  }
  // 입을 막으려던 사람이 살아남았다. 그 사람이 말한다.
  if (o.ref) line += ` ${settleTruth(g, o.ref, true)}`;
  darkCard(g, { kind: 'dark:order_fail', who: o.target, comm: tc, n: c.id, text: line });
}

/** 성공한 뒤: 덮거나, 남에게 씌우거나, 수사하게 둔다. */
export function afterOrder(g: Game, caseId: number | undefined, how: 'cover' | 'frame' | 'let'): string {
  const c = caseById(g, caseId);
  if (!c) return '';
  if (how === 'cover') {
    coverUp(g, c);
    return '보일러 일지에 사고라고 적었다.';
  }
  if (how === 'frame') {
    // 헛단서를 심는다: 다른 용의자에게 단서 하나, 실행자의 불씨가 커진다(4.6).
    const others = c.sus.filter(s => !s.culprit && alive(g, s.id));
    if (!others.length) return '씌울 사람이 없었다.';
    const s = dpick(g, others);
    s.clues.push({ kind: 'item', truth: false, line: `${nameOf(g, s.id)}의 침상 밑에서 피 묻은 천이 나왔다.`, seg: g.seg });
    cross(g, 'frames');
    scene(g, 'frame', 3, `${g.seg}구간, ${nameOf(g, s.id)}에게 누명을 씌웠다.`, [s.id]);
    const exe = g.dark!.executors[g.dark!.executors.length - 1];
    if (exe) newEmber(g, exe.comm, 'chief', 'executor');
    return `${nameOf(g, s.id)}의 침상 밑에서 물건이 나왔다.`;
  }
  return '수사는 수사대로 간다.';
}

/** 실행자가 열차장을 흔든다(4.6, 6.3의 네 대응). 관계가 회의 이하로 떨어진 칸의 실행자가 정산마다 20%. */
export function executorTick(g: Game): void {
  const d = g.dark!;
  // 실행자가 죽으면 비밀은 그가 털어놓은 사람 하나에게 30%로 넘어간다.
  for (const x of [...d.executors]) {
    if (alive(g, x.id)) continue;
    d.executors = d.executors.filter(y => y !== x);
    const heirs = adults(g, x.comm, { noRep: true });
    if (heirs.length && dr(g) < 0.3) d.executors.push({ id: dpick(g, heirs).id, comm: x.comm, seg: g.seg });
  }
  if (g.cards.some(k => k.kind === 'dark:exec_threat')) return;
  for (const x of d.executors) {
    if (g.comms[x.comm].rel > -15 || dr(g) >= B.execBlackmail) continue;
    darkCard(g, { kind: 'dark:exec_threat', who: x.id, comm: x.comm });
    return;
  }
}

/** 실행자 협박의 대응(6.3) */
export function answerThreat(g: Game, id: string, how: 'give' | 'stand' | 'confess'): string {
  const d = g.dark!;
  const c = commOf(g, id);
  const name = nameOf(g, id);
  if (how === 'give') {
    g.lux = Math.max(0, g.lux - 3);
    g.comms[c].rel = clamp(g.comms[c].rel + 5, -100, 100);
    return `${name}이(가) 받아 갔다. 이번 한 번이라고 했다.`;
  }
  if (how === 'confess') {
    g.trust = clamp(g.trust - 10, 0, 100);
    d.executors = d.executors.filter(x => x.id !== id);
    for (const k of COMMS) if (g.comms[k].leader.trait === 'ideal') g.comms[k].rel = clamp(g.comms[k].rel + 5, -100, 100);
    scene(g, 'confess', 3, `${g.seg}구간, 열차장이 식당칸에서 자기가 시킨 죽음을 털어놓았다.`, []);
    return '식당칸이 조용해졌다. 털어놓은 말은 거둘 수 없다.';
  }
  // 버틴다: 겁 많은 사람이면 70%, 아니면 40%로 물러선다. 아니면 폭로(신임 −15, 무게만큼 적의).
  const fearful = COMMS.some(k => g.comms[k].leader.personId === id && g.comms[k].leader.trait === 'fear');
  if (dr(g) < (fearful ? 0.7 : 0.4)) return `${name}이(가) 눈을 피했다. 이번엔 물러섰다.`;
  g.trust = clamp(g.trust - 15, 0, 100);
  for (let i = 0; i < 3; i += 1) offend(g, c);
  d.executors = d.executors.filter(x => x.id !== id);
  scene(g, 'exposed', 4, `${g.seg}구간, ${name}이(가) 열차장이 시킨 일을 식당칸에서 말했다.`, [id]);
  return `${name}이(가) 식당칸에서 말했다. 열차장이 시켰다고.`;
}

// 정차로 정한 명령이면 실행자와 대상이 그 정차 작업조 명단에 붙는다(명단 화면에 이름이 보인다). 먼저 다녀온 정찰조는 다시 안 나간다.
CREW_EXTRAS.push(g => {
  const o = g.dark?.order;
  if (!o || o.method !== 'stop' || !o.exeId) return [];
  const scouts = g.stop?.scoutReport?.names ?? [];
  return [o.exeId, o.target].filter(id => alive(g, id)).map(id => nameOf(g, id)).filter(n => !scouts.includes(n));
});
