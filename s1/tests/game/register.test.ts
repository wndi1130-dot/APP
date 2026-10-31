import { readFileSync, readdirSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import type { Card, CardView } from '../../src/game';
import { playGame } from '../../tools/s1c_bot';

// 말씨 가름. 열차장 말은 해라체이고, 대체 불가한 장인 앞에서만 하오체다.
// 맡은 일로 열차장에게 보고하는 사람(기관사·수색대·배급장·의무장·측근·부관)은 합쇼체, 앞칸 대표의 「~시지요」도 그 높임으로 본다.
// 칸 사람·칸 대표는 해라체, 구조 카드의 바깥 사람은 높여 말한다.

type Ending = '합쇼' | '해요' | '하오' | '해라' | '조각';

/** 말 끝 말씨. 따옴표·말줄임을 걷고 마지막 문장의 끝말로 가른다. */
function ending(text: string): Ending {
  const t = text.replace(/\$\{[^}]*\}/g, 'X').trim().replace(/["'」』)\]…]+$/u, '').trim();
  const last = (t.split(/(?<=[.!?])\s+/).pop() ?? '').replace(/[.!?…~]+$/u, '').trim();
  if (/아니다$|다오$/u.test(last)) return '해라';
  if (/(습니다|십시오|니다|니까|십시다)$/u.test(last)) return '합쇼';
  if (/(세요|어요|아요|해요|예요|에요|지요|죠|요)$/u.test(last)) return '해요';
  if (/(하오|이오|소|구려|시오)$/u.test(last)) return '하오';
  if (/(다|라|자|냐|니|지|게|군|네|마|야|어|아|래|대|걸|거든|고|까|해)$/u.test(last)) return '해라';
  return '조각';
}

/** 열차장이 하오체로 말하는 카드(대체 불가한 장인) */
const HAO_OK = new Set(['dom:manual', 'dom:demand']);

type Voice = '보고' | '칸' | '앞칸 대표' | '옮김';
const ALLOWED: Record<Voice, Ending[]> = {
  보고: ['합쇼', '조각'], 칸: ['해라', '조각'], '앞칸 대표': ['합쇼', '해요'], 옮김: ['합쇼', '해요', '하오', '해라', '조각'],
};

/** 사건 글(본문·고른 뒤 글)의 따옴표 말마다 누가 하는 말인지. 새 따옴표 말을 쓰면 여기에 적는다. */
const EVENT_VOICES: [file: string, field: string, quote: string, voice: Voice][] = [
  ['ev_b01_doubtful_bridge', 'c_engine_brace.why', '우리 일은 불이다. 압력계가 떨어진다.', '칸'],
  ['ev_b01_fallen_tree', 'c_front_work.why', '하겠다', '칸'],
  ['ev_b01_frost_bird', 'c_front_space.why', '괜찮다', '칸'],
  ['ev_b01_frozen_switch', 'c_guard_clear.why', '얼음 걷기는 순찰이 아니다.', '칸'],
  ['ev_b01_mended_harmonica', 'c_front_cloth.why', '가져가라', '칸'],
  ['ev_b01_strap_break', 'c_front_hold.why', '언제까지 둘 거지', '칸'],
  ['ev_b01_two_wagons', 'c_guard_push.why', '미는 건 기관차가 한다.', '칸'],
  ['ev_b01_wobbly_cart', 'c_engine_carry.why', '손수레 일은 우리 몫이 아니다.', '칸'],
  ['ev_h01_low_fire', 'body', '이 삽질로는 다음 탑까지 불이 안 갑니다. 어디서든 덜어야 합니다.', '보고'],
  ['ev_h02_burst_crates', 'body', '끓이면 먹을 수는 있습니다, 탈이 날지는 모릅니다.', '보고'],
  ['ev_h02_sour_pot', 'body', '약을 안 풀면 죽을 따로 끓이고 오래 눕혀야 합니다. 풀지 말지 정해 주십시오.', '보고'],
  ['ev_h02_sour_pot', 'c_rest_only.why', '조건은 말씀드렸습니다.', '보고'],
  ['ev_h03_roof_ice', 'body', '앞의 낮은 다리는 세우고 얼음을 깨야 지납니다. 누가 올라갑니까.', '보고'],
  ['ev_h03_roof_ice', 'c_guard_up.why', '지난번도 우리였다.', '칸'],
  ['ev_h03_roof_ice', 'c_geared_up.why', '갖춘 건 안다', '칸'],
  ['ev_h04_one_box', 'body', '폐에 물이 찬 화부 하나, 지붕에서 떨어진 대원 하나. 둘 다 살리려면 이 상자가 다 듭니다.', '보고'],
  ['ev_h05_short_shift', 'body', '화부 넷이 손을 못 씁니다. 사람을 주든 석탄을 더 주든 하십시오, 아니면 불이 느려집니다.', '보고'],
  ['ev_h05_slow_fire', 'body', '말씀드렸습니다. 손이 이만큼이면 눈금도 이만큼입니다.', '보고'],
  ['ev_h06_frozen_pipe', 'body', '그때 고쳤으면 이음 하나였습니다, 지금은 마디 하나입니다.', '보고'],
  ['ev_h06_frozen_pipe', 'c_back_stove.why', '그 석탄은 모두의 것이다', '칸'],
  ['ev_h06_split_pipe', 'body', '세우면 반나절, 달리면서 고치면 손이 얼고, 두면 뒤가 업니다.', '보고'],
  ['ev_h07_broken_word', 'body', '겨울 솥은 건드리지 않겠다고 하셨습니다. 뒤에 선 사람들이 그 말을 기억합니다.', '앞칸 대표'],
  ['ev_h07_kept_word', 'body', '겨울 솥은 그대로였습니다. 말씀대로였습니다.', '앞칸 대표'],
  ['ev_h07_quiet_offer', 'body', '다음 회기 표는 드립니다, 안건을 좋아해서가 아닙니다. 이번 겨울 앞칸 솥만 건드리지 말아 주십시오.', '앞칸 대표'],
  ['ev_h08_white_wind', 'body', '한 시간 안에 앞이 안 보입니다. 밀고 가면 석탄을 먹고, 숲 그늘에 서면 솥이 빕니다.', '보고'],
  ['ev_h09_dropped_food', 'body', '내려 둔 식량 자루가 선로 옆에 그대로 있다.', '칸'],
  ['ev_h09_too_heavy', 'body', '이 무게로는 못 넘습니다. 뭐든 내려놓으셔야 합니다.', '보고'],
  ['ev_h10_aide_night', 'body', '한 번 다시 잰 것 말고는 없습니다.', '보고'],
  ['ev_h10_aide_night', 'c_this_once.why', '조건을 말씀드렸는데', '보고'],
  ['ev_h10_second_night', 'body', '두 밤째인 저분 손을 제가 봤습니다', '보고'],
  ['ev_h10_second_night', 'body', '맡기려면 교대로 세워 주십시오', '보고'],
  ['ev_h10_second_night', 'c_keep_watching.why', '저분 손을 봤습니다', '보고'],
  ['ev_h10_wrong_dose', 'body', '제가 쟀습니다. 다시 재게 해 주십시오.', '보고'],
  ['ev_h10_wrong_dose', 'c_watch_it.why', '다시 재게 해 달라', '옮김'],
  ['ev_h11_bridge_sag', 'body', '이제는 받침을 새로 대야 건넙니다.', '보고'],
  ['ev_h12_switch_stuck', 'body', '이제는 날을 갈아 끼워야 움직입니다.', '보고'],
  ['ev_h12_switch_stuck', 'c_guard_clear2.why', '지난번엔 얼음이었고, 이번엔 쇠다.', '칸'],
  ['ev_h13_wet_leaves', 'body', '모래통이 반입니다, 뿌리며 오르거나 내려서 쓸어야 합니다.', '보고'],
  ['ev_h14_swollen_creek', 'body', '무릎 깊이에 물살이 빠릅니다.', '보고'],
  ['ev_h16_leaking_roof', 'body', '우리 칸만 매번 이렇다.', '칸'],
  ['ev_h18_hot_axle', 'body', '흙탕물이 기름에 섞였습니다.', '보고'],
];

describe('말씨 가름', () => {
  it('말 끝을 가른다', () => {
    expect(ending('…신임은 말로 되찾는 게 아니다.')).toBe('해라');
    expect(ending('석탄을 아껴야 한다. 며칠만 버텨 다오.')).toBe('해라');
    expect(ending('해열제는 상자에 있습니다. 꺼낼지 정해 주십시오.')).toBe('합쇼');
    expect(ending('온기가 이래서는 손님을 못 받습니다. 조금만 올려 주시지요.')).toBe('해요');
    expect(ending('당신이 죽어도 열차는 달려야 하오.')).toBe('하오');
    expect(ending('열쇠는 경비대장 하나만 쥔다. 오늘부터.')).toBe('조각');
  });

  it('열차장 말은 해라체다(대체 불가한 장인 앞에서만 하오체)', { timeout: 120_000 }, () => {
    const bad: string[] = [];
    const seen = new Set<string>();
    const runs = [
      { s1c: true, s1b: 'kind', policy: 'caretaker', dom: 'engaged', disasters: true, deathWeight: true, climate: true, eventPack: true, arrivals: true, pickRule: 'random' },
      { s1c: true, s1b: 'cruel', policy: 'first', dom: 'engaged', disasters: true, deathWeight: true, eventPack: true, pickRule: 'random', late: true },
      { s1c: false, policy: 'caretaker', dom: 'idle' },
    ] as const;
    for (const [i, base] of runs.entries()) {
      for (const seed of [`reg-${i}-a`, `reg-${i}-b`]) {
        playGame(seed, {
          ...base,
          probe: {
            beforePick: (_g: unknown, card: Card, view: CardView) => {
              for (const ch of view.choices) {
                const say = ch.say?.trim();
                if (!say || /^\(.*\)$/.test(say) || seen.has(say)) continue;
                seen.add(say);
                const e = ending(say);
                if (e !== '해라' && e !== '조각' && !(e === '하오' && HAO_OK.has(card.kind))) bad.push(`${card.kind} ${e}: ${say}`);
              }
            },
          },
        });
      }
    }
    expect(seen.size).toBeGreaterThan(200);
    expect(bad).toEqual([]);
  });

  it('사건 글의 따옴표 말은 누가 하는 말인지에 맞는 말씨다', () => {
    const dir = new URL('../../data/events/', import.meta.url);
    const found: string[] = [];
    const bad: string[] = [];
    const table = new Map(EVENT_VOICES.map(([f, field, q, v]) => [`${f}#${field}#${q}`, v]));
    for (const file of readdirSync(dir).filter(f => f.endsWith('.json'))) {
      const ev = JSON.parse(readFileSync(new URL(file, dir), 'utf8')) as { body: string; choices: { id: string; why?: string; later?: string }[] };
      const id = file.replace(/\.json$/, '');
      const texts: [string, string][] = [['body', ev.body], ...ev.choices.flatMap(c => [[`${c.id}.why`, c.why ?? ''], [`${c.id}.later`, c.later ?? '']] as [string, string][])];
      for (const [field, text] of texts) {
        for (const m of text.matchAll(/"([^"]{2,})"/g)) {
          const key = `${id}#${field}#${m[1]}`;
          found.push(key);
          const v = table.get(key);
          if (!v) bad.push(`표에 없음 ${key}`);
          else if (!ALLOWED[v].includes(ending(m[1]))) bad.push(`${v}인데 ${ending(m[1])}: ${key}`);
        }
      }
    }
    expect(bad).toEqual([]);
    expect(found.length).toBe(EVENT_VOICES.length);
  });
});
