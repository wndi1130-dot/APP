// 판이 끝날 때 일지에 적는 「돌이켜 보면」 줄(결정 183, 구현 명세 「돌이켜 보면」).
// 판의 값은 하나도 바꾸지 않는다: 정산마다 재고와 길을 읽어 `g.look`에 적어 둘 뿐이고, 주사위를 굴리지 않는다.
// 글에 든 숫자는 정산 번호뿐이고, 사람 이름·지명·판단하는 말은 쓰지 않는다.
import { ROUTE } from './data';
import { D } from './domestic/data';
import { eduLookLines } from './domestic/classroom';
import { josa } from './josa';
import { journal, lawActive } from './state';
import type { Game } from './state';

export type LookRes = 'coal' | 'food' | 'wood' | 'scrap';
export type SkipKey = 'tailHeat' | 'heatQuota' | 'noInsulate' | 'tailRation' | 'contribution' | 'noOutsiders' | 'breakdown';

/** 이 값 이하면 「바닥을 보였다」. 판의 값이 아니라 읽는 눈금이라 P에 넣지 않는다. */
const FLOOR: Record<LookRes, number> = { coal: 15, food: 25, wood: 3, scrap: 3 };
const RES_NAME: Record<LookRes, string> = { coal: '석탄', food: '식량', wood: '목재', scrap: '고철' };
const RES_ORDER: LookRes[] = ['coal', 'food', 'wood', 'scrap'];
const COAL_PLACES = ['freight', 'factory'];

function lookOf(g: Game): NonNullable<Game['look']> {
  return (g.look ??= { low: {}, skip: {}, coalStops: 0 });
}

/** 정차에 닿을 때 센다: 석탄이 나는 곳(화물역·공장)에 선 수. 석탄이 처음 바닥을 본 뒤로는 세지 않는다. */
export function countCoalStop(g: Game, placeId: string, sign: 1 | -1 = 1): void {
  if (!COAL_PLACES.includes(placeId)) return;
  const look = lookOf(g);
  if (look.low.coal !== undefined) return;
  look.coalStops = Math.max(0, look.coalStops + sign);
}

/** 정산마다 한 번 본다. 처음 일어난 정산만 적고, 다시 올라갔다 내려가도 처음 것을 남긴다. */
export function trackLookback(g: Game): void {
  const look = lookOf(g);
  const read: Record<LookRes, number | undefined> = { coal: g.coal, food: g.food, wood: g.dom?.wood, scrap: g.dom?.scrap };
  for (const res of RES_ORDER) {
    const v = read[res];
    if (v !== undefined && v <= FLOOR[res] && look.low[res] === undefined) {
      look.low[res] = g.seg;
      // 석탄이 처음 바닥을 보인 정산에 단열한 칸이 없었고 단열할 목재가 있었나(그때가 아니면 알 수 없다)
      if (res === 'coal' && g.dom && g.dom.insulated.length === 0 && g.dom.wood >= D.insulateWood) look.skip.noInsulate = g.seg;
    }
  }
  const taken: Record<Exclude<SkipKey, 'noInsulate'>, boolean> = {
    tailHeat: g.comms.tail.heat < 2,
    heatQuota: lawActive(g, 'heat_quota'),
    tailRation: g.comms.tail.ration < 2,
    contribution: lawActive(g, 'contribution_ration'),
    noOutsiders: lawActive(g, 'no_outsiders'),
    breakdown: (g.dom?.stats.breakdowns ?? 0) > 0,
  };
  for (const key of Object.keys(taken) as (keyof typeof taken)[]) {
    if (taken[key] && look.skip[key] === undefined) look.skip[key] = g.seg;
  }
}

/** 구간 1부터 n까지, 노선 표로 본 석탄 나는 곳에 설 기댓값. 풀어 주는 구간은 그 곳들 가운데 석탄 나는 곳의 몫이다. */
export function expectedCoalStops(n: number): number {
  let sum = 0;
  for (let seg = 1; seg <= n; seg += 1) {
    const band = ROUTE.find(b => seg <= b.to) ?? ROUTE[ROUTE.length - 1];
    if (seg === band.relief.seg) {
      sum += band.relief.places.filter(id => COAL_PLACES.includes(id)).length / band.relief.places.length;
    } else {
      const total = Object.values(band.w).reduce((a, b) => a + b, 0);
      sum += COAL_PLACES.reduce((a, id) => a + (band.w[id] ?? 0), 0) / Math.max(1, total);
    }
  }
  return sum;
}

/** 노선이 박했던 판: 석탄이 처음 바닥을 보인 정산까지 석탄 나는 곳에 선 수가 기댓값의 반에 못 미친다. */
export function routeWasThin(g: Game): boolean {
  const low = g.look?.low.coal;
  if (low === undefined) return false;
  const want = expectedCoalStops(low);
  return want >= 2 && (g.look?.coalStops ?? 0) < want / 2;
}

const n째 = (seg: number): string => `${seg}째 정산`;
const sorted = (g: Game): { res: LookRes; seg: number }[] =>
  RES_ORDER.filter(r => g.look?.low[r] !== undefined).map(res => ({ res, seg: g.look!.low[res]! }))
    .sort((a, b) => a.seg - b.seg || RES_ORDER.indexOf(a.res) - RES_ORDER.indexOf(b.res));

/** 첫 줄(4-2): 가장 먼저 바닥을 본 것, 같은 정산에 둘이면 함께, 뒤에 다른 것이 있으면 뒤따랐다. */
function firstLine(lows: { res: LookRes; seg: number }[]): string {
  const [a, ...rest] = lows;
  const same = rest.find(x => x.seg === a.seg);
  if (same) {
    const x = RES_NAME[a.res]; const y = RES_NAME[same.res];
    return `돌이켜 보면, ${n째(a.seg)}에서 ${x}${josa(x, '과/와')} ${y}${josa(y, '이/가')} 함께 바닥을 보였다.`;
  }
  const x = RES_NAME[a.res];
  const next = rest[0];
  if (next) {
    const y = RES_NAME[next.res];
    return `돌이켜 보면, ${n째(a.seg)}에서 ${x}${josa(x, '이/가')} 처음 바닥을 보였고, ${n째(next.seg)}에서 ${y}${josa(y, '이/가')} 뒤따랐다.`;
  }
  return `돌이켜 보면, ${n째(a.seg)}에서 ${x}${josa(x, '이/가')} 처음 바닥을 보였다.`;
}

/** 끝까지 간 판의 한 줄(4-4). */
function arrivedLine(lows: { res: LookRes; seg: number }[]): string {
  const [a, b] = lows;
  const x = RES_NAME[a.res];
  if (!b) return `돌이켜 보면, ${n째(a.seg)}에서 ${x}${josa(x, '이/가')} 바닥을 보였다. 그래도 닿았다.`;
  const y = RES_NAME[b.res];
  return `돌이켜 보면, ${n째(a.seg)}에서 ${x}${josa(x, '이/가')}, ${n째(b.seg)}에서 ${y}${josa(y, '이/가')} 바닥을 보였다. 그래도 닿았다.`;
}

/** 둘째 줄 후보(4-3). 위에서부터 처음 맞는 하나. `full`은 풀이까지, 아니면 앞 문장만(노선 줄 뒤에 붙일 때). */
function skipSentence(g: Game, full: boolean): string | null {
  const look = g.look;
  if (!look) return null;
  const coal = look.low.coal;
  const food = look.low.food;
  const revolt = g.end === 'revolt';
  const s = look.skip;
  if (s.noInsulate !== undefined) return full ? '그때 단열한 칸은 하나도 없었다. 식은 칸이 석탄을 더 먹었다.' : '그때 단열한 칸은 하나도 없었다.';
  if (s.breakdown !== undefined && coal !== undefined && s.breakdown < coal) {
    return full ? `그보다 앞서 ${n째(s.breakdown)}에서 고장이 났고, 고치지 못한 기관이 석탄을 더 먹었다.` : `그보다 앞서 ${n째(s.breakdown)}에서 고장이 났다.`;
  }
  if (revolt && coal !== undefined) {
    if (s.tailHeat !== undefined && s.tailHeat >= coal) {
      return full ? `${n째(s.tailHeat)}에서 꼬리칸의 난방을 내렸다. 석탄은 아꼈고 꼬리칸은 식었다.` : `${n째(s.tailHeat)}에서 꼬리칸의 난방을 내렸다.`;
    }
    if (s.heatQuota !== undefined && s.heatQuota >= coal) {
      return full ? `${n째(s.heatQuota)}에서 난방 배당이 법이 되었다. 석탄은 아꼈고 뒤쪽 칸들은 식었다.` : `${n째(s.heatQuota)}에서 난방 배당이 법이 되었다.`;
    }
  }
  if (revolt && food !== undefined) {
    if (s.tailRation !== undefined && s.tailRation >= food) {
      return full ? `${n째(s.tailRation)}에서 꼬리칸의 배급을 깎았다. 식량은 버텼고 꼬리칸은 굶었다.` : `${n째(s.tailRation)}에서 꼬리칸의 배급을 깎았다.`;
    }
    if (s.contribution !== undefined && s.contribution >= food) {
      return full ? `${n째(s.contribution)}에서 기여 배급이 법이 되었다. 식량은 버텼고 일하지 못하는 사람은 굶었다.` : `${n째(s.contribution)}에서 기여 배급이 법이 되었다.`;
    }
    if (s.noOutsiders !== undefined && s.noOutsiders >= food) {
      return full ? `${n째(s.noOutsiders)}에서 바깥 사람을 받지 않기로 했다. 입은 줄었고 일손도 줄었다.` : `${n째(s.noOutsiders)}에서 바깥 사람을 받지 않기로 했다.`;
    }
  }
  return null;
}

/** 판이 끝날 때 적을 줄(많아야 둘). 읽기만 하고 판의 값은 바꾸지 않는다. */
export function lookbackLines(g: Game): string[] {
  const end = g.end;
  if (!end) return [];
  const lows = sorted(g);
  if (end === 'complete') return lows.length > 0 ? [arrivedLine(lows)] : [];
  if (end === 'ousted' || end === 'coup' || end === 'lost_captain') return lows.length > 0 ? [firstLine(lows)] : [];
  if (end !== 'revolt' && end !== 'stranded') return [];
  if (lows.length === 0) return end === 'revolt' ? ['돌이켜 보면, 석탄도 식량도 바닥을 보인 적은 없었다. 모자란 것은 다른 데 있었다.'] : [];
  const out = [firstLine(lows)];
  // 석탄이 15 아래로 내려간 정산과 0이 된 정산이 같은 좌초는 첫 줄 하나로 족하다.
  if (end === 'stranded' && g.look?.low.coal === g.seg) return out;
  const thin = routeWasThin(g);
  const tail = skipSentence(g, !thin);
  if (thin) out.push(tail ? `이 노선은 석탄이 나는 역이 드물었다. ${tail}` : '이 노선은 석탄이 나는 역이 드물었다.');
  else if (tail) out.push(tail);
  return out;
}

/** 끝나는 자리에서 부른다: 마지막 정산의 값까지 읽고, 줄을 일지에 적는다. 꼬리표 'dark'라서 끝 화면의 일지 추림에 든다. */
export function writeLookback(g: Game): void {
  trackLookback(g);
  for (const line of lookbackLines(g)) journal(g, line, 'dark');
  for (const line of eduLookLines(g)) journal(g, line);
}
