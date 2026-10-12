import { describe, expect, it } from 'vitest';
import { COMM_NAME, COMMS, createGame, keepPromise, VOICE, VOICE_ANY, voiceFor } from '../../src/game';

// 약속을 지켰을 때 그 칸 사람의 말 한 줄(결정 184). 값은 그대로이고 일지 줄만 하나 늘며, 고르는 데 주사위가 없다.

describe('약속 지킴의 말은 지킨 수로 차례로 고른다', () => {
  it('첫째·둘째는 그 칸의 줄, 셋째부터는 어느 칸에나 쓰는 셋을 차례로 돈다', () => {
    for (const c of COMMS) {
      expect(voiceFor(c, 1)).toBe(VOICE[c][0]);
      expect(voiceFor(c, 2)).toBe(VOICE[c][1]);
      expect([3, 4, 5, 6].map(n => voiceFor(c, n))).toEqual([VOICE_ANY[0], VOICE_ANY[1], VOICE_ANY[2], VOICE_ANY[0]]);
    }
  });

  it('말은 칸마다 둘, 어느 칸에나 셋이고 같은 칸의 말이 두 번 이어 나오지 않는다', () => {
    expect(COMMS.map(c => VOICE[c].length)).toEqual([2, 2, 2, 2, 2]);
    expect(VOICE_ANY).toHaveLength(3);
    for (const c of COMMS) for (let n = 1; n < 30; n += 1) expect(voiceFor(c, n + 1)).not.toBe(voiceFor(c, n));
  });

  it('말에 숫자가 없다', () => {
    for (const line of [...COMMS.flatMap(c => VOICE[c]), ...VOICE_ANY]) expect(line).not.toMatch(/\d/);
  });
});

describe('keepPromise는 값을 그대로 두고 말 한 줄을 잇는다', () => {
  it('신임 +4·관계 +5·지킨 수 +1은 그대로이고, 일지에 사실 줄 다음 말 줄이 붙는다', () => {
    const g = createGame('voice-1');
    const before = { trust: g.trust, rel: g.comms.tail.rel, kept: g.stats.promisesKept, rng: g.rng, len: g.journal.length };
    keepPromise(g, 'tail', '시험');
    expect(g.trust - before.trust).toBe(4);
    expect(g.comms.tail.rel - before.rel).toBe(5);
    expect(g.stats.promisesKept).toBe(before.kept + 1);
    expect(g.rng).toEqual(before.rng); // 주사위를 굴리지 않는다
    const added = g.journal.slice(before.len);
    expect(added).toHaveLength(2);
    expect(added[0].text).toBe(`${COMM_NAME.tail}과(와)의 약속을 지켰다: 시험.`);
    expect(added[1]).toEqual({ seg: g.seg, text: `${COMM_NAME.tail}: 「${VOICE.tail[0]}」`, tone: 'deal' });
  });

  it('같은 칸을 거듭 지키면 둘째 줄, 어느 칸에나 쓰는 줄로 이어지고 칸마다 따로 센다', () => {
    const g = createGame('voice-2');
    const said = (): string => g.journal[g.journal.length - 1].text;
    keepPromise(g, 'guard', 'a'); keepPromise(g, 'tail', 'b');
    expect(said()).toContain(VOICE.tail[0]);
    keepPromise(g, 'guard', 'c');
    expect(said()).toContain(VOICE.guard[1]);
    keepPromise(g, 'guard', 'd');
    expect(said()).toContain(VOICE_ANY[0]);
  });
});
