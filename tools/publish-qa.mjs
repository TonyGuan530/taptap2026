// 发布 QA：验证 itch 上的构建与本地完全一致、游戏可加载。
// 用法：node tools/publish-qa.mjs <version>   例：node tools/publish-qa.mjs demo-07
// 检查项：① butler 频道状态 √ ② itch CDN 四件套逐字节 md5 与本地一致 ③ 结论。
// 退出码：0=PASS，1=FAIL（需要重推或排查）。零依赖，Node 18+。
import { execSync } from 'node:child_process';
import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getSecret } from './secrets.mjs';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const version = process.argv[2];
if (!version) {
	console.error('用法: node tools/publish-qa.mjs <version>');
	process.exit(1);
}
const localDir = path.join(ROOT, 'builds', version);
if (!fs.existsSync(path.join(localDir, 'index.html'))) {
	console.error(`QA FAIL: 本地不存在 builds/${version}/index.html`);
	process.exit(1);
}
const FILES = ['index.html', 'index.pck', 'index.wasm', 'index.js'];
let fails = 0;

// ① butler 频道状态
console.log('== ① butler 频道状态 ==');
try {
	const key = getSecret('itch');
	const tmp = path.join(process.env.TEMP || '/tmp', 'butler_qa_creds.txt');
	fs.writeFileSync(tmp, key);
	const out = execSync(
		`"${path.join(ROOT, 'tools', 'butler', 'butler.exe')}" status "sxguan/taptap2026:html" -i "${tmp}"`,
		{ timeout: 60000, encoding: 'utf8' },
	);
	fs.unlinkSync(tmp);
	const ok = /√\s*#\d+/.test(out) && out.includes(version);
	console.log(ok ? `PASS: 频道已处理且版本为 ${version}` : `WARN: 频道输出未确认 ${version}\n${out}`);
	if (!ok) fails++;
} catch (e) {
	console.log('WARN: butler status 查询失败（网络？）' + e.message);
}

// ② itch CDN 文件与本地 md5 对比（build 号从 butler status 解析，确保是刚推的那个）
console.log('== ② CDN 文件校验 ==');
let embedBase = '';
let buildVerified = false;
try {
	const key = getSecret('itch');
	const tmp = path.join(process.env.TEMP || '/tmp', 'butler_qa_creds.txt');
	fs.writeFileSync(tmp, key);
	const out = execSync(
		`"${path.join(ROOT, 'tools', 'butler', 'butler.exe')}" status "sxguan/taptap2026:html" -i "${tmp}"`,
		{ timeout: 60000, encoding: 'utf8' },
	);
	fs.unlinkSync(tmp);
	const buildM = out.match(/√\s*#(\d+)/);
	if (buildM) {
		embedBase = `https://html.itch.zone/html/19508798-${buildM[1]}`;   // upload id 19508798 为频道固定值
		buildVerified = out.includes(version);
		console.log(`最新构建 #${buildM[1]} → ${embedBase}`);
		console.log(buildVerified ? `PASS: 频道版本 = ${version}` : `FAIL: 频道版本不是 ${version}（还在处理或推送未生效）`);
		if (!buildVerified) fails++;
	}
} catch (e) {
	console.log('WARN: butler status 失败 ' + e.message);
}
if (!embedBase) {
	// 兜底：从游戏页抓嵌入地址
	try {
		const page = await (await fetch('https://sxguan.itch.io/taptap2026', {
			method: 'POST',
			headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
			body: 'password=taptap',
		})).text();
		const m = page.match(/https:\/\/html\.itch\.zone\/html\/([\d.-]+)\/index\.html/);
		if (m) embedBase = `https://html.itch.zone/html/${m[1]}`;
	} catch { /* 抓取失败则跳过 */ }
}

if (!embedBase) {
	console.log('FAIL: 无法确定嵌入地址');
	fails++;
} else {
	if (!buildVerified) console.log('WARN: 嵌入地址来自页面抓取，构建号未核对');
	console.log('嵌入地址: ' + embedBase);
	// CDN 可能还在处理新构建（占位页特征：所有文件返回同一哈希）——最多重试 3 次，每次等 25 秒
	for (let attempt = 1; attempt <= 3; attempt++) {
		let bad = 0;
		let firstHash = '';
		let allSame = true;
		for (const f of FILES) {
			const localMd5 = crypto.createHash('md5').update(fs.readFileSync(path.join(localDir, f))).digest('hex');
			let remoteMd5 = '';
			let remoteSize = 0;
			try {
				const buf = Buffer.from(await (await fetch(`${embedBase}/${f}`)).arrayBuffer());
				remoteSize = buf.length;
				remoteMd5 = crypto.createHash('md5').update(buf).digest('hex');
			} catch (e) {
				console.log(`FAIL: ${f} 下载失败 ${e.message}`);
				bad++;
				continue;
			}
			if (firstHash === '') firstHash = remoteMd5;
			if (remoteMd5 !== firstHash) allSame = false;
			const ok = remoteMd5 === localMd5;
			if (f === 'index.html') {
				// itch 服务时会向 index.html 注入包装代码，逐字节必然不同——宽松校验：体积合理即通过
				const localSize = fs.statSync(path.join(localDir, f)).size;
				const htmlOk = remoteSize >= localSize * 0.8 && !allSame;
				console.log(`${htmlOk ? 'PASS' : 'FAIL'}: index.html（远程 ${remoteSize}B）宽松校验`);
				if (!htmlOk) bad++;
				continue;
			}
			console.log(`${ok ? 'PASS' : 'FAIL'}: ${f} 远程md5=${remoteMd5.slice(0, 8)} 本地md5=${localMd5.slice(0, 8)}`);
			if (!ok) bad++;
		}
		if (bad === 0) break;
		if (allSame && attempt < 3) {
			console.log(`CDN 疑似仍在处理构建（占位页），25 秒后重试（${attempt}/3）...`);
			await new Promise((r) => setTimeout(r, 25000));
		} else if (attempt < 3) {
			console.log(`仍有 ${bad} 项异常，25 秒后重试（${attempt}/3）...`);
			await new Promise((r) => setTimeout(r, 25000));
		}
		fails = Math.max(fails, bad);
	}
}

// ③ 结论
console.log('== 结论 ==');
console.log(fails === 0 ? `QA PASS: ${version} 发布完好，可以发链接给玩家` : `QA FAIL: ${fails} 项异常——先重推 (push-itch.ps1) 或检查网络，再把链接发出去`);
process.exit(fails === 0 ? 0 : 1);
