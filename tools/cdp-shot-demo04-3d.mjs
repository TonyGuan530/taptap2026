// CDP 无窗截图 v2：headless + remote-debugging，模拟前台会话（破解隐藏页取流停摆）
// 用法：node tools/cdp-shot-demo04-3d.mjs [buildDir] [waitMs]
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')), '..');
const buildDir = path.resolve(ROOT, process.argv[2] || 'builds/demo-04-3d-v4');
const waitMs = Number(process.argv[3] || 40000);
const DBG = 9223;
const EDGE = ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Microsoft/Edge/Application/msedge.exe'].find((p) => fs.existsSync(p));

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.svg': 'image/svg+xml' };
const server = http.createServer((req, res) => {
  const rel = decodeURIComponent(req.url.split('?')[0]).replace(/^\//, '') || 'index.html';
  const fp = path.join(buildDir, rel);
  if (!fp.startsWith(buildDir) || !fs.existsSync(fp) || fs.statSync(fp).isDirectory()) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(fp)] || 'application/octet-stream' });
  fs.createReadStream(fp).pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const PORT = server.address().port;
console.log('serve on', PORT);

const prof = path.join(process.env.TEMP || '.', 'edge-cdp-' + Date.now());
const edge = spawn(EDGE, [
  '--headless=new', '--hide-scrollbars', '--no-first-run', '--disable-gpu',
  `--remote-debugging-port=${DBG}`, `--user-data-dir=${prof}`,
  '--window-size=1280,720', `http://127.0.0.1:${PORT}/index.html`,
], { stdio: 'ignore' });

// 等 devtools 端口就绪
let target = null;
for (let i = 0; i < 40; i++) {
  await new Promise((r) => setTimeout(r, 500));
  try {
    const r = await fetch(`http://127.0.0.1:${DBG}/json/list`);
    const list = await r.json();
    target = list.find((t) => t.type === 'page' && t.url.includes('127.0.0.1'));
    if (target) break;
  } catch {}
}
if (!target) { console.error('未找到页面 target'); process.exit(1); }
console.log('target:', target.url);

const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
let mid = 0;
const pending = new Map();
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
};
function send(method, params = {}) {
  return new Promise((r) => { const id = ++mid; pending.set(id, r); ws.send(JSON.stringify({ id, method, params })); });
}
await send('Page.enable');
await send('Emulation.setFocusEmulationEnabled', { enabled: true });
await send('Page.bringToFront');
await send('Emulation.setPageScaleFactor', { pageScaleFactor: 1 });
console.log('前台模拟已开启，等待', waitMs / 1000, 's（引擎引导+运行）');
await new Promise((r) => setTimeout(r, waitMs));

const shots = [];
for (const tag of ['a', 'b', 'c']) {
  const cap = await send('Page.captureScreenshot', { format: 'png' });
  if (cap.result && cap.result.data) {
    const out = path.join(ROOT, 'reviews', 'shots', `demo-04-3d-cdp-${tag}.png`);
    fs.mkdirSync(path.dirname(out), { recursive: true });
    fs.writeFileSync(out, Buffer.from(cap.result.data, 'base64'));
    shots.push(out);
    console.log('OK', path.basename(out), Math.round(fs.statSync(out).size / 1024) + 'KB');
  }
  await new Promise((r) => setTimeout(r, 3000));
}
// 状态读数：Godot 壳层进度条
const ev = await send('Runtime.evaluate', { expression: 'document.getElementById("status-progress") ? document.getElementById("status-progress").value + "/" + document.getElementById("status-progress").max : "no-bar"', returnByValue: true });
console.log('progress:', ev.result && ev.result.result ? ev.result.result.value : '?');
ws.close();
edge.kill();
server.close();
process.exit(shots.length ? 0 : 1);
