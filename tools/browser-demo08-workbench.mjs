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
async function shot(stage){await page.screenshot({path:path.join(shots,'demo-08-3d-v29-'+stage+'-'+surface+'.png')});}
async function angle(value){const old=count('WORKBENCH|angle|');await page.mouse.dblclick(822,129);await page.keyboard.press('Control+A');await page.keyboard.type(String(value));await page.keyboard.press('Enter');await wait(()=>count('WORKBENCH|angle|')>old&&latestModel().includes('angles='+value.toFixed(1)), 'numeric angle '+value);}
async function charge(){const old=count('PAPER|launch|');await page.keyboard.down('Space');await page.waitForTimeout(1300);await page.keyboard.up('Space');await wait(()=>count('PAPER|launch|')>old,'physical launch');}
try{
 await page.goto(base+'/builds/demo-08-3d-v29/index.html');await page.waitForFunction(()=>!document.getElementById('status'),{timeout:45000});await page.locator('canvas').focus();await page.waitForTimeout(450);await shot('sheet');
 await page.mouse.click(300,30);await page.mouse.click(491.4,274.2);await page.mouse.click(542.15,189.93);await page.mouse.click(385.85,330.07);await wait(()=>count('WORKBENCH|crease|')===1,'face selected and edge-midpoint snapping');
 await page.mouse.click(80,152);assert(latestModel().includes('angles=0.0|pending=true'),'reselect pending crease keeps transaction');await angle(60);assert(Number(latestModel().match(/height=([0-9.]+)/)[1])>.08,'first hinge stands in 3D');await page.mouse.click(810,320);await wait(()=>latestModel().includes('pending=false'),'explicit first commit');await shot('standing');
 await page.mouse.click(300,30);await page.mouse.click(481.99,240.68);await page.mouse.click(552.32,177.62);await page.mouse.click(411.66,303.75);await wait(()=>count('WORKBENCH|crease|')===2,'second crease on tilted face');
 await page.mouse.dblclick(822,129);await page.keyboard.press('Control+A');await page.keyboard.type('-45');await page.keyboard.press('Enter');await wait(()=>latestModel().includes('angles=60.0,-45.0'),'second fold numeric angle');await page.mouse.click(810,320);await wait(()=>latestModel().includes('pending=false'),'second commit');await shot('two-folds');
 await page.mouse.click(80,152);await angle(30);assert(latestModel().includes('angles=30.0,-45.0'),'ancestor edit preserves downstream feature');await shot('ancestor-edit');await page.mouse.click(900,320);await wait(()=>latestModel().includes('angles=60.0,-45.0|pending=false'),'cancel restores ancestor and child');
 await page.mouse.click(80,152);await page.mouse.move(505.57,236);await page.mouse.down();await page.mouse.move(512,260,{steps:12});await page.mouse.up();await wait(()=>latestModel().includes('angles=90.0,-45.0'),'actual screen rotation handle sets 90 degrees');await shot('gizmo');await page.mouse.click(900,320);
 await page.mouse.click(46,421);await wait(()=>latestModel().includes('angles=60.0|pending=false'),'undo whole operation');await page.mouse.click(126,421);await wait(()=>latestModel().includes('angles=60.0,-45.0|pending=false'),'redo whole operation');
 await page.mouse.click(85,460);await wait(()=>latestModel().includes('angles=|pending=false|height=0.00000'),'new sheet clears geometry');await page.mouse.click(46,421);await wait(()=>latestModel().includes('angles=60.0,-45.0|pending=false'),'new sheet can be undone');
 const geometry=latestModel();await page.mouse.move(650,375);await page.mouse.down({button:'right'});await page.mouse.move(685,350,{steps:8});await page.mouse.up({button:'right'});await page.mouse.move(640,370);await page.mouse.down({button:'middle'});await page.mouse.move(658,380,{steps:5});await page.mouse.up({button:'middle'});await page.mouse.wheel(0,-120);await page.waitForTimeout(250);assert(latestModel()===geometry,'orbit pan and zoom do not mutate paper');await shot('orbit');await page.mouse.click(620,30);
 await page.mouse.click(397,30);await wait(()=>count('WORKBENCH|starter|')===1,'editable flying starter');assert(latestModel().includes('angles=14.0'),'starter exposes wing angle');
 const png=PNG.sync.read(await page.screenshot());let paperPixels=0;for(let y=65;y<450;y++)for(let x=185;x<740;x++){const i=(y*png.width+x)*4;if(png.data[i]>160&&png.data[i+1]>150&&png.data[i+2]>110)paperPixels++;}assert(paperPixels>2000,'real 3D paper appears in workbench');await shot('starter');
 await page.mouse.click(850,505);await charge();await wait(()=>count('PAPER|land|')>=1,'practice landing');await shot('land');await page.mouse.click(880,24);await wait(()=>messages.some(m=>m.includes('PAPER|menu|levels=5')),'five-level menu');await page.mouse.click(216,216);
 for(let i=1;i<=5;i++){await wait(()=>messages.some(m=>m.includes('PAPER|level|'+i+'|practice=false')),'level '+i);const old=count('WORKBENCH|starter|');await page.mouse.click(397,30);await wait(()=>count('WORKBENCH|starter|')>old,'level starter '+i);await page.mouse.click(850,505);await charge();await wait(()=>messages.some(m=>m.includes('PAPER|course|'+i+'|pass=true')),'level cleared '+i);await page.mouse.click(360,385);}
 await wait(()=>messages.some(m=>m.includes('PAPER|final|levels=5')),'five-level final');await shot('final');assert(errors.length===0,'no browser or script errors');passed=true;
}finally{await browser.close();const result={verifiedAt:new Date().toISOString(),base,build:'demo-08-3d-v29',passed,checks,telemetry:messages.filter(m=>/PAPER\||WORKBENCH\|/.test(m)),errors};writeFileSync(path.join(root,'reviews/demo08-workbench-browser-'+surface+'.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));}
process.exitCode=passed?0:1;
