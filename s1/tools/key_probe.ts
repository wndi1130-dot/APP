// 열쇠(ev_achieved)와 위로 카드를 재는 도구(인간찬가 대조 10.1). 봇 종류별(첫 칸·둘째 칸·아무거나)로 판당 열쇠가 선 횟수·어디서 섰나·위로 카드 장수와 구간·완주를 낸다.
// 사용: npx tsx tools/key_probe.ts [판 수=500] [결과 JSON 경로]   (사건 폴더를 바꾸려면 환경변수 S1_EVENTS_DIR)
// 열쇠가 이미 선 채로 또 서는 것은 한 번으로 센다(표식 하나라서 위로 한 장만 온다).

import { writeFileSync } from 'node:fs';
import { playGame } from './s1c_bot';
import type { BotOptions } from './s1c_bot';

const N = Number(process.argv[2] ?? 500);
const OUT = process.argv[3];
const COMFORT = new Set(['ev_b01_frost_bird', 'ev_b01_mended_harmonica', 'ev_b01_paper_puppet', 'ev_b01_uneven_mittens', 'ev_b01_warm_potatoes']);
const mean = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0);

const BOTS: [string, Partial<BotOptions>][] = [['첫 칸', {}], ['둘째 칸', { pickRule: 'second' }], ['아무거나', { pickRule: 'random' }]];
const result: Record<string, unknown> = {};

for (const [name, extra] of BOTS) {
  const keys: number[] = [];
  const comfort: number[] = [];
  const comfortSegs: number[] = [];
  const sources: Record<string, number> = {};
  const ends: Record<string, number> = {};
  const tensionEnd: number[] = [];
  const segReached: number[] = [];
  const contentCards: number[] = [];
  const newCards: Record<string, number> = {};
  for (let i = 0; i < N; i += 1) {
    let k = 0, c = 0;
    let pending = '';
    let was = false;
    const opts: BotOptions = {
      s1c: true, policy: 'caretaker', dom: 'engaged', eventPack: true, ...extra,
      probe: {
        beforePick: (g, card, view, idx) => {
          if (card.text && COMFORT.has(card.text)) { c += 1; comfortSegs.push(g.seg); }
          pending = `${card.text ?? ""}/${view.choices[idx]?.id ?? idx}`;
          was = !!g.contentFlags?.ev_achieved;
        },
        afterPick: g => {
          const now = !!g.contentFlags?.ev_achieved;
          if (now && !was) { k += 1; sources[pending] = (sources[pending] ?? 0) + 1; }
        },
      },
    };
    const { g, m } = playGame(`sim-${i}`, opts);
    keys.push(k); comfort.push(c);
    ends[m.end] = (ends[m.end] ?? 0) + 1;
    tensionEnd.push(m.tensionEnd); segReached.push(m.segReached);
    let cc = 0;
    for (const [id, memo] of Object.entries(g.eventLog)) {
      if (!id.startsWith('content:')) continue;
      cc += memo.n;
      const short = id.slice(8);
      if (['ev_h10_aide_night', 'ev_h10_wrong_dose', 'ev_h07_broken_word', 'ev_h07_kept_word', 'ev_h07_quiet_offer'].includes(short)) newCards[short] = (newCards[short] ?? 0) + memo.n;
    }
    contentCards.push(cc);
  }
  const dist = [0, 1, 2, 3].map(n => +(comfort.filter(x => (n === 3 ? x >= 3 : x === n)).length / N).toFixed(3));
  const top = Object.entries(sources).sort((a, b) => b[1] - a[1]).slice(0, 12).map(([k2, v]) => `${k2} ${(v / N).toFixed(2)}`);
  const row = {
    games: N,
    keysPerGame: +mean(keys).toFixed(2), comfortPerGame: +mean(comfort).toFixed(2), comfortDist_0_1_2_3plus: dist,
    comfortSegMean: +mean(comfortSegs).toFixed(1), comfortSegMin: Math.min(...comfortSegs, 99), comfortSegMax: Math.max(...comfortSegs, 0),
    complete: +((ends.complete ?? 0) / N).toFixed(3), ends: Object.fromEntries(Object.entries(ends).map(([k2, v]) => [k2, +(v / N).toFixed(3)])),
    tensionEnd: +mean(tensionEnd).toFixed(1), segReached: +mean(segReached).toFixed(1), contentCardsPerGame: +mean(contentCards).toFixed(2),
    newCardsPerGame: Object.fromEntries(Object.entries(newCards).map(([k2, v]) => [k2, +(v / N).toFixed(3)])),
    topKeySources: top,
  };
  result[name] = row;
  console.log(`[${name}] 열쇠 ${row.keysPerGame}/판 · 위로 ${row.comfortPerGame}장/판 (0/1/2/3+장 판 비율 ${dist.join('/')}) · 위로 구간 평균 ${row.comfortSegMean} (${row.comfortSegMin}~${row.comfortSegMax}) · 완주 ${(100 * row.complete).toFixed(1)}% 끝긴장 ${row.tensionEnd} · 콘텐츠카드 ${row.contentCardsPerGame}/판`);
  console.log(`   새·바뀐 카드(판당) ${JSON.stringify(row.newCardsPerGame)}`);
  console.log(`   열쇠가 서는 곳(판당) ${top.join(' | ')}`);
}
if (OUT) writeFileSync(OUT, JSON.stringify({ n: N, bots: result }, null, 2));
