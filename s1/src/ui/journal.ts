import type { Game } from '../game';

type Entry = Game['journal'][number];

/** 일지에서 먼저 보일 줄: 거래, 선을 넘은 일, 나쁜 일. 일지 창과 끝 화면이 같이 쓴다. */
export function isKeyLine(e: Entry): boolean {
  return e.tone === 'deal' || e.tone === 'dark' || e.tone === 'bad';
}

export interface LogGroup {
  seg: number;
  /** 펼쳐 보일 줄(접혀 있으면 중요한 줄만, 펼치면 전부). 새 것이 위 */
  lines: Entry[];
  /** 접혀서 안 보이는 줄 수 */
  more: number;
  open: boolean;
}

/** 일지를 구간별로 묶는다. 새 구간이 위, 묶음 안에서도 새 줄이 위. 묶음마다 중요한 줄만 보이고 나머지는 수로 센다. */
export function logGroups(journal: Entry[], open: readonly number[], limit = 80): LogGroup[] {
  const groups: LogGroup[] = [];
  for (const e of [...journal].reverse().slice(0, limit)) {
    let g = groups[groups.length - 1];
    if (!g || g.seg !== e.seg) { g = { seg: e.seg, lines: [], more: 0, open: open.includes(e.seg) }; groups.push(g); }
    if (g.open || isKeyLine(e)) g.lines.push(e); else g.more += 1;
  }
  return groups;
}
