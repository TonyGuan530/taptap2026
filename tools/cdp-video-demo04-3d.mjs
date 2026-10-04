// CDP 无窗录像 v1：startScreencast 出帧 + Input.dispatchKeyEvent 注入按键 → ffmpeg 合成 mp4
// 用法：node tools/cdp-video-demo04-3d.mjs [buildDir] [durationSec]
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn, execFileSync } from 'node:child_process';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')), '..');
const buildDir = path.resolve(ROOT, process.argv[2] || 'builds/demo-04-3d-v4');
const DUR = Number(process.argv[3] || 20);
const DBG = 9224;
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
const prof = path.join(process.env.TEMP || '.', 'edge-cdpv-' + Date.now());
const edge = spawn(EDGE, ['--headless=new', '--hide-scrollbars', '--no-first-run', `--remote-debugging-port=${DBG}`, `--user-data-dir=${prof}`, '--window-size=800,450', `http://127.0.0.1:${PORT}/index.html`], { stdio: 'ignore' });

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
const frames = [];
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); return; }
  if (m.method === 'Page.screencastFrame' && m.params.data) {
    frames.push(m.params.data);
    ws.send(JSON.stringify({ id: 'ack' + frames.length, method: 'Page.screencastFrameAck', params: { sessionId: m.params.sessionId } }));
  }
};
function send(method, params = {}) {
  return new Promise((r) => { const id = ++mid; pending.set(id, r); ws.send(JSON.stringify({ id, method, params })); });
}
function key(code, down) {
  return send('Input.dispatchKeyEvent', {
    type: down ? 'keyDown' : 'keyUp', windowsVirtualKeyCode: code, code: 'Key' + String.fromCharCode(code), key: String.fromCharCode(code), text: down ? String.fromCharCode(code).toLowerCase() : '',
  });
}
await send('Page.enable');
await send('Runtime.enable');
await send('Emulation.setFocusEmulationEnabled', { enabled: true });
await send('Page.bringToFront');
console.log('前台模拟开启，等引擎引导 25s');
await new Promise((r) => setTimeout(r, 25000));

const t0 = Date.now();
let jumpT = -9;
let walkOn = false;
while (Date.now() - t0 < DUR * 1000) {
  const t = (Date.now() - t0) / 1000;
  // 输入脚本：2~16s 持续向东 + 每 0.9s 一跳
  const walk = t > 2 && t < 16;
  if (walk !== walkOn) { await key(68, walk); walkOn = walk; }
  if (walk && t - jumpT > 0.9) { await key(32, true); await key(32, false); jumpT = t; }
  // 轮询截帧（强制合成出帧，避开 screencast 低帧率）
  const cap = await send('Page.captureScreenshot', { format: 'jpeg', quality: 75 });
  if (cap.result && cap.result.data) frames.push(cap.result.data);
}
if (walkOn) await key(68, false);
await new Promise((r) => setTimeout(r, 600));
const cap = await send('Page.captureScreenshot', { format: 'jpeg', quality: 75 });
if (cap.result && cap.result.data) frames.push(cap.result.data);
console.log('帧数:', frames.length);
ws.close();
edge.kill();
server.close();

if (frames.length < 10) { console.error('帧太少'); process.exit(1); }
const tmp = path.join(process.env.TEMP || '.', 'd04cdp-frames-' + Date.now());
fs.mkdirSync(tmp, { recursive: true });
frames.forEach((d, i) => fs.writeFileSync(path.join(tmp, `f${String(i).padStart(4, '0')}.jpg`), Buffer.from(d, 'base64')));
const out = path.join(ROOT, 'reviews', 'videos', 'demo-04-3d.mp4');
// 帧率按平均间隔折算（screencast 按需出帧）
const fps = Math.max(6, Math.min(30, Math.round(frames.length / DUR)));
execFileSync('ffmpeg', ['-y', '-framerate', String(fps), '-i', path.join(tmp, 'f%04d.jpg'), '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out], { stdio: 'ignore', timeout: 180000 });
console.log('VIDEO OK', out, Math.round(fs.statSync(out).size / 1024) + 'KB', fps + 'fps', frames.length + '帧');
