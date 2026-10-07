import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import Ajv2020 from 'ajv/dist/2020.js';
import type { AnySchema } from 'ajv';

// Same Ajv options as tools/validate.ts. The receipt schema refs common, place and chronicle.
const root = fileURLToPath(new URL('../', import.meta.url));
const schemaFile = (name: string) =>
  JSON.parse(readFileSync(join(root, 'schema', `${name}.schema.json`), 'utf8')) as AnySchema;
const ajv = new Ajv2020({ allErrors: true, strict: true, allowUnionTypes: true });
for (const name of ['common', 'place', 'chronicle', 'receipt']) ajv.addSchema(schemaFile(name));
const validator = ajv.getSchema('urn:s1:schema:receipt');
if (!validator) throw new Error('영수증 스키마를 찾을 수 없습니다.');
const validate = validator;

type Receipt = Record<string, any>;
const read = (path: string): Receipt => JSON.parse(readFileSync(path, 'utf8'));
const fixtures = {
  sulechow: join(root, 'fixtures/receipt/sulechow_sample.json'),
  s2Graybox: join(root, 'fixtures/receipt/s2_graybox_sample.json'),
  // Written by the GDScript builder (s2/tests/game/test_receipt.gd); both sides read this file.
  gdBuilder: join(root, '../s2/tests/game/fixtures/receipt_gd_sample.json'),
};
const issues = (value: unknown) => (validate(value) ? [] : (validate.errors ?? []).map(error =>
  ({ path: error.instancePath, keyword: error.keyword, missing: error.params.missingProperty as string | undefined })));
const sample = () => read(fixtures.s2Graybox);

describe('receipt fixtures', () => {
  it.each(Object.entries(fixtures))('%s passes the schema', (_, path) => {
    expect(issues(read(path))).toEqual([]);
  });

  it('uses draft 2020-12 and the urn id scheme', () => {
    const schema = schemaFile('receipt') as Record<string, unknown>;
    expect(schema.$schema).toBe('https://json-schema.org/draft/2020-12/schema');
    expect(schema.$id).toBe('urn:s1:schema:receipt');
  });

  it('keeps the S2-only fields on the S2 samples and leaves them out of the S3 example', () => {
    const s2 = read(fixtures.s2Graybox);
    expect(s2).toMatchObject({ source: 'direct', endReason: 'departed' });
    expect(s2.decisions).toContainEqual({ id: 'raider_surrender', choice: 'disarm_release' });
    const gd = read(fixtures.gdBuilder);
    expect(gd.source).toBe('direct');
    expect(gd.decisions.map((item: Receipt) => item.id)).toEqual(['water_tower', 'raider_surrender']);
    const s3 = read(fixtures.sulechow);
    for (const key of ['source', 'endReason', 'decisions']) expect(s3).not.toHaveProperty(key);
  });
});

describe('receipt rejections', () => {
  it.each(['place', 'time', 'stock', 'items', 'people', 'witnessed', 'placeState', 'promises'])(
    'requires %s', key => {
      const receipt = sample();
      delete receipt[key];
      expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '', keyword: 'required', missing: key }));
    },
  );

  it.each([-1, 0, 1.5])('checks stayGameMinutes as a nonnegative integer (%s)', minutes => {
    const receipt = sample();
    receipt.time.stayGameMinutes = minutes;
    const found = issues(receipt);
    if (minutes === 0) expect(found).toEqual([]);
    else expect(found).toContainEqual(expect.objectContaining({ path: '/time/stayGameMinutes' }));
  });

  it.each(['D1 00:00', 'D12 23:59'])('accepts clock %s', clock => {
    const receipt = sample();
    receipt.time.arrive = clock;
    expect(issues(receipt)).toEqual([]);
  });

  it.each(['D0 10:30', 'D1 24:00', 'D1 10:60', 'D1 9:30', '10:30', ''])('rejects clock "%s"', clock => {
    const receipt = sample();
    receipt.time.depart = clock;
    expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '/time/depart', keyword: 'pattern' }));
  });

  it('allows signed integer stock deltas on known keys only', () => {
    const receipt = sample();
    receipt.stock = { coal: -3, info: 1, wood: 0, ammo_shell: -12 };
    expect(issues(receipt)).toEqual([]);
    receipt.stock.coal = 1.5;
    expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '/stock/coal', keyword: 'type' }));
    receipt.stock = { secret: 1 };
    expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '/stock', keyword: 'additionalProperties' }));
    receipt.stock = {};
    expect(issues(receipt)).toEqual([]);
  });

  it('takes S1, NPC and S2 person ids but rejects duplicates and malformed ids', () => {
    const receipt = sample();
    receipt.people.sent = ['p_001', 'p_chief', 'npc_signalman', 's2_lead'];
    expect(issues(receipt)).toEqual([]);
    receipt.people.sent.push('s2_lead');
    expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '/people/sent', keyword: 'uniqueItems' }));
    receipt.people.sent = ['S2-Lead'];
    expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '/people/sent/0', keyword: 'pattern' }));
    receipt.people.sent = [];
    delete receipt.people.rescued;
    expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '/people', missing: 'rescued' }));
  });

  it('keeps items as lists that may repeat', () => {
    const receipt = sample();
    receipt.items.gained = ['weapon_pistol', 'weapon_pistol'];
    expect(issues(receipt)).toEqual([]);
    delete receipt.items.lost;
    expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '/items', missing: 'lost' }));
  });

  it('checks place type against the place schema', () => {
    const receipt = sample();
    receipt.place.type = 'station';
    expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '/place/type', keyword: 'enum' }));
  });

  it('reuses chronicle fields for witnessed entries', () => {
    const receipt = sample();
    receipt.witnessed[0] = { ...receipt.witnessed[0], id: 'ch_raiders_freed', when: 3, weight: 1, template: 'tpl_raiders_freed',
      witnesses: ['tail', { person: 's2_medic', text: '총을 내려놓게 했다.' }] };
    expect(issues(receipt)).toEqual([]);
    receipt.witnessed[0].when = -1;
    expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '/witnessed/0/when' }));
    receipt.witnessed[0].when = 'D1 13:55';
    delete receipt.witnessed[0].why;
    expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '/witnessed/0', missing: 'why' }));
    receipt.witnessed[0].why = 'raiders_surrendered';
    receipt.witnessed[0].note = 'extra';
    expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '/witnessed/0', keyword: 'additionalProperties' }));
  });

  it.each([[-0.01, false], [0, true], [1, true], [1.01, false]] as const)('bounds looted to 0..1 (%s)', (looted, ok) => {
    const receipt = sample();
    receipt.placeState.looted = looted;
    expect(issues(receipt).length === 0).toBe(ok);
  });

  it('lets placeState carry extra keys but needs remainingRisk as an integer', () => {
    const receipt = sample();
    receipt.placeState.bridgeOder = 'blocked';
    expect(issues(receipt)).toEqual([]);
    receipt.placeState.remainingRisk = -1;
    expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '/placeState/remainingRisk', keyword: 'minimum' }));
  });

  it('checks promises, source, endReason and decisions', () => {
    const cases: [string, (receipt: Receipt) => void][] = [
      ['/promises/0/kept', receipt => { receipt.promises = [{ leader: 'rep_engine', condition: 'bring_coal', kept: 'yes' }]; }],
      ['/source', receipt => { receipt.source = 'manual'; }],
      ['/endReason', receipt => { receipt.endReason = 'fled'; }],
      ['/decisions/1', receipt => { delete receipt.decisions[1].choice; }],
      ['', receipt => { receipt.extra = true; }],
      ['/content_type', receipt => { receipt.content_type = 'chronicle'; }],
    ];
    for (const [path, mutate] of cases) {
      const receipt = sample();
      mutate(receipt);
      expect(issues(receipt).map(item => item.path), path).toContain(path);
    }
    const receipt = sample();
    receipt.content_type = 'receipt';
    receipt.source = 'auto';
    for (const reason of ['departed', 'limit', 'wiped']) {
      receipt.endReason = reason;
      expect(issues(receipt)).toEqual([]);
    }
  });
});
