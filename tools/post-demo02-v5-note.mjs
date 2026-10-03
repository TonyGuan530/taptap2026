// 一次性：demo-02 v5 更新标注贴到看板
import { getSecret } from './secrets.mjs';

const API = 'https://api.miro.com/v1';
const token = getSecret('miro');
const board = getSecret('miro_board') || process.env.MIRO_BOARD;
if (!token || !board) { console.log('SKIP: 缺 Miro 凭据'); process.exit(2); }
const BOARD = encodeURIComponent(board);

const text = [
	'🆕 demo-02 v5 更新（2026-10-03 深夜，落实 ChatGPT v4 KEEP 后指令）：',
	'① 轻量 telemetry：记录词条切换时机/失败重置次数/借弹簧/脆墙撞击，通关时结算一行「路线: 石头@6.7s｜借弹簧｜重置0」，供真人试玩记录实际路线。',
	'② 物性即时反馈层（纯 UI/FX，无新系统）：切换瞬间闪现「羽毛·轻 / 石头·重 / 皮球·弹」；撞脆板反馈「撞击 720 ≥ 450」或「还差 N」——帮玩家建立 输入→物理→结果 因果。',
	'③ L1-L4 玩法/几何零改动，headless 8/8 PASS（含 telemetry 断言）。',
	'试玩: https://tonyguan530.github.io/taptap2026/play.html?id=demo-02 （itch CDN 故障持续，Pages 为准）',
].join('\n');

const r = await fetch(`${API}/boards/${BOARD}/widgets`, {
	method: 'POST',
	headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
	body: JSON.stringify({ type: 'text', text, x: 4400, y: 5840, width: 480 }),
});
console.log(r.ok ? 'OK: demo-02 v5 标注已上板 (4400,5840)' : `FAIL ${r.status}: ${await r.text()}`);
process.exit(r.ok ? 0 : 1);
