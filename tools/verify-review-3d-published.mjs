import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),base=process.env.REVIEW_3D_URL||'https://tonyguan530.github.io/taptap2026',checks=[];
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
async function get(p){const r=await fetch(base+'/'+p+'?review='+Date.now());if(!r.ok)throw Error(p+' HTTP '+r.status);return Buffer.from(await r.arrayBuffer());}
function check(ok,name){checks.push({name,passed:!!ok});if(!ok)throw Error(name);}
const slots=JSON.parse(await get('demos.json')).slots,archive=JSON.parse(await get('archive.json')).items;
let runtime;
for(const id of ['demo-09-3d-v1','demo-10-3d-v2','demo-11-3d-v1']){
 const slotId=id.replace(/-v\d+$/,'');check(slots.filter(s=>s.id===slotId&&s.buildId===id&&!s.hidden).length===1,id+' visible unique hub card');check(slots.some(s=>s.id===slotId.slice(0,-3)&&!s.hidden),id+' retains 2D');check(archive.some(s=>s.id===id&&s.status==='active'),id+' active archive entry');
 const local=JSON.parse(fs.readFileSync(path.join(root,'builds',id,'build.json'))),live=JSON.parse(await get('builds/'+id+'/build.json'));check(live.mainScene===local.mainScene&&live.sourceCommit===local.sourceCommit,id+' correct source and scene');check(hash(await get('builds/'+id+'/index.pck'))===hash(fs.readFileSync(path.join(root,'builds',id,'index.pck'))),id+' online PCK equals local');
 const html=(await get('builds/'+id+'/index.html')).toString();check(html.includes('mainPack":"index.pck"')&&html.includes(live.runtime.path.replace(/\.wasm$/,'')),id+' shared runtime configured');runtime=live.runtime;
}
check(hash(await get(runtime.path))===runtime.sha256,'online shared engine SHA256');
for(const name of ['index.audio.worklet.js','index.audio.position.worklet.js']){const rel=runtime.path.replace('index.wasm',name);check(hash(await get(rel))===hash(fs.readFileSync(path.join(root,'public',rel))),'online '+name+' SHA256');}
const result={verifiedAt:new Date().toISOString(),base,passed:true,checks};fs.writeFileSync(path.join(root,'reviews/release-09-11/published.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
