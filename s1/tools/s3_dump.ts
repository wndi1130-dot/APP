// S3 맞대기 기록을 JSON으로 낸다. 설명은 tools/s3_record.ts 머리와 s1/README.md.
//
//   npx tsx tools/s3_dump.ts record <시드> [나갈.json] [--deal | --deal=open|favor|fetch|bribe|blackmail]
//   npx tsx tools/s3_dump.ts vectors [나갈.json] [--only=algo|data]
//   npx tsx tools/s3_dump.ts tables [나갈.json]
//
// 나갈 파일을 안 주면 표준 출력으로 낸다. 같은 인자면 늘 같은 바이트가 나온다.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import type { DealTool } from '../src/game';
import { algoVectors, calcVectors, dataTables, dataVectors, recordGame } from './s3_record';

const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
const flags = process.argv.slice(2).filter(a => a.startsWith('--'));
const [mode, ...rest] = args;

function usage(): never {
  console.error('사용: s3_dump.ts record <시드> [나갈.json] [--deal[=도구]] | vectors [나갈.json] [--only=algo|data] | tables [나갈.json]');
  process.exit(2);
}

let data: unknown;
let out: string | undefined;
if (mode === 'record') {
  if (rest[0] === undefined) usage();
  const tool = flags.find(f => f.startsWith('--deal='))?.slice(7);
  if (tool !== undefined && !['open', 'favor', 'fetch', 'bribe', 'blackmail'].includes(tool)) usage();
  data = recordGame(rest[0], (tool as DealTool | undefined) ?? flags.includes('--deal'));
  out = rest[1];
} else if (mode === 'vectors') {
  const only = flags.find(f => f.startsWith('--only='))?.slice(7);
  if (only !== undefined && only !== 'algo' && only !== 'data') usage();
  data = only === 'algo' ? algoVectors() : only === 'data' ? dataVectors() : calcVectors();
  out = rest[0];
} else if (mode === 'tables') {
  data = dataTables();
  out = rest[0];
} else usage();

const text = `${JSON.stringify(data, null, 1)}\n`;
if (out) {
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, text);
  console.error(`${out} (${text.length}자)`);
} else process.stdout.write(text);
