// 콘텐츠 JSON 사건을 디스크에서 읽어 게임에 넣는다(브라우저는 main.ts가 import.meta.glob으로 한다).
// 봇·닿음 검사·시험이 쓴다.

import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { registerContentEvents } from '../src/game';

export const EVENTS_DIR = fileURLToPath(new URL('../data/events/', import.meta.url));

export function readContentEvents(dir = EVENTS_DIR): unknown[] {
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter(f => f.toLowerCase().endsWith('.json')).sort().flatMap(f => {
    const data = JSON.parse(readFileSync(join(dir, f), 'utf8').replace(/^﻿/u, '')) as unknown;
    return Array.isArray(data) ? data : [data];
  });
}

export function loadContentEvents(dir = EVENTS_DIR): number {
  const list = readContentEvents(dir);
  registerContentEvents(list);
  return list.length;
}
