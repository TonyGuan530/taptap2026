import fs from 'node:fs';
import {browser,check} from './v8-browser-harness.mjs';
const base=(process.env.INKBOUND_BASE||'http://127.0.0.1:8788').replace(/\/$/,''),out='.codex-tmp/inkbound';
fs.mkdirSync(out,{recursive:true});
const b=await browser(),errors=[],failed=[],report={base};
try{
 const page=await b.newPage({viewport:{width:1440,height:1000}});
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text()+' '+m.location().url)});
 page.on('response',r=>{if(r.status()>=400)failed.push({url:r.url(),status:r.status()})});
 await page.goto(base+'/inkbound.html',{waitUntil:'networkidle',timeout:90000});
 await page.waitForFunction(()=>[...document.images].every(i=>i.complete&&i.naturalWidth>0));
 report.images=await page.locator('img').count();check(report.images===4,'all four page images loaded');
 await page.waitForFunction(()=>document.querySelector('video').readyState>=1);
 report.ropeVideo=await page.locator('video').evaluate(v=>({duration:v.duration,width:v.videoWidth,height:v.videoHeight}));
 check(report.ropeVideo.width===960&&report.ropeVideo.duration>20,'rope MP4 metadata playable');
 await page.locator('[data-route="float"]').click();
 await page.waitForFunction(()=>document.querySelector('video').currentSrc.includes('float-play')&&document.querySelector('video').readyState>=1);
 report.floatVideo=await page.locator('video').evaluate(v=>({duration:v.duration,width:v.videoWidth,height:v.videoHeight}));
 check(report.floatVideo.width===960&&report.floatVideo.duration>20,'float MP4 metadata playable');
 await page.screenshot({path:out+'/entry-desktop.png',fullPage:true});
 await page.setViewportSize({width:390,height:844});
 check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'390px page has no horizontal overflow');
 await page.screenshot({path:out+'/entry-mobile.png',fullPage:true});
 await page.setViewportSize({width:1440,height:1000});
 await page.locator('#launch').click();
 const iframe=page.locator('#game-shell iframe');
 let frame=await (await iframe.elementHandle()).contentFrame();
 await frame.locator('#canvas').waitFor({timeout:90000});
 // Enable the game's read-only QA snapshot through its existing URL switch.
 // The shipped landing page keeps ordinary player URLs free of diagnostics.
 await iframe.evaluate(el=>{el.src+='?qa=1'});
 frame=await (await iframe.elementHandle()).contentFrame();
 await frame.waitForFunction(()=>window.__v9_ink_qa,null,{timeout:90000});
 report.game=await frame.evaluate(()=>({version:window.__v9_ink_qa.version,intro:window.__v9_ink_qa.ui.intro}));
 check(report.game.version===9&&report.game.intro,'embedded game reaches V9 character intro');
 report.errors=errors;report.failed=failed;
 check(!errors.length&&!failed.length,'page and embedded game have no console or HTTP errors');
}finally{await b.close();fs.writeFileSync(out+'/entry-qa.json',JSON.stringify(report,null,2)+'\n');}
console.log(JSON.stringify(report));
