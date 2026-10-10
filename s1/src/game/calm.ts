import { COMM_NAME, COMMS } from './data';
import type { Comm, LawId } from './data';
import { clamp, journal, lawActive } from './state';
import type { CalmState, Game } from './state';

// 불만을 낮추는 법 셋(coord\fun\H6_불만법_명세.md 3장, 결정 035): 저녁 솥불, 벽 장부, 떠난 사람의 밤.
// 통과된 동안 구간마다 천천히 깎이는 꼴이라 LawDef.res(고정 값)로는 못 담는다. 정산이 이 파일의 함수를 한 번씩 부른다.
// 숫자는 제안이고 사건 줄기가 봇으로 재서 고친다. 긴장 정산의 「합이 0 이하면 −2」 절벽(turn.ts meters)은 건드리지 않는다.
export const CALM = {
  // 저녁 솥불
  potCoal: 0.5, potTension: -0.1, potRel: 0.5, potRelLine: -15, potOffCoal: 20, potOnCoal: 30, potOffRel: -2,
  // 벽 장부
  ledgerRich: 50, ledgerPoor: 40, richTension: -0.2, richTrust: 0.2, trustCap: 70, poorTension: 0.3, poorRel: -0.5, repealTrust: -5,
  // 떠난 사람의 밤
  nightFear: -2, nightTension: -2, nightRel: 3, nightCoal: 1, nightLux: 1, nightMinCoal: 5, nightHalfFrom: 3, chosenTrust: -2,
  /** 소수로 쌓이는 값은 매 구간 일지를 내면 시끄러워 이 간격마다 한 줄 */
  noteEvery: 3,
};

export function calmOf(g: Game): CalmState {
  return (g.calm ??= {});
}

/** 솥불이 지금 켜져 있나. 켜진 적 없이 법만 서 있으면(포고 되살림 등) 석탄으로 정한다. */
export function potRunning(g: Game): boolean {
  return lawActive(g, 'evening_pot') && (g.calm?.potOn ?? g.coal > CALM.potOffCoal);
}

export type LedgerLevel = 'rich' | 'mid' | 'poor';
export function ledgerLevel(g: Game): LedgerLevel {
  if (g.coal <= CALM.ledgerPoor || g.food <= CALM.ledgerPoor) return 'poor';
  if (g.coal >= CALM.ledgerRich && g.food >= CALM.ledgerRich) return 'rich';
  return 'mid';
}

/** 이번 구간에 솥불이 드는 석탄(turn.ts forecast가 더한다) */
export function calmCoal(g: Game): number {
  return potRunning(g) ? CALM.potCoal : 0;
}

/** 긴장 정산에 더하는 몫(turn.ts meters가 tensionAdd 합과 같이 더한다) */
export function calmTension(g: Game): number {
  let t = 0;
  if (potRunning(g)) t += CALM.potTension;
  if (lawActive(g, 'wall_ledger')) {
    const level = ledgerLevel(g);
    if (level === 'rich') t += CALM.richTension;
    else if (level === 'poor') t += CALM.poorTension;
  }
  return t;
}

/** 법이 선 때에 맞춰 값을 맞춘다(politics.ts enactLaw). */
export function calmEnact(g: Game, law: LawId): void {
  if (law === 'evening_pot') {
    const c = calmOf(g);
    c.potOn = g.coal > CALM.potOffCoal;
    c.potSegs = 0;
  } else if (law === 'wall_ledger') {
    const c = calmOf(g);
    c.ledger = ledgerLevel(g);
    c.ledgerSegs = 0;
  } else if (law === 'night_of_names') {
    // 법이 서기 전의 죽음은 밤으로 세지 않는다. 서는 구간에 난 죽음은 센다.
    calmOf(g).nightSeg = g.seg - 1;
  }
}

/** 폐지 때 값(politics.ts repealLaw). 벽 장부를 지우면 신임 −5 한 번. */
export function calmRepeal(g: Game, law: LawId): void {
  if (law === 'wall_ledger') {
    g.trust = clamp(g.trust + CALM.repealTrust, 0, 100);
    journal(g, '벽 장부를 지웠다. 숨기는 것이 있다는 말이 돈다.', 'bad');
  } else if (law === 'evening_pot') {
    if (g.calm) delete g.calm.potOn;
  }
}

/** 폐지 표결 화면에 보일 줄 */
export function calmRepealLines(law: LawId): string[] {
  return law === 'wall_ledger' ? [`장부를 지우면 신임 ${CALM.repealTrust}`] : [];
}

/** 지금 상태를 한 줄로(폐지 표결 화면). 없으면 null. */
export function calmStateLine(g: Game, law: LawId): string | null {
  if (law === 'evening_pot') return potRunning(g) ? '지금 불이 켜져 있다' : '지금 불이 꺼져 있다. 주다가 끊은 불은 안 켠 불보다 차다.';
  if (law === 'wall_ledger') {
    const level = ledgerLevel(g);
    return level === 'poor' ? '벽의 숫자가 날마다 줄어든다. 꼬리칸이 그 앞에 오래 서 있다.' : level === 'rich' ? '벽의 숫자가 넉넉하다' : null;
  }
  return null;
}

/** 정산 한가운데(관계가 처지로 움직인 뒤)에서 솥불과 장부를 셈한다. 일지는 상태가 바뀔 때와 noteEvery 구간마다만 낸다. */
export function calmSettle(g: Game): void {
  const c = calmOf(g);
  if (lawActive(g, 'evening_pot')) {
    const was = c.potOn ?? g.coal > CALM.potOffCoal;
    if (was && g.coal <= CALM.potOffCoal) {
      c.potOn = false;
      for (const k of COMMS) if (g.comms[k].rel <= CALM.potRelLine) g.comms[k].rel = clamp(g.comms[k].rel + CALM.potOffRel, -100, 100);
      journal(g, '저녁 솥불이 꺼졌다. 석탄이 모자란다.', 'bad');
    } else if (!was && g.coal >= CALM.potOnCoal) {
      c.potOn = true;
      c.potSegs = 0;
      journal(g, '저녁 솥불을 다시 켰다.', 'good');
    } else {
      c.potOn = was;
    }
    if (c.potOn) {
      let lifted: Comm | null = null;
      for (const k of COMMS) {
        const s = g.comms[k];
        if (s.rel <= CALM.potRelLine) {
          s.rel = clamp(s.rel + CALM.potRel, -100, 100);
          if (!lifted || s.rel < g.comms[lifted].rel) lifted = k;
        }
      }
      c.potSegs = (c.potSegs ?? 0) + 1;
      if (lifted && c.potSegs % CALM.noteEvery === 0) journal(g, `저녁 솥불 덕에 ${COMM_NAME[lifted]}의 말이 조금 누그러졌다.`, 'good');
    }
  }
  if (lawActive(g, 'wall_ledger')) {
    const level = ledgerLevel(g);
    if (level === 'rich') {
      if (g.trust < CALM.trustCap) g.trust = Math.min(CALM.trustCap, g.trust + CALM.richTrust);
    } else if (level === 'poor') {
      g.comms.tail.rel = clamp(g.comms.tail.rel + CALM.poorRel, -100, 100);
    }
    c.ledgerSegs = c.ledger === level ? (c.ledgerSegs ?? 0) + 1 : 0;
    if (c.ledger !== level) {
      if (level === 'poor') journal(g, '벽의 숫자가 날마다 줄어든다. 꼬리칸이 그 앞에 오래 서 있다.', 'bad');
      else if (c.ledger === 'poor') journal(g, '벽의 숫자가 다시 늘었다. 꼬리칸이 한숨을 돌린다.', 'good');
    } else if (level === 'rich' && c.ledgerSegs > 0 && c.ledgerSegs % CALM.noteEvery === 0) {
      journal(g, '벽의 숫자를 보고 잠드는 사람이 늘었다.', 'good');
    }
    c.ledger = level;
  }
}

/** 이번 구간에 사람이 죽었으면 밤을 연다(정산에서 죽음이 다 난 뒤). 한 구간에 여럿이 죽어도 한 번이다. */
export function calmNight(g: Game): void {
  if (!lawActive(g, 'night_of_names')) return;
  const c = calmOf(g);
  const from = c.nightSeg ?? g.seg - 1;
  const fresh = (g.deathLog ?? []).filter(d => d.seg > from && d.seg <= g.seg);
  if (fresh.length === 0) return;
  c.nightSeg = g.seg;
  if (g.coal <= CALM.nightMinCoal) {
    journal(g, '이름을 부를 불이 없었다.', 'bad');
    return;
  }
  c.nights = (c.nights ?? 0) + 1;
  // 세 번째 밤부터 반, 사치품이 없어 어둡게 모이면 또 반. 값(석탄·사치품)은 그대로 든다.
  const k = (c.nights >= CALM.nightHalfFrom ? 0.5 : 1) * (g.lux <= 0 ? 0.5 : 1);
  g.coal -= CALM.nightCoal;
  g.lux = Math.max(0, g.lux - CALM.nightLux);
  g.fear = clamp(g.fear + CALM.nightFear * k, 0, 100);
  g.tension = clamp(g.tension + CALM.nightTension * k, 0, 100);
  const mourning = new Set<Comm>();
  for (const d of fresh) if (d.comm) mourning.add(d.comm);
  for (const k2 of mourning) g.comms[k2].rel = clamp(g.comms[k2].rel + CALM.nightRel * k, -100, 100);
  // 열차장이 고른 죽음(사살, 버림, 불길한 파견)이면 추모가 면죄부가 되지 않게 신임을 깎는다. 하차 장면의 죄책(disembark.ts)과 같은 기준이다.
  const chosen = fresh.some(d => d.cause !== 'other');
  if (chosen) g.trust = clamp(g.trust + CALM.chosenTrust, 0, 100);
  journal(g, `떠난 사람의 밤. 식당칸에 모여 ${fresh.map(d => d.name).join(', ')}의 이름을 불렀다.${chosen ? ' 그중에는 열차장이 고른 죽음이 있었다.' : ''}`, chosen ? 'bad' : 'good');
}
