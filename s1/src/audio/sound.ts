import { CUES, clipTable, createPlanner, cueForAction } from './cues';
import type { Cue } from './cues';
import { createEngine } from './engine';
import { soundOn } from './settings';
import { createStallPlan, trackTable } from './stall';

// 손끝 소리(sound_music 8b.1). 화면 파일을 고치지 않고 root 한 자리에서 듣는다:
// - 단추를 누름(click의 data-action) → 재질과 무게에 맞는 박자(cues.ts의 표)
// - 막힌 단추에서 손을 뗌 → 막힘. 화면(app.ts)이 단추를 흔드는 것과 같은 조건이다
// - 레버와 눈금 손잡이(range)가 한 단계 움직임 → 걸림
// 소리만 낸다. 화면을 바꾸지 않고 규칙에도 닿지 않는다. 메뉴의 '소리'로 끄면 아무것도 하지 않는다.

const FILES = import.meta.glob('./clips/*.wav', { eager: true, query: '?url', import: 'default' }) as Record<string, string>;
const STALL_FILES = import.meta.glob('./stall/*.wav', { eager: true, query: '?url', import: 'default' }) as Record<string, string>;

function makeContext(): AudioContext | null {
  const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!Ctor) return null;
  try {
    return new Ctor({ latencyHint: 'interactive' });
  } catch {
    return null;
  }
}

export function installSound(root: HTMLElement): void {
  const clips = clipTable(FILES);
  const engine = createEngine({ makeContext, clips, tracks: trackTable(STALL_FILES), load: url => fetch(url).then(r => r.arrayBuffer()), onReady: () => onBeat() });
  const plan = createPlanner(Object.fromEntries(CUES.map(c => [c, clips[c].length])) as Record<Cue, number>);
  const fire = (cue: Cue) => {
    const shot = plan(cue, performance.now());
    if (shot) engine.play(shot);
  };

  // 폰 브라우저는 손짓 뒤에만 소리를 낸다. 손을 뗄 때마다 장치가 깨어 있는지 본다(다른 앱에 다녀오면 다시 잠든다).
  // 손을 댈 때(pointerdown)는 브라우저가 아직 손짓으로 치지 않아 여기서 열지 않는다.
  const wake = () => {
    if (!soundOn()) return;
    void engine.preload();
    engine.unlock();
  };
  for (const type of ['pointerup', 'touchend', 'keydown'] as const) {
    document.addEventListener(type, wake, { capture: true, passive: true });
  }
  // 파일은 첫 손짓 전에 받아 둔다(소리 장치는 아직 열지 않는다). 꺼 두었으면 받지 않는다.
  if (soundOn()) setTimeout(() => void engine.preload(), 300);

  // 브레이크 연출이 도는 동안은 화면이 누름을 받지 않는다. 화면이 다시 그리기 전에 그 상태를 적어 둔다.
  let braking = false;
  root.addEventListener('click', () => { braking = !!root.querySelector('.is-braking'); }, { capture: true });
  root.addEventListener('click', event => {
    const el = (event.target as Element | null)?.closest<HTMLElement | SVGElement>('[data-action]');
    if (!el || braking || (el as HTMLButtonElement).disabled) return;
    wake(); // 메뉴에서 방금 소리를 켠 누름도 손짓이다
    fire(cueForAction(el.dataset.action ?? ''));
  });

  let downAt: { x: number; y: number } | null = null;
  root.addEventListener('pointerdown', event => { downAt = { x: event.clientX, y: event.clientY }; });
  root.addEventListener('pointerup', event => {
    const btn = (event.target as Element | null)?.closest('button:disabled');
    const moved = !downAt || Math.hypot(event.clientX - downAt.x, event.clientY - downAt.y) > 10;
    downAt = null;
    if (btn && !moved && !root.querySelector('.is-braking')) fire('denied');
  });

  root.addEventListener('input', event => {
    const el = event.target as HTMLInputElement | null;
    if (el?.tagName === 'INPUT' && el.type === 'range') fire('lever.notch');
  });

  // 멈춘 열차의 소리(결정 101): 화면이 홈 뿌리에 붙이는 data-beat와 data-stranded가 바뀌는 것만 지켜본다(stall.ts).
  // 화면이 다시 그려져 홈이 새로 만들어져도 값이 같으면 같은 박이다.
  const stall = createStallPlan();
  function onBeat(): void {
    const beat = root.querySelector<HTMLElement>('[data-beat]')?.dataset.beat ?? null;
    // 서 있는가. 홈이 안 보이는 화면(열차 관리, 의회)에서는 모른다(null): 바람을 그대로 둔다.
    // 판이 끝난 화면과 멈춘 화면에서는 서 있는 것이 아니다.
    const home = root.querySelector('section.home');
    const stranded = home ? home.hasAttribute('data-stranded') : root.querySelector('section.end, section.crash') ? false : null;
    for (const act of stall(beat, soundOn(), stranded)) {
      if (act.do === 'hold') {
        if (!engine.hold(act.track, act)) stall.missed(act.track);
      } else if (act.do === 'bend') engine.bend(act.track, act.rate, act.gain, act.ms);
      else engine.release(act.track, act.ms);
    }
  }
  if (typeof MutationObserver !== 'undefined') {
    new MutationObserver(onBeat).observe(root, { subtree: true, childList: true, attributes: true, attributeFilter: ['data-beat', 'data-stranded'] });
  }
  onBeat(); // 서 있는 채로 연 판이면 표식이 이미 붙어 있다
}
