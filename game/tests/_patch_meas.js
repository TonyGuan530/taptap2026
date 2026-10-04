const fs = require('fs');
const p = 'game/tests/test_demo04_3d.gd';
let t = fs.readFileSync(p, 'utf8');
const old = [
	'\tplayer.keys[KEY_SPACE] = true',
	'\twhile ticks < 240:',
	'\t\tawait physics_frame',
	'\t\tticks += 1',
	'\t\tmax_y = minf(max_y, player.position.y)',
].join('\n');
if (!t.includes(old)) { console.error('MISS'); process.exit(1); }
const neu = [
	'\tplayer.keys[KEY_SPACE] = true',
	'\tprint("[measure] keys set, pos=", player.position, " on_floor=", player.is_on_floor())',
	'\twhile ticks < 240:',
	'\t\tawait physics_frame',
	'\t\tticks += 1',
	'\t\tmax_y = minf(max_y, player.position.y)',
	'\t\tif ticks % 10 == 0:',
	'\t\t\tprint("[measure] t=", ticks, " pos.y=", player.position.y, " vy=", player.velocity.y, " keys_sp=", player.keys.get(KEY_SPACE, false), " jumps=", player.jumps_used)',
].join('\n');
t = t.replace(old, neu);
fs.writeFileSync(p, t);
console.log('measure instrumented');
