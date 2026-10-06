// Isolated browser capture. No desktop capture, no game-state writes.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
const root=process.cwd();
export const previewDir=path.join(root,'.codex-tmp/v8-preview');
export const videoDir=path.join(root,'public/tonight-v8-videos');
fs.mkdirSync(previewDir,{recursive:true});
export async function browser(){
 const {chromium}=createRequire(path.join(root,'.codex-tmp/lowpoly-tools/package.json'))('playwright-core');
 return chromium.launch({channel:'msedge',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-gpu-sandbox','--autoplay-policy=no-user-gesture-required','--mute-audio']});
}
export function check(ok,label){if(!ok)throw Error(label);console.log('PASS '+label);}
export async function snapshot(page,game){return page.evaluate(name=>window[name],game==='dino'?'__v8_dino_qa':'__v8_ink_qa');}
export async function mouse(page,type,x,y,button=0,buttons=0){
 await page.evaluate(a=>{
  const canvas=document.getElementById('canvas'),last=window.__qaMouse||[a.x,a.y];
  const init={clientX:a.x,clientY:a.y,movementX:a.x-last[0],movementY:a.y-last[1],button:a.button,buttons:a.buttons,bubbles:true,pointerType:'mouse',pointerId:1,isPrimary:true};
  canvas.dispatchEvent(a.type==='mousemove'?new PointerEvent('pointermove',init):new MouseEvent(a.type,init));
  window.__qaMouse=[a.x,a.y];
 },{type,x,y,button,buttons});
}
export async function click(page,x,y,button=0){await mouse(page,'mousemove',x,y);await mouse(page,'mousedown',x,y,button,button===2?2:1);await page.waitForTimeout(100);await mouse(page,'mouseup',x,y,button,0);await page.waitForTimeout(120);}
export async function drawStroke(page,points){
 await mouse(page,'mousemove',...points[0]);await page.waitForTimeout(100);
 await mouse(page,'mousedown',...points[0],0,1);await page.waitForTimeout(100);
 for(const point of points.slice(1)){await mouse(page,'mousemove',...point,0,1);await page.waitForTimeout(160);}
 await mouse(page,'mouseup',...points.at(-1));await page.waitForTimeout(160);
}
export async function shot(page,name){await page.waitForTimeout(180);await page.screenshot({path:path.join(previewDir,name+'.png')});}
export async function enableAudioCapture(page){
 await page.addInitScript(()=>{
  window.__recordAudio=[];const connect=AudioNode.prototype.connect;
  AudioNode.prototype.connect=function(target,...rest){
   const result=connect.call(this,target,...rest);
   if(target instanceof AudioDestinationNode){
    let entry=window.__recordAudio.find(item=>item.context===this.context);
    if(!entry){entry={context:this.context,destination:this.context.createMediaStreamDestination()};window.__recordAudio.push(entry);}
    connect.call(this,entry.destination);
   }
   return result;
  };
 });
}
export async function startRecording(page,game){
 fs.mkdirSync(videoDir,{recursive:true});
 const font=fs.readFileSync(path.join(root,'game/fonts/NotoSansSC-Medium.ttf')).toString('base64');
 await page.evaluate(async ({font,game})=>{
  const face=new FontFace('DemoVideo',`url(data:font/ttf;base64,${font})`);await face.load();document.fonts.add(face);
  const canvas=document.getElementById('canvas'),frame=document.createElement('canvas');frame.width=960;frame.height=620;
  const ctx=frame.getContext('2d');window.__recordCaption=game==='dino'?'恐龙也想开灯｜无限旷野':'涂鸦成真｜野外的词，手里的工具';window.__recordStart=performance.now();window.__recordSegments=[{seconds:0,text:window.__recordCaption}];
  function draw(){
   ctx.drawImage(canvas,0,0,960,540);ctx.fillStyle='#122e33';ctx.fillRect(0,540,960,80);
   ctx.fillStyle='#f5efd9';ctx.font='19px DemoVideo';ctx.textAlign='center';ctx.fillText(window.__recordCaption,480,578);
   ctx.font='12px DemoVideo';ctx.fillStyle='#91bbae';ctx.fillText('V8 实机录制 · 普通键鼠操作',480,606);window.__recordFrame=requestAnimationFrame(draw);
  }draw();
  const stream=frame.captureStream(25);for(const entry of window.__recordAudio||[]){await entry.context.resume();for(const track of entry.destination.stream.getAudioTracks())stream.addTrack(track);}
  const mime=['video/webm;codecs=vp8,opus','video/webm'].find(type=>MediaRecorder.isTypeSupported(type));
  const chunks=[],recorder=new MediaRecorder(stream,{mimeType:mime,videoBitsPerSecond:4500000});recorder.ondataavailable=e=>{if(e.data.size)chunks.push(e.data);};recorder.start(1000);
  window.__finishRecording=()=>new Promise(resolve=>{
   recorder.onstop=()=>{cancelAnimationFrame(window.__recordFrame);const reader=new FileReader();reader.onload=()=>resolve({data:reader.result.slice(reader.result.lastIndexOf(',')+1),audioTracks:stream.getAudioTracks().length,mime:recorder.mimeType,segments:window.__recordSegments});reader.readAsDataURL(new Blob(chunks,{type:recorder.mimeType}));};recorder.stop();
  });
 },{font,game});await page.waitForTimeout(1800);
}
export async function caption(page,text){await page.evaluate(text=>{window.__recordCaption=text;if(window.__recordSegments)window.__recordSegments.push({seconds:(performance.now()-window.__recordStart)/1000,text});},text);console.log('CAPTION '+text);}
export async function finishRecording(page,game){
 const result=await page.evaluate(()=>window.__finishRecording());const bytes=Buffer.from(result.data,'base64');
 check(bytes.length>100000&&bytes.subarray(0,4).toString('hex')==='1a45dfa3','valid actual '+game+' WebM recording');
 const file=path.join(videoDir,game+'-v8-raw.webm');fs.writeFileSync(file,bytes);
 const record={file,audioTracks:result.audioTracks,mime:result.mime,bytes:bytes.length,segments:result.segments};fs.writeFileSync(path.join(videoDir,game+'-capture.json'),JSON.stringify(record,null,2)+'\n');console.log('VIDEO '+JSON.stringify(record));return record;
}
