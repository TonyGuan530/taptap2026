import {createRequire} from 'node:module';
import {mkdirSync,writeFileSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url);
const {chromium}=require('D:/Apps/NodeJS/node_modules/@playwright/mcp/node_modules/playwright');
const {PNG}=require('D:/Apps/NodeJS/node_modules/@playwright/mcp/node_modules/playwright-core/lib/utilsBundle.js');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const base=process.env.DEMO08_REVIEW_URL||'http://127.0.0.1:8794';
const surface=base.startsWith('https:')?'online':'local';
const shots=path.join(root,'reviews/shots');mkdirSync(shots,{recursive:true});
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const page=await browser.newPage({viewport:{width:960,height:540}});
const messages=[],errors=[],checks=[];let passed=false;
page.on('console',m=>{messages.push(m.text());if((m.type()==='error'||/SCRIPT ERROR|^ERROR:/.test(m.text()))&&!m.text().includes('favicon'))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
const count=tag=>messages.filter(m=>m.includes(tag)).length;
const latestModel=()=>messages.filter(m=>m.includes('WORKBENCH|model|')).at(-1)||'';
function assert(ok,name){checks.push({name,passed:Boolean(ok)});if(!ok)throw Error(name);}
async function wait(check,name){const start=Date.now();while(!check()&&Date.now()-start<20000){if(errors.length)throw Error(errors.join('\n'));await page.waitForTimeout(80);}assert(check(),name);}
async function shot(stage){await page.screenshot({path:path.join(shots,'demo-08-3d-v31-'+stage+'-'+surface+'.png')});}
async function angle(value){const old=count('WORKBENCH|angle|');await page.mouse.dblclick(822,129);await page.keyboard.press('Control+A');await page.keyboard.type(String(value));await page.keyboard.press('Enter');await wait(()=>count('WORKBENCH|angle|')>old&&latestModel().includes('angles='+value.toFixed(1)), 'numeric angle '+value);}
async function charge(){const old=count('PAPER|launch|');await page.keyboard.down('Space');await page.waitForTimeout(1300);await page.keyboard.up('Space');await wait(()=>count('PAPER|launch|')>old,'physical launch');}
try{
 await page.goto(base+'/builds/demo-08-3d-v31/index.html');await page.waitForFunction(()=>!document.getElementById('status'),{timeout:45000});await page.locator('canvas').focus();await page.waitForTimeout(450);await shot('sheet');

 await page.mouse.click(397,30);await wait(()=>count('WORKBENCH|starter|')===1,'editable flying starter');
 await page.mouse.click(850,505);await wait(()=>count('PAPER|aim|angle=12')===1,'preflight before flight');

 const pose=()=>messages.filter(m=>m.includes('PAPER|pose|')).at(-1)||'';
 const launches=count('PAPER|launch|');const original=await page.screenshot();
 async function number(axis,value,submit=true){await page.mouse.dblclick(860,194+axis*68);await page.keyboard.press('Control+A');await page.keyboard.type(String(value),{delay:160});if(submit){await page.keyboard.press('Enter');await page.waitForTimeout(120);}}
 await page.mouse.move(720,194);await page.mouse.down();await page.mouse.move(795,194,{steps:12});await page.mouse.up();await wait(()=>pose().includes('xyz=180,0,0'),'X slider can rotate to 180 degrees');
 await number(0,-30);await wait(()=>pose().includes('xyz=-30,0,0'),'signed X pitch');await number(0,30);
 await page.mouse.move(713,262);await page.mouse.down();await page.mouse.move(744,262,{steps:8});await page.mouse.up();assert(!pose().includes('xyz=30,0,0'),'Y slider changes yaw');await number(1,45);
 await number(2,-25);await wait(()=>pose().includes('xyz=30,45,-25'),'XYZ values remain independently selected');await shot('xyz-pose');
 const initial=PNG.sync.read(original),rotated=PNG.sync.read(await page.screenshot());let changed=0;for(let y=230;y<390;y++)for(let x=350;x<548;x++){const p=(y*initial.width+x)*4;let d=0;for(let c=0;c<3;c++)d+=Math.abs(initial.data[p+c]-rotated.data[p+c]);if(d>60)changed++;}assert(changed>100,'rotated 3D plane visibly changes before flight');
 const saved=pose();await page.mouse.move(250,120);await page.waitForTimeout(180);assert(pose()===saved,'mouse movement does not overwrite XYZ');assert(count('PAPER|launch|')===launches,'rotating does not launch');
 await page.mouse.click(744,405);await wait(()=>pose().includes('xyz=12,0,0'),'reset restores 12/0/0');await number(2,-177,false);await page.mouse.click(744,405);await page.waitForTimeout(250);assert(pose().includes('xyz=12,0,0'),'reset discards pending Z text after focus exit');await number(0,30);await number(1,45);await number(2,-25);await number(1,60,false);
 await page.mouse.move(744,456);await page.mouse.down();await wait(()=>pose().includes('xyz=30,60,-25'),'charge commits pending Y number without Enter');await page.waitForTimeout(1300);await shot('charge-locked');const locked=pose();await page.keyboard.press('ArrowUp');await page.mouse.move(360,80);await page.waitForTimeout(150);assert(pose()===locked,'charging locks XYZ');await page.mouse.up();
 await wait(()=>count('PAPER|launch|')>launches,'release outside button launches');assert(messages.filter(m=>m.includes('PAPER|launch|')).at(-1).includes('rotation=30,60,-25|'),'physical launch uses full XYZ pose');
  await wait(()=>count('PAPER|land|')>=1,'practice landing');await shot('land');await page.mouse.click(880,24);await wait(()=>messages.some(m=>m.includes('PAPER|menu|levels=5')),'five-level menu');await page.mouse.click(216,216);
 for(let i=1;i<=5;i++){await wait(()=>messages.some(m=>m.includes('PAPER|level|'+i+'|practice=false')),'level '+i);const old=count('WORKBENCH|starter|');await page.mouse.click(397,30);await wait(()=>count('WORKBENCH|starter|')>old,'level starter '+i);await page.mouse.click(850,505);await wait(()=>pose().includes('xyz=12,0,0'),'new level resets pose '+i);await charge();await wait(()=>messages.some(m=>m.includes('PAPER|course|'+i+'|pass=true')),'level cleared '+i);await page.mouse.click(360,385);}
 await wait(()=>messages.some(m=>m.includes('PAPER|final|levels=5')),'five-level final');await shot('final');assert(errors.length===0,'no browser or script errors');passed=true;
}finally{await browser.close();const result={verifiedAt:new Date().toISOString(),base,build:'demo-08-3d-v31',passed,checks,telemetry:messages.filter(m=>/PAPER\||WORKBENCH\|/.test(m)),errors};writeFileSync(path.join(root,'reviews/demo08-preflight-xyz-browser-'+surface+'.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));}
process.exitCode=passed?0:1;
