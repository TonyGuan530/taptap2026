// 阶段 D 收尾：Hub/iframe/build.json 一致性冒烟（Edge headless，无窗口）。
// 流程：Hub 首页 → 校验 demos.json 里 demo-03 的 buildId → 点击对应卡片 →
// play.html 的 iframe src 应指向同版本构建 → iframe 内 canvas 完成启动 → 截图。
// 用法: node tools/hub-smoke.mjs <hubURL> <expectBuildId> <outdir>
// 例:   node tools/hub-smoke.mjs https://tonyguan530.github.io/taptap2026/ demo-03-3d-v11 reviews/shots/hub-smoke-v11
// 退出码: 0=PASS（卡片存在/iframe 指向一致/启动无页面错误），1=FAIL。
import { chromium } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const hub = process.argv[2];
const expectId = process.argv[3];
const outdir = path.isAbsolute(process.argv[4] || '') ? process.argv[4] : path.join(ROOT, process.argv[4] || 'reviews/shots/hub-smoke');
if (!hub || !expectId) {
	console.error('用法: node tools/hub-smoke.mjs <hubURL> <expectBuildId> <outdir>');
	process.exit(1);
}

const errors = [];
const problems = [];
fs.mkdirSync(outdir, { recursive: true });
const browser = await chromium.launch({ channel: 'msedge', headless: true });
try {
	const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
	page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
	page.on('console', (m) => {
		// "Failed to load resource" 是浏览器对 404 响应的重复记录（真实判定在 response 监听里）
		if (m.type() === 'error' && !m.text().includes('Failed to load resource')) {
			errors.push('console.error: ' + m.text());
		}
	});
	page.on('response', (r) => {
		// /api/* 是本地 Review 站的动态接口，GitHub Pages 静态托管上必然 404（play.js 优雅回退，非缺陷）
		if (r.status() === 404 && !r.url().includes('/api/')) errors.push('404: ' + r.url());
	});

	console.log('加载 Hub', hub);
	await page.goto(hub, { waitUntil: 'load', timeout: 90000 });
	await page.waitForSelector('.card.slot', { timeout: 30000 });

	// demos.json 一致性：demo-03 槽位 buildId 应为期望版本，且该构建有简介
	const d03 = await page.evaluate(async () => {
		const r = await fetch('demos.json');
		const j = await r.json();
		const s = (j.slots || []).find((x) => x.id === 'demo-03');
		return s ? { buildId: s.buildId, status: s.status } : null;
	});
	console.log('demos.json demo-03 →', JSON.stringify(d03));
	if (!d03 || d03.buildId !== expectId) problems.push(`demos.json demo-03 buildId=${d03 && d03.buildId} 期望 ${expectId}`);

	// 卡片存在且指向 play.html?id=<expectId>
	const cardHref = await page.evaluate((id) => {
		const el = document.querySelector(`.card.slot[href*="play.html?id=${encodeURIComponent(id)}"]`);
		return el ? el.getAttribute('href') : null;
	}, expectId);
	if (!cardHref) {
		problems.push(`Hub 首页没有指向 ${expectId} 的 demo-03 卡片`);
	} else {
		console.log('卡片链接:', cardHref);
		await page.screenshot({ path: path.join(outdir, 'hub-cards.png') });
	}

	// 点击进入 play 页 → iframe src 一致性（play.js 异步设置 src，先等它非空）
	await page.click(`.card.slot[href*="play.html?id=${encodeURIComponent(expectId)}"]`);
	await page.waitForSelector('#game', { timeout: 30000 });
	await page.waitForFunction(() => {
		const g = document.getElementById('game');
		return g && g.src && g.src.includes('builds/');
	}, { timeout: 30000 });
	const frameSrc = await page.evaluate(() => document.getElementById('game').src);
	console.log('iframe src:', frameSrc);
	if (!frameSrc.includes(`builds/${expectId}/index.html`)) problems.push(`iframe src=${frameSrc} 与 ${expectId} 不一致`);

	// iframe 内 Godot 启动（canvas 出现 + 等待首帧）
	const frame = page.frameLocator('#game');
	await frame.locator('canvas').waitFor({ timeout: 90000 });
	await page.waitForTimeout(15000);
	await page.screenshot({ path: path.join(outdir, 'play-loaded.png') });
	console.log('play 页截图完成（含已启动的游戏）');
} finally {
	await browser.close();
}

console.log('页面错误数:', errors.length);
errors.slice(0, 8).forEach((e) => console.log('  ', e));
console.log('一致性问题:', problems.length);
problems.forEach((p) => console.log('  ', p));
const pass = errors.length === 0 && problems.length === 0;
console.log(pass ? '== HUB SMOKE PASS ==' : '== HUB SMOKE FAIL ==');
process.exit(pass ? 0 : 1);
