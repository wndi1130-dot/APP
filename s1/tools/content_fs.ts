// 콘텐츠 JSON 사건을 디스크에서 읽어 게임에 넣는다(브라우저는 main.ts가 import.meta.glob으로 한다).
// 봇·닿음 검사·시험이 쓴다.

import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { registerContentDeals, registerContentEvents, registerContentSecrets } from '../src/game';

export const EVENTS_DIR = fileURLToPath(new URL('../data/events/', import.meta.url));

export function readContentEvents(dir = EVENTS_DIR): unknown[] {
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter(f => f.toLowerCase().endsWith('.json')).sort().flatMap(f => {
    const data = JSON.parse(readFileSync(join(dir, f), 'utf8').replace(/^﻿/u, '')) as unknown;
    return Array.isArray(data) ? data : [data];
  });
}

export const SECRETS_DIR = fileURLToPath(new URL('../data/secrets/', import.meta.url));
export const DEALS_DIR = fileURLToPath(new URL('../data/deals/', import.meta.url));

/** 사건과 함께 비밀·거래 조건도 읽는다(사건의 secret·deal 효과가 이걸 찾는다). 돌려주는 수는 사건 수. */
export function loadContentEvents(dir = EVENTS_DIR): number {
  registerContentSecrets(readContentEvents(SECRETS_DIR));
  registerContentDeals(readContentEvents(DEALS_DIR));
  const list = readContentEvents(dir);
  registerContentEvents(list);
  return list.length;
}
