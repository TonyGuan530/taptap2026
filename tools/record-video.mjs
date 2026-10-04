// v12 实玩视频录制（Edge headless + Playwright recordVideo）：
// 浏览器自合成帧，无窗口、不占鼠标、非屏幕录制（合规替代 Movie Maker 弹窗方案）。
// 流程：加载构建 → 经典模式脚本化实玩（建造/升级/F 指挥/酸雨）→ 重开进风暴（细雨+酸雨）→ 关闭生成 webm。
// 产物：reviews/videos/demo-03-3d.webm（用 ffmpeg 转 mp4）。
// 用法: node tools/record-video.mjs <buildURL> <outdir>
import { chromium } from 'playwright-core';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const url = process.argv[2];
const outdir = path.isAbsolute(process.argv[3] || '') ? process.argv[3] : path.join(ROOT, process.argv[3] || 'reviews/videos');
if (!url) {
	console.error('用法: node tools/record-video.mjs <buildURL> <outdir>');
	process.exit(1);
}

// 设计 960×540 归一化坐标：三槽位中心 + 经典/风暴按钮
const SLOT = [[191 / 960, 184 / 540], [479 / 960, 184 / 540], [767 / 960, 184 / 540]];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const browser = await chromium.launch({ channel: 'msedge', headless: true });
const context = await browser.newContext({
	viewport: { width: 1280, height: 720 },
	recordVideo: { dir: outdir, size: { width: 1280, height: 720 } },
});
const page = await context.newPage();
try {
	console.log('加载', url);
	await page.goto(url, { waitUntil: 'load', timeout: 90000 });
	await page.waitForSelector('canvas', { timeout: 90000 });
	await sleep(15000); // 启动 + 菜单
	const canvas = await page.$('canvas');
	const box = await canvas.boundingBox();
	const click = async (nx, ny) => {
		await page.mouse.click(box.x + box.width * nx, box.y + box.height * ny);
	};
	console.log('经典模式开局');
	await click(385 / 960, 325 / 540);
	await sleep(4000);
	await click(SLOT[0][0], SLOT[0][1]);   // ~4s 建槽1
	await sleep(9000);
	await click(SLOT[1][0], SLOT[1][1]);   // ~13s 建槽2
	await sleep(12000);                     // 20s 村民、22s 酸雨
	await click(SLOT[0][0], SLOT[0][1]);   // ~25s 升级槽1
	await sleep(8000);
	await page.keyboard.press('F');        // ~33s 灭火指挥
	console.log('经典段完成（40s）');
	await sleep(7000);
	// 风暴之夜段
	await page.reload({ waitUntil: 'load', timeout: 90000 });
	await page.waitForSelector('canvas', { timeout: 90000 });
	await sleep(15000);
	console.log('风暴之夜开局');
	await click(575 / 960, 325 / 540);
	await sleep(8000);
	await click(SLOT[0][0], SLOT[0][1]);   // 建槽1（细雨背景）
	await sleep(9000);                      // 15s±2 酸雨（紫雨+细雨叠加）
	console.log('风暴段完成');
	await sleep(3000);
} finally {
	await context.close(); // 落盘 webm
	await browser.close();
}
console.log('webm 已生成于', outdir);
