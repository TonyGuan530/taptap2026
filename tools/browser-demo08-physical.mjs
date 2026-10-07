import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.DEMO08_PLAYWRIGHT || 'D:/Apps/NodeJS/node_modules/@playwright/mcp/node_modules/playwright');
const { PNG } = require('D:/Apps/NodeJS/node_modules/@playwright/mcp/node_modules/playwright-core/lib/utilsBundle.js');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const base = process.env.DEMO08_REVIEW_URL || 'http://127.0.0.1:8794';
const surface = base.startsWith('https:') ? 'online' : 'local';
const shots = path.join(root, 'reviews/shots');
mkdirSync(shots, { recursive: true });
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const messages = [], errors = [];
let passed = false;
const visual = [];
const page = await browser.newPage({ viewport: { width: 960, height: 540 } });
page.on('console', message => {
  messages.push(message.text());
  if ((message.type() === 'error' || /SCRIPT ERROR|^ERROR:/.test(message.text())) && !message.text().includes('favicon')) errors.push(message.text());
});
page.on('pageerror', error => errors.push(error.message));
const count = tag => messages.filter(message => message.includes(tag)).length;
async function waitFor(check, name) {
  const start = Date.now();
  while (!check() && Date.now() - start < 18000) {
    if (errors.length) throw Error(errors.join('\n'));
    await page.waitForTimeout(100);
  }
  if (!check()) throw Error('Missing ' + name);
}
async function shot(stage) { await page.screenshot({ path: path.join(shots, `demo-08-3d-v27-${stage}-${surface}.png`) }); }
async function checkPreview() {
  const png = PNG.sync.read(await page.screenshot());
  let paperPixels = 0, placeholderPixels = 0;
  for (let y=90; y<416; y++) for (let x=482; x<938; x++) {
    const i=(y*png.width+x)*4, r=png.data[i], g=png.data[i+1], b=png.data[i+2];
    if (r>160 && g>160 && b>130) paperPixels++;
    if (r>200 && g<50 && b>200) placeholderPixels++;
  }
  visual.push({ paperPixels, placeholderPixels });
  if (paperPixels<1500 || placeholderPixels>10) throw Error('3D preview missing paper or displaying placeholder');
}
try {
  await page.goto(base + '/builds/demo-08-3d-v27/index.html');
  await page.waitForFunction(() => !document.getElementById('status'), { timeout: 45000 });
  await page.locator('canvas').focus();
  await page.waitForTimeout(350);
  await shot('sheet');
  await page.mouse.click(195, 180);
  await page.mouse.click(195, 440);
  await waitFor(() => count('PAPER|fold|') >= 1, 'manual fold');
  await page.waitForTimeout(280);
  await shot('folding');
  await page.waitForTimeout(650);
  await page.mouse.click(380, 485);
  await waitFor(() => count('PAPER|undo|') >= 1, 'undo');
  await page.mouse.click(560, 485);
  await waitFor(() => count('PAPER|fold|') >= 6, 'five-step dart');
  await page.waitForTimeout(900);
  await shot('dart');
  await checkPreview();
  await page.mouse.click(175, 485);
  await page.keyboard.press('ArrowUp');
  await page.keyboard.down('Space');
  await page.waitForTimeout(1250);
  await page.keyboard.up('Space');
  await waitFor(() => count('PAPER|launch|') >= 1, 'launch');
  await page.waitForTimeout(750);
  await shot('flight');
  await waitFor(() => count('PAPER|land|') >= 1, 'landing');
  await shot('land');
  await page.mouse.click(880,24);
  await waitFor(() => messages.some(m=>m.includes('PAPER|menu|levels=5')), 'five-level menu');
  await shot('menu');
  await page.mouse.click(216,216);
  for (let i=1; i<=5; i++) {
    await waitFor(() => messages.some(m=>m.includes(`PAPER|level|${i}|practice=false`)), `level ${i}`);
    const foldCount = count('PAPER|fold|'), launchCount = count('PAPER|launch|');
    await page.mouse.click(560,485);
    await waitFor(() => count('PAPER|fold|')>=foldCount+5, `level ${i} folds`);
    await page.waitForTimeout(1100);
    await page.mouse.click(175,485);
    await page.keyboard.down('Space');
    await page.waitForTimeout(1300);
    await page.keyboard.up('Space');
    await waitFor(() => count('PAPER|launch|')>launchCount, `level ${i} launch`);
    await waitFor(() => messages.some(m=>m.includes(`PAPER|course|${i}|pass=true`)), `level ${i} cleared`);
    await page.mouse.click(360,385);
  }
  await waitFor(() => messages.some(m=>m.includes('PAPER|final|levels=5')), 'five-level final screen');
  await shot('final');
  passed = errors.length === 0;
} finally {
  await browser.close();
  const result = { verifiedAt: new Date().toISOString(), base, build: 'demo-08-3d-v27', passed, visual, telemetry: messages.filter(message => message.includes('PAPER|')), errors };
  writeFileSync(path.join(root, `reviews/demo08-physical-browser-${surface}.json`), JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify(result, null, 2));
}
process.exitCode = passed ? 0 : 1;
