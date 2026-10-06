import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
const root=process.cwd(),base='https://tonyguan530.github.io/taptap2026/';
const dir=path.join(root,'.codex-tmp/inkbound-v10/remote');fs.mkdirSync(dir,{recursive:true});
const evidence=[];
for(const name of ['ladder-play.mp4','board-play.mp4','world.png','ladder.png','board.png','yellow.png','ending.png']){
  const local=fs.readFileSync(path.join(root,'public/inkbound-v10-art',name));
  const response=await fetch(new URL('inkbound-v10-art/'+name,base),{signal:AbortSignal.timeout(30000)});
  if(!response.ok)throw Error('Release asset HTTP '+response.status+' '+name);
  const remote=Buffer.from(await response.arrayBuffer());
  const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
  if(hash(remote)!==hash(local))throw Error('Deployed asset differs from recorded artifact '+name);
  evidence.push({file:name,bytes:remote.length,sha256:hash(remote)});
}
const cards=await fetch(new URL('demos.json',base)).then(r=>r.json());
if(cards.slots.find(s=>s.id==='demo-06-3d')?.buildId!=='demo-06-inkbound-v10')throw Error('Current painter card must use V10');
const homepage=await fetch(base).then(r=>r.text());
if(!homepage.includes('id="inkbound-v10-feature"'))throw Error('Main homepage V10 feature missing');
const historical=[];
for(const url of ['inkbound.html','builds/demo-06-inkbound-v9/index.html','builds/demo-06-tonight-v8/index.html','builds/demo-05-tonight-v8/index.html']){
  const response=await fetch(new URL(url,base),{signal:AbortSignal.timeout(30000)});
  if(!response.ok||(await response.text()).length<100)throw Error('Historical release missing '+url);
  historical.push({url,status:response.status});
}
fs.writeFileSync(path.join(dir,'assets-qa.json'),JSON.stringify({checkedAt:new Date().toISOString(),base,assets:evidence,card:'demo-06-inkbound-v10',homepage:true,historical},null,2)+'\n');
console.log(JSON.stringify({matchingAssets:evidence.length,historical:historical.length,homepage:true}));
