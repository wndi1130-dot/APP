#!/usr/bin/env node
// S1a 플레이 빌드 스크린샷. 빌드한 dist/를 작은 정적 서버로 띄우고 Playwright(Chromium)로 찍는다.
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
  const inHScroll = element => !!element.closest('[data-keep-scroll]');
  for (const element of document.querySelectorAll('body *')) {
    if (!visible(element)) continue;
    const rect = element.getBoundingClientRect();
    if (!inHScroll(element) && (rect.right > window.innerWidth + 0.5 || rect.left < -0.5)) {
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
    if (block && !(element instanceof SVGElement) && !element.hasAttribute('data-keep-scroll') && !inHScroll(element) && element.scrollWidth > element.clientWidth + 1) {
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


const SEED = process.env.SCREENSHOT_SEED || 'demo1';

async function click(page, selector) {
  const locator = page.locator(selector).first();
  await locator.waitFor({ state: 'visible', timeout: 5000 });
  await locator.click();
  await page.waitForTimeout(60);
}

async function has(page, selector) {
  return (await page.locator(selector).count()) > 0;
}

/** 한 걸음: 펼친 서류를 처리하거나, 창을 닫거나, 주 단추를 누른다. */
async function step(page) {
  if (await has(page, '.side, .drop, .settle')) return click(page, '.drop__head .x');
  if (await has(page, '[data-action="stop-go"]')) return click(page, '[data-action="stop-go"][data-go="1"]');
  if (await has(page, '[data-action="stop-seen"]')) return click(page, '[data-action="stop-seen"]');
  if (await has(page, '.choice:not([disabled])')) return click(page, '.choice:not([disabled])');
  if (await has(page, '.skip')) return click(page, '.skip');
  if (await has(page, '.vote-actions [data-action="vote"]')) return click(page, '.vote-actions [data-action="vote"]');
  if (await has(page, '.bottom [data-action="advance"]')) return click(page, '.bottom [data-action="advance"]');
  if (await has(page, '.bottom [data-action="open-stack"]')) return click(page, '.bottom [data-action="open-stack"]');
  throw new Error('누를 것이 없다');
}

async function until(page, selector, limit = 80) {
  for (let i = 0; i < limit; i += 1) {
    if (await has(page, selector)) return;
    await step(page);
  }
  throw new Error(`${selector}에 닿지 못했다`);
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
    await page.goto(`${url}?seed=${SEED}`);
    await page.locator('.home').waitFor();

    // 홈: 열차 단면, 칸 작은 창
    await capture(page, '01-home');
    await click(page, '[data-action="car"][data-car="tail1"]');
    await page.locator('.carpop').waitFor();
    await capture(page, '02-car-tail');
    await click(page, '.carpop .x');

    // 한눈에 보기와 수치만 보기
    await click(page, '.bottom [data-screen="overview"]');
    await page.locator('.overview').waitFor();
    await capture(page, '03-overview');
    await click(page, '[data-action="numbers"]');
    await capture(page, '04-overview-numbers');
    await click(page, '[data-action="numbers"]');
    await click(page, '.bottom [data-screen="home"]');

    // 불만 쪽 창
    await click(page, '.band__btn--unrest');
    await page.locator('.drop').waitFor();
    await capture(page, '05-factions');
    await click(page, '.drop__head .x');

    // 출발: 서류(사건 카드)
    await click(page, '.bottom [data-action="advance"]');
    await until(page, '.sheet');
    await capture(page, '06-card');

    // 정차 카드와 결과
    await until(page, '[data-action="stop-go"]');
    await capture(page, '07-stop');
    await click(page, '[data-action="stop-go"][data-go="1"]');
    await page.locator('[data-action="stop-seen"]').waitFor();
    await capture(page, '08-stop-result');
    // 회기가 아닌 구간: 정차를 덮으면 비상 소집 단추가 주 단추 옆에 뜬다.
    await click(page, '[data-action="stop-seen"]');
    await page.locator('.bottom [data-action="emergency"]').waitFor();
    await capture(page, '08b-emergency');

    // 의회(3구간 회기)
    await until(page, '.council .hemi');
    await capture(page, '09-council');
    // 거래 도구가 열린 집단을 고른다.
    let dealt = false;
    for (const c of ['tail', 'medtech', 'front', 'engine', 'guard']) {
      await click(page, `.clist [data-comm="${c}"], .plate[data-comm="${c}"]`);
      if (!dealt && await has(page, '[data-action="deal"][data-tool="open"]:not([disabled])')) {
        await capture(page, '10-council-leader');
        await click(page, '.cpanel .name');
        await page.locator('.person').waitFor();
        await capture(page, '10b-person');
        await click(page, '.person .x');
        await click(page, '[data-action="deal"][data-tool="open"]');
        await capture(page, '11-council-open-deal');
        await click(page, '.cond');
        if (await has(page, '.cut-pick')) await click(page, '.cut-pick .chip');
        await capture(page, '12-council-after-deal');
        dealt = true;
        break;
      }
    }
    if (!dealt) throw new Error('공개 협상을 열 수 있는 집단이 없다');
    await click(page, '.vote-actions [data-action="vote"]');
    await page.locator('.verdict').waitFor();
    await capture(page, '13-council-result');

    // 정산과 일지
    await until(page, '.settle');
    await capture(page, '14-settle');
    await click(page, '.drop__head .x');
    await click(page, '.bottom [data-panel="journal"]');
    await capture(page, '15-journal');
    await click(page, '.drop__head .x');

    // 끝까지 자동으로
    await until(page, '.end', 2000);
    await capture(page, '16-end');
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
    await capture(portraitPage, '17-portrait', { landscape: false });
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
