import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { buildContentBundle, buildContentFixtures, OUTPUTS } from '../tools/content_port';
import { readContentEvents } from '../tools/content_fs';
import { CONTENT_EVENTS, CONTENT_SECRETS, CONTENT_DEALS, DRAW } from '../src/game';
import { inEventPack } from '../src/game/event_pack';

const bundle = buildContentBundle();
const fixtures = buildContentFixtures(bundle);
const root = resolve(import.meta.dirname, '../..');

describe('S2 content export tool (S1 rules remain the oracle)', () => {
  it('exports all 46 pack events in filesystem order, retaining the original text and log fields', () => {
    const source = readContentEvents() as { id: string; phase: string }[];
    expect(bundle.events).toEqual(source.filter(ev => ev.phase === 'travel' && !ev.id.startsWith('ev_str_')));
    expect(bundle.events.filter(ev => inEventPack(ev.id))).toHaveLength(46);
    expect(bundle.events.some(ev => ev.id.startsWith('ev_str_'))).toBe(false);
    expect(bundle.draw).toEqual(DRAW);
    expect(bundle._note).toContain('ev_str_* excluded');
  });

  it('includes a future ordinary travel event and excludes stop/stranded content', () => {
    const base = bundle.events[0];
    const result = buildContentBundle([
      { ...base, id: 'ev_future' }, { ...base, id: 'ev_str_future' }, { ...base, id: 'ev_stop', phase: 'stop' }, base,
    ], [], []);
    expect(result.events.map(ev => ev.id)).toEqual(['ev_future', base.id]);
    expect(result.secrets).toEqual([]);
    expect(result.deals).toEqual([]);
  });

  it('has four fresh replay runs of at least 30 steps with actual content choices', () => {
    expect(new Set(fixtures.turns.runs.map(run => run.seed)).size).toBe(4);
    for (const run of fixtures.turns.runs) {
      expect(run.steps.length).toBeGreaterThanOrEqual(30);
      expect(run.contentChoices).toBeGreaterThan(0);
      expect(run.steps[0].before.eventPack).toBe(true);
      expect(run.steps[0].before.lateOn).toBe(true);
      for (let i = 1; i < run.steps.length; i++) expect(run.steps[i].before).toEqual(run.steps[i - 1].after);
    }
  });

  it('covers every first view and every enabled first-view answer, including the existing journal path', () => {
    const rows = fixtures.cards.views.filter(row => row.name.startsWith('first/'));
    expect(rows.map(row => row.card.text)).toEqual(bundle.events.map(ev => ev.id));
    for (const row of rows) {
      expect(row.choices.length).toBe(row.view.choices.filter(ch => !ch.disabled).length);
      for (const result of row.choices) {
        const ch = row.view.choices[result.index];
        expect(result.after.eventLog?.[`content:${row.card.text}`]?.pick).toBe(ch.label);
        const line = ch.log ?? `${row.view.title}: ${ch.label}.`;
        expect(result.after.journal.some(entry => entry.text === line)).toBe(true);
      }
    }
  });

  it('includes hidden requires, the all-hidden escape, binding, followup order and save data', () => {
    const find = (name: string) => fixtures.cards.views.find(row => row.name === name)!;
    expect(find('probe/port_requires').view.choices.map(ch => ch.special)).toEqual(['content:wait']);
    expect(find('probe/port_all_hidden').choices).toHaveLength(2);
    expect(find('bind/all-placeholders').view.body).not.toMatch(/\{[a-z0-9]+\}/);
    expect(find('bind/all-placeholders').view.choices[0].log).not.toContain('{');
    const ordered = fixtures.cards.parts.find(row => row.name === 'followup/choice-front-order')!;
    expect(ordered.after.cards.slice(0, 3).map(card => card.text)).toEqual(['port_front_c', 'port_front_b', 'port_front_a']);
    expect(fixtures.cards.save.after.eventPack).toBe(true);
    for (const key of ['contentAway', 'contentInjured', 'contentSecrets', 'contentDeals', 'contentQueue', 'chronicle', 'voteShift'] as const) {
      expect(fixtures.cards.save.after[key]).toEqual(fixtures.cards.save.before[key]);
    }
    expect(fixtures.cards.draws.filter(row => !row.before.eventPack)).toHaveLength(4);
    expect(fixtures.cards.views.filter(row => row.name.startsWith('requires/'))).toHaveLength(10);
    expect(fixtures.cards.draws.some(row => row.before.recentEvents.slice(-2).some(id => id.startsWith('content:') && bundle.events.some(ev => id === `content:${ev.id}`)))).toBe(true);
  });

  it('selects three real card shots and keeps source registries intact across deterministic generation', () => {
    const before = JSON.stringify([CONTENT_EVENTS, CONTENT_SECRETS, CONTENT_DEALS]);
    expect(buildContentFixtures(bundle)).toEqual(fixtures);
    expect(JSON.stringify([CONTENT_EVENTS, CONTENT_SECRETS, CONTENT_DEALS])).toBe(before);
    expect(fixtures.cards.shots.map(shot => shot.name)).toEqual(['short', 'longest', 'why_later']);
    for (const shot of fixtures.cards.shots) expect(fixtures.cards.views.some(row => row.name === shot.case && row.name.startsWith('first/'))).toBe(true);
  });

  it('matches every checked-in export without rewriting any existing fixture', () => {
    const expected = [bundle, fixtures.turns, fixtures.cards];
    OUTPUTS.forEach((path, index) => expect(JSON.parse(readFileSync(resolve(root, path), 'utf8'))).toEqual(expected[index]));
  });
});
