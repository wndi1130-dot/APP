import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { validateContent } from '../tools/validate';

const resourceKeys = ['coal', 'food', 'medicine', 'luxury', 'symbol', 'secret'] as const;
const fixture = () => JSON.parse(readFileSync(new URL('../fixtures/valid/place.json', import.meta.url), 'utf8'));
const errors = (value: unknown) => validateContent(value, 'place.json')
  .filter(item => item.severity === 'error');
const draftFile = fileURLToPath(new URL('../../ref/places_loot_draft.json', import.meta.url));
const draft = JSON.parse(readFileSync(draftFile, 'utf8')) as { places: unknown[] };

describe('place loot contract', () => {
  it.each([0, 0.5, 2])('accepts all six weights as nonnegative numbers (%s)', weight => {
    const place = fixture();
    place.loot = Object.fromEntries(resourceKeys.map(key => [key, weight]));
    expect(validateContent(place, 'place.json')).toEqual([]);
  });

  it.each(resourceKeys)('rejects a negative %s weight', key => {
    const place = fixture();
    place.loot[key] = -0.5;
    expect(errors(place)).toContainEqual(expect.objectContaining({
      path: `/loot/${key}`, code: 'schema.minimum',
    }));
  });

  it.each(resourceKeys)('rejects nonnumeric %s weights without coercion', key => {
    for (const value of ['1', null, true, [], {}]) {
      const place = fixture();
      place.loot[key] = value;
      expect(errors(place)).toContainEqual(expect.objectContaining({
        path: `/loot/${key}`, code: 'schema.type',
      }));
    }
  });

  it.each(resourceKeys)('requires the %s weight', key => {
    const place = fixture();
    delete place.loot[key];
    expect(errors(place)).toContainEqual(expect.objectContaining({
      path: `/loot/${key}`, code: 'schema.required',
    }));
  });

  it('rejects an unknown loot key', () => {
    const place = fixture();
    place.loot.wood = 1;
    expect(errors(place)).toContainEqual(expect.objectContaining({
      path: '/loot/wood', code: 'schema.additionalProperties',
    }));
  });

  it('accepts all six B5 draft places through the content validator', () => {
    expect(draft.places).toHaveLength(6);
    draft.places.forEach((place, index) => {
      expect(validateContent(place, draftFile, `/places/${index}`)).toEqual([]);
    });
  });
});
