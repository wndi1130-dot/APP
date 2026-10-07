// 오류 재현 묶음 읽기(r8 출시 실무 3). 사용: npx tsx tools/repro.ts 묶음.json [--save 나갈.json]
// 메뉴의 '오류 재현 묶음 복사'로 받은 JSON을 파일로 두고 돌린다. 직전 저장에 마지막 행동을 다시 해서
// 같은 오류가 나는지(행동 쪽 오류), 아니면 지금 저장과 똑같이 되는지(그리기 쪽 오류이거나 재현 성공) 알려 준다.
// --save는 직전 저장을 브라우저 저장 칸(s1a.game.v2)에 넣을 수 있는 JSON으로 써 준다.

import { readFileSync, writeFileSync } from 'node:fs';
import { replayBundle } from '../src/ui/repro';
import type { ReproBundle } from '../src/ui/repro';

const [file, flag, out] = process.argv.slice(2);
if (!file) {
  console.error('사용: npx tsx tools/repro.ts 묶음.json [--save 나갈.json]');
  process.exit(2);
}
const raw = readFileSync(file, 'utf8').trim();
const b = JSON.parse(raw.slice(raw.indexOf('{'), raw.lastIndexOf('}') + 1)) as ReproBundle;
if (b.kind !== 's1a-repro') throw new Error('재현 묶음이 아니다');

console.log(`빌드 ${b.build} · 시드 ${b.seed} · ${b.s1c ? 'S1c 켠 판' : 'S1a 판'} · ${b.when} · 화면 ${b.screen ?? '?'}`);
console.log(`지금 ${b.now.seg}구간 ${b.now.phase}${b.now.end ? ` (끝: ${b.now.end})` : ''}`);
console.log('최근 행동:');
for (const e of b.trail.slice(-12)) console.log(`  ${e.seg}구간 ${e.phase} ${e.a} ${JSON.stringify(e.d)}`);
if (b.error) console.log(`남은 오류: ${b.error.msg}${b.error.step ? ` (행동 ${b.error.step.a})` : ''}\n${b.error.stack ?? ''}`);

const r = replayBundle(b);
if (r.thrown) {
  console.log(`\n재현됨: 직전 저장에 '${r.last?.a}'를 다시 하니 같은 오류가 난다.\n${r.thrown.stack}`);
} else if (r.same) {
  console.log(`\n직전 저장에 '${r.last?.a}'를 다시 하니 지금 저장과 똑같다.${b.error ? ' 오류는 행동이 아니라 그리기나 타이머 쪽이다.' : ''}`);
} else {
  console.log(`\n다시 한 판이 지금 저장과 다르다: ${r.diff.join(', ')}`);
}
if (flag === '--save' && out && b.prev) {
  writeFileSync(out, JSON.stringify(b.prev));
  console.log(`직전 저장을 ${out}에 썼다.`);
}
