// 发布完整性一键巡检（每轮 patrol 复用）：demos.json / Pages 构建 / itch 通道 / git 状态 / 视频新鲜度。
// 用法: node tools/verify-release.mjs [版本]   例：node tools/verify-release.mjs demo-03-3d-v12
// 缺省版本 = demos.json 里 demo-03 的 buildId（以 Pages 线上为准）。
// 退出码 0=全部一致，1=有异常（逐项列出）。网络项超时按 FAIL 计（CDN 传播期可重试一次）。
import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const argVersion = process.argv[2] || '';
const BASE = 'https://tonyguan530.github.io/taptap2026';
const ITCH_TARGET = 'sxguan/taptap2026:html';
const BUTLER = path.join(ROOT, 'tools', 'butler', 'butler.exe');

const fails = [];
const ok = (name) => console.log('OK  ', name);
const bad = (name, detail) => {
	fails.push(name);
	console.log('FAIL', name, detail || '');
};
const jfetch = async (u, timeoutMs = 30000) => {
	const r = await fetch(u, { signal: AbortSignal.timeout(timeoutMs) });
	if (!r.ok) throw new Error(`HTTP ${r.status}`);
	return r.json();
};

// ① demos.json → 版本锚点
let version = argVersion;
try {
	const demos = await jfetch(`${BASE}/demos.json`);
	const s = (demos.slots || []).find((x) => x.id === 'demo-03');
	if (!s) bad('demos.json 有 demo-03 槽位');
	else if (!version) {
		version = s.buildId;
		ok(`demos.json demo-03 buildId=${version}（自动锚定）`);
	} else if (s.buildId !== version) bad(`demos.json demo-03 buildId=${s.buildId}（期望 ${version}）`);
	else ok(`demos.json demo-03 buildId=${version}`);
} catch (e) {
	bad('demos.json 可访问', String(e));
}

if (!version) {
	console.log('无版本锚点，终止');
	process.exit(1);
}

// ② Pages 构建（build.json + index.html + wasm）
for (const f of ['build.json', 'index.html', 'index.wasm']) {
	try {
		const r = await fetch(`${BASE}/builds/${version}/${f}`, { method: 'HEAD', signal: AbortSignal.timeout(30000) });
		if (r.ok) ok(`Pages builds/${version}/${f}`);
		else bad(`Pages builds/${version}/${f}`, `HTTP ${r.status}`);
	} catch (e) {
		bad(`Pages builds/${version}/${f}`, String(e));
	}
}

// ③ itch 通道版本（共享通道会轮转：非本 demo 只 WARN，Pages 才是稳定主入口）
try {
	const out = execSync(`"${BUTLER}" status ${ITCH_TARGET}`, { timeout: 60000, encoding: 'utf8' });
	if (out.includes('√') && out.includes(version)) ok(`itch 通道版本=${version}`);
	else console.log('WARN  itch 通道当前非本 demo（共享轮转）：', (out.split('\n').find((l) => l.includes('html')) || '').trim());
} catch (e) {
	console.log('WARN  itch 通道状态查询失败：', String(e).slice(0, 120));
}

// ④ 本地构建目录
const local = path.join(ROOT, 'builds', version);
if (fs.existsSync(path.join(local, 'index.pck')) && fs.existsSync(path.join(local, 'index.html'))) {
	ok(`本地 builds/${version}/ 完整`);
} else bad(`本地 builds/${version}/`, '缺 index.pck 或 index.html');

// ⑤ git：worktree 干净（builds 除外）且分支已推送
try {
	const st = execSync('git status --short', { cwd: ROOT, encoding: 'utf8' })
		.split('\n')
		.filter((l) => l.trim() && !l.includes('builds/'));
	if (st.length === 0) ok('worktree 干净（builds 除外）');
	else bad('worktree 有未提交变更', st.slice(0, 5).join(' | '));
	const head = execSync('git rev-parse HEAD', { cwd: ROOT, encoding: 'utf8' }).trim();
	const branch = execSync('git rev-parse --abbrev-ref HEAD', { cwd: ROOT, encoding: 'utf8' }).trim();
	execSync(`git fetch origin ${branch}`, { cwd: ROOT, timeout: 60000 });
	const remote = execSync(`git rev-parse origin/${branch}`, { cwd: ROOT, encoding: 'utf8' }).trim();
	if (head === remote) ok(`分支 ${branch} 已推送`);
	else bad(`分支 ${branch} 未推送`, `local=${head.slice(0, 7)} remote=${remote.slice(0, 7)}`);
} catch (e) {
	bad('git 状态', String(e).slice(0, 120));
}

// ⑥ 视频新鲜度（mp4 修改时间 ≥ 构建目录创建时间）
const mp4 = path.join(ROOT, 'reviews', 'videos', 'demo-03-3d.mp4');
if (fs.existsSync(mp4) && fs.existsSync(local)) {
	const vAge = fs.statSync(mp4).mtimeMs;
	const bAge = fs.statSync(local).mtimeMs;
	if (vAge >= bAge) ok('视频不旧于当前构建');
	else bad('视频旧于当前构建', '需 record-video 重录');
} else bad('视频文件存在', mp4);

console.log(fails.length === 0 ? `== RELEASE OK：${version} 全链一致 ==` : `== RELEASE FAIL：${fails.length} 项异常 ==`);
process.exit(fails.length === 0 ? 0 : 1);
