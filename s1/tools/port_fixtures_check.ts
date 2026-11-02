// S2 맞대기 표본이 지금 S1 코드로 뽑은 값과 같은지 본다. 표 칸만 늦은 표본이 PR 다섯(#672·#688·#721·#727·#815·#820)에
// 걸쳐 조용히 쌓여도 S2 맞대기 시험은 저장된 표본끼리 견주니 못 잡았다(코디네이터 10-28).
// 표본 도구를 모두 다시 돌리고, 돌리기 전 파일과 다르면 어느 파일·어느 칸인지 찍고 1로 끝난다.
// 다시 뽑은 파일은 그대로 두니, 로컬에서는 이 도구를 돌린 뒤 바뀐 표본을 그대로 커밋하면 된다.
// 사용: npx tsx tools/port_fixtures_check.ts
import { spawn } from 'node:child_process';
import { availableParallelism } from 'node:os';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const S1_DIR = resolve(import.meta.dirname, '..');
const ROOT = resolve(S1_DIR, '..');
const TRAIN = 's2/tests/fixtures/train';
const SHOW = 10;  // 파일마다 찍는 다른 칸 수
// 소수 끝자리(1 ULP 안팎)는 OS마다 Math 결과가 달라 같은 값으로 본다. 윈도에서 뽑은 train 표본을 CI 리눅스가
// 다시 뽑으면 stopRisk의 lam·pDeath 45칸이 끝자리만 달랐다(10-28). S2 맞대기 시험도 소수 일부는 오차를 두고 견준다.
const EPS = 1e-12;

// [도구, 인자, 그 도구가 쓰는 표본(저장소 뿌리 기준)]
const TOOLS: [string, string[], string[]][] = [
  ['stranded_port_fixtures', [], [`${TRAIN}/stranded_vectors.json`, `${TRAIN}/stranded_content_vectors.json`]],
  ['content_port', [], ['s2/game/train/content_events.json', `${TRAIN}/turn_vectors_eventpack.json`, `${TRAIN}/content_vectors.json`]],
  ['card_view_fixtures', [], [`${TRAIN}/card_vectors.json`]],
  ['deal_port_fixtures', [], [`${TRAIN}/deal_vectors.json`]],
  ['ladder_port_fixtures', [], [`${TRAIN}/ladder_vectors.json`]],
  ['law_port_fixtures', [], [`${TRAIN}/law_vectors.json`]],
  ['lawtech_port_fixtures', [], [`${TRAIN}/lawtech_vectors.json`]],
  ['mods_port_fixtures', [], [`${TRAIN}/mods_vectors.json`]],
  ['route_weather_fixtures', [], [`${TRAIN}/route_weather.json`]],
  ['slice_vectors', [], [`${TRAIN}/slice_vectors.json`, 's2/game/train/slice_start.json']],
  ['tech_port_fixtures', [], [`${TRAIN}/tech_vectors.json`]],
  ['train_port_fixtures', [], [`${TRAIN}/train_vectors.json`]],
  ['turn_port_fixtures', [], [`${TRAIN}/turn_vectors.json`]],
  ['turn_port_fixtures', ['--climate'], [`${TRAIN}/turn_vectors_climate.json`]],
  ['field_port_fixtures', [], ['s2/tests/game/fixtures/field_port/field_vectors.json']],
  ['end_port_fixtures', [], [`${TRAIN}/end_vectors.json`]],
];

function text(path: string): string {
  try { return readFileSync(resolve(ROOT, path), 'utf8').replace(/\r\n/g, '\n'); } catch { return ''; }
}

function short(v: unknown): string {
  if (v === undefined) return '없음';
  const s = JSON.stringify(v);
  return s.length > 80 ? `${s.slice(0, 77)}...` : s;
}

function diffs(a: unknown, b: unknown, at: string, out: string[], noise: { n: number }): void {
  if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length !== b.length) out.push(`${at} 길이: ${a.length} → ${b.length}`);
    for (let i = 0; i < Math.min(a.length, b.length); i++) diffs(a[i], b[i], `${at}/${i}`, out, noise);
  } else if (a && b && typeof a === 'object' && typeof b === 'object' && !Array.isArray(a) && !Array.isArray(b)) {
    const x = a as Record<string, unknown>;
    const y = b as Record<string, unknown>;
    for (const k of [...new Set([...Object.keys(x), ...Object.keys(y)])].sort()) diffs(x[k], y[k], `${at}/${k}`, out, noise);
  } else if (typeof a === 'number' && typeof b === 'number' && a !== b
    && Math.abs(a - b) <= EPS * Math.max(1, Math.abs(a), Math.abs(b))) {
    noise.n++;
  } else if (JSON.stringify(a) !== JSON.stringify(b)) {
    out.push(`${at}: ${short(a)} → ${short(b)}`);
  }
}

function run(tool: string, args: string[]): Promise<{ code: number; log: string; s: number }> {
  const t0 = Date.now();
  return new Promise(done => {
    const p = spawn(process.execPath, ['--import', 'tsx', `tools/${tool}.ts`, ...args], { cwd: S1_DIR });
    let log = '';
    p.stdout.on('data', d => { log += d; });
    p.stderr.on('data', d => { log += d; });
    p.on('close', code => done({ code: code ?? 1, log, s: (Date.now() - t0) / 1000 }));
  });
}

async function main(): Promise<void> {
  const before = new Map<string, string>();
  for (const [, , outs] of TOOLS) for (const f of outs) before.set(f, text(f));
  const t0 = Date.now();
  const results: { code: number; log: string; s: number }[] = new Array(TOOLS.length);
  // Stranded inputs read slice_start.json; generate them after its owning tool completes.
  const stranded = TOOLS.findIndex(([tool]) => tool === 'stranded_port_fixtures');
  let next = 0;
  const lane = async (): Promise<void> => {
    while (next < TOOLS.length) {
      const i = next++;
      if (i === stranded) continue;
      results[i] = await run(TOOLS[i][0], TOOLS[i][1]);
    }
  };
  await Promise.all(Array.from({ length: Math.min(availableParallelism(), TOOLS.length) }, lane));
  results[stranded] = await run(TOOLS[stranded][0], TOOLS[stranded][1]);
  let bad = 0;
  TOOLS.forEach(([tool, args], i) => {
    const r = results[i];
    console.log(`${tool}${args.length ? ` ${args.join(' ')}` : ''}: ${r.s.toFixed(1)}초`);
    if (r.code !== 0) {
      bad++;
      console.log(`  도구가 ${r.code}로 끝남\n${r.log.trim().split('\n').slice(-8).map(l => `  ${l}`).join('\n')}`);
    }
  });
  for (const [f, old] of before) {
    const now = text(f);
    if (now === old) continue;
    const found: string[] = [];
    const noise = { n: 0 };
    try { diffs(JSON.parse(old || 'null'), JSON.parse(now), '', found, noise); } catch { found.push('(JSON으로 못 읽음)'); }
    if (!found.length) {
      console.log(`${f}: 소수 끝자리만 ${noise.n}칸 다름 — 같은 값으로 봄`);
      continue;
    }
    bad++;
    console.log(`\n✗ ${f}: 지금 S1 코드로 뽑은 값과 다름 — 다른 칸 ${found.length}`);
    for (const line of found.slice(0, SHOW)) console.log(`  ${line}`);
    if (found.length > SHOW) console.log(`  … ${found.length - SHOW}칸 더`);
  }
  console.log(`\n표본 ${before.size}개, 도구 ${TOOLS.length}번, ${((Date.now() - t0) / 1000).toFixed(1)}초`);
  if (bad) {
    console.log('다시 뽑기: cd s1 && npx tsx tools/port_fixtures_check.ts 뒤 바뀐 표본을 커밋한다.');
    process.exit(1);
  }
  console.log('모든 표본이 지금 S1 코드로 뽑은 값과 같다.');
}

await main();
