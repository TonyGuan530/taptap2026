// 导出内容核对（指南 §C：历史出现过并发导出串台，导出后必查）
// 用法：node tools/verify-pck-demo04-3d.mjs builds/demo-04-3d-vN
import fs from 'node:fs';
const dir = process.argv[2];
if (!dir || !fs.existsSync(`${dir}/index.pck`)) { console.error(`用法: node tools/verify-pck-demo04-3d.mjs <builds/demo-04-3d-vN>`); process.exit(2); }
const s = fs.readFileSync(`${dir}/index.pck`).toString('latin1');
const i = s.indexOf('run/main_scene');
const main = s.slice(i, i + 80);
const checks = [
  [`main_scene 指向 demo04_3d.tscn`, main.includes('res://demo04_3d.tscn')],
  [`含 demo04_3d/root.gd`, s.includes('demo04_3d/root.gd')],
  [`含 demo04_3d/player.gd`, s.includes('demo04_3d/player.gd')],
];
let bad = 0;
for (const [name, ok] of checks) { console.log(`${ok ? 'OK  ' : 'FAIL'} ${name}`); if (!ok) bad++; }
if (bad > 0) process.exit(1);
const meta = JSON.parse(fs.readFileSync(`${dir}/build.json`, 'utf8'));
console.log(`build.json version=${meta.version}`);
console.log('PCK 校验通过');
