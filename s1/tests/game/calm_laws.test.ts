import { describe, expect, it } from 'vitest';
import {
  advance, calmNight, calmSettle, calmTension, CALM, createGame, enactLaw, forecast, LAWS, lawActive, lawOpen, onDeath, repealLaw,
} from '../../src/game';
import type { Game } from '../../src/game';

// 불만을 낮추는 법 셋(결정 035, H6_불만법_명세 3장): 저녁 솥불, 벽 장부, 떠난 사람의 밤.

function fresh(seed: string): Game {
  const g = createGame(seed);
  g.cards = [];
  return g;
}

describe('저녁 솥불', () => {
  it('켜져 있는 동안 관계 −15 이하인 칸만 구간마다 오르고, 석탄이 들고 긴장 몫이 준다', () => {
    const g = fresh('pot-on');
    g.coal = 100;
    g.comms.tail.rel = -20;
    g.comms.engine.rel = -5;
    const before = forecast(g).coal;
    enactLaw(g, 'evening_pot', []);
    expect(forecast(g).coal).toBeCloseTo(before + CALM.potCoal, 6);
    expect(calmTension(g)).toBeCloseTo(CALM.potTension, 6);
    calmSettle(g);
    expect(g.comms.tail.rel).toBeCloseTo(-20 + CALM.potRel, 6);
    expect(g.comms.engine.rel).toBe(-5); // 문턱 위의 칸에는 더 주지 않는다
  });

  it('석탄이 20 이하면 꺼지고 그때 한 번 관계를 깎고, 꺼진 동안은 아무 효과도 없다', () => {
    const g = fresh('pot-off');
    g.coal = 100;
    g.comms.tail.rel = -20;
    enactLaw(g, 'evening_pot', []);
    const base = forecast(g).coal - CALM.potCoal;
    g.coal = CALM.potOffCoal;
    calmSettle(g);
    expect(g.comms.tail.rel).toBeCloseTo(-20 + CALM.potOffRel, 6);
    expect(g.journal.some(j => j.text.includes('저녁 솥불이 꺼졌다'))).toBe(true);
    expect(forecast(g).coal).toBeCloseTo(base, 6);
    expect(calmTension(g)).toBe(0);
    const rel = g.comms.tail.rel;
    calmSettle(g);
    expect(g.comms.tail.rel).toBe(rel); // 다시 깎지도 올리지도 않는다
  });

  it('20과 30 사이에서는 깜박이지 않고, 30 이상이 되면 값 없이 다시 켜진다', () => {
    const g = fresh('pot-relight');
    g.coal = 100;
    g.comms.tail.rel = -20;
    enactLaw(g, 'evening_pot', []);
    g.coal = 20;
    calmSettle(g);
    const off = g.comms.tail.rel;
    g.coal = 25;
    calmSettle(g);
    expect(g.comms.tail.rel).toBe(off);
    expect(calmTension(g)).toBe(0);
    g.coal = 30;
    calmSettle(g);
    expect(calmTension(g)).toBeCloseTo(CALM.potTension, 6);
    expect(g.comms.tail.rel).toBeCloseTo(off + CALM.potRel, 6); // 깎임 없이 오르기만 한다
  });

  it('폐지하면 불이 사라지고, 다시 세우면 그때 석탄으로 켜짐이 정해진다', () => {
    const g = fresh('pot-repeal');
    g.coal = 100;
    enactLaw(g, 'evening_pot', []);
    repealLaw(g, 'evening_pot');
    expect(lawActive(g, 'evening_pot')).toBe(false);
    expect(calmTension(g)).toBe(0);
    g.coal = 15;
    enactLaw(g, 'evening_pot', []);
    expect(calmTension(g)).toBe(0);
    g.coal = 30;
    calmSettle(g);
    expect(calmTension(g)).toBeCloseTo(CALM.potTension, 6);
  });
});

describe('벽 장부', () => {
  it('넉넉하면 긴장 몫이 줄고 신임이 70까지 조금씩 오른다', () => {
    const g = fresh('ledger-rich');
    g.coal = 100; g.food = 100; g.trust = 50;
    enactLaw(g, 'wall_ledger', []);
    expect(calmTension(g)).toBeCloseTo(CALM.richTension, 6);
    calmSettle(g);
    expect(g.trust).toBeCloseTo(50 + CALM.richTrust, 6);
    g.trust = 69.9;
    calmSettle(g);
    expect(g.trust).toBe(CALM.trustCap);
    g.trust = 80;
    calmSettle(g);
    expect(g.trust).toBe(80); // 이미 높은 신임을 깎지는 않는다
  });

  it('모자라면 거꾸로 긴장 몫이 늘고 꼬리칸 관계가 깎이며, 사이일 때는 아무 일 없다', () => {
    const g = fresh('ledger-poor');
    g.coal = 100; g.food = 100;
    enactLaw(g, 'wall_ledger', []);
    g.food = CALM.ledgerPoor;
    const tail = g.comms.tail.rel;
    calmSettle(g);
    expect(calmTension(g)).toBeCloseTo(CALM.poorTension, 6);
    expect(g.comms.tail.rel).toBeCloseTo(tail + CALM.poorRel, 6);
    g.food = 45;
    const trust = g.trust;
    const tail2 = g.comms.tail.rel;
    calmSettle(g);
    expect(calmTension(g)).toBe(0);
    expect(g.trust).toBe(trust);
    expect(g.comms.tail.rel).toBe(tail2);
  });

  it('폐지하면 신임 −5 한 번', () => {
    const g = fresh('ledger-repeal');
    enactLaw(g, 'wall_ledger', []);
    g.trust = 60;
    repealLaw(g, 'wall_ledger');
    expect(g.trust).toBe(60 + CALM.repealTrust);
    expect(calmTension(g)).toBe(0);
  });
});

describe('떠난 사람의 밤', () => {
  it('첫 죽음이 난 뒤에야 안건으로 열린다', () => {
    const g = fresh('night-open');
    expect(lawOpen(g, 'night_of_names')).toBe(false);
    onDeath(g, 'tail', ['한 사람'], 'other');
    expect(lawOpen(g, 'night_of_names')).toBe(true);
  });

  it('죽은 구간의 밤에 공포·긴장이 내리고 그 사람의 칸 관계가 오르며, 석탄·사치품이 한 칸씩 든다', () => {
    const g = fresh('night-1');
    enactLaw(g, 'night_of_names', []);
    g.fear = 10; g.tension = 30; g.coal = 80; g.lux = 5; g.trust = 50;
    const rel = g.comms.medtech.rel;
    onDeath(g, 'medtech', ['가'], 'other');
    onDeath(g, 'medtech', ['나'], 'other');
    g.tension = 30; // 시신 법이 없을 때 죽음이 올리는 긴장은 빼고 본다
    calmNight(g);
    expect(g.fear).toBe(10 + CALM.nightFear);
    expect(g.tension).toBe(30 + CALM.nightTension);
    expect(g.comms.medtech.rel).toBeCloseTo(rel + CALM.nightRel, 6);
    expect(g.coal).toBe(80 - CALM.nightCoal);
    expect(g.lux).toBe(5 - CALM.nightLux);
    expect(g.trust).toBe(50); // 병·추위로 난 죽음엔 신임이 안 깎인다
    calmNight(g); // 같은 구간에 다시 불러도 한 번이다
    expect(g.coal).toBe(80 - CALM.nightCoal);
  });

  it('열차장이 고른 죽음이 섞이면 신임 −2가 같이 온다', () => {
    const g = fresh('night-chosen');
    enactLaw(g, 'night_of_names', []);
    g.trust = 50; g.coal = 80;
    onDeath(g, 'guard', ['다'], 'chosen', true);
    calmNight(g);
    expect(g.trust).toBe(50 + CALM.chosenTrust);
  });

  it('세 번째 밤부터 효과가 반이고 석탄·사치품 값은 그대로 든다', () => {
    const g = fresh('night-half');
    enactLaw(g, 'night_of_names', []);
    g.coal = 80; g.lux = 8;
    for (let i = 0; i < 2; i += 1) {
      g.seg += 1;
      onDeath(g, 'tail', [`x${i}`], 'other');
      calmNight(g);
    }
    g.seg += 1;
    g.fear = 10; g.tension = 30;
    const coal = g.coal;
    const rel = g.comms.tail.rel;
    onDeath(g, 'tail', ['x3'], 'other');
    g.tension = 30;
    calmNight(g);
    expect(g.fear).toBe(10 + CALM.nightFear / 2);
    expect(g.tension).toBe(30 + CALM.nightTension / 2);
    expect(g.comms.tail.rel).toBeCloseTo(rel + CALM.nightRel / 2, 6);
    expect(g.coal).toBe(coal - CALM.nightCoal);
  });

  it('사치품이 없으면 밤은 열리되 효과가 반이다', () => {
    const g = fresh('night-dark');
    enactLaw(g, 'night_of_names', []);
    g.coal = 80; g.lux = 0; g.fear = 10; g.tension = 30;
    onDeath(g, 'tail', ['라'], 'other');
    calmNight(g);
    expect(g.tension).toBeLessThan(30 + 3);
    expect(g.fear).toBe(10 + CALM.nightFear / 2);
    expect(g.lux).toBe(0);
  });

  it('석탄이 5 이하면 밤이 열리지 않고 값도 안 든다', () => {
    const g = fresh('night-cold');
    enactLaw(g, 'night_of_names', []);
    g.coal = CALM.nightMinCoal; g.fear = 10; g.tension = 30;
    onDeath(g, 'tail', ['마'], 'other');
    calmNight(g);
    expect(g.fear).toBe(10);
    expect(g.coal).toBe(CALM.nightMinCoal);
    expect(g.journal.some(j => j.text.includes('이름을 부를 불이 없었다'))).toBe(true);
  });

  it('법이 서기 전의 죽음은 밤으로 세지 않는다', () => {
    const g = fresh('night-late');
    g.coal = 80; g.fear = 10;
    onDeath(g, 'tail', ['바'], 'other');
    g.seg += 2;
    enactLaw(g, 'night_of_names', []);
    calmNight(g);
    expect(g.fear).toBe(10);
  });
});

describe('정산에 이어 붙은 모습', () => {
  it('정산 한 번에 솥불 석탄이 들고, 같은 구간의 죽음이 밤이 되며, 긴장은 절벽 규칙을 건드리지 않는다', () => {
    const plain = fresh('settle-int');
    const g = fresh('settle-int');
    for (const x of [plain, g]) { x.coal = 100; x.food = 100; x.phase = 'council'; }
    enactLaw(g, 'evening_pot', []);
    enactLaw(g, 'night_of_names', []);
    onDeath(g, 'tail', ['사'], 'other');
    onDeath(plain, 'tail', ['사'], 'other');
    advance(plain);
    advance(g);
    expect(g.phase).toBe('settle');
    // 솥불 0.5 + 밤 1 = 1.5 더 든다
    expect(plain.coal - g.coal).toBeCloseTo(CALM.potCoal + CALM.nightCoal, 6);
    expect(g.calm?.nights).toBe(1);
    expect(LAWS.evening_pot.why).toBeTruthy();
  });
});
