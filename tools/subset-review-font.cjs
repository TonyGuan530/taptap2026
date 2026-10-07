const fs=require('node:fs'),path=require('node:path');
async function main(){
  const [project,source,modulePath]=process.argv.slice(2),subset=require(modulePath);
  let text='';for(let n=32;n<127;n++)text+=String.fromCharCode(n);
  function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name);if(e.isDirectory()&&e.name!=='.godot')walk(p);else if(e.isFile()&&/\.(gd|tscn)$/.test(p))text+=fs.readFileSync(p,'utf8');}}
  walk(project);fs.writeFileSync(path.join(project,'fonts/NotoSansSC.ttf'),await subset(fs.readFileSync(source),[...new Set(text)].join(''),{targetFormat:'truetype'}));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
