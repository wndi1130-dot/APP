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
  s2Wounds: join(root, 'fixtures/receipt/s2_wounds_sample.json'),
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

// 판 2: 부위별 상처(body_injury 4.6). S1은 접는다. 깊은 상처·박힌 것·골절은 부상자, 물림은 물린 사람, 긁힘·찢김만이면 한 구간 안에 낫는다.
const SERIOUS = new Set(['deep', 'embedded', 'fracture']);
const foldGaps = (receipt: Receipt) => {
  const p = receipt.people;
  const gone = new Set([...p.dead, ...p.missing, ...p.leftBehind]);
  return (p.wounds ?? []).flatMap((w: Receipt) => {
    if (gone.has(w.person)) return [];
    if (w.kind === 'bite' && !p.bitten.includes(w.person)) return [`${w.person} bite not in bitten`];
    if (SERIOUS.has(w.kind) && !p.injured.includes(w.person)) return [`${w.person} ${w.kind} not in injured`];
    return [];
  });
};

describe('receipt wounds (version 2)', () => {
  const wounded = () => read(fixtures.s2Wounds);

  it('keeps version and wounds optional for version 1 receipts', () => {
    for (const path of [fixtures.sulechow, fixtures.s2Graybox, fixtures.gdBuilder]) {
      const receipt = read(path);
      expect(receipt).not.toHaveProperty('version');
      expect(receipt.people).not.toHaveProperty('wounds');
    }
    const receipt = sample();
    receipt.version = 1;
    expect(issues(receipt)).toEqual([]);
  });

  it('needs version 2 once wounds are written', () => {
    const receipt = wounded();
    delete receipt.version;
    expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '', keyword: 'required', missing: 'version' }));
    receipt.version = 1;
    expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '/version', keyword: 'minimum' }));
    receipt.version = 3;
    expect(issues(receipt)).toContainEqual(expect.objectContaining({ path: '/version', keyword: 'maximum' }));
  });

  it('accepts an empty wound list and every part and kind', () => {
    const receipt = wounded();
    receipt.people.wounds = [];
    expect(issues(receipt)).toEqual([]);
    const parts = ['head_neck', 'torso', 'arm_left', 'arm_right', 'leg_left', 'leg_right'];
    const kinds = ['scratch', 'laceration', 'deep', 'embedded', 'bite', 'fracture'];
    receipt.people.wounds = parts.flatMap(part => kinds.map(kind => ({ person: 's2_lead', part, kind, festering: kind === 'deep' })));
    expect(issues(receipt)).toEqual([]);
  });

  it.each([
    ['/people/wounds/0/part', (w: Receipt) => { w.part = 'hand_left'; }],
    ['/people/wounds/0/kind', (w: Receipt) => { w.kind = 'burn'; }],
    ['/people/wounds/0/person', (w: Receipt) => { w.person = 'S2 Scout'; }],
    ['/people/wounds/0/festering', (w: Receipt) => { w.festering = 'yes'; }],
    ['/people/wounds/0', (w: Receipt) => { w.bandaged = true; }],
    ['/people/wounds/0', (w: Receipt) => { delete w.kind; }],
  ] as const)('rejects a malformed wound at %s', (path, mutate) => {
    const receipt = wounded();
    mutate(receipt.people.wounds[0]);
    expect(issues(receipt).map(item => item.path)).toContain(path);
  });

  it('folds into the S1 lists: serious wounds are injured, bites are bitten, scratches heal', () => {
    expect(foldGaps(wounded())).toEqual([]);
    const receipt = wounded();
    receipt.people.wounds.push({ person: 's2_crew_02', part: 'leg_right', kind: 'fracture' });
    receipt.people.wounds.push({ person: 's2_crew_03', part: 'arm_left', kind: 'bite' });
    expect(foldGaps(receipt)).toEqual(['s2_crew_02 fracture not in injured', 's2_crew_03 bite not in bitten']);
    receipt.people.injured.push('s2_crew_02');
    receipt.people.dead.push('s2_crew_03');
    expect(foldGaps(receipt)).toEqual([]);
    expect(issues(receipt)).toEqual([]);
  });
});

// 같은 변형 입력을 S1 스키마와 S2 Receipt.check()가 똑같이 판정하는지 보는 공용 판정표(J07).
// S2 쪽은 s2/tests/game/test_receipt_contract.gd가 같은 표를 읽는다.
type Step = (string | number)[];
type ContractCase = { name: string; set: [Step, unknown][]; remove: Step[]; valid: boolean };
const contractDir = join(root, '../s2/tests/game/fixtures');
const contract = JSON.parse(readFileSync(join(contractDir, 'receipt_contract_cases.json'), 'utf8')) as
  { base: string; cases: ContractCase[] };
const applyCase = (base: Receipt, c: ContractCase): Receipt => {
  const out = structuredClone(base);
  const walk = (path: Step) => {
    let node: any = out;
    for (const key of path.slice(0, -1)) node = node[key];
    return [node, path[path.length - 1]] as const;
  };
  for (const [path, value] of c.set) { const [node, key] = walk(path); node[key] = structuredClone(value); }
  for (const path of c.remove) {
    const [node, key] = walk(path);
    if (Array.isArray(node)) node.splice(Number(key), 1); else delete node[key];
  }
  return out;
};

describe('receipt contract table (S1 schema = S2 check)', () => {
  const base = read(join(contractDir, contract.base));
  it('has unique names and both verdicts', () => {
    expect(new Set(contract.cases.map(c => c.name)).size).toBe(contract.cases.length);
    expect(contract.cases.some(c => c.valid)).toBe(true);
    expect(contract.cases.some(c => !c.valid)).toBe(true);
  });
  it.each(contract.cases.map(c => [c.name, c] as const))('%s', (_, c) => {
    const changed = applyCase(base, c);
    if (c.set.length || c.remove.length) expect(changed).not.toEqual(base);
    expect(issues(changed).length === 0).toBe(c.valid);
  });
});
