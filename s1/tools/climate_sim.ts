// 바깥 기온·결빙(climate.ts, 결정 370) 재기: 같은 씨앗을 기온 끈 판과 켠 판으로 돌려 견준다.
// 사용: npx tsx tools/climate_sim.ts [판 수=500] [결과 JSON 경로]
// 봇: 웹 새 판과 같게 재난·죽음의 무게를 켠 돌봄 봇(death_weight_sim.ts와 같은 씨앗 dw-0~). 끈 판이 기준이다(같은 커밋).

import { writeFileSync } from 'node:fs';
import { playGame } from './s1c_bot';
import type { BotOptions } from './s1c_bot';
import { CL } from '../src/game';

const n = Number(process.argv[2] ?? 500);
const out = process.argv[3];
const BASE: BotOptions = { s1c: true, policy: 'caretaker', dom: 'engaged', disasters: true, deathWeight: true };
const DEATH_CARDS = ['orphan', 'keepsake', 'loss_rep', 'loss_child', 'loss_hand', 'chain_push', 'chain_fix', 'heat_after'];

interface Row { end: string; deaths: number; deathCards: number; trustCrisis: boolean; coalZero: boolean; freezes: number; leverAfterDrop: number }

function run(climate: boolean, mult?: number[]): Row[] {
  const keep = [...CL.mult];
  if (mult) CL.mult.splice(0, CL.mult.length, ...mult);
  const rows: Row[] = [];
  for (let i = 0; i < n; i += 1) {
    let crisis = false;
    const { g, m } = playGame(`dw-${i}`, { ...BASE, ...(climate ? { climate: true } : {}), probe: { onSettle: x => { if (x.trustCrisis !== null) crisis = true; } } });
    rows.push({
      end: g.end ?? 'none', deaths: g.deaths.length, deathCards: DEATH_CARDS.reduce((s, k) => s + (m.cards[k] ?? 0), 0), trustCrisis: crisis,
      coalZero: m.climate.coalZero > 0, freezes: m.climate.freezes, leverAfterDrop: m.climate.leverAfterDrop,
    });
  }
  CL.mult.splice(0, CL.mult.length, ...keep);
  return rows;
}

const pct = (k: number, of: number) => (of ? (100 * k) / of : 0);
function summary(rows: Row[]) {
  const mean = (f: (r: Row) => number) => rows.reduce((s, r) => s + f(r), 0) / rows.length;
  return {
    games: rows.length, complete: pct(rows.filter(x => x.end === 'complete').length, rows.length), revolt: pct(rows.filter(x => x.end === 'revolt').length, rows.length),
    deathsMean: mean(r => r.deaths), deathCardsMean: mean(r => r.deathCards), deathCardsMax: Math.max(...rows.map(r => r.deathCards)),
    trustCrisis: pct(rows.filter(r => r.trustCrisis).length, rows.length), coalZero: pct(rows.filter(r => r.coalZero).length, rows.length),
    freezesMean: mean(r => r.freezes), leverAfterDropMean: mean(r => r.leverAfterDrop),
  };
}

const t0 = Date.now();
const off = summary(run(false));
const on = summary(run(true));
// 견줌: 처음 넣었던 중안 곱(사용자가 약안으로 바꾸기 전)
const mid = summary(run(true, [0.85, 1, 1.2, 1.45, 1.75]));
const res = { n, bot: BASE, mult: CL.mult, off, on, mid, secs: (Date.now() - t0) / 1000 };
console.log(JSON.stringify(res, null, 2));
if (out) writeFileSync(out, JSON.stringify(res, null, 2));
