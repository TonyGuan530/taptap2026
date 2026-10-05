// CDP 滥用浸泡：全键位混沌输入（含模式键 K/B/R/Shift+R/G/T/1~5），验证状态机健壮性
// 用法：node tools/cdp-chaos-demo04-3d.mjs [buildDir] [durationSec]
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')), '..');
const buildDir = path.resolve(ROOT, process.argv[2] || 'builds/demo-04-3d-v9');
const DUR = Number(process.argv[3] || 180);
const DBG = 9230;
const EDGE = ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].find((p) => fs.existsSync(p));

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
const edge = spawn(EDGE, ['--headless=new', '--hide-scrollbars', '--no-first-run', `--remote-debugging-port=${DBG}`, `--user-data-dir=${process.env.TEMP}/edge-chaos-${Date.now()}`, '--window-size=800,450', `http://127.0.0.1:${PORT}/index.html`], { stdio: 'ignore' });

let target = null;
for (let i = 0; i < 40; i++) {
  await new Promise((r) => setTimeout(r, 500));
  try { const l = await (await fetch(`http://127.0.0.1:${DBG}/json/list`)).json(); target = l.find((t) => t.type === 'page'); if (target) break; } catch {}
}
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
let mid = 0; const pend = new Map(); const errors = [];
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pend.has(m.id)) { pend.get(m.id)(m); pend.delete(m.id); return; }
  if (m.method === 'Runtime.consoleAPICalled' && m.params.type === 'error') {
    errors.push('console: ' + m.params.args.map((a) => a.value || a.description || '').join(' ').slice(0, 140));
  }
  if (m.method === 'Runtime.exceptionThrown') {
    errors.push('exception: ' + String(m.params.exceptionDetails?.exception?.description || m.params.exceptionDetails?.text || '').slice(0, 140));
  }
};
const send = (m, p = {}) => new Promise((r) => { const id = ++mid; pend.set(id, r); ws.send(JSON.stringify({ id, method: m, params: p })); });
async function key(code, down, shift = false) {
  const ch = String.fromCharCode(code);
  await send('Input.dispatchKeyEvent', { type: down ? 'keyDown' : 'keyUp', windowsVirtualKeyCode: code, code: 'Key' + ch, key: ch.toLowerCase(), text: down && !shift ? ch.toLowerCase() : '', modifiers: shift ? 8 : 0 });
}
await send('Page.enable'); await send('Runtime.enable');
await send('Emulation.setFocusEmulationEnabled', { enabled: true });
await send('Page.bringToFront');
console.log('引擎引导 25s → 混沌输入', DUR, 's');
await new Promise((r) => setTimeout(r, 25000));

// 全键位池：移动/跳/融合 + 模式键 K B R G T + 数字 1~5（Shift+R 用组合）
const POOL = [87, 65, 83, 68, 32, 69, 75, 66, 82, 71, 84, 49, 50, 51, 52, 53];
const held = new Map();
let shiftHeld = false;
const t0 = Date.now();
let n = 0;
while (Date.now() - t0 < DUR * 1000) {
  const code = POOL[Math.floor(Math.random() * POOL.length)];
  const useShift = code === 82 && Math.random() < 0.3;   // R 有概率带 Shift（完整再跑）
  if (useShift !== shiftHeld) { await key(16, useShift); shiftHeld = useShift; }   // 16=Shift
  const down = !held.get(code);
  await key(code, down, shiftHeld);
  held.set(code, down);
  if (down) setTimeout(() => { if (held.get(code)) { key(code, false, shiftHeld); held.set(code, false); } }, 500);
  n++;
  await new Promise((r) => setTimeout(r, 60));
}
for (const [c] of held) await key(c, false);
if (shiftHeld) await key(16, false);
await new Promise((r) => setTimeout(r, 1500));
const alive = (await js('1+1')) === 2;
async function js(expr) { const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true }); return r.result?.result?.value; }
console.log('页面状态:', alive ? 'alive' : 'dead');
ws.close(); edge.kill(); server.close();
console.log(`混沌浸泡完成：输入 ${n} 次 · 错误 ${errors.length} 条`);
for (const e of errors.slice(0, 8)) console.log('ERR', e);
fs.writeFileSync(path.join(ROOT, 'reports', 'chaos-last-errors.txt'), errors.join('\n') || '(no errors)');
process.exit(alive && errors.length === 0 ? 0 : 1);
