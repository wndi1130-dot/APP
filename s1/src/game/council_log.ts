import { COMM_NAME, LAW_IDS, LAWS } from './data';
import type { Comm } from './data';
import { josa } from './josa';
import { bumpRel } from './ledger';
import { addCard, journal, lawActive } from './state';
import type { Game } from './state';

// 회기 기록부와 결과 아크(정치 흐름 설계 2·3장, 결정 439). 새 계기가 아니라 기록이다.
// 기록부는 최근 줄만 남기고, 약속 누계(comms[c].kept·broken)와 영구 제한(openClosed)은 판 끝까지 따로 남는다(6.1 sol 검수 3).

/** 결과 아크 값(제안, 봇으로 정한다). */
export const ARC = {
  /** 같은 칸과의 약속을 이만큼 어기면 그 칸 대표가 약속 장부를 들고 온다 */
  ledgerAt: 2,
  /** 이만큼 어기면 그 칸과 공개 협상·현장 조달이 판 끝까지 닫힌다 */
  closeAt: 3,
  /** 안건 선택권을 넘긴 칸의 안건이 이만큼 이어 부결되면 서운해한다 */
  heldFails: 2,
  heldRel: -5,
  /** 가혹한 법이 이만큼 서 있는데 약속을 어기면 「말과 법이 다르다」 */
  harshLaws: 3,
  harshRel: -3,
} as const;

export const LOG_MAX = 24;

export type LogKind = 'enact' | 'repeal' | 'amend' | 'ratify' | 'motion' | 'decree';

export interface CouncilLogRow {
  session: number;
  seg: number;
  title: string;
  kind: LogKind;
  /** 안건을 올린 쪽: AI 칸이면 그 칸, 아니면 열차장 */
  by: Comm | 'chief';
  passed: boolean;
  yes: number;
  no: number;
  absent: number;
  need: number;
  exp: { mean: number; min: number; max: number };
  /** 개표 설명 한 줄(기대와 결과가 가장 크게 다른 칸) */
  why?: string;
}

export function logVote(g: Game, row: CouncilLogRow): void {
  const log = (g.councilLog ??= []);
  log.push(row);
  if (log.length > LOG_MAX) log.splice(0, log.length - LOG_MAX);
}

/** 지금 서 있는 가혹한 법 수 */
function harshCount(g: Game): number {
  return LAW_IDS.filter(l => LAWS[l].tag === '가혹' && lawActive(g, l)).length;
}

/** 약속을 어긴 직후(s.broken을 올린 뒤) 부른다. */
export function noteBroken(g: Game, c: Comm): void {
  const s = g.comms[c];
  const n = s.broken ?? 0;
  const name = COMM_NAME[c];
  if (harshCount(g) >= ARC.harshLaws) {
    bumpRel(g, c, ARC.harshRel, 'arc');
    journal(g, `${name}에서 말이 돈다: "법은 모질게 세우면서 약속은 가볍게 어긴다."`, 'bad');
  }
  if (n === ARC.ledgerAt) addCard(g, { kind: 'promise_ledger', comm: c });
  if (n >= ARC.closeAt && !s.openClosed) {
    s.openClosed = true;
    journal(g, `${name}${josa(name, '은/는')} 더는 열차장의 약속을 받지 않는다.`, 'bad');
  }
}

/** 표결 뒤: 안건 선택권을 넘긴 칸의 안건이 부결되면 센다. 가결이면 셈을 지운다. */
export function noteHeld(g: Game, c: Comm, passed: boolean): void {
  const s = g.comms[c];
  if (passed) { s.heldFails = 0; return; }
  s.heldFails = (s.heldFails ?? 0) + 1;
  if (s.heldFails < ARC.heldFails) return;
  s.heldFails = 0;
  bumpRel(g, c, ARC.heldRel, 'arc');
  const name = COMM_NAME[c];
  journal(g, `${name}${josa(name, '이/가')} 고른 안건이 또 떨어졌다. 들러리를 섰다고 여긴다.`, 'bad');
}
