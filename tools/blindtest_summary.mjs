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
const players3d = new Map(); // sid → events（3D：pid=demo06_3d_<关卡>_<sid>，每文件一会话）
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
	if (String(pid).startsWith('demo06_3d')) {
		const sid3 = events[0]?.sid || pid;
		if (!players3d.has(sid3)) players3d.set(sid3, []);
		players3d.get(sid3).push(...events);
		continue;
	}
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
	const lvAggAll = new Map();   // 关卡 → (组合 → 次数)，跨会话累计

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
		// 迁移轨迹按关卡聚合（次数计数），避免多会话/多轮跑批时行数爆炸
		for (const e of evs) {
			if (e.type !== 'place' || (e.level || 0) < 3) continue;
			const key = e.level;
			if (!lvAggAll.has(key)) lvAggAll.set(key, new Map());
			const combo = SHAPE_NAME[e.shape] + '+' + WORD_NAME[e.tag];
			const m = lvAggAll.get(key);
			m.set(combo, (m.get(combo) || 0) + 1);
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
	for (const [lv, combos] of [...lvAggAll.entries()].sort((x, y) => x[0] - y[0])) {
		const parts = [...combos.entries()].map(([c, n]) => (n > 1 ? c + '×' + n : c));
		transfer.push('L' + (lv + 1) + ': ' + parts.join(' | '));
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

function summarize3dSession(sid, evs) {
	evs.sort((a, b) => (a.el || 0) - (b.el || 0));
	const goal = evs.find((e) => e.type === 'goal');
	const places = evs.filter((e) => e.type === 'place');
	const rejected = evs.filter((e) => e.type === 'placement_rejected');
	const attempts = evs.filter((e) => e.type === 'placement_attempt');
	const resets = evs.filter((e) => e.type === 'reset');
	const route = places
		.map((p) => `${SHAPE_NAME[p.shape] || p.shape}+${WORD_NAME[p.tag] || p.tag}`)
		.join('→');
	const g = goal || {};
	const gpos = Array.isArray(g.ghost_pos) ? `(${g.ghost_pos.join(',')})` : '?';
	const rejRatio = attempts.length ? `${rejected.length}/${attempts.length}` : '0';
	return `${sid} | 通关L3?${goal ? 'Y' : 'N'} | 用时${g.elapsed ?? '?'}s | 放置${places.length} | 拒绝${rejRatio} | 复位${resets.length} | 墨余${g.ink_left ?? '?'} | 组合 ${route || '(未放置)'} | ghost终位${gpos}@${g.ghost_yaw ?? '?'}rad`;
}

const out3d = [];
if (players3d.size) {
	const sessions = [...players3d.entries()];
	const wins = sessions.filter(([, e]) => e.some((x) => x.type === 'goal'));
	const times = wins
		.map(([, e]) => e.find((x) => x.type === 'goal')?.elapsed)
		.filter((t) => typeof t === 'number')
		.sort((a, b) => a - b);
	const median = times.length ? times[Math.floor(times.length / 2)] : null;
	const totRej = sessions.reduce((s, [, e]) => s + e.filter((x) => x.type === 'placement_rejected').length, 0);
	const totAtt = sessions.reduce((s, [, e]) => s + e.filter((x) => x.type === 'placement_attempt').length, 0);
	out3d.push('## 3D 盲测每人一行摘要（L3 主 Gate，构建 demo-06-3d-v6+）\n');
	for (const [, evs] of sessions) out3d.push(summarize3dSession(evs[0]?.sid || 'S?', evs));
	out3d.push('');
	out3d.push(
		`汇总: 会话 ${sessions.length} / 通关 ${wins.length}` +
			(times.length ? `（${Math.round((wins.length / sessions.length) * 100)}%，中位用时 ${median}s）` : '') +
			` / 放置尝试 ${totAtt}（拒绝 ${totRej}${totAtt ? `，${Math.round((totRej / totAtt) * 100)}%` : ''}——高拒绝率=placement_control 疑似）`,
	);
	out3d.push('（failure_cause 与 lifecycle 口供由组织者记录表补充；新解 D 与 intentional/accidental 人工看录屏标注）');
}

const out = [];
const sortedPids = [...players.keys()].sort();
for (const pid of sortedPids) {
	const sess = players.get(pid);
	out.push(summarizePlayer(pid, sess).lines.join('\n'));
	out.push('');
}
if (markdown) {
	if (out3d.length) console.log(out3d.join('\n') + '\n');
	if (out.length) {
		console.log('## 盲测每人一行摘要（可直接发给 ChatGPT）\n');
		console.log(out.join('\n'));
		console.log('\n（新解 D 与 intentional/accidental 两列由人工看录屏补齐后再发）');
	}
	if (!out.length && !out3d.length) console.log('（无可汇总数据）');
} else if (out3d.length) {
	console.log(out3d.join('\n'));
} else {
	console.log(out.join('\n'));
}
