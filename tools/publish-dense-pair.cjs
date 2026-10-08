const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const entries=[{slot:'demo-05',id:'demo-05-valley-v9',title:'恐龙 · 小山谷营地',goal:'在营地附近采集、搭建休息棚；火山提前到来，带着营地计划转向地下避难。'},{slot:'demo-06',id:'demo-06-courtyard-v11',title:'INKBOUND · 一件作品的小庭院',goal:'在小庭院画一件梯架，攀登三个目标；Z回收返还墨水，保留图纸继续搭建。'}];
for(const e of entries){
 const dir=path.join(root,'builds',e.id),htmlPath=path.join(dir,'index.html'),wasm=path.join(dir,'index.wasm');
 if(!fs.existsSync(path.join(dir,'index.pck')))throw Error('Missing export '+e.id);
 const runtime='runtime/godot-4.7.2-fc74679e3b97/index.wasm',shared=path.join(root,'public',runtime);
 const existing=fs.readFileSync(shared),bytes=fs.existsSync(wasm)?fs.readFileSync(wasm):existing;
 const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
 if(hash(bytes)!==hash(existing))throw Error('Engine mismatch '+e.id);
 let html=fs.readFileSync(htmlPath,'utf8');
 html=html.replace(/const GODOT_CONFIG = (\{.*\});/,(_m,j)=>{const c=JSON.parse(j),exe='../../'+runtime.slice(0,-5);c.executable=exe;c.mainPack='index.pck';delete c.fileSizes['index.wasm'];c.fileSizes[exe+'.wasm']=bytes.length;return 'const GODOT_CONFIG = '+JSON.stringify(c)+';';});
 fs.writeFileSync(htmlPath,html);if(fs.existsSync(wasm))fs.unlinkSync(wasm);
 fs.writeFileSync(path.join(dir,'build.json'),JSON.stringify({title:e.title,version:e.id,date:new Date().toISOString(),author:'codex',notes:e.goal,runtime:{path:runtime,sha256:hash(existing)}},null,2)+'\n');
}
const demosPath=path.join(root,'public/demos.json'),archivePath=path.join(root,'public/archive.json');
const demos=JSON.parse(fs.readFileSync(demosPath)),archive=JSON.parse(fs.readFileSync(archivePath));
for(const e of entries){
 const canonical=demos.slots.find(s=>s.id===e.slot),old=canonical.buildId;
 for(const s of demos.slots.filter(s=>s.id===e.slot||s.canonicalSlot===e.slot)){s.buildId=e.id;s.title=e.title;s.goal=e.goal;s.status='done';delete s.landingUrl;}
 for(const item of archive.items.filter(i=>i.id===old&&old!==e.id)){item.status='archived';item.archivedAt='2026-10-07';item.reason='由密集体验快速迭代版替代；旧构建保留。';}
 archive.items=archive.items.filter(i=>i.id!==e.id);archive.items.unshift({id:e.id,title:e.title,status:'active',revivable:true,reason:e.goal});
}
fs.writeFileSync(demosPath,JSON.stringify(demos,null,2)+'\n');fs.writeFileSync(archivePath,JSON.stringify(archive,null,2)+'\n');
console.log(JSON.stringify(entries));
