import { COMM_NAME } from './data';
import type { Comm } from './data';
import { clamp, journal, lawActive } from './state';
import type { Game } from './state';

/** 죽은 사람은 일어난다. 시신 처리 법이 대가를 정한다(브리프 8.2). */
export function onDeath(g: Game, c: Comm, names: readonly string[]): void {
  const n = names.length;
  if (n <= 0) return;
  g.comms[c].pop = Math.max(1, g.comms[c].pop - n);
  g.deaths.push(...names);
  if (lawActive(g, 'corpse_throw')) {
    g.thrown += n;
  } else if (lawActive(g, 'corpse_store')) {
    g.stored += n;
    g.comms.tail.base[2] += n;
  } else if (lawActive(g, 'corpse_burn')) {
    g.coal += 2 * n;
    g.comms.tail.rel = clamp(g.comms.tail.rel - 3 * n, -100, 100);
  } else {
    // 정한 법이 없으면 누가 치울지 다투고, 일단 밖으로 던진다.
    if (!g.corpseIssue) journal(g, '첫 시신을 두고 다툼이 났다. 시신 처리가 안건에 올랐다.', 'bad');
    g.corpseIssue = true;
    g.tension = clamp(g.tension + 3 * n, 0, 100);
    g.thrown += n;
  }
  journal(g, `${COMM_NAME[c]}의 ${names.join(', ')}이(가) 죽었다.`, 'bad');
}
