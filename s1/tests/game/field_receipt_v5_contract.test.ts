import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { decodeFieldReceipt } from '../../src/game/field_receipt';

// S2 test_receipt_v5_contract.gd applies this same table to Receipt.check().
type Step = (string | number)[];
type ContractCase = { name: string; set: [Step, unknown][]; remove: Step[]; valid: boolean };
type Fixture = Record<string, unknown>;
const contractDir = fileURLToPath(new URL('../../../s2/tests/game/fixtures/', import.meta.url));
const contract = JSON.parse(readFileSync(join(contractDir, 'receipt_v5_contract_cases.json'), 'utf8')) as
  { base: string; cases: ContractCase[] };

// Keep set/remove traversal identical to tests/receipt.test.ts and the S2 runner.
function applyCase(base: Fixture, c: ContractCase): Fixture {
  const out = structuredClone(base);
  const walk = (path: Step) => {
    let node: any = out;
    for (const key of path.slice(0, -1)) node = node[key];
    return [node, path[path.length - 1]] as const;
  };
  for (const [path, value] of c.set) {
    const [node, key] = walk(path);
    node[key] = structuredClone(value);
  }
  for (const path of c.remove) {
    const [node, key] = walk(path);
    if (Array.isArray(node)) node.splice(Number(key), 1); else delete node[key];
  }
  return out;
}

describe('field receipt v5 contract table (S1 schema = S2 check)', () => {
  const base = JSON.parse(readFileSync(join(contractDir, contract.base), 'utf8')) as Fixture;

  it('has unique names and both verdicts', () => {
    expect(new Set(contract.cases.map(c => c.name)).size).toBe(contract.cases.length);
    expect(contract.cases.some(c => c.valid)).toBe(true);
    expect(contract.cases.some(c => !c.valid)).toBe(true);
  });

  it.each(contract.cases.map(c => [c.name, c] as const))('%s', (_, c) => {
    const changed = applyCase(base, c);
    if (c.set.length || c.remove.length) expect(changed).not.toEqual(base);
    if (c.valid) expect(() => decodeFieldReceipt(changed)).not.toThrow();
    else expect(() => decodeFieldReceipt(changed)).toThrow();
  });
});
