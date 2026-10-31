import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import type { Card, CardView } from '../../src/game';
import { playGame } from '../../tools/s1c_bot';

// 말씨 가름. 열차장 말은 해라체이고, 대체 불가한 장인 앞에서만 하오체다.
// 맡은 일로 열차장에게 보고하는 사람(기관사·수색대·배급장·의무장·측근·부관)은 합쇼체, 칸 사람·칸 대표는 해라체다.
// 앞칸 대표만 합쇼체이고 돌려 말하는 「~지요」도 그 높임으로 본다. 구조 카드의 바깥 사람은 높여 말한다.

type Ending = '합쇼' | '지요' | '해요' | '하오' | '해라' | '조각';

/** 한 문장의 말끝 말씨. 말끝이 없는(명사·조사로 끝나는) 문장은 조각이다. */
function endingOf(sentence: string): Ending {
  const last = sentence.replace(/[.!?…~]+$/u, '').trim();
  if (/(아니다|\s다오)$/u.test(last)) return '해라';
  if (/이라$/u.test(last)) return '조각';
  if (/(습니다|십시오|니다|니까|십시다)$/u.test(last)) return '합쇼';
  if (/(지요|죠)$/u.test(last)) return '지요';
  if (/(세요|어요|아요|해요|예요|에요|요)$/u.test(last)) return '해요';
  if (/(구려|오|소)$/u.test(last)) return '하오';
  if (/(다|라|자|냐|니|지|게|군|네|마|야|어|아|래|대|걸|거든|고|까|해|줘|와|봐|러)$/u.test(last)) return '해라';
  return '조각';
}

/** 말 한 덩이의 문장마다 말씨. 자리표시는 X로 둔다. */
function endings(text: string): Ending[] {
  const t = text.replace(/\$\{[^}]*\}/g, 'X').trim().replace(/["'」』”)\]]+$/u, '').trim();
  return t.split(/(?<=[.!?])\s+/u).map(s => s.trim()).filter(Boolean).map(endingOf);
}

type Voice = '보고' | '칸' | '앞칸 대표' | '바깥' | '옮김';
const ALLOWED: Record<Voice, Ending[]> = {
  보고: ['합쇼', '조각'],
  칸: ['해라', '조각'],
  '앞칸 대표': ['합쇼', '지요', '조각'],
  바깥: ['합쇼', '지요', '해요', '조각'],
  옮김: ['합쇼', '지요', '해요', '하오', '해라', '조각'],
};
const fits = (text: string, v: Voice) => endings(text).every(e => ALLOWED[v].includes(e));

/** 열차장이 하오체로 말하는 카드(대체 불가한 장인) */
const HAO_OK = new Set(['dom:manual', 'dom:demand']);

/** 사건 JSON의 따옴표 말("…", 「…」, “…”)마다 누가 하는 말인지. 새 따옴표 말을 쓰면 여기에 적는다. */
const EVENT_VOICES: [file: string, field: string, quote: string, voice: Voice][] = [
  ['ev_b01_doubtful_bridge', 'c_engine_brace.why', '우리 일은 불이다. 압력계가 떨어진다.', '칸'],
  ['ev_b01_fallen_tree', 'c_front_work.why', '하겠다', '칸'],
  ['ev_b01_frost_bird', 'c_front_space.why', '괜찮다', '칸'],
  ['ev_b01_frozen_switch', 'c_guard_clear.why', '얼음 걷기는 순찰이 아니다.', '칸'],
  ['ev_b01_mended_harmonica', 'c_front_cloth.why', '내주겠다', '칸'],
  ['ev_b01_strap_break', 'c_front_hold.why', '언제까지 두는지는 알아야겠다', '칸'],
  ['ev_b01_two_wagons', 'c_guard_push.why', '미는 건 기관차가 한다.', '칸'],
  ['ev_b01_warm_potatoes', 'c_front_share.later', '어긴 말', '옮김'],
  ['ev_b01_wobbly_cart', 'c_engine_carry.why', '손수레 일은 우리 몫이 아니다.', '칸'],
  ['ev_h01_low_fire', 'body', '이 삽질로는 다음 탑까지 불이 안 갑니다. 어디서든 덜어야 합니다.', '보고'],
  ['ev_h02_burst_crates', 'body', '끓이면 먹을 수는 있습니다, 탈이 날지는 모릅니다.', '보고'],
  ['ev_h02_burst_crates', 'c_swap_front.later', '어긴 말', '옮김'],
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
  ['ev_h06_split_pipe', 'body', '세우면 반나절, 달리면서 고치면 손이 얼고, 두면 뒤가 얼어붙습니다.', '보고'],
  ['ev_h07_broken_word', 'body', '겨울 솥은 건드리지 않겠다고 하셨습니다. 뒤에 선 사람들이 그 말을 기억합니다.', '앞칸 대표'],
  ['ev_h07_kept_word', 'body', '겨울 솥은 그대로였습니다. 말씀대로였습니다.', '앞칸 대표'],
  ['ev_h07_quiet_offer', 'body', '다음 회기 표는 드립니다, 안건을 좋아해서가 아닙니다. 이번 겨울 앞칸 솥만 건드리지 말아 주십시오.', '앞칸 대표'],
  ['ev_h07_quiet_offer', 'c_accept.later', '지킨 말', '옮김'],
  ['ev_h07_quiet_offer', 'c_accept.later', '어긴 말', '옮김'],
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

/** S1 게임 코드(`src/game`)의 큰따옴표 말마다 누가 하는 말인지. 같은 파일에 같은 말이 여러 번 나와도 한 줄. */
const TS_VOICES: [file: string, quote: string, voice: Voice][] = [
  ['arrival_cards.ts', '늦게 탄 사람들이 문간과 통로에서 잡니다. 먼저 있던 사람들과 자리를 두고 말이 오갔습니다.', '앞칸 대표'],
  ['arrival_cards.ts', '늦게 탄 사람들이 문간과 통로에서 잔다. 먼저 있던 사람들과 자리를 두고 말이 오갔다.', '칸'],
  ['budget.ts', '역사 안에', '옮김'],
  ['budget.ts', '설계도가 맞았다', '옮김'],
  ['cards.ts', '앞칸엔 난로가 두 개다.', '칸'],
  ['cards.ts', '참아라', '옮김'],
  ['cards.ts', '누울 자리가 사람 수보다 적다.', '칸'],
  ['cards.ts', '배부른 칸', '옮김'],
  ['cards.ts', '지난번 녹이느라 태운 석탄이면 한참 달렸다.', '칸'],
  ['cards.ts', '이번에도 우리냐?', '칸'],
  ['cards.ts', '지난번처럼 버티면 보일러 관이 탑니다.', '보고'],
  ['cards.ts', '다 같이 파면 금방 끝난다.', '칸'],
  ['cards.ts', '이번엔 앞칸 차례다.', '칸'],
  ['cards.ts', '해열제는 상자에 있습니다. 꺼낼지 정해 주십시오.', '보고'],
  ['cards.ts', '그 집 애만 애냐.', '칸'],
  ['cards.ts', '우리 애 차례는 언제냐.', '칸'],
  ['cards.ts', '우리 몫은 어디 갔어!', '칸'],
  ['cards.ts', '지난번처럼!', '칸'],
  ['cards.ts', '교대를 줄여 달라.', '칸'],
  ['cards.ts', '지붕 교대는 이제 못 선다.', '칸'],
  ['cards.ts', '지붕 위로 뭔가 지나갔다.', '칸'],
  ['cards.ts', '그 칸 난로는 밤새 벌겋더라.', '칸'],
  ['cards.ts', '화부들 손이 떨린다. 교대를 늘려 달라.', '칸'],
  ['cards.ts', '지난번 답, 우리는 기억한다.', '칸'],
  ['cards.ts', '제일 적게 받는 우리한테서 또 깎으면, 그게 고르게 줄이는 거냐.', '칸'],
  ['cards.ts', '다음 역까지 답이 없으면 불을 끄겠다.', '칸'],
  ['cards.ts', '데려가 주세요. 걸을 수는 있어요.', '바깥'],
  ['cards.ts', '할아버지를 업고 여기까지 왔어요. 같이 가게 해 주세요.', '바깥'],
  ['cards.ts', '아이만이라도 태워 주세요.', '바깥'],
  ['cards.ts', '기관사였어요. 불은 아직 땔 줄 알아요.', '바깥'],
  ['cards.ts', '또 두고 갑니까?', '보고'],
  ['cards.ts', '열차장…', '보고'],
  ['cards.ts', '감염 창이 닫히기 전에 잘라야 합니다.', '보고'],
  ['cards.ts', '${rep}이(가) 사흘째 일어나지 못한다. 회기엔 내가 나간다.', '칸'],
  ['cards.ts', '다음 역에서 내리겠다. 내 몫은 아이들에게.', '칸'],
  ['cards.ts', '아들이 나았다. 이번엔 조카다.', '칸'],
  ['cards.ts', '동생이 앞칸에서 쫓겨날 것 같다. 한마디만 해 달라.', '칸'],
  ['cards.ts', '부관 얘기, 잊지 않았겠지.', '칸'],
  ['cards.ts', '손님이 또 옵니다. 이번엔 세 병.', '앞칸 대표'],
  ['cards.ts', '그 견습생, 쓸 만하다. 하나 더.', '칸'],
  ['cards.ts', '아이들 겨울옷이 모자라다. 두 벌만.', '칸'],
  ['cards.ts', '비누가 없어 손을 못 씻는다. 한 상자만.', '칸'],
  ['cards.ts', '아들이 기침을 한다. 의무칸 침상 하나만.', '칸'],
  ['cards.ts', '동생이 앞칸 빈자리에 갈 수 있게 해 달라.', '칸'],
  ['cards.ts', '부관 자리 얘기, 다음에 내 이름도 올려 달라.', '칸'],
  ['cards.ts', '술 두 병만. 손님을 맞아야 합니다.', '앞칸 대표'],
  ['cards.ts', '견습생 하나를 꼬리칸에서 데려가고 싶다. 내가 고른 아이로.', '칸'],
  ['council_log.ts', '법은 모질게 세우면서 약속은 가볍게 어긴다.', '칸'],
  ['hub.ts', '${COMM_NAME[c]} 문을 막으면 된다. 말만 하라.', '칸'],
  ['needs.ts', '누가 얼마나 때는지 정하자', '칸'],
  ['needs.ts', '이 줄 밑이면 불을 꺼야 한다. 어디부터 끌지 정해 달라.', '칸'],
  ['needs.ts', '남은 석탄은 누가 정하냐?', '칸'],
  ['needs.ts', '정해진 몫을 달라', '칸'],
  ['needs.ts', '몫을 정해 달라.', '칸'],
  ['needs.ts', '저 사람을 언제까지 저렇게 둘 거냐.', '칸'],
  ['needs.ts', '누가 옮길지 정해 달라.', '칸'],
  ['needs.ts', '시신은 누가 치우느냐', '옮김'],
  ['needs.ts', '누구부터 치료할지 정해 달라.', '칸'],
  ['needs.ts', '순서 없이는 다 못 살립니다.', '보고'],
  ['politics.ts', '열차장은 약점을 잡는다.', '칸'],
  ['prologue.ts', '저탄장에 우리 사람 다섯이 있다. 그들을 데려오면 첫 회기에서 당신 편에 서겠다.', '칸'],
  ['prologue.ts', '약속을 지켰다. 그러니 하나만 청한다. 꼬리칸 난로에 석탄을 한 삽 더.', '칸'],
  ['prologue.ts', '이제 값을 치러라. 꼬리칸 난로에 한 삽 더, 배급도 한 국자 더.', '칸'],
  ['prologue.ts', '저탄장에 두고 온 사람들이다. 길을 질러 여기까지 왔다.', '칸'],
  ['dark/cases.ts', '${name}이(가) 한 일이라는 건 소문뿐이었다. 억울하다.', '칸'],
  ['domestic/data.ts', "종자곡 풀기에 '반만 풀기' 변형이 열린다(식량 +15, 앞칸 −10)", '옮김'],
  ['domestic/data.ts', "아동 노동에 '짐 꾸리기만' 변형이 열린다(아이들은 내리지 않는다). 공방에서 썰매·들것을 만든다(S2)", '옮김'],
];

const GAME = fileURLToPath(new URL('../../src/game/', import.meta.url));
const EVENTS = fileURLToPath(new URL('../../data/events/', import.meta.url));

/** 칸 대표가 요구하며 하는 말 표(cards.ts·late.ts)를 소스에서 칸마다 읽는다. 표는 내보내지 않는 값이라 글로 읽는다. */
function repLines(file: string, name: string): [comm: string, line: string][] {
  const src = readFileSync(join(GAME, file), 'utf8');
  const start = src.indexOf(`const ${name}:`);
  const body = src.slice(start, src.indexOf('\n};', start));
  return body.split('\n').flatMap(line => {
    const m = /^\s+(tail|medtech|guard|front|engine):/.exec(line);
    return m ? [...line.matchAll(/'([^']+)'/g)].map(q => [m[1], q[1]] as [string, string]) : [];
  });
}

function tsFiles(dir: string): string[] {
  return readdirSync(dir).flatMap(f => {
    const p = join(dir, f);
    return statSync(p).isDirectory() ? tsFiles(p) : f.endsWith('.ts') ? [p] : [];
  });
}

/** 글 칸 하나에서 따옴표 말을 모두 뽑는다 */
function quotesIn(text: string): string[] {
  return [...text.matchAll(/"([^"]+)"|「([^」]+)」|“([^”]+)”/gu)].map(m => m[1] ?? m[2] ?? m[3]);
}

/** 사건 하나의 모든 글 칸(본문·선택지의 모든 문자열) */
function eventTexts(ev: Record<string, unknown>): [string, string][] {
  const out: [string, string][] = [];
  for (const [k, v] of Object.entries(ev)) if (typeof v === 'string' && k !== 'id') out.push([k, v]);
  for (const c of (ev.choices as Record<string, unknown>[]) ?? []) {
    for (const [k, v] of Object.entries(c)) if (typeof v === 'string' && k !== 'id') out.push([`${c.id}.${k}`, v]);
  }
  return out;
}

/** 표 열쇠와 찾은 열쇠를 맞대어 빠진 것·남은 것을 돌려준다 */
function compareKeys(found: Set<string>, table: Set<string>): string[] {
  return [...[...found].filter(k => !table.has(k)).map(k => `표에 없음 ${k}`), ...[...table].filter(k => !found.has(k)).map(k => `글에 없음 ${k}`)];
}

describe('말씨 가름', () => {
  it('문장마다 말끝을 가른다', () => {
    expect(endings('…신임은 말로 되찾는 게 아니다.')).toEqual(['해라']);
    expect(endings('석탄을 아껴야 한다. 며칠만 버텨 다오.')).toEqual(['해라', '해라']);
    expect(endings('해열제는 상자에 있습니다. 꺼낼지 정해 주십시오.')).toEqual(['합쇼', '합쇼']);
    expect(endings('온기가 이래서는 손님을 못 받습니다. 조금만 올려 주시지요.')).toEqual(['합쇼', '지요']);
    expect(endings('당신이 죽어도 열차는 달려야 하오.')).toEqual(['하오']);
    expect(endings('내가 가오.')).toEqual(['하오']);
    expect(endings('여기는 안전하다오.')).toEqual(['하오']);
    expect(endings('알겠어요. 출발한다.')).toEqual(['해요', '해라']);
    expect(endings('열쇠는 경비대장 하나만 쥔다. 오늘부터.')).toEqual(['해라', '조각']);
    expect(endings('한 눈금만 올려 줘. 그날 밤 명단부터 다시 가져와.')).toEqual(['해라', '해라']);
    expect(fits('열쇠는 경비대장 하나만 쥡니다. 오늘부터.', '칸')).toBe(false);
    expect(fits('열차를 세워 주십시오. 반나절이면 된다.', '보고')).toBe(false);
    expect(fits('괜찮아요.', '앞칸 대표')).toBe(false);
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
                const key = `${card.kind}\n${say}`;
                if (!say || /^\(.*\)$/.test(say) || seen.has(key)) continue;
                seen.add(key);
                const ok = endings(say).every(e => e === '해라' || e === '조각' || (e === '하오' && HAO_OK.has(card.kind)));
                if (!ok) bad.push(`${card.kind} ${endings(say).join('·')}: ${say}`);
              }
            },
          },
        });
      }
    }
    expect(seen.size).toBeGreaterThan(200);
    expect(bad).toEqual([]);
  });

  it('칸 대표가 요구하며 하는 말은 칸 대표 말씨다(앞칸 대표만 합쇼체)', () => {
    const lines = [
      ...repLines('cards.ts', 'DEMAND_SAY'), ...repLines('cards.ts', 'DEMAND_AGAIN'), ...repLines('cards.ts', 'LEDGER_SAY'), ...repLines('late.ts', 'DEMAND_WORDS'),
    ];
    // 칸 다섯 × (요구 여섯 + 다시 온 요구 여섯 + 어긴 약속 하나 + 미룬 뒤 둘)
    expect(lines.length).toBe(75);
    const bad = lines.filter(([c, s]) => !fits(s, c === 'front' ? '앞칸 대표' : '칸')).map(([c, s]) => `${c} ${endings(s).join('·')}: ${s}`);
    expect(bad).toEqual([]);
  });

  it('사건 글의 따옴표 말은 누가 하는 말인지에 맞는 말씨다', () => {
    const found = new Set<string>();
    const bad: string[] = [];
    const table = new Map(EVENT_VOICES.map(([f, field, q, v]) => [`${f}#${field}#${q}`, v]));
    expect(table.size).toBe(EVENT_VOICES.length);
    for (const file of readdirSync(EVENTS).filter(f => f.endsWith('.json'))) {
      const ev = JSON.parse(readFileSync(join(EVENTS, file), 'utf8')) as Record<string, unknown>;
      for (const [field, text] of eventTexts(ev)) {
        for (const q of quotesIn(text)) {
          const key = `${file.replace(/\.json$/, '')}#${field}#${q}`;
          found.add(key);
          const v = table.get(key);
          if (v && !fits(q, v)) bad.push(`${v}인데 ${endings(q).join('·')}: ${key}`);
        }
      }
    }
    expect([...bad, ...compareKeys(found, new Set(table.keys()))]).toEqual([]);
  });

  it('게임 코드의 따옴표 말은 누가 하는 말인지에 맞는 말씨다', () => {
    const found = new Set<string>();
    const bad: string[] = [];
    const table = new Map(TS_VOICES.map(([f, q, v]) => [`${f}#${q}`, v]));
    expect(table.size).toBe(TS_VOICES.length);
    for (const p of tsFiles(GAME)) {
      const file = relative(GAME, p).replace(/\\/g, '/');
      for (const line of readFileSync(p, 'utf8').split('\n')) {
        const s = line.trim();
        if (s.startsWith('//') || s.startsWith('*') || s.startsWith('/*')) continue;
        for (const m of s.matchAll(/"([^"\n]*[가-힣][^"\n]*)"/gu)) {
          const key = `${file}#${m[1]}`;
          found.add(key);
          const v = table.get(key);
          if (v && !fits(m[1], v)) bad.push(`${v}인데 ${endings(m[1]).join('·')}: ${key}`);
        }
      }
    }
    expect([...bad, ...compareKeys(found, new Set(table.keys()))]).toEqual([]);
  });
});
