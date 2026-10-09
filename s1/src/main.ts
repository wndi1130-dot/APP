import './ui/styles.css';
import { registerContentDeals, registerContentEvents, registerContentSecrets } from './game';
import { startApp } from './ui/app';
import { showCrash } from './ui/crash';

// 콘텐츠 JSON(data/events·secrets·deals, content.ts). 빌드 때 묶어 넣는다.
const flat = (m: Record<string, unknown>): unknown[] => Object.values(m).flatMap(x => (Array.isArray(x) ? x : [x]));

const root = document.getElementById('app');

// 부팅 중에 난 오류를 놓치지 않게 앱보다 먼저 건다. 앱이 뜨면 걷고, 그 뒤의 오류는 앱(app.ts noteError)이 남긴다.
const early: { msg: string; stack?: string }[] = [];
const noteEarly = (e: unknown) => {
  const err = e instanceof Error ? e : new Error(String(e));
  console.error(err);
  if (early.length < 5) early.push({ msg: err.message, stack: err.stack?.split('\n').slice(0, 12).join('\n') });
};
const onError = (event: ErrorEvent) => noteEarly(event.error ?? event.message);
const onRejection = (event: PromiseRejectionEvent) => noteEarly(event.reason);
window.addEventListener('error', onError);
window.addEventListener('unhandledrejection', onRejection);

if (root) {
  try {
    registerContentEvents(flat(import.meta.glob('../data/events/*.json', { eager: true, import: 'default' })));
    registerContentSecrets(flat(import.meta.glob('../data/secrets/*.json', { eager: true, import: 'default' })));
    registerContentDeals(flat(import.meta.glob('../data/deals/*.json', { eager: true, import: 'default' })));
    startApp(root);
    window.removeEventListener('error', onError);
    window.removeEventListener('unhandledrejection', onRejection);
  } catch (e) {
    noteEarly(e);
    // 앱이 뜨기 전이면 재현 묶음이 없으니 모은 오류를 대신 복사한다.
    showCrash(root, 'boot', { fallbackText: () => JSON.stringify({ kind: 'boot', errors: early, ua: navigator.userAgent, t: Date.now() }) });
  }
}
