#!/usr/bin/env node
// 盲测 telemetry 汇总器（demo-06）：把游戏「📦数据」导出的 JSON 转成 ChatGPT Gate 判定所需的
// 「每人一行」摘要 + 聚合指标。零依赖 Node 18+。
// 用法：
//   node tools/blindtest_summary.mjs [文件或目录...]     （默认 reviews/blindtest/）
//   --markdown   同时输出可直接粘贴给 ChatGPT 的汇总段
// 输入格式（游戏内「📦数据」→ 复制 JSON）：
//   { "pid": "P01", "events": [ {type:"start|select|place|contact|reset|goal|session_end", ts, el, sid, level, ...} ] }
// 判读约定：level 2 = L3（主 Gate）；3 = L4；4 = L5；5 = L6。tag/shape 取自 place/select 事件。

import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const markdown = args.includes('--markdown');
const inputs = args.filter((a) => !a.startsWith('--'));
const targets = inputs.length ? inputs : ['reviews/blindtest'];

const files = [];
for (const t of targets) {
	if (fs.existsSync(t) && fs.statSync(t).isDirectory()) {
		for (const f of fs.readdirSync(t)) if (f.endsWith('.json')) files.push(path.join(t, f));
	} else if (fs.existsSync(t)) {
		files.push(t);
	}
}
if (!files.length) {
	console.log('未找到 telemetry JSON（默认目录 reviews/blindtest/）。组织者把「📦数据」复制的 JSON 存入该目录后重跑。');
	process.exit(1);
}

const players = new Map(); // pid → { sessions: Map(sid → events[]) }
for (const file of files) {
	let data;
	try {
		data = JSON.parse(fs.readFileSync(file, 'utf8'));
	} catch {
		console.error(`跳过（JSON 解析失败）: ${file}`);
		continue;
	}
	const pid = data.pid || path.basename(file, '.json');
	const events = Array.isArray(data.events) ? data.events : [];
	for (const ev of events) {
		const sid = ev.sid || 'S0';
		if (!players.has(pid)) players.set(pid, new Map());
		const sess = players.get(pid);
		if (!sess.has(sid)) sess.set(sid, []);
		sess.get(sid).push(ev);
	}
}

const WORD_NAME = { heavy: 'Heavy', float: 'Float', fire: 'Fire', sticky: 'Sticky' };
const SHAPE_NAME = { ball: '圆球', plank: '长板', block: '方块' };

function firstPlaceOfTag(evs, tag, afterEl = -1) {
	for (const e of evs) {
		if ((e.type === 'place' || e.type === 'select') && e.tag === tag && e.el > afterEl) return e.el;
	}
	return null;
}

function summarizePlayer(pid, sessions) {
	const lines = [];
	let allCombos = new Set();
	let stickyTried = false;
	let firstHeavy = null;
	let usedEnv = false;
	let l3Wins = 0;
	let l3Best = null; // { sid, elapsed, route, placements }
	const transfer = [];

	for (const [sid, evs] of sessions) {
		evs.sort((a, b) => (a.el || 0) - (b.el || 0));
		const goalEv = evs.find((e) => e.type === 'goal');
		const l3 = evs.filter((e) => e.level === 2);
		const l3Goal = l3.find((e) => e.type === 'goal');
		const places = evs.filter((e) => e.type === 'place');
		for (const p of places) allCombos.add(`${p.shape}×${p.tag}`);
		if (places.some((p) => p.tag === 'sticky')) stickyTried = true;
		const hv = firstPlaceOfTag(evs, 'heavy');
		if (hv !== null && (firstHeavy === null || hv < firstHeavy)) firstHeavy = hv;
		usedEnv = evs.some((e) => e.type === 'contact' && String(e.with || '').startsWith('env'));
		if (l3Goal) {
			l3Wins += 1;
			const route = l3
				.filter((e) => e.type === 'place')
				.map((e) => `${SHAPE_NAME[e.shape] || e.shape}+${WORD_NAME[e.tag] || e.tag}`)
				.join('→');
			const cand = { sid, elapsed: l3Goal.elapsed, route, n: l3.filter((e) => e.type === 'place').length };
			if (!l3Best || cand.elapsed < l3Best.elapsed) l3Best = cand;
		}
		const hiLevels = [...new Set(evs.filter((e) => (e.level || 0) >= 3).map((e) => e.level))];
		for (const lv of hiLevels) {
			const t = evs.filter((e) => e.level === lv && e.type === 'place').map((e) => `${SHAPE_NAME[e.shape]}+${WORD_NAME[e.tag]}`);
			if (t.length) transfer.push(`L${lv + 1}: ${t.join(' → ') || '(无放置)'}`);
		}
	}
	if (!l3Best) {
		for (const [, evs] of sessions) {
			const l3 = evs.filter((e) => e.level === 2);
			if (l3.length) {
				const route = l3.filter((e) => e.type === 'place').map((e) => `${SHAPE_NAME[e.shape]}+${WORD_NAME[e.tag]}`).join('→');
				l3Best = { sid, elapsed: null, route: route || '(未放置)', n: 0 };
			}
		}
	}
	const combos = allCombos.size;
	const comboStr = [...allCombos].map((c) => c.replace('ball', '球').replace('plank', '板').replace('block', '块')).join(' ');
	const envStr = usedEnv ? 'Y' : 'N';
	const heavyStr = firstHeavy === null ? '未尝试' : `${Math.round(firstHeavy)}s`;
	const stickyStr = stickyTried ? 'Y' : 'N';
	const passStr = l3Wins > 0 ? 'Y' : 'N';
	const best = l3Best || {};
	lines.push(
		`${pid} | 通关L3?${passStr} | 首解=${best.route || '?'} | 用时${best.elapsed ?? '?'}s | 组合尝试${combos} | 用环境物${envStr} | 首试Heavy=${heavyStr} | 试Sticky=${stickyStr}`,
	);
	lines.push(`    组合明细: ${comboStr || '(无)'}`);
	if (transfer.length) lines.push(`    迁移轨迹: ${transfer.join(' | ')}`);
	return { pid, passStr, best, combos, comboStr, envStr, heavyStr, stickyStr, lines };
}

const out = [];
const sortedPids = [...players.keys()].sort();
for (const pid of sortedPids) {
	const sess = players.get(pid);
	out.push(summarizePlayer(pid, sess).lines.join('\n'));
	out.push('');
}
if (markdown) {
	console.log('## 盲测每人一行摘要（可直接发给 ChatGPT）\n');
	console.log(out.join('\n'));
	console.log('\n（新解 D 与 intentional/accidental 两列由人工看录屏补齐后再发）');
} else {
	console.log(out.join('\n'));
}
