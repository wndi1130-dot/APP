import { describe, expect, it } from 'vitest';
import {
  advance, breakPromise, castVote, createGame, currentAgenda, enableDark, keepPromise, makeDeal, openCouncil, preVote, primaryAction,
} from '../../src/game';
import type { Game } from '../../src/game';
import { afterVote } from '../../src/game/dark/council';
import { B } from '../../src/game/dark/data';
import { MOTION_SOURCES } from '../../src/game/motions';

// 정기 신임 표결(s1b_dark_path 5.3, 사용자 결정 '정기 투표'). 숫자와 부결의 결과는 제안(B.conf*).

function darkGame(seed: string): Game {
  const g = createGame(seed);
  enableDark(g);
  return g;
}

/** 정기 회기를 n번 연다(의회 단계로 둔다). */
function sessions(g: Game, n: number): void {
  for (let i = 0; i < n; i += 1) {
    openCouncil(g);
    g.phase = 'council';
  }
}

/** 표결 결과를 정해 둔다: 모든 칸 관계를 올리거나 내린다. */
function lean(g: Game, rel: number): void {
  for (const c of Object.keys(g.comms) as (keyof Game['comms'])[]) { g.comms[c].rel = rel; g.comms[c].grudge = 0; }
}

describe('정기 신임 표결', () => {
  it(`${B.confEvery}회기마다 법 안건 앞에 따로 열리고, 안건 자리를 쓰지 않는다`, () => {
    const g = darkGame('conf-every');
    sessions(g, B.confEvery - 1);
    expect(preVote(g)).toBe(false);
    sessions(g, 1);
    expect(preVote(g)).toBe(true);
    const lawAgenda = g.council!.options[g.council!.idx];
    expect(currentAgenda(g)).toMatchObject({ kind: 'motion', motion: 'confidence' });
    expect(primaryAction(g)).toMatchObject({ label: '표결', ok: false });
    // 거래는 못 한다
    expect(makeDeal(g, 'tail', 'open').ok).toBe(false);
    lean(g, 40);
    castVote(g);
    expect(g.council!.result?.passed).toBe(true);
    expect(primaryAction(g)).toMatchObject({ label: '다음 안건', ok: true });
    advance(g);
    expect(g.phase).toBe('council');
    expect(preVote(g)).toBe(false);
    expect(g.council!.result).toBeNull();
    expect(currentAgenda(g)).toEqual(lawAgenda);
    // 다음 표결은 다시 confEvery회기 뒤
    sessions(g, B.confEvery - 1);
    expect(preVote(g)).toBe(false);
    sessions(g, 1);
    expect(preVote(g)).toBe(true);
  });

  it('통과하면 신임이 오른다', () => {
    const g = darkGame('conf-pass');
    sessions(g, B.confEvery);
    lean(g, 40);
    g.trust = 50;
    castVote(g);
    expect(g.trust).toBe(50 + B.confPassTrust);
    expect(g.dark!.confLock ?? 0).toBe(0);
  });

  it('부결이면 쫓겨나지 않고, 신임이 깎이고 다음 회기 안건은 대표가 고른다', () => {
    const g = darkGame('conf-fail');
    sessions(g, B.confEvery);
    lean(g, -60);
    g.trust = 50;
    castVote(g);
    expect(g.council!.result?.passed).toBe(false);
    expect(g.phase).toBe('council');
    expect(g.trust).toBe(50 - B.confFailTrust);
    expect(g.dark!.confLock).toBe(B.confFailLock);
    lean(g, 0);
    sessions(g, 1);
    expect(g.council!.locked).toBe(true);
    expect(g.dark!.confLock).toBe(0);
    expect(g.journal.some(e => e.text.startsWith('신임을 잃은 회기다.'))).toBe(true);
    const a = currentAgenda(g);
    if (a) expect(a.by).toBeDefined();
    // 그다음 회기는 다시 열차장이 고른다
    sessions(g, 1);
    expect(g.council!.locked).toBe(false);
  });

  it('부결 다음 회기에 위기 안건이 있으면 그 회기는 위기 안건이 받는다', () => {
    const g = darkGame('conf-fail-crisis');
    sessions(g, B.confEvery);
    lean(g, -60);
    castVote(g);
    expect(g.dark!.confLock).toBe(B.confFailLock);
    const share = () => [{ kind: 'motion' as const, motion: 'share' as const, subject: 'tail' as const }];
    MOTION_SOURCES.push(share);
    try {
      sessions(g, 1);
    } finally { MOTION_SOURCES.splice(MOTION_SOURCES.indexOf(share), 1); }
    expect(g.council!.locked).toBe(true);
    expect(g.council!.options).toHaveLength(1);
    expect(currentAgenda(g)).toMatchObject({ kind: 'motion', motion: 'share' });
    expect(g.journal.some(e => e.text.startsWith('신임을 잃은 회기다. 대표들은'))).toBe(true);
  });

  it('비상 소집은 정기 회기로 세지 않는다', () => {
    const g = darkGame('conf-emergency');
    sessions(g, B.confEvery - 1);
    openCouncil(g, true);
    expect(preVote(g)).toBe(false);
    sessions(g, 1);
    expect(preVote(g)).toBe(true);
  });

  it('S1b가 꺼진 판엔 열리지 않는다', () => {
    const g = createGame('conf-plain');
    sessions(g, B.confEvery * 2);
    expect(g.council!.pre).toBeUndefined();
  });

  it('원수 대표가 갈려도 불씨를 만들지 않는다', () => {
    const g = darkGame('conf-rival');
    const comms = Object.keys(g.comms) as (keyof Game['comms'])[];
    const byComm = Object.fromEntries(comms.map((c, i) => [c, i % 2 ? { yes: 9, no: 0 } : { yes: 0, no: 9 }]));
    const before = g.dark!.embers.length;
    for (let i = 0; i < 50; i += 1) afterVote(g, { kind: 'motion', motion: 'confidence' }, { yes: 0, no: 0, absent: 0, passed: true, byComm } as never);
    expect(g.dark!.embers.length).toBe(before);
  });

  it('칸마다 지킨 약속과 어긴 약속을 센다(신임 입장)', () => {
    const g = darkGame('conf-promise');
    keepPromise(g, 'tail', '시험');
    breakPromise(g, 'engine', '시험');
    expect(g.dark!.kept.tail).toBe(1);
    expect(g.dark!.broken.engine).toBe(1);
  });
});
