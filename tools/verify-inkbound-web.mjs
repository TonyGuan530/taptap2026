import fs from 'node:fs';
import {browser,snapshot,click,drawStroke,check,enableAudioCapture} from './v8-browser-harness.mjs';
const root=process.cwd(),dir=root+'/.codex-tmp/inkbound';fs.mkdirSync(dir,{recursive:true});
const route=process.argv.includes('--float')?'float':'rope',record=process.argv.includes('--record');
const b=await browser(),page=await b.newPage({viewport:{width:960,height:540}}),errors=[],evidence=[];
page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
const state=()=>snapshot(page,'ink');
async function shot(name){await page.waitForTimeout(220);await page.screenshot({path:dir+'/'+route+'-'+name+'.png'});}
function compact(s={}){return {player:s.player,words:s.words,ink:s.ink,hp:s.hp,tool:s.active_tool,puzzles:s.puzzles,ui:s.ui,won:s.won};}
async function move(x,z){
 for(const axis of [0,2])for(let i=0;i<110;i++){
  const s=await state(),d=(axis===0?x:z)-s.player[axis];if(s.dead)throw Error('Player died');if(Math.abs(d)<.17)break;
  const key=axis===0?(d>0?'d':'a'):(d>0?'s':'w');await page.keyboard.down(key);await page.waitForTimeout(Math.min(380,Math.max(35,Math.abs(d)/3.5*750)));await page.keyboard.up(key);await page.waitForTimeout(75);
  if(i===109)throw Error('Walk blocked '+x+','+z+' '+JSON.stringify((await state()).player));
 }
}
async function draw(word,kind='open',short=false){
 if(!(await state()).ui.notebook)await page.keyboard.press('Tab');await page.waitForTimeout(180);let s=await state();
 check(s.words.includes(word),'collected '+word+' in world');
 await click(page,...s.ui.buttons[kind==='closed'?'closed':'open']);await click(page,...s.ui.buttons.clear);await click(page,...s.ui.buttons['word_'+word]);
 s=await state();const [x,y]=s.ui.draw_rect;
 const points=kind==='closed'?[[x+14,y+65],[x+518,y+65],[x+518,y+175],[x+14,y+175]]:short?[[x+20,y+125],[x+60,y+125]]:[[x+20,y+125],[x+160,y+115],[x+330,y+120],[x+510,y+135]];
 await drawStroke(page,points);await shot('drawing-'+word+(short?'-short':''));s=await state();check(s.drawing.vertices>=2,'ordinary pointer creates actual vertices');
 await page.keyboard.press('Enter');await page.waitForTimeout(220);s=await state();check(s.active_tool.word===word&&s.active_tool.kind===kind,'equipped actual '+kind+' '+word);
}
async function use(name){const s=await state();await click(page,...s.landmarks[name].ground_screen,2);await page.waitForTimeout(350);}
async function startRecord(){await page.evaluate(async()=>{
 const canvas=document.getElementById('canvas'),chunks=[],stream=canvas.captureStream(25);
 for(const entry of window.__recordAudio||[]){await entry.context.resume();for(const track of entry.destination.stream.getAudioTracks())stream.addTrack(track);}
 window.__inkboundTracks=stream.getAudioTracks().length;
 const r=new MediaRecorder(stream,{mimeType:'video/webm;codecs=vp8,opus',videoBitsPerSecond:3500000});
 r.ondataavailable=e=>{if(e.data.size)chunks.push(e.data)};r.start(1000);window.__inkboundFinish=()=>new Promise(resolve=>{r.onstop=()=>{const reader=new FileReader();reader.onload=()=>resolve(reader.result.slice(reader.result.lastIndexOf(',')+1));reader.readAsDataURL(new Blob(chunks,{type:r.mimeType}));};r.stop();});
 });}
async function finishRecord(){const data=await page.evaluate(()=>window.__inkboundFinish());const bytes=Buffer.from(data,'base64');check(bytes.length>100000&&bytes.subarray(0,4).toString('hex')==='1a45dfa3','valid WebM file from actual canvas recording');fs.writeFileSync(dir+'/'+route+'-play.webm',bytes);fs.writeFileSync(dir+'/'+route+'-capture.json',JSON.stringify({bytes:bytes.length,audioTracks:await page.evaluate(()=>window.__inkboundTracks),method:'canvas+game audio capture'},null,2)+'\n');}
try{
 if(record)await enableAudioCapture(page);
 await page.goto(process.env.INKBOUND_URL||'http://127.0.0.1:8788/builds/demo-06-inkbound-v9/index.html?qa=1');await page.waitForFunction(()=>window.__v8_ink_qa,null,{timeout:60000});await page.waitForTimeout(800);
 let s=await state();check(!s.settings.open&&s.version===9,'V9 starts without configuration dialog');await shot('start');if(record)await startRecord();
 if(s.ui.intro){await click(page,...s.ui.buttons.begin);await page.waitForTimeout(250);check(!(await state()).ui.intro,'ordinary click dismisses character introduction');await shot('world');}
 const initial=s.loot.filter(l=>!l.id).slice(0,6);for(const l of initial){await move(l.pos[0],l.pos[2]);}
 s=await state();check(s.words.length===6,'ordinary movement picks all six material words');await move(5.8,6);await move(5.8,3);
 await draw('Sticky','open',true);await use('key');s=await state();check(!s.puzzles.key,'short line cannot reach key');check(s.active_tool.word==='Sticky','miss preserves drawn tool');
 await draw('Sticky');await use('key');s=await state();check(s.puzzles.key,'long drawn hook retrieves key and opens gate');await shot('key');evidence.push({phase:'key',state:compact(s)});
 await page.keyboard.press('z');await move(5.8,7);await move(11.45,7);await shot('bank');
 if(route==='rope'){
  await draw('Elastic');await use('anchor');await shot('cast');await page.waitForTimeout(1200);s=await state();check(s.puzzles.river&&s.puzzles.river_route==='elastic_rope','elastic drawn rope physically carries player to far bank');
 }else{
  await draw('Float','closed');
  const original=JSON.stringify((await state()).active_tool.vertices);
  for(const word of ['Heavy','Float']){
   await page.keyboard.press('Tab');await page.waitForTimeout(180);s=await state();await click(page,...s.ui.buttons['word_'+word]);await page.keyboard.press('Enter');await page.waitForTimeout(200);s=await state();
   check(s.active_tool.word===word&&JSON.stringify(s.active_tool.vertices)===original,'same drawn contour can change property to '+word+' without redrawing');
  }
  await page.keyboard.press('r');await page.waitForTimeout(180);check((await state()).ui.message.includes('90'),'ordinary R rotates the closed tool');
  for(let i=0;i<3;i++)await page.keyboard.press('r');
  await use('river_center');s=await state();check(s.active_tool.solids>0,'real closed outline becomes physical floating support');await shot('raft');await move(16.15,7);s=await state();check(s.puzzles.river&&s.puzzles.river_route==='float_contour','ordinary walking crosses actual drawn floating outline');
 }
 await shot('river');evidence.push({phase:'river',state:compact(s)});await page.keyboard.press('z');await move(16.5,7);await page.keyboard.press('e');
 if(route==='rope'){
  await move(17.1,7);await move(17.1,3);await draw('Sharp');await use('vines');s=await state();check(s.puzzles.vines,'drawn sharp line touches and cuts actual vines');await move(21.0,3);await move(24.0,3);await move(24.0,7);
 }else{
  await move(17.1,7);await move(17.1,10.5);await draw('Magnetic');await use('lever');s=await state();check(s.puzzles.turret_disabled,'magnetic drawn line operates actual safety lever');await move(24.0,10.5);await move(24.0,7);
 }
 await move(25,7);await page.keyboard.press('e');await page.waitForTimeout(300);s=await state();check(s.won&&s.ui.result.includes('完成用时'),'full ordinary-input run reaches route-specific ending');await shot('ending');evidence.push({phase:'ending',state:compact(s)});
 if(record){await page.waitForTimeout(1500);await finishRecord();}
 check(!errors.length,'no browser or Godot runtime console errors');
}catch(error){evidence.push({failure:String(error),state:compact(await state().catch(()=>({}))),errors});await shot('failure').catch(()=>{});if(record)await finishRecord().catch(()=>{});throw error;}
finally{await b.close();fs.writeFileSync(dir+'/'+route+'-qa.json',JSON.stringify({route,errors,evidence,method:'ordinary keyboard/pointer only; no game-state edits'},null,2)+'\n');}
