import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {browser,check,enableAudioCapture} from './v8-browser-harness.mjs';
const root=process.cwd(),dir=path.resolve(process.env.INKBOUND_V10_QA_DIR||path.join(root,'.codex-tmp/inkbound-v10'));
fs.mkdirSync(dir,{recursive:true});
const route=process.argv.includes('--board')?'board':'ladder';
const record=process.argv.includes('--record');
const blackOnly=process.argv.includes('--black-only');
const localPck=path.join(root,'builds/demo-06-inkbound-v10/index.pck');
const buildProof={url:process.env.INKBOUND_V10_URL||'http://127.0.0.1:8788/builds/demo-06-inkbound-v10/index.html?qa=1',expectedPckSha256:createHash('sha256').update(fs.readFileSync(localPck)).digest('hex')};
const b=await browser(),page=await b.newPage({viewport:{width:960,height:540}});
// Retain the complete ~29 MB PCK response rather than Chromium's default small body cache.
const network=await page.context().newCDPSession(page);
await network.send('Network.enable',{maxTotalBufferSize:256*1024*1024,maxResourceBufferSize:96*1024*1024});
let pckTimer;
function receivePck(){
  let requestId,receivedStatus;
  const finished=new Promise((resolve,reject)=>{
    pckTimer=setTimeout(()=>reject(Error('Timed out capturing actual HTTP PCK body')),90000);
    network.on('Network.responseReceived',event=>{
      if(new URL(event.response.url).pathname.endsWith('/demo-06-inkbound-v10/index.pck')){requestId=event.requestId;receivedStatus=event.response.status;}
    });
    network.on('Network.loadingFinished',async event=>{
      if(event.requestId!==requestId)return;
      clearTimeout(pckTimer);
      try{const data=await network.send('Network.getResponseBody',{requestId});resolve({status:receivedStatus,bytes:Buffer.from(data.body,data.base64Encoded?'base64':'utf8')});}catch(error){reject(error);}
    });
    network.on('Network.loadingFailed',event=>{if(event.requestId===requestId){clearTimeout(pckTimer);reject(Error('Actual PCK request failed: '+event.errorText));}});
  });
  finished.catch(()=>{}); // Navigation failures must not leave an unobserved secondary rejection.
  return finished;
}
const errors=[],evidence=[];
page.on('pageerror',e=>errors.push(String(e)));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
const state=()=>page.evaluate(()=>window.__v10_ink_qa);
async function shot(name){await page.waitForTimeout(200);await page.screenshot({path:path.join(dir,route+'-'+name+'.png')});}
async function button(name){const s=await state();check(Array.isArray(s.ui.buttons[name]),'button available '+name);await page.mouse.click(...s.ui.buttons[name]);await page.waitForTimeout(150);}
async function key(name,ms=0){if(ms){await page.keyboard.down(name);await page.waitForTimeout(ms);await page.keyboard.up(name);}else await page.keyboard.press(name);await page.waitForTimeout(110);}
async function move(x,z,tolerance=.28){
  for(const axis of [0,2]){
    let previous=null,stuck=0;
    for(let i=0;i<110;i++){
      const s=await state(),d=(axis===0?x:z)-s.player[axis];
      // A real pickup can open the chapter/result before exact centre arrival.
      if(s.ui.result && s.goals.every(Boolean))return;
      if(Math.abs(d)<tolerance)break;
      const k=axis===0?(d>0?'d':'a'):(d>0?'s':'w');
      const delay=Math.min(320,Math.max(40,Math.abs(d)/3.5*800));
      await page.keyboard.down(k);await page.waitForTimeout(delay);await page.keyboard.up(k);await page.waitForTimeout(100);
      const p=(await state()).player[axis];
      if(previous!==null&&Math.abs(p-previous)<.02)stuck++;else stuck=0;
      previous=p;
      if(stuck>8||i===109)throw Error('Ordinary movement blocked '+JSON.stringify({target:[x,z],player:(await state()).player}));
    }
  }
}
async function stroke(points){
  await page.mouse.move(...points[0]);await page.mouse.down();await page.waitForTimeout(60);
  for(const point of points.slice(1)){await page.mouse.move(...point,{steps:8});await page.waitForTimeout(80);}
  await page.mouse.up();await page.waitForTimeout(80);
}
async function draw(kind,property='None',length=230){
  if(!(await state()).ui.notebook)await key('Tab');
  await button(kind);await button('clear');await button('property_'+property);
  const [x,y]= (await state()).ui.draw_rect;
  if(kind==='ladder'){
    const a=x+100,b=x+165,top=y+285-length,bottom=y+285;
    for(const pts of [[[a,bottom],[a,top]],[[b,bottom],[b,top]],[[a,bottom-length*.3],[b,bottom-length*.3]],[[a,bottom-length*.7],[b,bottom-length*.7]]])await stroke(pts);
  }else if(kind==='board'){
    await stroke([[x+22,y+90],[x+22+length,y+90],[x+22+length,y+175],[x+22,y+175],[x+22,y+90]]);
  }else if(kind==='blade'){
    await stroke([[x+130,y+280],[x+120,y+280-length],[x+140,y+280-length],[x+130,y+280]]);
    await stroke([[x+100,y+267],[x+160,y+267]]);
  }
  let s=await state();check(s.drawing.analysis.ok,'actual mouse strokes form '+kind);
  if(kind==='ladder')check(s.drawing.strokes.length===4,'four separate strokes remain separate');
  await shot('draw-'+kind+'-'+property+'-'+length);
  await button('confirm');s=await state();
  check(!s.ui.notebook&&s.active_tool.kind===kind&&s.active_tool.property===property,'saved actual '+property+' '+kind);
  return s.active_tool;
}
async function aim(name,place=true){const s=await state();check(s.landmarks[name],'landmark '+name);await page.mouse.move(...s.landmarks[name].ground_screen);await page.waitForTimeout(220);if(place){await page.mouse.click(...(await state()).landmarks[name].ground_screen);await page.waitForTimeout(250);}}
async function climb(){
  await key('e');check((await state()).climbing_id>=0,'ordinary E enters physical ladder');
  await page.keyboard.down('w');
  try {await page.waitForFunction(()=>window.__v10_ink_qa.climbing_id<0,null,{timeout:7000});}
  finally {await page.keyboard.up('w');}
  await page.waitForTimeout(150);
  check((await state()).player[1]>1,'climb exits onto actual raised support');
}
function compact(s){return {player:s.player,tool:s.active_tool,words:s.words,ink:s.ink,structures:s.structures,goals:s.goals,yellow_unlocked:s.yellow_unlocked,won:s.won,message:s.ui.message,weapon:s.weapon,vines:s.vines,enemy:s.enemy,combat:s.combat,final_goal:s.final_goal,result_text:s.ui.result_text};}
async function milestone(phase){const s=await state();evidence.push({phase,state:compact(s)});await shot(phase);}
async function faceRight(){await key('d',60);await page.waitForTimeout(350);check((await state()).facing[0]>.9,'ordinary D faces the actual weapon right');}
async function swing(){await key('f');await page.waitForTimeout(800);}
async function finalJump(){
  await move(34.85,0);
  await page.keyboard.down('d');await page.keyboard.press('Space');
  try{await page.waitForFunction(()=>window.__v10_ink_qa.won,null,{timeout:6000});}
  finally{await page.keyboard.up('d');}
  const s=await state();check(s.won&&s.final_goal.collected&&s.ui.result,'physical arrival collects the final page and opens the ending');
  await milestone('ending');
}
async function startRecord(){await page.evaluate(async()=>{
  const canvas=document.getElementById('canvas'),chunks=[],stream=canvas.captureStream(25);
  for(const entry of window.__recordAudio||[]){await entry.context.resume();for(const track of entry.destination.stream.getAudioTracks())stream.addTrack(track);}
  window.__v10Tracks=stream.getAudioTracks().length;
  const r=new MediaRecorder(stream,{mimeType:'video/webm;codecs=vp8,opus',videoBitsPerSecond:3800000});
  r.ondataavailable=e=>{if(e.data.size)chunks.push(e.data);};r.start(1000);
  window.__v10Finish=()=>new Promise(resolve=>{r.onstop=()=>{const reader=new FileReader();reader.onload=()=>resolve(reader.result.slice(reader.result.lastIndexOf(',')+1));reader.readAsDataURL(new Blob(chunks,{type:r.mimeType}));};r.stop();});
});}
async function finishRecord(){const data=await page.evaluate(()=>window.__v10Finish());const bytes=Buffer.from(data,'base64');check(bytes.length>100000&&bytes.subarray(0,4).toString('hex')==='1a45dfa3','valid WebM capture from actual game');fs.writeFileSync(path.join(dir,route+'-play.webm'),bytes);fs.writeFileSync(path.join(dir,route+'-capture.json'),JSON.stringify({bytes:bytes.length,build:buildProof,videoSha256:createHash('sha256').update(bytes).digest('hex'),audioTracks:await page.evaluate(()=>window.__v10Tracks),method:'actual game canvas and audio; ordinary Playwright mouse/keyboard'},null,2)+'\n');}
try{
  if(record)await enableAudioCapture(page);
  const actualPck=receivePck();
  await page.goto(buildProof.url);
  const response=await actualPck;
  check(response.status>=200&&response.status<300,'browser receives the actual exported PCK');
  buildProof.pckSha256=createHash('sha256').update(response.bytes).digest('hex');
  check(buildProof.pckSha256===buildProof.expectedPckSha256,'actual HTTP PCK matches this source export');
  await page.waitForFunction(()=>window.__v10_ink_qa,null,{timeout:60000});await page.waitForTimeout(600);
  check((await state()).version===10,'boot independent V10 build');await shot('intro');
  await button('begin');check(!(await state()).ui.intro,'ordinary click begins adventure');if(record)await startRecord();await milestone('world');
  if(route==='ladder'){
    await move(2.1,0);await draw('ladder','None',60);
    const before=await state();await aim('threshold_goal');let s=await state();
    check(s.structures.length===0&&s.ink.black===before.ink.black,'short ladder keeps drawing and spends no ink');
    await draw('ladder','None',230);await aim('threshold_goal');check((await state()).structures.length===1,'drawn long ladder placed');await climb();
  }else{
    await move(.6,0);await draw('board','None',230);await aim('threshold_goal');check((await state()).structures.length===1,'drawn actual board placed');
  }
  await move(5.1,0);check((await state()).goals[0],'actual movement collects first high page');await milestone('threshold');
  await move(7.6,1);check((await state()).words.includes('Sticky'),'world movement collects Sticky');await move(10.3,0);
  if(route==='ladder'){await aim('courtyard_goal');await climb();}
  else{await draw('board','Sticky',200);await aim('courtyard_goal');}
  await move(13.5,0);check((await state()).goals[1],'actual movement collects second high page');await milestone('courtyard');
  await move(16,1);check((await state()).words.includes('Elastic'),'world movement collects Elastic');await move(route==='board'?18.0:18.6,0);
  if(route==='ladder'){
    const before=await state();await aim('tower_goal');check((await state()).structures.length===before.structures.length,'same unstretched ladder cannot reach taller tower');
    const original=JSON.stringify((await state()).active_tool.segments);await key('Tab');await button('property_Elastic');await button('confirm');
    const elastic=(await state()).active_tool;check(elastic.length>4.4,'Elastic changes actual retained length by 1.4');
    check(JSON.stringify(elastic.segments)!==original,'Elastic changes actual mapped geometry');await aim('tower_goal');await climb();
  }else{await draw('board','Sticky',300);const count=(await state()).structures.length;await aim('tower_goal');check((await state()).structures.length===count+1,'Sticky board placed from a safe slope distance');}
  await move(22,0);let s=await state();check(s.goals.every(Boolean)&&s.yellow_unlocked,'actual three goals unlock yellow ink');await milestone('black-complete');
  if(!blackOnly){
    check(!s.won&&!s.final_goal.collected,'three black pages are a chapter transition, not the final win');
    if(s.ui.result)await button('continue');
    await move(27.5,-.6);check((await state()).words.includes('Sharp'),'ordinary exploration collects Sharp at the vine roots');
    if(route==='ladder'){
      await key('Tab');await button('color_yellow');await key('Tab');
      await draw('blade','Sharp',45);await move(28.55,0);await faceRight();await swing();
      check(!(await state()).vines.cut,'short drawn Sharp blade cannot reach the distant vine');await milestone('short-blade');
      await draw('blade','None',170);await swing();
      check(!(await state()).vines.cut,'long unmodified blade does not cut the vine');
      const original=(await state()).active_tool.length;
      await key('Tab');await button('property_Sharp');await button('confirm');await swing();
      s=await state();check(s.vines.cut&&s.vines.collision===0&&Math.abs(s.weapon.length-original)<.001,'same strokes with Sharp physically cut and remove the obstruction');
      await milestone('yellow');
      await move(32.5,0);const hp=(await state()).combat.hp;
      await page.waitForFunction(h=>window.__v10_ink_qa.combat.hp<h,hp,{timeout:5000});
      check((await state()).combat.hp<hp,'enemy windup causes a real hit rather than contact every frame');await milestone('enemy-hit');
      await move(32.0,0);await faceRight();await swing();await swing();
      check(!(await state()).enemy.alive&&(await state()).enemy.hp===0,'actual drawn blade strikes defeat the inkling');await milestone('enemy-defeated');
    }else{
      await move(27.2,1.15);await key('e');check((await state()).ink.black>=319,'ordinary courtyard fountain refills building ink');
      await move(27.9,.65);await draw('ladder','None',280);await aim('yellow_ledge');await climb();
      await milestone('yellow');await move(32,1.5);
      check(!(await state()).vines.cut&&(await state()).vines.collision!==0,'original black ladder crosses above the still-solid vine');
      check((await state()).enemy.alive,'building route leaves the optional enemy alive');await milestone('black-bypass');
    }
    await finalJump();
  }
  if(record){await page.waitForTimeout(1000);await finishRecord();}
  check(errors.length===0,'no browser or Godot console errors');
}catch(error){evidence.push({failure:String(error),state:await state().catch(()=>null),errors});await shot('failure').catch(()=>{});if(record)await finishRecord().catch(()=>{});throw error;}
finally{clearTimeout(pckTimer);await b.close();fs.writeFileSync(path.join(dir,route+'-qa.json'),JSON.stringify({route,blackOnly,build:buildProof,errors,evidence,method:'ordinary Playwright mouse and physical keyboard; QA read-only'},null,2)+'\n');}
