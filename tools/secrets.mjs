// 读取本机 data/secrets.json 里保存的 Key（由 Review 站 /key 页写入）
// 用法：import { getSecret } from './secrets.mjs';  getSecret('miro')
// itch 的 Key 历史上存在 'latest' 字段，这里做了兼容。
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const FILE = path.join(ROOT, 'data', 'secrets.json');

export function getSecret(slot) {
  try {
    const j = JSON.parse(fs.readFileSync(FILE, 'utf8'));
    if (slot === 'itch') return (j.latest || j.itch || {}).value || '';
    return (j[slot] || {}).value || '';
  } catch {
    return '';
  }
}
