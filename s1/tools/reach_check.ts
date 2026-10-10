// 닿음 검사(r8 출시 실무): 자동 플레이를 여러 정책으로 돌려 한 번도 안 나온 사건·카드와 끊어진 후속을 찾는다.
// 사용: npx tsx tools/reach_check.ts [판 수=300]. 봇이 안 하는 행동이 있어야 나오는 카드는 REACH_NOTES에 까닭을 적는다.
// 까닭 없이 안 나온 것이 있으면 종료 코드 1. 끊어진 후속(그리는 곳 없는 카드, 고를 수 없는 카드)은 봇이 바로 멈춘다.

import { CONTENT_EVENTS, DOM_CARD_KINDS, HUB_CARD_KINDS, PEOPLE_KINDS, PROLOGUE_CARD_KINDS, S1A_CARD_KINDS, TRAVEL_EVENTS } from '../src/game';
import { playGame } from './s1c_bot';
import type { BotOptions } from './s1c_bot';

/** 자동 플레이로는 안 나오는 카드와 그 까닭. 봇이 쓰게 되거나 규칙이 들어오면 지운다. */
export const REACH_NOTES: Record<string, string> = {
  'dom:officer': '의도된 미도달. 열차장 침상은 필드 중상·폐렴 때만이고 S3부터 생긴다(내정 스레드 c491d50). 코드엔 훅(overreachTick)만 둔다',
  leash: '협박 거래 뒤에 온다. 봇은 협박을 안 쓴다',
  'dom:give': '기술 m4 복원 뒤에 온다. 봇은 m4를 거의 안 고른다',
  'dom:demand': '분야에 아는 사람이 하나뿐이고 그 분야 기술이 서 있어야 온다. 내정 봇은 견습생을 일찍 붙인다',
  'dom:box': '기관 매뉴얼이 있고 기관실이 반대(−40) 아래일 때 온다',
  'dom:stoker': '대체 기관사가 있는데 기관실이 파업할 때 온다',
  'dom:pressure': '기관 숙련자가 견습 수준만 남았을 때 온다',
  strike_warn: '기관실이 크게 틀어져야 온다. 봇 판에선 드물다',
  strike: '파업 경고 뒤에 온다. 봇 판에선 드물다',
  hub_few: '라이프치히에 모든 칸이 중립 이상으로 닿아야 온다. 봇 판에선 드물다',
  rep_sick: '온기나 배급이 38 아래로 두 구간 머문 칸에 온다. 서막 첫 거래에서 봇이 늘 꼬리칸 난방을 올려서 봇 판엔 그런 칸이 거의 없다(서막 없는 판에선 나온다)',
  // 새 이동 사건 묶음(ev_b01_, 켠 판에서만). 손으로 조건을 맞추면 모두 뽑힌다. 봇이 그 길을 안 가서 안 나온다(시뮬 4,000판×5정책에서도 0번)
  'content:ev_b01_handle_break': '앞 사건 cracked_handle에서 미루는 선택(c_defer)을 해야 온다. 봇은 그 선택을 안 한다',
  'content:ev_b01_scattered_grain': '앞 사건 sack_seam에서 미루는 선택(c_defer)을 해야 온다. 봇은 그 선택을 안 한다',
  'content:ev_b01_strap_break': '앞 사건 frayed_strap에서 미루는 선택(c_defer)을 해야 온다. 봇은 그 선택을 안 한다',
  'content:ev_b01_full_infirmary': '기술·의무진 과밀이 70 이상이어야 온다. 봇 판에선 거의 없다',
  'content:ev_b01_stoker_burn': '기관실 과밀이 60 이상이어야 온다. 봇 판에선 거의 없다',
  'content:ev_b01_window_ice': '앞칸 온기가 42 이하여야 온다. 봇 판에선 거의 없다',
  'content:ev_b01_wobbly_cart': '앞칸 과밀이 55 이상이어야 온다. 봇 판에선 거의 없다',
  'content:ev_h02_sour_pot': '앞 사건 ev_h02_burst_crates에서 끓여 섞는 선택을 해야 온다. 봇은 첫 칸(다 버린다)만 고른다',
  'content:ev_h04_one_box': '의약품이 3~10일 때만 온다. 봇 판에선 거의 없다',
  'content:ev_h05_slow_fire': '앞 사건 ev_h05_short_shift에서 버티라 하는 선택을 해야 온다. 봇은 그 선택을 안 한다',
  'content:ev_h06_frozen_pipe': '앞 사건 ev_h06_split_pipe에서 다음 정차까지 두는 선택을 해야 온다. 봇은 그 선택을 안 한다',
  'content:ev_h10_wrong_dose': '앞 사건 ev_h10_second_night에서 조수가 대신 보는 선택을 해야 온다. 봇은 그 선택을 안 한다',
  'content:ev_h11_bridge_sag': '앞 사건 ev_b01_doubtful_bridge에서 그대로 지나는 선택을 해야 온다. 봇은 그 선택을 안 한다',
  'content:ev_h12_switch_stuck': '앞 사건 ev_b01_frozen_switch에서 그대로 지나는 선택을 해야 온다. 봇은 그 선택을 안 한다',
};

export const CONFIGS: [string, BotOptions][] = [
  ['S1a 돌봄', { s1c: false, policy: 'caretaker', dom: 'idle' }],
  ['S1a 첫 선택지', { s1c: false, policy: 'first', dom: 'idle' }],
  ['S1c 돌봄', { s1c: true, policy: 'caretaker', dom: 'engaged' }],
  ['S1c 첫 선택지', { s1c: true, policy: 'first', dom: 'idle' }],
  // 새 이동 사건 묶음(ev_b01_, event_pack.ts)은 기본 꺼짐이라 켠 판을 따로 돌려야 닿는다
  ['S1c 돌봄 묶음 켬', { s1c: true, policy: 'caretaker', dom: 'engaged', eventPack: true }],
];

export interface ReachReport { games: number; seen: Record<string, number>; unreached: string[]; unexpected: string[]; noted: string[]; notes: Record<string, string> }

export function reachReport(n: number): ReachReport {
  const seen: Record<string, number> = {};
  for (const [, opts] of CONFIGS) {
    for (let i = 0; i < n; i += 1) {
      const { g, m } = playGame(`reach-${i}`, opts);
      for (const [k, v] of Object.entries(m.cards)) if (k !== 'travel') seen[k] = (seen[k] ?? 0) + v;
      for (const id of Object.keys(g.eventLog ?? {})) {
        if (TRAVEL_EVENTS.some(e => e.id === id)) seen[`travel:${id}`] = (seen[`travel:${id}`] ?? 0) + 1;
        if (id.startsWith('content:')) seen[id] = (seen[id] ?? 0) + 1;
      }
    }
  }
  const all = [
    ...TRAVEL_EVENTS.map(e => `travel:${e.id}`), ...S1A_CARD_KINDS.filter(k => k !== 'travel'), ...PEOPLE_KINDS, ...DOM_CARD_KINDS, ...HUB_CARD_KINDS, ...PROLOGUE_CARD_KINDS,
    ...CONTENT_EVENTS.map(e => `content:${e.id}`),
  ];
  // 콘텐츠 사건 중 게임이 아직 안 뽑는 단계(s1b, 이동 밖 단계)는 까닭을 붙인다. 후속으로만 오는 사건은 단계를 안 본다.
  const notes: Record<string, string> = { ...REACH_NOTES };
  const followed = new Set(CONTENT_EVENTS.flatMap(e => e.choices.flatMap(ch => [...ch.followups, ...ch.effects.flatMap(x => (x.type === 'followup' ? [x.id] : []))])));
  for (const e of CONTENT_EVENTS) {
    if (followed.has(e.id)) continue;
    if (e.stage === 's1b') notes[`content:${e.id}`] ??= 'S1b 사건은 아직 안 뽑는다';
    else if (e.phase !== 'travel') notes[`content:${e.id}`] ??= `${e.phase} 단계 콘텐츠 사건은 아직 안 뽑는다(content.ts)`;
  }
  const unreached = all.filter(k => !seen[k]);
  return {
    games: n * CONFIGS.length, seen, unreached,
    unexpected: unreached.filter(k => !notes[k]),
    noted: unreached.filter(k => notes[k]),
    notes,
  };
}

if (process.argv[1]?.endsWith('reach_check.ts')) {
  const n = Number(process.argv[2] ?? 300);
  const t0 = Date.now();
  const r = reachReport(n);
  console.log(`${r.games}판 (${((Date.now() - t0) / 1000).toFixed(1)}초). 끊어진 후속 없음.`);
  for (const k of r.noted) console.log(`  안 나옴(까닭 있음) ${k}: ${r.notes[k]}`);
  for (const k of r.unexpected) console.log(`  안 나옴(까닭 없음) ${k}`);
  const rare = Object.entries(r.seen).filter(([, v]) => v < 5).map(([k, v]) => `${k} ${v}`);
  if (rare.length) console.log(`  드묾(5번 미만): ${rare.join(', ')}`);
  if (r.unexpected.length) process.exit(1);
}
