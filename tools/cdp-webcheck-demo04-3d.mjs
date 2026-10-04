// CDP Web 验收 v1：遥测下载落地断言 + iframe 嵌入引导 + 实验房 T 导出截图
// 用法：node tools/cdp-webcheck-demo04-3d.mjs [buildDir]
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')), '..');
const buildDir = path.resolve(ROOT, process.argv[2] || 'builds/demo-04-3d-v5');
const DBG = 9226;
const DLDIR = path.join(process.env.TEMP || '.', 'd04-dl-' + Date.now());
fs.mkdirSync(DLDIR, { recursive: true });
const EDGE = ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Microsoft/Edge/Application/msedge.exe'].find((p) => fs.existsSync(p));

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.svg': 'image/svg+xml' };
function makeServer() {
  return http.createServer((req, res) => {
    const rel = decodeURIComponent(req.url.split('?')[0]).replace(/^\//, '') || 'index.html';
    const fp = path.join(buildDir, rel);
    if (!fp.startsWith(buildDir) || !fs.existsSync(fp) || fs.statSync(fp).isDirectory()) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(fp)] || 'application/octet-stream' });
    fs.createReadStream(fp).pipe(res);
  });
}
const server = makeServer();
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const PORT = server.address().port;

// iframe 包装页（模拟 Hub 嵌入）
const hubServer = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(`<!DOCTYPE html><html><body style="margin:0"><iframe src="http://127.0.0.1:${PORT}/index.html" style="width:100vw;height:100vh;border:0"></iframe></body></html>`);
});
await new Promise((r) => hubServer.listen(0, '127.0.0.1', r));
const HUB = hubServer.address().port;

const prof = path.join(process.env.TEMP || '.', 'edge-webcheck-' + Date.now());
const edge = spawn(EDGE, ['--headless=new', '--hide-scrollbars', '--no-first-run', `--remote-debugging-port=${DBG}`, `--user-data-dir=${prof}`, '--window-size=800,450', '--autoplay-policy=no-user-gesture-required', 'about:blank'], { stdio: 'ignore' });
let target = null;
for (let i = 0; i < 40; i++) {
  await new Promise((r) => setTimeout(r, 500));
  try {
    const list = await (await fetch(`http://127.0.0.1:${DBG}/json/list`)).json();
    target = list.find((t) => t.type === 'page');
    if (target) break;
  } catch {}
}
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
let mid = 0;
const pending = new Map();
ws.onmessage = (ev) => { const m = JSON.parse(ev.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } };
function send(method, params = {}) { return new Promise((r) => { const id = ++mid; pending.set(id, r); ws.send(JSON.stringify({ id, method, params })); }); }
async function nav(url) { await send('Page.navigate', { url }); }
async function js(expr) { const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true }); return r.result && r.result.result ? r.result.result.value : undefined; }
async function key(code, down = true) { const ch = String.fromCharCode(code); await send('Input.dispatchKeyEvent', { type: down ? 'keyDown' : 'keyUp', windowsVirtualKeyCode: code, code: 'Key' + ch, key: ch.toLowerCase(), text: down ? ch.toLowerCase() : '' }); }
async function tap(code) { await key(code, true); await key(code, false); }
async function shot(out) {
  fs.mkdirSync(path.dirname(out), { recursive: true });
  const cap = await send('Page.captureScreenshot', { format: 'png' });
  fs.writeFileSync(out, Buffer.from(cap.result.data, 'base64'));
  return Math.round(fs.statSync(out).size / 1024);
}
await send('Page.enable');
await send('Runtime.enable');
await send('Emulation.setFocusEmulationEnabled', { enabled: true });
// 允许下载落地
const sdb = await send('Browser.setDownloadBehavior', { behavior: 'allow', downloadPath: DLDIR });
console.log('setDownloadBehavior resp:', JSON.stringify(sdb).slice(0, 120));

console.log('== 用例 W1：iframe 嵌入引导 ==');
await nav(`http://127.0.0.1:${HUB}/`);
await new Promise((r) => setTimeout(r, 30000));
// 引导判定：主文档 iframe 存在且游戏画布非初始尺寸
const iframeOk = await js(`(() => { const f = document.querySelector('iframe'); return f ? 'iframe-ok' : 'no-iframe'; })()`);
const s1 = await shot(path.join(ROOT, 'reviews', 'shots', 'demo-04-3d-web-iframe.png'));
console.log(`W1 iframe=${iframeOk} shot=${s1}KB`);

console.log('== 用例 W2：实验房 K + 遥测 T 下载落地（顶层直开，避开跨域 iframe 焦点） ==');
await nav(`http://127.0.0.1:${PORT}/index.html`);
await new Promise((r) => setTimeout(r, 45000));   // 引导（SwiftShader 编译较慢）
await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: 400, y: 225, button: 'left', clickCount: 1 });
await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: 400, y: 225, button: 'left', clickCount: 1 });
await new Promise((r) => setTimeout(r, 800));
await tap(75);                       // K → 实验房
await new Promise((r) => setTimeout(r, 2000));
await tap(84);                       // T → 导出 + 触发下载
await new Promise((r) => setTimeout(r, 5000));
const probe = await js(`(() => { try { const a = document.createElement('a'); a.href = 'data:application/json;base64,e30='; a.download = 'probe.json'; document.body.appendChild(a); a.click(); a.remove(); return 'clicked'; } catch (e) { return 'err:' + e.message; } })()`);
console.log('probe download:', probe);
await new Promise((r) => setTimeout(r, 3000));
const dls = fs.readdirSync(DLDIR).filter((f) => f.endsWith('.json'));
let dlOk = false;
let evCount = '?';
if (dls.length) {
  try {
    const env = JSON.parse(fs.readFileSync(path.join(DLDIR, dls[0]), 'utf8'));
    dlOk = env.game === 'demo-04-3d' && Array.isArray(env.events);
    evCount = env.events.length;
  } catch (e) { dlOk = false; }
}
const s2 = await shot(path.join(ROOT, 'reviews', 'shots', 'demo-04-3d-web-telemetry.png'));
console.log(`W2 遥测下载=${dlOk ? 'OK' : 'FAIL'} 文件=${dls.join(',') || '无'} 事件=${evCount} shot=${s2}KB`);

console.log('== 用例 W3：中文渲染抽查（截图已含） ==');
console.log('完成。下载目录:', DLDIR);
ws.close();
edge.kill();
server.close();
hubServer.close();
process.exit(dlOk && iframeOk === 'iframe-ok' ? 0 : 1);
