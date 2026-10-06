import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
const root=process.cwd(),target=path.resolve(root,'.codex-tmp/inkbound-publish'),files=new Set();
if(!target.startsWith(path.join(root,'.codex-tmp')+path.sep))throw Error('Publication path outside task scratch');
function git(args){return execFileSync('git',['-C',target,...args],{encoding:'utf8',stdio:['ignore','pipe','pipe'],windowsHide:true}).trimEnd();}
if(git(['rev-parse','HEAD'])!==git(['rev-parse','origin/main']))throw Error('Reset task publication checkout to freshly fetched main before preparing');
function include(relative,required=true){
  relative=relative.replaceAll('\\','/');
  if(files.has(relative)||relative.includes('/.godot/')||relative.startsWith('game/.godot/'))return;
  if(/secrets|\.codex-tmp|raw\.webm/i.test(relative))throw Error('Private file in release manifest');
  const absolute=path.join(root,relative);
  if(!fs.existsSync(absolute)||!fs.statSync(absolute).isFile()){if(required)throw Error('Missing release dependency '+relative);return;}
  files.add(relative);
  if(/\.(gd|tscn|tres|gdshader|import)$/.test(relative)){
    const source=fs.readFileSync(absolute,'utf8');
    for(const m of source.matchAll(/res:\/\/([^"'\n\r]+?)(?=["'])/g))include('game/'+m[1]);
  }
  if(/\.(gd|gdshader)$/.test(relative))include(relative+'.uid',false);
  if(/\.(glb|fbx|png|jpg|jpeg|webp|tga|ttf)$/.test(relative))include(relative+'.import',false);
  if(relative.endsWith('.glb')){
    const binary=fs.readFileSync(absolute);
    if(binary.readUInt32LE(0)!==0x46546c67)throw Error('Invalid GLB dependency '+relative);
    for(let offset=12;offset+8<=binary.length;){
      const length=binary.readUInt32LE(offset),type=binary.readUInt32LE(offset+4);offset+=8;
      if(offset+length>binary.length)throw Error('Truncated GLB dependency '+relative);
      if(type===0x4e4f534a){
        const json=JSON.parse(binary.subarray(offset,offset+length).toString('utf8'));
        for(const asset of [...(json.images||[]),...(json.buffers||[])]){
          if(!asset.uri||asset.uri.startsWith('data:'))continue;
          if(/^[a-z]+:/i.test(asset.uri))throw Error('Unsupported external GLB URI '+relative);
          const dependency=path.resolve(path.dirname(absolute),decodeURIComponent(asset.uri));
          if(!dependency.startsWith(root+path.sep))throw Error('GLB dependency outside repository '+relative);
          include(path.relative(root,dependency));
        }
      }
      offset+=length;
    }
  }
}
include('game/v10/ink_world.tscn');
include('game/tests/test_ink_v10_blade_perf.gd');
include('tools/build-inkbound-v10-report.mjs');
for(const file of ['tools/overnight-inkbound.mjs','tools/install-inkbound-overnight.ps1','tools/run-inkbound-overnight.ps1','docs/inkbound-overnight.md'])include(file);
for(const file of ['game/tests/test_ink_v10_geometry.gd','game/tests/test_ink_v10_smoke.gd','game/tests/test_ink_v10_yellow.gd','docs/superpowers/specs/2026-10-06-inkbound-colors-design.md','docs/superpowers/plans/2026-10-06-inkbound-colors.md','docs/inkbound-v10-validation.md','docs/inkbound-v10-validation.json','docs/inkbound-equipment-recognition.md','tools/export-inkbound-v10.ps1','tools/verify-inkbound-v10-web.mjs','tools/verify-inkbound-v10-entry.mjs','tools/build-inkbound-v10-entry.mjs','tools/v8-browser-harness.mjs','tools/prepare-inkbound-v10-publish.mjs','tools/stage-inkbound-v10-publish.mjs','tools/miro-post-inkbound-v10.mjs','public/inkbound-v10.html','game/assets/lowpoly/SOURCES.md','game/fonts/LICENSE-OFL.txt'])include(file);
for(const folder of ['game/assets/lowpoly/kenney-dungeon','game/assets/lowpoly/kenney-forest','game/assets/lowpoly/kenney-nature','game/assets/lowpoly/kenney-nature-v8','game/assets/lowpoly/quaternius-dinosaur']){
  for(const file of fs.readdirSync(path.join(root,folder)))if(/license|source-lock/i.test(file))include(folder+'/'+file);
}
for(const folder of ['public/inkbound-v10-art','builds/demo-06-inkbound-v10'])for(const file of fs.readdirSync(path.join(root,folder)))include(folder+'/'+file);
const manifest=[];
for(const relative of [...files].sort()){
  let bytes=fs.readFileSync(path.join(root,relative));
  // Shared dependency drift must be resolved deliberately, never overwritten silently.
  if(relative.startsWith('game/')&&!relative.startsWith('game/v10/')&&!relative.startsWith('game/tests/')){
    let remote;try{remote=execFileSync('git',['-C',target,'show','HEAD:'+relative],{stdio:['ignore','pipe','pipe'],windowsHide:true});}catch{}
    if(remote&&!remote.equals(bytes)){
      const text=/\.(gd|gdshader|tscn|tres|import|uid|md|txt|json)$/i.test(relative);
      if(text&&remote.toString('utf8').replaceAll('\r\n','\n')===bytes.toString('utf8').replaceAll('\r\n','\n'))bytes=remote;
      else throw Error('Shared source/asset differs from current main: '+relative);
    }
  }
  fs.mkdirSync(path.dirname(path.join(target,relative)),{recursive:true});fs.writeFileSync(path.join(target,relative),bytes);
  manifest.push({file:relative,bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')});
}
const demos=JSON.parse(git(['show','HEAD:public/demos.json']));
const slot=demos.slots.find(s=>s.id==='demo-06-3d');if(!slot)throw Error('Painter card missing from current main');
Object.assign(slot,{title:'墨迹漂流 / INKBOUND（几何与墨刃）',goal:'多笔画梯架与闭合板面，按真实尺寸搭建攀爬；野外拾取弹性与黏性改变通路，三段立体纸页之后用黄墨画武器，切藤或搭建绕行，找回完整画页。',buildId:'demo-06-inkbound-v10',status:'done',landingUrl:'./inkbound-v10.html'});
demos.updatedAt=new Date().toISOString().slice(0,10);
fs.mkdirSync(path.join(target,'public'),{recursive:true});fs.writeFileSync(path.join(target,'public/demos.json'),JSON.stringify(demos,null,2)+'\n');
manifest.push({file:'public/demos.json',note:'Only current painter card changed; other demos preserved from fresh main'});
let homepage=git(['show','HEAD:public/index.html']);
if(!homepage.includes('id="inkbound-v10-feature"')){
  const feature='<section id="inkbound-v10-feature" style="margin:24px 0;padding:22px 26px;border-radius:12px;background:#f1e8d4;color:#2b4751;display:flex;align-items:center;gap:25px;flex-wrap:wrap"><div style="flex:1;min-width:220px"><span style="font-size:11px;letter-spacing:.18em;color:#9e6856">NEW / INKBOUND V10</span><h2 style="margin:8px 0">把笔迹，走成一条路。</h2><p style="font-size:14px;color:#5b7475">黑墨画梯子与坡板，黄墨画武器。野外的词，让原笔迹改变性质。</p><a href="inkbound-v10.html" style="display:inline-block;padding:10px 20px;background:#263d47;color:#f3e8cd;text-decoration:none;border-radius:5px">打开绘本 / 看实机录像 ↗</a></div><a href="inkbound-v10.html" style="flex:0 1 320px"><img src="inkbound-v10-art/world.png" alt="墨迹漂流 V10 实机" style="width:100%;border-radius:6px;display:block"></a></section>';
  if(!homepage.includes('<main class="container">'))throw Error('Homepage insertion point changed');
  homepage=homepage.replace('<main class="container">','<main class="container">\n  '+feature);
}
fs.writeFileSync(path.join(target,'public/index.html'),homepage+'\n');manifest.push({file:'public/index.html',note:'V10 banner added to current main; V8/V9 links preserved'});
fs.writeFileSync(path.join(root,'.codex-tmp/inkbound-v10/publish-manifest.json'),JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({files:manifest.length,megabytes:Math.round(manifest.reduce((n,f)=>n+(f.bytes||0),0)/1048576),target}));
