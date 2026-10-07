import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.DEMO02_PLAYWRIGHT || 'D:/Apps/NodeJS/node_modules/@playwright/mcp/node_modules/playwright');
const { PNG } = require('D:/Apps/NodeJS/node_modules/@playwright/mcp/node_modules/playwright-core/lib/utilsBundle.js');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const shots = path.join(root, 'reviews', 'shots');
mkdirSync(shots, { recursive: true });
const base = process.env.DEMO02_REVIEW_URL || 'http://127.0.0.1:8792';
const browser = await chromium.launch({ headless: true, executablePath: process.env.DEMO02_BROWSER || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const results = [];

async function start(id) {
  const page = await browser.newPage({ viewport: { width: 960, height: 540 }, deviceScaleFactor: 1 });
  const messages = [];
  const errors = [];
  page.on('console', message => {
    const text = message.text();
    messages.push(text);
    if (message.type() === 'error' && !text.includes('favicon')) errors.push(text);
  });
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(`${base}/builds/${id}/index.html`);
  await page.waitForFunction(() => !document.getElementById('status'), { timeout: 45000 });
  await page.locator('canvas').focus();
  return { page, messages, errors };
}
async function waitForTelemetry(state, prefix) {
  const startTime = Date.now();
  while (Date.now() - startTime < 25000) {
    if (state.messages.some(message => message.includes(prefix))) return;
    if (state.errors.length) throw new Error(state.errors.join('\n'));
    await state.page.waitForTimeout(100);
  }
  throw new Error(`Missing browser telemetry: ${prefix}\n${state.messages.slice(-10).join('\n')}`);
}
async function featherPosition(page) {
  const png = PNG.sync.read(await page.screenshot());
  const { width, height, data } = png;
  const mask = new Uint8Array(width * height);
  for (let y = 40; y < Math.min(height, 480); y++) {
    for (let x = 35; x < width - 5; x++) {
      const index = (y * width + x) * 4;
      if (Math.abs(data[index] - 232) < 3 && Math.abs(data[index + 1] - 228) < 3 && Math.abs(data[index + 2] - 216) < 3) mask[y * width + x] = 1;
    }
  }
  let largest = null;
  for (let index = 0; index < mask.length; index++) {
    if (!mask[index]) continue;
    mask[index] = 0;
    const queue = [index];
    let sumX = 0, sumY = 0;
    for (let cursor = 0; cursor < queue.length; cursor++) {
      const pixel = queue[cursor];
      sumX += pixel % width;
      sumY += Math.floor(pixel / width);
      for (const adjacent of [pixel - 1, pixel + 1, pixel - width, pixel + width]) {
        if (adjacent >= 0 && adjacent < mask.length && mask[adjacent]) { mask[adjacent] = 0; queue.push(adjacent); }
      }
    }
    if (queue.length > 400 && (!largest || queue.length > largest.size)) largest = { x: sumX / queue.length, y: sumY / queue.length, size: queue.length };
  }
  return largest;
}
async function playL3(state) {
  let previous = null, launched = false, steering = false, flapped = false;
  const startTime = Date.now();
  const trace = [];
  while (Date.now() - startTime < 20000) {
    const point = await featherPosition(state.page);
    const now = Date.now();
    if (point) {
      trace.push({ x: Math.round(point.x), y: Math.round(point.y) });
      if (previous && point.y < previous.y - 5) launched = true;
      if (launched && !steering && previous && point.y > previous.y + 1) {
        await state.page.waitForTimeout(300);
        await state.page.keyboard.down('ArrowRight');
        steering = true;
      }
      if (steering && !flapped && previous && (point.y - previous.y) * 1000 / Math.max(1, now - previous.time) > 80) {
        await state.page.keyboard.press('Space');
        flapped = true;
      }
      if (steering && point.x >= 640 && point.y < 220) {
        await state.page.keyboard.up('ArrowRight');
        await state.page.keyboard.press('Digit2');
        await waitForTelemetry(state, 'TEL|L3|');
        return { flapped, trace };
      }
      previous = { ...point, time: now };
    }
    await state.page.waitForTimeout(80);
  }
  await state.page.keyboard.up('ArrowRight');
  throw new Error(`L3 visual-input route failed: ${JSON.stringify(trace)}`);
}
try {
  const three = await start('demo-02-3d-v16');
  await three.page.screenshot({ path: path.join(shots, 'demo-02-3d-v16-start.png') });
  await three.page.keyboard.press('Digit3', { delay: 100 });
  await three.page.keyboard.down('KeyW');
  await waitForTelemetry(three, 'TEL3D|L1|');
  await three.page.keyboard.up('KeyW');
  await three.page.screenshot({ path: path.join(shots, 'demo-02-3d-v16-L1-win.png') });
  await three.page.mouse.click(875, 30);
  await three.page.waitForTimeout(150);
  await three.page.screenshot({ path: path.join(shots, 'demo-02-3d-v16-L2.png') });
  results.push({ build: 'demo-02-3d-v16', browser: 'headless Edge', passed: three.errors.length === 0, telemetry: three.messages.filter(message => message.includes('TEL3D|')), errors: three.errors, screenshots: ['start', 'L1-win', 'L2'] });
  await three.page.close();

  const two = await start('demo-02-v8');
  await two.page.keyboard.press('Digit3');
  await waitForTelemetry(two, 'TEL|L1|');
  await two.page.mouse.click(910, 68);
  await two.page.keyboard.press('Digit2');
  await waitForTelemetry(two, 'TEL|L2|');
  await two.page.mouse.click(910, 68);
  await two.page.keyboard.press('Digit1');
  await two.page.screenshot({ path: path.join(shots, 'demo-02-v8-L3-start.png') });
  const route = await playL3(two);
  await two.page.screenshot({ path: path.join(shots, 'demo-02-v8-L3-win.png') });
  results.push({ build: 'demo-02-v8', browser: 'headless Edge', passed: two.errors.length === 0, telemetry: two.messages.filter(message => message.includes('TEL|')), errors: two.errors, screenshots: ['L3-start', 'L3-win'], l3Route: route });
  await two.page.close();
} finally {
  await browser.close();
  writeFileSync(path.join(root, 'reviews', 'demo02-closing-browser.json'), `${JSON.stringify({ verifiedAt: new Date().toISOString(), results }, null, 2)}\n`);
}
console.log(JSON.stringify(results.map(({ build, passed, telemetry, errors }) => ({ build, passed, telemetry, errors })), null, 2));
process.exitCode = results.length === 2 && results.every(result => result.passed) ? 0 : 1;
