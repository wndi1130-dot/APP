import type { Comm } from './data';
import { CAPTAIN_ID, departurePeople, returnedOf } from './field_receipt';
import type { AnyDeparture, FieldReceipt } from './field_receipt';
import { familyOf, MEMORY_HOOK } from './people';
import { isGone, PROFILES } from './state';
import type { Game } from './state';

// 사람 기억(J13, 결정 439 카드 1·2). 설계: 조율 폴더 streams 「사람기억_정차장면_설계_20261025」 1~2장.
// 사람 한 명이 필드에서 겪거나 본 일, 돌아온 사람에게 들은 일을 그 사람에게 남긴다. 그 사람의 말·출발 화면·회고만 바꾸고
// 칸 관계·긴장·신임은 쓰지 않는다(칸 쪽 값은 목격 약속·body_search·정치 흐름 몫, 같은 일을 두 번 세지 않는다).
// 본 사람이 돌아오지 않으면 아무도 「어떻게」를 모른다(결정 304와 같은 규칙). 값은 모두 가안이다.

export type MemoryKind =
  | 'saved_me' | 'saved_by' | 'left_me' | 'saw_shot_surrendered' | 'saw_mercy' | 'saw_fall' | 'lost_kin'
  | 'saw_resident_aid' | 'saw_resident_robbed' | 'saw_resident_ignored' | 'event';
/** seen 그 자리에서 봄, told 돌아온 사람에게 들음, unknown 「돌아오지 못했다」만 앎 */
export type MemoryHow = 'seen' | 'told' | 'unknown';
export interface Memory {
  /** 기억을 가진 사람(프로필 id) */
  who: string;
  kind: MemoryKind;
  /** 그 일의 상대: 열차장(CAPTAIN_ID)이나 사람 id. 열차장에 대한 값(stance)은 about이 열차장인 줄만 센다 */
  about: string;
  seg: number;
  where: string;
  how: MemoryHow;
  /** 들려준 사람(돌아온 목격자) */
  from: string[];
  weight: number;
  /** 이 구간까지 남는다. null이면 판 끝까지 */
  until: number | null;
  /** lost_kin: dead·left·missing, event: 사건 키, 구한 일: grab·carry·treat, 정차 사람: 패턴 */
  detail?: string;
  /** lost_kin: 본 사람의 말에 열차장이 곁에 있었다고 나오는가 */
  chiefNear?: boolean;
  /** 이 기억의 대상 사람(lost_kin의 떠난 사람, saw_fall의 쓰러진 사람) */
  subject?: string;
  /** lost_kin·unknown: 곁에 본 사람은 있었는데 그 사람도 돌아오지 못했다 */
  seenByGone?: boolean;
}
export interface MemoryBook { rows: Memory[]; applied: string[]; spent: string[] }
/** 열차 안 사건이 남기는 줄(정치 흐름과 맞춘 꼴). memoryTick이 정산 때 읽고 비운다 */
export interface PersonEvent { key: string; who: string; seg: number; comm: Comm; by?: string }

export const MEM = {
  /** 개인 단계 문턱: 열차장에 대한 값이 이 이상이면 good, 반대쪽 이하면 bad. 사이면 칸 관계를 그대로 쓴다 */
  good: 3, bad: -3,
  /** 가벼운 일(치료받음·살려 보냄·정차 사람)이 남는 구간 수 */
  short: 3,
  /** 출발 계약에 실어 보내는 기억 키 수 */
  cues: 3,
  /** 회고에 나오는 사람 수 */
  testimonies: 3,
} as const;

/** 구한 일의 무게: 열차장이 구했으면 saved_me, 동료가 구했으면 saved_by(열차장 값에는 안 닿는다) */
const SAVE_W = { grab: { chief: 3, mate: 2 }, carry: { chief: 3, mate: 2 }, treat: { chief: 1, mate: 1 } } as const;
const SAVE_TEMPLATES: Record<string, { detail: keyof typeof SAVE_W; prefix: string }> = {
  rescued_from_grab: { detail: 'grab', prefix: 'freed_' },
  carried_back: { detail: 'carry', prefix: 'carried_' },
  treated_by: { detail: 'treat', prefix: 'treated_' },
};
const LEFT_W = -2;
const SHOT_W = -2;
/** 가족이 남겨졌다고 들음 */
const KIN_LEFT_W = -2;

/** 목소리(필드 ally_lines.gd 세 목소리). 출발 계약이 목소리를 싣기 전까지는 사람 id로 정해진 값이다 */
export type Voice = 'fear' | 'rough' | 'quiet';
const VOICES: Voice[] = ['fear', 'rough', 'quiet'];
/** 같은 일에도 사람마다 무게가 다르다: 목소리와 치료 숙련에서 정한다(칸·출신으로 정하지 않는다, 설계 1.5) */
const MERCY_W: Record<Voice | 'medic', number> = { medic: 1, fear: 0, rough: -1, quiet: 0 };
const RESIDENT_W: Record<'aid' | 'robbed' | 'ignored', Record<Voice | 'medic', number>> = {
  aid: { medic: 1, fear: 0, rough: 1, quiet: 1 },
  robbed: { medic: -2, fear: 0, rough: -1, quiet: -1 },
  ignored: { medic: -1, fear: 0, rough: 0, quiet: -1 },
};
/** 정치 흐름의 사건 키(10-25 합의 다섯). 값은 그쪽과 맞출 때까지 0: 말·회고에만 쓴다 */
export const EVENT_KEYS = ['riot_fell', 'ember_hurt', 'ladder_guard', 'gap_hurt', 'ex_chief'] as const;
const EVENT_W: Record<string, number> = {};

function hash(s: string): number {
  let x = 2166136261;
  for (let i = 0; i < s.length; i += 1) x = Math.imul(x ^ s.charCodeAt(i), 16777619);
  return x >>> 0;
}

export function voiceOf(pid: string): Voice {
  return VOICES[hash(`${pid}:voice`) % VOICES.length];
}

/** 출발 계약의 지식 층이 의료면 치료 숙련으로 본다 */
function isMedic(d: AnyDeparture, pid: string): boolean {
  if (d.version !== 2) return false;
  return [...d.roster, ...d.workCrew].some(p => p.id === pid && p.know?.field === 'med' && p.know.skill >= 1);
}

function weighFor(d: AnyDeparture, pid: string, table: Record<Voice | 'medic', number>): number {
  return isMedic(d, pid) ? table.medic : table[voiceOf(pid)];
}

export function memoryBook(g: Game): MemoryBook {
  return (g.memory ??= { rows: [], applied: [], spent: [] });
}

function nameOf(pid: string): string {
  if (pid === CAPTAIN_ID) return '열차장';
  return PROFILES.find(p => p.id === pid)?.name ?? pid;
}

function alive(g: Game, pid: string): boolean {
  if (pid === CAPTAIN_ID) return true;
  const p = PROFILES.find(x => x.id === pid);
  return !!p && !isGone(g, p.name);
}

function live(g: Game, m: Memory): boolean {
  return m.until === null || m.until >= g.seg;
}

function memId(m: Memory): string {
  return `${m.who}:${m.kind}:${m.seg}:${m.about}:${m.subject ?? ''}`;
}

/** 목격 줄의 본 사람 id(문자열이나 {person}) */
function witnessIds(row: Record<string, unknown>): string[] {
  const out: string[] = [];
  for (const w of Array.isArray(row.witnesses) ? row.witnesses as unknown[] : []) {
    const pid = typeof w === 'string' ? w : (w as { person?: unknown } | null)?.person;
    if (typeof pid === 'string') out.push(pid);
  }
  return out;
}

function str(v: unknown): string {
  return typeof v === 'string' ? v : '';
}

/** 그 사람이 나오는 목격 줄: who가 그 사람이거나 what이 「…_<id>」로 끝난다 */
function rowsAbout(r: FieldReceipt, pid: string): Record<string, unknown>[] {
  return (r.witnessed as Record<string, unknown>[]).filter(row => str(row.who) === pid || str(row.what).endsWith(`_${pid}`));
}

/**
 * 귀환 한 번에서 사람 기억을 거둔다(설계 1.3·1.6). 같은 영수증 id는 한 번만 거둔다(applyFieldReturn의 멱등 키와 같다).
 * 기억을 갖는 사람은 살아서 돌아온 사람과, 떠난 사람의 가족 한 사람(열차에 남은 사람)이다.
 */
export function memoryFromReturn(g: Game, departure: AnyDeparture, receipt: FieldReceipt): Memory[] {
  const book = memoryBook(g);
  if (book.applied.includes(receipt.receiptId)) return [];
  book.applied.push(receipt.receiptId);
  const back = new Set(returnedOf(receipt));
  const out: Memory[] = [];
  const where = receipt.place.id;
  const seg = g.seg;
  const add = (m: Omit<Memory, 'seg' | 'where'> & Partial<Pick<Memory, 'where'>>) => {
    if (m.who === CAPTAIN_ID || !back.has(m.who) && m.kind !== 'lost_kin') return;
    out.push({ seg, where, ...m });
  };
  const goneIds = new Set([...receipt.people.dead, ...receipt.people.missing, ...receipt.people.leftBehind]);
  const known = new Set(departurePeople(departure).map(p => p.id));
  const backWitnesses = (row: Record<string, unknown>) => witnessIds(row).filter(w => back.has(w) && (known.has(w) || receipt.people.rescued.includes(w)));

  for (const row of receipt.witnessed as Record<string, unknown>[]) {
    const template = str(row.template) || (str(row.what) === 'shot_surrendered_raider' ? 'shot_surrendered_raider' : '');
    const doer = str(row.who);
    const what = str(row.what);
    const seen = backWitnesses(row);
    const save = SAVE_TEMPLATES[template];
    if (save) {
      if (!what.startsWith(save.prefix)) continue;
      const victim = what.slice(save.prefix.length);
      const byChief = doer === CAPTAIN_ID;
      add({
        who: victim, kind: byChief ? 'saved_me' : 'saved_by', about: doer, how: 'seen', from: [], detail: save.detail,
        weight: SAVE_W[save.detail][byChief ? 'chief' : 'mate'], until: save.detail === 'treat' ? seg + MEM.short : null,
      });
      continue;
    }
    if (template === 'left_behind_survived' && what.startsWith('left_')) {
      add({ who: what.slice('left_'.length), kind: 'left_me', about: CAPTAIN_ID, how: 'seen', from: [], weight: LEFT_W, until: null });
      continue;
    }
    if (template === 'shot_surrendered_raider' || template === 'spared_raider') {
      for (const w of seen) {
        if (template === 'shot_surrendered_raider') add({ who: w, kind: 'saw_shot_surrendered', about: doer, how: 'seen', from: [], weight: SHOT_W, until: null });
        else add({ who: w, kind: 'saw_mercy', about: doer, how: 'seen', from: [], detail: what, weight: weighFor(departure, w, MERCY_W), until: seg + MEM.short });
      }
      continue;
    }
    const res = /^resident_(aid|robbed|ignored)$/.exec(template);
    if (res) {
      const outcome = res[1] as 'aid' | 'robbed' | 'ignored';
      for (const w of seen) {
        if (w === doer) continue;
        add({
          who: w, kind: `saw_resident_${outcome}`, about: doer, how: 'seen', from: [], detail: what,
          weight: weighFor(departure, w, RESIDENT_W[outcome]), until: outcome === 'robbed' ? null : seg + MEM.short,
        });
      }
    }
  }

  // 쓰러진 사람을 본 동료와, 떠난 사람의 가족 한 사람.
  for (const pid of goneIds) {
    const rows = rowsAbout(receipt, pid);
    // 열차장 혼자 본 일은 열차장이 말하기 전까지 아무도 모른다(설계 1.6, 말할지 고르는 카드는 2단계).
    const saw = [...new Set(rows.flatMap(backWitnesses))].filter(w => w !== pid && w !== CAPTAIN_ID);
    const seenByGone = rows.some(row => witnessIds(row).some(w => w !== pid && w !== CAPTAIN_ID && goneIds.has(w)));
    const chiefNear = rows.some(row => str(row.who) === CAPTAIN_ID || witnessIds(row).includes(CAPTAIN_ID));
    for (const w of saw) add({ who: w, kind: 'saw_fall', about: CAPTAIN_ID, subject: pid, how: 'seen', from: [], weight: 0, until: null });
    const detail = receipt.people.dead.includes(pid) ? 'dead' : receipt.people.leftBehind.includes(pid) ? 'left' : 'missing';
    const kin = kinOf(g, pid);
    if (!kin) continue;
    // 남겨진 일은 함께 돌아온 동료 누구나 안다(떠날 때 그 자리에 없었으니까). 죽음은 본 사람이 돌아와야 「어떻게」를 안다.
    const mates = [...back].filter(x => x !== CAPTAIN_ID && x !== kin && known.has(x));
    const from = detail === 'left' ? mates : saw.filter(x => x !== kin);
    const how: MemoryHow = saw.includes(kin) ? 'seen' : from.length > 0 ? 'told' : 'unknown';
    out.push({
      who: kin, kind: 'lost_kin', about: CAPTAIN_ID, subject: pid, seg, where, how, from: how === 'told' ? from : [], detail,
      weight: detail === 'left' && how !== 'unknown' ? KIN_LEFT_W : 0, until: null,
      ...(how !== 'unknown' && chiefNear ? { chiefNear } : {}), ...(how === 'unknown' && seenByGone ? { seenByGone } : {}),
    });
  }

  book.rows.push(...out);
  for (const m of out) chronicleOf(g, m);
  return out;
}

/** 떠난 사람의 가족 가운데 열차에 남은(살아 있는) 첫 사람. 결정 439 카드 1 「명부 가족 한 사람」 */
export function kinOf(g: Game, pid: string): string | null {
  const p = PROFILES.find(x => x.id === pid);
  if (!p) return null;
  return familyOf(g, p.name)?.others[0]?.id ?? null;
}

const CHRONICLE: Partial<Record<MemoryKind, true>> = { saved_me: true, left_me: true, saw_shot_surrendered: true, lost_kin: true, saw_resident_robbed: true, saw_resident_aid: true };

/** 무게 있는 기억은 일대기 장면 줄로도 남긴다(틀 s3.<kind>, 끝 화면이 읽는다) */
function chronicleOf(g: Game, m: Memory): void {
  if (!CHRONICLE[m.kind]) return;
  (g.chronicle ??= []).push({ template: `s3.${m.kind}`, who: m.who, where: m.where, when: m.seg, witnesses: m.how === 'seen' ? [m.who] : m.from, from: 's3' });
}

/** 정산 때(people.ts peopleTick): 열차 안 사건 줄을 그 사람과 가족의 기억으로 옮기고 비운다 */
export function memoryTick(g: Game): void {
  const events = g.personEvents;
  if (!events || events.length === 0) return;
  const book = memoryBook(g);
  for (const e of events) {
    const about = e.by === 'chief' ? CAPTAIN_ID : e.by ?? '';
    const w = about === CAPTAIN_ID ? EVENT_W[e.key] ?? 0 : 0;
    const rows: Memory[] = [];
    if (alive(g, e.who)) rows.push({ who: e.who, kind: 'event', about, seg: e.seg, where: '', how: 'seen', from: [], weight: w, until: null, detail: e.key });
    else {
      const kin = kinOf(g, e.who);
      if (kin) rows.push({ who: kin, kind: 'lost_kin', about, subject: e.who, seg: e.seg, where: '', how: 'told', from: [], weight: 0, until: null, detail: `event:${e.key}` });
    }
    book.rows.push(...rows);
  }
  g.personEvents = [];
}

// ---- 읽기 ----

export function memoriesOf(g: Game, pid: string): Memory[] {
  return (g.memory?.rows ?? []).filter(m => m.who === pid && live(g, m));
}

/** 열차장에 대한 그 사람의 개인 값(살아 있는 기억, about이 열차장인 줄만) */
export function personalScore(g: Game, pid: string): number {
  return memoriesOf(g, pid).filter(m => m.about === CAPTAIN_ID).reduce((s, m) => s + m.weight, 0);
}

/** 개인 단계(설계 1.4). 문턱 사이면 null: 그 사람은 칸 관계 단계를 그대로 쓴다 */
export function stanceOf(g: Game, pid: string): 'good' | 'bad' | null {
  const p = personalScore(g, pid);
  return p >= MEM.good ? 'good' : p <= MEM.bad ? 'bad' : null;
}

/** 필드 말풍선이 부를 기억 키(새것부터, 겹치지 않게). 동료가 구한 일은 「saved_by:<id>」 */
export function cuesOf(g: Game, pid: string): string[] {
  const keys = [...memoriesOf(g, pid)].sort((a, b) => b.seg - a.seg).map(m => (m.kind === 'saved_by' ? `saved_by:${m.about}` : m.kind));
  return [...new Set(keys)].slice(0, MEM.cues);
}

/** 출발 계약의 사람 칸에 실을 것. 기억이 없으면 빈 꼴(필드는 칸 관계만 쓴다) */
export function departureMemory(g: Game, pid: string): { stance?: 'good' | 'bad'; cues?: string[] } {
  const stance = stanceOf(g, pid);
  const cues = cuesOf(g, pid);
  return { ...(stance ? { stance } : {}), ...(cues.length ? { cues } : {}) };
}

// ---- 출발 화면의 협조(결정 439 카드 2 「가」: 출발 화면에서만) ----

const REFUSE_WHY: Partial<Record<MemoryKind, string>> = {
  left_me: '그날 두고 갈 뻔했던 일',
  saw_shot_surrendered: '손 든 사람을 쏜 일',
  lost_kin: '가족을 두고 온 일',
  saw_resident_robbed: '신호소 그 집 일',
};

/**
 * 구해 준 일이 있으면 「자원한다」(덤·벌 없음, 고르기 쉬워질 뿐). 개인 단계가 bad면 그 단계를 만든 가장 무거운 기억 하나로
 * 첫 파견 하나를 빠진다. 까닭은 고르는 자리에 그대로 보이고, 다른 사람을 고르면 된다. 한 기억으로 한 번만 빠진다.
 */
export function dispatchNote(g: Game, pid: string): { volunteer: boolean; refuse: string | null } {
  const rows = memoriesOf(g, pid).filter(m => m.about === CAPTAIN_ID);
  const volunteer = rows.some(m => m.kind === 'saved_me' && m.detail !== 'treat');
  if (stanceOf(g, pid) !== 'bad') return { volunteer, refuse: null };
  const spent = new Set(g.memory?.spent ?? []);
  const worst = rows.filter(m => m.weight < 0 && !spent.has(memId(m))).sort((a, b) => a.weight - b.weight || b.seg - a.seg)[0];
  return { volunteer, refuse: worst ? REFUSE_WHY[worst.kind] ?? '지난 일' : null };
}

/** 빠진 사람이 출발하지 않았으면 그 기억의 거절을 쓴 것으로 적는다 */
export function spendRefusal(g: Game, pid: string): void {
  const rows = memoriesOf(g, pid).filter(m => m.about === CAPTAIN_ID && m.weight < 0);
  const book = memoryBook(g);
  const worst = rows.filter(m => !book.spent.includes(memId(m))).sort((a, b) => a.weight - b.weight || b.seg - a.seg)[0];
  if (worst) book.spent.push(memId(worst));
}

// ---- 말과 회고(설계 1.8, 아르곤 검수 반영본) ----

/** 열차에 남은 가족의 한 줄. 그 사람이 아는 것(how)을 넘는 말은 하지 않는다 */
export function kinLine(g: Game, kin: string): string | null {
  const m = memoriesOf(g, kin).filter(x => x.kind === 'lost_kin').sort((a, b) => b.seg - a.seg)[0];
  if (!m || !m.subject) return null;
  const him = nameOf(m.subject);
  const teller = m.from[0] ? nameOf(m.from[0]) : '';
  // 열차장은 돌아와 이 말을 듣고 있으니 「돌아온 사람이 없다」는 쓰지 않는다(아르곤 검수 5).
  if (m.how === 'unknown') return m.seenByGone ? '곁에 있던 사람도 돌아오지 못했어요.' : `${him}이(가) 어떻게 갔는지… 아무도 말을 안 해 줘요.`;
  if (m.detail === 'left') return '살아 있었대요. 두고 왔대요.';
  if (m.detail === 'missing') return `${him}이(가) 어디서 멈췄는지 아무도 몰라요.`;
  if (m.chiefNear && teller) return `${teller}이(가) 그러더라고요. 마지막까지 열차장님이 옆에 있었다고.`;
  if (teller) return `${teller}이(가) 그날 일을 말해 줬어요.`;
  return `${him}이(가) 어떻게 갔는지… 아무도 말을 안 해 줘요.`;
}

/** 살아 돌아온 사람을 열차장이 구했다는 걸 가족이 들은 한 줄 */
export function kinThanks(g: Game, kin: string, pid: string): string | null {
  return memoriesOf(g, pid).some(m => m.kind === 'saved_me' && m.detail !== 'treat') ? `${nameOf(pid)}이(가) 그러는데, 열차장님이 끌어냈다고요. …고마워요.` : null;
}

const TESTIMONY: Partial<Record<MemoryKind | 'lost_kin_unknown', { warm: string; cold: string }>> = {
  saved_me: { warm: '그날 저를 끌어낸 손이 열차장 손이었어요.', cold: '살았으니 된 거죠.' },
  left_me: { warm: '멀어지는 등을 봤어요. 그래도 저는 걸어서 돌아왔어요.', cold: '다들 자기 살 길 찾았죠.' },
  saw_shot_surrendered: { warm: '손을 들고 있었어요. 저는 지금도 그 손이 보여요.', cold: '우릴 털려던 사람이었어요.' },
  lost_kin_unknown: { warm: '{그}이(가) 어떻게 갔는지 저는 끝내 몰라요.', cold: '돌아오지 못했어요. 그게 다예요.' },
};

export interface MemoryTestimony { pid: string; name: string; line: string; seg: number }

/** 끝 화면·회고 쪽의 증언: 그 기억을 가진 살아 있는 사람이 먼저(설계 1.7 (3)). 사람마다 가장 무거운 기억 하나, 모두 MEM.testimonies까지 */
export function memoryTestimonies(g: Game): MemoryTestimony[] {
  const cold = !!g.dark?.numb;
  const best = new Map<string, Memory>();
  for (const m of g.memory?.rows ?? []) {
    const key = m.kind === 'lost_kin' && m.how === 'unknown' ? 'lost_kin_unknown' : m.kind;
    if (!TESTIMONY[key as keyof typeof TESTIMONY] || !alive(g, m.who)) continue;
    const have = best.get(m.who);
    if (!have || Math.abs(m.weight) > Math.abs(have.weight) || (Math.abs(m.weight) === Math.abs(have.weight) && m.seg < have.seg)) best.set(m.who, m);
  }
  return [...best.values()]
    .sort((a, b) => Math.abs(b.weight) - Math.abs(a.weight) || a.seg - b.seg)
    .slice(0, MEM.testimonies)
    .map(m => {
      const key = (m.kind === 'lost_kin' && m.how === 'unknown' ? 'lost_kin_unknown' : m.kind) as keyof typeof TESTIMONY;
      const t = TESTIMONY[key]!;
      return { pid: m.who, name: nameOf(m.who), line: (cold ? t.cold : t.warm).replaceAll('{그}', m.subject ? nameOf(m.subject) : ''), seg: m.seg };
    });
}

MEMORY_HOOK.tick = memoryTick;
