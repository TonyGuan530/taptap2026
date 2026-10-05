// 触屏可玩性检查（TapTap 受众手机优先）：hasTouch 上下文真实 tap 菜单按钮 → 进入对局 → tap 槽位建造 → 截图。
// Godot Web 默认 emulate_mouse_from_touch=true，tap 应映射为点击；此工具实证该链路。
// 用法: node tools/touch-check.mjs <buildURL> <outdir>
import { chromium } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const url = process.argv[2];
const outdir = path.isAbsolute(process.argv[3] || '') ? process.argv[3] : path.join(ROOT, process.argv[3] || 'reviews/shots/touch');
if (!url) {
	console.error('用法: node tools/touch-check.mjs <buildURL> <outdir>');
	process.exit(1);
}
fs.mkdirSync(outdir, { recursive: true });

const errors = [];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// 手机横屏玩法：812×375（iPhone 横屏级）+ hasTouch
const browser = await chromium.launch({ channel: 'msedge', headless: true });
const context = await browser.newContext({
	viewport: { width: 812, height: 375 },
	hasTouch: true,
	isMobile: true,
	deviceScaleFactor: 2,
});
const page = await context.newPage();
try {
	page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
	await page.goto(url, { waitUntil: 'load', timeout: 90000 });
	await page.waitForSelector('canvas', { timeout: 90000 });
	await page.waitForTimeout(15000);
	await page.screenshot({ path: path.join(outdir, 'touch-menu.png') });

	const canvas = await page.$('canvas');
	const box = await canvas.boundingBox();
	if (!box) throw new Error('canvas 无 boundingBox');
	console.log(`canvas ${Math.round(box.width)}x${Math.round(box.height)} @ (${Math.round(box.x)},${Math.round(box.y)})`);

	// 设计 960×540 等比缩放 + keep 居中：算内容区偏移
	const scale = Math.min(box.width / 960, box.height / 540);
	const offX = (box.width - 960 * scale) / 2;
	const offY = (box.height - 540 * scale) / 2;
	const tapAt = async (nx, ny, name) => {
		const x = box.x + offX + 960 * scale * nx;
		const y = box.y + offY + 540 * scale * ny;
		await page.touchscreen.tap(x, y);
		console.log(`tap ${name} @ (${Math.round(x)},${Math.round(y)})`);
		await sleep(1200);
	};

	console.log('tap 经典 60 秒');
	await tapAt(385 / 960, 325 / 540, '经典');
	await sleep(6000);
	await page.screenshot({ path: path.join(outdir, 'touch-classic-play.png') });

	await tapAt(191 / 960, 184 / 540, '槽位1');  // 世界拾取也吃触屏
	await sleep(2500);
	await page.screenshot({ path: path.join(outdir, 'touch-build.png') });
} finally {
	await context.close();
	await browser.close();
}
console.log('页面错误数:', errors.length);
errors.forEach((e) => console.log('  ', e));
console.log(errors.length === 0 ? '== TOUCH PASS（以截图复核为准）==' : '== FAIL ==');
process.exit(errors.length === 0 ? 0 : 1);
