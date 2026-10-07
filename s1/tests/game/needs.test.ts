import { describe, expect, it } from 'vitest';
import {
  advance, agendaOptions, callEmergency, castVote, createGame, emergencyCost, emergencyStatus, enactLaw, HUNGER_GRACE, NEED_GRACE,
  needTick, resolveStop, blocs, setAgenda, chooseCard, viewCard, SECRET_POOL, setAutoLevers,
} from '../../src/game';
import type { Game } from '../../src/game';

// 법 요구(예고 뒤 손해), 비상 소집, 식량 0 버티기(2026-10-07 사용자 후기).

function clear(g: Game) { g.cards = []; }

describe('법 요구', () => {
  it('문제가 생기면 먼저 예고하고, 기한이 지나도 법이 없으면 손해가 난다', () => {
    const g = createGame('need-1');
    g.coal = 45;
    const notes: string[] = [];
    needTick(g, notes);
    expect(g.needs.coal).toMatchObject({ since: g.seg, due: g.seg + NEED_GRACE, hits: 0 });
    expect(g.cards.some(c => c.kind === 'info' && c.who?.includes('필요'))).toBe(true);
    const coal = g.coal;
    g.seg += NEED_GRACE - 1;
    needTick(g, notes);
    expect(g.coal).toBe(coal);
    g.seg += 1;
    const trust = g.trust;
    needTick(g, notes);
    expect(g.coal).toBeLessThan(coal);
    expect(g.trust).toBeLessThan(trust);
    expect(g.needs.coal?.hits).toBe(1);
  });

  it('같은 묶음의 어느 법이든 통과하면 요구가 풀린다', () => {
    const g = createGame('need-2');
    g.food = 40;
    needTick(g, []);
    expect(g.needs.food).toBeDefined();
    enactLaw(g, 'common_kitchen', []);
    needTick(g, []);
    expect(g.needs.food).toBeUndefined();
  });

  it('요구가 걸린 안건이 의회 안건 목록 앞쪽에 온다', () => {
    const g = createGame('need-3');
    g.injured = 5;
    needTick(g, []);
    const { options } = agendaOptions(g);
    expect(['treat_all', 'triage', 'no_outsiders']).toContain(options[0].law);
  });
});

function toStopDone(g: Game, seg: number) {
  g.seg = seg;
  g.phase = 'prep';
  clear(g);
  advance(g); clear(g);
  advance(g); clear(g);
  resolveStop(g, true);
  clear(g);
}

describe('비상 소집', () => {
  it('회기가 아닌 구간에 정차를 마치면 신임을 써서 부를 수 있다', () => {
    const g = createGame('em-1');
    toStopDone(g, 2);
    expect(emergencyStatus(g)).toMatchObject({ show: true, ok: true });
    const trust = g.trust;
    const cost = emergencyCost(g);
    expect(callEmergency(g)).toBe(true);
    expect(g.phase).toBe('council');
    expect(g.council?.emergency).toBe(true);
    expect(g.trust).toBe(trust - cost);
    expect(emergencyCost(g)).toBeGreaterThan(cost);
  });

  it('정기 회기 구간에는 비상 소집 단추가 없다', () => {
    const g = createGame('em-2');
    toStopDone(g, 3);
    expect(emergencyStatus(g).show).toBe(false);
    expect(callEmergency(g)).toBe(false);
  });

  it('반대하는 칸이 밖에 나간 사이 통과시키면 기습으로 기억된다', () => {
    let found = false;
    for (let i = 0; i < 40 && !found; i += 1) {
      const g = createGame(`em-ambush-${i}`);
      toStopDone(g, 2);
      if (!callEmergency(g)) continue;
      const idx = g.council!.options.findIndex(o => Object.values(blocs(g, o)).some(b => b.absent > 0 && b.score < 0));
      if (idx < 0) continue;
      setAgenda(g, idx);
      const before = { ...Object.fromEntries(Object.entries(g.comms).map(([c, s]) => [c, s.grudge])) };
      const r = castVote(g, true);
      if (!r) continue;
      const ambushed = g.journal.some(j => j.text.includes('기습'));
      if (ambushed) {
        found = true;
        expect(Object.entries(g.comms).some(([c, s]) => s.grudge > (before[c] ?? 0))).toBe(true);
      }
    }
    expect(found).toBe(true);
  });
});

describe('식량 0', () => {
  it('얼마간 버티다 기한을 넘기면 굶어 죽는 사람이 나온다', () => {
    const g = createGame('hunger');
    const deaths = () => g.deaths.length;
    for (let i = 0; i < HUNGER_GRACE + 2; i += 1) {
      g.food = 0;
      g.phase = 'council';
      g.council = null;
      clear(g);
      const before = deaths();
      advance(g);
      if (i < HUNGER_GRACE) expect(deaths(), `구간 ${i + 1}`).toBe(before);
      else expect(deaths(), `구간 ${i + 1}`).toBeGreaterThan(before);
      g.phase = 'council';
    }
  });
});

describe('숨긴 물림', () => {
  function hide(seed: string) {
    const g = createGame(seed);
    g.cards = [{ uid: 1, kind: 'bitten', comm: 'tail', who: '대원' }];
    g.nextCardUid = 2;
    expect(chooseCard(g, 1, 1)).toBe(true);
    return g;
  }

  it('숨기면 비밀이 아니라 2구간 시계가 걸린다', () => {
    const g = hide('bite-hide');
    expect(g.hiddenBites).toEqual([{ who: '대원', comm: 'tail', at: g.seg, due: g.seg + 2 }]);
  });

  it('귀환 검사 법이 있으면 첫 정산에 드러나고, 그 구간 안이면 아직 자를 수 있다', () => {
    const g = hide('bite-patrol');
    enactLaw(g, 'patrol', []);
    g.phase = 'council'; g.council = null; g.cards = [];
    advance(g);
    const found = g.cards.find(c => c.kind === 'bite_found');
    expect(found).toBeDefined();
    expect(viewCard(g, found!).choices[0].disabled).toBeFalsy();
  });

  it('들키지 않으면 기한에 칸 안에서 일어나 사람을 문다', () => {
    let rose = false;
    for (let i = 0; i < 20 && !rose; i += 1) {
      const g = hide(`bite-rise-${i}`);
      for (let k = 0; k < 3 && !rose; k += 1) {
        g.phase = 'council'; g.council = null;
        if (g.cards.some(c => c.kind === 'bite_found')) break;
        g.cards = [];
        const injured = g.injured;
        advance(g);
        if (g.journal.some(j => j.text.includes('안에서 일어났다'))) {
          rose = true;
          expect(g.injured).toBeGreaterThan(injured);
          expect(g.deaths).toContain('대원');
        }
        g.seg += 1;
      }
    }
    expect(rose).toBe(true);
  });

  it('숨긴 물림은 더는 비밀 풀에 없다', () => {
    expect(SECRET_POOL.some(s => s.text === '물린 걸 숨기고 있다')).toBe(false);
  });
});

describe('배급장 맡기기 조건', () => {
  it('정차 여섯 번을 지나야 열리고, 앞칸 지지가 떨어지면 장부를 내려놓는다', () => {
    const g = createGame('delegate');
    setAutoLevers(g, true);
    expect(g.autoLevers).toBe(false);
    g.seg = 7;
    g.comms.front.rel = 30;
    setAutoLevers(g, true);
    expect(g.autoLevers).toBe(true);
    g.comms.front.rel = 0;
    g.phase = 'settle'; g.cards = [];
    advance(g);
    expect(g.autoLevers).toBe(false);
    expect(g.cards.some(c => c.who?.includes('장부'))).toBe(true);
  });
});
