// 一次性清理：删除 Miro 板上 demo-04 的旧「运行画面」贴纸与旧截图/录屏链接文本（保留原始想法卡片）
// 用法：node tools/_miro_cleanup_demo04.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getSecret } from './secrets.mjs';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const API = 'https://api.miro.com/v1';
const token = getSecret('miro');
const board = getSecret('miro_board') || process.env.MIRO_BOARD;
const BOARD = encodeURIComponent(board);

async function miro(method, url, body) {
	const r = await fetch(url, {
		method,
		headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
		body: body ? JSON.stringify(body) : undefined,
	});
	if (!r.ok && r.status !== 204) throw new Error(`${method} ${url} → ${r.status}: ${(await r.text()).slice(0, 120)}`);
	return r.status === 204 ? {} : r.json();
}

const all = await miro('GET', `${API}/boards/${BOARD}/widgets?limit=500`);
const items = all.data || [];
const victims = items.filter((w) => {
	if (w.type === 'sticker' && (w.data || {}).content && w.data.content.includes('demo-04 运行画面')) return true;
	if (w.type === 'text' && (w.data || {}).content && w.data.content.includes('shots/demo-04')) return true;
	return false;
});
console.log(`待删除 ${victims.length} 个旧件：`);
for (const w of victims) {
	console.log(`  ${w.id} ${w.type} @(${w.geometry?.x ?? '?'},${w.geometry?.y ?? '?'}) :: ${String((w.data || {}).content || (w.data || {}).title || '').slice(0, 60)}`);
}
for (const w of victims) {
	await miro('DELETE', `${API}/boards/${BOARD}/widgets/${w.id}`);
	console.log(`DELETED ${w.id}`);
}
console.log('清理完成');
