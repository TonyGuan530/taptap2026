extends SceneTree
## DEMO11 3D 格子核心 headless 测试（阶段 A：锁兼容基线）
## 对照对象是 game/demo11_3d/sandbox_rules.gd（从 demo11_sandbox.gd 移植）。
## 覆盖：基础移动/面向/步数；房1 双路径与门边沿；沉水/填坑兼容（差异1：铁入水也造桥、
## 序列硬编码 push:box、object_move 不增）；推物/磁拉落点权限（差异2）；烧箱优先（差异3）；
## family 分类精确串不匹配（差异5）；restart/reset_sample 生命周期（差异6）；融冰三分支、
## 环境注入融化（melt 计数口径）、无落点退回边界（审计 §3-2）；磁石视线/落点规则；
## 旧版五房预设全流程 → final + 83 步；事件批次与稳定 id。
## 运行：godot --headless --path game -s res://tests/test_demo11_3d_core.gd

const SandboxRules := preload("res://demo11_3d/sandbox_rules.gd")

# 旧测试（test_demo11.gd）五房预设序列原样复制，用于锁核心等价
const SEQ_R1 := ["right", "right", "right", "right", "down", "left", "left", "left", "left", "down", "down", "down"]
const SEQ_R1B := ["down", "down", "right", "right", "right", "left", "left", "down", "down", "left"]
const SEQ_R2A := ["down", "down", "right", "right", "right", "right", "right", "right", "right", "right", "right"]
const SEQ_R3A := ["down", "down", "down", "right", "right", "right", "right", "right", "up", "fire:left", "down", "left", "left", "left", "left", "left", "up", "up", "up", "right", "right", "down", "left", "down", "right", "right", "right", "down", "right", "right", "right", "right"]
const SEQ_R4A := ["down", "down", "magnet:right", "magnet:right", "magnet:right", "magnet:right", "magnet:right", "magnet:right", "magnet:right", "down", "right", "right", "right", "right", "up", "right", "right", "down", "down", "right", "right"]
const SEQ_R5A := ["down", "right", "right", "right", "right", "up", "right", "right", "right"]
const SEQ_R5B := ["left", "down", "right"]
const SEQ_R5C := ["up", "up"]

var passes := 0
var fails := 0


func _init() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("PASS  " + msg)
	else:
		fails += 1
		print("FAIL  " + msg)


func _obj_at(s, type: String, x: int, y: int) -> bool:
	for o in s.objects:
		if String(o.type) == type and int(o.x) == x and int(o.y) == y:
			return true
	return false


func _obj_id_at(s, type: String, x: int, y: int) -> int:
	for o in s.objects:
		if String(o.type) == type and int(o.x) == x and int(o.y) == y:
			return int(o.id)
	return -1


func _seq_has(s, item: String) -> bool:
	for a in s.solution_seq:
		if str(a) == item:
			return true
	return false


func _events_has_type(s, etype: String) -> bool:
	for e in s._events:
		if String(e.type) == etype:
			return true
	return false


## 全墙底图 + 指定行覆盖，构造迷你用例（12x7 尺寸不变）
func _rows(edits: Dictionary) -> Array:
	var rows: Array = []
	for y in SandboxRules.ROOM_H:
		rows.append("############")
	for k in edits:
		rows[int(k)] = String(edits[k])
	return rows


## ops：无冒号=move，"tool:方向"=try_tool；任一步失败打印并返回 false
func _run_ops(s, ops: Array) -> bool:
	for op_v in ops:
		var op := String(op_v)
		var ok := false
		var ci := op.find(":")
		if ci > 0:
			ok = s.try_tool(op.substr(0, ci), op.substr(ci + 1))
		else:
			ok = s.try_move(op)
		if not ok:
			print("      序列中断于 " + op + "（房索引 %d，玩家 %d,%d）" % [s.room_idx, int(s.player.x), int(s.player.y)])
			return false
	return true


func _run() -> void:
	# ================= 用例1 基础移动 / 撞墙 / 面向 / 步数 / 事件 =================
	var s = SandboxRules.new()
	_check(int(s.player.x) == 1 and int(s.player.y) == 1 and s.facing == "right" and int(s.steps) == 0,
		"用例1a 房1 起点 P(1,1) facing=right steps=0")
	var up_ok: bool = s.try_move("up")
	_check(not up_ok and s.facing == "right" and int(s.steps) == 0,
		"用例1b 撞上方墙拒绝：不转向（仍 right）不记步")
	var r_ok: bool = s.try_move("right")
	var ev: Array = s.drain_events()
	_check(r_ok and int(s.player.x) == 2 and int(s.steps) == 1,
		"用例1c 右移成功：(2,1) steps=1")
	_check(ev.size() == 1 and String(ev[0].type) == "move" and ev[0].from == Vector2i(1, 1) and ev[0].to == Vector2i(2, 1),
		"用例1d move 事件 from/to 与整数格一致")
	_check(s.drain_events().is_empty(), "用例1e drain 后事件清空")
	_check(s.try_move("left") and int(s.player.x) == 1 and s.facing == "left",
		"用例1f 左移回 (1,1)，facing 更新为 left")
	_check(s.try_move("bogus") == false and int(s.steps) == 2,
		"用例1g 非法方向拒绝，不记步")
	_check(s.try_tool("ice", "right") == false, "用例1h 房1 无工具：try_tool 拒绝（门禁）")

	# ================= 用例2 房1 双路径 + 稳定 id + 门边沿 + family =================
	var s2 = SandboxRules.new()
	var box_id: int = _obj_id_at(s2, "box", 5, 2)
	_check(box_id >= 0, "用例2a 对象携带稳定 id")
	var ok_a2: bool = _run_ops(s2, ["right", "right", "right", "right", "down"])
	_check(ok_a2 and s2.room_idx == 0 and int(s2.tele.switch_on) == 1 and s2.gate_open(),
		"用例2b 路径A前半：箱推上开关 (5,3)，门开边沿 switch_on=1")
	var moved_box = s2.object_by_id(box_id)
	_check(not moved_box.is_empty() and int(moved_box.x) == 5 and int(moved_box.y) == 3,
		"用例2c 被推箱 id 不变、位置 (5,3)（表现层按 id 绑定节点的前提）")
	var ok_rest: bool = _run_ops(s2, ["left", "left", "left", "left", "down", "down", "down"])
	_check(ok_rest and s2.room_idx == 1 and int(s2.steps) == 12 and int(s2.rooms_cleared) == 1,
		"用例2d 路径A：12 步过房进房2（rooms_cleared=1）")
	_check(String(s2.family_by_room[0]) == "plain", "用例2e 路径A family=plain")
	_check(_events_has_type(s2, "gate_open") and _events_has_type(s2, "room_clear"),
		"用例2f 事件流含 gate_open 与 room_clear（切房不清事件）")
	var s2b = SandboxRules.new()
	var ok_b: bool = _run_ops(s2b, SEQ_R1B)
	_check(ok_b and s2b.room_idx == 1 and int(s2b.steps) == 10,
		"用例2g 路径B（下箱右推）：10 步过房，房1 第二解保留")

	# ================= 用例3 沉水/填坑兼容（差异1 + 审计 §3-1/§3-3） =================
	s2.load_room(1)  # 房2：B(3,3)，水列 x=5，坑 (3,5)
	_run_ops(s2, ["down", "down", "right"])  # 玩家 (2,3)，箱 (3,3)
	var mv_before_push: int = int(s2.tele.object_move)
	_run_ops(s2, ["right"])  # 先普通推动：箱 (3,3)→(4,3)，玩家跟进 (3,3)
	var mv_after_push: int = int(s2.tele.object_move)
	var ok_sink: bool = _run_ops(s2, ["right"])  # 第二推入水 (5,3)
	_check(ok_sink and s2.objects.is_empty() and String(s2.grid[s2._idx(5, 3)]) == "bridge",
		"用例3ab 木箱推入水 → bridge，箱对象消失")
	_check(mv_after_push == mv_before_push + 1 and int(s2.tele.object_move) == mv_after_push,
		"用例3c 兼容口径：普通推计 1，sink 分支不增 object_move（审计 §3-1）")
	_check(_seq_has(s2, "push:box:water"),
		"用例3d 序列记录 push:box:water")
	var n: int = s2.solution_seq.size()
	_check(str(s2.solution_seq[n - 2]) == "push:box:water" and str(s2.solution_seq[n - 1]) == "move:right",
		"用例3e 沉水动作写两条序列项 push+move（审计 §3-3 顺序）")
	_check(s2.try_move("right") and int(s2.player.x) == 5,
		"用例3f 玩家可走 bridge")
	var s_i = SandboxRules.new()
	s_i._load_map(["ice"], _rows({3: "#PI~.......#"}))
	var iron_id3: int = _obj_id_at(s_i, "iron", 2, 3)
	var ok_iron: bool = s_i.try_move("right")
	var sink_ev3 = {}
	for e in s_i._events:
		if String(e.type) == "sink":
			sink_ev3 = e
	_check(ok_iron and String(s_i.grid[s_i._idx(3, 3)]) == "bridge" and s_i.objects.is_empty(),
		"用例3g 兼容差异1：铁块推入水也造 bridge（对照融冰分支铁沉水）")
	_check(int(sink_ev3.id) == iron_id3,
		"用例3g2 sink 事件携带被沉对象稳定 id（视图绑定依据）")
	_check(_seq_has(s_i, "push:box:water") and int(s_i.tele.object_move) == 0,
		"用例3h 铁块沉水序列硬编码 push:box:water、object_move 不增")
	s_i._load_map(["ice"], _rows({3: "#PIO.......#"}))
	_check(s_i.try_move("right") and String(s_i.grid[s_i._idx(3, 3)]) == "fill",
		"用例3i 兼容：铁块推入坑 → fill")
	var s_o = SandboxRules.new()
	s_o._load_map([], _rows({3: "#PBO.......#"}))
	_check(s_o.try_move("right") and String(s_o.grid[s_o._idx(3, 3)]) == "fill",
		"用例3j 木箱推入坑 → fill")

	# ================= 用例4 冻冰 / 烧箱优先（差异3）/ 工具融冰 / 分类不匹配（差异5） =================
	var s_f = SandboxRules.new()
	s_f._load_map(["ice", "fire"], _rows({2: "#P.~.......#", 3: "#..B.......#", 4: "#..........#"}))
	_run_ops(s_f, ["right"])  # (2,2) facing right
	_check(s_f.try_tool("ice", "right") and String(s_f.grid[s_f._idx(3, 2)]) == "ice",
		"用例4a 冰霜杖冻结面前水格 (3,2)")
	_run_ops(s_f, ["down", "down", "right", "up"])  # 推箱 (3,3)→(3,2) 冰上
	_check(_obj_at(s_f, "box", 3, 2), "用例4b 木箱可推上冰（落点 floor/ice）")
	var burn_ok: bool = s_f.try_tool("fire", "up")
	_check(burn_ok and not _obj_at(s_f, "box", 3, 2) and String(s_f.grid[s_f._idx(3, 2)]) == "ice"
		and int(s_f.tele.burn) == 1 and int(s_f.tele.melt) == 0,
		"用例4c 兼容差异3：冰上有箱时 G 先烧箱，融冰分支不可达")
	var melt_ok: bool = s_f.try_tool("fire", "up")
	_check(melt_ok and String(s_f.grid[s_f._idx(3, 2)]) == "water" and int(s_f.tele.melt) == 1
		and _seq_has(s_f, "tool:fire:melt:up"),
		"用例4d 工具融冰：空冰回水，melt 计 1，序列 tool:fire:melt:up")
	s_f._classify_family()
	_check(String(s_f.family) == "freeze_route",
		"用例4e 兼容差异5：分类器精确串不匹配带方向动作，melt_route 不可达 → freeze_route")

	# ================= 用例5 环境融冰三分支 + 计数口径 + 无落点边界（审计 §3-2） =================
	var s_m = SandboxRules.new()
	s_m._load_map(["ice"], _rows({3: "#P.~.......#"}))
	_run_ops(s_m, ["right"])
	_check(s_m.try_tool("ice", "right"), "用例5a 冻结 (3,3)")
	s_m.melt_queue.append({x = 3, y = 3, left = 0.01})
	s_m.advance_time(0.02)
	_check(String(s_m.grid[s_m._idx(3, 3)]) == "water" and int(s_m.tele.melt) == 0 and s_m.melt_queue.is_empty(),
		"用例5b 环境融化空冰→水：melt 计数不变（melt 只计工具路径），队列消费")
	# 铁块磁拉上冰 + 融化沉水（融冰分支2）
	var s_n = SandboxRules.new()
	s_n._load_map(["ice", "magnet"], _rows({3: "#P.~I......#"}))
	_run_ops(s_n, ["right"])
	s_n.try_tool("ice", "right")
	var iron_id: int = _obj_id_at(s_n, "iron", 4, 3)
	_check(s_n.try_tool("magnet", "right") and _obj_at(s_n, "iron", 3, 3),
		"用例5c 磁拉落点接受 ice（差异2 正面），铁块上冰")
	var mag_ev = {}
	for e in s_n._events:
		if String(e.type) == "magnet":
			mag_ev = e
	_check(int(mag_ev.id) == iron_id and int(s_n.tele.object_move) == 1,
		"用例5d magnet 事件携带稳定 id，object_move 计 1")
	s_n.melt_queue.append({x = 3, y = 3, left = 0.01})
	s_n.advance_time(0.02)
	var melt_ev5 = {}
	for e5 in s_n._events:
		if String(e5.type) == "melt" and String(e5.occupant) == "iron":
			melt_ev5 = e5
	_check(s_n.objects.is_empty() and String(s_n.grid[s_n._idx(3, 3)]) == "water",
		"用例5e 融冰分支2：冰上铁块沉水被移除、该格回 water")
	_check(int(melt_ev5.id) == iron_id,
		"用例5e2 melt 事件携带铁块稳定 id")
	# 玩家站冰融化（融冰分支3）
	var s_p = SandboxRules.new()
	s_p._load_map(["ice"], _rows({3: "#P.~.......#"}))
	_run_ops(s_p, ["right"])
	s_p.try_tool("ice", "right")
	s_p.try_move("right")  # 玩家 (3,3) 站冰上
	s_p.melt_queue.append({x = 3, y = 3, left = 0.01})
	s_p.advance_time(0.02)
	_check(int(s_p.player.x) == 2 and int(s_p.player.y) == 3 and String(s_p.grid[s_p._idx(3, 3)]) == "water",
		"用例5f 融冰分支3：up/down 是墙，环序先命中 left 落点 (2,3)，冰回水")
	var p_ev = {}
	for e in s_p._events:
		if String(e.type) == "melt":
			p_ev = e
	_check(String(p_ev.occupant) == "player" and p_ev.player_to == Vector2i(2, 3),
		"用例5g melt 事件 occupant=player 且带 player_to")
	# 无落点：玩家留在原格、该格变水
	var s_q = SandboxRules.new()
	s_q._load_map(["ice"], _rows({3: "###~P~######"}))
	s_q.grid[s_q._idx(4, 3)] = "ice"  # P 所在格改为冰（构造玩家站冰、四周全水/墙）
	s_q.melt_queue.append({x = 4, y = 3, left = 0.01})
	s_q.advance_time(0.02)
	_check(int(s_q.player.x) == 4 and int(s_q.player.y) == 3 and String(s_q.grid[s_q._idx(4, 3)]) == "water",
		"用例5h 无落点退回边界：玩家留在原格、该格照样变水（玩家站水上，审计 §3-2）")

	# ================= 用例6 磁石规则（差异2 + 视线） =================
	var s_g = SandboxRules.new()
	s_g._load_map(["magnet"], _rows({3: "#P.B.I.....#"}))
	_check(s_g.try_tool("magnet", "right") and _obj_at(s_g, "iron", 4, 3),
		"用例6a 只有 wall 截断视线：箱不挡，铁被拉到箱后一格")
	var s_h = SandboxRules.new()
	s_h._load_map(["magnet"], _rows({3: "#PI........#"}))
	var iron_pos_before := _obj_at(s_h, "iron", 2, 3)
	_check(not s_h.try_tool("magnet", "right") and iron_pos_before,
		"用例6b 磁拉落点=玩家格拒绝，铁块原位")
	var s_j = SandboxRules.new()
	s_j._load_map(["magnet"], _rows({3: "#P.BI......#"}))
	_check(not s_j.try_tool("magnet", "right") and _obj_at(s_j, "iron", 4, 3),
		"用例6c 磁拉落点被箱占用拒绝")
	var s_k = SandboxRules.new()
	s_k._load_map(["magnet"], _rows({3: "#P.#I......#"}))
	_check(not s_k.try_tool("magnet", "right") and _obj_at(s_k, "iron", 4, 3),
		"用例6d wall 截断视线：拉不到墙后铁块")
	var s_t = SandboxRules.new()
	s_t._load_map(["magnet"], _rows({3: "#P.TI......#"}))
	_check(not s_t.try_tool("magnet", "right") and _obj_at(s_t, "iron", 4, 3),
		"用例6e 火把不截断视线但占落点：落点被火把占用拒绝")
	var s_u = SandboxRules.new()
	s_u._load_map([], _rows({3: "#P..I......#"}))
	_check(not s_u.try_tool("magnet", "right"),
		"用例6f 工具未解锁拒绝")
	var s_v = SandboxRules.new()
	s_v._load_map(["magnet"], _rows({2: "#PT........#"}))
	_check(s_v.try_move("right") == false,
		"用例6g 火把阻挡移动且不可推")

	# ================= 用例7 开关 / 门 / 压力板占用型 =================
	var s_w = SandboxRules.new()
	_run_ops(s_w, ["down", "down", "right", "right", "right"])  # 箱 (3,3) 连推两次到开关 (5,3)，玩家 (4,3)
	_check(s_w.gate_open(), "用例7a 箱压开关门开")
	_run_ops(s_w, ["left"])
	_check(s_w.gate_open(), "用例7b 人离开但箱仍压住：门保持开（占用型）")
	_run_ops(s_w, ["right", "right", "right"])  # 箱推离开关后玩家自己也离开开关格（人踩也算导通）
	_check(not s_w.gate_open(), "用例7c 箱推离开关：门关（离开即断）")
	s_w.load_room(1)
	_check(s_w.gate_open(), "用例7d 无开关房门常开（房2）")
	var s_x = SandboxRules.new()
	s_x._load_map(["magnet"], _rows({3: "#P..TS.....#"}))
	_check(not s_x.gate_open(), "用例7e 火把压不住开关（只有 box/iron/人导通）")

	# ================= 用例8 生命周期（差异6：restart 保留 / reset_sample 全清） =================
	var s_y = SandboxRules.new()
	_run_ops(s_y, SEQ_R1)
	_check(int(s_y.steps) == 12 and int(s_y.rooms_cleared) == 1 and int(s_y.tele.switch_on) == 1
		and s_y.family_by_room.size() == 1,
		"用例8a 过房1 后：steps=12 cleared=1 switch_on=1 family 记录 1 房")
	s_y.restart()
	_check(s_y.room_idx == 0 and int(s_y.player.x) == 1 and s_y.solution_seq.is_empty() and String(s_y.family) == "",
		"用例8b restart()=load_room(0)：房内序列与 family 清空")
	_check(int(s_y.steps) == 12 and int(s_y.rooms_cleared) == 1 and int(s_y.tele.switch_on) == 1
		and s_y.family_by_room.size() == 1,
		"用例8c 兼容差异6：restart 保留 tele/steps/rooms_cleared/family_by_room（续样本语义）")
	s_y.reset_sample()
	_check(int(s_y.steps) == 0 and int(s_y.rooms_cleared) == 0 and s_y.tele.tool_use == 0
		and s_y.tele.switch_on == 0 and s_y.family_by_room.is_empty() and s_y.room_idx == 0,
		"用例8d reset_sample() 新样本入口：全清遥测/步数/家族/已通过数")

	# ================= 用例9 五房预设全流程 → final + 83 步（第五房索引 [4]） =================
	var s_z = SandboxRules.new()
	var all_ok := true
	all_ok = _run_ops(s_z, SEQ_R1) and all_ok
	_check(all_ok and s_z.room_idx == 1, "流程 房1 通关")
	all_ok = _run_ops(s_z, SEQ_R2A) and all_ok
	_check(all_ok and s_z.room_idx == 2, "流程 房2 通关（箱桥流）")
	all_ok = _run_ops(s_z, SEQ_R3A) and all_ok
	_check(all_ok and s_z.room_idx == 2 and s_z.gate_open() and _obj_at(s_z, "box", 6, 3),
		"流程 房3 中段：火烧+推箱压开关，门开、箱在 (6,3)（旧版 31+1 步的 +1）")
	all_ok = s_z.try_move("down") and all_ok
	_check(all_ok and s_z.room_idx == 3, "流程 房3 通关（烧箱流，踏入开启的门）")
	all_ok = _run_ops(s_z, SEQ_R4A) and all_ok
	_check(all_ok and s_z.room_idx == 4, "流程 房4 通关（磁拉流）")
	_check(s_z.room_idx == 4, "第五房索引是 [4]（rooms[4]），不是 [5]")
	_run_ops(s_z, SEQ_R5A)
	_check(s_z.room_idx == 4 and not s_z.gate_open() and _obj_at(s_z, "iron", 9, 4),
		"流程 房5：B2 沉水成桥 + 铁块推上开关A，单开关不足门仍关")
	_run_ops(s_z, SEQ_R5B)
	_check(s_z.gate_open() and _obj_at(s_z, "box", 9, 5),
		"流程 房5：木箱推上开关B，双开关同时压住门开")
	var ok_r5: bool = _run_ops(s_z, SEQ_R5C)
	_check(ok_r5 and s_z.room_idx == 5 and s_z.state == "play",
		"流程 房5：踏上门格 → 进入 EXT-1（六房制：final 移至扩展房通关）")
	_check(int(s_z.steps) == 83, "五房步数=83（12+11+32+14+14，工具不计步）")
	_check(int(s_z.rooms_cleared) == 5 and int(s_z.tele.room5_complete) == 1,
		"rooms_cleared=5、room5_complete=1（索引 [4] 不变量保持）")
	_check(s_z.family_by_room.size() == 5
		and String(s_z.family_by_room[0]) == "plain"
		and String(s_z.family_by_room[1]) == "box_bridge"
		and String(s_z.family_by_room[2]) == "plain"
		and String(s_z.family_by_room[3]) == "magnet_iron"
		and String(s_z.family_by_room[4]) == "box_bridge",
		"五房 family 归类：plain/box_bridge/plain/magnet_iron/box_bridge")
	# ---- EXT-1 解法A（旧机制：箱桥+推铁上开关，全程不动移动火把） ----
	var ok_ext_a: bool = _run_ops(s_z, ["right", "right", "right", "right", "right", "down", "down", "right", "up", "right", "right", "down", "left", "down", "left"])
	_check(ok_ext_a and s_z.room_idx == 6 and s_z.state == "play" and int(s_z.steps) == 98,
		"EXT-1 解法A（箱桥+铁上开关，15 步）：进入 EXT-2（七房制：final 移至 EXT-2 通关）")
	_check(String(s_z.family_by_room[5]) == "box_bridge" and s_z.family_by_room.size() == 6,
		"EXT-1 family=box_bridge，六段 family 齐全")
	# ---- EXT-2 解法（反相板保持空置 + 推铁上 S，13 步） → 进入 EXT-3（八房制） ----
	var ok_ext2: bool = _run_ops(s_z, ["down", "down", "right", "right", "right", "right", "right", "right", "down", "right", "right", "right", "down"])
	_check(ok_ext2 and s_z.room_idx == 7 and s_z.state == "play" and int(s_z.steps) == 111,
		"EXT-2 解法（反相板保持空置 + 铁上 S，13 步）：进入 EXT-3（八房制：final 移至 EXT-3 通关）")
	_check(String(s_z.family_by_room[6]) == "plain" and s_z.family_by_room.size() == 7,
		"七段 family 齐全（EXT-2=plain）")
	# ---- EXT-3 解法A（碎冰单次 + 绕行双推铁，18 步） → 进入 EXT-4（九房制） ----
	var ok_ext3: bool = _run_ops(s_z, ["down", "right", "right", "right", "right", "right", "up", "right", "right", "right", "right", "down", "down", "down", "down", "left", "left", "up"])
	_check(ok_ext3 and s_z.room_idx == 8 and s_z.state == "play" and int(s_z.steps) == 129,
		"EXT-3 解法A（薄冰单次通行 + 铁上开关，18 步）：进入 EXT-4（九房制：final 移至 EXT-4 通关）")
	_check(String(s_z.family_by_room[7]) == "plain" and s_z.family_by_room.size() == 8,
		"八段 family 齐全（EXT-3=plain）")
	# ---- EXT-4 解法A（薄冰道：清 B1 → 走 C → row3/row5 绕行推铁上开关，13 步） → 九房 final ----
	var ok_ext4: bool = _run_ops(s_z, ["right", "right", "down", "right", "right", "right", "down",
		"right", "right", "right", "down", "down", "left", "up"])
	_check(ok_ext4 and s_z.room_idx == 9 and s_z.state == "play" and int(s_z.steps) == 143,
		"EXT-4 解法A（四机制协同，14 步）：进入 EXT-5（十房制：final 移至 EXT-5 通关），全程 143 步（129+14）")
	_check(String(s_z.family_by_room[8]) == "plain" and s_z.family_by_room.size() == 9,
		"九段 family 齐全（EXT-4=plain）")
	# ---- EXT-5 解法（淬冰 → 踩冰 → 铁上开关 → G，12 步） → room_clear 进入 EXT-6 ----
	var ok_ext5: bool = _run_ops(s_z, ["down", "right", "right", "right", "ice:right", "right", "right", "right",
		"right", "down", "left", "down", "right"])
	_check(ok_ext5 and s_z.room_idx == 10 and s_z.state == "play" and int(s_z.steps) == 155,
		"EXT-5 解法（淬冰 + 铁上开关，12 步）：room_clear 进入 EXT-6，全程 155 步（143+12）")
	_check(String(s_z.family_by_room[9]) == "freeze_route" and s_z.family_by_room.size() == 10,
		"family[9]=freeze_route（EXT-5 用 F 冰霜杖）、十段 family 齐全")
	# ---- EXT-6 解法（推铁上开关 → G，10 步） → room_clear 进入 EXT-7 ----
	var ok_ext6: bool = _run_ops(s_z, ["down", "down", "right", "right", "right", "right", "down", "right", "right", "right"])
	_check(ok_ext6 and s_z.room_idx == 11 and s_z.state == "play" and int(s_z.steps) == 165,
		"EXT-6 解法（铁上开关，10 步）：room_clear 进入 EXT-7（十二房制：final 移至 EXT-7 通关），全程 165 步（155+10）")
	_check(String(s_z.family_by_room[10]) == "plain" and s_z.family_by_room.size() == 11,
		"family[10]=plain（EXT-6 纯走位）、十一段 family 齐全")
	# ---- EXT-7 解法A（挪灶化冰：铁上开关 3 + 箱上冰 4 + 挪灶 13 + 融化 + 让路过桥 3）→ room_clear 进入 EXT-8 ----
	var ok_ext7: bool = _run_ops(s_z, ["down", "right", "right", "down", "right", "right", "right",
		"down", "down", "left", "left", "left", "left", "up", "right", "right", "right", "down", "right", "up"])
	s_z.advance_time(3.0)
	var ok_ext7b: bool = _run_ops(s_z, ["up", "right", "right"])
	_check(ok_ext7 and ok_ext7b and s_z.room_idx == 12 and s_z.state == "play" and int(s_z.steps) == 188,
		"EXT-7 解法A（挪灶化冰，23 步 + 融化倒计时）：room_clear 进入 EXT-8（十三房制：final 移至 EXT-8 通关），全程 188 步（165+23）")
	_check(String(s_z.family_by_room[11]) == "plain" and s_z.family_by_room.size() == 12,
		"family[11]=plain（EXT-7 纯挪灶无工具）、十二段 family 齐全")
	# ---- EXT-8 解法（单行阀：箱顺阀三推上开关 + 绕行进 G，12 步）→ room_clear 进入 EXT-9 ----
	var ok_ext8: bool = _run_ops(s_z, ["down", "down", "right", "right", "right", "right", "right",
		"down", "right", "right", "down", "right"])
	_check(ok_ext8 and s_z.room_idx == 13 and s_z.state == "play" and int(s_z.steps) == 200,
		"EXT-8 解法（单行阀，12 步）：room_clear 进入 EXT-9（十四房制：final 移至 EXT-9 通关），全程 200 步（188+12）")
	_check(String(s_z.family_by_room[12]) == "plain" and s_z.family_by_room.size() == 13,
		"family[12]=plain（EXT-8 无工具）、十三段 family 齐全")
	# ---- EXT-9 解法（对影门：过门东送铁上开关 + 原门返回 + 西岸进 G，16 步）→ room_clear 进入 EXT-10 ----
	var ok_ext9: bool = _run_ops(s_z, ["down", "right", "right", "right", "right", "down", "down",
		"up", "left", "up", "left", "left", "left", "down", "down", "down"])
	_check(ok_ext9 and s_z.room_idx == 14 and s_z.state == "play" and int(s_z.steps) == 216,
		"EXT-9 解法（对影门，16 步）：room_clear 进入 EXT-10（十五房制：final 移至 EXT-10 通关），全程 216 步（200+16）")
	_check(String(s_z.family_by_room[13]) == "plain" and s_z.family_by_room.size() == 14,
		"family[13]=plain（EXT-9 无工具）、十四段 family 齐全")
	# ---- EXT-10 解法（铁敬：箱归普通板 + 铁归重压板 + 进 G，13 步）→ room_clear 进入 EXT-11 ----
	var ok_ext10: bool = _run_ops(s_z, ["right", "right", "down", "down",
		"right", "right", "right", "right", "down", "right", "up", "right", "down"])
	_check(ok_ext10 and s_z.room_idx == 15 and s_z.state == "play" and int(s_z.steps) == 229,
		"EXT-10 解法（铁敬，13 步）：room_clear 进入 EXT-11（十六房制：final 移至 EXT-11 通关），全程 229 步（216+13）")
	_check(String(s_z.family_by_room[14]) == "plain" and s_z.family_by_room.size() == 15,
		"family[14]=plain（EXT-10 无工具）、十五段 family 齐全")
	# ---- EXT-11 解法（焚垣：G 烧墙开路 + 铁下推上开关 + 进 G，13 步）→ room_clear 进入 EXT-12 ----
	var ok_ext11: bool = _run_ops(s_z, ["down", "right", "right", "right", "fire:right",
		"right", "right", "up", "right", "down", "down", "right", "down", "right"])
	_check(ok_ext11 and s_z.room_idx == 16 and s_z.state == "play" and int(s_z.steps) == 242,
		"EXT-11 解法（焚垣，13 步 + 烧墙工具不计步）：room_clear 进入 EXT-12（十七房制：final 移至 EXT-12 通关），全程 242 步（229+13）")
	_check(String(s_z.family_by_room[15]) == "plain" and s_z.family_by_room.size() == 16,
		"family[15]=plain（烧墙不入 family 关键词，基线口径）、十六段 family 齐全")
	# ---- EXT-12 解法（冰厅：骑行刹车停 + 铁三推下上开关 + 进 G，11 步）→ room_clear 进入 EXT-13 ----
	var ok_ext12: bool = _run_ops(s_z, ["down", "right", "up", "right", "down", "down", "down",
		"right", "down", "right", "right"])
	_check(ok_ext12 and s_z.room_idx == 17 and s_z.state == "play" and int(s_z.steps) == 253,
		"EXT-12 解法（冰厅，11 步，骑行整段计 1 步）：room_clear 进入 EXT-13（十八房制：final 移至 EXT-13 通关），全程 253 步（242+11）")
	_check(String(s_z.family_by_room[16]) == "plain" and s_z.family_by_room.size() == 17,
		"family[16]=plain（EXT-12 无工具）、十七段 family 齐全")
	# ---- EXT-13 解法（闸时：等窗过门 + 铁下推上开关 + 进 G，13 步）→ room_clear 进入 EXT-14 ----
	var ok_ext13: bool = _run_ops(s_z, ["down", "right", "right", "right", "right", "right",
		"up", "right", "down", "down", "right", "down", "right"])
	_check(ok_ext13 and s_z.room_idx == 18 and s_z.state == "play" and int(s_z.steps) == 266,
		"EXT-13 解法（闸时，13 步，逻辑时钟开窗持续）：room_clear 进入 EXT-14（十九房制：final 移至 EXT-14 通关），全程 266 步（253+13）")
	_check(String(s_z.family_by_room[17]) == "plain" and s_z.family_by_room.size() == 18,
		"family[17]=plain（EXT-13 无工具）、十八段 family 齐全")
	# ---- EXT-14 解法（跃泉：垫跳越水 + 铁下推上开关 + 进 G，13 步）→ room_clear 进入 EXT-15 ----
	var ok_ext14: bool = _run_ops(s_z, ["down", "down", "right", "right", "up", "right", "up",
		"right", "down", "right", "down", "right", "down"])
	_check(ok_ext14 and s_z.room_idx == 19 and s_z.state == "play" and int(s_z.steps) == 279,
		"EXT-14 解法（跃泉，13 步，垫跳整段计 1 步）：room_clear 进入 EXT-15（二十房制：final 移至 EXT-15 通关），全程 279 步（266+13）")
	_check(String(s_z.family_by_room[18]) == "plain" and s_z.family_by_room.size() == 19,
		"family[18]=plain（EXT-14 无工具）、十九段 family 齐全")
	# ---- EXT-15 解法（错拍：踩 Z 等反拍穿 z + 铁两推下上开关 + 进 G，15 步）→ room_clear 进入 EXT-16 ----
	var ok_ext15: bool = _run_ops(s_z, ["down", "right", "right", "right"])
	s_z.advance_time(2.5)
	var ok_ext15b: bool = _run_ops(s_z, ["right", "right", "right", "up", "right", "right",
		"down", "down", "left", "down", "down"])
	_check(ok_ext15 and ok_ext15b and s_z.room_idx == 20 and s_z.state == "play" and int(s_z.steps) == 294,
		"EXT-15 解法（错拍，15 步 + 反拍等待）：room_clear 进入 EXT-16（二十一房制：final 移至 EXT-16 通关），全程 294 步（279+15）")
	_check(String(s_z.family_by_room[19]) == "plain" and s_z.family_by_room.size() == 20,
		"family[19]=plain（EXT-15 无工具）、二十段 family 齐全")
	# ---- EXT-16 解法（合鸣：一推定音 + 相位门过门，11 步）→ room_clear 进入 EXT-17 ----
	var ok_ext16: bool = _run_ops(s_z, ["down", "right", "down", "right", "right", "right",
		"right", "right", "right", "down", "down"])
	_check(ok_ext16 and s_z.room_idx == 21 and s_z.state == "play" and int(s_z.steps) == 305,
		"EXT-16 解法（合鸣，11 步，铁滑整段计 1 次 push）：room_clear 进入 EXT-17（二十二房制：final 移至 EXT-17 通关），全程 305 步（294+11）")
	_check(String(s_z.family_by_room[20]) == "plain" and s_z.family_by_room.size() == 21,
		"family[20]=plain（EXT-16 无工具）、二十一段 family 齐全")
	# ---- EXT-17 解法（间歇泉：冻冰抢窗过涧 + 铁下推上开关 + 进 G，14 步）→ room_clear 进入 EXT-18 ----
	var ok_ext17: bool = _run_ops(s_z, ["down", "right", "down", "right", "ice:right", "right", "right",
		"up", "right", "right", "down", "right", "down", "right", "right"])
	_check(ok_ext17 and s_z.room_idx == 22 and s_z.state == "play" and int(s_z.steps) == 319,
		"EXT-17 解法（间歇泉，14 步，冻冰工具不计步）：room_clear 进入 EXT-18（二十三房制：final 移至 EXT-18 通关），全程 319 步（305+14）")
	_check(String(s_z.family_by_room[21]) == "freeze_route" and s_z.family_by_room.size() == 22,
		"family[21]=freeze_route（EXT-17 用 F 冰霜杖）、二十二段 family 齐全")
	# ---- EXT-18 解法（一拍即合：弹簧跳越水踩自锁 + 过相位门 + 进 G，5 步）→ room_clear 进入 EXT-19 ----
	var ok_ext18: bool = _run_ops(s_z, ["down", "right", "right", "right", "right"])
	_check(ok_ext18 and s_z.room_idx == 23 and s_z.state == "play" and int(s_z.steps) == 324,
		"EXT-18 解法（一拍即合，5 步，踩自锁永久开门）：room_clear 进入 EXT-19（三十八房制：final 移至 EXT-33 通关），全程 324 步（319+5）")
	_check(String(s_z.family_by_room[22]) == "plain" and s_z.family_by_room.size() == 23,
		"family[22]=plain（EXT-18 无工具）、二十三段 family 齐全")
	# ---- EXT-19 解法（呼吸桥：等寒泉结冰过涧 + 铁下推上开关 + 进 G，14 步）→ room_clear 进入 EXT-20 ----
	var ok_ext19: bool = _run_ops(s_z, ["down", "right", "down", "right"])
	s_z.advance_time(2.2)  # 寒泉半周期：呼吸桥结冰
	var ok_ext19b: bool = _run_ops(s_z, ["right", "right", "right", "right", "up", "right", "down",
		"right", "down", "right"])
	_check(ok_ext19 and ok_ext19b and s_z.room_idx == 24 and s_z.state == "play" and int(s_z.steps) == 338,
		"EXT-19 解法（呼吸桥，14 步）：room_clear 进入 EXT-20（三十八房制：final 移至 EXT-33 通关），全程 338 步（324+14）")
	_check(String(s_z.family_by_room[23]) == "plain" and s_z.family_by_room.size() == 24,
		"family[23]=plain（EXT-19 无工具，冻冰来自寒泉周期）、二十四段 family 齐全")
	# ---- EXT-20 解法（脆壁：铁三推穿裂墙缺口上开关 + 绕行进 G，12 步）→ room_clear 进入 EXT-21 ----
	var ok_ext20: bool = _run_ops(s_z, ["down", "right", "right", "right", "right", "right", "right",
		"down", "right", "right", "right", "up"])
	_check(ok_ext20 and s_z.room_idx == 25 and s_z.state == "play" and int(s_z.steps) == 350,
		"EXT-20 解法（脆壁，12 步，推碰碎墙走缺口）：room_clear 进入 EXT-21（三十八房制：final 移至 EXT-33 通关），全程 350 步（338+12）")
	_check(String(s_z.family_by_room[24]) == "plain" and s_z.family_by_room.size() == 25,
		"family[24]=plain（EXT-20 无工具，缺口靠推碰砸穿）、二十五段 family 齐全")
	# ---- EXT-21 解法（三拍：同相双门夹呼吸桥，8 步 + 两次等拍）→ room_clear 进入 EXT-22 ----
	var ok_ext21a: bool = _run_ops(s_z, ["right"])
	s_z.advance_time(2.2)  # 二拍：寒泉冻桥
	var ok_ext21b: bool = _run_ops(s_z, ["right", "right", "right", "right", "right"])
	s_z.advance_time(2.2)  # 三拍：东门同相重开
	var ok_ext21c: bool = _run_ops(s_z, ["right", "right"])
	_check(ok_ext21a and ok_ext21b and ok_ext21c and s_z.room_idx == 26 and s_z.state == "play" and int(s_z.steps) == 358,
		"EXT-21 解法（三拍，8 步，错相三连窗过门-抢冰-候门）：room_clear 进入 EXT-22（三十八房制：final 移至 EXT-33 通关），全程 358 步（350+8）")
	_check(String(s_z.family_by_room[25]) == "plain" and s_z.family_by_room.size() == 26,
		"family[25]=plain（EXT-21 无工具，节奏即门槛）、二十六段 family 齐全")
	# ---- EXT-22 解法（暗缝：铁下推上开关 + 玩家钻缝进 G，12 步）→ room_clear 进入 EXT-23 ----
	var ok_ext22: bool = _run_ops(s_z, ["right", "up", "right", "down", "down", "right", "right",
		"up", "right", "right", "right", "right"])
	_check(ok_ext22 and s_z.room_idx == 27 and s_z.state == "play" and int(s_z.steps) == 370,
		"EXT-22 解法（暗缝，12 步，缝前绕行下推 + 玩家钻缝）：room_clear 进入 EXT-23（三十八房制：final 移至 EXT-33 通关），全程 370 步（358+12）")
	_check(String(s_z.family_by_room[26]) == "plain" and s_z.family_by_room.size() == 27,
		"family[26]=plain（EXT-22 无工具，缝只放行玩家）、二十七段 family 齐全")
	# ---- EXT-23 解法（疑路：铁上开关 + 木箱献祭填坑 + 踏填土进 G，23 步）→ room_clear 进入 EXT-24 ----
	var ok_ext23: bool = _run_ops(s_z, ["up", "left", "left", "right", "right", "right", "right",
		"right", "down", "right", "up", "up", "up", "up", "left", "left", "left", "left",
		"left", "left", "left", "left", "left"])
	_check(ok_ext23 and s_z.room_idx == 28 and s_z.state == "play" and int(s_z.steps) == 393,
		"EXT-23 解法（疑路，23 步，暗坑献祭填坑）：room_clear 进入 EXT-24（三十八房制：final 移至 EXT-33 通关），全程 393 步（370+23）")
	_check(String(s_z.family_by_room[27]) == "box_bridge" and s_z.family_by_room.size() == 28,
		"family[27]=box_bridge（推箱入暗坑沉底填坑命中既有箱桥分类）、二十八段 family 齐全")
	# ---- EXT-24 解法（相位桥：开窗过桥 + 等反拍 + 反相窗过 z 进 G，9 步 + 一次等拍）→ room_clear 进入 EXT-25 ----
	var ok_ext24a: bool = _run_ops(s_z, ["right", "right", "right", "right", "right"])
	s_z.advance_time(2.2)  # 反拍：桥合、z 开
	var ok_ext24b: bool = _run_ops(s_z, ["right", "right", "right", "right"])
	_check(ok_ext24a and ok_ext24b and s_z.room_idx == 29 and s_z.state == "play" and int(s_z.steps) == 402,
		"EXT-24 解法（相位桥，9 步，两窗连过）：room_clear 进入 EXT-25（三十八房制：final 移至 EXT-33 通关），全程 402 步（393+9）")
	_check(String(s_z.family_by_room[28]) == "plain" and s_z.family_by_room.size() == 29,
		"family[28]=plain（EXT-24 无工具，纯节奏）、二十九段 family 齐全")
	# ---- EXT-25 解法（终演：相位桥 + 呼吸桥 + 反相门三重奏，9 步 + 一次等拍）→ room_clear 进入 EXT-26 ----
	var ok_ext25a: bool = _run_ops(s_z, ["right", "right", "right"])
	s_z.advance_time(2.2)  # 冰窗与门窗同窗对齐
	var ok_ext25b: bool = _run_ops(s_z, ["right", "right", "right", "right", "right", "right"])
	_check(ok_ext25a and ok_ext25b and s_z.room_idx == 30 and s_z.state == "play" and int(s_z.steps) == 411,
		"EXT-25 解法（终演，9 步，三重奏两窗连过）：room_clear 进入 EXT-26（三十八房制：final 移至 EXT-33 通关），全程 411 步（402+9）")
	_check(String(s_z.family_by_room[29]) == "plain" and s_z.family_by_room.size() == 30,
		"family[29]=plain（EXT-25 无工具，纯节奏）、三十段 family 齐全")
	# ---- EXT-26 解法（弹射：箱弹射过河 + F 冻水跟渡 + 绕行推箱上开关，11 步）→ room_clear 进入 EXT-27 ----
	var ok_ext26: bool = _run_ops(s_z, ["right", "right", "right", "ice:right", "right", "right",
		"right", "right", "up", "right", "right", "down"])
	_check(ok_ext26 and s_z.room_idx == 31 and s_z.state == "play" and int(s_z.steps) == 422,
		"EXT-26 解法（弹射，11 步，垫弹货物越河）：room_clear 进入 EXT-27（三十八房制：final 移至 EXT-33 通关），全程 422 步（411+11）")
	_check(String(s_z.family_by_room[30]) == "freeze_route" and s_z.family_by_room.size() == 31,
		"family[30]=freeze_route（EXT-26 用 F 冻水跟渡）、三十一段 family 齐全")
	# ---- EXT-27 解法（联桥：箱压联动开关 + 过联桥 + 推铁上开关 + 绕行进 G，15 步）→ room_clear 进入 EXT-28 ----
	var ok_ext27: bool = _run_ops(s_z, ["up", "up", "right", "right", "down", "right", "down",
		"right", "right", "right", "right", "up", "right", "right", "down"])
	_check(ok_ext27 and s_z.room_idx == 32 and s_z.state == "play" and int(s_z.steps) == 437,
		"EXT-27 解法（联桥，15 步，开关压桥不压门）：room_clear 进入 EXT-28（三十八房制：final 移至 EXT-33 通关），全程 437 步（422+15）")
	_check(String(s_z.family_by_room[31]) == "plain" and s_z.family_by_room.size() == 32,
		"family[31]=plain（EXT-27 无工具）、三十二段 family 齐全")
	# ---- EXT-28 解法（双联：两箱各压一座联动开关 + 双桥连成一线 + 推铁上开关，20 步）→ room_clear 进入 EXT-29 ----
	var ok_ext28: bool = _run_ops(s_z, ["right", "right", "right", "up", "left", "down", "right",
		"down", "left", "right", "up", "right", "right", "right", "up", "right", "down",
		"right", "right", "down"])
	_check(ok_ext28 and s_z.room_idx == 33 and s_z.state == "play" and int(s_z.steps) == 457,
		"EXT-28 解法（双联，20 步，与门双桥）：room_clear 进入 EXT-29（三十八房制：final 移至 EXT-33 通关），全程 457 步（437+20）")
	_check(String(s_z.family_by_room[32]) == "plain" and s_z.family_by_room.size() == 33,
		"family[32]=plain（EXT-28 无工具）、三十三段 family 齐全")
	# ---- EXT-29 解法（油道：箱滑 5 格压开关 + 玩家跟滑 + 进 G，6 步）→ room_clear 进入 EXT-30 ----
	var ok_ext29: bool = _run_ops(s_z, ["up", "right", "right", "right", "down", "right"])
	_check(ok_ext29 and s_z.room_idx == 34 and s_z.state == "play" and int(s_z.steps) == 463,
		"EXT-29 解法（油道，6 步，箱滑送货）：room_clear 进入 EXT-30（三十八房制：final 移至 EXT-33 通关），全程 463 步（457+6）")
	_check(String(s_z.family_by_room[33]) == "plain" and s_z.family_by_room.size() == 34,
		"family[33]=plain（EXT-29 无工具）、三十四段 family 齐全")
	# ---- EXT-30 解法（联运：油道滑行接力弹射投递 + F 冻河跟渡 + 推箱上开关 + 绕行进 G，9 步）→ room_clear 进入 EXT-31 ----
	var ok_ext30: bool = _run_ops(s_z, ["right", "right", "right", "ice:right", "right", "right",
		"up", "right", "right", "down"])
	_check(ok_ext30 and s_z.room_idx == 35 and s_z.state == "play" and int(s_z.steps) == 472,
		"EXT-30 解法（联运，9 步，滑+弹联运投递）：room_clear 进入 EXT-31（三十八房制：final 移至 EXT-33 通关），全程 472 步（463+9）")
	_check(String(s_z.family_by_room[34]) == "freeze_route" and s_z.family_by_room.size() == 35,
		"family[34]=freeze_route（EXT-30 用 F 冻河跟渡）、三十五段 family 齐全")
	# ---- EXT-31 解法（潮汐：露潮过滩 + 等反拍过门，8 步 + 一次等拍）→ room_clear 进入 EXT-32 ----
	var ok_ext31a: bool = _run_ops(s_z, ["right", "right", "right", "right"])
	s_z.advance_time(2.2)  # 反拍：z 开（潮仍露至 4.0）
	var ok_ext31b: bool = _run_ops(s_z, ["right", "right", "right", "right"])
	_check(ok_ext31a and ok_ext31b and s_z.room_idx == 36 and s_z.state == "play" and int(s_z.steps) == 480,
		"EXT-31 解法（潮汐，8 步，2:1 复拍子）：room_clear 进入 EXT-32（三十八房制：final 移至 EXT-33 通关），全程 480 步（472+8）")
	_check(String(s_z.family_by_room[35]) == "plain" and s_z.family_by_room.size() == 36,
		"family[35]=plain（EXT-31 无工具）、三十六段 family 齐全")
	# ---- EXT-32 解法（联运潮滩：潮滩 + 油道接力弹射投递 + F 冻河跟渡 + 下行进 G，7 步）→ room_clear 进入 EXT-33 ----
	var ok_ext32: bool = _run_ops(s_z, ["right", "right", "right", "ice:right", "right", "down", "right", "right"])
	_check(ok_ext32 and s_z.room_idx == 37 and s_z.state == "play" and int(s_z.steps) == 487,
		"EXT-32 解法（联运潮滩，7 步，潮滩+滑弹联运）：room_clear 进入 EXT-33（三十八房制：final 移至 EXT-33 通关），全程 487 步（480+7）")
	_check(String(s_z.family_by_room[36]) == "freeze_route" and s_z.family_by_room.size() == 37,
		"family[36]=freeze_route（EXT-32 用 F 冻河跟渡）、三十七段 family 齐全")
	# ---- EXT-33 解法（换乘：换乘窗跨双滩 + 推铁上开关 + 北上绕行进 G，11 步）→ room_clear 进入 EXT-34 ----
	s_z.advance_time(2.2)  # 换乘窗 [2,4)：u 露 + j 露同真
	var ok_ext33: bool = _run_ops(s_z, ["right", "right", "right", "right", "right", "right", "right",
		"up", "right", "right", "down"])
	_check(ok_ext33 and s_z.room_idx == 38 and s_z.state == "play" and int(s_z.steps) == 498,
		"EXT-33 解法（换乘，11 步，错相双滩换乘窗）：room_clear 进入 EXT-34（六十四房制：final 移至 EXT-34 通关），全程 498 步（487+11）")
	_check(String(s_z.family_by_room[37]) == "plain" and s_z.family_by_room.size() == 38,
		"family[37]=plain（EXT-33 无工具）、三十八段 family 齐全")
	# ---- EXT-34 解法（推凿：推箱凿塌假墙 + 箱续推压开关 + 北上绕行进 G，11 步）→ 三十九房 final ----
	var ok_ext34: bool = _run_ops(s_z, ["right", "right", "right", "right", "right", "right", "right",
		"up", "right", "right", "down"])
	_check(ok_ext34 and s_z.room_idx == 39 and s_z.state == "play" and int(s_z.steps) == 509,
		"EXT-34 解法（推凿，11 步，推力凿桩）：room_clear 进入 EXT-35（六十四房制：final 移至 EXT-35 通关），全程 509 步（498+11）")
	_check(String(s_z.family_by_room[38]) == "plain" and s_z.family_by_room.size() == 39,
		"family[38]=plain（EXT-34 无工具）、三十九段 family 齐全")
	# ---- EXT-35 解法（暖轨：下行压开关 + 避轨东行进 G，12 步）→ room_clear 进入 EXT-36 ----
	var ok_ext35: bool = _run_ops(s_z, ["up", "right", "right", "down", "down", "right", "right",
		"right", "right", "right", "right", "down"])
	_check(ok_ext35 and s_z.room_idx == 40 and s_z.state == "play" and int(s_z.steps) == 521,
		"EXT-35 解法（暖轨，12 步，巡轨时限+车压板不导通）：room_clear 进入 EXT-36（六十四房制：final 移至 EXT-36 通关），全程 521 步（509+12）")
	_check(String(s_z.family_by_room[39]) == "plain" and s_z.family_by_room.size() == 40,
		"family[39]=plain（EXT-35 无工具）、四十段 family 齐全")
	# ---- EXT-36 解法（钥匣：沉箱造桥 + 冻河 + 拾钥 + 开锁门，9 步 + ice 工具）→ room_clear 进入 EXT-37 ----
	var ok_ext36: bool = _run_ops(s_z, ["right", "right", "right", "right", "right", "ice:right",
		"right", "right", "right", "right"])
	_check(ok_ext36 and s_z.room_idx == 41 and s_z.state == "play" and int(s_z.steps) == 530,
		"EXT-36 解法（钥匣，9 步 + 1 工具，推箱沉桥+冻河+拾钥开锁）：room_clear 进入 EXT-37（六十四房制：final 移至 EXT-37 通关），全程 530 步（521+9）")
	_check(String(s_z.family_by_room[40]) == "box_bridge" and s_z.family_by_room.size() == 41,
		"family[40]=box_bridge（EXT-36 用 F 冻河+沉箱桥，分类器箱桥优先）、四十一段 family 齐全")
	# ---- EXT-37 解法（藤垣：推箱压开关 + 攀越藤垣 + 踩自锁踏板进 G，15 步）→ room_clear 进入 EXT-38 ----
	var ok_ext37: bool = _run_ops(s_z, ["up", "up", "right", "right", "down", "right", "right",
		"right", "right", "up", "right", "right", "down", "down", "right"])
	_check(ok_ext37 and s_z.room_idx == 42 and s_z.state == "play" and int(s_z.steps) == 545,
		"EXT-37 解法（藤垣，15 步，人货分流的唯一通路）：room_clear 进入 EXT-38（六十四房制：final 移至 EXT-38 通关），全程 545 步（530+15）")
	_check(String(s_z.family_by_room[41]) == "plain" and s_z.family_by_room.size() == 42,
		"family[41]=plain（EXT-37 无工具）、四十二段 family 齐全")
	# ---- EXT-38 解法（晶屑：推晶入坑碎水 + 冻冰过壕，9 步 + ice 工具）→ room_clear 进入 EXT-39 ----
	var ok_ext38: bool = _run_ops(s_z, ["right", "right", "right", "right", "ice:right",
		"right", "right", "right", "right", "right"])
	_check(ok_ext38 and s_z.room_idx == 43 and s_z.state == "play" and int(s_z.steps) == 554,
		"EXT-38 解法（晶屑，9 步 + 1 工具，一推碎水自置水源）：room_clear 进入 EXT-39（六十四房制：final 移至 EXT-39 通关），全程 554 步（545+9）")
	_check(String(s_z.family_by_room[42]) == "freeze_route" and s_z.family_by_room.size() == 43,
		"family[42]=freeze_route（EXT-38 用 F 冻晶水成桥）、四十三段 family 齐全")
	# ---- EXT-39 解法（换相井：双井零等待过 j/u 双滩，9 步）→ room_clear 进入 EXT-40 ----
	var ok_ext39: bool = _run_ops(s_z, ["right", "right", "right", "right", "right",
		"right", "right", "right", "right"])
	_check(ok_ext39 and s_z.room_idx == 44 and s_z.state == "play" and int(s_z.steps) == 563,
		"EXT-39 解法（换相井，9 步，踩井换相零等待）：room_clear 进入 EXT-40（六十四房制：final 移至 EXT-40 通关），全程 563 步（554+9）")
	_check(String(s_z.family_by_room[43]) == "plain" and s_z.family_by_room.size() == 44,
		"family[43]=plain（EXT-39 无工具）、四十四段 family 齐全")
	# ---- EXT-40 解法（输送：推箱上带 + 玩家搭车 + 箱压开关 + 南绕进 G，8 步 + 等带 4.5 秒）→ room_clear 进入 EXT-41 ----
	var ok_ext40: bool = _run_ops(s_z, ["right", "right", "right", "right"])
	s_z.advance_time(4.5)
	var ok_ext40b: bool = _run_ops(s_z, ["down", "right", "right", "up"])
	_check(ok_ext40 and ok_ext40b and s_z.room_idx == 45 and s_z.state == "play" and int(s_z.steps) == 571,
		"EXT-40 解法（输送，8 步 + 等带，箱随带压开关 + 人搭车南绕进 G）：room_clear 进入 EXT-41（六十四房制：final 移至 EXT-41 通关），全程 571 步（563+8）")
	_check(String(s_z.family_by_room[44]) == "plain" and s_z.family_by_room.size() == 45,
		"family[44]=plain（EXT-40 无工具，带运不计序列）、四十五段 family 齐全")
	# ---- EXT-41 解法（经纬：上货上带 + 十字拐向 + 东行进 G，9 步 + 等带 4.5 秒）→ room_clear 进入 EXT-42 ----
	var ok_ext41: bool = _run_ops(s_z, ["right", "right", "right"])
	s_z.advance_time(4.5)
	var ok_ext41b: bool = _run_ops(s_z, ["up", "right", "right", "right", "right", "right"])
	_check(ok_ext41 and ok_ext41b and s_z.room_idx == 46 and s_z.state == "play" and int(s_z.steps) == 580,
		"EXT-41 解法（经纬，9 步 + 等带，带线拐向送货）：room_clear 进入 EXT-42（六十四房制：final 移至 EXT-42 通关），全程 580 步（571+9）")
	_check(String(s_z.family_by_room[45]) == "plain" and s_z.family_by_room.size() == 46,
		"family[45]=plain（EXT-41 无工具，带运不计序列）、四十六段 family 齐全")
	# ---- EXT-42 解法（双钥：拾银钥穿银门拾金钥进金锁，13 步）→ room_clear 进入 EXT-43 ----
	var ok_ext42: bool = _run_ops(s_z, ["up", "right", "right", "right", "right", "right",
		"right", "right", "down", "right", "right", "down", "down"])
	_check(ok_ext42 and s_z.room_idx == 47 and s_z.state == "play" and int(s_z.steps) == 593,
		"EXT-42 解法（双钥，13 步，银钥穿门+金钥开锁的取钥链）：room_clear 进入 EXT-43（六十四房制：final 移至 EXT-43 通关），全程 593 步（580+13）")
	_check(String(s_z.family_by_room[46]) == "plain" and s_z.family_by_room.size() == 47,
		"family[46]=plain（EXT-42 无工具，纯走位）、四十七段 family 齐全")
	# ---- EXT-43 解法（候潮：推箱上带 + 候潮过闸 + 南绕进 G，10 步 + 两次等/踩）→ room_clear 进入 EXT-44 ----
	var ok_ext43: bool = _run_ops(s_z, ["right", "right", "right", "right"])
	s_z.advance_time(4.5)
	var ok_ext43b: bool = _run_ops(s_z, ["right"])
	s_z.advance_time(1.5)
	var ok_ext43c: bool = _run_ops(s_z, ["down", "right", "right", "right", "up"])
	_check(ok_ext43 and ok_ext43b and ok_ext43c and s_z.room_idx == 48 and s_z.state == "play" and int(s_z.steps) == 603,
		"EXT-43 解法（候潮，10 步 + 两次等/踩，带上候潮过闸）：room_clear 进入 EXT-44（六十四房制：final 移至 EXT-44 通关），全程 603 步（593+10）")
	_check(String(s_z.family_by_room[47]) == "plain" and s_z.family_by_room.size() == 48,
		"family[47]=plain（EXT-43 无工具，带运不计序列）、四十八段 family 齐全")
	# ---- EXT-44 解法（晶运：推晶上带 + 随带行驶 + 出带碎水 + 冻冰过壕，7 步 + ice 工具）→ room_clear 进入 EXT-45 ----
	var ok_ext44: bool = _run_ops(s_z, ["right", "right", "right"])
	s_z.advance_time(2.5)
	var ok_ext44b: bool = _run_ops(s_z, ["ice:right", "right", "right", "right", "right"])
	_check(ok_ext44 and ok_ext44b and s_z.room_idx == 49 and s_z.state == "play" and int(s_z.steps) == 610,
		"EXT-44 解法（晶运，7 步 + 1 工具，晶随带远程投水冻桥）：room_clear 进入 EXT-45（六十四房制：final 移至 EXT-45 通关），全程 610 步（603+7）")
	_check(String(s_z.family_by_room[48]) == "freeze_route" and s_z.family_by_room.size() == 49,
		"family[48]=freeze_route（EXT-44 用 F 冻晶水成桥）、四十九段 family 齐全")
	# ---- EXT-45 解法（潮渡：2R 推箱上带首 + 候潮联运 + row3 东行 U 进 G(10,2)，11 键 11 步 + 等潮 5.5 秒）→ room_clear 进入 EXT-46 ----
	var ok_ext45: bool = _run_ops(s_z, ["right", "right"])
	s_z.advance_time(5.5)
	var ok_ext45b: bool = _run_ops(s_z, ["down", "right", "right", "right", "right", "right", "right", "right", "up"])
	_check(ok_ext45 and ok_ext45b and s_z.room_idx == 50 and s_z.state == "play" and int(s_z.steps) == 621,
		"EXT-45 解法（潮渡，11 键 11 步 + 等潮，带上候潮联运渡滩上开关）：room_clear 自动进入 EXT-46（六十四房制：final 移至 EXT-46 通关），全程 621 步（610+11）")
	_check(String(s_z.family_by_room[49]) == "plain" and s_z.family_by_room.size() == 50,
		"family[49]=plain（EXT-45 无工具，带运不计序列）、五十段 family 齐全")
	# ---- EXT-46 解法（焚藤：攀藤借朝向烧两洞 + 推箱上 S + 推铁上 W 双压开门，43 键 41 步）→ room_clear 进入 EXT-47 ----
	var ok_ext46: bool = _run_ops(s_z, ["down", "right", "right", "down", "right", "right", "up",
		"fire:up", "up", "up", "down", "fire:down",
		"up", "left", "left", "left", "left", "down", "right",
		"right", "right", "right", "right", "right",
		"down", "left", "left", "down", "left", "left", "up", "left", "right",
		"right", "right", "right", "right",
		"up", "up", "right", "right", "down", "right"])
	_check(ok_ext46 and s_z.room_idx == 51 and s_z.state == "play" and int(s_z.steps) == 662,
		"EXT-46 解法（焚藤，41 步 + 2 烧不计步，双货双压开门）：room_clear 自动进入 EXT-47（六十四房制：final 移至 EXT-47 通关），全程 662 步（621+41）")
	_check(String(s_z.family_by_room[50]) == "plain" and s_z.family_by_room.size() == 51,
		"family[50]=plain（burn_ivy 不进分类器——差异5 基线冻结）、五十一段 family 齐全")
	# ---- EXT-47 解法（引晶：磁拉晶出龛 + 推晶入坑化水 + F 冻桥，32 键 27 步）→ room_clear 进入 EXT-48 ----
	var ok_ext47: bool = _run_ops(s_z, ["down", "right", "right", "right", "right", "right",
		"magnet:right", "left", "left", "right", "magnet:right",
		"left", "left", "right", "magnet:right",
		"left", "left", "right", "magnet:right",
		"down", "right", "up", "ice:up",
		"up", "up", "right", "right", "right", "right", "right", "right", "down"])
	_check(ok_ext47 and s_z.room_idx == 52 and s_z.state == "play" and int(s_z.steps) == 689,
		"EXT-47 解法（引晶，27 步 + 4 拉 1 冻不计步，磁认晶隔空引晶出龛）：room_clear 自动进入 EXT-48（六十四房制：final 移至 EXT-48 通关），全程 689 步（662+27）")
	_check(String(s_z.family_by_room[51]) == "magnet_iron" and s_z.family_by_room.size() == 52,
		"family[51]=magnet_iron（拉晶与拉铁同串——差异5 冻结沿用）、五十二段 family 齐全")
	# ---- EXT-48 解法（潮轨：冻道困车 + 踩井沉车 + 翻回过潮，17 键 15 步）→ room_clear 进入 EXT-49 ----
	var ok_ext48: bool = _run_ops(s_z, ["right", "right", "right", "ice:right", "right",
		"ice:right", "right", "ice:right", "right"])
	s_z.advance_time(2.0)
	var ok_ext48b: bool = _run_ops(s_z, ["down", "left", "up", "down", "up", "right", "right", "right", "right"])
	_check(ok_ext48 and ok_ext48b and s_z.room_idx == 53 and s_z.state == "play" and int(s_z.steps) == 704,
		"EXT-48 解法（潮轨，15 步 + 3 冻不计步，冻道困车踩井沉车翻回过潮）：room_clear 自动进入 EXT-49（六十四房制：final 移至 EXT-49 通关），全程 704 步（689+15）")
	_check(String(s_z.family_by_room[52]) == "freeze_route" and s_z.family_by_room.size() == 53,
		"family[52]=freeze_route（F 冻桥入分类）、五十三段 family 齐全")
	# ---- EXT-49 解法（送货门：两箱接力投递，22 步）→ room_clear 进入 EXT-50 ----
	var ok_ext49: bool = _run_ops(s_z, ["down", "right", "right", "right", "up", "right", "right", "right",
		"left", "left", "down", "left", "left", "up", "right", "right", "right", "right",
		"up", "left", "left", "left"])
	_check(ok_ext49 and s_z.room_idx == 54 and s_z.state == "play" and int(s_z.steps) == 726,
		"EXT-49 解法（送货门，22 步，物传人留+对格占退最近位投递开关板）：room_clear 自动进入 EXT-50（六十四房制：final 移至 EXT-50 通关），全程 726 步（704+22）")
	_check(String(s_z.family_by_room[53]) == "plain" and s_z.family_by_room.size() == 54,
		"family[53]=plain（push:box:portal 不进分类器——差异5 冻结）、五十四段 family 齐全")
	# ---- EXT-50 解法（双踩：箱上板计 1 + 人滑入计 2 锁定 + row3 绕行，9 步）→ room_clear 进入 EXT-51 ----
	var ok_ext50: bool = _run_ops(s_z, ["right", "right", "right", "right", "right",
		"down", "right", "right", "up"])
	_check(ok_ext50 and s_z.room_idx == 55 and s_z.state == "play" and int(s_z.steps) == 735,
		"EXT-50 解法（双踩，9 步，停箱只计一次人滑入补第二脚）：room_clear 自动进入 EXT-51（六十四房制：final 移至 EXT-51 通关），全程 735 步（726+9）")
	_check(String(s_z.family_by_room[54]) == "plain" and s_z.family_by_room.size() == 55,
		"family[54]=plain（纯推箱）、五十五段 family 齐全——'s' 启用后占用表小写全满")
	# ---- EXT-51 解法（潮磨：引晶上潮格磨水 + F 冻桥过河 + 推箱上 S，21 键 20 步）→ room_clear 进入 EXT-52 ----
	var ok_ext51: bool = _run_ops(s_z, ["right"])
	s_z.advance_time(5.0)
	var ok_ext51b: bool = _run_ops(s_z, ["ice:right", "right", "down", "left", "down",
		"left", "left", "up", "right", "right", "right", "right", "right", "right",
		"down", "right", "up", "right", "up", "right"])
	_check(ok_ext51 and ok_ext51b and s_z.room_idx == 56 and s_z.state == "play" and int(s_z.steps) == 755,
		"EXT-51 解法（潮磨，20 步 + 1 冻不计步，引晶上潮格磨水冻桥过河推箱压板）：room_clear 自动进入 EXT-52（六十四房制：final 移至 EXT-52 通关），全程 755 步（735+20）")
	_check(String(s_z.family_by_room[55]) == "freeze_route" and s_z.family_by_room.size() == 56,
		"family[55]=freeze_route（F 冻桥入分类）、五十六段 family 齐全")
	# ---- EXT-52 解法（连碎：推 A 入坑连锁 B 同碎 + F×2 冻双水 + 踏冰进 G，9 键 7 步）→ room_clear 进入 EXT-53 ----
	var ok_ext52: bool = _run_ops(s_z, ["right", "right", "right",
		"ice:right", "right", "ice:right", "right", "right"] + ["right"])
	_check(ok_ext52 and s_z.room_idx == 57 and s_z.state == "play" and int(s_z.steps) == 762,
		"EXT-52 解法（连碎，7 步 + 2 冻不计步，推 A 入坑连锁 B 同碎双坑化水）：room_clear 自动进入 EXT-53（六十四房制：final 移至 EXT-54 通关），全程 762 步（755+7）")
	_check(String(s_z.family_by_room[56]) == "freeze_route" and s_z.family_by_room.size() == 57,
		"family[56]=freeze_route（F 冻桥入分类）、五十七段 family 齐全")
	# ---- EXT-53 解法（弹晶：推晶上垫沿向弹 2 格落坑化水 + F 冻冰过河进 G，9 键 8 步）→ room_clear 进入 EXT-54 ----
	var ok_ext53: bool = _run_ops(s_z, ["right", "right", "right", "right",
		"ice:right", "right", "right", "right", "right"])
	_check(ok_ext53 and s_z.room_idx == 58 and s_z.state == "play" and int(s_z.steps) == 770,
		"EXT-53 解法（弹晶，8 步 + 1 冻不计步，推晶上垫弹 2 格落坑化水冻桥进 G）：room_clear 自动进入 EXT-54（六十四房制：final 移至 EXT-54 通关），全程 770 步（762+8）")
	_check(String(s_z.family_by_room[57]) == "freeze_route" and s_z.family_by_room.size() == 58,
		"family[57]=freeze_route（F 冻桥入分类）、五十八段 family 齐全")
	# ---- EXT-54 解法（滑晶：推晶上滑道出道入坑化水 + F 冻冰过河进 G，7 键 6 步）→ room_clear 进入 EXT-55 ----
	var ok_ext54: bool = _run_ops(s_z, ["right", "right", "right",
		"ice:right", "right", "right", "right"])
	_check(ok_ext54 and s_z.room_idx == 59 and s_z.state == "play" and int(s_z.steps) == 776,
		"EXT-54 解法（滑晶，6 步 + 1 冻不计步，推晶上滑道出道入坑化水冻桥进 G）：room_clear 自动进入 EXT-55（六十四房制：final 移至 EXT-58 通关），全程 776 步（770+6）")
	_check(String(s_z.family_by_room[58]) == "freeze_route" and s_z.family_by_room.size() == 59,
		"family[58]=freeze_route（F 冻桥入分类）、五十九段 family 齐全")
	# ---- EXT-55 解法（车碾板：等 14 拍车碾双踩板咬合 + 挡轨折返 + 走位进 G，10 步）→ room_clear 进入 EXT-56 ----
	s_z.advance_time(14.0)
	var ok_ext55: bool = _run_ops(s_z, ["down", "right", "right", "right", "right",
		"right", "right", "right", "right", "down"])
	_check(ok_ext55 and s_z.room_idx == 60 and s_z.state == "play" and int(s_z.steps) == 786,
		"EXT-55 解法（车碾板，10 步等拍不计步，车碾双踩板×2 咬合门开走位进 G）：room_clear 自动进入 EXT-56（六十四房制：final 移至 EXT-58 通关），全程 786 步（776+10）")
	_check(String(s_z.family_by_room[59]) == "plain" and s_z.family_by_room.size() == 60,
		"family[59]=plain（无工具纯走位+环境 Actor）、六十段 family 齐全")
	# ---- EXT-56 解法（车越堑：等 23 拍巡轨车两越断口碾双踩板咬合 + 走位进 G，10 步）→ room_clear 进入 EXT-57 ----
	s_z.advance_time(23.0)
	var ok_ext56: bool = _run_ops(s_z, ["down", "right", "right", "right", "right",
		"right", "right", "right", "right", "down"])
	_check(ok_ext56 and s_z.room_idx == 61 and s_z.state == "play" and int(s_z.steps) == 796,
		"EXT-56 解法（车越堑，10 步等拍不计步，车两越断口碾双踩板×2 咬合门开走位进 G）：room_clear 自动进入 EXT-57（六十四房制：final 移至 EXT-58 通关），全程 796 步（786+10）")
	_check(String(s_z.family_by_room[60]) == "plain" and s_z.family_by_room.size() == 61,
		"family[60]=plain（无工具纯走位+环境 Actor）、六十一段 family 齐全")
	# ---- EXT-57 解法（晶潮渡：晶上带摆渡入潮磨水 + F 冻桥 + 搭带过河进 G，7 步）→ 六十四房 final ----
	var ok_ext57a: bool = _run_ops(s_z, ["right", "right", "right"])
	s_z.advance_time(2.0)
	s_z.advance_time(2.5)
	var ok_ext57b: bool = _run_ops(s_z, ["ice:right"])
	s_z.advance_time(1.0)
	var ok_ext57c: bool = _run_ops(s_z, ["right", "right", "right", "right"])
	_check(ok_ext57a and ok_ext57b and ok_ext57c and s_z.room_idx == 62 and s_z.state == "play" and int(s_z.steps) == 803,
		"EXT-57 解法（晶潮渡，7 步 + 1 冻不计步，晶上带摆渡入潮磨水冻桥搭带过河进 G）：room_clear 自动进入 EXT-58（六十四房制：final 移至 EXT-58 通关），全程 803 步（796+7）")
	_check(String(s_z.family_by_room[61]) == "freeze_route" and s_z.family_by_room.size() == 62,
		"family[61]=freeze_route（F 冻桥入分类）、六十二段 family 齐全")
	# ---- EXT-58 解法（桥渡：铁上带摆渡过桥压重压板 + 玩家搭带过桥绕东进 G，7 步）→ 六十四房 final ----
	var ok_ext58a: bool = _run_ops(s_z, ["right", "right"])
	for i in 4:
		s_z.advance_time(1.0)
	var ok_ext58b: bool = _run_ops(s_z, ["down", "right", "right", "up"])
	_check(ok_ext58a and ok_ext58b and s_z.room_idx == 63 and s_z.state == "play" and int(s_z.steps) == 809,
		"EXT-58 解法（桥渡，6 步等拍不计步，铁上带摆渡过桥压重压板门开搭带过河进 G）：room_clear 自动进入 EXT-59（六十四房制：final 移至 EXT-59 通关），全程 809 步（803+6）")
	_check(String(s_z.family_by_room[62]) == "plain" and s_z.family_by_room.size() == 63,
		"family[62]=plain（无工具纯走位+环境带运）、六十三段 family 齐全")
	# ---- EXT-59 解法（候闸：车候潮过闸压重压板门开 + 玩家 row3 直走绕行进 G，11 步）→ 六十四房 final ----
	var ok_ext59a: bool = _run_ops(s_z, ["down", "right", "right", "right", "right",
		"right", "right", "right", "right", "right"])
	s_z.advance_time(5.0)
	var ok_ext59b: bool = _run_ops(s_z, ["up"])
	_check(ok_ext59a and ok_ext59b and s_z.state == "final" and int(s_z.steps) == 820,
		"EXT-59 解法（候闸，11 步等拍不计步，车候潮过闸压重压板门开 + 玩家 row3 绕行进 G）：state=final，全程 820 步（809+11，六十四房制终点）")
	var z_ev2: Array = s_z.drain_events()
	_check(z_ev2.size() > 0 and String(z_ev2[z_ev2.size() - 1].type) == "final" and int(z_ev2[z_ev2.size() - 1].steps) == 820,
		"final 事件携带步数 820，批次可整体读取")

	print("==== 汇总：%d PASS / %d FAIL ====" % [passes, fails])
	quit(1 if fails > 0 else 0)
