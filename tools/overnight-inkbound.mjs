import fs from 'node:fs';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const scratch = path.join(repo, '.codex-tmp/inkbound-v10/overnight');
fs.mkdirSync(scratch, {recursive:true});
const config = JSON.parse(fs.readFileSync(path.join(scratch, 'config.json'), 'utf8'));
const mode = process.argv[2] || 'continue';
if (!['continue','release','smoke','check'].includes(mode)) throw new Error('Unknown mode');
const now = Date.now();
const stamp = new Date(now).toISOString().replace(/[:.]/g,'-');
const stateFile = path.join(scratch, 'state.json');
const readState = () => { try {return JSON.parse(fs.readFileSync(stateFile,'utf8'));} catch {return {};} };
function writeState(state) {
  const tmp = stateFile + '.' + process.pid + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(state, null, 2)+'\n');
  fs.renameSync(tmp, stateFile);
}
function report(status, extra={}) {
  const record={at:new Date().toISOString(),mode,status,...extra};
  fs.appendFileSync(path.join(scratch,'history.jsonl'),JSON.stringify(record)+'\n');
  process.stdout.write(JSON.stringify(record)+'\n');
}
const stop = ['STOP','COMPLETE'].find(f=>fs.existsSync(path.join(scratch,f)));
if(stop){report('skipped-'+stop.toLowerCase());process.exit(0);}
if (mode !== 'smoke') {
  const active = config.watchFiles.filter(f => fs.existsSync(f) && now - fs.statSync(f).mtimeMs < config.idleMinutes*60000);
  if(active.length){report('skipped-active-work',{active:active.map(f=>path.basename(f))});process.exit(0);}
}
if(mode==='check'){report('idle-ready');process.exit(0);}
const lockFile=path.join(scratch,'worker.lock');
let lock;
try {lock=fs.openSync(lockFile,'wx');}
catch {
  let old;try{old=JSON.parse(fs.readFileSync(lockFile,'utf8'));}catch{}
  let alive=false;
  if(old?.pid){try{process.kill(old.pid,0);alive=true;}catch{}}
  // Never remove a live worker's lock, even when its model call is slow.
  if(alive || now-fs.statSync(lockFile).mtimeMs < 180000){report('skipped-worker-lock');process.exit(0);}
  fs.unlinkSync(lockFile);lock=fs.openSync(lockFile,'wx');
}
fs.writeFileSync(lock,JSON.stringify({pid:process.pid,mode,at:new Date().toISOString()}));
const state=readState();
if((state[mode]?.consecutiveFailures||0)>=3){fs.closeSync(lock);fs.unlinkSync(lockFile);report('blocked-three-failures');process.exit(1);}
const header = `You are the unattended Inkbound V10 continuation worker. The user explicitly asked for overnight development and periodic verified GitHub Pages publication, with full access and no repeat permission requests. Read .codex-tmp/inkbound-v10/overnight-brief.md, .codex-tmp/inkbound-v10/progress.md, docs/superpowers/specs/2026-10-06-inkbound-colors-design.md and the implementation plan before work. Stay within this exact worktree and V10 scope. Use headless Godot/browser only. Preserve V8/V9 and unrelated changes. The scheduler already checked desktop inactivity and holds the shared worker lock. Do not spawn another background process or scheduler. Do not run git remote -v, print secrets, reset this worktree, or stage all files. Default model/settings only.\n`;
const prompts={
  continue: header+`Continue the first unfinished implementation/review/verification/release task. Finish one concrete milestone in this run, with meaningful tests, and update the progress ledger so the next run resumes rather than repeats. Yellow required behavior is a real drawn hand-held blade; black ladders/boards and three physical vertical goals come first. Other equipment categories are a future candidate/confirmation architecture; no browser ML and no fake completed guns/animals. If code is complete, proceed to headless Web export, ordinary-input routes, gameplay video, fresh review, verified Pages publication and Miro. Publication is authorized, but only tested changes. Check agent-owned files and actual current code instead of assuming pending plan entries mean nothing was implemented. Return a concise Chinese milestone, evidence and next step. If the release and all required acceptance checks are actually complete, write .codex-tmp/inkbound-v10/overnight/COMPLETE with deployed link, validation evidence, commit and workflow. If externally blocked, record precise blocker and stop; never mark complete prematurely.`,
  release: header+`Check whether a NEW V10 milestone is verified and ready for publication; if unchanged or not ready, save one concise status and stop without an empty commit or rebuild. If ready, publish using the fresh publication checkout and explicit dependency/source/build manifest described in the brief. Require native tests, restored shared config, successful export artifacts, ordinary-input browser route and fresh review first. Preserve current remote main, V8/V9 URLs and other demos. Follow Pages workflow and verify deployed game/media. Update ledger and release evidence; record actual failure if any. Do not invent readiness or release broken work simply because an hour elapsed. Write COMPLETE only when the entire agreed V10 scope and remote acceptance are fulfilled.`,
  smoke: `Read only: confirm the working directory is this repository and tools/overnight-inkbound.mjs exists. Do not edit files, invoke other agents, open windows, browse, run tests, access secrets, or publish. Reply exactly OVERNIGHT_SMOKE_OK.`
};
const log=fs.openSync(path.join(scratch,stamp+'-'+mode+'.jsonl'),'a');
const err=fs.openSync(path.join(scratch,stamp+'-'+mode+'.stderr.log'),'a');
const result=path.join(scratch,stamp+'-'+mode+'.result.md');
report('started',{pid:process.pid,result:path.basename(result)});
let child;
let failed=false;
try {
  child=spawn(config.codex,['exec','--sandbox',mode==='smoke'?'read-only':'danger-full-access','-c','approval_policy="never"','--cd',repo,'--color','never','--json','--ephemeral','--output-last-message',result,'-'],{cwd:repo,windowsHide:true,stdio:['pipe',log,err]});
  child.stdin.end(prompts[mode]);
  const code=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',resolve);});
  const response=fs.existsSync(result)?fs.readFileSync(result,'utf8'):'';
  failed=code!==0 || !response.trim() || (mode==='smoke'&&!response.includes('OVERNIGHT_SMOKE_OK'));
  const latest=readState();
  latest[mode]={at:new Date().toISOString(),code,result:path.basename(result),consecutiveFailures:failed?(latest[mode]?.consecutiveFailures||0)+1:0};
  writeState(latest);
  report(failed?'failed':'finished',{code,result:path.basename(result)});
} catch(e){
  failed=true;
  const latest=readState();latest[mode]={at:new Date().toISOString(),error:e.message,consecutiveFailures:(latest[mode]?.consecutiveFailures||0)+1};writeState(latest);report('failed',{error:e.message});
} finally {
  fs.closeSync(log);fs.closeSync(err);fs.closeSync(lock);fs.unlinkSync(lockFile);
}
process.exitCode=failed?1:0;
