// 一次性：demo-02 v3 更新标注贴到看板（贴在 demo-02 贴纸上方，不重复媒体卡）
import { getSecret } from './secrets.mjs';

const API = 'https://api.miro.com/v1';
const token = getSecret('miro');
const board = getSecret('miro_board') || process.env.MIRO_BOARD;
if (!token || !board) { console.log('SKIP: 缺 Miro 凭据'); process.exit(2); }
const BOARD = encodeURIComponent(board);

const text = [
	'🆕 demo-02 v3 更新（2026-10-03）：',
	'新增跳跃输入系统：空格=跳（羽毛可空中扑翼） / ←→=空中横移，力度随词条变化。',
	'第三关「组合测试房」：弹簧起飞 → 空中切羽毛横漂 → 舱顶正上方切石头砸穿舱门入舱，一条链用满三个词条；错误词条会掉坑自动重置。',
	'headless 回归 4/4 PASS。上方卡片截图/录屏已更新为 v3（链接不变内容即最新）。',
	'试玩: https://sxguan.itch.io/taptap2026 （密码 taptap）',
	'（itch CDN 故障期备用镜像: https://tonyguan530.github.io/taptap2026/builds/demo-02-v3/ ）',
].join('\n');

const r = await fetch(`${API}/boards/${BOARD}/widgets`, {
	method: 'POST',
	headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
	body: JSON.stringify({ type: 'text', text, x: 4400, y: 6300, width: 480 }),
});
console.log(r.ok ? 'OK: demo-02 v3 标注已上板 (4400,6300)' : `FAIL ${r.status}: ${await r.text()}`);
process.exit(r.ok ? 0 : 1);
