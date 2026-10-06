import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync,spawnSync} from 'node:child_process';
const root=process.cwd(),source=path.join(root,'.codex-tmp/inkbound-v10'),out=path.join(root,'public/inkbound-v10-art');
const encoder=path.join(root,'.codex-tmp/video-tools/python/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe');
const evidence=[];
const pckSha256=createHash('sha256').update(fs.readFileSync(path.join(root,'builds/demo-06-inkbound-v10/index.pck'))).digest('hex');
for(const route of ['ladder','board']){
  const qa=JSON.parse(fs.readFileSync(path.join(source,route+'-qa.json'),'utf8'));
  const capture=JSON.parse(fs.readFileSync(path.join(source,route+'-capture.json'),'utf8'));
  const last=qa.evidence.at(-1);
  if(qa.blackOnly || qa.errors.length || !last.state?.won || last.failure)throw Error('Full '+route+' route must pass before creating release media');
  if(capture.audioTracks<1)throw Error('Actual game audio required for '+route+' video');
  if(qa.build?.pckSha256!==pckSha256||capture.build?.pckSha256!==pckSha256)throw Error('Recording and QA must match the current exported PCK');
  const input=path.join(source,route+'-play.webm');
  const magic=Buffer.alloc(4),fd=fs.openSync(input,'r');fs.readSync(fd,magic,0,4,0);fs.closeSync(fd);
  if(magic.toString('hex')!=='1a45dfa3'||fs.statSync(input).size<100000)throw Error('Invalid recording '+input);
  if(capture.videoSha256!==createHash('sha256').update(fs.readFileSync(input)).digest('hex'))throw Error('Recorded media differs from its capture proof');
  evidence.push({route,capture});
}
fs.mkdirSync(out,{recursive:true});
for(const [from,to]of [['ladder-world.png','world.png'],['ladder-threshold.png','ladder.png'],['board-courtyard.png','board.png'],['ladder-yellow.png','yellow.png'],['ladder-ending.png','ending.png']])fs.copyFileSync(path.join(source,from),path.join(out,to));
for(const item of evidence){
  const file=path.join(out,item.route+'-play.mp4');
  execFileSync(encoder,['-hide_banner','-y','-i',path.join(source,item.route+'-play.webm'),'-c:v','libx264','-preset','veryfast','-crf','23','-pix_fmt','yuv420p','-c:a','aac','-b:a','112k','-movflags','+faststart',file],{stdio:['ignore','pipe','pipe'],windowsHide:true});
  execFileSync(encoder,['-hide_banner','-v','error','-i',file,'-map','0:v:0','-map','0:a:0','-f','null','-'],{stdio:['ignore','pipe','pipe'],windowsHide:true});
  item.file=path.basename(file);item.bytes=fs.statSync(file).size;
  item.decoded=true;
  const audio=spawnSync(encoder,['-hide_banner','-i',file,'-vn','-af','volumedetect','-f','null','-'],{encoding:'utf8',windowsHide:true});
  const peak=audio.stderr?.match(/max_volume:\s*(-?\d+(?:\.\d+)?) dB/);
  if(audio.status!==0||!peak||Number(peak[1])<=-80)throw Error('Game recording must contain audible actual audio: '+item.route);
  item.audioPeakDb=Number(peak[1]);
  console.log(JSON.stringify({route:item.route,bytes:item.bytes,audioTracks:item.capture.audioTracks}));
}
fs.writeFileSync(path.join(out,'capture.json'),JSON.stringify({method:'real game recording, ordinary mouse/keyboard, read-only QA',videos:evidence},null,2)+'\n');
