import {createRequire} from 'node:module';
import {mkdirSync,writeFileSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url);
const {chromium}=require('D:/Apps/NodeJS/node_modules/@playwright/mcp/node_modules/playwright');
const {PNG}=require('D:/Apps/NodeJS/node_modules/@playwright/mcp/node_modules/playwright-core/lib/utilsBundle.js');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const base=process.env.REVIEW_3D_URL||'http://127.0.0.1:8794',surface=base.startsWith('https:')?'online':'local';
const shots=path.join(root,'reviews/shots/release-09-11');mkdirSync(shots,{recursive:true});
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const results=[];
function difference(a,b,rect=[0,0,960,540]){const x=PNG.sync.read(a),y=PNG.sync.read(b);let count=0;for(let j=rect[1];j<rect[3];j++)for(let i=rect[0];i<rect[2];i++){let d=0,p=(j*x.width+i)*4;for(let c=0;c<3;c++)d+=Math.abs(x.data[p+c]-y.data[p+c]);if(d>60)count++;}return count;}
async function run(id,play){
 const page=await browser.newPage({viewport:{width:960,height:540}}),result={id,checks:[],errors:[],messages:[]};results.push(result);
 page.on('pageerror',e=>result.errors.push(e.message));page.on('console',m=>{result.messages.push(m.text());if((m.type()==='error'||/SCRIPT ERROR|^ERROR:/.test(m.text()))&&!m.text().includes('favicon'))result.errors.push(m.text());});
 const assert=(ok,name)=>{result.checks.push({name,passed:!!ok});if(!ok)throw Error(id+': '+name);};
 const shot=async(name)=>{const data=await page.screenshot({path:path.join(shots,id+'-'+name+'-'+surface+'.png')});return data;};
 try{const response=await page.goto(base+'/builds/'+id+'/index.html');assert(response.status()===200,'HTML served');await page.waitForFunction(()=>!document.getElementById('status'),{timeout:60000});await page.locator('canvas').focus();await page.waitForTimeout(800);assert(await page.locator('canvas').isVisible(),'engine canvas ready');await play(page,assert,shot);assert(result.errors.length===0,'no browser or script errors');result.passed=true;}finally{await page.close();}
}
try{
 await run('demo-09-3d-v1',async(p,check,shot)=>{
  const menu=await shot('menu');await p.mouse.click(460,200);await p.waitForTimeout(400);const garage=await shot('garage');check(difference(menu,garage)>10000,'level selection enters garage');
  await p.mouse.click(689,221);for(const x of [615,883]){await p.mouse.click(x,167);for(const side of [612,695]){await p.mouse.click(side,106);await p.mouse.click(750,254);}}await p.waitForTimeout(150);await shot('designed');await p.mouse.click(750,466);await p.waitForTimeout(500);const launch=await shot('launch');check(difference(garage,launch)>10000,'valid design launches vehicle');
  await p.keyboard.down('w');await p.waitForTimeout(2500);await p.keyboard.up('w');const driven=await shot('driven');check(difference(launch,driven,[0,70,550,510])>5000,'W drives physical vehicle through track');
 });
 await run('demo-10-3d-v2',async(p,check,shot)=>{
  const initial=await shot('world');await p.mouse.click(460,290);await p.keyboard.down('w');await p.waitForTimeout(900);await p.keyboard.up('w');check(difference(initial,await shot('walk'),[0,75,960,500])>3000,'W moves explorer');await p.keyboard.press('Tab');await p.waitForTimeout(400);const manuscript=await shot('manuscript');check(difference(initial,manuscript)>10000,'Tab opens manuscript');
  await p.mouse.click(335,76);await p.waitForTimeout(250);const popup=await shot('choices');check(difference(manuscript,popup)>3000,'click word opens choices');await p.keyboard.press('3');await p.waitForTimeout(450);await shot('edited');await p.keyboard.press('Tab');await p.waitForTimeout(400);check(difference(initial,await shot('rewritten-world'),[0,75,960,500])>10000,'word choice visibly rebuilds 3D world');
 });
 await run('demo-11-3d-v1',async(p,check,shot)=>{
  const initial=await shot('room1');for(const key of ['ArrowRight','ArrowRight','ArrowRight','ArrowRight','ArrowDown','ArrowLeft','ArrowLeft','ArrowLeft','ArrowLeft','ArrowDown','ArrowDown','ArrowDown']){await p.keyboard.press(key);await p.waitForTimeout(130);}await p.waitForTimeout(350);const second=await shot('room2');check(difference(initial,second,[0,0,960,75])>300,'first puzzle changes room HUD');check(difference(initial,second,[0,90,960,520])>5000,'first puzzle rebuilds room geometry');await p.keyboard.press('f');await p.keyboard.press('Home');await p.waitForTimeout(200);await shot('tool');
 });
}finally{await browser.close();const result={verifiedAt:new Date().toISOString(),base,passed:results.length===3&&results.every(r=>r.passed),results};writeFileSync(path.join(root,'reviews/release-09-11/browser-'+surface+'.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({base,passed:result.passed,results:results.map(({id,checks,errors})=>({id,checks,errors}))},null,2));if(!result.passed)process.exitCode=1;}
