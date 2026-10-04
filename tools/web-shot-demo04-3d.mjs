// 无窗口 Web 出图：本地静态服务 + Edge headless 渲染 WebGL → PNG
// 用法：node tools/web-shot-demo04-3d.mjs [buildDir] [outPrefix] [ms虚拟时间, ...]
// 全程不开窗（用户红线）：--headless=new 由 Edge 无头合成器渲染，无窗口创建。
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn, execFileSync } from 'node:child_process';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')), '..');
const buildDir = path.resolve(ROOT, process.argv[2] || 'builds/demo-04-3d-v4');
const prefix = process.argv[3] || 'demo-04-3d';
const budgets = process.argv.slice(4).length ? process.argv.slice(4) : ['9000', '16000', '26000'];
let PORT = 0;   // 临时端口，防僵尸服务占用
const EDGE_CANDIDATES = [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
];
const edge = EDGE_CANDIDATES.find((p) => fs.existsSync(p));
if (!edge) { console.error('未找到 Edge'); process.exit(2); }

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json', '.svg': 'image/svg+xml', '.worklet.js': 'text/javascript' };
const server = http.createServer((req, res) => {
  const rel = decodeURIComponent(req.url.split('?')[0]).replace(/^\//, '') || 'index.html';
  const fp = path.join(buildDir, rel);
  if (!fp.startsWith(buildDir) || !fs.existsSync(fp) || fs.statSync(fp).isDirectory()) { res.writeHead(404); res.end('nf'); return; }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(fp)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp' });
  fs.createReadStream(fp).pipe(res);
});
await new Promise((r) => server.listen(PORT, '127.0.0.1', r));
PORT = server.address().port;
console.log('serving', buildDir, 'on', PORT);

const outDir = path.join(ROOT, 'reviews', 'shots');
fs.mkdirSync(outDir, { recursive: true });
let ok = 0;
for (const b of budgets) {
  const out = path.join(outDir, `${prefix}-web-t${b}.png`);
  const prof = path.join(process.env.TEMP || '.', 'edge-headless-' + b);
  const args = [
    '--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run',
    '--user-data-dir=' + prof,
    '--window-size=1280,720', `--screenshot=${out}`, `--virtual-time-budget=${b}`,
    `http://127.0.0.1:${PORT}/index.html`,
  ];
  try {
    execFileSync(edge, args, { stdio: 'ignore', timeout: 120000 });
    const sz = fs.existsSync(out) ? fs.statSync(out).size : 0;
    console.log(`${sz > 20000 ? 'OK  ' : 'FAIL'} t=${b}s -> ${path.basename(out)} (${Math.round(sz / 1024)}KB)`);
    if (sz > 20000) ok += 1;
  } catch (e) {
    console.log(`FAIL t=${b}s: ${String(e).slice(0, 80)}`);
  }
}
server.close();
console.log(`完成：${ok}/${budgets.length} 张`);
process.exit(ok > 0 ? 0 : 1);
