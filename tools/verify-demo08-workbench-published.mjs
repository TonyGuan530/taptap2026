import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
const require = createRequire(import.meta.url);
const { chromium } = require('D:/Apps/NodeJS/node_modules/@playwright/mcp/node_modules/playwright');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const base = process.env.DEMO08_REVIEW_URL || 'https://tonyguan530.github.io/taptap2026';
const checks = [];
const assert = (condition, name) => { checks.push({ name, passed: Boolean(condition) }); if (!condition) throw Error(name); };
const hash = data => crypto.createHash('sha256').update(data).digest('hex');
async function get(relative) {
  const response = await fetch(base+'/'+relative+'?verify='+Date.now());
  if (!response.ok) throw Error(relative+' HTTP '+response.status);
  return response;
}
let passed = false;
let pckSha256;
try {
  const demos = await (await get('demos.json')).json();
  assert(!demos.slots.some(x=>x.id==='demo-08'),'2D slot removed');
  assert(demos.slots.find(x=>x.id==='demo-08-3d')?.buildId==='demo-08-3d-v29','3D slot points to v29');
  const archive = await (await get('archive.json')).json();
  assert(archive.items.find(x=>x.id==='demo-08-v3')?.status==='archived','2D v3 archived');
  assert(archive.items.find(x=>x.id==='demo-08-3d-v29')?.status==='active','v29 active');
  assert(archive.items.find(x=>x.id==='demo-08-3d-v28')?.status==='archived','v28 archived');
  const local = fs.readFileSync(path.join(root,'builds/demo-08-3d-v29/index.pck'));
  const online = Buffer.from(await (await get('builds/demo-08-3d-v29/index.pck')).arrayBuffer());
  pckSha256 = hash(local);
  assert(hash(online)===pckSha256,'Online PCK matches latest tested export');
  const browser = await chromium.launch({ headless:true, executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
  try {
    const page = await browser.newPage();
    await page.goto(base+'/');
    await page.locator('.slot[href="play.html?id=demo-08-3d-v29"]').waitFor();
    assert(await page.locator('.slot[href="play.html?id=demo-08-v3"]').count()===0,'2D absent from rendered hub');
    await page.goto(base+'/archive.html');
    await page.locator('details').filter({has:page.locator('#list')}).locator('summary').click();
    await page.locator('#list .meta').filter({hasText:'demo-08-v3'}).waitFor();
    assert(true,'2D v3 appears in rendered archive');
  } finally { await browser.close(); }
  passed = true;
} finally {
  const result = { verifiedAt:new Date().toISOString(), base, passed, pckSha256, checks };
  fs.writeFileSync(path.join(root,'reviews/demo08-workbench-published.json'),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify(result,null,2));
}
process.exitCode = passed ? 0 : 1;
