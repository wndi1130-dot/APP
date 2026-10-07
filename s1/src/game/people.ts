import { COMMS, COMM_NAME, TRAIT_BAN, TRAITS } from './data';
import type { Comm, Trait } from './data';
import { addCard, drawPerson, isGone, journal, lawActive, PROFILES, situation } from './state';
import type { Game, Leader, Profile } from './state';
import familiesJson from '../../generated/profile_families.json';

// 사람의 무게(2026-10-07 사용자가 고른 묶음, politics_detail 6장). 카드 구성과 숫자는 제안이다.
// A1 유품과 남은 사람, A2 대표의 몸, A3 내리겠다는 노인, A4 출산. 이 카드가 뜬 구간 다음엔 이동 사건을 뽑지 않는다(6.0).

interface Family { id: string; community: Comm; parents: string[]; children: string[] }
export const FAMILIES = (familiesJson as unknown as { families: Family[] }).families;

const byId = (id: string): Profile | undefined => PROFILES.find(p => p.id === id);
const byName = (name: string): Profile | undefined => PROFILES.find(p => p.name === name);

export const PEOPLE_KINDS = ['orphan', 'keepsake', 'rep_sick', 'elder', 'birth', 'naming'] as const;

/** 사람 카드가 이번 구간이나 바로 앞 정산에 왔으면 이동 사건을 쉰다. 카드 수를 늘리지 않으려는 것이다. */
export function peopleCardRecent(g: Game): boolean {
  return (g.peopleSeg ?? -99) >= g.seg - 1 || g.cards.some(c => (PEOPLE_KINDS as readonly string[]).includes(c.kind));
}

function addPeopleCard(g: Game, card: Parameters<typeof addCard>[1]): void {
  addCard(g, card);
  g.peopleSeg = g.seg;
}

/** 그 사람의 가족(살아 있는 사람만). */
export function familyOf(g: Game, name: string): { fam: Family; isParent: boolean; kids: Profile[]; others: Profile[] } | null {
  const p = byName(name);
  if (!p) return null;
  const fam = FAMILIES.find(f => f.parents.includes(p.id) || f.children.includes(p.id));
  if (!fam) return null;
  const alive = (id: string) => { const q = byId(id); return q && !isGone(g, q.name) && q.name !== name ? q : undefined; };
  const kids = fam.children.map(alive).filter((q): q is Profile => !!q && q.age < 16);
  const others = [...fam.parents, ...fam.children].map(alive).filter((q): q is Profile => !!q);
  return { fam, isParent: fam.parents.includes(p.id), kids, others };
}

// ---- 누가 죽나(기획 점검 01 2.6) ----
// 굶주림과 약 부족 사망이 늘 꼬리칸 첫 프로필부터 일어나지 않게, 나이·처지·법으로 무게를 두고 판마다 난수로 고른다. 숫자는 제안.
export type VictimCause = 'hunger' | 'wound';

export function victimWeight(g: Game, p: Profile, cause: VictimCause): number {
  const old = p.age >= 65;
  const child = p.age <= 10;
  if (cause === 'wound') {
    // 다친 사람은 파견 나이(16~65)다. 나이가 많을수록 못 버틴다. 중환자 분류 법은 가망 없는 쪽을 먼저 놓는다.
    if (p.age < 16 || p.age > 65) return 0;
    return (p.age >= 50 ? 1.6 : 1) * (lawActive(g, 'triage') && p.age >= 50 ? 1.5 : 1);
  }
  let w = old ? 3 : child ? 2.5 : 1;
  // 기여 배급은 일 못 하는 사람 몫을 줄이고, 공동 식당은 약한 사람을 먼저 먹인다.
  if (lawActive(g, 'contribution_ration') && (old || p.age < 16)) w *= 1.5;
  if (lawActive(g, 'common_kitchen') && (old || child)) w *= 0.6;
  // 배급이 나쁜 칸일수록 먼저 쓰러진다.
  const ration = situation(g, p.community)[1];
  return w * Math.max(0.3, (100 - ration) / 50);
}

/** 무게대로 n명을 고른다(대표는 빼고). */
export function pickVictims(g: Game, n: number, cause: VictimCause, rnd: () => number): Profile[] {
  const out: Profile[] = [];
  const pool = PROFILES.filter(p => !isGone(g, p.name) && !COMMS.some(c => g.comms[c].leader.name === p.name))
    .map(p => ({ p, w: victimWeight(g, p, cause) })).filter(x => x.w > 0);
  for (let k = 0; k < n && pool.length > 0; k += 1) {
    const total = pool.reduce((sum, x) => sum + x.w, 0);
    let r = rnd() * total;
    let i = 0;
    while (i < pool.length - 1 && r >= pool[i].w) { r -= pool[i].w; i += 1; }
    out.push(pool[i].p);
    pool.splice(i, 1);
  }
  return out;
}

// ---- A1 유품과 남은 사람 ----
/** 죽음이 나면 그 구간에 카드 하나(죽은 사람이 여럿이면 아이를 남긴 부모가 먼저). 대표가 죽으면 승계 몫이라 안 띄운다. */
export function afterDeath(g: Game, c: Comm, names: readonly string[]): void {
  const known = names.filter(n => byName(n) && !COMMS.some(k => g.comms[k].leader.name === n));
  for (const n of known) {
    const f = familyOf(g, n);
    if (f) for (const o of f.others) mourn(g, o.name, o.community);
  }
  if (known.length === 0 || g.cards.some(x => x.kind === 'orphan')) return;
  const parent = known.find(n => { const f = familyOf(g, n); return f && f.isParent && f.kids.length > 0; });
  // 남은 아이가 먼저다: 유품 카드가 기다리는 중에 부모가 죽으면 그 카드를 남은 아이 카드로 바꾼다.
  const waiting = g.cards.find(x => x.kind === 'keepsake');
  if (waiting) {
    if (parent) { waiting.kind = 'orphan'; waiting.comm = c; waiting.who = parent; delete waiting.text; }
    return;
  }
  if (parent) addPeopleCard(g, { kind: 'orphan', comm: c, who: parent });
  // 정차 중에 죽었으면 밖에서 죽은 것이다(유품 카드 문장이 달라진다).
  else addPeopleCard(g, { kind: 'keepsake', comm: c, who: known[0], ...(g.phase === 'stop' ? { text: 'field' } : {}) });
}

/** 상중: 2구간. 게이지가 아니라 인물 상태다. 파견에 넣으면 사기가 낮고 회기엔 결석한다. */
export const MOURN_SEGS = 2;
function mourn(g: Game, name: string, comm: Comm): void {
  g.mourning = [...(g.mourning ?? []).filter(m => m.name !== name), { name, comm, until: g.seg + MOURN_SEGS }];
}
export function mourners(g: Game, c?: Comm): string[] {
  return (g.mourning ?? []).filter(m => m.until >= g.seg && (!c || m.comm === c)).map(m => m.name);
}

/** 잠깐 오른 처지(외투와 장화). 카드 효과로 이미 더한 값을 기한이 지나면 되돌린다. */
export function revertLater(g: Game, c: Comm, i: 0 | 1 | 2 | 3, v: number, segs: number): void {
  (g.tempBase ??= []).push({ c, i, v, until: g.seg + segs });
}

// ---- A2 대표의 몸 ----
// 문턱은 브리프의 30에서 38로 올렸다(제안): 지금 S1a 수치에선 처지가 30 아래로 두 구간 이어지는 판이 300판 중 1판뿐이다.
export const SICK = { below: 38, streak: 2, chance: 0.3, max: 2, succeed: 3 } as const;

function proxyTrait(rep: Trait, c: Comm): Trait {
  const ban = TRAIT_BAN[c];
  const shift: Trait[] = rep === 'fear' || rep === 'family' ? ['ambition', 'greed'] : TRAITS.filter(t => t !== rep);
  return shift.find(t => t !== ban) ?? 'ambition';
}

/** 대표가 앓아눕고 측근이 회기에 나온다. 측근과는 빚(부탁)과 뇌물이 안 통한다. */
export function fallSick(g: Game, c: Comm): void {
  const s = g.comms[c];
  const p = drawPerson(g, c, [25, 60]);
  const proxy: Leader = { personId: p.id, name: p.name, age: p.age, trait: proxyTrait(s.leader.trait, c), traitShown: 0 };
  s.sick = { since: g.seg, rep: s.leader };
  s.leader = proxy;
  g.sickCount = (g.sickCount ?? 0) + 1;
  addPeopleCard(g, { kind: 'rep_sick', comm: c });
  journal(g, `${COMM_NAME[c]} 대표 ${s.sick.rep.name}이(가) 앓아누웠다. 회기엔 ${proxy.name}이(가) 대신 나온다.`, 'bad');
}

export function recover(g: Game, c: Comm, why: string): void {
  const s = g.comms[c];
  if (!s.sick) return;
  // 앓던 대표가 그사이 죽었으면 되돌릴 사람이 없다. 대신 나오던 측근이 자리를 잇는다.
  if (isGone(g, s.sick.rep.name)) {
    journal(g, `${s.leader.name}이(가) ${COMM_NAME[c]} 대표 자리를 이었다.`, 'dark');
    s.sick = undefined;
    s.debt = false;
    return;
  }
  journal(g, `${s.sick.rep.name}이(가) ${why} 다시 대표 자리에 앉았다.`, 'good');
  s.leader = s.sick.rep;
  s.sick = undefined;
}

function sickTick(g: Game, rnd: () => number): void {
  for (const c of COMMS) {
    const s = g.comms[c];
    const [w, r] = situation(g, c);
    const low = w < SICK.below || r < SICK.below;
    s.lowStreak = low ? (s.lowStreak ?? 0) + 1 : 0;
    if (s.sick) {
      if (isGone(g, s.sick.rep.name)) recover(g, c, '');
      else if (!low) recover(g, c, '처지가 나아지자');
      else if (g.seg - s.sick.since >= SICK.succeed) {
        journal(g, `${s.sick.rep.name}은(는) 끝내 일어나지 못했다. ${s.leader.name}이(가) ${COMM_NAME[c]} 대표 자리를 이었다.`, 'dark');
        s.sick = undefined;
        s.debt = false;
      }
      continue;
    }
    if ((g.sickCount ?? 0) < SICK.max && (s.lowStreak ?? 0) >= SICK.streak && !g.cards.some(x => x.kind === 'rep_sick') && rnd() < SICK.chance) fallSick(g, c);
  }
}

// ---- A3 내리겠다는 노인 ----
export function elderCandidate(g: Game): Profile | null {
  const alive = PROFILES.filter(p => !isGone(g, p.name) && !COMMS.some(c => g.comms[c].leader.name === p.name));
  const tailOld = alive.filter(p => p.community === 'tail' && p.age >= 65).sort((a, b) => b.age - a.age)[0];
  if (tailOld) return tailOld;
  return alive.filter(p => p.age >= 60).sort((a, b) => b.age - a.age)[0] ?? null;
}

function elderTick(g: Game): void {
  if (g.elderAsked) return;
  if (!(g.food < 20 || situation(g, 'tail')[1] < 30)) return;
  const elder = elderCandidate(g);
  if (!elder) return;
  g.elderAsked = true;
  addPeopleCard(g, { kind: 'elder', comm: elder.community, who: elder.name });
}

// ---- A4 출산 ----
export const BIRTH = { chance: 0.4, from: 8, to: 18, warm: 35, weakSegs: 3 } as const;

function hash(s: string): number {
  let x = 2166136261;
  for (let i = 0; i < s.length; i += 1) x = Math.imul(x ^ s.charCodeAt(i), 16777619);
  return x >>> 0;
}

/** 판마다 확률로 한 번, 예고 없이(2026-10-07 사용자 결정, 40%는 제안). 난수 흐름을 안 건드리게 판 씨앗으로 정한다. */
export function birthSeg(seed: string): number | null {
  const h = hash(`${seed}:birth`);
  if ((h % 1000) / 1000 >= BIRTH.chance) return null;
  return BIRTH.from + (Math.floor(h / 1000) % (BIRTH.to - BIRTH.from + 1));
}

export function motherOf(g: Game, c: Comm): Profile | null {
  const fam = FAMILIES.filter(f => f.community === c).flatMap(f => f.parents).map(byId)
    .find(p => p && !isGone(g, p.name) && p.age >= 18 && p.age <= 42);
  if (fam) return fam;
  return PROFILES.find(p => p.community === c && !isGone(g, p.name) && p.age >= 18 && p.age <= 40) ?? null;
}

function birthTick(g: Game): void {
  if (g.born || g.seg !== birthSeg(g.seed)) return;
  const c: Comm = hash(`${g.seed}:birth:comm`) % 3 === 0 ? 'front' : 'tail';
  const mother = motherOf(g, c);
  if (!mother) return;
  g.born = { comm: c, mother: mother.name, weak: false, left: 0 };
  addPeopleCard(g, { kind: 'birth', comm: c, who: mother.name });
}

/** 약한 아이: 3구간 동안 구간마다 의약품 1. 못 내면 일지 한 줄로만 남긴다(아기의 죽음은 카드·그림으로 안 보인다. 처리 방식은 사용자 몫). */
function weakTick(g: Game): void {
  const b = g.born;
  if (!b || !b.weak || b.left <= 0) return;
  if (g.med >= 1) {
    g.med -= 1;
    b.left -= 1;
    if (b.left === 0) {
      b.weak = false;
      addPeopleCard(g, { kind: 'naming', comm: b.comm, who: b.mother });
      journal(g, `${b.mother}의 아이가 고비를 넘겼다.`, 'good');
    }
  } else {
    b.left = 0;
    b.lost = true;
    g.comms[b.comm].pop = Math.max(1, g.comms[b.comm].pop - 1);
    journal(g, `${b.mother}의 아이는 그 겨울을 넘기지 못했다.`, 'dark');
  }
}

/** 정산 때 부른다. */
export function peopleTick(g: Game, rnd: () => number): void {
  g.tempBase = (g.tempBase ?? []).filter(t => {
    if (g.seg < t.until) return true;
    g.comms[t.c].base[t.i] -= t.v;
    return false;
  });
  weakTick(g);
  sickTick(g, rnd);
  elderTick(g);
  birthTick(g);
}

/** 판 끝 일대기 줄: 맡긴 아이가 어디서 컸는지. */
export function raisedLines(g: Game): string[] {
  return Object.entries(g.raised ?? {}).map(([name, c]) => `${name}은(는) ${COMM_NAME[c as Comm]}에서 컸다.`);
}

export function burnLaw(g: Game): boolean {
  return lawActive(g, 'corpse_burn');
}

