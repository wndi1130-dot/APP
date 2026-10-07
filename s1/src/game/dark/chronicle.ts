import { COMM_NAME } from '../data';
import type { Comm } from '../data';
import { familyOf } from '../people';
import { journal } from '../state';
import type { Game } from '../state';
import { B, CROSSINGS, GRAVE, MEANS } from './data';
import type { MeansKey } from './data';
import { REACTIONS } from './lines';
import { adults, alive, byId, byName, commOf, dpick, nameOf } from './state';

// 10장 일대기와 추모의 벽, 10.5 악몽과 무뎌짐. 수단(열차장이 고른 일의 무게)은 여기서만 센다.
// 끝 화면(ui/panels.ts)은 darkEnd()만 읽는다.

/** 악몽이 바꾸는 카드 수(10.5: 다음 구간 몇 장의 카드) */
export const NIGHTMARE_CARDS = 3;

/** 열차장이 고른 일을 수단에 더한다. 선을 넘는 선택(10.1)이면 기록하고 악몽, 악몽을 지닌 채 또 넘으면 무뎌짐(10.5). */
export function cross(g: Game, key: MeansKey): void {
  const d = g.dark!;
  d.means[key] = (d.means[key] ?? 0) + 1;
  if (!CROSSINGS.includes(key)) return;
  if (d.nightmareUntil >= g.seg) d.numb = true;
  d.crossed.push({ key, seg: g.seg });
  d.nightmareUntil = g.seg + 1;
  d.nightmareCards = NIGHTMARE_CARDS;
}

/** 일대기 장면 후보(10.3). 목격자는 산 사람 가운데 그 자리 사람들이다. 없으면 장면은 남아도 증언은 없다(묻힌 일). */
export function scene(g: Game, key: string, weight: number, text: string, who: string[], witnesses?: string[]): void {
  const d = g.dark!;
  const comm: Comm = who[0] ? commOf(g, who[0]) : 'guard';
  const seen = witnesses ?? [
    ...adults(g, comm, { except: who }).slice(0, 40).filter((_, i) => i % 7 === g.seg % 7).slice(0, 2).map(p => p.id),
    g.comms.guard.leader.personId,
  ].filter(id => !who.includes(id));
  d.scenes.push({ seg: g.seg, key, weight, text, who, witnesses: seen });
  (g.chronicle ??= []).push({ template: `s1b.${key}`, who: who[0] ?? 'chief', where: g.stop?.place ?? '', when: g.seg, witnesses: seen, from: 's1b' });
}

/** 선을 넘는 선택지에 붙는 반응 한 줄(10.1). 무뎌짐이면 지운다(10.5: 경고가 안 보이는 것 자체가 값).
 * 카드를 그릴 때마다 불리므로 난수를 쓰지 않고 카드마다 정해진 줄을 고른다(다시 그려도 같은 줄, 난수 흐름도 그대로). */
export function reaction(g: Game, about: string | undefined, salt: string): string {
  const d = g.dark!;
  if (d.numb) return '';
  const fam = about ? familyOf(g, nameOf(g, about)) : null;
  const kin = fam?.others[0]?.name;
  const pool = REACTIONS.filter(r => kin || !r.includes('{kin}'));
  let h = 0;
  for (const ch of `${g.seed}|${salt}`) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return pool[h % pool.length].replaceAll('{kin}', kin ?? '');
}

/** 악몽(10.5): 선을 넘은 다음 몇 장의 카드에서 열차장 말이 첫 문장에서 끊긴다. */
export function nightmareSay(say: string): string {
  const first = say.split(/(?<=[.!?])\s/)[0] ?? say;
  return `…${first.replace(/[!]$/, '.')}`;
}

// ---- 10.2 톤 ----
export type Means3 = 'clean' | 'shaken' | 'dark';
export type Tone = 'hope' | 'hope_cost' | 'shade' | 'tragedy' | 'worth' | 'despair';

export function meansTotal(g: Game): number {
  const d = g.dark!;
  const chosen = (Object.keys(d.means) as MeansKey[]).reduce((s, k) => s + MEANS[k] * (d.means[k] ?? 0), 0);
  return chosen + MEANS.blackmail * g.stats.blackmails;
}
export function meansLayer(g: Game): Means3 {
  const d = g.dark!;
  if (d.crossed.length === 0) return 'clean';
  const grave = GRAVE.reduce((s, k) => s + (d.means[k] ?? 0), 0);
  return meansTotal(g) >= 8 || grave >= 2 ? 'dark' : 'shaken';
}
export function saved(g: Game): boolean {
  return g.end === 'complete' && g.deaths.length <= B.savedDeaths;
}
export function tone(g: Game): Tone {
  const m = meansLayer(g);
  const s = saved(g);
  if (m === 'clean') return s ? 'hope' : 'hope_cost';
  if (m === 'shaken') return s ? 'shade' : 'tragedy';
  return s ? 'worth' : 'despair';
}

/** 톤 한 문장(자리표시, Gemini가 판의 숫자를 넣어 쓴다). */
const TONE_LINE: Record<Tone, string> = {
  hope: '열차는 닿았다. 누구의 이름도 팔지 않고.',
  hope_cost: '많이 잃었다. {lost}. 그래도 열차장은 끝까지 사람을 팔지 않았다.',
  shade: '열차는 닿았다. 다만 {cross}의 일은 아무도 잊지 않는다.',
  tragedy: '지키려던 것을 놓쳤다. {cross}부터였다.',
  worth: '열차는 닿았다. 그럴 가치가 있었는지는 남은 사람들이 묻는다.',
  despair: '열차는 많은 것을 치르고도 아무것도 지키지 못했다.',
};
const CROSS_WORD: Record<MeansKey, string> = {
  assn_ordered: '암살 명령', executions: '처형', scapegoats: '희생양', frames: '누명', exiles: '하차 명령', lynch_allowed: '막지 않은 린치',
  summary: '즉결', trial_bought: '산 재판', blackmail: '협박', harsh_chosen: '가혹한 법',
};

// ---- 10.3 증언 ----
const TESTIMONY: Record<string, { warm: string; cold: string }> = {
  execute: { warm: '총소리가 나고 다들 숟가락을 내려놨어요.', cold: '판결이 났으니 끝난 일이죠.' },
  exile: { warm: '승강장에 서 있던 게 마지막이었어요. 창을 닦아도 보였어요.', cold: '짐 하나 들고 내렸어요. 그게 다예요.' },
  scapegoat: { warm: '그날 밤 거기 있었다는 것 말고는 아무것도 없었어요.', cold: '누군가는 데려가야 했어요.' },
  lynch: { warm: '경비대는 보고만 있었어요. 열차장도요.', cold: '사람들이 화가 나 있었죠.' },
  order: { warm: '사고였다고들 했어요. 아무도 믿지 않았어요.', cold: '사고였어요.' },
  exposed: { warm: '그 말을 듣고 식당칸이 조용해졌어요.', cold: '다들 짐작은 했어요.' },
  innocent: { warm: '그 사람은 죄가 없었어요. 다들 알게 됐죠.', cold: '틀릴 수도 있죠.' },
  frame: { warm: '그 사람 침상 밑에서 나온 게 진짜였는지 모르겠어요.', cold: '증거가 나왔으니까요.' },
  trial_bought: { warm: '표가 어디서 왔는지 다 알았어요.', cold: '의회가 정한 거예요.' },
  confess: { warm: '열차장이 모두 앞에서 자기가 했다고 했어요.', cold: '말했으니 끝난 거죠.' },
};

export interface Testimony { name: string; comm: Comm; line: string; seg: number }
export interface WallName { name: string; seg: number; comm?: Comm; like?: string; boarding?: string }
export interface DarkEnd {
  tone: Tone; toneLine: string; means: number; layer: Means3; scenes: { seg: number; text: string }[]; testimonies: Testimony[]; wall: WallName[];
  h7: Record<string, number>;
}

function pickScenes(g: Game): { seg: number; text: string; key: string; witnesses: string[] }[] {
  const d = g.dark!;
  const byKey: Record<string, number> = {};
  const out: typeof d.scenes = [];
  for (const s of [...d.scenes].sort((a, b) => b.weight - a.weight || a.seg - b.seg)) {
    if ((byKey[s.key] ?? 0) >= 2) continue;
    byKey[s.key] = (byKey[s.key] ?? 0) + 1;
    out.push(s);
    if (out.length >= 10) break;
  }
  return out.sort((a, b) => a.seg - b.seg);
}

/** 끝 화면 자료(10.3). 증언은 그 일의 목격자 가운데 산 사람, 칸마다 많아야 둘, 모두 3~5개. */
export function darkEnd(g: Game): DarkEnd {
  const d = g.dark!;
  const t = tone(g);
  const scenes = pickScenes(g);
  const lost = g.deaths.slice(0, 2).join(', ') || '이름들';
  const first = d.crossed[0];
  const toneLine = TONE_LINE[t].replaceAll('{lost}', lost).replaceAll('{cross}', first ? `${first.seg}구간의 ${CROSS_WORD[first.key]}` : '그날');
  const testimonies: Testimony[] = [];
  const perComm: Partial<Record<Comm, number>> = {};
  for (const s of [...scenes].sort((a, b) => b.seg - a.seg)) {
    const lines = TESTIMONY[s.key];
    if (!lines) continue;
    const w = s.witnesses.find(id => alive(g, id) && (perComm[commOf(g, id)] ?? 0) < 2 && !testimonies.some(x => x.name === nameOf(g, id)));
    if (!w) continue;
    const c = commOf(g, w);
    perComm[c] = (perComm[c] ?? 0) + 1;
    testimonies.push({ name: nameOf(g, w), comm: c, line: d.numb ? lines.cold : lines.warm, seg: s.seg });
    if (testimonies.length >= 5) break;
  }
  // 10.4: 죽은 까닭은 쓰지 않는다. 희생양·처형으로 죽은 사람도 같은 글씨로.
  const wall: WallName[] = (g.deathLog ?? []).map(x => {
    const p = byName(x.name);
    return { name: x.name, seg: x.seg, ...(p ? { comm: p.community, like: p.like, boarding: boardingOf(g, p.id) } : {}) };
  });
  return {
    tone: t, toneLine, means: meansTotal(g), layer: meansLayer(g), scenes: scenes.map(s => ({ seg: s.seg, text: s.text })), testimonies, wall, h7: h7Record(g),
  };
}

function boardingOf(g: Game, id: string): string {
  if (g.dark!.joined.includes(id)) return '판 중에 탔다';
  const b = (byId(id) as { boarding?: string } | undefined)?.boarding;
  return ({ refugee: '피난길에 탔다', bought: '자리를 사서 탔다', rescue: '구조돼 탔다', depot: '차고에서부터 있었다', force: '밀고 올라탔다', born: '열차에서 났다' } as Record<string, string>)[b ?? ''] ?? '처음부터 탔다';
}

// ---- 15.1 H7 자동 기록 ----
/** 카드 하나를 고른 기록(UI가 잰다). crossing: 선을 넘는 선택지가 보였나, picked: 그걸 골랐나, alt: 다른 답이 열려 있었나. */
export interface H7Pick { kind: string; seg: number; chars: number; ms: number; choices: number; crossing: boolean; picked: boolean; alt: boolean }

export function logPick(g: Game, p: Omit<H7Pick, 'seg'>): void {
  const d = g.dark;
  if (!d) return;
  d.h7.push({ ...p, seg: g.seg });
}

function median(xs: number[]): number {
  if (xs.length === 0) return 0;
  const s = [...xs].sort((a, b) => a - b);
  return s[Math.floor(s.length / 2)];
}

/** 판 끝에 일지에 붙이고 JSON으로 내보내는 숫자(15.1). 망설임은 같은 판, 선택지 수 같고 글자 ±30%인 카드끼리 비교한다. */
export function h7Record(g: Game): Record<string, number> {
  const d = g.dark!;
  const rate = (p: H7Pick) => p.ms / Math.max(1, p.chars);
  const ratios: number[] = [];
  for (const p of d.h7.filter(x => x.crossing)) {
    const peers = d.h7.filter(x => !x.crossing && x.choices === p.choices && Math.abs(x.chars - p.chars) <= p.chars * 0.3);
    const m = median(peers.map(rate));
    if (m > 0) ratios.push(rate(p) / m);
  }
  const s = d.stats;
  return {
    hesitation: +median(ratios).toFixed(2), hesitationN: ratios.length,
    crossingShown: d.h7.filter(x => x.crossing).length, crossingShownWithAlt: d.h7.filter(x => x.crossing && x.alt).length,
    crossings: d.crossed.length, means: meansTotal(g),
    signs: s.signs, imminent: s.imminent, violent: s.violent, violentDeaths: s.violentDeaths,
    cases: s.cases, solved: s.solved, misjudged: s.misjudged, trials: s.trials, scapegoats: s.scapegoats, lynches: s.lynches, orders: s.orders,
    revealed: s.revealed, risen: s.risen, cardsDeferred: s.cardsDeferred,
  };
}

/** 판이 끝날 때 일지 끝에 H7 숫자 한 줄(15.1). */
export function closeChronicle(g: Game): void {
  if (!g.dark || g.dark.closed) return;
  g.dark.closed = true;
  const r = h7Record(g);
  journal(g, `기록: 징후 ${r.signs}, 폭력 ${r.violent}(사망 ${r.violentDeaths}), 선을 넘음 ${r.crossings}, 수단 ${r.means}, 망설임 ${r.hesitation}배.`);
}

/** 추모의 벽 줄(10.4): 이름 옆엔 구간만. 누르면 산 동안의 한 줄. */
export function wallLine(w: WallName): string {
  return `${w.name} · ${w.seg}구간`;
}
export function wallDetail(w: WallName): string {
  return [w.comm ? COMM_NAME[w.comm] : '', w.boarding ?? '', w.like ? `좋아하던 것: ${w.like}` : ''].filter(Boolean).join(' · ');
}

