import { describe, expect, it } from 'vitest';
import { COMMS, createGame, openConditions } from '../../src/game';

// R3 대조에서 나온 거래 허점(2026-10-07): 다음 안건 선택권을 같은 회기에 두 칸에 팔면
// 먼저 받은 칸의 몫이 위반 처리도 없이 사라졌다.

describe('다음 안건 선택권', () => {
  it('누가 이미 쥐었으면 다른 칸에 다시 내놓지 않는다', () => {
    const g = createGame('deal-agenda');
    const offered = () => COMMS.filter(c => openConditions(g, c).some(x => x.kind === 'agenda'));
    // 회기에 따라 공통 조건이 돌아가므로 선택권이 나오는 회기를 찾는다.
    for (let s = 0; s < 4 && offered().length === 0; s += 1) g.session += 1;
    expect(offered().length).toBeGreaterThan(0);
    g.agendaHolder = 'tail';
    expect(offered()).toEqual([]);
    for (const c of COMMS) expect(openConditions(g, c)).toHaveLength(3);
  });
});
