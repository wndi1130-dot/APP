import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { playGame } from './s1c_bot';
import type { GameMetrics, S1aPolicy } from './s1c_bot';

const n = Number(process.argv[2] ?? 1000);
if (!Number.isInteger(n) || n < 1) throw new Error('판 수는 양의 정수여야 한다');
const prefix = process.argv[3] ?? 'tools/rumor_sim';
const runs: Record<string, unknown> = {};
const baseline = JSON.parse(readFileSync(new URL('./rumor_off_baseline.json', import.meta.url), 'utf8')) as { hashes: Record<string, string> };
let baselineMatches = 0;
const comparisons: Record<string, unknown> = {};
const t0 = Date.now();
const mean = (ms: GameMetrics[], f: (m: GameMetrics) => number) => ms.reduce((s, m) => s + f(m), 0) / ms.length;
for (const policy of ['caretaker', 'first'] as S1aPolicy[]) {
  let off: GameMetrics[] = [];
  for (const rumor of [false, true]) {
    const ms: GameMetrics[] = [];
    for (let i = 0; i < n; i++) {
      const { g, m } = playGame(`rumor-${i}`, { s1c: false, policy, dom: 'idle', rumor });
      if (g.phase !== 'end' || !g.end) throw new Error(`F-NOT-TERMINAL: ${policy}/${rumor}/${i} ${g.phase}/${g.seg}`);
      if (!rumor && i < 1000) {
        const hash = createHash('sha256').update(JSON.stringify(g)).digest('hex');
        if (hash !== baseline.hashes[`${policy}:${i}`]) throw new Error(`F-OFF-REGRESSION: ${policy}/${i}`);
        baselineMatches++;
      }
      ms.push(m);
    }
    const votes = ms.reduce((s, m) => s + m.voteTotal, 0);
    const passed = ms.reduce((s, m) => s + m.votesPassed, 0);
    const key = `${policy}/${rumor ? 'on' : 'off'}`;
    runs[key] = {
      games: n, terminal: n,
      completed: ms.filter(m => m.end === 'complete').length,
      completionRate: mean(ms, m => +(m.end === 'complete')),
      votes, passed, votePassRate: votes ? passed / votes : null,
      tensionPeakMean: mean(ms, m => m.tensionPeak),
      rumorCardsMean: mean(ms, m => m.cards.rumor ?? 0),
      overlapMean: mean(ms, m => m.rumorOverlaps),
      cardsMean: mean(ms, m => m.titleTotal),
      repeatedCardsMean: mean(ms, m => m.titleRepeats),
      travelCardsMean: mean(ms, m => Object.values(m.travelById).reduce((a, b) => a + b, 0)),
      travelRepeatsMean: mean(ms, m => m.travelRepeats),
      contentCardsMean: mean(ms, m => Object.values(m.contentById).reduce((a, b) => a + b, 0)),
      contentRepeatsMean: mean(ms, m => m.contentRepeats),
      segmentsMean: mean(ms, m => m.segReached),
      rumorChoices: [0, 1, 2].map(j => ms.reduce((s, m) => s + m.rumorChoices[j], 0)),
      ends: Object.fromEntries(['complete', 'stranded', 'ousted', 'revolt'].map(e => [e, ms.filter(m => m.end === e).length])),
    };
    if (!rumor) off = ms;
    else {
      const delta = ms.map((m, i) => +(m.end === 'complete') - +(off[i].end === 'complete'));
      const avg = delta.reduce((a, b) => a + b, 0) / n;
      const variance = delta.reduce((s, x) => s + (x - avg) ** 2, 0) / Math.max(1, n - 1);
      const both = ms.map((m, i) => ({ on: m, off: off[i] })).filter(p => p.on.end === 'complete' && p.off.end === 'complete');
      comparisons[policy] = {
        completionDelta: avg, paired95HalfWidth: 1.96 * Math.sqrt(variance / n),
        bothComplete: both.length,
        bothCompleteCardsDelta: both.reduce((s, p) => s + p.on.titleTotal - p.off.titleTotal, 0) / Math.max(1, both.length),
        bothCompleteRepeatedCardsDelta: both.reduce((s, p) => s + p.on.titleRepeats - p.off.titleRepeats, 0) / Math.max(1, both.length),
      };
    }
    // 각 묶음이 끝나는 즉시 기록한다. 나중 묶음이 실패해도 관찰값을 남긴다.
    writeFileSync(`${prefix}.json`, JSON.stringify({ n, base: '9714567', seeds: 'rumor-0..rumor-(n-1)', elapsedSeconds: (Date.now() - t0) / 1000, baselineMatches, runs, comparisons }, null, 2));
    console.log(`${key}: ${JSON.stringify(runs[key])}`);
  }
}
console.log(`완료: ${n * 4}판, ${(Date.now() - t0) / 1000}초`);
