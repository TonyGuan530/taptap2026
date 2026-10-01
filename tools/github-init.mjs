// 用 GitHub Token 自动建仓库 + 推送代码，打通 GitHub Pages / Actions
// 用法：node tools/github-init.mjs [仓库名=taptap2026]
// Token 存在 /key 页（github，Fine-grained 需 Administration + Contents 读写）。零依赖，Node 18+。
import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getSecret } from './secrets.mjs';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const run = (cmd) => execSync(cmd, { cwd: ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();

const token = getSecret('github');
if (!token) {
  console.log('SKIP: 未保存 GitHub Token（打开 Review 站 /key 页保存后重试）');
  process.exit(2);
}
const repoName = process.argv[2] || 'taptap2026';

const headers = {
  Authorization: `Bearer ${token}`,
  Accept: 'application/vnd.github+json',
  'X-GitHub-Api-Version': '2022-11-28',
  'Content-Type': 'application/json',
};

// 1. 认证 + 拿用户名
const me = await fetch('https://api.github.com/user', { headers });
if (!me.ok) {
  console.log(`ERROR: GitHub Token 无效（${me.status}）`);
  process.exit(1);
}
const login = (await me.json()).login;
console.log(`OK: 认证为 ${login}`);

// 2. 仓库已存在就直接跳过创建（GitHub 对 fine-grained token 是先查权限后查重名，
//    所以不能用 POST 的 422 来判断"已存在"）
const probe = await fetch(`https://api.github.com/repos/${login}/${repoName}`, { headers });
if (probe.ok) {
  console.log(`OK: 仓库 ${login}/${repoName} 已存在，跳过创建`);
} else {
  const create = await fetch('https://api.github.com/user/repos', {
    method: 'POST',
    headers,
    body: JSON.stringify({
      name: repoName,
      description: 'TapTap2026 - Godot 小游戏 + Miro→GPT→自动开发流水线',
      private: false, // 免费版 GitHub Pages 只支持公开仓库
      auto_init: false,
    }),
  });
  if (create.ok) {
    console.log(`OK: 仓库已创建 ${login}/${repoName}（公开，免费 Pages 要求）`);
  } else if (create.status === 403) {
    // Fine-grained Token 经常没有"建仓库"权限，但推送不受影响
    console.log('MANUAL: Token 没有「建仓库」权限，请手动建一个空仓库（30 秒，一次性）：');
    console.log('  打开 https://github.com/new');
    console.log(`  · Repository name 填 ${repoName}`);
    console.log('  · 选 Public（免费 Pages 要求）');
    console.log('  · 下面的初始化选项（README / .gitignore / license）全部不勾');
    console.log('  · 点 Create repository');
    console.log('建好后重跑: node tools/github-init.mjs  （脚本会自动检测到已存在并直接推送）');
    process.exit(2);
  } else {
    console.log(`ERROR: 建仓库失败 ${create.status}: ${(await create.text()).slice(0, 200)}`);
    process.exit(1);
  }
}

// 3. 配 remote（Token 只存本机 .git/config）
const remoteUrl = `https://x-access-token:${token}@github.com/${login}/${repoName}.git`;
let remotes = '';
try { remotes = run('git remote -v'); } catch { /* ignore */ }
if (remotes.includes('origin')) {
  run(`git remote set-url origin "${remoteUrl}"`);
  console.log('OK: 已更新 origin 地址');
} else {
  run(`git remote add origin "${remoteUrl}"`);
  console.log('OK: 已添加 origin');
}

// 4. 推送
try {
  run('git push -u origin main');
  console.log(`OK: 已推送 main → https://github.com/${login}/${repoName}`);
  console.log('');
  console.log('最后两步要去网页点一次（一次性）：');
  console.log(`  1. https://github.com/${login}/${repoName}/settings/pages → Source 选 "GitHub Actions"`);
  console.log('  2. Settings → Secrets and variables → Actions：');
  console.log('     Variable ITCH_TARGET = sxguan/taptap2026');
  console.log('     Secret  ITCH_API_KEY = 你的 itch Key（Review 站 /key 页有存，复制过去）');
  console.log('     配好后每次 git push 就会自动导出+发布 Pages+更新 itch');
} catch (e) {
  console.log('ERROR: 推送失败：' + (e.stderr || e.message));
  process.exit(1);
}
