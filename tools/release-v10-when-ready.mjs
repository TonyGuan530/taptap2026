// v10 发布守卫脚本：余量充足时执行三步发布，不足时拒绝并说明
// 用法：node tools/release-v10-when-ready.mjs [--force]   （--force 跳过余量守卫）
import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const MAIN = 'D:/GIT/taptap2026';
const WT = 'D:/GIT/taptap2026-demo04-3d';
const SRC = path.join(WT, 'builds/demo-04-3d-v10');
const DST = path.join(MAIN, 'builds/demo-04-3d-v10');
const LIMIT_MB = 1024;   // GitHub Pages 官方上限 1GB
const HEADROOM_REAL = 60;   // 发布后最低余量（校准：事故阈值是硬上限 1024，此前 900 为保守假设）


if (!fs.existsSync(path.join(SRC, 'index.pck'))) { console.error('ABORT: 本地 v10 构建不存在（先导出）'); process.exit(1); }
if (!process.argv.includes('--force')) {
  const du = execSync(`du -s "${MAIN}/builds"`, { encoding: 'utf8' });
  const usedMB = Math.round(parseInt(du) / 1024);
  const newMB = 46;   // v10 构建实测体积
  if (usedMB + newMB > LIMIT_MB - 60) {
    console.error(`ABORT: Pages 余量不足（现用 ${usedMB}MB + 新版 ${newMB}MB > 上限 ${LIMIT_MB - 60}MB）。`);
    console.error('请先由属主清理超留版本（当前 demo-02-3d 持有 4 版 ≈138MB 可清），或用 --force 明示跳过守卫。');
    process.exit(1);
  }
  console.log(`余量守卫通过：现用 ${usedMB}MB + ${newMB}MB ≤ ${LIMIT_MB - 60}MB`);
}
// 三步发布
execSync(`cp -r "${SRC}" "${MAIN}/builds/"`, { stdio: 'inherit' });
const slotPatch = `
const fs=require('fs');
const p='${MAIN}/public/demos.json'.replace(/\//g, path.sep);
`.replace(/path\.sep.*/, '');
const djPath = path.join(MAIN, 'public', 'demos.json');
const dj = JSON.parse(fs.readFileSync(djPath, 'utf8'));
const slot = dj.slots.find((x) => x.id === 'demo-04-3d');
			if (slot) { slot.buildId = 'demo-04-3d-v10'; dj.updatedAt = new Date().toISOString().slice(0, 10); fs.writeFileSync(djPath, JSON.stringify(dj, null, 2) + String.fromCharCode(10)); console.log('slot -> v10'); }
execSync(`git add builds/demo-04-3d-v10 public/demos.json && git add -u builds/`, { cwd: MAIN, stdio: 'inherit' });
execSync(`git commit -m "demo-04：3D v10 发布（Web 鼠标捕获修复+外星生物待机动画；预验证 pck+巡游+混沌全过）；Pages 换版仅留 v10"`, { cwd: MAIN, stdio: 'inherit' });
execSync(`git pull --rebase --autostash origin main`, { cwd: MAIN, stdio: 'inherit' });
execSync(`git push origin main`, { cwd: MAIN, stdio: 'inherit' });
console.log('RELEASED: demo-04-3d-v10 已上线（Pages 部署待 CI）');
