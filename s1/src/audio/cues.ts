import { soundOn } from './settings';

// 손끝 반응의 박자(sound_music 8b.1 `UI.*`). 화면 재질은 둘이다: 계기·단추는 법랑과 놋쇠, 서류는 종이.
// 어느 단추가 어느 박자인지, 같은 소리를 얼마나 띄워 내는지, 변형을 어떻게 돌리는지만 여기서 정한다.
// 소리 장치(engine.ts)와 화면(sound.ts)을 모르는 계산이라 시험이 여기에 붙는다.

export const CUES = ['enamel.press', 'enamel.confirm', 'paper.press', 'paper.confirm', 'lever.notch', 'denied'] as const;
export type Cue = typeof CUES[number];

/** 같은 박자를 다시 내기까지 두는 틈(ms). 이 안에 또 오면 버린다: 연타로 쌓지 않는다. */
export const CUE_GAP: Record<Cue, number> = {
  'enamel.press': 60,
  'paper.press': 60,
  'lever.notch': 45,
  'enamel.confirm': 200,
  'paper.confirm': 200,
  denied: 250,
};

/** 높이를 흔드는 너비: ±5% */
export const PITCH = 0.05;

// 표에 없는 단추는 놋쇠 누름이다. 무게(확정)는 틀리면 시끄러운 쪽이라 뜻이 분명한 단추에만 준다.
const ACTION_CUE: Record<string, Cue> = {
  // 서류에 긋는 한 획: 사건 카드 고르기, 표결과 포고, 남은 사람을 두고 떠나기
  choose: 'paper.confirm',
  vote: 'paper.confirm',
  decree: 'paper.confirm',
  'depart-leave': 'paper.confirm',
  // 서류를 집고 넘기고 접기
  agenda: 'paper.press',
  deal: 'paper.press',
  'deal-cond': 'paper.press',
  'deal-close': 'paper.press',
  fold: 'paper.press',
  'open-stack': 'paper.press',
  person: 'paper.press',
  'log-more': 'paper.press',
  'slip-close': 'paper.press',
  'toast-close': 'paper.press',
  tip: 'paper.press',
  'depart-wait': 'paper.press',
  'dom-why': 'paper.press',
  // 놋쇠 걸쇠가 물리는 확정: 사람을 보내고, 자리를 정하고, 자원을 쓴다
  'stop-go': 'enamel.confirm',
  emergency: 'enamel.confirm',
  'comm-act': 'enamel.confirm',
  'dom-move-apply': 'enamel.confirm',
  'dom-restore': 'enamel.confirm',
  'dom-finish': 'enamel.confirm',
  'dom-restart': 'enamel.confirm',
  'dom-apprentice': 'enamel.confirm',
  'dom-manual': 'enamel.confirm',
  // 단계가 있는 손잡이
  'dom-hot': 'lever.notch',
};

export function cueForAction(action: string): Cue {
  return ACTION_CUE[action] ?? 'enamel.press';
}

/** 파일 이름(`enamel_press_1.wav`)에서 박자를 읽어 변형 목록으로 묶는다. 이름이 안 맞는 파일은 버린다. */
export function clipTable(files: Record<string, string>): Record<Cue, string[]> {
  const table = Object.fromEntries(CUES.map(c => [c, [] as string[]])) as Record<Cue, string[]>;
  for (const path of Object.keys(files).sort()) {
    const m = /([a-z]+(?:_[a-z]+)?)_\d+\.wav$/.exec(path);
    const cue = m?.[1].replace('_', '.') as Cue | undefined;
    if (cue && cue in table) table[cue].push(files[path]);
  }
  return table;
}

/** 낼 소리 하나: 어느 박자의 몇째 변형을 어느 높이로 */
export interface Shot { cue: Cue; variant: number; rate: number }

/**
 * 소리를 낼지 정한다. 소리를 껐거나, 같은 박자가 틈 안에 또 왔거나, 변형 파일이 없으면 null.
 * 변형은 바로 앞의 것을 피해 고르고 높이를 ±5% 흔든다.
 */
export function createPlanner(variants: Record<Cue, number>, rand: () => number = Math.random): (cue: Cue, now: number) => Shot | null {
  const lastAt = new Map<Cue, number>();
  const lastVariant = new Map<Cue, number>();
  return (cue, now) => {
    const n = variants[cue];
    if (!soundOn() || !n) return null;
    if (now - (lastAt.get(cue) ?? -Infinity) < CUE_GAP[cue]) return null;
    const prev = lastVariant.get(cue);
    let variant = prev === undefined || n === 1 ? Math.floor(rand() * n) : Math.floor(rand() * (n - 1));
    if (prev !== undefined && n > 1 && variant >= prev) variant += 1;
    variant = Math.min(n - 1, variant);
    lastAt.set(cue, now);
    lastVariant.set(cue, variant);
    return { cue, variant, rate: 1 + (rand() * 2 - 1) * PITCH };
  };
}
