import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {browser,check} from './v8-browser-harness.mjs';
const dir='.codex-tmp/inkbound-v10-touch',url=process.env.INKBOUND_TOUCH_URL||'https://tonyguan530.github.io/taptap2026/builds/demo-06-inkbound-v10-touch/index.html?qa=1';
const expected=JSON.parse(fs.readFileSync('builds/demo-06-inkbound-v10-touch/build.json','utf8')).pckSha256;
const b=await browser(),page=await b.newPage({viewport:{width:844,height:390},hasTouch:true,isMobile:true});
const c=await page.context().newCDPSession(page),errors=[];
page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
const state=()=>page.evaluate(()=>window.__v10_ink_qa);
async function point(p){const s=await state(),box=await page.locator('#canvas').boundingBox(),scale=Math.min(box.width/s.viewport[0],box.height/s.viewport[1]);return {id:1,x:box.x+(box.width-s.viewport[0]*scale)/2+p[0]*scale,y:box.y+(box.height-s.viewport[1]*scale)/2+p[1]*scale};}
async function touch(type,p){await c.send('Input.dispatchTouchEvent',{type,touchPoints:type==='touchEnd'?[]:[await point(p)]});}
async function tap(p){await touch('touchStart',p);await page.waitForTimeout(110);await touch('touchEnd',p);await page.waitForTimeout(200);}
let timer;
try{
 await c.send('Network.enable',{maxTotalBufferSize:256*1024*1024,maxResourceBufferSize:96*1024*1024});
 const pck=new Promise((resolve,reject)=>{
  let requestId,status;timer=setTimeout(()=>reject(Error('Online PCK timeout')),90000);
  c.on('Network.responseReceived',e=>{if(e.response.url.split('?')[0]===new URL('index.pck',url).href){requestId=e.requestId;status=e.response.status;}});
  c.on('Network.loadingFinished',async e=>{if(e.requestId!==requestId)return;clearTimeout(timer);try{const r=await c.send('Network.getResponseBody',{requestId});resolve({status,bytes:Buffer.from(r.body,r.base64Encoded?'base64':'utf8')});}catch(error){reject(error);}});
 });pck.catch(()=>{});
 await page.goto(url);const response=await pck;
 const hash=createHash('sha256').update(response.bytes).digest('hex');
 check(response.status===200&&hash===expected,'actual online PCK equals the tested touch export');
 await page.waitForFunction(()=>window.__v10_ink_qa?.touch.enabled,null,{timeout:60000});
 await tap((await state()).ui.buttons.begin);check(!(await state()).ui.intro,'online actual touch begins play');
 const before=(await state()).player,centre=(await state()).touch.joystick;
 await touch('touchStart',centre);await touch('touchMove',[centre[0]+64,centre[1]]);await page.waitForTimeout(350);await touch('touchEnd',centre);await page.waitForTimeout(200);
 const after=(await state()).player;check(after[0]>before[0]+.3,'online touch joystick moves actual body');
 await page.screenshot({path:dir+'/online-world.png'});
 await tap((await state()).touch.actions.notebook);
 await page.waitForFunction(()=>window.__v10_ink_qa.ui.notebook);
 const [x,y]=(await state()).ui.draw_rect;
 for(const [a,z]of [[[x+100,y+280],[x+100,y+50]],[[x+170,y+280],[x+170,y+50]],[[x+100,y+110],[x+170,y+110]],[[x+100,y+210],[x+170,y+210]]]){
  await touch('touchStart',a);await touch('touchMove',z);await touch('touchEnd',z);await page.waitForTimeout(150);
 }
 await page.waitForTimeout(250);const drawing=(await state()).drawing;
 check(drawing.strokes.length===4&&drawing.analysis.ok,'online finger input retains four valid ladder strokes');
 await page.screenshot({path:dir+'/online-paper.png'});
 await tap((await state()).ui.buttons.confirm);await page.waitForFunction(()=>!window.__v10_ink_qa.ui.notebook);
 check((await state()).active_tool.kind==='ladder','online paper saves the real drawing');
 check(!errors.length,'online game has no browser or Godot console errors');
 fs.writeFileSync(dir+'/online-smoke.json',JSON.stringify({date:new Date().toISOString(),url,pckSha256:hash,method:'actual CDP touch input, mobile 844x390, read-only QA',passed:true,before,after,strokes:drawing.strokes.length,errors},null,2)+'\n');
}finally{clearTimeout(timer);await b.close();}
