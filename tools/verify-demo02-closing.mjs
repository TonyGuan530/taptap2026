import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const godot = process.env.DEMO02_GODOT || 'D:/GIT/taptap2026/tools/godot/Godot_v4.7.2-stable_win64_console.exe';
const jobs = [
  ...['v4', 'v5', 'v6', 'v7'].map(version => ({ name: `2d-${version}`, script: `test_demo02_${version}.gd` })),
  ...[0.0, 0.3, 0.8, 1.2].map(delay => ({ name: `2d-closing-delay-${delay}`, script: 'test_demo02_closing_2d.gd', args: [`--delay=${delay}`] })),
  { name: '2d-closing-progression', script: 'test_demo02_closing_2d.gd', args: ['--mode=ui'] },
  ...Array.from({ length: 15 }, (_, index) => ({ name: `3d-case-${index}`, script: 'test_demo02_3d_b.gd', args: [`--case=${index}`] })),
  { name: '3d-closing-view', script: 'test_demo02_closing_3d.gd', args: ['--mode=view'] },
  { name: '3d-closing-progression', script: 'test_demo02_closing_3d.gd', args: ['--mode=progress'] },
  { name: '3d-closing-stone-control', script: 'test_demo02_closing_3d.gd', args: ['--mode=stone'] },
  ...[30, 60, 120].map(ticks => ({ name: `3d-closing-${ticks}hz`, script: 'test_demo02_closing_3d.gd', ticks, args: [`--ticks=${ticks}`] })),
];
const results = [];
let cursor = 0;
const logDir = path.join(root, 'reviews', 'demo02-closing-tests');
mkdirSync(logDir, { recursive: true });

async function worker() {
  while (cursor < jobs.length) {
    const job = jobs[cursor++];
    const ticks = job.ticks || 60;
    const result = await new Promise(resolve => {
      const args = ['--headless', '--path', path.join(root, 'game'), '--fixed-fps', String(ticks), '--script', `res://tests/${job.script}`, '--', ...(job.args || [])];
      const child = spawn(godot, args, { windowsHide: true, cwd: root });
      let output = '';
      let timedOut = false;
      const timeout = setTimeout(() => { timedOut = true; child.kill(); }, 60000);
      child.stdout.on('data', chunk => { output += chunk; });
      child.stderr.on('data', chunk => { output += chunk; });
      child.on('error', error => { output += String(error); });
      child.on('close', code => {
        clearTimeout(timeout);
        const ok = code === 0 && !timedOut && !/FAIL|SCRIPT ERROR|^ERROR:/m.test(output) && /ALL DONE|CLOSING_3D fails=0|stone: PASS|stale victory: PASS/.test(output);
        writeFileSync(path.join(logDir, `${job.name}.log`), output);
        resolve({ name: job.name, ok, exitCode: code, timedOut, summary: output.split(/\r?\n/).filter(line => /PASS|FAIL|ALL DONE|CLOSING_3D|ERROR/.test(line)) });
      });
    });
    results.push(result);
    console.log(`${result.ok ? 'PASS' : 'FAIL'} ${result.name} exit=${result.exitCode}`);
    if (!result.ok) console.log(result.summary.join('\n'));
  }
}
await Promise.all(Array.from({ length: 4 }, worker));
results.sort((a, b) => a.name.localeCompare(b.name));
const report = { verifiedAt: new Date().toISOString(), godot, passed: results.filter(result => result.ok).length, total: results.length, results };
writeFileSync(path.join(root, 'reviews', 'demo02-closing-validation.json'), `${JSON.stringify(report, null, 2)}\n`);
console.log(`TOTAL ${report.passed}/${report.total}`);
process.exitCode = report.passed === report.total ? 0 : 1;
