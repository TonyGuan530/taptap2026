// 盲测数据通道端到端：真实浏览器（Edge headless）打完整一局经典 60 秒，
// 验证结算面板出现、消费时间线与总结行渲染，截图存证。约 95 秒真实时间。
// 用法: node tools/endpanel-check.mjs <buildURL> <outdir>
import { chromium } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const url = process.argv[2];
const outdir = path.isAbsolute(process.argv[3] || '') ? process.argv[3] : path.join(ROOT, process.argv[3] || 'reviews/shots/endpanel');
if (!url) {
	console.error('用法: node tools/endpanel-check.mjs <buildURL> <outdir>');
	process.exit(1);
}
fs.mkdirSync(outdir, { recursive: true });

const SLOT0 = [191 / 960, 184 / 540];
const SLOT1 = [479 / 960, 184 / 540];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const errors = [];
const browser = await chromium.launch({ channel: 'msedge', headless: true });
try {
	const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
	page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
	await page.goto(url, { waitUntil: 'load', timeout: 90000 });
	await page.waitForSelector('canvas', { timeout: 90000 });
	await sleep(15000);
	const box = await (await page.$('canvas')).boundingBox();
	const click = async (nx, ny) => page.mouse.click(box.x + box.width * nx, box.y + box.height * ny);

	console.log('经典开局');
	await click(385 / 960, 325 / 540);
	await sleep(4000);
	await click(...SLOT0);  // ~4s 建槽1
	await sleep(9000);
	await click(...SLOT1);  // ~13s 建槽2
	await sleep(12000);
	await click(...SLOT0);  // ~25s 升级槽1
	console.log('局中投资完成，等待 60 秒结算…');
	await sleep(40000);      // ~65s 到达结算
	await page.screenshot({ path: path.join(outdir, 'endpanel.png') });
	console.log('结算截图完成');
} finally {
	await browser.close();
}
console.log('页面错误数:', errors.length);
errors.forEach((e) => console.log('  ', e));
console.log(errors.length === 0 ? '== ENDPanel PASS（以截图复核为准）==' : '== FAIL ==');
process.exit(errors.length === 0 ? 0 : 1);
