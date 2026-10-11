import { describe, expect, it } from 'vitest';
import { createGame, drain, forecast, potView, rnd, situation } from '../../src/game';
import type { Game } from '../../src/game';
import { COMMS } from '../../src/game/data';
import { bedNeed } from '../../src/game/domestic/beds';
import { D } from '../../src/game/domestic/data';
import { potActive, potCook, potOf, potRisk, potSick, potSickRisk, potTick, potUsable, setPot, setPotCook } from '../../src/game/domestic/pot';
import { enableDomestic } from '../../src/game/domestic/state';
import { workPower } from '../../src/game/domestic/workshop';
import { playGame } from '../../tools/s1c_bot';

// 식당칸 솥의 불리기 세 단계(food_cooking 4.5). 숫자는 제안이다(domestic/data.ts pot*).
// 시험은 값에 묶이지 않는다: 기본값은 D에서 읽어 견주고, 켜고 끌 수 있는 규칙은 withD로 값을 잠깐 못박아 본다.

/** 내정을 켠 새 판. 담당은 세우지 않는다. */
const bare = (seed: string): Game => { const g = createGame(seed); g.cards = []; enableDomestic(g); return g; };
const anyone = (g: Game): string => g.dom!.people.find(p => p.alive && !p.gone)!.id;
/** 솥 담당까지 세운 판. 담당 칸과 사이가 나빠 들킬 확률이 더해지는 일이 없게 관계를 0 위로 둔다. */
const fresh = (seed: string): Game => {
  const g = bare(seed);
  setPotCook(g, anyone(g));
  g.comms[potCook(g)!.comm].rel = 10;
  return g;
};
/** D의 값을 잠깐 바꿔 돌리고 되돌린다. */
function withD<T>(over: Partial<typeof D>, fn: () => T): T {
  const keep = { ...D };
  Object.assign(D, over);
  try { return fn(); } finally { Object.assign(D, keep); }
}
/** 판 난수는 씨앗으로만 정해진다. 바라는 판정(들킴, 탈)이 나올 때까지 난수 흐름을 한 칸씩 넘긴 뒤 솥 한 구간을 돌린다. */
function roll(g: Game, want: { caught?: boolean; sick?: boolean } = {}): string[] {
  for (let i = 0; i < 4000; i += 1) {
    const probe = structuredClone(g);
    const c0 = potOf(probe).caught;
    const s0 = potOf(probe).sickHits ?? 0;
    potTick(probe, []);
    if ((potOf(probe).caught > c0) === !!want.caught && ((potOf(probe).sickHits ?? 0) > s0) === !!want.sick) {
      const notes: string[] = [];
      potTick(g, notes);
      return notes;
    }
    rnd(g);
  }
  throw new Error('바라는 판정이 나오는 난수를 못 찾았다');
}

describe('기본은 그대로다', () => {
  it('고르지 않은 판은 솥 칸이 없고 식량 예고·처지·난수가 그대로다', () => {
    const g = bare('pot-0');
    const rng = JSON.stringify(g.rng);
    const before = forecast(g).food;
    const notes: string[] = [];
    potTick(g, notes);
    expect(g.dom?.pot).toBeUndefined();
    expect(forecast(g).food).toBe(before);
    expect(JSON.stringify(g.rng)).toBe(rng);
    expect(notes).toEqual([]);
    setPot(g, 'plain');
    setPotCook(g, null);
    expect(g.dom?.pot).toBeUndefined();
  });

  it('담당만 세우고 그대로 둔 판도 식량 예고와 난수가 그대로다', () => {
    const g = bare('pot-0b');
    const rng = JSON.stringify(g.rng);
    const before = forecast(g).food;
    setPotCook(g, anyone(g));
    potTick(g, []);
    expect(forecast(g).food).toBe(before);
    expect(JSON.stringify(g.rng)).toBe(rng);
  });

  it('내정을 끈 판에서는 고를 수 없다', () => {
    const g = createGame('pot-off');
    setPot(g, 'thin');
    expect(potOf(g).mode).toBe('plain');
    expect(potView(g).on).toBe(false);
    expect(potView(g).choices.map(c => c.mode)).toEqual(['plain']);
  });

  it('봇이 솥을 건드리지 않으면 내정 판은 끝까지 솥 칸이 없다', () => {
    const { g } = playGame('pot-bot', { s1c: true, policy: 'caretaker', dom: 'engaged' });
    expect(g.dom?.pot).toBeUndefined();
  });
});

describe('조리 담당', () => {
  it('담당이 문인 판에서는 담당이 없으면 묽게도 섞어서도 못 고른다', () => {
    withD({ potCook: 1 }, () => {
      const g = bare('pot-c1');
      setPot(g, 'thin');
      expect(potOf(g).mode).toBe('plain');
      expect(potUsable(g, 'mixed')).toEqual({ ok: false, why: '담당 없음' });
      expect(potView(g)).toMatchObject({ cookNeeded: true, potCook: null });
      const id = anyone(g);
      setPotCook(g, id);
      setPot(g, 'thin');
      expect(potOf(g).mode).toBe('thin');
      expect(potView(g).potCook).toMatchObject({ id, comm: potCook(g)!.comm });
    });
  });

  it('담당이 문이 아닌 판에서는 담당 없이 고른다', () => {
    withD({ potCook: 0 }, () => {
      const g = bare('pot-c2');
      setPot(g, 'thin');
      expect(potOf(g).mode).toBe('thin');
      expect(potView(g).cookNeeded).toBe(false);
    });
  });

  it('없는 사람은 못 세우고, 담당을 세운 동안 공방 작업량이 줄며 내리면 돌아온다', () => {
    withD({ potCook: 1 }, () => {
      const g = bare('pot-c3');
      const w0 = workPower(g);
      setPotCook(g, '없는-사람');
      expect(potCook(g)).toBeUndefined();
      setPotCook(g, anyone(g));
      expect(workPower(g)).toBeCloseTo(w0 * D.potCookWork, 10);
      setPotCook(g, null);
      expect(workPower(g)).toBeCloseTo(w0, 10);
    });
  });

  it('담당이 사라지면 솥이 그대로로 돌아간다', () => {
    withD({ potCook: 1 }, () => {
      const g = fresh('pot-c4');
      setPot(g, 'thin');
      potCook(g)!.alive = false;
      const notes: string[] = [];
      potTick(g, notes);
      expect(potOf(g).mode).toBe('plain');
      expect(notes).toContain('솥을 맡은 사람이 없어 솥이 그대로로 돌아갔다.');
    });
  });

  it('담당이 사는 칸이 등을 돌렸으면 들킬 확률이 더해진다', () => {
    withD({ potCook: 1, potCookRisk: 0.1 }, () => {
      const g = fresh('pot-c5');
      const base = potRisk(g);
      g.comms[potCook(g)!.comm].rel = -1;
      expect(potRisk(g)).toBeCloseTo(base + 0.1, 10);
    });
  });
});

describe('묽게', () => {
  it('식량 소모에 묽게 곱이 걸리고 모든 칸 배급 처지가 내려간다. 그대로로 돌리면 되돌아온다', () => {
    const g = fresh('pot-1');
    const dom0 = forecast(g).food;
    const sit0 = COMMS.map(c => situation(g, c)[1]);
    setPot(g, 'thin');
    const v = potView(g);
    const plain = v.choices.find(c => c.mode === 'plain')!.food;
    expect(plain).toBeCloseTo(dom0, 10);
    expect(forecast(g).food).toBeCloseTo(v.food, 10);
    expect(v.saved).toBeGreaterThan(0);
    // 내정의 덧셈 몫(온실·가족 특혜)이 0인 새 판에서는 통째로 묽게 곱이다.
    expect(forecast(g).food).toBeCloseTo(dom0 * D.potThinFood, 10);
    COMMS.forEach((c, i) => expect(situation(g, c)[1]).toBe(Math.max(0, sit0[i] - D.potThinSit)));
    setPot(g, 'plain');
    COMMS.forEach((c, i) => expect(situation(g, c)[1]).toBe(sit0[i]));
    expect(forecast(g).food).toBeCloseTo(dom0, 10);
  });

  it('잇달아 쓴 구간을 세고, 쉬면 처음으로 돌아가며, 난수는 굴리지 않는다', () => {
    withD({ potGruelRun: 0 }, () => {
      const g = fresh('pot-2');
      setPot(g, 'thin');
      const rng = JSON.stringify(g.rng);
      potTick(g, []);
      potTick(g, []);
      expect(potOf(g).thinRun).toBe(2);
      expect(potView(g).gruelIn).toBeNull();
      expect(JSON.stringify(g.rng)).toBe(rng);
      setPot(g, 'plain');
      potTick(g, []);
      expect(potOf(g).thinRun).toBe(0);
      expect(potOf(g).thinSegs).toBe(2);
    });
  });

  it('묽은 죽: 정한 구간만큼 잇달으면 긴장이 오르고 다시 처음부터 센다. 난수는 굴리지 않는다', () => {
    withD({ potGruelRun: 3, potGruelTension: 5 }, () => {
      const g = fresh('pot-2g');
      g.tension = 30;
      setPot(g, 'thin');
      const rng = JSON.stringify(g.rng);
      expect(potView(g).gruelIn).toBe(3);
      potTick(g, []);
      potTick(g, []);
      expect(g.tension).toBe(30);
      expect(potView(g).gruelIn).toBe(1);
      drain(g);
      const notes: string[] = [];
      potTick(g, notes);
      expect(g.tension).toBe(35);
      expect(drain(g).map(r => [r.k, r.why])).toEqual([['tension', 'pot']]);
      expect(potOf(g)).toMatchObject({ thinRun: 0, thinSegs: 3, gruel: 1, mode: 'thin' });
      expect(notes).toEqual(['묽은 죽이 이어져 불만이 커졌다.']);
      expect(JSON.stringify(g.rng)).toBe(rng);
    });
  });

  it('두 구간 쓰고 한 구간 쉬면 묽은 죽이 나지 않는다', () => {
    withD({ potGruelRun: 3, potGruelTension: 5 }, () => {
      const g = fresh('pot-2p');
      g.tension = 30;
      for (let i = 0; i < 9; i += 1) {
        setPot(g, i % 3 === 2 ? 'plain' : 'thin');
        potTick(g, []);
      }
      expect(g.tension).toBe(30);
      expect(potOf(g).gruel ?? 0).toBe(0);
    });
  });
});

describe('섞어서', () => {
  it('식량 소모에 섞는 곱이 걸리고 구간마다 목재가 든다', () => {
    const g = fresh('pot-3');
    const food0 = forecast(g).food;
    const sit0 = COMMS.map(c => situation(g, c)[1]);
    const wood0 = g.dom!.wood;
    setPot(g, 'mixed');
    expect(forecast(g).food).toBeCloseTo(food0 * D.potMixFood, 10);
    COMMS.forEach((c, i) => expect(situation(g, c)[1]).toBe(Math.max(0, sit0[i] - D.potMixSit)));
    expect(potView(g).choices.find(c => c.mode === 'mixed')).toMatchObject({ ok: true, wood: D.potMixWood, risk: potRisk(g), sickRisk: potSickRisk(g) });
    roll(g);
    expect(g.dom!.wood).toBe(wood0 - D.potMixWood);
    expect(potOf(g).mode).toBe('mixed');
  });

  it('들킬 확률이 쌓이는 판: 섞은 구간마다 오르고 쉬면 내린다', () => {
    withD({ potRisk0: 0.15, potRiskUp: 0.05, potRiskDown: 0.05 }, () => {
      const g = fresh('pot-4');
      setPot(g, 'mixed');
      expect(potRisk(g)).toBeCloseTo(0.15, 10);
      expect(potView(g).risk).toBeCloseTo(0.15, 10);
      roll(g);
      roll(g);
      expect(potRisk(g)).toBeCloseTo(0.25, 10);
      setPot(g, 'plain');
      expect(potView(g).risk).toBe(0);
      potTick(g, []);
      expect(potRisk(g)).toBeCloseTo(0.2, 10);
      for (let i = 0; i < 10; i += 1) potTick(g, []);
      expect(potRisk(g)).toBeCloseTo(0.15, 10);
    });
  });

  it('들킬 확률이 안 쌓이는 판: 몇 구간을 섞어도 그대로다', () => {
    withD({ potRisk0: 0.15, potRiskUp: 0, potRiskDown: 0 }, () => {
      const g = fresh('pot-4b');
      setPot(g, 'mixed');
      roll(g);
      roll(g);
      roll(g);
      expect(potRisk(g)).toBeCloseTo(0.15, 10);
    });
  });

  it('들키면 신임과 긴장이 움직이고 까닭이 장부에 남으며 솥은 그대로로 돌아간다(관계 벌을 켠 판은 모든 칸 관계도)', () => {
    withD({ potCaughtRel: 5, potCaughtLock: 0 }, () => {
      const g = fresh('pot-5');
      g.trust = 50; g.tension = 30;
      const rel0 = COMMS.map(c => g.comms[c].rel);
      setPot(g, 'mixed');
      drain(g);
      const notes = roll(g, { caught: true });
      expect(g.trust).toBe(50 - D.potCaughtTrust);
      expect(g.tension).toBe(30 + D.potCaughtTension);
      COMMS.forEach((c, i) => expect(g.comms[c].rel).toBe(rel0[i] - 5));
      const rows = drain(g);
      expect(rows.every(r => r.why === 'pot')).toBe(true);
      expect(rows.map(r => r.k).sort()).toEqual(['tension', 'trust', ...COMMS.map(c => `rel:${c}`)].sort());
      expect(potOf(g).mode).toBe('plain');
      expect(potOf(g).caught).toBe(1);
      expect(potView(g).lockLeft).toBe(0);
      expect(potUsable(g, 'mixed').ok).toBe(true);
      expect(notes).toContain('섞은 빵이 드러났다.');
      expect(g.cards.some(c => c.kind === 'info' && c.who === '섞은 빵이 드러났다')).toBe(true);
    });
  });

  it('잠금을 켠 판: 들키면 관계는 그대로이고 한동안 섞어서를 못 고른다', () => {
    withD({ potCaughtRel: 0, potCaughtLock: 3 }, () => {
      const g = fresh('pot-5k');
      const rel0 = COMMS.map(c => g.comms[c].rel);
      setPot(g, 'mixed');
      drain(g);
      roll(g, { caught: true });
      COMMS.forEach((c, i) => expect(g.comms[c].rel).toBe(rel0[i]));
      expect(drain(g).map(r => r.k).sort()).toEqual(['tension', 'trust']);
      const until = potOf(g).lockUntil!;
      expect(until).toBe(g.seg + 3);
      expect(potUsable(g, 'mixed').ok).toBe(false);
      expect(potUsable(g, 'mixed').why).toMatch(/^드러남 · \d+구간 잠금$/);
      expect(potUsable(g, 'thin').ok).toBe(true);
      setPot(g, 'mixed');
      expect(potOf(g).mode).toBe('plain');
      g.seg = until;
      expect(potView(g).lockLeft).toBe(1);
      g.seg = until + 1;
      expect(potView(g).lockLeft).toBe(0);
      setPot(g, 'mixed');
      expect(potOf(g).mode).toBe('mixed');
    });
  });

  it('공동 식당 법이 서 있으면 신임 벌이 곱절이다', () => {
    const g = fresh('pot-6');
    g.trust = 50;
    g.passed.common_kitchen = g.session;
    setPot(g, 'mixed');
    expect(potView(g).lawDouble).toBe(true);
    roll(g, { caught: true });
    expect(g.trust).toBe(50 - D.potCaughtTrust * D.potCaughtLaw);
  });

  it('목재가 없으면 못 고르고, 쓰다 떨어지면 그대로로 돌아가며 식량도 덜 들지 않는다', () => {
    const g = fresh('pot-7');
    const food0 = forecast(g).food;
    g.dom!.wood = 0;
    setPot(g, 'mixed');
    expect(potOf(g).mode).toBe('plain');
    expect(potView(g).choices.find(c => c.mode === 'mixed')).toMatchObject({ ok: false, why: '섞을 목재가 없다' });
    g.dom!.wood = D.potMixWood;
    setPot(g, 'mixed');
    roll(g);
    expect(g.dom!.wood).toBe(0);
    expect(potActive(g)).toBe('plain');
    expect(forecast(g).food).toBeCloseTo(food0, 10);
    const notes: string[] = [];
    potTick(g, notes);
    expect(potOf(g).mode).toBe('plain');
    expect(notes).toEqual(['섞을 목재가 떨어져 솥이 그대로로 돌아갔다.']);
  });
});

describe('섞은 빵의 탈', () => {
  const SICK = { potSick0: 0.1, potSickUp: 0.05, potSickMax: 0.4, potSickN: 2, potSickSegs: 2, potSickMed: 1, potSickTension: 2, potSickWork: 0.05 };

  it('탈이 날 확률은 잇달아 섞을수록 오르고 위가 막혀 있으며, 쉬면 처음으로 돌아간다', () => {
    withD({ ...SICK, potSickMax: 0.2 }, () => {
      const g = fresh('pot-s1');
      g.dom!.wood = 100;
      setPot(g, 'mixed');
      expect(potSickRisk(g)).toBeCloseTo(0.1, 10);
      expect(potView(g).sickRisk).toBeCloseTo(0.1, 10);
      roll(g);
      expect(potSickRisk(g)).toBeCloseTo(0.15, 10);
      roll(g);
      roll(g);
      roll(g);
      expect(potSickRisk(g)).toBeCloseTo(0.2, 10);
      setPot(g, 'plain');
      expect(potView(g).sickRisk).toBe(0);
      potTick(g, []);
      expect(potSickRisk(g)).toBeCloseTo(0.1, 10);
    });
  });

  it('탈이 나면 사람이 누워 침상을 쓰고 공방 작업량이 줄며 약과 긴장이 움직인다. 솥은 계속 돈다', () => {
    withD(SICK, () => {
      const g = fresh('pot-s2');
      g.med = 5; g.tension = 30;
      const bed0 = bedNeed(g);
      const w0 = workPower(g);
      setPot(g, 'mixed');
      drain(g);
      const notes = roll(g, { sick: true });
      expect(potSick(g)).toBe(2);
      expect(bedNeed(g)).toBe(bed0 + 2);
      expect(workPower(g)).toBeCloseTo(w0 * (1 - 0.05 * 2), 10);
      expect(g.med).toBe(4);
      expect(g.tension).toBe(32);
      expect(drain(g).map(r => [r.k, r.why]).sort()).toEqual([['med', 'pot'], ['tension', 'pot']]);
      expect(potOf(g).mode).toBe('mixed');
      expect(potView(g)).toMatchObject({ sick: 2, sickLeft: 3 });
      // 글은 빵을 까닭으로 적는다. 누구인지, 어느 칸인지는 적지 않는다.
      expect(notes).toEqual(['섞은 빵에 탈이 나 2명이 누웠다.']);
    });
  });

  it('정한 구간이 지나면 일어난다', () => {
    withD(SICK, () => {
      const g = fresh('pot-s3');
      const bed0 = bedNeed(g);
      setPot(g, 'mixed');
      roll(g, { sick: true });
      setPot(g, 'plain');
      g.seg += 2;
      expect(potSick(g)).toBe(2);
      g.seg += 1;
      expect(potSick(g)).toBe(0);
      expect(bedNeed(g)).toBe(bed0);
      expect(potView(g)).toMatchObject({ sick: 0, sickLeft: 0 });
      const notes: string[] = [];
      potTick(g, notes);
      expect(notes).toEqual(['탈이 났던 사람들이 일어났다.']);
    });
  });

  it('탈을 끈 판(누울 사람 0)에서는 섞어도 탈 난수를 굴리지 않는다', () => {
    withD({ ...SICK, potSickN: 0, potRisk0: 0, potRiskUp: 0 }, () => {
      const g = fresh('pot-s4');
      setPot(g, 'mixed');
      for (let i = 0; i < 20; i += 1) { g.dom!.wood = 10; potTick(g, []); }
      expect(potOf(g).sickHits ?? 0).toBe(0);
      expect(potOf(g).caught).toBe(0);
    });
  });
});

describe('식량이 0이면 불릴 것이 없다', () => {
  it('못 고르고, 쓰던 솥은 그대로로 돌아간다', () => {
    const g = fresh('pot-8');
    setPot(g, 'thin');
    g.food = 0;
    const notes: string[] = [];
    potTick(g, notes);
    expect(potOf(g).mode).toBe('plain');
    expect(notes).toContain('불릴 식량이 없어 솥이 그대로로 돌아갔다.');
    setPot(g, 'thin');
    expect(potOf(g).mode).toBe('plain');
    expect(potView(g).choices.find(c => c.mode === 'thin')).toMatchObject({ ok: false, why: '불릴 식량이 없다' });
  });
});

describe('판을 실제로 돌린다(봇)', () => {
  const BOT = { s1c: true, policy: 'caretaker', dom: 'idle' } as const;
  /** 첫 정산에서 식량이 얼마나 바뀌었나. thin이면 첫 카드를 고른 직후(첫 정산 전)에 담당을 세우고 묽게를 고른다. */
  const firstSettle = (thin: boolean): { food: number; g: Game } => {
    let food: number | null = null;
    let set = false;
    const { g } = playGame('pot-9', {
      ...BOT,
      probe: {
        afterPick: game => { if (thin && !set) { set = true; setPotCook(game, anyone(game)); setPot(game, 'thin'); } },
        onSettle: game => { food ??= game.lastSettle?.food ?? null; },
      },
    });
    if (food === null) throw new Error('정산이 한 번도 없었다');
    return { food, g };
  };

  it('묽게 고른 판은 그대로인 판보다 첫 정산에서 식량이 덜 줄고, 쓴 구간이 세어진다', () => {
    const a = firstSettle(false);
    const b = firstSettle(true);
    expect(a.g.dom?.pot).toBeUndefined();
    expect(b.food).toBeGreaterThan(a.food);
    expect(potOf(b.g).thinSegs).toBeGreaterThan(0);
  });
});
