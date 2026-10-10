import { describe, expect, it } from 'vitest';
import { addCard, createGame, enableDark, PROFILES, viewCard } from '../../src/game';
import type { Card, Game } from '../../src/game';
import { flagged, openCase, suspicion, topByClues, updateFlags } from '../../src/game/dark/cases';
import type { OpenArgs } from '../../src/game/dark/cases';
import type { CaseKind, Fact, Suspect } from '../../src/game/dark/state';
import { readSave } from '../../src/ui/repro';

// 금지선 점검 K05(공유 폴더 guard/k05_owners.md)의 s1/ 몫 가운데 규칙 하나:
// 칸 소속(사건 칸이나 옆 칸 사람)과 처지(늦게 탐·구조됨·벌받음)만으로는 희생양 후보가 켜지지 않는다.

const adult = PROFILES.find(p => p.age >= 20 && ['pl', 'de', 'cz'].includes(p.name_lang ?? ''))!;
const sus = (facts: Fact[], clues = 0): Suspect => ({
  id: adult.id, culprit: false, facts, acq: false,
  clues: Array.from({ length: clues }, (_, i) => ({ kind: 'foot' as const, truth: false, line: `단서 ${i}`, seg: 1 })),
});

describe('K05 칸 소속과 칸끼리의 원한은 희생양 후보 표시를 켜지 않는다', () => {
  const g = createGame('k05');
  enableDark(g);

  it('같은 칸·옆 칸에 늦게 탔거나 구조됐거나 벌받은 사람이라는 것만으로는 안 켜진다', () => {
    for (const extra of ['joined', 'rescued', 'punished'] as const) expect(flagged(g, sus(['car', extra]))).toBe(false);
    // 원수 칸 사람이라는 것도 칸의 사실이다
    expect(flagged(g, sus(['car', 'rival']))).toBe(false);
    expect(flagged(g, sus(['rival', 'joined']))).toBe(false);
  });

  it('그 사람을 가리킨 단서가 있으면 켜진다. 칸 단위 드나듦(access)만으로는 안 켜진다', () => {
    expect(flagged(g, sus(['car'], 1))).toBe(true);
    // access는 ACCESS[kind] === 소속 칸이라 칸의 사실이다(개인 기록이 아니다). 의심 점수에만 든다.
    expect(flagged(g, sus(['access']))).toBe(false);
  });
});

// ---- 칸 소속·출신·탄 경위만으로는 켜지지 않고, 피고는 편견 점수로 가르지 않는다 ----

const KINDS: CaseKind[] = ['theft', 'boiler', 'assault', 'assn', 'poison', 'coupling'];
const args = (kind: CaseKind, g: Game, victimComm: OpenArgs['victimComm'] = 'guard'): OpenArgs =>
  ({ kind, culprit: g.comms.tail.leader.personId, victimComm, dead: false, clock: 3, where: '통로' });
function darkGame(seed: string): Game {
  const g = createGame(seed);
  enableDark(g);
  return g;
}

describe('K05 단서가 없는 용의자는 사실이 무엇이든 후보가 아니다', () => {
  it('여러 시드·사건 종류로 열어도 단서 없는 용의자는 flagged가 false이고 scapegoatOk가 비어 있다', () => {
    for (const seed of ['k05-a', 'k05-b', 'k05-c', 'k05-d']) {
      for (const kind of KINDS) {
        const g = darkGame(seed);
        const c = openCase(g, args(kind, g, kind === 'boiler' ? 'engine' : 'front'));
        expect(c.sus.length).toBeGreaterThanOrEqual(2);
        for (const x of c.sus) expect(x.clues.length).toBe(0);
        for (const x of c.sus) expect(flagged(g, x), `${seed} ${kind}`).toBe(false);
        expect(g.scapegoatOk ?? [], `${seed} ${kind}`).toEqual([]);
        // 사실을 있는 대로 다 얹어도(칸 단위 드나듦·같은 칸·원한·늦게 탐) 단서가 없으면 그대로다
        for (const x of c.sus) x.facts = ['access', 'car', 'rival', 'joined', 'punished'];
        updateFlags(g);
        for (const x of c.sus) expect(flagged(g, x), `${seed} ${kind} 사실 가득`).toBe(false);
        expect(g.scapegoatOk ?? []).toEqual([]);
      }
    }
  });

  it('access와 joined뿐이면 false, 같은 사람에 단서가 하나 붙고 점수 2 이상이면 true', () => {
    const g = darkGame('k05-b');
    const x = sus(['access', 'joined']);
    expect(suspicion(x)).toBeGreaterThanOrEqual(2);
    expect(flagged(g, x)).toBe(false);
    for (const kind of ['foot', 'witness'] as const) {
      const y = sus(['access', 'joined']);
      y.clues.push({ kind, truth: false, line: '단서', seg: 1 });
      expect(suspicion(y)).toBeGreaterThanOrEqual(2);
      expect(flagged(g, y)).toBe(true);
    }
    // 단서가 있어도 점수 2 미만이면 안 켜진다
    expect(flagged(g, sus([], 1))).toBe(false);
  });

  it('출처 없는 밀고·떠도는 말(informant)만으로는 안 켜지고, 출처 있는 단서가 붙으면 켜진다', () => {
    const g = darkGame('k05-informant');
    const x = sus(['joined']);
    x.clues.push({ kind: 'informant', truth: false, line: '쪽지', seg: 1 }, { kind: 'informant', truth: true, line: '배식 줄 말', seg: 2 });
    expect(suspicion(x)).toBeGreaterThanOrEqual(2);
    expect(flagged(g, x)).toBe(false);
    for (const kind of ['foot', 'item', 'witness', 'ledger', 'public'] as const) {
      const y = sus(['joined']);
      y.clues.push({ kind: 'informant', truth: false, line: '쪽지', seg: 1 }, { kind, truth: false, line: '단서', seg: 2 });
      expect(flagged(g, y)).toBe(true);
    }
  });
});

describe('K05 피고는 단서로만 고르고 편견 점수로 가르지 않는다', () => {
  it('증거 단계·단서 수가 같으면 편견 점수가 높아도 c.sus 앞쪽 사람이 피고다', () => {
    const g = darkGame('k05-top');
    const c = openCase(g, args('assault', g));
    const [a, b] = c.sus;
    for (const x of [a, b]) { x.clues = []; x.acq = false; x.served = false; }
    c.sus = [a, b];
    // 뒤쪽만 늦게 탔다(편견 점수가 높다)
    a.facts = []; b.facts = ['joined'];
    expect(suspicion(b)).toBeGreaterThan(suspicion(a));
    expect(topByClues(g, c)?.id).toBe(a.id);
    // 순서를 뒤집어 넣으면 뒤집힌 앞쪽(편견 점수가 높은 쪽)이 피고다: 순서만 보고 점수는 안 본다
    c.sus = [b, a];
    expect(topByClues(g, c)?.id).toBe(b.id);
    // 단서가 한 쪽에 더 있으면 그쪽이 피고다(편견 점수와 상관없이)
    a.clues = [{ kind: 'foot', truth: true, line: '발자국.', seg: 1 }];
    expect(topByClues(g, c)?.id).toBe(a.id);
  });
});

describe('K05 수사·재판 카드에는 탄 경위 문구가 안 나온다', () => {
  const PHRASES = ['판 중에 탔다', '피난길에 탔다', '자리를 사서 탔다', '구조돼 탔다', '차고에서부터 있었다', '밀고 올라탔다', '열차에서 났다', '처음부터 탔다'];
  const add = (g: Game, card: Omit<Card, 'uid'>): Card => { addCard(g, card); return g.cards[g.cards.length - 1]; };

  it('dark:case와 dark:gtrial 본문에 boardingText 문구가 없다', () => {
    const g = darkGame('k05-card');
    const c = openCase(g, args('assault', g));
    g.dark!.joined.push(c.sus[0].id); // 늦게 탄 사람이 용의자로 있다
    c.sus[0].clues = [{ kind: 'witness', truth: true, line: '봤다.', seg: 1 }];
    const inv = viewCard(g, add(g, { kind: 'dark:case', n: c.id, comm: 'guard' }));
    expect(inv.body).toContain('용의자');
    for (const ph of PHRASES) expect(inv.body, `수사 ${ph}`).not.toContain(ph);
    c.status = 'trial';
    const tr = viewCard(g, add(g, { kind: 'dark:gtrial', n: c.id, comm: 'guard' }));
    expect(tr.body).toContain('증거 단계');
    for (const ph of PHRASES) expect(tr.body, `재판 ${ph}`).not.toContain(ph);
  });
});

describe('K05 옛 저장의 후보 목록은 불러온 뒤 다시 센다', () => {
  it('flagged가 아닌 사람이 scapegoatOk에 남은 저장을 불러오면 빠진다', () => {
    const g = darkGame('k05-old');
    openCase(g, args('assault', g));
    g.scapegoatOk = ['옛-후보-id'];
    const r = readSave(JSON.parse(JSON.stringify(g)));
    expect(r.ok).toBe(true);
    if (r.ok) expect(r.g.scapegoatOk).toEqual([]);
  });

  it('단서로 켜진 후보는 불러온 뒤에도 남는다', () => {
    const g = darkGame('k05-old2');
    const c = openCase(g, args('assault', g));
    const x = c.sus.find(y => { const p = PROFILES.find(q => q.id === y.id); return !!p && p.age >= 16 && ['pl', 'de', 'cz'].includes(p.name_lang ?? ''); });
    expect(x, '이름 거름을 지나는 용의자가 있어야 시험이 된다').toBeDefined();
    if (!x) return;
    x.facts = ['car', 'joined'];
    x.clues = [{ kind: 'witness', truth: false, line: '봤다.', seg: 1 }];
    updateFlags(g);
    const before = [...(g.scapegoatOk ?? [])];
    expect(before).toContain(x.id);
    g.scapegoatOk = ['옛-후보-id'];
    const r = readSave(JSON.parse(JSON.stringify(g)));
    expect(r.ok).toBe(true);
    if (r.ok) expect(r.g.scapegoatOk).toEqual(before);
  });
});

