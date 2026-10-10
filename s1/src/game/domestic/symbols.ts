import { COMM_NAME } from '../data';
import type { Comm } from '../data';
import { clamp, journal } from '../state';
import type { Game } from '../state';

// 상징물 걸기(S1c, 제안). 가진 상징물(g.symbols)을 칸에 걸어 두면 그 칸 결속이 구간마다 조금 오르고,
// 내리거나 잃으면 한 번 크게 깎인다. 상징물 개수는 걸거나 내려도 그대로다(걸린 것도 가진 것이다).
// 내정(g.dom)을 켠 판에서만 돈다. 난수를 쓰지 않는다. 봇·시뮬은 걸지 않으니 기존 판 결과는 그대로다.

/** 모두 제안. 결속(coh)은 0~1 척도라 1이 아니라 0.01이 '조금'이다(시작 0.55~0.85, 사건 하나가 0.02~0.05, 처형 같은 큰 일이 0.2).
 * 관계(rel)는 -100~100 척도(불결 −1, 매장 +1, 기술 ±5, 입환 −8)라 4가 '한 번 크게'다. */
export const SYM = { cohPerSeg: 0.01, lossCoh: 0.08, lossRel: 4 } as const;

/** 못 거는 까닭. 걸 수 있으면 null. */
export function hangWhy(g: Game, c: Comm): string | null {
  const d = g.dom;
  if (!d) return '내정을 켠 판에서만 쓴다.';
  if (d.hung.includes(c)) return '이 칸에는 이미 걸려 있다.';
  if (g.symbols - d.hung.length < 1) return '걸 수 있는 상징물이 없다. 이미 건 것뿐이거나 하나도 없다.';
  return null;
}

/** 한 칸에서 상징물이 빠질 때의 깎임: 결속·관계를 한 번 깎는다. */
function lose(g: Game, c: Comm): void {
  const s = g.comms[c];
  s.coh = clamp(s.coh - SYM.lossCoh, 0, 1);
  s.rel = clamp(s.rel - SYM.lossRel, -100, 100);
}

/** 상징물을 건다. 걸었으면 true. */
export function hangSymbol(g: Game, c: Comm): boolean {
  if (hangWhy(g, c) !== null) return false;
  g.dom!.hung.push(c);
  journal(g, `${COMM_NAME[c]} 칸에 상징물을 걸었다. 걸어 두는 동안 결속이 조금씩 오른다.`);
  return true;
}

/** 상징물을 내린다(내린 칸은 한 번 크게 깎인다). 걸려 있었으면 true. */
export function unhangSymbol(g: Game, c: Comm): boolean {
  const d = g.dom;
  const i = d ? d.hung.indexOf(c) : -1;
  if (!d || i < 0) return false;
  d.hung.splice(i, 1);
  lose(g, c);
  journal(g, `${COMM_NAME[c]} 칸에서 상징물을 내렸다. 결속이 크게 꺾이고 관계가 상했다.`, 'bad');
  return true;
}

/** 정산 때 한 번: 가진 것보다 많이 걸려 있으면(사건·이탈로 상징물을 내줬다) 나중에 건 칸부터 넘친 만큼 내리고, 남은 칸은 결속이 오른다. */
export function symbolTick(g: Game, notes: string[]): void {
  const d = g.dom;
  if (!d) return;
  while (d.hung.length > Math.max(0, g.symbols)) {
    const c = d.hung.pop()!;
    lose(g, c);
    notes.push(`상징물을 잃어 ${COMM_NAME[c]} 칸에서 내려졌다. 결속이 크게 꺾이고 관계가 상했다.`);
  }
  for (const c of d.hung) g.comms[c].coh = clamp(g.comms[c].coh + SYM.cohPerSeg, 0, 1);
}
