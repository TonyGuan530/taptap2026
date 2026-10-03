extends SceneTree
## demo-11 塞尔达式箱庭谜题 headless 测试（纯格子状态机，全部同步调用，无 physics 等待）
## 用例1 基础移动与撞墙；用例2 推箱与推箱受阻；用例3 推箱入水成桥/入坑填路
## 用例4 冰霜杖冻冰 + 火把融冰；用例5 火把烧箱；用例6 磁石隔空拉铁
## 用例7 开关与门（箱压/人踩/离开 + 房间5 双开关需同时）
## 用例8 房间1 双解；用例9 房间2/4 各双解；用例10 能力门禁；用例11 全流程 5 房 → final + steps 一致
## 运行：godot --headless --path game -s res://tests/test_demo11.gd

## 动作序列常量（right/down/left/up 为 move，ice:/fire:/magnet: 为 use_tool）
const SEQ_R1 := ["right", "right", "right", "right", "down", "left", "left", "left", "left", "down", "down", "down"]
const SEQ_R1B := ["down", "down", "right", "right", "right", "left", "left", "down", "down", "left"]
const SEQ_R2A := ["down", "down", "right", "right", "right", "right", "right", "right", "right", "right", "right"]
const SEQ_R2B := ["right", "right", "right", "ice:right", "right", "right", "down", "down", "right", "right", "right", "right"]
const SEQ_R3A := ["down", "down", "down", "right", "right", "right", "right", "right", "up", "fire:left", "down", "left", "left", "left", "left", "left", "up", "up", "up", "right", "right", "down", "left", "down", "right", "right", "right", "down", "right", "right", "right", "right"]
const SEQ_R4A := ["down", "down", "magnet:right", "magnet:right", "magnet:right", "magnet:right", "magnet:right", "magnet:right", "magnet:right", "down", "right", "right", "right", "right", "up", "right", "right", "down", "down", "right", "right"]
const SEQ_R4B := ["down", "down", "right", "right", "right", "right", "right", "right", "up", "right", "right", "right", "down", "left", "left", "left", "left", "left", "left", "left", "down", "right", "right", "up", "right", "right", "down", "down", "right", "right"]
const SEQ_R5A := ["right", "right", "ice:right", "right", "right", "down", "right", "down", "down", "right", "up", "up"]
const SEQ_R5B := ["down", "down", "left", "left"]
const SEQ_R5C := ["up", "right", "right", "up", "right", "right", "down", "down", "down", "right", "up", "up", "up", "up"]

var log_lines: Array = []
var passes := 0
var fails := 0
var moves_made := 0


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)
	log_lines.append(t)
	var f := FileAccess.open("user://test11log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()


func _check(cond: bool, tag: String) -> void:
	if cond:
		passes += 1
		_log("PASS " + tag)
	else:
		fails += 1
		_log("FAIL " + tag)


func _new_scene() -> Control:
	var s: Control = load("res://demo11_sandbox.tscn").instantiate()
	root.add_child(s)
	await process_frame
	return s


## 执行一段混合动作序列：move 成功则计入 moves_made；返回是否全部成功
func _run_ops(s: Control, ops: Array) -> bool:
	var all_ok := true
	for op in ops:
		var o := String(op)
		var ok := false
		if o.begins_with("ice:") or o.begins_with("fire:") or o.begins_with("magnet:"):
			var parts := o.split(":")
			ok = bool(s.use_tool(String(parts[0]), String(parts[1])))
		else:
			ok = bool(s.move(o))
			if ok:
				moves_made += 1
		if not ok:
			all_ok = false
	return all_ok


func _px(s: Control) -> int:
	return int(s.player.x)


func _py(s: Control) -> int:
	return int(s.player.y)


func _tile_at(s: Control, x: int, y: int) -> String:
	return String(s.grid[y * 12 + x])


func _obj_at(s: Control, type: String, x: int, y: int) -> bool:
	for o in s.objects:
		var od: Dictionary = o
		if String(od.type) == type and int(od.x) == x and int(od.y) == y:
			return true
	return false


func _iron_x(s: Control) -> int:
	for o in s.objects:
		var od: Dictionary = o
		if String(od.type) == "iron":
			return int(od.x)
	return -1


func _run() -> void:
	await process_frame
	_log("demo-11 塞尔达式箱庭谜题 headless 测试开始")
	var s: Control = await _new_scene()

	# --- 用例1 基础移动与撞墙 ---
	s.load_room(0)
	_check(_px(s) == 1 and _py(s) == 1 and not s.is_win(),
		"用例1a 载入：房间1 玩家起点 (1,1)，初始未通关")
	var ok_r: bool = s.move("right")
	_check(ok_r and _px(s) == 2 and _py(s) == 1, "用例1b 右移：move 返回 true，玩家到 (2,1)")
	var ok_u: bool = s.move("up")
	_check(not ok_u and _px(s) == 2 and _py(s) == 1, "用例1c 撞墙：上方是墙，move 返回 false 且位置不变")
	var ok_l: bool = s.move("left")
	var ok_l2: bool = s.move("left")
	_check(ok_l and not ok_l2 and _px(s) == 1, "用例1d 左移一步到 (1,1) 后再左移撞墙返回 false")
	var ok_d: bool = s.move("down")
	var ok_bad: bool = s.move("jump")
	_check(ok_d and not ok_bad, "用例1e 下移到 (1,2) 成功；非法方向名返回 false")

	# --- 用例2 推箱与推箱受阻 ---
	s.load_room(0)
	var walk_ok := true
	for k in 4:
		walk_ok = bool(s.move("right")) and walk_ok
	var push1: bool = s.move("down")
	_check(walk_ok and push1 and _obj_at(s, "box", 5, 3) and not _obj_at(s, "box", 5, 2) and _px(s) == 5 and _py(s) == 2,
		"用例2a 推箱：木箱 (5,2) 被推到 (5,3)，玩家进占原位 (5,2)")
	for k in 3:
		s.move("left")
	s.move("down")
	var push2: bool = s.move("right")
	var push3: bool = s.move("right")
	_check(push2 and not push3 and _px(s) == 3 and _obj_at(s, "box", 4, 3),
		"用例2b 推箱受阻：目标格被另一木箱占据时 move 返回 false、玩家原地不动")

	# --- 用例3 推箱入水成桥 / 推箱入坑填路 ---
	s.load_room(1)
	var pre := true
	pre = bool(s.move("down")) and pre
	pre = bool(s.move("down")) and pre
	for k in 4:
		pre = bool(s.move("right")) and pre
	var on_bridge: bool = _tile_at(s, 5, 3) == "bridge" and _px(s) == 5 and _py(s) == 3 and not _obj_at(s, "box", 5, 3)
	var cross: bool = s.move("right")
	_check(pre and on_bridge and cross,
		"用例3a 推箱入水：木箱被推进水格 (5,3) 变成桥面（bridge、木箱消失），玩家踩上去并继续前进")
	s.load_room(1)
	var pre2: bool = bool(s.move("right"))
	pre2 = bool(s.move("right")) and pre2
	pre2 = bool(s.move("down")) and pre2
	var pit1: bool = s.move("down")
	var pit2: bool = s.move("down")
	var pit3: bool = s.move("down")
	_check(pre2 and pit1 and pit2 and _tile_at(s, 3, 5) == "fill" and pit3,
		"用例3b 推箱入坑：深坑 (3,5) 被木箱填成可走路面（fill）且玩家踩上去")

	# --- 用例4 冰霜杖冻冰 + 火把融冰 ---
	s.load_room(1)
	for k in 3:
		s.move("right")
	var fz: bool = s.use_tool("ice", "right")
	var fz_tile: String = _tile_at(s, 5, 1)
	var on_ice: bool = s.move("right")
	var fz_bad: bool = s.use_tool("ice", "right")
	_check(fz and fz_tile == "ice" and on_ice and not fz_bad,
		"用例4a 冰霜杖：水 (5,1) 冻成冰面（ice）且可走；对非水格使用返回 false")
	s.load_room(2)
	for k in 3:
		s.move("down")
	for k in 8:
		s.move("right")
	s.move("up")
	s.move("up")
	s.move("up")
	var fz2: bool = s.use_tool("ice", "right")
	var fz2_tile: String = _tile_at(s, 10, 1)
	var step_on: bool = s.move("right")
	s.move("left")
	var melt: bool = s.use_tool("fire", "right")
	var melt_tile: String = _tile_at(s, 10, 1)
	var step_water: bool = s.move("right")
	_check(fz2 and fz2_tile == "ice" and step_on and melt and melt_tile == "water" and not step_water,
		"用例4b 房间3 冻融循环：F 冻水成冰且可走 → 退一步 G 火把融冰还原成水（不可走）")

	# --- 用例5 火把烧箱 ---
	s.load_room(2)
	for k in 3:
		s.move("down")
	for k in 5:
		s.move("right")
	s.move("up")
	var burn: bool = s.use_tool("fire", "left")
	var burn_bad: bool = s.use_tool("fire", "down")
	_check(burn and not _obj_at(s, "box", 5, 3) and _obj_at(s, "box", 6, 2) and not burn_bad,
		"用例5 火把烧箱：面前木箱 (5,3) 被移除，其余物件不受影响；对空地板使用返回 false")

	# --- 用例6 磁石隔空拉铁 ---
	s.load_room(3)
	s.move("down")
	s.move("down")
	var pull1: bool = s.use_tool("magnet", "right")
	var iron_x1: int = _iron_x(s)
	var pulls_ok := true
	for k in 6:
		pulls_ok = bool(s.use_tool("magnet", "right")) and pulls_ok
	var iron_x7: int = _iron_x(s)
	var pull_adj: bool = s.use_tool("magnet", "right")
	var pull_none: bool = s.use_tool("magnet", "down")
	_check(pull1 and iron_x1 == 8 and pulls_ok and iron_x7 == 2 and not pull_adj and not pull_none,
		"用例6 磁石：铁块从 9 列被逐格拉到 2 列（开关上）；紧贴玩家与视线无铁块时返回 false")

	# --- 用例7 开关与门 ---
	s.load_room(0)
	var g0: bool = s.gate_open()
	for k in 4:
		s.move("right")
	var press_box: bool = s.move("down")
	var g1: bool = s.gate_open()
	s.move("left")
	var g2: bool = s.gate_open()
	s.move("right")
	var g2b: bool = s.gate_open()
	s.move("down")   # 把箱推离开关
	s.move("left")    # 玩家离开开关格
	var g3: bool = s.gate_open()
	_check(not g0 and press_box and g1 and g2 and g2b and not g3,
		"用例7a 开关与门：箱压=开；人绕行箱仍压=开；把箱推离=关")
	s.load_room(4)
	var pre5: bool = _run_ops(s, SEQ_R5A)
	var g_half: bool = s.gate_open()
	var pre5b: bool = _run_ops(s, SEQ_R5B)
	for k in 3:
		_run_ops(s, ["magnet:right"])
	var g_both: bool = s.gate_open()
	_run_ops(s, ["up"])
	var g_stay: bool = s.gate_open()
	_check(pre5 and pre5b and not g_half and g_both and g_stay,
		"用例7b 房间5 双开关：仅箱压住一个时门不开；走到铁块同排磁拉上开关B后双压才开门，且人走开门保持开")

	# --- 用例8 房间1 双解 ---
	s.load_room(0)
	var a_ok: bool = _run_ops(s, SEQ_R1)
	_check(a_ok and s.room_idx == 1, "用例8a 房间1 解法A（上箱下推压开关）12 步通关：room_idx=1")
	s.load_room(0)
	var b_ok: bool = _run_ops(s, SEQ_R1B)
	_check(b_ok and s.room_idx == 1, "用例8b 房间1 解法B（下箱右推压开关）10 步通关：room_idx=1")

	# --- 用例9 房间2/4 各双解 ---
	s.load_room(1)
	var r2a: bool = _run_ops(s, SEQ_R2A)
	_check(r2a and s.room_idx == 2, "用例9a 房间2 解法A（推箱入水成桥）11 步通关：room_idx=2")
	s.load_room(1)
	var r2b: bool = _run_ops(s, SEQ_R2B)
	_check(r2b and s.room_idx == 2, "用例9b 房间2 解法B（冰霜杖冻冰过河）11 步+1 工具通关：room_idx=2")
	s.load_room(3)
	var r4a: bool = _run_ops(s, SEQ_R4A)
	_check(r4a and s.room_idx == 4, "用例9c 房间4 解法A（磁石隔空拉铁 7 次）14 步通关：room_idx=4")
	s.load_room(3)
	var r4b: bool = _run_ops(s, SEQ_R4B)
	_check(r4b and s.room_idx == 4, "用例9d 房间4 解法B（绕进围栏长路推铁 30 步）通关：room_idx=4")

	# --- 用例10 能力门禁 ---
	var tools_match := true
	for i in s.ROOMS.size():
		s.load_room(i)
		if s.tools != s.ROOMS[i].tools:
			tools_match = false
	s.load_room(0)
	var deny1: bool = s.use_tool("ice", "right")
	var deny2: bool = s.use_tool("magnet", "right")
	s.load_room(1)
	var deny3: bool = s.use_tool("magnet", "right")
	var deny4: bool = s.use_tool("fire", "right")
	_check(tools_match and not deny1 and not deny2 and not deny3 and not deny4,
		"用例10 能力门禁：每关 tools 与 ROOMS 表一致；未解锁能力 use_tool 一律 false")

	# --- 用例11 全流程：5 房间依次通关 → final，steps 与成功移动数一致 ---
	var base_steps: int = s.steps
	moves_made = 0
	s.load_room(0)
	var f1: bool = _run_ops(s, SEQ_R1)
	_check(f1 and s.room_idx == 1, "流程1 房间1（解法A）通过")
	var f2: bool = _run_ops(s, SEQ_R2A)
	_check(f2 and s.room_idx == 2, "流程2 房间2（解法A 推箱成桥）通过")
	var f3: bool = _run_ops(s, SEQ_R3A)
	var f3_mid: bool = f3 and s.room_idx == 2 and s.gate_open() and _obj_at(s, "box", 6, 3)
	_check(f3_mid, "流程3 房间3（解法A 火烧+推箱压开关）：门已开、木箱在开关上")
	var win3: bool = bool(s.move("down"))
	if win3:
		moves_made += 1
	_check(win3 and s.room_idx == 3, "流程3 房间3 通过（进入房间4）")
	var f4: bool = _run_ops(s, SEQ_R4A)
	_check(f4 and s.room_idx == 4, "流程4 房间4（解法A 磁石拉铁）通过（进入房间5）")
	var f5a: bool = _run_ops(s, SEQ_R5A)
	var mid5: bool = f5a and s.room_idx == 4 and not s.gate_open() and _obj_at(s, "box", 7, 1)
	_check(mid5, "流程5 房间5：冻冰过水+木箱压上开关A，单开关不足门仍关")
	_run_ops(s, SEQ_R5B)
	for k in 3:
		_run_ops(s, ["magnet:right"])
	var mid5b: bool = s.gate_open() and _obj_at(s, "iron", 7, 4)
	_check(mid5b, "流程5 房间5：磁石把铁块拉上开关B，双开关同时压住门开")
	var f5c: bool = _run_ops(s, SEQ_R5C)
	_check(f5c and s.state == "final", "用例11a 全流程：5 个房间依次通关 → state=final")
	_check(s.steps - base_steps == moves_made,
		"用例11b 步数：steps 增量 %d 与成功移动次数 %d 一致（工具使用不计数）" % [s.steps - base_steps, moves_made])
	_check(s.steps - base_steps == 12 + 11 + 31 + 1 + 14 + 29,
		"用例11c 步数合计：全程 98 步（房间1=12 房间2=11 房间3=31+1 房间4=14 房间5=29）")

	_log("==== 汇总：%d PASS / %d FAIL ====" % [passes, fails])
	quit(1 if fails > 0 else 0)
