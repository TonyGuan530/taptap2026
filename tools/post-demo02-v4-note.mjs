// 一次性：demo-02 v4 更新标注贴到看板（贴在 demo-02 v3 标注上方）
import { getSecret } from './secrets.mjs';

const API = 'https://api.miro.com/v1';
const token = getSecret('miro');
const board = getSecret('miro_board') || process.env.MIRO_BOARD;
if (!token || !board) { console.log('SKIP: 缺 Miro 凭据'); process.exit(2); }
const BOARD = encodeURIComponent(board);

const text = [
	'🆕 demo-02 v4 更新（2026-10-03 晚，落实 ChatGPT KEEP 后指令）：',
	'① 删除通用跳跃：高度一律来自环境物理（弹簧/坠落/反弹）——听评审的，别做成平台跳跃。',
	'② 羽毛扑翼削为每次滞空一次的轻量升力修正（不可悬停）；←→横移保留，力度仍是词条属性。',
	'③ 新增第四关「开放解法房」：代码只检查 GOAL、不检查词条序列。已验证 ≥2 条独立路线（羽毛出生直漂入右敞口 / 弹簧→羽毛→高窗口切石头砸穿脆板），皮球弹跳路线留给玩家发现。',
	'④ 公开试玩 build（release 导出）已隐藏「参考解法」提示，开发模式仍显示。',
	'headless 6/6 PASS（L1-L3 回归 + L4 双路线 + 错误解法不误通关）。截图/录屏已更新为 L4 路线B 演绎。',
	'试玩: https://tonyguan530.github.io/taptap2026/play.html?id=demo-02 （itch CDN 故障持续，Pages 为准）',
].join('\n');

const r = await fetch(`${API}/boards/${BOARD}/widgets`, {
	method: 'POST',
	headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
	body: JSON.stringify({ type: 'text', text, x: 4400, y: 6060, width: 480 }),
});
console.log(r.ok ? 'OK: demo-02 v4 标注已上板 (4400,6060)' : `FAIL ${r.status}: ${await r.text()}`);
process.exit(r.ok ? 0 : 1);
