// 跨浏览器冒烟（Firefox）：加载构建 → 等启动 → 真实点击经典模式 → 截图。
// 用法: node tools/firefox-smoke.mjs <buildURL> <outdir>
import { firefox } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const url = process.argv[2];
const outdir = path.isAbsolute(process.argv[3] || '') ? process.argv[3] : path.join(ROOT, process.argv[3] || 'reviews/shots/firefox');
if (!url) {
	console.error('用法: node tools/firefox-smoke.mjs <buildURL> <outdir>');
	process.exit(1);
}
fs.mkdirSync(outdir, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const errors = [];

const browser = await firefox.launch({ headless: true });
try {
	const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
	page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
	page.on('console', (m) => {
		if (m.type() === 'error' && !m.text().includes('Failed to load resource')) errors.push('console.error: ' + m.text());
	});
	await page.goto(url, { waitUntil: 'load', timeout: 120000 });
	await page.waitForSelector('canvas', { timeout: 120000 });
	await sleep(18000); // Firefox 首次 wasm 编译更慢，多留余量
	await page.screenshot({ path: path.join(outdir, 'ff-menu.png') });
	const box = await (await page.$('canvas')).boundingBox();
	await page.mouse.click(box.x + box.width * 385 / 960, box.y + box.height * 325 / 540);
	console.log('点击 经典 60 秒');
	await sleep(8000);
	// v13 新取景下槽位1实际位置（从截图量得）：先用世界点击，再键盘兜底，两帧区分
	await page.mouse.click(box.x + box.width * 0.305, box.y + box.height * 0.632);
	console.log('点击 槽位1（新取景坐标）');
	await sleep(3500);
	await page.screenshot({ path: path.join(outdir, 'ff-worldclick.png') });
	await page.keyboard.press('1');
	console.log('键盘 1 兜底');
	await sleep(3000);
	await page.screenshot({ path: path.join(outdir, 'ff-play.png') });
	console.log('Firefox 对局截图完成');
} finally {
	await browser.close();
}
console.log('页面错误数:', errors.length);
errors.forEach((e) => console.log('  ', e));
console.log(errors.length === 0 ? '== FIREFOX PASS（以截图复核为准）==' : '== FAIL ==');
process.exit(errors.length === 0 ? 0 : 1);
