// 让 GPT 按验收标准评审已完成的 demo，报告写入 reviews/<时间戳>.md
// 用法：node tools/gpt-review.mjs
// Key 存在 /key 页（openai，可选 openai_base 自定义中转地址）。零依赖，Node 18+。
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getSecret } from './secrets.mjs';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const REVIEWS_DIR = path.join(ROOT, 'reviews');

const key = getSecret('openai');
if (!key) {
  console.log('SKIP: 未保存 OpenAI Key（打开 Review 站 /key 页保存后重试）');
  process.exit(2);
}
const base = (getSecret('openai_base') || 'https://api.openai.com/v1').replace(/\/$/, '');
const model = process.env.OPENAI_MODEL || 'gpt-4o-mini';

const read = (p) => {
  try { return fs.readFileSync(path.join(ROOT, p), 'utf8'); } catch { return ''; }
};

const backlog = read('requirements/backlog.md');
const demos = read('public/demos.json');
const notes = read('requirements/miro-export.md');

// 汇总试玩反馈（最近的评论），给评审当输入
let feedback = '';
try {
  const db = JSON.parse(read('data/db.json') || '{}');
  const rows = [];
  for (const [bid, list] of Object.entries(db)) {
    for (const c of list.slice(-10)) rows.push(`- [${bid}] ${c.name} ${c.rating}★：${c.text}`);
  }
  feedback = rows.slice(-30).join('\n');
} catch { /* ignore */ }

if (!backlog) {
  console.log('SKIP: requirements/backlog.md 不存在');
  process.exit(2);
}

const prompt = `你是游戏项目严格但务实的玩法评审官。团队在验证一组小玩法 demo，请对照验收标准逐个评审。

## 玩法需求池（含验收标准）
${backlog}

## Demo 计划与完成状态
${demos}

${notes ? `## Miro 上的原始想法（参考）\n${notes.slice(0, 3000)}\n` : ''}
${feedback ? `## 玩家试玩反馈（最近）\n${feedback}\n` : ''}

请输出中文 markdown 评审报告，要求：
1. 对每个状态为 done 的玩法块单独一节：结论 PASS 或 NEEDS_WORK
2. NEEDS_WORK 的给出最多 5 条具体、可执行的修改建议（每条一行，别空谈）
3. 最后给一行总结：「下一步：建议开发 demo-0X」或「下一步：优先修复 demo-0X」
不要复述需求原文，直接给结论和建议。`;

let r;
try {
  r = await fetch(base + '/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model,
      temperature: 0.3,
      messages: [
        { role: 'system', content: '你是游戏玩法评审官，输出简洁的中文 markdown，结论明确。' },
        { role: 'user', content: prompt },
      ],
    }),
  });
} catch (e) {
  console.log(`ERROR: 调不上 ${base}（${e.message}）。用中转的话把地址存到 /key 页 openai_base。`);
  process.exit(1);
}
if (!r.ok) {
  console.log(`ERROR: OpenAI 接口返回 ${r.status}: ${(await r.text()).slice(0, 200)}`);
  process.exit(1);
}
const data = await r.json();
const content = data.choices?.[0]?.message?.content || '';
if (!content) {
  console.log('ERROR: GPT 返回了空内容');
  process.exit(1);
}

fs.mkdirSync(REVIEWS_DIR, { recursive: true });
const stamp = new Date().toISOString().replace(/[:T]/g, '-').slice(0, 16);
const file = path.join(REVIEWS_DIR, `${stamp}.md`);
fs.writeFileSync(file, `# GPT 评审报告 ${stamp}\n\n> 模型：${model}\n\n${content}\n`);
console.log(`OK: 评审完成 → reviews/${stamp}.md`);
const needsWork = (content.match(/NEEDS_WORK/g) || []).length;
const pass = (content.match(/PASS/g) || []).length;
console.log(`SUMMARY: PASS=${pass} NEEDS_WORK=${needsWork}`);
console.log(content.split('\n').filter((l) => l.includes('下一步')).slice(-1)[0] || '');
