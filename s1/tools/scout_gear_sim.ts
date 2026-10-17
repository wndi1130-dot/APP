// 정찰 장비(domestic/scout_gear.ts, 결정 371·373·388) 웹 판 재기: 같은 씨앗을 장비 끈 판과 켠 판으로 돌려 견준다.
// 사용: npx tsx tools/scout_gear_sim.ts [판 수=500] [결과 JSON 경로]
// 봇: climate_sim.ts와 같은 웹 새 판 돌봄 봇(재난·죽음의 무게 켬, 씨앗 dw-0~). 켠 판은 봇이 연구로 장비를 얻는 자연 진행이다.
// 웹 봇은 정찰을 보내지 않아서, 정찰 먼저 보내는 인원 정책(PN1, PS4)을 얹은 줄을 같이 잰다.

import { writeFileSync } from 'node:fs';
import { playGame } from './s1c_bot';
import type { BotOptions, CrewPolicy } from './s1c_bot';

const n = Number(process.argv[2] ?? 500);
const out = process.argv[3];
const BASE: BotOptions = { s1c: true, policy: 'caretaker', dom: 'engaged', disasters: true, deathWeight: true };
const DEATH_CARDS = ['orphan', 'keepsake', 'loss_rep', 'loss_child', 'loss_hand', 'chain_push', 'chain_fix', 'heat_after'];

interface Row { end: string; deaths: number; deathCards: number; trustCrisis: boolean; scouts: number; lures: number; noiseUp: number }

function run(gear: boolean, crew?: CrewPolicy): Row[] {
  const rows: Row[] = [];
  for (let i = 0; i < n; i += 1) {
    let crisis = false;
    const opts: BotOptions = { ...BASE, ...(gear ? { scoutGear: true } : {}), ...(crew ? { crew } : {}), probe: { onSettle: x => { if (x.trustCrisis !== null) crisis = true; } } };
    const { g, m } = playGame(`dw-${i}`, opts);
    rows.push({
      end: g.end ?? 'none', deaths: g.deaths.length, deathCards: DEATH_CARDS.reduce((s, k) => s + (m.cards[k] ?? 0), 0), trustCrisis: crisis,
      scouts: m.gear.scouts, lures: m.gear.lures, noiseUp: m.gear.noiseUp,
    });
  }
  return rows;
}

const pct = (k: number, of: number) => (of ? (100 * k) / of : 0);
function summary(rows: Row[]) {
  const mean = (f: (r: Row) => number) => rows.reduce((s, r) => s + f(r), 0) / rows.length;
  return {
    games: rows.length, complete: pct(rows.filter(x => x.end === 'complete').length, rows.length), revolt: pct(rows.filter(x => x.end === 'revolt').length, rows.length),
    deathsMean: mean(r => r.deaths), deathCardsMean: mean(r => r.deathCards), trustCrisis: pct(rows.filter(r => r.trustCrisis).length, rows.length),
    scoutsMean: mean(r => r.scouts), luresMean: mean(r => r.lures), noiseUpMean: mean(r => r.noiseUp),
  };
}

const t0 = Date.now();
const res: Record<string, unknown> = { n, bot: BASE };
for (const crew of [undefined, 'PN1', 'PS4'] as (CrewPolicy | undefined)[]) {
  const key = crew ?? 'web';
  res[key] = { off: summary(run(false, crew)), on: summary(run(true, crew)) };
}
res.secs = (Date.now() - t0) / 1000;
console.log(JSON.stringify(res, null, 2));
if (out) writeFileSync(out, JSON.stringify(res, null, 2));
