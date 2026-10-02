// 把各 demo 的运行截图 + 录屏链接贴到 Miro 看板对应想法旁
// 用法：node tools/miro-post-shots.mjs [--force]   （--force 重复贴，默认按 sticker 锚点去重）
// Token/看板 ID 存在 data/secrets.json（/key 页）。零依赖，Node 18+。
// 注：此看板的 API 不支持直接创建图片/视频组件，配方 = sticker 锚点 + card 标题 + text 链接。
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getSecret } from './secrets.mjs';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const API = 'https://api.miro.com/v1';
const token = getSecret('miro');
const board = getSecret('miro_board') || process.env.MIRO_BOARD;
if (!token || !board) {
	console.log('SKIP: 缺 Miro Token 或看板 ID（/key 页保存）');
	process.exit(2);
}
const BOARD = encodeURIComponent(board);
const force = process.argv.includes('--force');
const RAW = 'https://raw.githubusercontent.com/TonyGuan530/taptap2026/main';

const SHOTS = [
	{ id: 'demo-01', name: '灵感菇侦探', img: 'demo-01.png', video: 'demo-01.mp4', x: 6300, y: 2560, done: true },
	{ id: 'demo-05', name: '恐龙火山生存', img: 'demo-05.png', video: 'demo-05.mp4', x: 4400, y: 4560 },
	{ id: 'demo-02', name: '物性变换谜题', img: 'demo-02.png', video: 'demo-02.mp4', x: 4400, y: 6560 },
	{ id: 'demo-03', name: '岩浆降温的小人国度', img: 'demo-03.png', video: 'demo-03.mp4', x: 4400, y: 8460 },
	{ id: 'demo-04', name: 'SOUP 2.0 DNA 融合逃生', img: 'demo-04.png', video: 'demo-04.mp4', x: 4400, y: 10560 },
	{ id: 'demo-07', name: '简单美食小摊（绿幕版）', img: 'demo-07.png', video: 'demo-07.mp4', x: 4400, y: 11760 },
];

async function miro(method, url, body) {
	const r = await fetch(url, {
		method,
		headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
		body: body ? JSON.stringify(body) : undefined,
	});
	if (!r.ok) throw new Error(`${method} ${url} → ${r.status}: ${(await r.text()).slice(0, 150)}`);
	return r.status === 204 ? {} : r.json();
}

async function postShot(s) {
	const imgUrl = `${RAW}/reviews/shots/${s.img}`;
	const vidUrl = `${RAW}/reviews/videos/${s.video}`;
	await miro('POST', `${API}/boards/${BOARD}/widgets`, {
		type: 'sticker', text: `🎮 ${s.id} 运行画面 + 录屏 ▼`, x: s.x, y: s.y,
	});
	await miro('POST', `${API}/boards/${BOARD}/widgets`, {
		type: 'card', title: `🎮 ${s.id} ${s.name}`, x: s.x, y: s.y + 140,
	});
	await miro('POST', `${API}/boards/${BOARD}/widgets`, {
		type: 'text',
		text: `截图: ${imgUrl}\n录屏: ${vidUrl}\n试玩: https://sxguan.itch.io/taptap2026 （密码 taptap）`,
		x: s.x, y: s.y + 300, width: 480,
	});
	console.log(`OK ${s.id} 已贴到 (${s.x}, ${s.y})`);
}

let posted = 0;
for (const s of SHOTS) {
	if (!force && s.done) {
		console.log(`SKIP ${s.id}: 之前已贴（--force 可重贴）`);
		continue;
	}
	if (!force) {
		// 去重：看板上已有同 id 的 sticker 就跳过
		let dup = false;
		try {
			const list = await miro('GET', `${API}/boards/${BOARD}/widgets?type=sticker`);
			dup = (list.data || []).some((w) => JSON.stringify(w.data || {}).includes(`${s.id} 运行画面`));
		} catch { /* 列不出来就直接贴 */ }
		if (dup) {
			console.log(`SKIP ${s.id}: 看板上已贴过`);
			continue;
		}
	}
	const imgPath = path.join(ROOT, 'reviews', 'shots', s.img);
	const vidPath = path.join(ROOT, 'reviews', 'videos', s.video);
	if (!fs.existsSync(imgPath) || !fs.existsSync(vidPath)) {
		console.log(`SKIP ${s.id}: 缺截图或录屏文件`);
		continue;
	}
	await postShot(s);
	posted++;
}
console.log(`完成：新贴 ${posted} 个`);
