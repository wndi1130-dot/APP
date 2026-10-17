import { COMMS, COMM_NAME } from './data';
import { END_LINK } from './state';
import type { Game } from './state';
import { snapshot } from './field_receipt';
import type { FieldSnapshot } from './field_receipt';

// 둘째 역 도착 화면과 끝 카드(구현명세 S3 연결 v1 5절, 결정 297). 수직 슬라이스는 여기서 끝난다.
// 첫 귀환 뒤 다음 정차에 닿으면 정차를 고르지 않고 이 화면을 보인다. 둘째 역에는 필드도 새 정차 결정도 없다.
// 이 모듈은 상태를 읽기만 한다. 판을 바꾸는 것은 「계속」(finishSlice) 하나다.

export type ArrivalKind = 'arrive' | 'people' | 'stock' | 'warm' | 'symbol' | 'promise' | 'council';
export interface ArrivalSection { k: ArrivalKind; title: string; lines: string[] }

const diff = (a: number, b: number) => (b === a ? '그대로' : `${a} → ${b} (${b > a ? '+' : '−'}${Math.abs(b - a)})`);

/** 첫 귀환 뒤 다음 정차에 닿았고 아직 정차를 고르지 않았다. 이때 정차 카드 대신 도착 화면을 보인다. */
export function secondStationReached(g: Game): boolean {
  const rec = g.fieldReturns?.records[0];
  return !!rec && g.phase === 'stop' && g.seg > rec.seg && !g.stop?.done;
}

/**
 * 도착 화면 차례(5절 추천): ① 도착 → ② 사람 → 물자 → 온기 → ③ 상징물 → ④ 약속 → ⑤ 특별 회기. 끝 카드는 endCard.
 * 사람·물자·온기는 첫 귀환을 반영하기 직전(반영 기록의 before)과 지금을 견준다. 상징물·약속은 반영 기록의 까닭 줄 그대로다.
 */
export function arrivalSummary(g: Game): ArrivalSection[] | null {
  const fr = g.fieldReturns;
  const rec = fr?.records[0];
  if (!fr || !rec) return null;
  const was: FieldSnapshot = rec.before;
  const now = snapshot(g);
  const out: ArrivalSection[] = [];
  out.push({ k: 'arrive', title: '둘째 역', lines: [`${g.seg}구간, 둘째 역에 닿았다. 첫 정차에서 ${g.seg - rec.seg}구간을 달려왔다.`] });

  const people: string[] = [];
  if (rec.dead.length > 0) people.push(`돌아오지 못한 사람: ${rec.dead.join(', ')}`);
  for (const c of COMMS) if (now.pop[c] !== was.pop[c]) people.push(`${COMM_NAME[c]} ${diff(was.pop[c], now.pop[c])}명`);
  if (now.injured !== was.injured) people.push(`다친 사람 ${diff(was.injured, now.injured)}`);
  out.push({ k: 'people', title: '사람', lines: people.length ? people : ['사람 수는 그대로다.'] });

  out.push({ k: 'stock', title: '물자', lines: [
    `석탄 ${diff(was.coal, now.coal)}`, `식량 ${diff(was.food, now.food)}`, `의약품 ${diff(was.med, now.med)}`, `사치품 ${diff(was.lux, now.lux)}`,
  ] });

  const warm = COMMS.filter(c => now.warm[c] !== was.warm[c]).map(c => `${COMM_NAME[c]} 온기 ${diff(was.warm[c], now.warm[c])}`);
  out.push({ k: 'warm', title: '온기', lines: warm.length ? warm : ['칸마다 온기는 그대로다.'] });

  const symbol = rec.lines.filter(l => l.k === 'symbol').map(l => l.text);
  out.push({ k: 'symbol', title: '상징물', lines: symbol.length ? symbol : ['가져온 상징물이 없다.'] });

  const promise = rec.lines.filter(l => l.k === 'promise').map(l => l.text);
  out.push({ k: 'promise', title: '약속', lines: promise.length ? promise : ['필드에서 한 약속이 없었다.'] });

  const sp = fr.special;
  const council: string[] = [];
  if (!sp) council.push('특별 회기는 열리지 않았다.');
  else if (sp.status === 'skipped') council.push(`특별 회기를 열지 못했다: ${sp.why ?? ''}`.trim());
  else {
    if (sp.picked && sp.result) council.push(`「${sp.picked}」 ${sp.result.passed ? '가결' : '부결'} (찬성 ${sp.result.yes}, 반대 ${sp.result.no}, 필요 ${sp.result.need})`);
    if (sp.before && sp.after) {
      council.push(`신임 ${diff(sp.before.trust, sp.after.trust)}`, `긴장 ${diff(sp.before.tension, sp.after.tension)}`);
      for (const c of COMMS) if (sp.after.rel[c] !== sp.before.rel[c]) council.push(`${COMM_NAME[c]} 관계 ${diff(sp.before.rel[c], sp.after.rel[c])}`);
    }
  }
  out.push({ k: 'council', title: '특별 회기', lines: council });
  return out;
}

/** 끝 카드 문구(결정 297: 작업자가 정한다). */
export function endCard(g: Game): { title: string; lines: string[] } {
  const rec = g.fieldReturns?.records[0];
  const lost = rec?.dead.length ?? 0;
  return {
    title: '여기까지',
    lines: [
      '첫 정차 한 번이 열차를 이만큼 바꿨다.',
      lost > 0 ? `${lost}명은 그 역에 남았다.` : '나간 사람은 모두 열차로 돌아왔다.',
      '이 시험판은 둘째 역에서 멈춘다.',
    ],
  };
}

/** 「계속」: 끝 카드로 판을 닫는다. 둘째 역에 닿은 때만 된다. 더 나아가는 길은 없다. */
export function finishSlice(g: Game): boolean {
  if (!secondStationReached(g)) return false;
  g.fieldReturns!.arrived = { seg: g.seg };
  END_LINK.finish(g, 'slice');
  return true;
}
