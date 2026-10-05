#!/usr/bin/env node
// S1a 화면 뼈대 스크린샷. 빌드한 dist/를 작은 정적 서버로 띄우고 Playwright(Chromium)로 찍는다.
//
//   npm run build
//   NODE_PATH="$(npm root -g)" node tools/screenshots.cjs
//
// 가로 844×390에서 찍을 때마다 가로 스크롤(document.scrollingElement.scrollWidth > innerWidth),
// 화면 밖으로 나간 요소, 잘리거나 상자 밖으로 넘친 내용, 세로 스크롤, 12px보다 작은 글자를
// 검사하고 하나라도 있으면 실패(종료 코드 1)한다.
//
// 다른 크기로 같은 흐름을 검사할 때(저장 폴더를 따로 준다):
//   SCREENSHOT_VIEWPORT=750x340 SCREENSHOT_DIR=/tmp/shots NODE_PATH="$(npm root -g)" node tools/screenshots.cjs
'use strict';

const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');

let chromium;
try {
  ({ chromium } = require('playwright'));
} catch (error) {
  console.error('playwright를 찾지 못했다. NODE_PATH="$(npm root -g)"를 붙여 실행한다.');
  console.error(String(error && error.message));
  process.exit(2);
}

const ROOT = path.resolve(__dirname, '..');
const DIST = path.join(ROOT, 'dist');
const OUT = process.env.SCREENSHOT_DIR ? path.resolve(process.env.SCREENSHOT_DIR) : path.join(ROOT, 'screenshots');

function parseViewport(value, fallback) {
  const match = /^(\d+)x(\d+)$/.exec(value || '');
  return match ? { width: Number(match[1]), height: Number(match[2]) } : fallback;
}

const LANDSCAPE = parseViewport(process.env.SCREENSHOT_VIEWPORT, { width: 844, height: 390 });
const PORTRAIT = { width: LANDSCAPE.height, height: LANDSCAPE.width };
const MIN_FONT_PX = 12;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
};

function serve(dir) {
  const server = http.createServer((request, response) => {
    const url = new URL(request.url, 'http://localhost');
    const relative = decodeURIComponent(url.pathname).replace(/^\/+/, '') || 'index.html';
    const file = path.resolve(dir, relative);
    if (!file.startsWith(dir + path.sep) && file !== dir) {
      response.writeHead(403).end();
      return;
    }
    fs.readFile(file, (error, body) => {
      if (error) {
        response.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' }).end('없음');
        return;
      }
      response.writeHead(200, { 'content-type': MIME[path.extname(file)] || 'application/octet-stream' }).end(body);
    });
  });
  return new Promise(resolve => {
    server.listen(0, '127.0.0.1', () => resolve({ server, url: `http://127.0.0.1:${server.address().port}/` }));
  });
}

/** 화면 배치 검사. 브라우저 안에서 돈다. */
function inspectLayout(minFont) {
  const describe = element => {
    const test = element.closest('[data-test]');
    const label = element.getAttribute('class') || element.tagName.toLowerCase();
    return `${label}${test ? ` (in ${test.getAttribute('data-test')})` : ''}`;
  };
  const visible = element => {
    const style = getComputedStyle(element);
    if (style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity) === 0) return false;
    const rect = element.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  };
  const scroller = document.scrollingElement;
  const main = document.querySelector('main');
  const mainRect = main ? main.getBoundingClientRect() : null;
  const inScrollBox = element => {
    for (let node = element.parentElement; node && node !== main; node = node.parentElement) {
      const overflowY = getComputedStyle(node).overflowY;
      if (overflowY === 'auto' || overflowY === 'scroll' || overflowY === 'hidden' || overflowY === 'clip') return true;
    }
    return false;
  };
  const overlapping = [];
  const outside = [];
  const smallText = [];
  const clipped = [];
  const truncated = [];
  for (const element of document.querySelectorAll('body *')) {
    if (!visible(element)) continue;
    const rect = element.getBoundingClientRect();
    if (rect.right > window.innerWidth + 0.5 || rect.left < -0.5) {
      outside.push(`${describe(element)} [${Math.round(rect.left)}, ${Math.round(rect.right)}]`);
    }
    if (mainRect && main.contains(element) && element !== main && !inScrollBox(element)
      && (rect.bottom > mainRect.bottom + 1 || rect.top < mainRect.top - 1)) {
      overlapping.push(`${describe(element)} [${Math.round(rect.top)}, ${Math.round(rect.bottom)}]`);
    }
    const ownText = [...element.childNodes].some(node => node.nodeType === Node.TEXT_NODE && node.textContent.trim() !== '');
    const style = getComputedStyle(element);
    if (ownText && parseFloat(style.fontSize) < minFont) smallText.push(`${describe(element)} ${style.fontSize}`);
    const block = style.display !== 'inline' && style.display !== 'contents' && element.clientWidth > 0;
    if (block && element.scrollWidth > element.clientWidth + 1) {
      const entry = `${describe(element)} ${element.scrollWidth}>${element.clientWidth}`;
      if (style.textOverflow === 'ellipsis') truncated.push(entry);
      else if (style.overflowX === 'hidden' || style.overflowX === 'clip') clipped.push(entry);
      else if (style.overflowX === 'visible') clipped.push(`${entry} (상자 밖으로 넘침)`);
      else clipped.push(`${entry} (가로 스크롤 상자)`);
    }
  }
  return {
    scrollWidth: scroller.scrollWidth,
    scrollHeight: scroller.scrollHeight,
    innerWidth: window.innerWidth,
    innerHeight: window.innerHeight,
    outside,
    overlapping,
    smallText,
    clipped,
    truncated,
  };
}

const report = [];

async function capture(page, name, { landscape = true } = {}) {
  const file = path.join(OUT, `${name}.png`);
  await page.waitForTimeout(80);
  const layout = await page.evaluate(inspectLayout, MIN_FONT_PX);
  const problems = [];
  if (landscape) {
    if (layout.scrollWidth > layout.innerWidth) {
      problems.push(`가로 스크롤이 생겼다: scrollWidth ${layout.scrollWidth} > innerWidth ${layout.innerWidth}`);
    }
    if (layout.outside.length > 0) problems.push(`화면 밖으로 나간 요소: ${layout.outside.slice(0, 8).join('; ')}`);
    if (layout.clipped.length > 0) problems.push(`잘린 내용: ${layout.clipped.slice(0, 8).join('; ')}`);
    if (layout.overlapping.length > 0) problems.push(`본문이 위아래 막대를 침범: ${layout.overlapping.slice(0, 8).join('; ')}`);
    if (layout.scrollHeight > layout.innerHeight) problems.push(`세로 스크롤이 생겼다: ${layout.scrollHeight} > ${layout.innerHeight}`);
  }
  if (layout.smallText.length > 0) problems.push(`${MIN_FONT_PX}px보다 작은 글자: ${layout.smallText.slice(0, 8).join('; ')}`);
  await page.screenshot({ path: file, animations: 'disabled' });
  report.push({ name, file: path.relative(ROOT, file), truncated: layout.truncated.length });
  if (problems.length > 0) {
    throw new Error(`[${name}] 배치 검사 실패\n  - ${problems.join('\n  - ')}`);
  }
  const note = layout.truncated.length > 0 ? ` · 말줄임 ${layout.truncated.length}곳` : '';
  console.log(`찍음 ${path.relative(ROOT, file)}${note}`);
}

async function tap(page, test) {
  const locator = page.locator(`[data-test="${test}"]`).first();
  await locator.waitFor({ state: 'visible', timeout: 5000 });
  await locator.tap();
}

async function expectText(page, test, text) {
  const content = await page.locator(`[data-test="${test}"]`).first().innerText();
  if (!content.includes(text)) throw new Error(`[${test}]에 "${text}"가 없다: ${content.slice(0, 200)}`);
}

/** 주 단추를 누르고, 결정 카드가 뜨면 고른다. */
async function advanceTo(page, segment, phase, choiceFor) {
  for (let step = 0; step < 60; step += 1) {
    const state = await page.locator('[data-test="stepper"]').getAttribute('aria-label');
    if (state && state.startsWith(`${segment}구간, ${phase} 단계`)) return;
    if (await page.locator('[data-test="decision-card"]').count() > 0) {
      const card = await page.locator('[data-test="decision-card"]').innerText();
      await tap(page, `choice-${choiceFor(card)}`);
      continue;
    }
    await tap(page, 'primary');
  }
  throw new Error(`${segment}구간 ${phase} 단계에 닿지 못했다`);
}

async function main() {
  if (!fs.existsSync(path.join(DIST, 'index.html'))) {
    console.error('dist/index.html이 없다. 먼저 npm run build를 실행한다.');
    process.exit(2);
  }
  fs.mkdirSync(OUT, { recursive: true });
  const { server, url } = await serve(DIST);
  const browser = await chromium.launch();
  const errors = [];
  try {
    const context = await browser.newContext({
      viewport: LANDSCAPE, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: 'ko-KR', reducedMotion: 'reduce',
    });
    const page = await context.newPage();
    page.on('pageerror', error => errors.push(`pageerror: ${error.message}`));
    page.on('console', message => { if (message.type() === 'error') errors.push(`console: ${message.text()}`); });
    await page.goto(url);
    await page.locator('[data-test="support-bar"]').waitFor();

    // 1. 홈
    await capture(page, '01-home');

    // 2. 불만·지지 패널
    await tap(page, 'support-bar');
    await page.locator('[data-test="faction-panel"]').waitFor();
    await capture(page, '02-factions');
    await tap(page, 'close-panel');

    // 3. 결정 카드(이동 단계의 사건 카드)
    await tap(page, 'primary');
    await page.locator('[data-test="decision-card"]').waitFor();
    await capture(page, '03-card');

    // 3구간 회기까지 진행한다. 정차에선 꼬리칸 4명을 보내 회기에 부재가 생기게 한다.
    const pick = card => (card.includes('보낼 사람') ? 0 : 0);
    await advanceTo(page, 3, '의회', pick);
    await tap(page, 'primary'); // 식당칸으로
    await page.locator('[data-test="council"]').waitFor();
    await tap(page, 'mode-public');
    await tap(page, 'primary'); // 표결
    await expectText(page, 'council', '표결 끝');

    // 4·5. 같은 표결을 공개와 비밀로
    await capture(page, '04-council-public');
    await tap(page, 'mode-secret');
    await expectText(page, 'council', '합계만 남는다');
    await capture(page, '05-council-secret');
    await tap(page, 'mode-public');

    // 6. 열차장실(일지), 인물
    await tap(page, 'back');
    await tap(page, 'car-captain');
    await page.locator('[data-test="journal"]').waitFor();
    await capture(page, '06-captain-journal');
    await tap(page, 'tab-people');
    await page.locator('[data-test="people"]').waitFor();
    await capture(page, '07-captain-people');

    // 공동체 칸(꼬리칸)
    await tap(page, 'back');
    await tap(page, 'car-tail');
    await page.locator('[data-test="community-tail"]').waitFor();
    await capture(page, '08-car-tail');

    // 메뉴와 디버그
    await tap(page, 'back');
    await tap(page, 'menu');
    await page.locator('[data-test="menu-popover"]').waitFor();
    await tap(page, 'save');
    await tap(page, 'menu');
    await capture(page, '09-menu');
    await tap(page, 'debug');
    await page.locator('[data-test="debug"]').waitFor();
    await page.locator('[data-test="toast"]').waitFor({ state: 'detached', timeout: 5000 });
    await tap(page, 'flag-S1b');
    await tap(page, 'flag-S1c');
    await capture(page, '10-debug');

    // 플래그와 더미 세력을 켠 상태: 공방칸 자리(S1c), 6집단 의회, S1b 자리
    await tap(page, 'flag-faction');
    await tap(page, 'back');
    await capture(page, '11-home-flags');
    await advanceTo(page, 4, '출발 전 운영', () => 1);
    await tap(page, 'car-dining');
    await page.locator('[data-test="council"]').waitFor();
    await expectText(page, 'council', '복원파');
    await capture(page, '12-council-faction');
    await context.close();

    // 세로 화면
    const portrait = await browser.newContext({
      viewport: PORTRAIT, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: 'ko-KR', reducedMotion: 'reduce',
    });
    const portraitPage = await portrait.newPage();
    portraitPage.on('pageerror', error => errors.push(`pageerror: ${error.message}`));
    await portraitPage.goto(url);
    const overlay = portraitPage.locator('.rotate');
    await overlay.waitFor({ state: 'visible' });
    const text = await overlay.innerText();
    if (!text.includes('가로로 돌려 주세요')) throw new Error(`세로 화면 안내가 없다: ${text}`);
    await capture(portraitPage, '13-portrait', { landscape: false });
    await portrait.close();
  } finally {
    await browser.close();
    server.close();
  }
  if (errors.length > 0) throw new Error(`페이지 오류\n  - ${errors.join('\n  - ')}`);
  console.log(`\n${report.length}장 저장: ${path.relative(process.cwd(), OUT) || OUT}`);
}

main().catch(error => {
  console.error(String(error && error.stack ? error.stack : error));
  process.exit(1);
});
