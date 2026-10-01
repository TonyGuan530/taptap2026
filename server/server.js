#!/usr/bin/env node
/**
 * TapTap2026 内部 Review 站点（零依赖，仅需 Node 18+）
 *
 * 启动：    node server/server.js
 * 环境变量：
 *   PORT      端口，默认 8787
 *   HOST      监听地址，默认 127.0.0.1（局域网分享用 0.0.0.0）
 *   ADMIN_KEY 设置后可用 DELETE + x-admin-key 头删除评论
 */
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const PUBLIC_DIR = path.join(ROOT, 'public');
const BUILDS_DIR = path.join(ROOT, 'builds');
const DATA_DIR = path.join(ROOT, 'data');
const DB_FILE = path.join(DATA_DIR, 'db.json');
const SECRETS_FILE = path.join(DATA_DIR, 'secrets.json');

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || '127.0.0.1';
const ADMIN_KEY = process.env.ADMIN_KEY || '';

// 可存放的 Key 类型：latest=itch（历史原因叫 latest）、miro、miro_board（看板ID）、
// openai、openai_base（中转地址）、github
const SECRET_SLOTS = ['latest', 'miro', 'miro_board', 'openai', 'openai_base', 'github'];

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.side': 'application/octet-stream',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.css': 'text/css; charset=utf-8',
  '.ogg': 'audio/ogg',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

// ---------------- 数据 ----------------

function loadDb() {
  try {
    return JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
  } catch {
    return {};
  }
}
let db = loadDb();

function saveDb() {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2));
}

function maskSecret(value) {
  const v = String(value);
  if (v.length <= 8) return '••••';
  return `${v.slice(0, 3)}…${v.slice(-3)}（${v.length} 字符）`;
}

function loadSecrets() {
  try {
    return JSON.parse(fs.readFileSync(SECRETS_FILE, 'utf8'));
  } catch {
    return {};
  }
}

function listBuilds() {
  let entries = [];
  try {
    entries = fs.readdirSync(BUILDS_DIR, { withFileTypes: true });
  } catch {
    return [];
  }
  const builds = [];
  for (const ent of entries) {
    if (!ent.isDirectory()) continue;
    if (!fs.existsSync(path.join(BUILDS_DIR, ent.name, 'index.html'))) continue;
    let meta = {};
    try {
      meta = JSON.parse(fs.readFileSync(path.join(BUILDS_DIR, ent.name, 'build.json'), 'utf8'));
    } catch {
      /* 没有 build.json 时用目录信息兜底 */
    }
    const st = fs.statSync(path.join(BUILDS_DIR, ent.name));
    const comments = db[ent.name] || [];
    const ratings = comments.map((c) => c.rating).filter((r) => r >= 1 && r <= 5);
    builds.push({
      id: ent.name,
      title: meta.title || ent.name,
      version: meta.version || '',
      date: meta.date || st.mtime.toISOString(),
      author: meta.author || '',
      notes: meta.notes || '',
      commentCount: comments.length,
      avgRating: ratings.length
        ? Math.round((ratings.reduce((a, b) => a + b, 0) / ratings.length) * 10) / 10
        : 0,
    });
  }
  builds.sort((a, b) => (b.date || '').localeCompare(a.date || ''));
  return builds;
}

// ---------------- HTTP 基础 ----------------

function sendJson(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-cache',
    ...secHeaders(),
  });
  res.end(body);
}

function secHeaders() {
  // Godot 4 线程版 Web 导出需要跨域隔离头；全站统一带上
  return {
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
  };
}

function sendFile(res, filePath) {
  let st;
  try {
    st = fs.statSync(filePath);
  } catch {
    return sendJson(res, 404, { error: 'not found' });
  }
  if (st.isDirectory()) return sendFile(res, path.join(filePath, 'index.html'));
  const ext = path.extname(filePath).toLowerCase();
  res.writeHead(200, {
    'Content-Type': MIME[ext] || 'application/octet-stream',
    'Content-Length': st.size,
    'Cache-Control': 'no-cache',
    ...secHeaders(),
  });
  fs.createReadStream(filePath).pipe(res);
}

function safeJoin(base, rel) {
  const p = path.normalize(path.join(base, rel));
  const normBase = path.normalize(base);
  if (p !== normBase && !p.startsWith(normBase + path.sep)) return null;
  return p;
}

function readBody(req, limit = 16 * 1024) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > limit) {
        reject(new Error('body too large'));
        req.destroy();
      } else {
        chunks.push(c);
      }
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

// ---------------- 路由 ----------------

const server = http.createServer(async (req, res) => {
  try {
    const pathname = decodeURIComponent(new URL(req.url, 'http://x').pathname);

    if (pathname === '/api/health') {
      return sendJson(res, 200, { ok: true, builds: listBuilds().length });
    }

    if (pathname === '/api/builds') {
      return sendJson(res, 200, listBuilds());
    }

    let m = pathname.match(/^\/api\/builds\/([^/]+)$/);
    if (m && req.method === 'GET') {
      const b = listBuilds().find((x) => x.id === m[1]);
      if (!b) return sendJson(res, 404, { error: 'build not found' });
      const comments = (db[b.id] || []).slice().sort((a, c) => c.ts - a.ts);
      return sendJson(res, 200, { ...b, comments });
    }

    m = pathname.match(/^\/api\/builds\/([^/]+)\/comments$/);
    if (m && req.method === 'POST') {
      const id = m[1];
      if (!fs.existsSync(path.join(BUILDS_DIR, id, 'index.html'))) {
        return sendJson(res, 404, { error: 'build not found' });
      }
      let body;
      try {
        body = JSON.parse(await readBody(req));
      } catch {
        return sendJson(res, 400, { error: '请求格式不对' });
      }
      const name = String(body.name || '').trim().slice(0, 20) || '匿名玩家';
      const rating = Math.round(Number(body.rating));
      const text = String(body.text || '').trim().slice(0, 500);
      if (!(rating >= 1 && rating <= 5)) return sendJson(res, 400, { error: '评分需为 1-5 星' });
      if (!text) return sendJson(res, 400, { error: '写点想说的吧～' });
      const comment = {
        id: Date.now().toString(36) + Math.random().toString(36).slice(2, 7),
        name,
        rating,
        text,
        ts: Date.now(),
      };
      (db[id] = db[id] || []).push(comment);
      saveDb();
      return sendJson(res, 200, { ok: true, comment });
    }

    m = pathname.match(/^\/api\/builds\/([^/]+)\/comments\/([^/]+)$/);
    if (m && req.method === 'DELETE') {
      if (!ADMIN_KEY || req.headers['x-admin-key'] !== ADMIN_KEY) {
        return sendJson(res, 403, { error: '需要有效的 ADMIN_KEY' });
      }
      const [, bid, cid] = m;
      db[bid] = (db[bid] || []).filter((c) => c.id !== cid);
      saveDb();
      return sendJson(res, 200, { ok: true });
    }

    // API Key 存放（本机 data/secrets.json，gitignore；GET 只回掩码）
    if (pathname === '/api/secrets' && req.method === 'POST') {
      let body;
      try {
        body = JSON.parse(await readBody(req));
      } catch {
        return sendJson(res, 400, { error: '请求格式不对' });
      }
      const slot = String(body.key || 'latest');
      if (!SECRET_SLOTS.includes(slot)) {
        return sendJson(res, 400, { error: '未知的 Key 类型：' + slot });
      }
      const value = String(body.value || '').trim();
      if (!value) return sendJson(res, 400, { error: '内容为空' });
      const secrets = loadSecrets();
      secrets[slot] = { value, savedAt: Date.now() };
      fs.mkdirSync(DATA_DIR, { recursive: true });
      fs.writeFileSync(SECRETS_FILE, JSON.stringify(secrets, null, 2));
      return sendJson(res, 200, { ok: true, hint: maskSecret(value) });
    }
    if (pathname === '/api/secrets' && req.method === 'GET') {
      const secrets = loadSecrets();
      const saved = {};
      for (const slot of SECRET_SLOTS) {
        if (secrets[slot] && secrets[slot].value) {
          saved[slot] = { savedAt: secrets[slot].savedAt, hint: maskSecret(secrets[slot].value) };
        }
      }
      return sendJson(res, 200, { saved });
    }

    if (req.method !== 'GET' && req.method !== 'HEAD') {
      return sendJson(res, 405, { error: 'method not allowed' });
    }

    // 静态：试玩页
    if (pathname === '/play') return sendFile(res, path.join(PUBLIC_DIR, 'play.html'));
    // 静态：API Key 存放页
    if (pathname === '/key') return sendFile(res, path.join(PUBLIC_DIR, 'key.html'));
    // 静态：首页
    if (pathname === '/' || pathname === '/index.html') {
      return sendFile(res, path.join(PUBLIC_DIR, 'index.html'));
    }
    // 静态：构建产物（Godot 导出的 index.html / .wasm / .pck 等）
    if (pathname.startsWith('/builds/')) {
      const fp = safeJoin(BUILDS_DIR, pathname.slice('/builds/'.length));
      if (!fp) return sendJson(res, 400, { error: 'bad path' });
      return sendFile(res, fp);
    }
    // 静态：站点前端资源
    const fp = safeJoin(PUBLIC_DIR, pathname.slice(1));
    if (fp && fs.existsSync(fp) && fs.statSync(fp).isFile()) return sendFile(res, fp);

    return sendJson(res, 404, { error: 'not found' });
  } catch (err) {
    console.error('[server]', err);
    try {
      sendJson(res, 500, { error: 'server error' });
    } catch {
      /* 响应头已发出 */
    }
  }
});

server.listen(PORT, HOST, () => {
  const display = HOST === '0.0.0.0' ? '0.0.0.0' : `localhost`;
  console.log(`✅ Review 站点已启动: http://localhost:${PORT}`);
  const lan = Object.values(os.networkInterfaces())
    .flat()
    .filter((n) => n && n.family === 'IPv4' && !n.internal)
    .map((n) => n.address);
  if (lan.length) {
    if (HOST === '0.0.0.0') {
      console.log('📡 局域网访问地址（同一 WiFi 下的朋友试试）:');
      lan.forEach((ip) => console.log(`   http://${ip}:${PORT}`));
    } else {
      console.log('ℹ️  想让局域网/内网穿透访问，请用 HOST=0.0.0.0 启动');
    }
  }
  console.log(`📦 发现 ${listBuilds().length} 个可试玩构建`);
  if (!ADMIN_KEY) {
    console.log('ℹ️  未设置 ADMIN_KEY，删除评论功能未启用');
  }
});
