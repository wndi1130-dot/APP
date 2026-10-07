import { CONDITIONS, COMMS, COMM_NAME, LOOT_NAME, P, REP_AGE, TRAIT_BAN, TRAITS } from './data';
import type { Comm } from './data';
import { CARD_EXTENSIONS } from './cards';
import type { CardView, Choice, Eff } from './cards';
import { onDeath } from './death';
import { MOTION_SOURCES } from './motions';
import { hash, markSeen, pickFresh } from './omens';
import { offend } from './politics';
import { addCard, clamp, drawPerson, isGone, journal, PROFILES, storyOf, totalPop } from './state';
import type { Card, Game, HubPlan, HubState, MotionAgenda } from './state';

// 라이프치히 이탈(first_leg_story 7.7, 2026-10-07 사용자 결정). 불만이 높은 칸은 라이프치히에서 몫을 들고 내린다.
// 두 구간 전에 짐 싸는 징후와 창고 유출이 오고, 마지막 회기에 '우리 몫을 내놔라'가 오르고, 도착하면 칸마다
// 보낸다·설득한다·무력으로 막는다를 고른다. 새 계기 없이 관계·적의·결속도·신임을 쓴다. 숫자는 모두 제안이다.

export const HUB = Object.freeze({
  /** 관계 단계별 떠나려는 몫: 회의, 반대, 적대 */
  share: [0.1, 0.3, 0.6] as const,
  grudgeAdd: 0.2, cap: 0.8,
  /** 결속도가 이 이상이면 흔들림 없이 덩어리로 움직이고, 대표는 몫 0.3 이상이면 간다 */
  cohLump: 0.75, wobble: 0.1, leaderLump: 0.3,
  /** 두 구간 동안 구간마다 빠지는 식량·의약품: 재고 × 몫 × 인원 비율 × 이 값 */
  leak: 0.1,
  persuadeTrust: 60, persuadeQuarter: 75, persuadeGrudge: 1, persuadeCost: 5,
  forceGuardRel: 15, escape: 0.25, hurt: [0.05, 0.1] as const, dead: [0.01, 0.03] as const,
  forceRel: -20, forceTension: 15, forceWitness: -5, forceGuard: 5,
  /** 적대로 떠나거나 몫 요구가 통과 못 했을 때 더 들고 가는 것 */
  engineCoal: 5, tailFood: 0.15,
});

export function hubOf(g: Game): HubState {
  return (g.hub ??= { warned: [], stash: {}, agreed: [] });
}

/** 판과 칸마다 고정된 0~1 값. 징후 때와 도착 때 같은 판단이 나오게 한다. */
function u(g: Game, key: string): number {
  return hash(`${g.seed}|hub|${key}`) / 2 ** 32;
}

/** 떠나려는 몫(7.7 표). 관계 단계 + 적의, 결속이 낮으면 ±10%p 흔들린다. */
export function departShare(g: Game, c: Comm): number {
  const s = g.comms[c];
  let share = s.rel <= -70 ? HUB.share[2] : s.rel <= -40 ? HUB.share[1] : s.rel <= -15 ? HUB.share[0] : 0;
  if (s.grudge >= 2) share += HUB.grudgeAdd;
  share = Math.min(HUB.cap, share);
  if (share > 0 && s.coh < HUB.cohLump) share = clamp(share + (u(g, `w|${c}`) * 2 - 1) * HUB.wobble, 0, HUB.cap);
  return Math.round(share * 100) / 100;
}

export function leaverCount(g: Game, c: Comm, share = departShare(g, c)): number {
  if (share <= 0) return 0;
  const pop = g.comms[c].pop;
  return Math.max(0, Math.min(pop - 1, Math.max(1, Math.round(share * pop))));
}

export function leaderGoes(g: Game, c: Comm, share: number): boolean {
  if (share <= 0) return false;
  return g.comms[c].coh >= HUB.cohLump ? share >= HUB.leaderLump : u(g, `l|${c}`) < share;
}

const hostile = (g: Game, c: Comm) => g.comms[c].rel <= -70;

// ---- 짐 싸는 징후(7.7 표). 같은 뜻을 문장만 바꿔 되풀이한다. 고정 해석: 누군가 내릴 채비를 한다. ----
const PACK_ANY = [
  '{칸} 사람들이 담요를 끈으로 묶어 침상 밑에 밀어 넣었다.',
  '{칸}에서 밤새 바스락거렸다. 아침에 보니 다들 장화를 신은 채 잤다.',
  '{칸} 아이들이 \'큰 역\'에 가면 다른 기차를 탄다고 말하고 다닌다.',
  '{이름}이 창밖 선로를 오래 본다. 무엇을 셈하는 얼굴이다.',
];
const PACK_STORE = '창고 장부와 자루 수가 안 맞는다. 모자란 건 하필 오래 가는 것들이다.';
const PACK_COMM: Record<Comm, string> = {
  tail: '꼬리칸 사람들이 빵을 반만 먹고 반은 품에 넣는다.',
  engine: '기관실 공구함 자물쇠에 새 긁힌 자국이 있다.',
  guard: '경비대가 교대 때 총을 반납하지 않고 그대로 들고 간다.',
  medtech: '의무칸 약상자 하나가 붕대로 다시 싸여 있다. 누가 쌌는지 아무도 모른다.',
  front: '앞칸 사람들이 트렁크를 닦는다. 이 열차에선 한 번도 안 열던 트렁크다.',
};
export const PACK_MEANING = '누군가 내릴 채비를 한다.';

function someone(g: Game, c: Comm): string {
  const pool = PROFILES.filter(p => p.community === c && !isGone(g, p.name) && g.comms[c].leader.name !== p.name);
  return pool.length > 0 ? pool[Math.floor(u(g, `n|${c}|${g.seg}`) * pool.length)].name : COMM_NAME[c];
}

function fill(g: Game, line: string, c: Comm): string {
  return line.replace('{칸}', COMM_NAME[c]).replace('{이름}', someone(g, c));
}

/** 징후 문장: 몫이 있으면 하나, 반대·적대면 하나 더, 적대면 물자 문장이 꼭 든다. 한 판에 같은 문장은 한 번. */
export function packLines(g: Game, c: Comm, share: number): string[] {
  const seen = g.linesSeen ?? [];
  const out: string[] = [];
  const take = (pool: string[], salt: string) => {
    const t = pickFresh(pool.filter(x => !out.includes(x)), seen, `${g.seed}|${salt}`);
    out.push(t);
    markSeen(g, t);
  };
  take([PACK_COMM[c], ...PACK_ANY], `pack1|${c}`);
  if (share >= HUB.share[1]) take(PACK_ANY, `pack2|${c}`);
  if (hostile(g, c)) take([PACK_STORE], `pack3|${c}`);
  return out.map(line => fill(g, line, c));
}

/** 라이프치히 두 구간 전과 한 구간 전, 구간이 시작될 때(nextSegment). 아직 징후를 안 받은 칸에 쪽지를 놓는다. */
export function hubOmenTick(g: Game): void {
  if (g.seg !== P.segments - 1 && g.seg !== P.segments) return;
  const hub = hubOf(g);
  for (const c of COMMS) {
    const share = departShare(g, c);
    if (share <= 0 || hub.warned.includes(c)) continue;
    hub.warned.push(c);
    const lines = packLines(g, c, share);
    addCard(g, { kind: 'hub_omen', comm: c, text: lines.join('\n') });
    journal(g, `${lines[0]} ${COMM_NAME[c]}이(가) 라이프치히에서 내리려 한다.`, 'dark');
    // 다른 지도자도 움직인다: 경비대장은 막자고 먼저 말하고, 남을 칸은 빌 자리를 셈한다(7.7).
    const guard = g.comms.guard;
    if (c !== 'guard' && guard.rel >= HUB.forceGuardRel && (guard.leader.trait === 'ambition' || guard.leader.trait === 'greed')) {
      journal(g, `경비대장 ${guard.leader.name}: "${COMM_NAME[c]} 문을 막으면 된다. 말만 하라."`, 'dark');
    }
    const eyeing = COMMS.filter(o => o !== c && departShare(g, o) <= 0).sort((a, b) => g.comms[b].base[2] - g.comms[a].base[2])[0];
    if (eyeing && eyeing !== 'front') journal(g, `${COMM_NAME[eyeing]} 대표 ${g.comms[eyeing].leader.name}이(가) ${COMM_NAME[c]} 자리를 두고 벌써 말을 꺼낸다.`);
  }
}

/** 징후를 받은 칸은 두 구간 동안 식량·의약품을 조금씩 미리 뺀다(장부 불일치). 정산에서 부른다. */
export function hubLeakTick(g: Game, notes: string[]): void {
  if (g.seg < P.segments - 1 || g.seg > P.segments) return;
  const hub = hubOf(g);
  const total = Math.max(1, totalPop(g));
  let any = false;
  for (const c of hub.warned) {
    const share = departShare(g, c);
    if (share <= 0) continue;
    const k = share * (g.comms[c].pop / total) * HUB.leak;
    const food = Math.max(0, Math.round(g.food * k * 10) / 10);
    const med = Math.max(0, Math.round(g.med * k * 10) / 10);
    if (food + med <= 0) continue;
    g.food -= food;
    g.med -= med;
    const st = (hub.stash[c] ??= { food: 0, med: 0 });
    st.food += food;
    st.med += med;
    any = true;
  }
  if (any) {
    notes.push(PACK_STORE);
    journal(g, PACK_STORE, 'dark');
  }
}

// ---- 마지막 회기의 '우리 몫을 내놔라' ----
MOTION_SOURCES.push(g => {
  if (g.seg !== P.segments || g.council?.emergency) return [];
  const agreed = g.hub?.agreed ?? [];
  return COMMS.filter(c => departShare(g, c) > 0 && !agreed.includes(c))
    .map((c): MotionAgenda => ({ kind: 'motion', motion: 'share', subject: c, by: c }));
});

/** 마지막 회기에 몫 요구가 올라왔는데 통과 못 했다(부결이거나 다른 안건을 골랐다). */
function refused(g: Game, c: Comm): boolean {
  const offered = (g.council?.options ?? []).some(o => o.kind === 'motion' && o.motion === 'share' && o.subject === c);
  return offered && !hubOf(g).agreed.includes(c);
}

// ---- 들고 가는 것 ----
export interface Carry { food: number; coal: number; med: number; lux: number; symbols: number }

/** n명이 들고 가는 것. 1인당 몫에서 미리 빼 둔 것을 뺀다. 적대이거나 몫 요구가 통과 못 했으면 칸이 맡던 것을 더 가져간다. */
export function carryOf(g: Game, c: Comm, n: number, opts: { extra?: boolean; half?: boolean; stash?: boolean } = {}): Carry {
  const total = Math.max(1, totalPop(g));
  const f = (n / total) * (opts.half ? 0.5 : 1);
  const st = opts.stash ? hubOf(g).stash[c] : undefined;
  const out: Carry = {
    food: Math.max(0, Math.round(g.food * f - (st?.food ?? 0))),
    coal: Math.max(0, Math.round(g.coal * f)),
    med: Math.max(0, Math.round(g.med * f - (st?.med ?? 0))),
    lux: 0, symbols: 0,
  };
  if (opts.extra) {
    if (c === 'guard') out.symbols = Math.ceil(g.symbols / 2);
    if (c === 'engine') out.coal += HUB.engineCoal;
    if (c === 'medtech') out.med += Math.floor(Math.max(0, g.med - out.med) / 2);
    if (c === 'front') out.lux = Math.ceil(g.lux / 2);
    if (c === 'tail') out.food += Math.round(Math.max(0, g.food - out.food) * HUB.tailFood);
  }
  out.food = Math.min(out.food, Math.max(0, Math.floor(g.food)));
  out.coal = Math.min(out.coal, Math.max(0, Math.floor(g.coal)));
  out.med = Math.min(out.med, Math.max(0, Math.floor(g.med)));
  out.lux = Math.min(out.lux, g.lux);
  out.symbols = Math.min(out.symbols, g.symbols);
  return out;
}

function carryEffs(k: Carry): Eff[] {
  const out: Eff[] = [];
  if (k.food) out.push({ t: 'food', v: -k.food });
  if (k.coal) out.push({ t: 'coal', v: -k.coal });
  if (k.med) out.push({ t: 'med', v: -k.med });
  if (k.lux) out.push({ t: 'lux', v: -k.lux });
  return out;
}

function carryText(k: Carry): string {
  const parts = [
    k.food ? `식량 ${k.food}` : '', k.coal ? `석탄 ${k.coal}` : '', k.med ? `의약품 ${k.med}` : '',
    k.lux ? `사치품 ${k.lux}` : '', k.symbols ? `${LOOT_NAME.symbol} ${k.symbols}` : '',
  ].filter(Boolean);
  return parts.length > 0 ? parts.join(', ') : '빈손';
}

// ---- 도착 ----
function planFor(g: Game, c: Comm): HubPlan {
  const share = departShare(g, c);
  const n = leaverCount(g, c, share);
  const goes = n > 0 && leaderGoes(g, c, share);
  const names: string[] = goes ? [g.comms[c].leader.name] : [];
  // 결정하는 순간에 얼굴을 보여 준다(결정 사항). 셋까지.
  while (n > 0 && names.length < Math.min(3, n)) {
    const p = drawPerson(g, c, [16, 80]);
    if (names.includes(p.name) || g.comms[c].leader.name === p.name) break;
    names.push(p.name);
  }
  return { share, n, names, leaderGoes: goes };
}

/** 대표가 떠나면 앓는 대표의 측근 뽑기처럼 그 자리에서 잇는다(7.7 S1a 맞춤: 기다리는 구간 없음). */
function succeed(g: Game, c: Comm, gone: string[]): string {
  const s = g.comms[c];
  const p = drawPerson(g, c, REP_AGE[c]);
  const ban = TRAIT_BAN[c];
  const traits = TRAITS.filter(t => t !== ban && t !== s.leader.trait);
  const trait = traits[Math.floor(u(g, `t|${c}`) * traits.length)] ?? 'ambition';
  if (gone.includes(p.name)) return s.leader.name;
  s.leader = { personId: p.id, name: p.name, age: p.age, trait, traitShown: 0 };
  s.sick = undefined;
  s.debt = false;
  s.promise = null;
  return p.name;
}

/** 사람과 상징물을 내리고 대표를 잇는다. 식량·석탄·의약품·사치품은 부른 쪽이 이미 뺐다. */
function leave(g: Game, c: Comm, n: number, k: Carry, names: string[], leaderLeaves: boolean): string[] {
  const lines: string[] = [];
  const old = g.comms[c].leader.name;
  g.symbols = Math.max(0, g.symbols - k.symbols);
  for (const name of names) if (!isGone(g, name)) (g.left ??= []).push(name);
  lines.push(`${COMM_NAME[c]} ${n}명이 내렸다. ${carryText(k)}을(를) 들고 갔다.`);
  if (leaderLeaves) {
    const next = succeed(g, c, names);
    lines.push(`대표 ${old}도 갔다. ${next}이(가) ${COMM_NAME[c]} 대표 자리를 이었다.`);
  }
  return lines;
}

/** 24구간 정산 뒤 '도착'. 떠나려는 칸마다 고르기 카드를 놓고, 마지막에 결과 카드를 놓는다. */
export function arriveHub(g: Game): void {
  const hub = hubOf(g);
  const story = storyOf(g);
  story.stage = 6;
  const split = (story.flags.hub_split ??= {});
  hub.plan = {};
  hub.lines = [];
  let anyLeaving = false;
  for (const c of COMMS) {
    const plan = planFor(g, c);
    hub.plan[c] = plan;
    if (plan.n <= 0) { split[c] = 'stayed'; continue; }
    anyLeaving = true;
    if (hub.agreed.includes(c)) {
      // 몫 요구가 통과한 칸은 고르기 없이 1인당 몫만 들고 평화롭게 내린다.
      const k = carryOf(g, c, plan.n, { stash: true });
      for (const e of carryEffs(k)) applyRes(g, e);
      g.comms[c].pop = Math.max(1, g.comms[c].pop - plan.n);
      hub.lines.push(...leave(g, c, plan.n, k, plan.names, plan.leaderGoes));
      split[c] = 'left';
      delete hub.stash[c];
    } else {
      addCard(g, { kind: 'hub_split', comm: c, n: plan.n });
    }
  }
  if (!anyLeaving) {
    // 모든 칸이 중립 이상이면 이 장면이 빈다. 개인 몇이 내리겠다는 작은 장면으로 대신한다(7.7 기본값).
    const c = [...COMMS].sort((a, b) => g.comms[a].rel - g.comms[b].rel)[0];
    const few = PROFILES.filter(p => p.community === c && !isGone(g, p.name) && g.comms[c].leader.name !== p.name)
      .sort((a, b) => hash(`${g.seed}|few|${a.id}`) - hash(`${g.seed}|few|${b.id}`)).slice(0, 2).map(p => p.name);
    if (few.length > 0) addCard(g, { kind: 'hub_few', comm: c, who: few.join(',') });
  }
  story.flags.signal_heard = true;
  addCard(g, { kind: 'hub_end' });
  journal(g, '라이프치히 중앙역. 지붕 아래 다른 열차들이 승강장마다 자리를 잡았다. 막다른 역이라 열차를 돌려 나가야 한다.');
}

function applyRes(g: Game, e: Eff): void {
  if (e.t === 'food') g.food += e.v;
  else if (e.t === 'coal') g.coal += e.v;
  else if (e.t === 'med') g.med = Math.max(0, g.med + e.v);
  else if (e.t === 'lux') g.lux = Math.max(0, g.lux + e.v);
}

// ---- 허브 고르기 ----
export function persuadeStatus(g: Game, c: Comm): string | undefined {
  if (g.trust < HUB.persuadeTrust) return `신임이 ${HUB.persuadeTrust} 아래다`;
  if (g.comms[c].grudge > HUB.persuadeGrudge) return `${COMM_NAME[c]}은(는) 열차장 말을 듣지 않는다`;
  return undefined;
}

export function forceStatus(g: Game, c: Comm, n: number): string | undefined {
  if (c === 'guard') return '경비대가 떠나려는 쪽이다';
  if ((hubOf(g).plan?.guard?.n ?? 0) > 0 && storyOf(g).flags.hub_split?.guard !== 'persuaded') return '경비대가 떠나려는 쪽이다';
  if (g.comms.guard.rel < HUB.forceGuardRel) return '경비대가 따르지 않는다';
  if (g.comms.guard.pop < n / 4) return '경비대 수가 모자라다';
  return undefined;
}

/** 설득하면 떠날 사람: 신임 60~74면 절반, 75 이상이면 4분의 1. */
export function persuadedCount(g: Game, n: number): number {
  return Math.round(n * (g.trust >= HUB.persuadeQuarter ? 0.25 : 0.5));
}

function promiseFor(c: Comm): string {
  const pool = CONDITIONS[c];
  return (pool.find(x => x.kind === 'ration') ?? pool.find(x => x.kind === 'relocate') ?? pool[0]).label;
}

function forceRange(n: number): { hurt: [number, number]; dead: [number, number] } {
  return {
    hurt: [Math.max(1, Math.round(n * HUB.hurt[0])), Math.max(1, Math.round(n * HUB.hurt[1]))],
    dead: [Math.round(n * HUB.dead[0]), Math.round(n * HUB.dead[1])],
  };
}

function splitView(g: Game, card: Card): CardView {
  const c = card.comm ?? 'tail';
  const plan = hubOf(g).plan?.[c] ?? { share: 0, n: card.n ?? 0, names: [], leaderGoes: false };
  const n = plan.n;
  const extra = hostile(g, c) || refused(g, c);
  const send = carryOf(g, c, n, { extra, stash: true });
  const pn = persuadedCount(g, n);
  const pk = carryOf(g, c, pn);
  const esc = Math.round(n * HUB.escape);
  const fk = carryOf(g, c, esc, { half: true });
  const fr = forceRange(n);
  const others = COMMS.filter(o => o !== c && o !== 'guard');
  const leader = g.comms[c].leader;
  const choices: Choice[] = [
    {
      label: '보낸다', say: '가라. 몫은 들고 가라.',
      effs: [{ t: 'pop', c, v: -n }, ...carryEffs(send)],
      extra: send.symbols ? [`${LOOT_NAME.symbol} −${send.symbols}`] : undefined,
      special: 'hub_send', log: `라이프치히: ${COMM_NAME[c]} ${n}명을 보냈다.`,
    },
    {
      label: '설득한다', say: '내리지 마라. 약속하마. 이 열차에 자리가 있다.',
      effs: [{ t: 'trust', v: -HUB.persuadeCost }, ...(pn > 0 ? [{ t: 'pop', c, v: -pn } as Eff] : []), ...carryEffs(pk)],
      extra: [`약속: ${promiseFor(c)}`],
      special: 'hub_persuade', disabled: persuadeStatus(g, c), log: `라이프치히: ${COMM_NAME[c]}을(를) 설득했다.`,
    },
    {
      label: '무력으로 막는다', say: '경비대, 문을 막아라. 아무도 못 내린다.',
      effs: [
        { t: 'rel', c, v: HUB.forceRel }, { t: 'grudge', c }, { t: 'fervor', c, v: 1 }, { t: 'tension', v: HUB.forceTension },
        ...others.map(o => ({ t: 'rel', c: o, v: HUB.forceWitness }) as Eff), { t: 'rel', c: 'guard', v: HUB.forceGuard },
        ...(esc > 0 ? [{ t: 'pop', c, v: -esc } as Eff] : []), ...carryEffs(fk),
      ],
      extra: [`다침 ${fr.hurt[0]}~${fr.hurt[1]}명`, ...(fr.dead[1] > 0 ? [`죽음 ${fr.dead[0]}~${fr.dead[1]}명`] : []), '경비대 다침 1~2명'],
      special: 'hub_force', disabled: forceStatus(g, c, n), witness: true, log: `라이프치히: ${COMM_NAME[c]}을(를) 무력으로 막았다.`,
    },
  ];
  // 고를 수 없어도 자원 때문은 아니다. 조건이 안 되는 고르기는 회색과 이유로 보인다.
  const body = [
    `${n}명이 짐을 들고 승강장에 섰다.${plan.leaderGoes ? ` 대표 ${leader.name}이(가) 맨 앞에 있다.` : ''}`,
    extra ? `1인당 몫에 더해 칸이 맡던 것까지 들고 가려 한다(${carryText(send)}).` : `1인당 몫(${carryText(send)})을 들고 가겠다고 한다.`,
  ].join(' ');
  return {
    title: `${COMM_NAME[c]}이(가) 내리려 한다`,
    speaker: { name: plan.leaderGoes ? leader.name : (plan.names[0] ?? leader.name), role: COMM_NAME[c], comm: c },
    body, choices, required: true, focus: c, faces: plan.names,
  };
}

function hubView(g: Game, card: Card): CardView | null {
  const c = card.comm ?? 'tail';
  switch (card.kind) {
    case 'hub_omen':
      return {
        title: '짐 싸는 기척', body: `${card.text ?? ''}\n${PACK_MEANING} ${COMM_NAME[c]}이(가) 라이프치히에서 내리려 한다. 두 구간 안에 관계를 한 단계라도 올리면 떠날 사람이 준다.`,
        required: true, focus: c, choices: [{ label: '알았다', effs: [] }],
      };
    case 'hub_split':
      return splitView(g, card);
    case 'hub_few': {
      const who = (card.who ?? '').split(',').filter(Boolean);
      return {
        title: '다른 열차로 옮기겠다는 사람', speaker: { name: who[0] ?? COMM_NAME[c], role: COMM_NAME[c], comm: c }, focus: c, required: true, faces: who,
        body: `${who.join('와(과) ')}이(가) 다른 승강장의 열차로 옮기겠다고 한다. 칸 전체가 아니라 몇 사람의 결정이다.`,
        choices: [
          { label: '보내 준다', say: '원한다면 막지 않겠다. 잘 가라.', effs: [{ t: 'pop', c, v: -who.length }], special: 'hub_few_go' },
          { label: '붙잡는다', say: '여기가 너희 열차다. 같이 가자.', effs: [{ t: 'rel', c, v: 2 }], special: 'hub_few_stay' },
        ],
      };
    }
    case 'hub_end': {
      const lines = hubOf(g).lines ?? [];
      return {
        title: '라이프치히 중앙역',
        body: [
          ...(lines.length > 0 ? lines : ['아무도 내리지 않았다.']),
          '다른 열차의 무전실에서 같은 문장이 되풀이된다. 북쪽, 좌표 하나, 그리고 처음으로 \'우리\'라는 말.',
        ].join('\n'),
        required: true, choices: [{ label: '열차를 돌린다', effs: [] }],
      };
    }
    default:
      return null;
  }
}

function hubChoose(g: Game, card: Card, choice: Choice): void {
  const c = card.comm ?? 'tail';
  const hub = hubOf(g);
  const split = (storyOf(g).flags.hub_split ??= {});
  const plan = hub.plan?.[c];
  const lines = (hub.lines ??= []);
  if (card.kind === 'hub_end') {
    // 허브 결과를 일지에 남긴다(판 끝 일대기가 읽는다).
    for (const line of lines) journal(g, line, 'dark');
    journal(g, '다른 열차의 무전실에서 북쪽의 같은 방송이 되풀이된다. 처음으로 \'우리\'라고 말하는 목소리다.');
    return;
  }
  switch (choice.special) {
    case 'hub_send': {
      if (!plan) return;
      // 사람과 자원은 선택지 효과로 이미 뺐다. 상징물(경비대 몫)은 효과에 없어서 여기서 뺀다.
      const sent: Carry = { food: 0, coal: 0, med: 0, lux: 0, symbols: hostile(g, c) || refused(g, c) ? carryOf(g, c, 0, { extra: true }).symbols : 0 };
      for (const e of choice.effs) if (e.t === 'food' || e.t === 'coal' || e.t === 'med' || e.t === 'lux') sent[e.t] = -e.v;
      lines.push(...leave(g, c, plan.n, sent, plan.names, plan.leaderGoes));
      if (hostile(g, c)) lines.push(`${COMM_NAME[c]}의 떠난 무리는 열차를 원망하며 갔다. 떨어져 나간 집단으로 남는다.`);
      split[c] = 'left';
      delete hub.stash[c];
      break;
    }
    case 'hub_persuade': {
      if (!plan) return;
      const pn = persuadedCount(g, plan.n);
      const st = hub.stash[c];
      if (st) { g.food += st.food; g.med += st.med; delete hub.stash[c]; }
      const promise = promiseFor(c);
      lines.push(`${COMM_NAME[c]}을(를) 설득했다. 약속: ${promise}.${pn > 0 ? ` 그래도 ${pn}명은 내렸다.` : ' 아무도 내리지 않았다.'}`);
      for (const name of plan.names.filter(x => x !== g.comms[c].leader.name).slice(0, pn)) (g.left ??= []).push(name);
      journal(g, `${COMM_NAME[c]}에 약속했다: ${promise}. 이 약속은 라이프치히 너머에서 확인된다.`, 'deal');
      split[c] = 'persuaded';
      break;
    }
    case 'hub_force': {
      if (!plan) return;
      const st = hub.stash[c];
      if (st) { g.food += st.food; g.med += st.med; delete hub.stash[c]; }
      const fr = forceRange(plan.n);
      const roll = (key: string, [lo, hi]: [number, number]) => lo + Math.floor(u(g, key) * (hi - lo + 1));
      const hurt = roll(`fh|${c}`, fr.hurt);
      const dead = roll(`fd|${c}`, fr.dead);
      const guardHurt = 1 + (u(g, `fg|${c}`) < 0.5 ? 1 : 0);
      g.injured += hurt + guardHurt;
      const esc = Math.round(plan.n * HUB.escape);
      const names: string[] = [];
      for (let i = 0; i < dead; i += 1) {
        const p = drawPerson(g, c, [16, 80]);
        if (p.name === g.comms[c].leader.name || names.includes(p.name)) continue;
        names.push(p.name);
      }
      if (names.length > 0) onDeath(g, c, names, 'chosen', true);
      lines.push(`경비대가 ${COMM_NAME[c]} 문을 막았다. ${esc > 0 ? `${esc}명이 빠져나갔다. ` : ''}${hurt}명이 다쳤${names.length > 0 ? `고 ${names.join(', ')}이(가) 죽었다` : '다'}. 경비대도 ${guardHurt}명이 다쳤다.`);
      split[c] = 'forced';
      break;
    }
    case 'hub_few_go':
      for (const name of (card.who ?? '').split(',').filter(Boolean)) (g.left ??= []).push(name);
      lines.push(`${(card.who ?? '').split(',').join(', ')}이(가) 다른 열차로 옮겨 갔다.`);
      break;
    case 'hub_few_stay':
      lines.push(`${(card.who ?? '').split(',').join(', ')}이(가) 남기로 했다.`);
      break;
    default:
      break;
  }
}

CARD_EXTENSIONS.push({ view: hubView, choose: hubChoose });
