import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  advance, castVote, chooseCard, COMMON_CONDITIONS, COMMS, CONDITIONS, createGame, currentAgenda, DISEMBARK_LINES, LAWS, makeDeal, PLACES,
  RELATION_LINES, SCENE_LINES,
  primaryAction, resolveStop, SECRET_POOL, toolStatus, viewCard,
} from '../../src/game';

// 화면에 나오는 고정 글과 실제로 한 판 돌며 나온 글(서류 카드, 일지)을 content_rules.json의 오류 규칙으로 검사한다.
// 경고 규칙(상투어 등)은 사람이 본다.

interface Rule { id: string; severity: string; scope: string; terms?: string[]; patterns?: string[]; pattern_flags?: string }
const rules = (JSON.parse(readFileSync(join(__dirname, '../../schema/content_rules.json'), 'utf8')) as { rules: Rule[] }).rules
  .filter(r => r.severity === 'error');

function violations(text: string, dialogue: boolean): string[] {
  const out: string[] = [];
  for (const rule of rules) {
    if (rule.scope === 'dialogue' && !dialogue) continue;
    const hitTerm = (rule.terms ?? []).find(t => text.includes(t));
    const hitPattern = (rule.patterns ?? []).find(p => new RegExp(p, rule.pattern_flags ?? 'iu').test(text));
    if (hitTerm || hitPattern) out.push(`${rule.id}: ${text}`);
  }
  return out;
}

function playedTexts(seed: string): { text: string; dialogue: boolean }[] {
  const g = createGame(seed);
  const texts: { text: string; dialogue: boolean }[] = [];
  for (let guard = 0; guard < 2000 && g.phase !== 'end'; guard += 1) {
    if (g.cards.length > 0) {
      const card = g.cards[0];
      const view = viewCard(g, card);
      texts.push({ text: view.title, dialogue: false }, { text: view.body, dialogue: true });
      for (const ch of view.choices) texts.push({ text: ch.label, dialogue: true });
      chooseCard(g, card.uid, view.choices.findIndex(c => !c.disabled));
      continue;
    }
    if (g.phase === 'stop' && g.stop && !g.stop.done) { resolveStop(g, true); continue; }
    if (g.phase === 'council' && g.council && !g.council.result && currentAgenda(g)) {
      for (const c of COMMS) if (toolStatus(g, c, 'open').ok) makeDeal(g, c, 'open', 0);
      castVote(g);
      continue;
    }
    if (!primaryAction(g).ok) break;
    advance(g);
  }
  for (const e of g.journal) texts.push({ text: e.text, dialogue: false });
  return texts;
}

describe('화면 글 규칙', () => {
  it('법, 장소, 비밀, 거래 조건 글에 금지 표현이 없다', () => {
    const fixed = [
      ...Object.values(LAWS).flatMap(l => [l.title, ...l.changes]),
      ...PLACES.map(p => p.name),
      ...SECRET_POOL.map(s => s.text),
      ...Object.values(CONDITIONS).flat().map(c => c.label),
      ...COMMON_CONDITIONS.map(c => c.label),
      ...Object.values(SCENE_LINES).flat(),
      ...Object.values(DISEMBARK_LINES),
      ...Object.values(RELATION_LINES),
    ];
    expect(fixed.flatMap(t => violations(t, false))).toEqual([]);
  });

  it('여러 판에서 나온 카드와 일지에 금지 표현이 없다', () => {
    const found: string[] = [];
    let seen = 0;
    for (let i = 0; i < 12; i += 1) {
      const texts = playedTexts(`text-${i}`);
      seen += texts.length;
      for (const t of texts) found.push(...violations(t.text, t.dialogue));
    }
    expect(seen).toBeGreaterThan(300);
    expect([...new Set(found)]).toEqual([]);
  });
});
