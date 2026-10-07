import './ui/styles.css';
import { registerContentDeals, registerContentEvents, registerContentSecrets } from './game';
import { startApp } from './ui/app';

// 콘텐츠 JSON(data/events·secrets·deals, content.ts). 빌드 때 묶어 넣는다.
const flat = (m: Record<string, unknown>): unknown[] => Object.values(m).flatMap(x => (Array.isArray(x) ? x : [x]));
registerContentEvents(flat(import.meta.glob('../data/events/*.json', { eager: true, import: 'default' })));
registerContentSecrets(flat(import.meta.glob('../data/secrets/*.json', { eager: true, import: 'default' })));
registerContentDeals(flat(import.meta.glob('../data/deals/*.json', { eager: true, import: 'default' })));

const root = document.getElementById('app');
if (root) startApp(root);
