#!/usr/bin/env node
/**
 * 生成静态试玩站点到 dist/（供 GitHub Pages 或任意静态托管使用）
 * 用法: node tools/build-static.mjs
 * 产物: dist/ = public/ 全部文件 + builds/ 全部构建 + builds.json（构建清单）
 * 说明: 静态模式没有评论后端，前端会自动切换为 giscus / 链接式反馈。
 */
import { readdirSync, statSync, existsSync, mkdirSync, readFileSync, writeFileSync, cpSync, rmSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const buildsDir = path.join(root, 'builds');
const publicDir = path.join(root, 'public');
const distDir = path.join(root, 'dist');

rmSync(distDir, { recursive: true, force: true });
mkdirSync(distDir, { recursive: true });
cpSync(publicDir, distDir, { recursive: true });

const builds = [];
for (const ent of readdirSync(buildsDir, { withFileTypes: true })) {
  if (!ent.isDirectory()) continue;
  if (!existsSync(path.join(buildsDir, ent.name, 'index.html'))) continue;
  let meta = {};
  try {
    meta = JSON.parse(readFileSync(path.join(buildsDir, ent.name, 'build.json'), 'utf8'));
  } catch {
    /* 缺 build.json 时用目录信息兜底 */
  }
  const st = statSync(path.join(buildsDir, ent.name));
  builds.push({
    id: ent.name,
    title: meta.title || ent.name,
    version: meta.version || '',
    date: meta.date || st.mtime.toISOString(),
    author: meta.author || '',
    notes: meta.notes || '',
    commentCount: 0,
    avgRating: 0,
  });
}
builds.sort((a, b) => (b.date || '').localeCompare(a.date || ''));

cpSync(buildsDir, path.join(distDir, 'builds'), { recursive: true });
writeFileSync(
  path.join(distDir, 'builds.json'),
  JSON.stringify({ generatedAt: new Date().toISOString(), builds }, null, 2)
);
console.log(`✅ 静态站点已生成: dist/ （${builds.length} 个构建）`);
console.log('   本地预览: npx serve dist   或直接把 dist/ 内容推到 GitHub Pages');
