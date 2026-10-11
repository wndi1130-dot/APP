import { describe, expect, it } from 'vitest';
import { createGame, enterStranded, resumeRun } from '../../src/game';
import { STALL_SECS, beatAt, stallBeats, stallCount, stallSecs } from '../../src/ui/stall_beats';

describe('멈춘 열차로 들어가는 연출의 박자', () => {
  it('처음은 달림 3초 뒤 느려짐·급제동·고요·판 열림으로 6.5초에 끝난다', () => {
    const spans = stallBeats(STALL_SECS.first);
    expect(spans.map(s => [s.beat, s.at, s.ms])).toEqual([
      ['run', 0, 3000], ['slow', 3000, 1000], ['brake', 4000, 1100], ['hush', 5100, 800], ['open', 5900, 600],
    ]);
  });

  it('길이를 줄이면 달림만 줄고 뒤의 네 박은 그대로다', () => {
    expect(stallBeats(4.5).map(s => [s.beat, s.at])).toEqual([['run', 0], ['slow', 1000], ['brake', 2000], ['hush', 3100], ['open', 3900]]);
    expect(stallBeats(3.5).map(s => s.beat)).toEqual(['slow', 'brake', 'hush', 'open']);
  });

  it('지난 때로 박을 찾고, 다 지나면 null이다', () => {
    const spans = stallBeats(6.5);
    expect(beatAt(spans, 0)).toBe('run');
    expect(beatAt(spans, 2999)).toBe('run');
    expect(beatAt(spans, 4000)).toBe('brake');
    expect(beatAt(spans, 6499)).toBe('open');
    expect(beatAt(spans, 6500)).toBeNull();
  });

  it('두 번째 멈춤부터는 짧은 길이를 쓴다', () => {
    const g = createGame('stall-beats');
    expect(stallCount(g)).toBe(0);
    enterStranded(g, 4, 10);
    expect(stallCount(g)).toBe(1);
    expect(stallSecs(stallCount(g))).toBe(STALL_SECS.first);
    resumeRun(g);
    enterStranded(g, 2, 10);
    expect(stallCount(g)).toBe(2);
    expect(stallSecs(stallCount(g))).toBe(STALL_SECS.again);
  });
});
