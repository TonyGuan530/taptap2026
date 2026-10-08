import {createRequire} from 'node:module';import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url),{chromium}=require('D:/Apps/NodeJS/node_modules/@playwright/mcp/node_modules/playwright');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),base='https://tonyguan530.github.io/taptap2026',checks=[],errors=[];
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const page=await browser.newPage({viewport:{width:1280,height:900}});page.on('pageerror',e=>errors.push(e.message));
function check(ok,name){checks.push({name,passed:!!ok});if(!ok)throw Error(name);}
try{
 await page.goto(base+'/');await page.locator('.card.slot').first().waitFor();
 for(const id of ['demo-09-v2','demo-10-v3b','demo-11-v3','demo-09-3d-v1','demo-10-3d-v2','demo-11-3d-v1']){const card=page.locator('.card.slot[href="play.html?id='+id+'"]');check(await card.count()===1&&await card.isVisible(),id+' visible unique playable card');}
 await page.screenshot({path:path.join(root,'reviews/shots/release-09-11/hub-online.png'),fullPage:true});
 await page.locator('.card.slot[href="play.html?id=demo-09-3d-v1"]').click();await page.waitForURL('**/play.html?id=demo-09-3d-v1');
 const frame=page.frameLocator('iframe').first();await frame.locator('canvas').waitFor({timeout:60000});await frame.locator('#status').waitFor({state:'detached',timeout:60000});check(true,'hub opens ready 09 engine in play iframe');check(errors.length===0,'hub and iframe have no page errors');
 const result={verifiedAt:new Date().toISOString(),base,passed:true,checks,errors};fs.writeFileSync(path.join(root,'reviews/release-09-11/hub-online.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
}finally{await browser.close();}
