// 阶段 D headless 浏览器冒烟：Edge headless 实载构建 → 等待 Godot 启动 → 真实点击菜单三模式 → 抓页面错误 + 截图。
// 全程无窗口（headless），不占用户鼠标。
// 用法: node tools/browser-smoke.mjs <index.html URL> <outdir>
// 例:   node tools/browser-smoke.mjs https://tonyguan530.github.io/taptap2026/builds/demo-03-3d-v7/index.html ../reviews/shots/browser-smoke
// 退出码: 0=PASS（页面加载、canvas 启动、三次点击均无页面错误），1=FAIL。截图交人工/AI 复核画面。
import { chromium } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const url = process.argv[2];
const outdir = path.isAbsolute(process.argv[3] || '') ? process.argv[3] : path.join(ROOT, process.argv[3] || 'reviews/shots/browser-smoke');
if (!url) {
	console.error('用法: node tools/browser-smoke.mjs <index.html URL> <outdir>');
	process.exit(1);
}

const errors = [];
// 设计分辨率 960x540，视口同比例 1280x720 → 归一化坐标精确映射
const MODES = [
	{ name: 'classic', nx: 385 / 960, ny: 325 / 540, waitMs: 7000 },  // 经典 60 秒按钮中心
	{ name: 'storm', nx: 575 / 960, ny: 325 / 540, waitMs: 9000 },    // 风暴之夜按钮中心
	{ name: 'hard', nx: 765 / 960, ny: 325 / 540, waitMs: 9000 },     // 寒夜守卫按钮中心
];

const browser = await chromium.launch({ channel: 'msedge', headless: true });
try {
	const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
	page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
	page.on('console', (m) => {
		if (m.type() === 'error') errors.push('console.error: ' + m.text());
	});
	fs.mkdirSync(outdir, { recursive: true });

	console.log('加载', url);
	await page.goto(url, { waitUntil: 'load', timeout: 90000 });
	await page.waitForSelector('canvas', { timeout: 90000 });
	await page.waitForTimeout(15000); // 等 wasm+pck 实例化与首帧
	await page.screenshot({ path: path.join(outdir, '00-menu.png') });
	console.log('菜单截图完成');

	const canvas = await page.$('canvas');
	const box = await canvas.boundingBox();
	if (!box || box.width < 300) throw new Error('canvas 尺寸异常: ' + JSON.stringify(box));

	for (const m of MODES) {
		await page.reload({ waitUntil: 'load', timeout: 90000 });
		await page.waitForSelector('canvas', { timeout: 90000 });
		await page.waitForTimeout(15000);
		const x = box.x + box.width * m.nx;
		const y = box.y + box.height * m.ny;
		await page.mouse.click(x, y);
		console.log(`点击 ${m.name} @ (${Math.round(x)},${Math.round(y)})`);
		await page.waitForTimeout(m.waitMs);
		await page.screenshot({ path: path.join(outdir, `${m.name}-play.png`) });
		console.log(`${m.name} 截图完成`);
	}
} finally {
	await browser.close();
}

console.log('页面错误数:', errors.length);
errors.slice(0, 10).forEach((e) => console.log('  ', e));
console.log(errors.length === 0 ? '== SMOKE PASS ==' : '== SMOKE FAIL ==');
process.exit(errors.length === 0 ? 0 : 1);
