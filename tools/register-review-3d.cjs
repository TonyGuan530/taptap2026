const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),specs=[
 {id:'demo-09-3d',buildId:'demo-09-3d-v1',title:'赛车模拟器 3D · 造车与驾驶',goal:'选关进入车库，选择车身和轮胎布局后发车；真实3D刚体，W/S油门与倒车，A/D转向。'},
 {id:'demo-10-3d',buildId:'demo-10-3d-v2',title:'修改小说 · 可探索3D世界',goal:'WASD探索小说世界，Tab打开手稿，点击词语修改正文与3D场景；E调查，Esc释放鼠标。'},
 {id:'demo-11-3d',buildId:'demo-11-3d-v1',title:'箱庭谜题 3D · 推箱与工具',goal:'方向键移动与推箱，压板开门；F冻结、G灼烧、H磁铁，工具随关卡解锁；滚轮观察，Home复位镜头。'}
];
const read=p=>JSON.parse(fs.readFileSync(path.join(root,p),'utf8')),write=(p,v)=>fs.writeFileSync(path.join(root,p),JSON.stringify(v,null,2)+'\n');
const demos=read('public/demos.json'),archive=read('public/archive.json'),feedback=read('public/feedback-board.json');
for(const [i,s] of specs.entries()){
 demos.slots=demos.slots.filter(v=>v.id!==s.id);const index=demos.slots.findIndex(v=>v.id===s.id.slice(0,-3));demos.slots.splice(index+1,0,{...s,status:'done'});
 archive.items=archive.items.filter(v=>v.id!==s.buildId);archive.items.unshift({id:s.buildId,title:s.title,status:'active',revivable:true,reason:'用户授权上传3D评审版；原2D版本保留，待最终反馈。'});
 const fb=feedback.items.find(v=>v.id==='FB-'+(105+i));if(fb){fb.status='responded';fb.reply='3D评审版已发布，待用户复测：https://tonyguan530.github.io/taptap2026/builds/'+s.buildId+'/index.html';fb.fixedIn=s.buildId;}
}
write('public/demos.json',demos);write('public/archive.json',archive);write('public/feedback-board.json',feedback);
const patches={'game/demo09_3d.gd':'Preserve selected body and wheel lateral positions on launch/retry; exclude vehicle from chase camera.', 'game/demo10_3d/chapter_world.gd':'Build station ribs from three thin bars instead of solid corridor-sized boxes.'};
const manifest=read('reviews/release-09-11/source-manifest.json');for(const entry of manifest.files){if(patches[entry.path]){entry.baseSha256 ||= entry.sha256;entry.sha256=crypto.createHash('sha256').update(fs.readFileSync(path.join(root,entry.path))).digest('hex');entry.patch=patches[entry.path];}}
write('reviews/release-09-11/source-manifest.json',manifest);
const releases=read('reviews/release-09-11/exports.json');for(const entry of releases)entry.pckSha256=crypto.createHash('sha256').update(fs.readFileSync(path.join(root,'builds',entry.buildId,'index.pck'))).digest('hex');write('reviews/release-09-11/exports.json',releases);
console.log('Registered three 3D slots and retained 2D slots.');
