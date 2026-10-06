import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd(),file=path.join(root,'reviews/miro-inkbound-v10.json');
const proof=JSON.parse(fs.readFileSync(path.join(root,'docs/inkbound-v10-validation.json'),'utf8'));
if(!proof.release?.onlineVerified || !proof.release?.commit || !proof.release?.workflow)throw Error('Online release acceptance required before marking Miro complete');
const secrets=JSON.parse(fs.readFileSync('D:/GIT/taptap2026/data/secrets.json','utf8'));
const token=secrets.miro?.value,board=secrets.miro_board?.value;
if(!token||!board)throw Error('Miro credentials missing');
const base='https://api.miro.com/v2/boards/'+encodeURIComponent(board);
async function request(method,route,body,multipart=false){
  const response=await fetch(base+route,{method,headers:{Authorization:'Bearer '+token,...(multipart?{}:{'Content-Type':'application/json'})},body:body?(multipart?body:JSON.stringify(body)):undefined,signal:AbortSignal.timeout(30000)});
  if(!response.ok){
    const detail=await response.json().catch(()=>({}));
    const message=String(detail.message||detail.code||'').replaceAll(token,'[redacted]').slice(0,600);
    throw Error('Miro '+method+' '+route+' HTTP '+response.status+' '+message);
  }
  return response.json();
}
const log=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):{board,items:[],createdAt:new Date().toISOString()};
function save(){fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,JSON.stringify(log,null,2)+'\n');}
// Frame backgrounds use Miro's documented palette.
if(!log.frame){const frame=await request('POST','/frames',{data:{title:'INKBOUND V10 · 几何与墨刃 · 已发布实机',type:'freeform'},style:{fillColor:'#fff9b1'},position:{x:28500,y:6900},geometry:{width:2400,height:2400}});log.frame=frame.id;save();}
// Keep the new frame in the inspected empty area to the right of the idea board.
const frame=await request('GET','/items/'+log.frame);
if(frame.position.x!==28500||frame.position.y!==6900)await request('PATCH','/frames/'+log.frame,{position:{x:28500,y:6900}});
const url=proof.release.url;
const sections=[
  ['主题：规则组合产生通路','黑墨限定建造几何，黄墨限定手持墨刃。实际原笔迹决定长度、宽度与碰撞；野外拾取的词条改变同一张画稿。手动意图选择保障可靠性，后续 $P/$Q 有限模板候选只帮助选择用途。没有把自由画枪、动物、载具标为已完成。',600,190],
  ['黑墨三段垂直关卡','低台 → 庭院高台 → 书塔，均可搭真实多笔梯架或闭合板面。短梯够不到时不会扣墨；弹性1.4倍改变真实轮廓与可达高度；黏性改变板面坡度与摩擦限制。E 攀爬、W/S 上下、Space 离梯，墨泉与回收支持试错。',1800,190],
  ['黄墨藤庭：同一目标两种解法','实际画剑：短剑够不到；同一长剑加“锋利”后接触切断软藤、移除碰撞，再击退污墨。另一条完整录像仍用黑墨搭梯登上侧台，越过保持实体的藤墙并绕开污墨。最终必须真实抵达末页，黑章结束只是转章。',600,625],
  ['独游方向与实机入口','奶油纸雕平台、青绿树林、深墨线条、金黄墨刃；沿用原绘画学徒角色。下方图片全部是实际导出游戏截图。\n已验证桌面试玩、手机展示页和含游戏音频的两条完整录像。\n'+url+'\n发布提交 '+proof.release.commit+'；Pages workflow '+proof.release.workflow+'。',1800,625]
];
for(let i=0;i<sections.length;i++){
  const [title,body,x,y]=sections[i];
  const content='<p><strong>'+title+'</strong></p>'+body.split('\n').map(t=>'<p>'+t+'</p>').join('');
  const existing=log.items.find(x=>x.key==='text-'+i);
  const bodyData={data:{content},style:{fontSize:24,color:'#263d47'},geometry:{width:1050},parent:{id:log.frame},position:{x,y}};
  const item=await request(existing?'PATCH':'POST',existing?'/texts/'+existing.id:'/texts',bodyData);
  if(!existing)log.items.push({key:'text-'+i,id:item.id});save();
}
for(const [key,name,x,y]of [['world','world.png',600,1150],['ladder','ladder.png',1800,1150],['yellow','yellow.png',600,1830],['ending','ending.png',1800,1830]]){
  if(log.items.some(item=>item.key===key))continue;
  const form=new FormData();form.append('resource',new Blob([fs.readFileSync(path.join(root,'public/inkbound-v10-art',name))],{type:'image/png'}),name);
  form.append('data',JSON.stringify({title:'V10 实机 · '+key,parent:{id:log.frame},position:{x,y},geometry:{width:1050}}));
  const item=await request('POST','/images',form,true);log.items.push({key,id:item.id});save();
}
// Feedback Slide explicitly asks authors to mark completed feedback themselves.
if(!log.feedbackNote){
  // The nested Feedback Slide rejects new-child positions. Append to its existing
  // author-completion instruction, preserving the original text and geometry.
  const id='3458764685857034952',actual=await request('GET','/items/'+id);
  const marker='FB-103 · INKBOUND V10';
  if(!actual.data.content.includes(marker))await request('PATCH','/texts/'+id,{data:{content:actual.data.content+'<p><strong>✅ '+marker+' 已修复</strong></p><p>真实多笔绘画＋野外词条；切藤战斗／搭建绕行两条路线已在线通关。<a href="'+url+'">试玩与含游戏音频的实机录像</a></p>'}});
  const saved=await request('GET','/items/'+id);
  if(!saved.data?.content?.includes(marker)||!saved.data.content.includes(url))throw Error('Feedback completion readback mismatch');
  log.feedbackNote=id;log.feedbackMode='append-existing-instruction';save();
}
const verified=[];for(const item of [...log.items,{key:'feedback',id:log.feedbackNote}]){const actual=await request('GET','/items/'+item.id);verified.push({key:item.key,id:actual.id,type:actual.type});}
log.verified=verified;log.verifiedAt=new Date().toISOString();log.release=proof.release;log.url='https://miro.com/app/board/'+encodeURIComponent(board)+'/?moveToWidget='+log.frame;save();
console.log(JSON.stringify({url:log.url,verified:verified.length}));
