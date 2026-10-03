extends SceneTree
## demo-11 v2 headless 测试：房间5「开放实验房」的火融冰传播规则 + 状态空间搜索
## 用例1 火把工具融冰 → 冰上铁块沉底（传播：铁块分支，格子还原成不可走的水）
## 用例2 倒计时融冰（_process 结算）→ 冰上木箱沉成永久桥（传播：木箱分支）
## 用例3 倒计时融冰 → 玩家站冰位移到相邻最近地板（传播：玩家分支）
##      注：房间3 火把旁无水格可冻，倒计时路径以「注入热源倒计时」在房间5 等价驱动（同一 _process 融化结算代码）
## 用例4 预写 3 条标准解法（箱桥流 / 铁磁流 / 混合流-含融冰）在真实场景可通关
## 用例5 状态空间搜索（限深 DFS，状态哈希去重，节点上限 20000）：
##      ≥3 个不同通关终态；≥1 条解法不在预设序列中；≥1 条解法经过融冰动作；超限报 FAIL 并输出已探索数
## 运行：godot --headless --path game -s res://tests/test_demo11_v2.gd

const NODE_CAP := 20000
const DEPTH_LIMIT := 14
const MAX_SOLUTIONS := 400

## 预写 3 条标准解法（动作序列，right/up/... 为 move，tool:dir 为 use_tool）
## A 箱桥流：B2 沉水成桥过河 → I1 推上开关A(9,4) → B1 推上开关B(9,5) → 抵达门(8,3)
const PRESET_A := ["down", "right", "right", "right", "right", "up", "right", "right", "right", "left", "down", "right", "up", "up"]
## B 铁磁流：F 冻冰过河 → I1 推上开关A → H 磁石隔空把 I2 拉上开关B → 抵达门
const PRESET_B := ["right", "right", "ice:right", "right", "right", "right", "right", "right", "left", "down", "magnet:right", "up", "right", "up"]
## C 混合流：F 冻冰过河 → G 融冰（经过融冰动作）→ I1 推上开关A → B1 推上开关B → 抵达门
const PRESET_C := ["right", "right", "ice:right", "right", "right", "fire:left", "right", "right", "right", "left", "down", "right", "up", "up"]
const PRESETS := [PRESET_A, PRESET_B, PRESET_C]

var log_lines: Array = []
var passes := 0
var fails := 0

# 搜索器状态
var visited := {}        # 状态哈希 -> 见过的最大剩余深度
var seen_finals := {}    # 通关终态哈希 -> true
var solutions := []      # {ops: Array, melt: bool}
var explored := 0        # 已探索节点数
var budget := 0          # 本阶段剩余节点预算（全局上限 NODE_CAP）
var capped := false      # 是否触到节点上限


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)
	log_lines.append(t)
	var f := FileAccess.open("user://test11v2log.txt", FileAccess.WRITE)
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


func _count_type(s: Control, type: String) -> int:
	var n := 0
	for o in s.objects:
		if String(o.type) == type:
			n += 1
	return n


# ---------------- 用例1-3：传播规则 ----------------

func _case_propagation(s: Control) -> void:
	# 用例1 火把工具融冰 → 冰上铁块沉底：先冻铁块落点 (4,4)，绕东侧到 I1 右侧逐格左推上冰，再火把融化
	s.load_room(4)
	var ops := ["right", "right", "ice:right", "right", "right", "up", "up", "right", "right",
		"right", "right", "down", "down", "left", "left", "left", "left", "fire:left"]
	var ok := _run_ops(s, ops)
	_check(ok and not _obj_at(s, "iron", 4, 4) and _tile_at(s, 4, 4) == "water" and _count_type(s, "iron") == 1,
		"用例1 融冰传播-铁块：G 融掉铁块脚下的冰 → 铁块沉底消失，该格还原成不可走的水，场上仅剩 1 块铁")

	# 用例2 倒计时融冰 → 冰上木箱沉成永久桥：先冻 (4,5)，再把 B2 推上冰面，注入热源倒计时后结算
	s.load_room(4)
	var ok2 := _run_ops(s, ["right", "right", "down", "ice:right", "up", "left", "left", "down", "right", "right"])
	var on_ice := ok2 and _obj_at(s, "box", 4, 5) and _tile_at(s, 4, 5) == "ice"
	s.melt_queue.append({x = 4, y = 5, left = 0.001})
	await process_frame
	await process_frame
	_check(on_ice and not _obj_at(s, "box", 4, 5) and _tile_at(s, 4, 5) == "bridge" and _count_type(s, "box") == 1,
		"用例2 融冰传播-木箱：倒计时融化冰上木箱的支撑 → 木箱沉入水格变永久桥，木箱消失")

	# 用例3 倒计时融冰 → 玩家站冰位移到相邻最近地板（(4,4) 融化 → 最近可站立为 (3,4)）
	s.load_room(4)
	var ok3 := _run_ops(s, ["right", "right", "ice:right", "right"])
	var on_ice3 := ok3 and _px(s) == 4 and _py(s) == 4 and _tile_at(s, 4, 4) == "ice"
	s.melt_queue.append({x = 4, y = 4, left = 0.001})
	await process_frame
	await process_frame
	_check(on_ice3 and _px(s) == 3 and _py(s) == 4 and _tile_at(s, 4, 4) == "water",
		"用例3 融冰传播-玩家：脚下冰面被融化 → 玩家不惩罚地退回相邻最近地板格 (3,4)，该格还原成水")


# ---------------- 用例4：预写标准解法可通关 ----------------

func _case_presets(s: Control) -> void:
	var names := ["箱桥流", "铁磁流", "混合流-含融冰"]
	for i in PRESETS.size():
		s.load_room(4)
		var ok: bool = _run_ops(s, PRESETS[i])
		_check(ok and s.state == "final",
			"用例4%s 预设标准解法 %d（%s）在开放实验房可通关 → final" % [char(97 + i), i + 1, String(names[i])])


# ---------------- 用例5：状态空间搜索 ----------------

func _state_key(s: Control) -> String:
	var objs := []
	for o in s.objects:
		objs.append("%s:%d,%d" % [String(o.type), int(o.x), int(o.y)])
	objs.sort()
	return "%d,%d|%s|%s" % [_px(s), _py(s), ",".join(objs), ",".join(s.grid)]


func _snap(s: Control) -> Dictionary:
	var objs := []
	for o in s.objects:
		objs.append(o.duplicate())
	return {
		player = {x = _px(s), y = _py(s)},
		objs = objs,
		grid = s.grid.duplicate(),
		state = String(s.state),
	}


func _restore(s: Control, snap: Dictionary) -> void:
	s.player = {x = int(snap.player.x), y = int(snap.player.y)}
	var objs := []
	for o in snap.objs:
		objs.append(o.duplicate())
	s.objects = objs
	s.grid = snap.grid.duplicate()
	s.state = String(snap.state)
	s.slide_t = 1.0
	s.pushed_idx = -1


## 应用一个动作。返回 -1=非法未生效 / 0=生效未融冰 / 1=生效且触发融冰
func _apply(s: Control, act: String) -> int:
	if act.begins_with("ice:") or act.begins_with("fire:") or act.begins_with("magnet:"):
		var parts := act.split(":")
		var tool := String(parts[0])
		var dir := String(parts[1])
		var dv: Vector2i = s.DIR_VECS[dir]
		var tx: int = _px(s) + dv.x
		var ty: int = _py(s) + dv.y
		var before := ""
		if tx >= 0 and tx < 12 and ty >= 0 and ty < 7:
			before = String(s.grid[ty * 12 + tx])
		var ok: bool = bool(s.use_tool(tool, dir))
		if not ok:
			return -1
		if tool == "fire" and before == "ice":
			var after := ""
			if tx >= 0 and tx < 12 and ty >= 0 and ty < 7:
				after = String(s.grid[ty * 12 + tx])
			if after != "ice":
				return 1
		return 0
	var ok2: bool = bool(s.move(act))
	return 0 if ok2 else -1


## 搜索瞄准点：最近的未压住开关；全部压住则为终点门
func _search_target(s: Control) -> Dictionary:
	var best := {}
	var best_d := 9999
	for o in s.objects:
		var od: Dictionary = o
		if String(od.type) != "switch" or bool(s._switch_pressed(od)):
			continue
		var d: int = absi(int(od.x) - _px(s)) + absi(int(od.y) - _py(s))
		if d < best_d:
			best_d = d
			best = {x = int(od.x), y = int(od.y)}
	if best.is_empty():
		best = {x = int(s.gate_pos.x), y = int(s.gate_pos.y)}
	return best


func _ordered_actions(s: Control, mode: String) -> Array:
	var dirs := ["up", "down", "left", "right"]
	var target := _search_target(s)
	var px := _px(s)
	var py := _py(s)
	var sorted_dirs := dirs.duplicate()
	sorted_dirs.sort_custom(func(a, b):
		var va: Vector2i = s.DIR_VECS[a]
		var vb: Vector2i = s.DIR_VECS[b]
		var da: int = absi(px + va.x - int(target.x)) + absi(py + va.y - int(target.y))
		var db: int = absi(px + vb.x - int(target.x)) + absi(py + vb.y - int(target.y))
		return da < db)
	var acts := []
	if mode == "melt":
		for d in dirs:
			acts.append("fire:" + d)
		for d in dirs:
			acts.append("ice:" + d)
		for d in sorted_dirs:
			acts.append(d)
		for d in dirs:
			acts.append("magnet:" + d)
	elif mode == "shuffled":
		var all_acts := []
		for d in dirs:
			all_acts.append(d)
		for d in dirs:
			all_acts.append("ice:" + d)
		for d in dirs:
			all_acts.append("fire:" + d)
		for d in dirs:
			all_acts.append("magnet:" + d)
		all_acts.shuffle()
		acts = all_acts
	else:
		for d in sorted_dirs:
			acts.append(d)
		for d in dirs:
			acts.append("ice:" + d)
		for d in dirs:
			acts.append("fire:" + d)
		for d in dirs:
			acts.append("magnet:" + d)
	return acts


func _dfs(s: Control, depth_left: int, path: Array, melt_path: Array, mode: String) -> void:
	if capped or solutions.size() >= MAX_SOLUTIONS or budget <= 0:
		return
	var key := _state_key(s)
	if visited.has(key) and int(visited[key]) >= depth_left:
		return
	visited[key] = depth_left
	explored += 1
	budget -= 1
	if explored >= NODE_CAP:
		capped = true
	if s.is_win():
		if not seen_finals.has(key):
			seen_finals[key] = true
			solutions.append({ops = path.duplicate(), melt = melt_path.has(true)})
		return
	if depth_left <= 0 or capped:
		return
	var snap := _snap(s)
	for act_v in _ordered_actions(s, mode):
		var act: String = String(act_v)
		var res: int = _apply(s, act)
		if res < 0:
			continue
		var np := path.duplicate()
		np.append(act)
		var nm := melt_path.duplicate()
		nm.append(res == 1)
		_dfs(s, depth_left - 1, np, nm, mode)
		_restore(s, snap)
		if capped or solutions.size() >= MAX_SOLUTIONS or budget <= 0:
			return


func _matches_preset(ops: Array) -> bool:
	for preset_v in PRESETS:
		var preset: Array = preset_v
		if ops.size() <= preset.size():
			var prefix := true
			for i in ops.size():
				if String(ops[i]) != String(preset[i]):
					prefix = false
					break
			if prefix:
				return true
	return false


func _has_melt_solution() -> bool:
	for sol_v in solutions:
		var sol: Dictionary = sol_v
		if bool(sol.melt):
			return true
	return false


func _case_search(s: Control) -> void:
	s.load_room(4)
	explored = 0
	capped = false
	solutions = []
	seen_finals = {}
	visited = {}
	# 阶段1 常规贪心（先移动后工具）：找主流解
	budget = 9000
	_dfs(s, DEPTH_LIMIT, [], [], "normal")
	# 阶段2 融冰优先（先 fire/ice）：找经过融冰动作的解
	if not _has_melt_solution():
		visited = {}
		budget = mini(NODE_CAP - explored, 8000)
		_dfs(s, DEPTH_LIMIT, [], [], "melt")
	# 阶段3 固定种子乱序兜底多样性
	if solutions.size() < 3 or not _has_melt_solution():
		visited = {}
		seed(20261002)
		budget = NODE_CAP - explored
		_dfs(s, DEPTH_LIMIT, [], [], "shuffled")

	var distinct_finals: int = seen_finals.size()
	var non_preset := []
	var melt_sols := []
	var preset_hits := 0
	for sol_v in solutions:
		var sol: Dictionary = sol_v
		if bool(sol.melt):
			melt_sols.append(sol)
		if _matches_preset(sol.ops):
			preset_hits += 1
		else:
			non_preset.append(sol)
	_log("搜索统计：已探索节点 %d / 上限 %d，触限=%s，收集解 %d 条（去重终态 %d 个；与预设重合 %d 条；非预设 %d 条；含融冰解 %d 条）" % [
		explored, NODE_CAP, str(capped), solutions.size(), distinct_finals, preset_hits, non_preset.size(), melt_sols.size()])
	if non_preset.size() > 0:
		var ex: Dictionary = non_preset[0]
		_log("非预设解举例（%d 步，含融冰=%s）：%s" % [ex.ops.size(), str(ex.melt), ", ".join(ex.ops)])
	if melt_sols.size() > 0:
		var ex2: Dictionary = melt_sols[0]
		_log("融冰解举例（%d 步）：%s" % [ex2.ops.size(), ", ".join(ex2.ops)])
	for i in solutions.size():
		var sol2: Dictionary = solutions[i]
		_log("  解%d：%s | %d 步 | 融冰=%s | 预设重合=%s" % [i + 1, ", ".join(sol2.ops), sol2.ops.size(), str(sol2.melt), str(_matches_preset(sol2.ops))])

	_check(not capped, "用例5a 性能护栏：搜索在节点上限 %d 内完成（已探索 %d，未超限）" % [NODE_CAP, explored])
	_check(distinct_finals >= 3, "用例5b 多解涌现：搜索找到的不同通关终态 %d 个 ≥ 3" % distinct_finals)
	_check(non_preset.size() >= 1, "用例5c 非编排解：至少 1 条解法不在 3 条预设标准解法序列中（共 %d 条）" % non_preset.size())
	_check(_has_melt_solution(), "用例5d 传播可被搜索利用：存在至少 1 条经过「融冰」动作的解")


# ---------------- 主流程 ----------------

func _run() -> void:
	await process_frame
	_log("demo-11 v2 headless 测试开始（传播规则 + 开放实验房状态空间搜索）")
	var s: Control = await _new_scene()
	await _case_propagation(s)
	_case_presets(s)
	_case_search(s)
	_log("==== 汇总：%d PASS / %d FAIL ====" % [passes, fails])
	quit(1 if fails > 0 else 0)
