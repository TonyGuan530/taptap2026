import fs from 'node:fs';
const p = 'tools/blindtest_summary.mjs';
let s = fs.readFileSync(p, 'utf8');
const oldAgg = `\t\tconst hiLevels = [...new Set(evs.filter((e) => (e.level || 0) >= 3).map((e) => e.level))];
\t\tfor (const lv of hiLevels) {
\t\t\tconst t = evs.filter((e) => e.level === lv && e.type === 'place').map((e) => \\\`\${SHAPE_NAME[e.shape]}+\${WORD_NAME[e.tag]}\\\`);
\t\t\tif (t.length) transfer.push(\\\`L\\\${lv + 1}: \\\${t.join(' → ')}\\\`);
\t\t}`;
const newAgg = `\t\t// 迁移轨迹按关卡聚合（次数计数），避免多会话/多轮跑批时行数爆炸
\t\tconst lvAgg = new Map();
\t\tfor (const e of evs) {
\t\t\tif (e.type !== 'place' || (e.level || 0) < 3) continue;
\t\t\tconst key = e.level;
\t\t\tif (!lvAgg.has(key)) lvAgg.set(key, new Map());
\t\t\tconst combo = SHAPE_NAME[e.shape] + '+' + WORD_NAME[e.tag];
\t\t\tlvAgg.get(key).set(combo, (lvAgg.get(key).get(combo) || 0) + 1);
\t\t}
\t\tfor (const [lv, combos] of [...lvAgg.entries()].sort((x, y) => x[0] - y[0])) {
\t\t\tconst parts = [...combos.entries()].map(([c, n]) => (n > 1 ? c + '×' + n : c));
\t\t\ttransfer.push('L' + (lv + 1) + ': ' + parts.join(' | '));
\t\t}`;
if (!s.includes(oldAgg)) { console.log('OLD NOT FOUND'); process.exit(1); }
s = s.replace(oldAgg, newAgg, 1);
fs.writeFileSync(p, s);
console.log('aggregation patched');
