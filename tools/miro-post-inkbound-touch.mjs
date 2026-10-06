import fs from 'node:fs';
const secrets=JSON.parse(fs.readFileSync('D:/GIT/taptap2026/data/secrets.json','utf8'));
const token=secrets.miro?.value,board=secrets.miro_board?.value;
if(!token||!board)throw Error('Miro connection unavailable');
const api='https://api.miro.com/v2/boards/'+encodeURIComponent(board);
async function request(method,route,body){
 const response=await fetch(api+route,{method,headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(30000)});
 if(!response.ok)throw Error('Miro '+method+' HTTP '+response.status);
 return response.json();
}
const ids={design:'3458764686237509355',release:'3458764686237509427',feedback:'3458764685857034952'};
if(process.argv.includes('--read')){
 for(const [key,id]of Object.entries(ids)){
  const item=await request('GET','/items/'+id);
  console.log(JSON.stringify({key,id,content:item.data?.content}));
 }
}else{
 const proof=JSON.parse(fs.readFileSync('docs/inkbound-touch-validation.json','utf8'));
 const designOnly=process.argv.includes('--design-only');
 if(!designOnly&&!proof.release?.onlineVerified)throw Error('Online touch release verification required');
 const marker='INKBOUND-TOUCH-20261007';
 const additions={
  design:'<p><strong>'+marker+' · GD／编剧新提案，尚未实现</strong></p><p>V10 多解不等于涌现。新主旨：可信结构＋相符词条授能，梯子外观不能自动可攀爬。取消墨色用途锁；首片可攀爬＋漂浮、两槽、一个开放邮台目标。能力读取结构，目标只认结果；同一稿从无能力到授能，再在新处境复用。需自由试玩验证。</p><p><a href="https://github.com/TonyGuan530/taptap2026/blob/main/docs/inkbound-emergence-redesign.md">修订策划</a> · <a href="https://github.com/TonyGuan530/taptap2026/blob/main/docs/inkbound-gd-writer-review.md">独立评审</a></p>',
  release:'<p><strong>'+marker+' · 触控补丁已上线</strong></p><p><a href="'+(proof.release?.url||'')+'">手机横屏触控试玩</a>：摇杆、独立手指点控与手绘。147 项原生检查及两条浏览器路线通过。实体 Android／iOS 尚未验证；新授能规则仍是提案。</p>',
 };
 const results=[];
 for(const key of (designOnly?['design']:['design','release'])){
  const item=await request('GET','/items/'+ids[key]);
  const original=item.data?.content;if(typeof original!=='string')throw Error('Owned Miro text missing');
  const content=original.includes(marker)?original:original+additions[key];
  if(content!==original)await request('PATCH','/texts/'+ids[key],{data:{content}});
  const readback=await request('GET','/items/'+ids[key]);
  if(!readback.data?.content.includes(marker))throw Error('Miro readback failed');
  results.push({key,id:ids[key],verified:true,geometry:readback.geometry,position:readback.position});
 }
 fs.writeFileSync('reviews/miro-inkbound-touch.json',JSON.stringify({date:new Date().toISOString(),board,frame:'3458764686237509345',results,release:proof.release,designStatus:'proposal only, not implemented'},null,2)+'\n');
 console.log(JSON.stringify({verified:results.length}));
}
