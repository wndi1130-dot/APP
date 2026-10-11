import { describe, expect, it } from 'vitest';
import { createGame } from '../../src/game';
import { LAWS } from '../../src/game/data';
import { bedNeed, bedOverflow } from '../../src/game/domestic/medbay';
import { enableDomestic } from '../../src/game/domestic/state';
import { D } from '../../src/game/domestic/data';
import { onDeath } from '../../src/game/death';
import { addWound, healCuts, liveWounds } from '../../src/game/wounds';
import { playGame } from '../../tools/s1c_bot';

// 잇기 ②(결정 055): 부상 정산이 명부 표로 돌고, 침상 셈이 명부를 읽는다.

const fresh = (seed: string) => { const g = createGame(seed); g.cards = []; return g; };

describe('날 수 줄이기(명세 4절)', () => {
  it('모두를 치료는 healDays −1로 새 부상의 날을 하루 줄이고, 옛 회복 확률 칸은 없다', () => {
    expect(LAWS.treat_all.res.healDays).toBe(-1);
    expect('heal' in LAWS.treat_all.res).toBe(false);
    const g = fresh('ws-1');
    expect(healCuts(g)).toBe(0);
    g.passed.treat_all = g.session;
    expect(healCuts(g)).toBe(1);
  });
});

describe('침상 셈이 명부를 읽는다', () => {
  it('가벼운 상처는 침상을 안 쓰고, 침상·제 칸 기록과 명부 밖 부상자는 쓴다', () => {
    const g = fresh('ws-2');
    enableDomestic(g);
    addWound(g, { who: '가', comm: 'tail', from: 'stop', where: '시험', grade: 'light', part: 'armL', septic: false });
    expect(bedNeed(g)).toBe(0);
    addWound(g, { who: '나', comm: 'tail', from: 'stop', where: '시험', grade: 'deep', part: 'torso', septic: false });
    expect(bedNeed(g)).toBe(1);
    g.injured += 2; // 명부 밖에서 오른 몫(hub.ts)
    expect(bedNeed(g)).toBe(3);
    g.injured = 0;
    for (let i = 0; i < D.beds + 2; i += 1) addWound(g, { who: `침${i}`, comm: 'tail', from: 'stop', where: '시험', grade: 'deep', part: 'torso', septic: false });
    expect(bedOverflow(g)).toBeGreaterThan(0);
  });
});

describe('다친 사람이 죽으면', () => {
  it('부상자 수에서도 빠지고, 다음 정산이 산 사람을 대신 다치게 채우지 않는다', () => {
    const g = fresh('ws-3');
    addWound(g, { who: '가', comm: 'tail', from: 'stop', where: '시험', grade: 'deep', part: 'torso', septic: false });
    addWound(g, { who: '나', comm: 'tail', from: 'stop', where: '시험', grade: 'deep', part: 'torso', septic: false });
    expect(g.injured).toBe(2);
    onDeath(g, 'tail', ['가']);
    expect(g.injured).toBe(1);
    expect(liveWounds(g).map(w => w.who)).toEqual(['나']);
    onDeath(g, 'tail', ['다']); // 다치지 않은 사람의 죽음은 부상자 수를 건드리지 않는다
    expect(g.injured).toBe(1);
  });
});

describe('판을 끝까지 돌리면', () => {
  it('정산을 마친 시점마다 g.injured는 명부의 활성 기록 수와 같다', () => {
    let bad = 0; let n = 0;
    const probe = { onSettle: (g: ReturnType<typeof createGame>) => { n += 1; if (liveWounds(g).length !== g.injured) bad += 1; } };
    for (const seed of ['ws-bot-1', 'ws-bot-2', 'ws-bot-3', 'ws-x-0']) playGame(seed, { s1c: true, s1b: 'cruel', policy: 'caretaker', dom: 'engaged', probe } as never);
    expect(n).toBeGreaterThan(30);
    expect(bad).toBe(0);
  }, 120000);
});
