import { describe, expect, it } from 'vitest';
import { createGame, createS1cGame, fallSick, viewCard } from '../../src/game';

describe('S1c 측근 겸직(8.1, J10 8번): 대표가 앓으면 견습 화부·약사가 대신 나온다', () => {
  it('기관실은 견습 화부, 앞칸은 약사', () => {
    for (const seed of ['aide-a', 'aide-b', 'aide-c']) {
      const g = createS1cGame(seed);
      const role = (r: string) => g.dom!.people.find(p => p.role === r)!.name;
      fallSick(g, 'engine');
      fallSick(g, 'front');
      expect(g.comms.engine.leader.name).toBe(role('견습 화부'));
      expect(g.comms.front.leader.name).toBe(role('약사'));
    }
  });

  it('그 사람이 없으면 예전처럼 새로 뽑는다', () => {
    const g = createS1cGame('aide-gone');
    const stoker = g.dom!.people.find(p => p.role === '견습 화부')!;
    stoker.alive = false;
    fallSick(g, 'engine');
    expect(g.comms.engine.leader.name).not.toBe(stoker.name);
    expect(g.comms.engine.sick).toBeTruthy();
  });

  it('S1a 판은 그대로 새로 뽑는다', () => {
    const g = createGame('aide-s1a');
    const rep = g.comms.engine.leader.name;
    fallSick(g, 'engine');
    expect(g.comms.engine.leader.name).not.toBe(rep);
  });
});

describe('열병 카드 본문', () => {
  it('조건 문장이 한 번만 나온다', () => {
    const g = createS1cGame('typhus-body');
    const v = viewCard(g, { uid: 1, kind: 'dom:typhus', comm: 'tail', n: 3 });
    expect(v.body.split('붐비고 담요를 같이 덮는 칸').length - 1).toBe(1);
  });
});
