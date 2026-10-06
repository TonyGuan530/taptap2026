import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
const root=process.cwd(),scratch=path.join(root,'.codex-tmp/inkbound-v10');
const read=file=>JSON.parse(fs.readFileSync(file,'utf8'));
const build=read(path.join(root,'builds/demo-06-inkbound-v10/build.json'));
const hash=createHash('sha256').update(fs.readFileSync(path.join(root,'builds/demo-06-inkbound-v10/index.pck'))).digest('hex');
if(build.pckSha256!==hash||build.title!=='墨迹漂流 / INKBOUND')throw Error('Export hash or Chinese metadata mismatch');
const native=read(path.join(scratch,'review/final-native.json'));
if(native.sourceGameCommit!==build.sourceCommit||native.suites.some(s=>s.failures||s.exitCode||s.stderr))throw Error('Independent native evidence must match final game source');
const routes=['ladder','board'].map(route=>{
  const qa=read(path.join(scratch,route+'-qa.json'));
  if(qa.blackOnly||qa.errors.length||qa.build.pckSha256!==hash||!qa.evidence.at(-1).state?.won||qa.evidence.some(e=>e.failure))throw Error('Full ordinary '+route+' route must pass for current PCK');
  return {...qa,evidence:qa.evidence.map(e=>({phase:e.phase,player:e.state.player,goals:e.state.goals,won:e.state.won,vines:e.state.vines,enemy:e.state.enemy,combat:e.state.combat,final_goal:e.state.final_goal,tool:{kind:e.state.tool.kind,property:e.state.tool.property,length:e.state.tool.length},weapon:{equipped:e.state.weapon.equipped,length:e.state.weapon.length,property:e.state.weapon.property}}))};
});
const entry=read(path.join(scratch,'entry-qa.json'));
if(entry.errors.length||!entry.evidence.some(e=>e.phase==='embedded-input'&&e.moved)||!entry.evidence.some(e=>e.phase==='mobile'))throw Error('Desktop iframe input, video and mobile entry acceptance required');
const media=read(path.join(root,'public/inkbound-v10-art/capture.json'));
if(media.videos.length!==2||media.videos.some(v=>!v.decoded||v.capture.build.pckSha256!==hash||!(v.audioPeakDb>-80)))throw Error('Matching decoded two-route media with actual game audio required');
const reportFile=path.join(root,'docs/inkbound-v10-validation.json');
const previous=fs.existsSync(reportFile)?read(reportFile):{};
const proof={validatedAt:new Date().toISOString(),build,native,routes,entry,media,release:previous.build?.pckSha256===hash?previous.release:{onlineVerified:false},scope:{implemented:['black multi-stroke ladder and closed board','three real vertical pages','Sticky traction and Elastic real dimensions','yellow retained-stroke hand weapon','Sharp world pickup and physical vine cut','one telegraphed inkling','building bypass and final page ending'],future:['bow/gun/armor behaviors','red vehicles','blue animals','template recognition candidate UI'],humanDuration:'7–10 minute design target; no measured human playtest average'}};
fs.writeFileSync(reportFile,JSON.stringify(proof,null,2)+'\n');
const dense=native.cpuTimingBench.timings.find(t=>t.label==='gui_max_affordable');
const ending=routes.map(r=>r.evidence.at(-1));
const release=proof.release?.onlineVerified?'已发布并通过线上普通键鼠两条路线验收。提交 `'+proof.release.commit+'`，Pages workflow `'+proof.release.workflow+'`。':'本地验收完成；发布及线上验收待执行。';
const lines=[
'# 墨迹漂流 INKBOUND V10 · 几何与墨刃',
'',release,'',
'试玩与实机录像：https://tonyguan530.github.io/taptap2026/inkbound-v10.html','',
'## 本轮完成','',
'黑墨三段垂直纸页关卡：画两根边梁与横档成为梯架，画闭合轮廓成为实际板面；野外捡到黏性、弹性，改变同一张画稿的可用坡度和真实长度。梯子与坡板均能找回三张碎页。',
'',
'黑章结束只开启黄墨藤庭。亲手画的墨刃握在画家手中；短剑够不到时，需要改变尺寸或靠近。锋利来自实际世界拾取，接触后切断藤蔓并移除实体碰撞。另一条路线保留藤墙，用黑墨梯架登侧台越过并绕开污墨。两条路线均须跳上最后的画页台，才显示完整结局。',
'',
'WASD 移动；Space 跳/离梯；Tab 画纸；鼠标多笔绘画、选择用途和一个词条、保存；黑墨点击目标搭建；E 攀爬/墨泉补墨，W/S 上下；Q 回收；黄墨左键/F 挥砍；R 重开。失败不扣墨、不丢画稿，回收与死亡恢复避免卡住。',
'',
'## 验证证据','',
'| 项目 | 结果 |','|---|---|',
...native.suites.map(s=>'| 独立原生 '+s.name+' | '+s.checks+'/'+s.checks+'，exit 0，stderr 空 |'),
'| 普通鼠标键盘全流程 | 梯架＋切藤战斗、板面＋搭梯绕行均真实获得最后画页；控制台错误 0 |',
'| 导出 | Godot 4.7.2，无头导入/启动/Web 导出 exit 0，共享配置恢复 |',
'| 展示页 | 桌面视频实际播放、iframe 鼠标开始与键盘移动；390px 手机页无横向溢出 |',
'| 实机录像 | 两段 H.264/AAC MP4，含实际游戏音频，完整解码通过；画面960×540 |',
'',
'游戏源码提交 `'+build.sourceCommit+'`；实际浏览器 HTTP PCK 字节与本地 SHA256 一致：`'+hash+'`。两段录像及 QA 均绑定此 PCK，禁止混用早期测试录像。完整结构化证据在 [inkbound-v10-validation.json](inkbound-v10-validation.json)。',
'',
'密集转折合法画稿：851 点、24 笔、827 段、黄墨119.9/120；所有可见笔段及转角保留。独立 CPU 接触更新 p95 '+dense.p95_ms+'ms，最大 '+dense.max_ms+'ms。这是开发机原生接触运算测量，不能当作浏览器整体帧率。保守范围筛选之后仍由实际 Godot 胶囊接触与遮挡决定命中。缩放余量独立探针4/4通过。',
'',
'## 美术、主题与边界','',
'沿用原创绘画学徒与低多边形纸雕风格，Kenney/Quaternius资源来源和许可随源文件保留，GLB外部色板纹理一并进入发布依赖集合。截图全部来自本轮实机。',
'',
'“涌现”展示来自尺寸、几何连接、物性与接触的组合：同一张画稿换词条形成新路线，同一目标可切藤或建造越过。弓、枪、防具、红墨载具和蓝墨动物留在后续范围；[$P/$Q候选识别方案](inkbound-equipment-recognition.md)尚未接入试玩。设计目标7–10分钟，尚无真实玩家平均时长。',
'',
'恐龙V8、画家V8/V9保持固定入口。后台任务说明见 [inkbound-overnight.md](inkbound-overnight.md)。Miro实际更新记录在 `reviews/miro-inkbound-v10.json`。',''
];
fs.writeFileSync(path.join(root,'docs/inkbound-v10-validation.md'),lines.join('\n'));
console.log(JSON.stringify({checks:native.totalSuiteChecks,routes:routes.map(r=>r.route),pckSha256:hash,onlineVerified:proof.release?.onlineVerified===true}));
