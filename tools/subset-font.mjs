// 字体子集化：扫描 game/**/*.gd 的全部唯一字符 + ASCII + 常用标点，
// 用 subset-font 把 game/fonts/NotoSansSC.ttf 裁成子集（原文件备份为 .full.ttf）。
// 用法：node tools/subset-font.mjs [--restore]
// 安全网：子集覆盖所有 .gd 字符串字面量里的字符（demo 文本全部住在 .gd 表里）；
// 若未来新增了 .gd 里没有的显示字符（如外部数据驱动文本），重跑本脚本即可。
import fs from 'node:fs';
import path from 'node:path';
import subsetFont from 'subset-font';

const ROOT = path.join(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')), '..');
const GAME = path.join(ROOT, 'game');
const FONT = path.join(GAME, 'fonts', 'NotoSansSC.ttf');
const BACKUP = path.join(ROOT, "assets-backup-fonts", "NotoSansSC.full.ttf");

function walk(dir, ext, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (e.name === '.godot' || e.name === 'addons') continue;
      walk(p, ext, out);
    } else if (e.name.endsWith(ext)) out.push(p);
  }
  return out;
}

if (process.argv.includes('--restore')) {
  fs.copyFileSync(BACKUP, FONT);
  console.log('restored full font from', BACKUP);
  process.exit(0);
}

if (!fs.existsSync(BACKUP)) fs.copyFileSync(FONT, BACKUP); // 首次运行备份全量字体
const source = BACKUP; // 永远从全量备份裁，避免二次子集化丢字

// 1. 收集字符集
const chars = new Set();
for (let c = 32; c <= 126; c++) chars.add(String.fromCharCode(c)); // ASCII 全量
for (const c of '，。！？：；「」『』（）《》——…·、×+%°©®™✓↑↓←→①②③④⑤⑥⑦⑧⑨⑩℃') chars.add(c); // 常用符号兜底
for (const f of walk(GAME, '.gd')) {
  const t = fs.readFileSync(f, 'utf8');
  for (const ch of t) chars.add(ch);
}
const text = [...chars].join('');
console.log('unique chars:', chars.size);

// 2. 子集化（woff2 目标格式不行——Godot 要 ttf/otf，subset-font 支持 targetFormat ttf？其默认输出 woff2；
//    指定 targetFormat: 'sfnt' 得到 ttf 容器）
const subset = await subsetFont(fs.readFileSync(source), text, { targetFormat: 'sfnt' });
fs.writeFileSync(FONT, subset);
console.log('font subset written:', FONT, subset.length, 'bytes (full:', fs.statSync(BACKUP).size, 'bytes)');
