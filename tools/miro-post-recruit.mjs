// 把 demo-05 HD-2D 真人空间学习测试招募贴到 Miro 看板（督导 KEEP 最后 Gate 的排期入口）
// 用法：node tools/miro-post-recruit.mjs   （Token/看板 ID 存 data/secrets.json）
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getSecret } from './secrets.mjs';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const API = 'https://api.miro.com/v1';
const token = getSecret('miro');
const board = getSecret('miro_board') || process.env.MIRO_BOARD;
if (!token || !board) {
	console.log('SKIP: 缺 Miro Token 或看板 ID');
	process.exit(2);
}
const BOARD = encodeURIComponent(board);
const RAW = 'https://raw.githubusercontent.com/TonyGuan530/taptap2026/main';

async function miro(method, url, body) {
	const r = await fetch(url, {
		method,
		headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
		body: body ? JSON.stringify(body) : undefined,
	});
	if (!r.ok) throw new Error(`${method} → ${r.status}: ${(await r.text()).slice(0, 150)}`);
	return r.status === 204 ? {} : r.json();
}

const LOG = path.join(ROOT, 'reviews', 'miro-post-log.json');
const log = fs.existsSync(LOG) ? JSON.parse(fs.readFileSync(LOG, 'utf8')) : {};
if (log['demo-05-hd2d-recruit'] && !process.argv.includes('--force')) {
	console.log('SKIP: 招募卡已贴过（--force 重贴）');
	process.exit(0);
}

const text = [
	'· 试玩（v6）：https://tonyguan530.github.io/taptap2026/builds/demo-05-hd2d-v6/index.html',
	'· 人数：2-3 人 × 至少 2 个夜晚 × 死亡后重开 ≥1 次（约 10 分钟/人）',
	'· 只给操作说明：WASD 移动 · E 交互 · Q 吃 · R 喝 · B 建造（1/2/3 选型，E 放置）· Enter 重开',
	`· 记录单：${RAW}/reviews/human-test-demo05-hd2d-template.md`,
	'· 判定：2/3 人在无提示下根据上一夜世界反馈主动改变建窝位置/路线 → 督导给 KEEP',
	'· 勿剧透：不解释预报/灰潮/泥流机制，让玩家自己从世界反馈形成规则',
].join('\n');

await miro('POST', `${API}/boards/${BOARD}/widgets`, {
	type: 'card', title: '📢 demo-05 HD-2D 招募：真人空间学习测试（KEEP 最后 Gate）', x: 5400, y: 5480,
});
await miro('POST', `${API}/boards/${BOARD}/widgets`, {
	type: 'text', text, x: 5400, y: 5620, width: 480,
});
log['demo-05-hd2d-recruit'] = { postedAt: new Date().toISOString(), x: 5400, y: 5480 };
fs.writeFileSync(LOG, JSON.stringify(log, null, 2));
console.log('OK: 招募卡已贴到 (5400, 5480)');
