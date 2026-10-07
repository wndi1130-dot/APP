import { COMM_NAME, P } from './data';
import type { Comm } from './data';
import { clamp, journal, lawActive } from './state';
import type { Game } from './state';
import { afterDeath } from './people';

/** 죽음의 원인. chosen: 열차장이 고른 일로 죽음(사살, 버림, 숨긴 물림). warned: '매우 불길하다'를 보고도 보낸 파견.
 * other: 그 밖(추위, 굶주림, 병, 약속 밖의 사고). 하차 장면이 죄책감과 애도를 가른다(presentation_motion, 2026-10-07). */
export type DeathCause = 'chosen' | 'warned' | 'other';

export function logDeath(g: Game, names: readonly string[], cause: DeathCause, witness = false): void {
  for (const name of names) (g.deathLog ??= []).push({ seg: g.seg, name, cause, ...(witness ? { witness } : {}) });
}

/** 죽은 사람은 일어난다. 시신 처리 법이 대가를 정한다(브리프 8.2). */
export function onDeath(g: Game, c: Comm, names: readonly string[], cause: DeathCause = 'other', witness = false): void {
  const n = names.length;
  if (n <= 0) return;
  g.comms[c].pop = Math.max(1, g.comms[c].pop - n);
  g.deaths.push(...names);
  logDeath(g, names, cause, witness);
  if (lawActive(g, 'corpse_throw')) {
    g.thrown += n;
  } else if (lawActive(g, 'corpse_store')) {
    g.stored += n;
    g.comms.tail.base[2] += n;
  } else if (lawActive(g, 'corpse_burn')) {
    // 다음에 내리는 정차까지 냉동칸(찬 객차)에 두었다가 선로 옆 장작불에서 태운다(s1c_domestic 4.1).
    // 냉동칸은 안치한 시신과 함께 6구까지. 넘치면 살던 칸에 둔다.
    const inCar = Math.min(n, Math.max(0, P.coldCap - g.stored - (g.pyre ?? 0)));
    g.pyre = (g.pyre ?? 0) + inCar;
    const over = n - inCar;
    if (over > 0) {
      const kin = (g.pyreKin ??= {});
      kin[c] = (kin[c] ?? 0) + over;
      g.comms[c].base[2] += P.pyreKinCrowd * over;
      journal(g, `냉동칸이 찼다. 시신 ${over}구를 ${COMM_NAME[c]}에 둔다.`, 'dark');
    }
  } else {
    // 정한 법이 없으면 누가 치울지 다투고, 일단 밖으로 던진다.
    if (!g.corpseIssue) journal(g, '첫 시신을 두고 다툼이 났다. 시신 처리가 안건에 올랐다.', 'bad');
    g.corpseIssue = true;
    g.tension = clamp(g.tension + 3 * n, 0, 100);
    g.thrown += n;
  }
  journal(g, `${COMM_NAME[c]}의 ${names.join(', ')}이(가) 죽었다.`, 'bad');
  afterDeath(g, c, names);
}
