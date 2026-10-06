import fs from 'node:fs';
import {createHash} from 'node:crypto';
const dir='.codex-tmp/inkbound-v10-touch';
const build=JSON.parse(fs.readFileSync('builds/demo-06-inkbound-v10-touch/build.json','utf8'));
const hash=createHash('sha256').update(fs.readFileSync('builds/demo-06-inkbound-v10-touch/index.pck')).digest('hex');
if(hash!==build.pckSha256)throw Error('Export metadata mismatch');
const suites=[];
for(const name of ['geometry','smoke','yellow','blade_perf','touch']){
 const out=fs.readFileSync(`${dir}/native-${name}.out.log`,'utf8'),err=fs.readFileSync(`${dir}/native-${name}.err.log`,'utf8');
 const count=out.match(/CHECKS=(\d+) FAILURES=(\d+)/);
 if(!count||Number(count[2])!==0||err.trim())throw Error('Native suite failed '+name);
 suites.push({name,checks:Number(count[1]),failures:0,stderr:err});
}
const routes={};
for(const [name,folder,route]of [['phone','phone-final','ladder'],['desktop','desktop-final','board']]){
 const qa=JSON.parse(fs.readFileSync(`${dir}/${folder}/${route}-qa.json`,'utf8'));
 if(qa.errors.length||qa.evidence.some(e=>e.failure)||!qa.evidence.at(-1).state.won||qa.build.pckSha256!==hash)throw Error('Full route failed '+name);
 routes[name]={passed:true,method:qa.method,route,milestones:qa.evidence.map(e=>e.phase),final:qa.evidence.at(-1).state,build:qa.build};
}
const file='docs/inkbound-touch-validation.json';
const previous=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):{};
const report={date:new Date().toISOString(),build:{...build,pckSha256:hash},native:{totalChecks:suites.reduce((a,s)=>a+s.checks,0),failures:0,suites},browser:routes,entry:JSON.parse(fs.readFileSync(`${dir}/entry-qa.json`,'utf8')),limitations:['Chromium mobile-browser emulation, not physical Android/iOS hardware','Touch patch retains V10 gameplay; emergence redesign remains a proposal'],review:'Independent input review passed; later ladder-arrival regression reproduced RED and fixed GREEN',release:previous.release||null};
fs.writeFileSync(file,JSON.stringify(report,null,2)+'\n');
const releaseText=report.release?.onlineVerified?`\n线上发布：提交 ${report.release.commit}，GitHub Pages [工作流 ${report.release.workflow}，第 ${report.release.attempt} 次运行](https://github.com/TonyGuan530/taptap2026/actions/runs/${report.release.workflow}) 成功。实际线上 PCK 与验收构建一致；手机浏览器真实触摸完成开始、摇杆移动、四笔绘画与保存，控制台无错误。\n\n[触控试玩](${report.release.url}) · [展示页](${report.release.landingUrl})。\n`:'';
fs.writeFileSync('docs/inkbound-touch-validation.md',`# INKBOUND V10 触控补丁验证\n\n混合项目：3D世界与角色，2D绘画和输入界面。\n\n- 源提交：${build.sourceCommit}\n- PCK SHA-256：${hash}\n- Godot 4.7.2，无窗口导入、启动、导出均 exit 0。\n- 原生 ${report.native.totalChecks} 项检查通过，无 stderr；覆盖真实移动、多指同时操作、取消与失焦、笔画所有权、画纸穿透拦截、梯顶输入复位。\n- 移动浏览器 844×390：实际 CDP 触摸绘画、移动、攀爬、切藤、战斗、双指移动与跳跃、完整结局。\n- 桌面鼠标与键盘：板面路线＋搭梯绕过保留的藤墙和敌人，完整结局。\n- 两条浏览器路线接收到的实际 HTTP PCK 都与本地导出一致，控制台无错误。\n- 验证设备为 Chromium 模拟移动浏览器，未使用实体 Android／iOS 手机。\n\n保留旧 V10 导出和录屏；原录像仍对应原版哈希。当前补丁验收的是操作与原有流程，不能作为新版涌现玩法已完成的证明。新设计见 [改版案](inkbound-emergence-redesign.md)。\n`);
console.log(JSON.stringify({checks:report.native.totalChecks,phone:routes.phone.passed,desktop:routes.desktop.passed,hash}));
if(releaseText)fs.appendFileSync('docs/inkbound-touch-validation.md',releaseText);
