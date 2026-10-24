import { describe, expect, it } from 'vitest';
import {
  agendaOptions, cancelJob, cancelOpen, createGame, createS1cGame, giveCandidates, isLawAgenda, jobCheck, startJob, viewCard, GREENHOUSE_CARS,
} from '../../src/game';
import type { Game, TechId } from '../../src/game';

// 결정 426 PR 2(S1 정리): 결정이 더 필요 없는 규칙 바로잡기.

function done(g: Game, id: TechId): void {
  g.dom!.techs[id] = { stage: 'done', defect: false, progress: 0, need: 0 } as NonNullable<Game['dom']>['techs'][TechId];
}

describe('폐지는 통과한 뒤 2회기가 지나야 오른다', () => {
  const repealOffered = (g: Game) => agendaOptions(g).options.some(o => isLawAgenda(o) && o.law === 'common_kitchen' && o.repeal);
  it('다시 올리기와 같은 셈: 2회기 안에는 없고 셋째 회기에 있다', () => {
    const g = createGame('repeal');
    g.passed = { ...g.passed, common_kitchen: 3 };
    g.session = 5;
    expect(repealOffered(g)).toBe(false);
    g.session = 6;
    expect(repealOffered(g)).toBe(true);
  });
});

describe('장갑은 하는 일이 있는 칸에만', () => {
  it('경비대칸에만 댈 수 있다', () => {
    const g = createS1cGame('armor-only');
    done(g, 'w3');
    g.dom!.scrap = 100;
    expect(jobCheck(g, 'armor', 'guard').ok).toBe(true);
    for (const car of ['tail1', 'medtech', 'front']) {
      expect(jobCheck(g, 'armor', car)).toEqual({ ok: false, why: '경비대칸에만 댄다' });
    }
  });
});

describe('줄에 올린 개조는 손대기 전이면 내린다', () => {
  it('낸 자재를 그대로 돌려받고, 공방이 손댄 뒤에는 못 내린다', () => {
    const g = createS1cGame('cancel');
    done(g, 'e5');
    const d = g.dom!;
    d.wood = 20;
    const before = { wood: d.wood, scrap: d.scrap };
    expect(startJob(g, 'insulate', 'tail1')).toBe(true);
    expect(d.wood).toBeLessThan(before.wood);
    expect(cancelOpen(g)).toBe(true);
    expect(cancelJob(g)).toBe(true);
    expect(d.job).toBeNull();
    expect({ wood: d.wood, scrap: d.scrap }).toEqual(before);
    expect(startJob(g, 'insulate', 'tail1')).toBe(true);
    d.job!.progress = 1;
    expect(cancelOpen(g)).toBe(false);
    expect(cancelJob(g)).toBe(false);
    expect(d.job).not.toBeNull();
  });

  it('옛 저장 판의 줄(낸 자재 기록 없음)은 내리지 않는다', () => {
    const g = createS1cGame('cancel-old');
    g.dom!.job = { kind: 'insulate', car: 'tail1', progress: 0, need: 3 };
    expect(cancelOpen(g)).toBe(false);
  });
});

describe('온실은 창고칸에만', () => {
  it('사람이 사는 칸과 냉동칸은 내줄 칸에 없다(금지선, 2026-10-25)', () => {
    expect([...GREENHOUSE_CARS]).toEqual(['store']);
    const g = createS1cGame('give');
    done(g, 'm4');
    expect(giveCandidates(g)).toEqual(['store']);
    const v = viewCard(g, { uid: 1, kind: 'dom:give' });
    const specials = v.choices.map(c => c.special);
    expect(specials).toEqual(['dom:give:store', 'dom:none']);
    expect(v.body).not.toContain('살던 사람');
  });
});
