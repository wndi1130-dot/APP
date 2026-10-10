// S3 맞대기 기록을 JSON으로 낸다. 설명은 tools/s3_record.ts 머리와 s1/README.md.
//
//   npx tsx tools/s3_dump.ts record <시드> [나갈.json] [--deal]
//   npx tsx tools/s3_dump.ts vectors [나갈.json]
//   npx tsx tools/s3_dump.ts tables [나갈.json]
//
// 나갈 파일을 안 주면 표준 출력으로 낸다. 같은 인자면 늘 같은 바이트가 나온다.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { calcVectors, dataTables, recordGame } from './s3_record';

const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
const flags = process.argv.slice(2).filter(a => a.startsWith('--'));
const [mode, ...rest] = args;

function usage(): never {
  console.error('사용: s3_dump.ts record <시드> [나갈.json] [--deal] | vectors [나갈.json] | tables [나갈.json]');
  process.exit(2);
}

let data: unknown;
let out: string | undefined;
if (mode === 'record') {
  if (rest[0] === undefined) usage();
  data = recordGame(rest[0], flags.includes('--deal'));
  out = rest[1];
} else if (mode === 'vectors') {
  data = calcVectors();
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
