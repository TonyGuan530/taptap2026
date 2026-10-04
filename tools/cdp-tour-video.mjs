// CDP 五关巡游录像：?tour=1 内置机器人通关，captureScreenshot 轮询全程 → ffmpeg 延时片
// 用法：node tools/cdp-tour-video.mjs [buildDir] [maxWaitSec]
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn, execFileSync } from 'node:child_process';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')), '..');
const buildDir = path.resolve(ROOT, process.argv[2] || 'builds/demo-04-3d-v5');
const MAXWAIT = Number(process.argv[3] || 480);
const DBG = 9225;
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
const prof = path.join(process.env.TEMP || '.', 'edge-tour-' + Date.now());
const edge = spawn(EDGE, ['--headless=new', '--hide-scrollbars', '--no-first-run', `--remote-debugging-port=${DBG}`, `--user-data-dir=${prof}`, '--window-size=800,450', `http://127.0.0.1:${PORT}/index.html?tour=1`], { stdio: 'ignore' });

let target = null;
for (let i = 0; i < 40; i++) {
  await new Promise((r) => setTimeout(r, 500));
  try {
    const list = await (await fetch(`http://127.0.0.1:${DBG}/json/list`)).json();
    target = list.find((t) => t.type === 'page' && t.url.includes('127.0.0.1'));
    if (target) break;
  } catch {}
}
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
let mid = 0;
const pending = new Map();
ws.onmessage = (ev) => { const m = JSON.parse(ev.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } };
function send(method, params = {}) { return new Promise((r) => { const id = ++mid; pending.set(id, r); ws.send(JSON.stringify({ id, method, params })); }); }
async function js(expr) {
  const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true });
  return r.result && r.result.result ? r.result.result.value : undefined;
}
await send('Page.enable');
await send('Runtime.enable');
await send('Emulation.setFocusEmulationEnabled', { enabled: true });
await send('Page.bringToFront');
console.log('巡游开始，全程截帧（上限', MAXWAIT, 's）…');
const frames = [];
const t0 = Date.now();
let lastLvl = '';
while (Date.now() - t0 < MAXWAIT * 1000) {
  const done = await js('window.tourDone');
  const lvl = await js('window.hudLevel || ""');
  const cap = await send('Page.captureScreenshot', { format: 'jpeg', quality: 72 });
  if (cap.result && cap.result.data) frames.push(cap.result.data);
  const el = Math.round((Date.now() - t0) / 1000);
  if (lvl !== lastLvl) { console.log(`t=${el}s 关卡=${lvl} 帧=${frames.length}`); lastLvl = lvl; }
  if (done !== undefined && done !== null) { console.log(`tourDone=${done} @t=${el}s 帧=${frames.length}`); break; }
}
ws.close();
edge.kill();
server.close();
if (frames.length < 20) { console.error('帧太少:', frames.length); process.exit(1); }
const tmp = path.join(process.env.TEMP || '.', 'd04tour-' + Date.now());
fs.mkdirSync(tmp, { recursive: true });
frames.forEach((d, i) => fs.writeFileSync(path.join(tmp, `f${String(i).padStart(4, '0')}.jpg`), Buffer.from(d, 'base64')));
const out = path.join(ROOT, 'reviews', 'videos', 'demo-04-3d.mp4');
const fps = Math.max(8, Math.min(24, Math.round(frames.length / 22)));   // 延时片目标 ~22s
execFileSync('ffmpeg', ['-y', '-framerate', String(fps), '-i', path.join(tmp, 'f%04d.jpg'), '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out], { stdio: 'ignore', timeout: 300000 });
console.log('VIDEO OK', out, Math.round(fs.statSync(out).size / 1024) + 'KB', fps + 'fps', frames.length + '帧');
