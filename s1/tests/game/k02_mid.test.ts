import { describe, expect, it } from 'vitest';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import { createGame, darkEnd, enableDark, onDeath, PROFILES } from '../../src/game';
import type { Game } from '../../src/game';
import { openCase, punish, reveal, scapegoat, sendTrial } from '../../src/game/dark/cases';
import { h7Record } from '../../src/game/dark/chronicle';
import { darkSettle, darkTravel } from '../../src/game/dark/hooks';
import { executorTick, runOrder } from '../../src/game/dark/order';
import { adults, commOf, isRep } from '../../src/game/dark/state';
import type { Ember } from '../../src/game/dark/state';
import { applyStep, readSave } from '../../src/ui/repro';
import type { Step } from '../../src/ui/repro';
import { darkCardShown, darkPickMs, darkPickReset, darkVisibility } from '../../src/ui/dark';

// K02 판정(/mnt/project-files/s1b_wip/k02_verdict.md)의 중간 6~11.

function darkGame(seed: string): Game {
  const g = createGame(seed);
  enableDark(g);
  g.seg = 4;
  return g;
}

const tailAdults = (g: Game) => adults(g, 'tail', { noRep: true });

describe('K02 6. 끝까지 안 드러난 배급·근신 오판은 끝 증언에서 말한다', () => {
  function misjudged(seed: string, how: 'ration' | 'confine') {
    const g = darkGame(seed);
    const culprit = tailAdults(g)[0].id;
    const c = openCase(g, { kind: 'heating', culprit, victimComm: 'front', dead: false, clock: 3, where: '앞칸' });
    const s = c.sus.find(x => !x.culprit)!;
    punish(g, c, s, how, 'trial');
    return { g, s };
  }

  for (const how of ['ration', 'confine'] as const) {
    it(`${how} 오판은 무게 1 장면과 그 칸 사람 둘의 목격자를 남기고, 끝 증언에 오른다`, () => {
      const { g, s } = misjudged(`k02-6-${how}`, how);
      const sc = g.dark!.scenes.find(x => x.key === 'misjudged')!;
      expect(sc.weight).toBe(1);
      expect(sc.who).toEqual([s.id]);
      expect(sc.witnesses).toHaveLength(2);
      for (const id of sc.witnesses) expect(commOf(g, id)).toBe(commOf(g, s.id));
      const e = darkEnd(g);
      expect(e.testimonies.some(t => sc.witnesses.some(id => PROFILES.find(p => p.id === id)!.name === t.name))).toBe(true);
    });
  }

  it('죄가 있는 사람을 벌하면 이 장면이 없다', () => {
    const g = darkGame('k02-6-guilty');
    const culprit = tailAdults(g)[0].id;
    const c = openCase(g, { kind: 'heating', culprit, victimComm: 'front', dead: false, clock: 3, where: '앞칸' });
    const s = c.sus.find(x => x.culprit)!;
    s.proxyFor = undefined;
    punish(g, c, s, 'ration', 'trial');
    expect(g.dark!.scenes.some(x => x.key === 'misjudged')).toBe(false);
  });

  it('나중에 드러나면 이 장면은 거두고 드러난 장면이 대신한다', () => {
    const { g, s } = misjudged('k02-6-revealed', 'ration');
    reveal(g, s.id, commOf(g, s.id));
    expect(g.dark!.scenes.some(x => x.key === 'misjudged')).toBe(false);
    expect(g.dark!.scenes.some(x => x.key === 'innocent')).toBe(true);
    expect((g.chronicle ?? []).some(x => x.template === 's1b.misjudged')).toBe(false);
  });
});

describe('K02 7. 피해자와 근신자는 대리 진범이 되지 않는다', () => {
  it('피해자는 자기 사건의 대리 진범이 되지 않는다', () => {
    for (let i = 0; i < 80; i += 1) {
      const g = darkGame(`k02-7-victim-${i}`);
      const rep = g.comms.tail.leader.personId;
      const victim = tailAdults(g)[i % tailAdults(g).length].id;
      const c = openCase(g, { kind: 'assault', culprit: rep, victimComm: 'tail', victim, dead: false, clock: 3, where: '통로' });
      const hand = c.sus.find(x => x.culprit)!;
      expect(hand.id).not.toBe(victim);
      expect(isRep(g, hand.id)).toBe(false);
    }
  });

  it('근신 중인 사람은 대리 진범이 되지 않는다', () => {
    for (let i = 0; i < 10; i += 1) {
      const g = darkGame(`k02-7-confined-${i}`);
      const rep = g.comms.tail.leader.personId;
      const pool = tailAdults(g);
      const free = pool[i % pool.length].id;
      g.dark!.confined = pool.filter(p => p.id !== free).map(p => ({ id: p.id, until: g.seg + 3 }));
      const c = openCase(g, { kind: 'assault', culprit: rep, victimComm: 'front', dead: false, clock: 3, where: '통로' });
      expect(c.sus.find(x => x.culprit)!.id).toBe(free);
    }
  });
});

describe('K02 8. 실행자는 사람마다 한 줄이다', () => {
  function orderOnce(g: Game, target: string, exe: string) {
    g.dark!.order = { target, why: 'hostile', exe: 'guard', exeId: exe, method: 'night', at: g.seg };
    runOrder(g, 'travel');
  }

  it('같은 사람이 두 번 실행해도 기록은 하나이고 구간이 새로 적힌다', () => {
    const g = darkGame('k02-8');
    const exe = adults(g, 'guard', { noRep: true })[0].id;
    const [a, b] = adults(g, 'front', { noRep: true });
    orderOnce(g, a.id, exe);
    g.seg += 2;
    orderOnce(g, b.id, exe);
    const mine = g.dark!.executors.filter(x => x.id === exe);
    expect(mine).toHaveLength(1);
    expect(mine[0].seg).toBe(g.seg);
  });

  it('실행자가 죽어도 이어받는 굴림은 한 번이고 같은 사람이 둘로 적히지 않는다', () => {
    for (let i = 0; i < 20; i += 1) {
      const g = darkGame(`k02-8-heir-${i}`);
      const exe = adults(g, 'guard', { noRep: true })[0];
      const [a, b] = adults(g, 'front', { noRep: true });
      orderOnce(g, a.id, exe.id);
      orderOnce(g, b.id, exe.id);
      onDeath(g, 'guard', [exe.name], 'other');
      executorTick(g);
      const ids = g.dark!.executors.map(x => x.id);
      expect(new Set(ids).size).toBe(ids.length);
      expect(ids.length).toBeLessThanOrEqual(1);
    }
  });
});

describe('K02 9. H7 망설임은 화면 밖 시간을 세지 않는다', () => {
  it('뒤로 갔던 시간은 뺀다', () => {
    const g = darkGame('k02-9');
    darkPickReset();
    darkCardShown(g, 7, 1000);
    darkVisibility(2000, true);
    darkVisibility(12000, false);
    expect(darkPickMs(g, 7, 13000)).toBe('2000');
  });

  it('뒤에 있는 채로 골랐으면 뒤로 간 때까지만 센다', () => {
    const g = darkGame('k02-9-hidden');
    darkPickReset();
    darkCardShown(g, 8, 1000);
    darkVisibility(2000, true);
    expect(darkPickMs(g, 8, 50000)).toBe('1000');
  });

  it('카드를 뒤에서 처음 봐도 보기 전 시간은 빼지 않는다', () => {
    const g = darkGame('k02-9-late');
    darkPickReset();
    darkVisibility(1000, true);
    darkCardShown(g, 9, 5000);
    darkVisibility(8000, false);
    expect(darkPickMs(g, 9, 9000)).toBe('1000');
  });

  it('새 판이나 불러오기에서 지운다', () => {
    const g = darkGame('k02-9-reset');
    darkPickReset();
    darkCardShown(g, 1, 1000);
    darkVisibility(2000, true);
    darkPickReset();
    expect(darkPickMs(g, 1, 3000)).toBeUndefined();
    darkCardShown(g, 1, 4000); // 새 판의 같은 uid
    expect(darkPickMs(g, 1, 4500)).toBe('500');
  });
});

describe('K02 10. 폭력 사망은 피해 사건과 같은 정의다', () => {
  it('처형은 피해 사건이자 폭력 사망으로 한 번 센다', () => {
    const g = darkGame('k02-10-exec');
    const c = openCase(g, { kind: 'assault', culprit: tailAdults(g)[0].id, victimComm: 'guard', dead: false, clock: 3, where: '통로' });
    const s = c.sus.find(x => !x.culprit)!;
    c.convicted = s.id;
    const { harm, stats } = g.dark!;
    const before = [harm, stats.violentDeaths];
    punish(g, c, s, 'execute', 'trial');
    expect([g.dark!.harm, g.dark!.stats.violentDeaths]).toEqual([before[0] + 1, before[1] + 1]);
  });

  it('성공한 암살 명령은 피해 사건이자 폭력 사망으로 한 번 센다', () => {
    let ok = 0;
    for (let i = 0; i < 40 && ok < 3; i += 1) {
      const g = darkGame(`k02-10-order-${i}`);
      const target = adults(g, 'front', { noRep: true })[0].id;
      const exe = adults(g, 'guard', { noRep: true })[0].id;
      g.dark!.order = { target, why: 'hostile', exe: 'guard', exeId: exe, method: 'night', at: g.seg };
      const harm = g.dark!.harm;
      runOrder(g, 'travel');
      if (g.dark!.stats.ordersOk === 0) {
        expect(g.dark!.stats.violentDeaths).toBe(0); // 실패는 부상이라 사망이 아니다
        continue;
      }
      ok += 1;
      expect(g.dark!.stats.violentDeaths).toBe(1);
      expect(g.dark!.harm).toBe(harm + 1);
    }
    expect(ok).toBe(3);
  });

  it('린치와 희생양은 죽었을 때만 폭력 사망이다', () => {
    const seen = new Set<number>();
    for (let i = 0; i < 40; i += 1) {
      const g = darkGame(`k02-10-lynch-${i}`);
      const c = openCase(g, { kind: 'assault', culprit: tailAdults(g)[0].id, victimComm: 'guard', dead: true, clock: 1, where: '통로' });
      const s = c.sus.find(x => !x.culprit)!;
      const harm = g.dark!.harm;
      const out = scapegoat(g, c, s, i % 2 === 0);
      const died = out.includes('돌아오지 않았다');
      expect(g.dark!.harm).toBe(harm + 1);
      expect(g.dark!.stats.violentDeaths).toBe(died ? 1 : 0);
      seen.add(g.dark!.stats.violentDeaths);
    }
    expect(seen).toEqual(new Set([0, 1]));
  });

  it('H7 기록의 폭력 사망이 이 숫자를 그대로 읽는다', () => {
    const g = darkGame('k02-10-h7');
    g.dark!.stats.violentDeaths = 3;
    expect(h7Record(g).violentDeaths).toBe(3);
  });
});

describe('K02 11. 대기 상태를 저장했다 되살려도 같은 행동은 같은 결과', () => {
  function pending(seed: string): Game {
    const g = darkGame(seed);
    const d = g.dark!;
    // 임박(폭행 임박)
    const e: Ember = {
      id: 900, who: 'tail', actor: tailAdults(g)[0].id, target: 'guard', mark: g.comms.guard.leader.personId, cause: 'fervor',
      stage: 2, imm: 3, quiet: 0, guardUntil: -1, sab: 'heating', blocked: false, born: g.seg,
    };
    d.embers.push(e);
    // 재판 중인 사건
    const c = openCase(g, { kind: 'assault', culprit: tailAdults(g)[1].id, victimComm: 'guard', dead: true, clock: 3, where: '통로', ember: 901 });
    c.opened = g.seg - 1;
    sendTrial(g, c);
    // 입막음 명령(진실을 막으려는 명령이 걸려 있다)
    const [innocent, witness] = tailAdults(g).slice(2);
    d.innocents.push({ id: innocent.id, comm: 'tail', seg: g.seg - 1, caseId: c.id, how: 'punish', held: true });
    d.order = { target: witness.id, why: 'truth', ref: innocent.id, exe: 'guard', exeId: adults(g, 'guard', { noRep: true })[0].id, method: 'night', at: g.seg };
    // 밤샘을 바라는 시신: 정산하면 밤샘 카드가 뜬다
    d.practice = 'guard';
    d.fresh.push({ comm: 'tail', name: g.comms.tail.leader.name, vigil: true });
    darkSettle(g);
    expect(g.cards.some(k => k.kind === 'dark:vigil')).toBe(true);
    expect(c.status).toBe('trial');
    return g;
  }

  it('저장 글을 거쳐도 판이 같고, 같은 행동을 하면 같은 판이 나온다', () => {
    const g = pending('k02-11');
    const r = readSave(JSON.parse(JSON.stringify(g)));
    expect(r.ok).toBe(true);
    const twin = (r as { g: Game }).g;
    expect(JSON.stringify(twin)).toBe(JSON.stringify(g));
    const vigil = g.cards.find(k => k.kind === 'dark:vigil')!;
    const steps: Step[] = [{ a: 'choose', d: { uid: String(vigil.uid), index: '0' } }];
    for (const st of steps) { applyStep(g, st); applyStep(twin, st); }
    darkTravel(g);
    darkTravel(twin);
    for (let i = 0; i < 3; i += 1) {
      g.seg += 1;
      twin.seg += 1;
      darkSettle(g);
      darkSettle(twin);
    }
    expect(JSON.stringify(twin)).toBe(JSON.stringify(g));
  });
});

describe('K02 11. s1b_sim 인수 검사', () => {
  const root = fileURLToPath(new URL('../../', import.meta.url));
  // 잘못된 인수는 판을 돌리기 전에 멈춘다. tsx 래퍼 없이 node에 바로 싣는다(validate.test.ts와 같다).
  const sim = (...args: string[]) => spawnSync(process.execPath, ['--import', 'tsx', join(root, 'tools/s1b_sim.ts'), ...args],
    { cwd: root, encoding: 'utf8', timeout: 60_000 });

  it.each(['0', '-3', '2.5', 'abc', '1e3', ''])('판 수 "%s"는 거절한다', n => {
    const r = sim(n);
    expect(r.status).not.toBe(0);
    expect(r.stderr).toContain('판 수는 양의 정수');
  });

  it.each(['toString', 'constructor', '__proto__', 'hasOwnProperty', 'noSuchKey'])('--set 키 "%s"는 B 자신의 속성이 아니라서 거절한다', k => {
    const r = sim('1', `--set=${k}:1`);
    expect(r.status).not.toBe(0);
    expect(r.stderr).toContain('B에 없는 값');
  });

  it('--set 값이 숫자가 아니면 거절한다', () => {
    const r = sim('1', '--set=escBase:abc');
    expect(r.status).not.toBe(0);
    expect(r.stderr).toContain('숫자가 아닌 값');
  });
});
