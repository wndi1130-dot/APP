// 소리 설정(sound_music 8b.1): 켬·끔과 크기 세 단계. 진동(ui/fx.ts)처럼 브라우저에만 남는 개인 설정이다.
// 소리는 손끝 반응일 뿐이라 꺼도 놓치는 정보가 없다(원칙 1). 규칙과 저장에는 닿지 않는다.
const SOUND_KEY = 's1a.sound';
const VOL_KEY = 's1a.soundvol';

export type SoundVol = 0 | 1 | 2;
export const SOUND_VOL_NAME = ['작게', '보통', '크게'] as const;
/** 단계마다 곱하는 크기. 파일은 가장 큰 값을 −6~−12dB로 맞춰 두었다. */
export const SOUND_VOL_GAIN = [0.3, 0.6, 1] as const;

let on: boolean | null = null;
let vol: SoundVol | null = null;

function read(key: string): string | null {
  try {
    return globalThis.localStorage?.getItem(key) ?? null;
  } catch {
    return null;
  }
}

function write(key: string, value: string): void {
  try {
    globalThis.localStorage?.setItem(key, value);
  } catch {
    // 저장 못 해도 이번 창에선 따른다.
  }
}

export function soundOn(): boolean {
  if (on === null) on = read(SOUND_KEY) !== '0';
  return on;
}

export function setSound(next: boolean): void {
  on = next;
  write(SOUND_KEY, next ? '1' : '0');
}

export function soundVol(): SoundVol {
  if (vol === null) {
    const saved = read(VOL_KEY);
    vol = saved === '0' ? 0 : saved === '2' ? 2 : 1;
  }
  return vol;
}

/** 작게 → 보통 → 크게 → 작게. 바뀐 단계를 돌려준다 */
export function cycleSoundVol(): SoundVol {
  vol = ((soundVol() + 1) % 3) as SoundVol;
  write(VOL_KEY, String(vol));
  return vol;
}
