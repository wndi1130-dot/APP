// 표결 전 수단 셋 재기(결정 433): 「늘 협박」이 기준(공개 협상)보다 쉬운 길이 되지 않는지, 설득이 어떤 자리에 서는지 본다.
// 사용: npx tsx tools/deal_sim.ts [판 수=1000] [--push=법id] [--only=정책 이름 일부]
//   돌봄 봇이 표가 모자랄 때 칸마다 정책의 차례로 쓸 수 있는 첫 수단을 쓴다(s1c_bot dealTools). --push를 주면 그 법이 오를 때마다 고른다.
// 판은 서막을 거치는 S1a 돌봄 판(내정 꺼짐)이다. 숫자는 판마다 평균이고 완주는 비율이다.
import type { DealTool, EndKind, LawId } from '../src/game';
import { COMMS } from '../src/game';
import { playGame } from './s1c_bot';
import type { BotOptions, GameMetrics } from './s1c_bot';

const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
const flags = process.argv.slice(2).filter(a => a.startsWith('--'));
const N = Number(args[0] ?? 1000);
const push = flags.find(x => x.startsWith('--push='))?.slice(7) as LawId | undefined;
const only = flags.find(x => x.startsWith('--only='))?.slice(7);

// [이름, 수단 차례, 설득을 쓰는 「될 듯」 확률 하한]
const POLICIES: [string, DealTool[], number?][] = [
  ['공개 협상(기준)', ['open']],
  ['늘 협박', ['blackmail', 'open']],
  ['늘 설득', ['persuade', 'open']],
  ['설득은 될 듯 60% 넘을 때', ['persuade', 'open'], 0.6],
  ['늘 뇌물', ['bribe', 'open']],
];
// 설득이 안 먹힌 칸은 그 회기 다른 거래가 막히므로 「설득 먼저, 협박 마지막」은 「늘 설득」과 같은 판이 된다. 따로 두지 않는다.
const ENDS: EndKind[] = ['complete', 'stranded', 'revolt', 'ousted', 'coup', 'lost_captain'];
const END_WORD: Record<string, string> = { complete: '완주', stranded: '석탄', revolt: '반란', ousted: '축출', coup: '쿠데타', lost_captain: '실종' };

const mean = (xs: number[]) => xs.reduce((s, x) => s + x, 0) / Math.max(1, xs.length);
const pc = (x: number) => `${(100 * x).toFixed(1)}%`;
const t0 = Date.now();
for (const [name, tools, persuadeAt] of POLICIES.filter(([n]) => !only || n.includes(only))) {
  const ms: GameMetrics[] = [];
  const gs: { trust: number; tension: number; hostile: number; blackmails: number; persuadeTry: number; persuadeOk: number; pushed: boolean }[] = [];
  for (let i = 0; i < N; i += 1) {
    let tries = 0; let oks = 0;
    const opts: BotOptions = { s1c: false, policy: 'caretaker', dom: 'idle', dealTools: tools, persuadeAt, ...(push ? { pushLaw: push } : {}) };
    const { g, m } = playGame(`deal-${i}`, opts);
    // 설득의 결과는 일지 줄로 센다(makeDeal이 남기는 두 꼴)
    for (const e of g.journal) {
      if (e.text.includes('설득했지만')) tries += 1;
      else if (e.text.includes('설득했다.')) { tries += 1; oks += 1; }
    }
    ms.push(m);
    gs.push({
      trust: g.trust, tension: m.tensionMax, hostile: COMMS.filter(c => g.comms[c].grudge >= 2).length,
      blackmails: g.stats.blackmails, persuadeTry: tries, persuadeOk: oks, pushed: !!push && g.passed[push] !== undefined,
    });
  }
  const done = ms.filter(m => m.end === 'complete').length / N;
  const tried = gs.reduce((s, x) => s + x.persuadeTry, 0);
  console.log(`${name.padEnd(16)} 완주 ${pc(done)} · 법 ${mean(ms.map(m => m.lawsPassed)).toFixed(2)} · 가혹법 ${mean(ms.map(m => m.harshPassed)).toFixed(2)}${push ? ` · ${push} 섬 ${pc(gs.filter(x => x.pushed).length / N)}` : ''} · 끝 신임 ${mean(gs.map(x => x.trust)).toFixed(1)} · 긴장 최고 ${mean(gs.map(x => x.tension)).toFixed(1)} · 적대 칸 ${mean(gs.map(x => x.hostile)).toFixed(2)} · 협박 ${mean(gs.map(x => x.blackmails)).toFixed(2)} · 설득 ${mean(gs.map(x => x.persuadeTry)).toFixed(2)}번(먹힘 ${tried ? pc(gs.reduce((s, x) => s + x.persuadeOk, 0) / tried) : '-'})`);
  // 못 끝낸 판이 어떻게 끝났는지: 협박의 대가가 다른 끝(반란·축출·쿠데타)으로 치러지는지 본다
  console.log(`${''.padEnd(18)}끝: ${ENDS.map(e => `${END_WORD[e]} ${pc(ms.filter(m => m.end === e).length / N)}`).join(' · ')}`);
}
console.log(`(${N}판씩, ${((Date.now() - t0) / 1000).toFixed(1)}초)`);
