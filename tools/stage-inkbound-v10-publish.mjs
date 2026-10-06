import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
const target='.codex-tmp/inkbound-publish';
const paths=JSON.parse(fs.readFileSync('.codex-tmp/inkbound-v10/publish-manifest.json','utf8')).map(f=>f.file);
function git(args){return execFileSync('git',['-C',target,...args],{encoding:'utf8',stdio:['ignore','pipe','pipe'],windowsHide:true});}
const preexisting=git(['diff','--cached','--name-only','-z']).split('\0').filter(Boolean);
if(preexisting.some(file=>!paths.includes(file)))throw Error('Unrelated path was already staged');
git(['add','--',...paths]);
const staged=git(['diff','--cached','--name-only','-z']).split('\0').filter(Boolean);
if(staged.some(file=>!paths.includes(file)))throw Error('Unrelated path staged');
if(staged.some(file=>/secrets|\.codex-tmp|\.webm$|\.godot\//i.test(file)))throw Error('Private or temporary file staged');
const deletions=git(['diff','--cached','--diff-filter=D','--name-only']).trim();
if(deletions)throw Error('Unexpected deletion: '+deletions);
const authored=staged.filter(file=>!file.startsWith('builds/')&&!/\/LICENSE[^/]*$/i.test(file));
git(['diff','--cached','--check','--',...authored]);
console.log(JSON.stringify({staged:staged.length,manifest:paths.length,unrelated:0,deletions:0}));
