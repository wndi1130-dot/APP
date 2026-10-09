import { describe, it } from 'vitest';
import { rumorChecks } from '../../tools/rumor_checks';

describe('C1 소문 시제품', () => {
  for (const [name, check] of Object.entries(rumorChecks)) it(name, check);
});
