// 从 Miro 看板拉取成员的想法，写入 requirements/miro-export.md
// 用法：node tools/miro-fetch.mjs [看板ID]
//   看板ID 也可以存在 /key 页（miro_board）或环境变量 MIRO_BOARD
// Token 存在 /key 页（miro）。零依赖，Node 18+。
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getSecret } from './secrets.mjs';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = path.join(ROOT, 'requirements', 'miro-export.md');

const token = getSecret('miro');
if (!token) {
  console.log('SKIP: 未保存 Miro Token（打开 Review 站 /key 页保存后重试）');
  process.exit(2);
}
const board = process.argv[2] || process.env.MIRO_BOARD || getSecret('miro_board');
if (!board) {
  console.log('SKIP: 未提供 Miro 看板 ID（用法: node tools/miro-fetch.mjs <boardId>，或在 /key 页保存看板 ID）');
  process.exit(2);
}

const headers = { Authorization: `Bearer ${token}` };

// 先试 v1 widgets（带 text 字段，最好用），不行再退 v2 items
async function fetchV1() {
  const items = [];
  let offset = 0;
  for (;;) {
    const r = await fetch(`https://api.miro.com/v1/boards/${board}/widgets?size=100&offset=${offset}`, { headers });
    if (r.status === 401 || r.status === 403) throw new Error('Miro Token 无效或权限不足（401/403）');
    if (r.status === 404) throw new Error('NOT_FOUND');
    if (!r.ok) throw new Error(`Miro API v1 出错: ${r.status}`);
    const d = await r.json();
    items.push(...(d.data || []));
    const total = d.total ?? items.length;
    offset += (d.size || 100);
    if (!d.data || d.data.length === 0 || items.length >= total) break;
  }
  return items.map((w) => ({
    type: w.type || 'widget',
    x: w.x ?? 0,
    y: w.y ?? 0,
    text: w.text || w.title || w.data?.text || w.data?.content || '',
  }));
}

async function fetchV2() {
  const items = [];
  let cursor = '';
  for (;;) {
    const url = `https://api.miro.com/v2/boards/${board}/items?limit=50${cursor ? '&cursor=' + encodeURIComponent(cursor) : ''}`;
    const r = await fetch(url, { headers });
    if (r.status === 401 || r.status === 403) throw new Error('Miro Token 无效或权限不足（401/403）');
    if (!r.ok) throw new Error(`Miro API v2 出错: ${r.status}`);
    const d = await r.json();
    for (const it of d.data || []) {
      items.push({
        type: it.type || 'item',
        x: it.position?.x ?? 0,
        y: it.position?.y ?? 0,
        text: it.data?.content || it.data?.title || it.data?.text || '',
      });
    }
    cursor = d.cursor || '';
    if (!cursor || !(d.data || []).length) break;
  }
  return items;
}

let widgets;
try {
  widgets = await fetchV1();
} catch (e) {
  if (e.message === 'NOT_FOUND') {
    widgets = await fetchV2();
  } else {
    throw e;
  }
}

const usable = widgets.filter((w) => String(w.text).trim());
if (!usable.length) {
  console.log(`WARN: 看板 ${board} 上没有可读的文本内容（共 ${widgets.length} 个对象）`);
  process.exit(1);
}
usable.sort((a, b) => a.y - b.y || a.x - b.x);

const lines = [
  `# Miro 导出：看板 ${board}`,
  '',
  `> 拉取时间：${new Date().toLocaleString('zh-CN')} · 共 ${usable.length} 条内容（按 纵向→横向 排序）`,
  '> 请把有用的想法整理进 requirements/backlog.md（每个玩法块一节，## demo-0X 开头）',
  '',
];
for (const w of usable) {
  lines.push(`### [${w.type}] @(${Math.round(w.x)},${Math.round(w.y)})`);
  lines.push('');
  lines.push(String(w.text).trim());
  lines.push('');
}
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, lines.join('\n'));
console.log(`OK: 已拉取 ${usable.length} 条内容 → requirements/miro-export.md`);
