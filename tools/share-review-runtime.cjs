const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),ids=['demo-09-3d-v1','demo-10-3d-v2','demo-11-3d-v1'];
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
let engineHash;
for(const id of ids){
  const dir=path.join(root,'builds',id),wasm=path.join(dir,'index.wasm');
  const existing=JSON.parse(fs.readFileSync(path.join(dir,'build.json')));
  const bytes=fs.readFileSync(fs.existsSync(wasm)?wasm:path.join(root,'public',existing.runtime.path)),sha=hash(bytes);
  if(engineHash&&sha!==engineHash)throw Error('Runtime versions differ');engineHash=sha;
  const shared='runtime/godot-4.7.2-'+sha.slice(0,12),sharedDir=path.join(root,'public',shared);
  fs.mkdirSync(sharedDir,{recursive:true});const target=path.join(sharedDir,'index.wasm');
  if(fs.existsSync(target)){if(hash(fs.readFileSync(target))!==sha)throw Error('Shared runtime hash mismatch');}
  else fs.writeFileSync(target,bytes);
  for(const name of ['index.audio.worklet.js','index.audio.position.worklet.js']){
    const content=fs.readFileSync(path.join(dir,name)),out=path.join(sharedDir,name);
    if(fs.existsSync(out)&&hash(fs.readFileSync(out))!==hash(content))throw Error('Audio runtime versions differ');
    fs.writeFileSync(out,content);
  }
  const htmlPath=path.join(dir,'index.html');let html=fs.readFileSync(htmlPath,'utf8');
  html=html.replace(/const GODOT_CONFIG = (\{.*\});/,(_all,json)=>{
    const c=JSON.parse(json),exe='../../'+shared+'/index';c.executable=exe;c.mainPack='index.pck';
    delete c.fileSizes['index.wasm'];c.fileSizes[exe+'.wasm']=bytes.length;
    return 'const GODOT_CONFIG = '+JSON.stringify(c)+';';
  });fs.writeFileSync(htmlPath,html);
  const metaPath=path.join(dir,'build.json'),meta=JSON.parse(fs.readFileSync(metaPath));meta.runtime={path:shared+'/index.wasm',sha256:sha};fs.writeFileSync(metaPath,JSON.stringify(meta,null,2)+'\n');
  // These are this command's three freshly generated engine copies only.
  if(!wasm.startsWith(path.join(root,'builds')+path.sep))throw Error('Unexpected wasm location');
  if(fs.existsSync(wasm))fs.unlinkSync(wasm);
}
console.log('Shared review runtime SHA256 '+engineHash);
