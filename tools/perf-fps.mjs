// 阶段 C/D 验收项：Web 实测帧率（Edge headless，浏览器自合成，无窗口）。
// 经典/风暴各采样 15s rAF；采集 GPU 字符串、视口分辨率；配合 build.json 体积入账。
// 用法: node tools/perf-fps.mjs <buildURL> <outdir>
// 说明：headless 渲染可能走软件 GL，数据偏保守——作为同机可比基线，不做绝对性能结论。
import { chromium } from 'playwright-core';
import os from 'node:os';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const url = process.argv[2];
const outdir = path.join(ROOT, process.argv[3] || 'reports');
if (!url) {
	console.error('用法: node tools/perf-fps.mjs <buildURL> <outdir>');
	process.exit(1);
}

const sample = (page, ms) => page.evaluate((dur) => new Promise((res) => {
	let n = 0;
	let worst = 0;
	let last = performance.now();
	const t0 = last;
	function f(now) {
		const gap = now - last;
		if (gap > worst) worst = gap;
		last = now;
		n += 1;
		if (now - t0 < dur) requestAnimationFrame(f);
		else res({ fps: n / ((now - t0) / 1000), worstGapMs: worst });
	}
	requestAnimationFrame(f);
}), ms);

const browser = await chromium.launch({ channel: 'msedge', headless: true });
const result = { url, viewport: '1280x720', when: new Date().toISOString(), host: os.hostname(), cpu: os.cpus()[0].model, modes: {} };
try {
	const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
	await page.goto(url, { waitUntil: 'load', timeout: 90000 });
	await page.waitForSelector('canvas', { timeout: 90000 });
	await page.waitForTimeout(15000);
	result.gpu = await page.evaluate(() => {
		const c = document.createElement('canvas');
		const gl = c.getContext('webgl2') || c.getContext('webgl');
		if (!gl) return 'no-webgl';
		const ext = gl.getExtension('WEBGL_debug_renderer_info');
		return ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER);
	});
	for (const [mode, btnX] of [['classic', 385 / 960], ['storm', 575 / 960]]) {
		await page.reload({ waitUntil: 'load', timeout: 90000 });
		await page.waitForSelector('canvas', { timeout: 90000 });
		await page.waitForTimeout(15000);
		const box = await (await page.$('canvas')).boundingBox();
		await page.mouse.click(box.x + box.width * btnX, box.y + box.height * 325 / 540);
		await page.waitForTimeout(3000);
		const r = await sample(page, 15000);
		result.modes[mode] = { avgFps: Math.round(r.fps * 10) / 10, worstFrameMs: Math.round(r.worstGapMs) };
		console.log(mode, JSON.stringify(result.modes[mode]));
	}
} finally {
	await browser.close();
}
const out = path.join(outdir, 'perf-fps-v12.json');
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, JSON.stringify(result, null, 2) + '\n');
console.log('GPU:', result.gpu);
console.log('已写入', out);
