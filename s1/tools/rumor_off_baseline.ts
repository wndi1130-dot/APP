import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { playGame } from './s1c_bot';
import type { S1aPolicy } from './s1c_bot';

const path = new URL('./rumor_off_baseline.json', import.meta.url);
const verify = process.argv.includes('--verify');
const count = 1000;
const hashes: Record<string, string> = {};
for (const policy of ['caretaker', 'first'] as S1aPolicy[]) {
  for (let i = 0; i < count; i++) {
    const { g } = playGame(`rumor-${i}`, { s1c: false, policy, dom: 'idle' });
    hashes[`${policy}:${i}`] = createHash('sha256').update(JSON.stringify(g)).digest('hex');
  }
}
if (!verify) {
  writeFileSync(path, JSON.stringify({ head: '9714567', count, hashes }, null, 2), { flag: 'wx' });
  console.log(`플래그 연결 전 기존 판 상태 ${count * 2}판 SHA-256 기록 완료`);
} else {
  const baseline = JSON.parse(readFileSync(path, 'utf8')) as { hashes: Record<string, string> };
  const differences = Object.keys(hashes).filter(k => hashes[k] !== baseline.hashes[k]);
  if (differences.length) throw new Error(`끔 상태 차이 ${differences.length}판: ${differences.slice(0, 5).join(', ')}`);
  console.log(`끔 상태 전체 판 JSON SHA-256 ${count * 2}판 일치`);
}
