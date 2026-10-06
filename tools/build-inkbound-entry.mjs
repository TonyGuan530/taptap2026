import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
const root=process.cwd(),source=path.join(root,'.codex-tmp/inkbound'),out=path.join(root,'public/inkbound-art');
fs.mkdirSync(out,{recursive:true});
for(const [a,b]of [['rope-world.png','world.png'],['rope-cast.png','rope.png'],['float-raft.png','float.png'],['rope-ending.png','ending.png']])fs.copyFileSync(path.join(source,a),path.join(out,b));
const encoder=path.join(root,'.codex-tmp/video-tools/python/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe');
for(const route of ['rope','float']){
 const input=path.join(source,route+'-play.webm'),output=path.join(out,route+'-play.mp4');
 const result=execFileSync(encoder,['-hide_banner','-y','-i',input,'-c:v','libx264','-preset','veryfast','-crf','23','-pix_fmt','yuv420p','-c:a','aac','-b:a','112k','-movflags','+faststart',output],{encoding:'utf8',stdio:['ignore','pipe','pipe']});
 const capture=JSON.parse(fs.readFileSync(path.join(source,route+'-capture.json'),'utf8'));console.log(JSON.stringify({route,bytes:fs.statSync(output).size,audioTracks:capture.audioTracks}));
}
