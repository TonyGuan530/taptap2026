// 把 Miro Feedback Slide 的修复结果标注贴回看板（看板要求"如果完成请自己标注"）
// 用法：node tools/miro-post-feedback-note.mjs   （按本地日志去重，可加 --force 重贴）
// Token/看板 ID 存在 data/secrets.json。零依赖，Node 18+。
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

// 标注内容与位置：贴在 Feedback Slide 三问题贴纸 (-334,-12) 正下方
const NOTE = {
	id: 'feedback-note-2026-10-03',
	x: -334, y: 150, width: 560,
	text: [
		'✅ AL 修复标注（2026-10-03）：',
		'1. demo-02-v2 导出错位 → 已切 main_scene 重导，资源包即物性谜题 v2',
		'2. 物性谜题第二关缺入口 → 已加「下一关」按钮（通关后启用，末关变「从头再来」），L1/L2 回归 PASS',
		'3. demo-07 元数据 BOM → 导出脚本改无 BOM 写出，build.json 已修复',
		'注：itch 新构建部署故障持续（CDN 占位页），平台恢复后 demo-07 自动上线，届时按钮修复随下次发布带出。',
	].join('\n'),
};

async function miro(method, url, body) {
	const r = await fetch(url, {
		method,
		headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
		body: body ? JSON.stringify(body) : undefined,
	});
	if (!r.ok) throw new Error(`${method} ${url} → ${r.status}: ${(await r.text()).slice(0, 150)}`);
	return r.status === 204 ? {} : r.json();
}

const LOG = path.join(ROOT, 'reviews', 'miro-post-log.json');
const log = fs.existsSync(LOG) ? JSON.parse(fs.readFileSync(LOG, 'utf8')) : {};
if (!force && log[NOTE.id]) {
	console.log(`SKIP: 标注已贴过（--force 可重贴）`);
	process.exit(0);
}
await miro('POST', `${API}/boards/${BOARD}/widgets`, {
	type: 'text', text: NOTE.text, x: NOTE.x, y: NOTE.y, width: NOTE.width,
});
log[NOTE.id] = { postedAt: new Date().toISOString(), x: NOTE.x, y: NOTE.y };
fs.writeFileSync(LOG, JSON.stringify(log, null, 2));
console.log(`OK: 修复标注已贴到 (${NOTE.x}, ${NOTE.y})`);
