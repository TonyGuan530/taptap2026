import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';

const root=process.cwd(),target=path.resolve(root,'.codex-tmp/inkbound-publish');
if(!target.startsWith(path.join(root,'.codex-tmp')+path.sep))throw Error('Unexpected publication directory');
const git=args=>execFileSync('git',['-C',target,...args],{encoding:'utf8',windowsHide:true}).trim();
if(git(['rev-parse','HEAD'])!==git(['rev-parse','origin/main']))throw Error('Use freshly fetched main in the publication clone');
const proof=JSON.parse(fs.readFileSync('docs/inkbound-touch-validation.json','utf8'));
if(proof.native.totalChecks!==147||proof.native.failures!==0||!proof.browser.phone.passed||!proof.browser.desktop.passed)throw Error('Complete input validation required before staging');
const build='builds/demo-06-inkbound-v10-touch';
if(createHash('sha256').update(fs.readFileSync(build+'/index.pck')).digest('hex')!==proof.build.pckSha256)throw Error('Validated PCK changed');
const files=[
 'game/v10/touch_controls.gd','game/v10/touch_controls.gd.uid',
 'game/v10/ink_world.gd','game/v10/sketch_pad.gd',
 'game/tests/test_ink_v10_touch.gd','game/tests/test_ink_v10_touch.gd.uid',
 'tools/export-inkbound-v10.ps1','tools/verify-inkbound-v10-web.mjs','tools/prepare-inkbound-touch-publish.mjs','tools/miro-post-inkbound-touch.mjs','tools/build-inkbound-touch-report.mjs','tools/verify-inkbound-touch-online.mjs',
 'public/inkbound-v10.html','docs/inkbound-touch-validation.json','docs/inkbound-touch-validation.md','docs/inkbound-emergence-redesign.md','docs/inkbound-gd-writer-review.md','docs/superpowers/plans/2026-10-07-inkbound-emergence.md',
 ...fs.readdirSync(build).map(name=>build+'/'+name),
];
const manifest=[];
for(const file of files){
 const bytes=fs.readFileSync(file),dest=path.join(target,file);
 fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes);
 manifest.push({file,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')});
}
// Merge only the painter slot into current main. Other games stay authoritative there.
const demos=JSON.parse(git(['show','HEAD:public/demos.json']));
const slot=demos.slots.find(s=>s.id==='demo-06-3d');if(!slot)throw Error('Painter slot missing');
slot.buildId='demo-06-inkbound-v10-touch';slot.landingUrl='./inkbound-v10.html';
fs.writeFileSync(path.join(target,'public/demos.json'),JSON.stringify(demos,null,2)+'\n');
manifest.push({file:'public/demos.json',note:'Only painter build and landing URL changed'});
fs.writeFileSync('.codex-tmp/inkbound-v10-touch/publish-manifest.json',JSON.stringify(manifest,null,2)+'\n');
// Explicit paths only: this clone intentionally has unstaged deletions outside this release.
git(['add','-f','--',...manifest.map(item=>item.file)]);
console.log(JSON.stringify({files:manifest.length,validatedPck:proof.build.pckSha256}));
