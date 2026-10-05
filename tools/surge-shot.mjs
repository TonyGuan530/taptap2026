// 涌潮视觉证据：经典局推进到 34~42s 涌潮窗，抓「推进中」与「退潮后」对比帧。
// 用法: node tools/surge-shot.mjs <buildURL> <outdir>
import { chromium } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const url = process.argv[2];
const outdir = path.isAbsolute(process.argv[3] || '') ? process.argv[3] : path.join(ROOT, process.argv[3] || 'reviews/shots/surge');
if (!url) {
	console.error('用法: node tools/surge-shot.mjs <buildURL> <outdir>');
	process.exit(1);
}
fs.mkdirSync(outdir, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const browser = await chromium.launch({ channel: 'msedge', headless: true });
try {
	const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
	await page.goto(url, { waitUntil: 'load', timeout: 90000 });
	await page.waitForSelector('canvas', { timeout: 90000 });
	await sleep(15000);
	const box = await (await page.$('canvas')).boundingBox();
	await page.mouse.click(box.x + box.width * 385 / 960, box.y + box.height * 325 / 540);
	console.log('经典开局');
	await sleep(8000);
	await page.keyboard.press('1');  // ~4+ 游戏秒建槽1（键盘通道；水滴恰好 20 时可能差一点）
	await sleep(3000);
	await page.keyboard.press('1');  // 重试建造（已建则静默失败，无害）
	console.log('已建槽1，等待涌潮…');
	await sleep(38000);  // headless 游戏时约 0.6 倍：至 ~30 游戏秒（预警期）
	await page.screenshot({ path: path.join(outdir, 'surge-warn.png') });
	await sleep(13000);   // ~37 游戏秒：推进中
	await page.screenshot({ path: path.join(outdir, 'surge-active.png') });
	await sleep(20000);   // ~48 游戏秒：退潮后
	await page.screenshot({ path: path.join(outdir, 'surge-receded.png') });
	console.log('三帧完成');
} finally {
	await browser.close();
}
