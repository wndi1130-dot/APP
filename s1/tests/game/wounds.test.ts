import { describe, expect, it } from 'vitest';
import { createGame } from '../../src/game';
import type { Game } from '../../src/game';
import { enableDomestic } from '../../src/game/domestic/state';
import { D } from '../../src/game/domestic/data';
import {
  activeWounds, addWound, bedCount, healCuts, isWounded, medPerDay, migrateWounds, rebalanceBeds, stopSepticP, syncInjured, WOUND_ROLL, woundTick,
} from '../../src/game/wounds';
import type { Wound, WoundGrade, WoundInput } from '../../src/game/wounds';

// 부상 명부(정치_열차_명세_1_부상 1~3절): 아직 어느 규칙도 부르지 않는 새 모듈의 단독 시험.

function fresh(seed: string): Game {
  const g = createGame(seed);
  g.cards = [];
  return g;
}

let n = 0;
const make = (g: Game, grade: WoundGrade, extra: Partial<WoundInput> = {}): Wound =>
  addWound(g, { who: `사람${(n += 1)}`, comm: 'tail', from: 'stop', where: '시험', grade, part: 'torso', septic: false, ...extra });

describe('addWound: 등급별 값', () => {
  it('light는 1일에 침상이 없고, 깊은 상처는 3~4일 침상 2일, 골절은 팔 6일 다리 8일, 절단은 4일 침상 4일이다', () => {
    const g = fresh('w-grade');
    const light = make(g, 'light');
    expect([light.state, light.daysLeft, light.bedDays]).toEqual(['light', 1, 0]);
    const deep = make(g, 'deep');
    expect(deep.state).toBe('bed');
    expect([3, 4]).toContain(deep.daysLeft);
    expect(deep.bedDays).toBe(2);
    expect(make(g, 'fracture', { part: 'armL' }).daysLeft).toBe(6);
    expect(make(g, 'fracture', { part: 'legR' }).daysLeft).toBe(8);
    const amp = make(g, 'amputation', { part: 'armR' });
    expect([amp.state, amp.daysLeft, amp.bedDays]).toEqual(['bed', 4, 4]);
    expect(g.injured).toBe(5);
  });

  it('골절인데 머리·몸통이면 팔다리 넷 가운데서 부위를 다시 뽑는다', () => {
    const g = fresh('w-limb');
    for (let i = 0; i < 40; i += 1) {
      const w = make(g, 'fracture', { part: i % 2 ? 'head' : 'torso' });
      expect(['armL', 'armR', 'legL', 'legR']).toContain(w.part);
    }
  });

  it('곪으면 날이 1.5배 올림이고, 모두를 치료는 하루 줄이되 등급 바닥 아래로 안 간다', () => {
    const g = fresh('w-septic');
    expect(make(g, 'fracture', { part: 'legL', septic: true }).daysLeft).toBe(12);
    g.passed.treat_all = 1;
    expect(healCuts(g)).toBe(1);
    expect(make(g, 'fracture', { part: 'armL' }).daysLeft).toBe(5);
    expect(make(g, 'light').daysLeft).toBe(1); // 바닥
    expect(make(g, 'amputation').daysLeft).toBe(3);
    expect(make(g, 'deep', { cuts: 5 }).daysLeft).toBe(2); // 바닥 = 절반
  });

  it('M1 응급 처치가 있으면 하루 더 줄고 곪을 확률이 정차 기본 10%다', () => {
    const g = fresh('w-m1');
    enableDomestic(g);
    expect(healCuts(g)).toBe(0);
    g.dom!.techs.m1 = { stage: 'done', defect: false, progress: 1, need: 1 } as never;
    const cut = healCuts(g);
    expect(cut).toBe(1);
    expect(make(g, 'fracture', { part: 'armL' }).daysLeft).toBe(5);
    expect(stopSepticP(g, false)).toBe(WOUND_ROLL.septicM1);
    expect(stopSepticP(g, true)).toBeCloseTo(WOUND_ROLL.septicM1 + WOUND_ROLL.septicLongStay, 6);
  });

  it('의무진에 활성 기록이 있으면 다른 칸의 침상 기록은 하루 늦게 낫고, 의무진 자신은 아니다', () => {
    const g = fresh('w-nurse');
    const own = make(g, 'fracture', { part: 'armL', comm: 'medtech' });
    expect(own.daysLeft).toBe(6);
    expect(make(g, 'fracture', { part: 'armL', comm: 'tail' }).daysLeft).toBe(7);
    expect(make(g, 'light', { comm: 'tail' }).daysLeft).toBe(1); // 침상 기록만
  });

  it('대표가 다치면 personId가 같이 적히고, 번호는 1부터 하나씩 오른다', () => {
    const g = fresh('w-leader');
    const boss = g.comms.guard.leader;
    const w = addWound(g, { who: boss.name, comm: 'guard', from: 'brawl', where: '시험', grade: 'deep', part: 'armL', septic: false });
    expect(w.personId).toBe(boss.personId);
    const w2 = make(g, 'light');
    expect(w2.personId).toBeUndefined();
    expect(w2.id).toBe(w.id + 1);
    expect(isWounded(g, boss.name)).toBe(true);
  });

  it('값을 안 주면 정차 비율로 뽑고, 값을 다 주면 난수를 쓰지 않는다', () => {
    const g = fresh('w-roll');
    const seen: Record<string, number> = { light: 0, deep: 0, fracture: 0, amputation: 0 };
    for (let i = 0; i < 4000; i += 1) {
      const w = addWound(g, { who: `r${i}`, comm: 'tail', from: 'stop', where: '시험' });
      seen[w.grade] += 1;
    }
    for (const k of Object.keys(seen)) expect(Math.abs(seen[k] / 4000 - WOUND_ROLL.grade[k as WoundGrade])).toBeLessThan(0.03);
    const before = JSON.stringify(g.rng);
    make(g, 'light');
    expect(JSON.stringify(g.rng)).toBe(before);
  });
});

describe('woundTick', () => {
  it('깊은 상처는 의약품 0.5/일을 쓰고, 침상 2일 뒤 제 칸으로 내려오며, 날이 다하면 낫는다', () => {
    const g = fresh('t-deep');
    g.med = 10;
    const w = make(g, 'deep');
    const notes: string[] = [];
    woundTick(g, notes);
    expect(g.med).toBe(9.5);
    expect([w.state, w.daysLeft, w.bedDays]).toEqual(['bed', w.days0 - 1, 1]);
    woundTick(g, notes);
    expect(w.state).toBe('light');
    expect(g.injured).toBe(1);
    for (let i = 0; i < 4 && w.state === 'light'; i += 1) woundTick(g, notes);
    expect(w.state).toBe('healed');
    expect(g.injured).toBe(0);
  });

  it('골절은 침상에 있는 동안만 의약품이 들고, 곪음은 +0.5, light는 0이다', () => {
    const g = fresh('t-med');
    const f = make(g, 'fracture', { part: 'armL' });
    expect(medPerDay(f)).toBe(0.5);
    f.bedDays = 0;
    expect(medPerDay(f)).toBe(0);
    expect(medPerDay(make(g, 'deep', { septic: true }))).toBe(1);
    expect(medPerDay(make(g, 'light'))).toBe(0);
  });

  it('medMult를 곱하고, 활성 기록이 없으면 의약품도 난수도 쓰지 않는다', () => {
    const g = fresh('t-mult');
    g.med = 10;
    const rng = JSON.stringify(g.rng);
    woundTick(g, []);
    expect(g.med).toBe(10);
    expect(JSON.stringify(g.rng)).toBe(rng);
    make(g, 'deep');
    woundTick(g, [], 1.6);
    expect(g.med).toBeCloseTo(10 - 0.5 * 1.6, 6);
  });

  it('절단은 침상 4일 뒤 영구가 되고, 날 수와 같이 와도 healed가 영구를 이기지 않는다', () => {
    const g = fresh('t-amp');
    g.med = 20;
    const a = make(g, 'amputation', { part: 'armL' });
    for (let i = 0; i < 3; i += 1) woundTick(g, []);
    expect(a.state).toBe('bed');
    woundTick(g, []);
    expect(a.state).toBe('permanent');
    expect(g.injured).toBe(0); // 영구는 셈에서 빠진다
    expect(activeWounds(g)).toHaveLength(0);
    const before = g.med;
    woundTick(g, []);
    expect(g.med).toBe(before); // 영구는 의약품을 안 쓴다
  });

  it('둘이 같은 정산에 오면 healed가 이긴다(침상 날이 남은 날보다 길어도)', () => {
    const g = fresh('t-both');
    g.med = 5;
    const w = make(g, 'deep');
    w.daysLeft = 1; w.bedDays = 1;
    woundTick(g, []);
    expect(w.state).toBe('healed');
  });

  it('의약품이 모자라면 0으로 내려가고 날은 안 가며, 사망 굴림 뒤 죽은 기록은 명부에서 빠진다', () => {
    const g = fresh('t-short');
    g.med = 0;
    const ws = Array.from({ length: 60 }, () => make(g, 'deep'));
    const days = ws.map(w => w.daysLeft);
    const notes: string[] = [];
    woundTick(g, notes);
    expect(notes).toContain('의약품이 떨어졌다.');
    const left = activeWounds(g);
    expect(left.length).toBeLessThan(60);
    expect(left.length).toBeGreaterThan(40);
    for (const w of left) expect(w.daysLeft).toBe(days[ws.indexOf(w)]);
    expect(g.deaths.length).toBe(60 - left.length);
    expect(g.injured).toBe(left.length);
  });

  it('의무진이 거부하면 의약품만 줄고 날도 사망도 없다', () => {
    const g = fresh('t-refuse');
    g.med = 3;
    const w = make(g, 'deep');
    g.comms.medtech.fervor = 1;
    g.comms.medtech.rel = -50;
    const notes: string[] = [];
    woundTick(g, notes);
    expect(notes).toContain('의무진이 진료를 거부했다.');
    expect(g.med).toBe(2.5);
    expect(w.daysLeft).toBe(w.days0);
    g.med = 0;
    woundTick(g, []);
    expect(g.deaths).toHaveLength(0);
    expect(w.state).toBe('bed');
  });

  it('의무칸을 열병 환자에게 내준 동안 침상 기록의 날은 멈추고 제 칸의 light는 계속 간다', () => {
    const g = fresh('t-typhus');
    enableDomestic(g);
    g.dom!.typhus = [{ comm: 'tail', patients: ['환자'], apart: false, bay: true, at: 0 }];
    g.med = 10;
    const bed = make(g, 'deep');
    const home = make(g, 'deep');
    home.state = 'home';
    woundTick(g, []);
    expect(bed.daysLeft).toBe(bed.days0);
    expect(bed.bedDays).toBe(2);
    expect(home.daysLeft).toBe(home.days0 - 1);
  });

  it('곪음은 정산마다 10%로 하루 늘되 처음 값의 두 배가 상한이다', () => {
    const g = fresh('t-grow');
    g.med = 1000;
    const w = make(g, 'fracture', { part: 'legL', septic: true });
    w.state = 'light'; w.bedDays = 0;
    let max = w.daysLeft;
    for (let i = 0; i < 25 && isWounded(g, w.who); i += 1) {
      woundTick(g, []);
      max = Math.max(max, w.daysLeft);
    }
    expect(max).toBeLessThanOrEqual(w.days0 * 2);
  });
});

describe('rebalanceBeds / syncInjured / migrateWounds', () => {
  it('침상이 모자라면 규칙대로 home으로 내리고, 내릴 때 하루가 늘며, 침상이 비면 되돌린다', () => {
    const g = fresh('b-rota');
    enableDomestic(g);
    g.dom!.bedOrder = 'rota';
    const ws = Array.from({ length: D.beds + 2 }, (_, i) => { g.seg = i; return make(g, 'deep'); });
    const days = ws.map(w => w.daysLeft);
    expect(rebalanceBeds(g)).toBe(2);
    const home = ws.filter(w => w.state === 'home');
    expect(home.map(w => w.id)).toEqual(ws.slice(D.beds).map(w => w.id)); // 늦게 생긴 기록부터
    for (const w of home) expect(w.daysLeft).toBe(days[ws.indexOf(w)] + 1);
    expect(bedCount(g)).toBe(D.beds);
    expect(g.injured).toBe(D.beds + 2); // home도 활성이다
    ws[0].state = 'healed';
    expect(rebalanceBeds(g)).toBe(1);
    expect(bedCount(g)).toBe(D.beds);
  });

  it("'sick'이면 낫는 날이 적게 남은 사람이 home으로 내려간다", () => {
    const g = fresh('b-sick');
    enableDomestic(g);
    g.dom!.bedOrder = 'sick';
    const ws = Array.from({ length: D.beds + 1 }, () => make(g, 'deep'));
    ws[3].daysLeft = 1;
    rebalanceBeds(g);
    expect(ws.filter(w => w.state === 'home')).toEqual([ws[3]]);
  });

  it('syncInjured는 bed·home·light만 센다', () => {
    const g = fresh('s-sync');
    const a = make(g, 'deep'); const b = make(g, 'light'); const c = make(g, 'amputation');
    a.state = 'home'; c.state = 'permanent';
    syncInjured(g);
    expect(g.injured).toBe(2);
    expect(b.state).toBe('light');
  });

  it('옛 저장은 injured만큼 deep 기록으로 옮기고 판 난수를 쓰지 않으며, 두 번 옮기지 않는다', () => {
    const g = fresh('m-old');
    g.injured = 3;
    const rng = JSON.stringify(g.rng);
    migrateWounds(g);
    const ws = activeWounds(g);
    expect(ws).toHaveLength(3);
    expect(ws.every(w => w.grade === 'deep' && w.where === '옛 기록' && w.daysLeft === 3 && w.bedDays === 2)).toBe(true);
    expect(new Set(ws.map(w => w.who)).size).toBe(3);
    expect(g.injured).toBe(3);
    expect(JSON.stringify(g.rng)).toBe(rng);
    migrateWounds(g);
    expect(activeWounds(g)).toHaveLength(3);
    const h = fresh('m-old');
    h.injured = 3;
    migrateWounds(h);
    expect(activeWounds(h).map(w => w.who)).toEqual(ws.map(w => w.who)); // 같은 판이면 같은 사람
  });
});
