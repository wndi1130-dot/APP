import { h } from './dom';
import { CONFIRM_MS, confirmed } from './notice';
import { reproText } from './repro';

// 전체 화면 오류(ui_states.md L3 시작 실패, E2 그리기 오류). 앱의 클릭 위임이 깨졌을 수 있어서
// 단추마다 자기 리스너를 단다. 화면 틀이 아니라 글만 믿는다.

export type CrashKind = 'boot' | 'render';

export interface CrashOpts {
  /** 다시 그리기(render 종류) */
  onRetry?: () => void;
  /** 새 판 시작(render 종류, 두 번 눌러). 새 판을 연 뒤 다시 그리는 것까지 맡는다. */
  onNew?: () => void;
  /** 재현 묶음이 없을 때(앱이 뜨기 전) 대신 복사할 글 */
  fallbackText?: () => string;
}

const COPY_BLOCKED = '복사가 막혔다. 아래 칸을 펼쳐 길게 눌러 복사해 줘.';

function bundleText(opts: CrashOpts): string {
  try {
    return reproText() || opts.fallbackText?.() || '';
  } catch {
    return opts.fallbackText?.() ?? '';
  }
}

export function showCrash(root: HTMLElement, kind: CrashKind, opts: CrashOpts = {}): void {
  const boot = kind === 'boot';
  const status = h('p', { class: 'crash__status', role: 'status' });
  const box = h('textarea', { class: 'crash__text', readonly: true, rows: 6, hidden: true, 'aria-label': '오류 묶음' }) as HTMLTextAreaElement;

  const copy = h('button', { class: 'btn btn--ghost', type: 'button' }, '오류 묶음 복사');
  copy.addEventListener('click', () => {
    const text = bundleText(opts);
    const blocked = () => {
      // 클립보드가 막히면 글을 칸에 펼쳐 길게 눌러 복사하게 한다.
      box.value = text;
      box.hidden = false;
      status.textContent = COPY_BLOCKED;
    };
    const clip = globalThis.navigator?.clipboard;
    if (clip?.writeText) clip.writeText(text).then(() => { status.textContent = `복사했다(${Math.round(text.length / 1000)}KB). 채팅에 붙여 보내 줘.`; }, blocked);
    else blocked();
  });

  const reload = h('button', { class: 'btn', type: 'button' }, boot ? '다시 불러오기' : '다시 그리기');
  reload.addEventListener('click', () => { if (boot) globalThis.location.reload(); else opts.onRetry?.(); });

  const actions: HTMLElement[] = [reload, copy];
  const note = h('p', { class: 'crash__confirm', role: 'status' });
  if (!boot && opts.onNew) {
    // 새 판은 판을 버리므로 3초 안에 두 번 눌러야 한다.
    const fresh = h('button', { class: 'btn btn--ghost', type: 'button' }, '새 판');
    let first: { action: string; t: number } | null = null;
    let timer: ReturnType<typeof setTimeout> | undefined;
    fresh.addEventListener('click', () => {
      const now = Date.now();
      if (confirmed(first, 'new', now)) { clearTimeout(timer); opts.onNew?.(); return; }
      first = { action: 'new', t: now };
      note.textContent = '한 번 더 누르면 지금 판을 버린다.';
      clearTimeout(timer);
      timer = setTimeout(() => { first = null; note.textContent = ''; }, CONFIRM_MS);
    });
    actions.push(fresh);
  }

  root.replaceChildren(h('section', { class: 'crash', role: 'alert' },
    h('div', { class: 'crash__band' },
      h('b', { class: 'crash__title' }, boot ? '열차를 띄우지 못했다.' : '화면이 어긋났다.'),
      h('p', { class: 'crash__line' }, boot ? '저장한 판은 그대로 있다.' : '판은 마지막 저장까지 남아 있다.'),
      h('div', { class: 'crash__actions' }, actions), note, status, box)));
}
