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
async function shot(stage){await page.screenshot({path:path.join(shots,'demo-08-3d-v30-'+stage+'-'+surface+'.png')});}
async function angle(value){const old=count('WORKBENCH|angle|');await page.mouse.dblclick(822,129);await page.keyboard.press('Control+A');await page.keyboard.type(String(value));await page.keyboard.press('Enter');await wait(()=>count('WORKBENCH|angle|')>old&&latestModel().includes('angles='+value.toFixed(1)), 'numeric angle '+value);}
async function charge(){const old=count('PAPER|launch|');await page.keyboard.down('Space');await page.waitForTimeout(1300);await page.keyboard.up('Space');await wait(()=>count('PAPER|launch|')>old,'physical launch');}
try{
 await page.goto(base+'/builds/demo-08-3d-v30/index.html');await page.waitForFunction(()=>!document.getElementById('status'),{timeout:45000});await page.locator('canvas').focus();await page.waitForTimeout(450);await shot('sheet');

 await page.mouse.click(397,30);await wait(()=>count('WORKBENCH|starter|')===1,'editable flying starter');
 await page.mouse.click(850,505);await wait(()=>count('PAPER|aim|angle=12')===1,'preflight before flight');
 const launches=count('PAPER|launch|');
 await page.mouse.move(622,225);await page.mouse.down();await page.mouse.move(808,225,{steps:15});await page.mouse.up();await wait(()=>messages.at(-1).includes('PAPER|aim|angle=60'),'slider selects 60 degrees');
 const aimCount=count('PAPER|aim|');await page.mouse.move(300,120);await page.waitForTimeout(250);assert(count('PAPER|aim|')===aimCount,'moving mouse preserves selected angle');
 await page.mouse.dblclick(860,218);await page.keyboard.press('Control+A');await page.keyboard.type('30',{delay:160});await page.keyboard.press('Enter');await wait(()=>messages.at(-1).includes('PAPER|aim|angle=30'),'numerical input commits 30 degrees');await shot('angle30');
 await page.mouse.click(877,274);await wait(()=>messages.at(-1).includes('PAPER|aim|angle=45'),'45 degree preset');
 await page.mouse.dblclick(860,218);await page.keyboard.press('Control+A');await page.keyboard.type('30',{delay:160});await page.waitForTimeout(250);
 assert(count('PAPER|launch|')===launches,'adjusting angle does not launch');
 await page.mouse.move(744,350);await page.mouse.down();await wait(()=>messages.at(-1).includes('PAPER|aim|angle=30'),'charge commits pending typed angle without Enter');await page.waitForTimeout(1300);await shot('charge-locked');
 const locked=count('PAPER|aim|');await page.keyboard.press('ArrowUp');await page.mouse.move(360,80);await page.waitForTimeout(150);assert(count('PAPER|aim|')===locked,'charging locks angle against keyboard and mouse');await page.mouse.up();
 await wait(()=>count('PAPER|launch|')>launches,'release outside button launches');assert(messages.filter(m=>m.includes('PAPER|launch|')).at(-1).includes('angle=30|'),'actual physics launches at selected 30 degrees');
 await wait(()=>count('PAPER|land|')>=1,'practice landing');await shot('land');await page.mouse.click(880,24);await wait(()=>messages.some(m=>m.includes('PAPER|menu|levels=5')),'five-level menu');await page.mouse.click(216,216);
 for(let i=1;i<=5;i++){await wait(()=>messages.some(m=>m.includes('PAPER|level|'+i+'|practice=false')),'level '+i);const old=count('WORKBENCH|starter|');await page.mouse.click(397,30);await wait(()=>count('WORKBENCH|starter|')>old,'level starter '+i);await page.mouse.click(850,505);await charge();await wait(()=>messages.some(m=>m.includes('PAPER|course|'+i+'|pass=true')),'level cleared '+i);await page.mouse.click(360,385);}
 await wait(()=>messages.some(m=>m.includes('PAPER|final|levels=5')),'five-level final');await shot('final');assert(errors.length===0,'no browser or script errors');passed=true;
}finally{await browser.close();const result={verifiedAt:new Date().toISOString(),base,build:'demo-08-3d-v30',passed,checks,telemetry:messages.filter(m=>/PAPER\||WORKBENCH\|/.test(m)),errors};writeFileSync(path.join(root,'reviews/demo08-preflight-browser-'+surface+'.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));}
process.exitCode=passed?0:1;
