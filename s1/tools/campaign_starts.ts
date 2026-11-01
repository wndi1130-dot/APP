// Campaign boards at the same point as slice_vectors.ts, before to_travel.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import * as S1 from '../src/game';
import type { Game } from '../src/game';
import { tables } from './turn_port_fixtures';

type Start = { state: Game; tables: Record<string, unknown> };
type Fingerprint = { seed: string; initial_rng: number; sha256: string };

const starts: Start[] = [];
const fingerprints: Fingerprint[] = [];
for (let i: number = 1; i <= 10; i += 1) {
  const seed: string = `camp-${String(i).padStart(2, '0')}`;
  const state: Game = S1.createGame(seed);
  S1.enableClimate(state);
  const start: Start = { state, tables: tables() };
  starts.push(start);
  fingerprints.push({
    seed, initial_rng: state.rng.state,
    sha256: createHash('sha256').update(JSON.stringify(state)).digest('hex'),
  });
}
if (new Set(fingerprints.map((row: Fingerprint): string => row.sha256)).size !== 10
  || new Set(fingerprints.map((row: Fingerprint): number => row.initial_rng)).size !== 10) {
  throw new Error('Campaign starts must have ten distinct boards and RNG states');
}
const target: string = resolve(import.meta.dirname, '../../s2/tests/game/fixtures/campaign_starts.json');
const bytes: Buffer = Buffer.from(`${JSON.stringify(starts)}\n`, 'utf8');
let identical: boolean = false;
try { identical = readFileSync(target).equals(bytes); } catch { /* First generation. */ }
if (!identical) writeFileSync(target, bytes);
console.log(JSON.stringify({ count: starts.length, bytes: bytes.length, identical, fingerprints }));
