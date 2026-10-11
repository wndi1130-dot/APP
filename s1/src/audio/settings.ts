// 소리 설정(sound_music 8b.1): 켬·끔과 크기 세 단계. 진동(ui/fx.ts)처럼 브라우저에만 남는 개인 설정이다.
// 메뉴에는 단추 하나로 보인다: 누를 때마다 끔 → 작게 → 보통 → 크게 → 끔.
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

export function setSoundVol(next: SoundVol): void {
  vol = next;
  write(VOL_KEY, String(next));
}

/** 메뉴 단추가 도는 차례: 끔 → 작게 → 보통 → 크게 → 끔 */
export function cycleSound(): void {
  if (!soundOn()) {
    setSoundVol(0);
    setSound(true);
  } else if (soundVol() < 2) {
    setSoundVol((soundVol() + 1) as SoundVol);
  } else {
    setSound(false);
  }
}

/** 메뉴 단추 글: '소리 끔', '소리: 작게' */
export function soundLabel(): string {
  return soundOn() ? `소리: ${SOUND_VOL_NAME[soundVol()]}` : '소리 끔';
}
