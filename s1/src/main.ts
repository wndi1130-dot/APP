import './ui/styles.css';
import { registerContentEvents } from './game';
import { startApp } from './ui/app';

// 콘텐츠 JSON 사건(data/events, content.ts). 빌드 때 묶어 넣는다.
const events = import.meta.glob('../data/events/*.json', { eager: true, import: 'default' });
registerContentEvents(Object.values(events).flatMap(x => (Array.isArray(x) ? x : [x])));

const root = document.getElementById('app');
if (root) startApp(root);
