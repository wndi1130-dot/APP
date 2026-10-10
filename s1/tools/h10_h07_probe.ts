// 인간찬가 대조 10.9의 측정 셋: (1) 의무장의 둘째 밤이 뜬 순간의 의무칸 과밀·부상자·의약품 분포 (2) 조용한 제안이 뜨는/받는/앞칸 솥을 건드리는 비율 (3) 판이 끝나는 구간 분포.
// 사용: npx tsx tools/h10_h07_probe.ts [판 수=1000] [결과 JSON 경로] [봇=first|second|random]
import { writeFileSync } from 'node:fs';
import { situation } from '../src/game';
import { playGame } from './s1c_bot';
import type { BotOptions } from './s1c_bot';

const N = Number(process.argv[2] ?? 1000);
const OUT = process.argv[3];
const BOT = process.argv[4] ?? 'first';
const extra: Partial<BotOptions> = BOT === 'first' ? {} : { pickRule: BOT as 'second' | 'random' };
// view.choices에는 id가 없어 칸 번호로 센다: 앞칸 솥·몫·살림을 건드리는 칸 = low_fire 셋째(가구), burst_crates 셋째(앞칸 비축), too_heavy 첫째(살림 상자), warm_potatoes 둘째(앞칸 몫)
const TOUCH = new Set(['ev_h01_low_fire/2', 'ev_h02_burst_crates/2', 'ev_h09_too_heavy/0', 'ev_b01_warm_potatoes/1']);

interface Night { crowd: number; med: number; injured: number; seg: number; pick: string }
const nights: Night[] = [];
let quietShown = 0, quietAccept = 0, acceptThenTouch = 0, anyTouch = 0, brokenShown = 0, keptShown = 0, promiseGames = 0;
const touchSeen: Record<string, number> = {};
const endSegs: number[] = [];
const ends: Record<string, number> = {};
const quietSeg: number[] = [];

for (let i = 0; i < N; i += 1) {
  let accepted = false, touched = false, acceptThenTouchHere = false, quiet = false;
  const opts: BotOptions = {
    s1c: true, policy: 'caretaker', dom: 'engaged', eventPack: true, ...extra,
    probe: {
      beforePick: (g, card, view, idx) => {
        const id = card.text ?? '';
        void view; const pick = String(idx);
        if (id === 'ev_h10_second_night') nights.push({ crowd: situation(g, 'medtech')[2], med: g.med, injured: g.injured, seg: g.seg, pick });
        if (id === 'ev_h07_quiet_offer') { quiet = true; quietSeg.push(g.seg); if (pick === '0') accepted = true; }
        if (TOUCH.has(`${id}/${pick}`)) {
          touched = true; touchSeen[`${id}/${pick}`] = (touchSeen[`${id}/${pick}`] ?? 0) + 1;
          if (accepted) acceptThenTouchHere = true;
        }
        if (id === 'ev_h07_broken_word') brokenShown += 1;
        if (id === 'ev_h07_kept_word') keptShown += 1;
      },
    },
  };
  const { m } = playGame(`sim-${i}`, opts);
  if (quiet) quietShown += 1;
  if (accepted) { quietAccept += 1; promiseGames += 1; }
  if (acceptThenTouchHere) acceptThenTouch += 1;
  if (touched) anyTouch += 1;
  endSegs.push(m.segReached);
  ends[m.end] = (ends[m.end] ?? 0) + 1;
}

const q = (xs: number[], p: number) => { const s = [...xs].sort((a, b) => a - b); return s.length ? s[Math.min(s.length - 1, Math.floor(p * s.length))] : NaN; };
const hist = (xs: number[], step: number) => { const h: Record<string, number> = {}; for (const x of xs) { const k = `${Math.floor(x / step) * step}`; h[k] = (h[k] ?? 0) + 1; } return Object.fromEntries(Object.entries(h).sort((a, b) => Number(a[0]) - Number(b[0]))); };
const mean = (xs: number[]) => (xs.length ? +(xs.reduce((a, b) => a + b, 0) / xs.length).toFixed(2) : NaN);
const aide = nights.filter(n => n.pick === '1');
const stat = (ns: Night[]) => ({
  n: ns.length,
  crowdHist10: hist(ns.map(n => n.crowd), 10), crowdMean: mean(ns.map(n => n.crowd)),
  crowdPct: Object.fromEntries([0.1, 0.33, 0.5, 0.67, 0.9].map(p => [`p${Math.round(p * 100)}`, q(ns.map(n => n.crowd), p)])),
  injuredHist: hist(ns.map(n => n.injured), 1), injuredMean: mean(ns.map(n => n.injured)),
  medHist5: hist(ns.map(n => n.med), 5), medPct: Object.fromEntries([0.33, 0.5, 0.67].map(p => [`p${Math.round(p * 100)}`, q(ns.map(n => n.med), p)])),
  segMean: mean(ns.map(n => n.seg)),
});
const gt = (k: number) => +(endSegs.filter(s => s > k).length / N).toFixed(3);
const out = {
  bot: BOT, games: N,
  secondNight: { shownRate: +(nights.length / N).toFixed(3), presentedAll: stat(nights), choseAide: stat(aide), picks: nights.reduce<Record<string, number>>((a, n) => { a[n.pick] = (a[n.pick] ?? 0) + 1; return a; }, {}) },
  quiet: { shownRate: +(quietShown / N).toFixed(3), acceptRate: +(quietAccept / N).toFixed(3), acceptOfShown: +(quietAccept / Math.max(1, quietShown)).toFixed(3), shownSegMean: mean(quietSeg), acceptThenTouchRate: +(acceptThenTouch / N).toFixed(3), anyTouchRate: +(anyTouch / N).toFixed(3), touchPicksPerGame: Object.fromEntries(Object.entries(touchSeen).map(([k, v]) => [k, +(v / N).toFixed(3)])), brokenPerGame: +(brokenShown / N).toFixed(4), keptPerGame: +(keptShown / N).toFixed(4) },
  end: { ends: Object.fromEntries(Object.entries(ends).map(([k, v]) => [k, +(v / N).toFixed(3)])), segHist2: hist(endSegs, 2), segMean: mean(endSegs), over14: gt(14), over20: gt(20), over10: gt(10), reach24: +(endSegs.filter(s => s >= 24).length / N).toFixed(3) },
};
console.log(JSON.stringify(out, null, 1));
if (OUT) writeFileSync(OUT, JSON.stringify(out, null, 2));
