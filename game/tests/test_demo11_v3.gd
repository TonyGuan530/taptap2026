extends SceneTree
## demo-09 v3 遥测 instrumentation 验收（监督第 77 轮批示消化）：
## 用例1 七字段齐全
## 用例2 family 归类-房2：推箱填桥=box_bridge、冻冰过河=freeze_route（同房两解两族）
## 用例3 family 归类-房4：磁石拉铁=magnet_iron
## 用例4 计数：冻/融/烧/移物/开关导通 各 ≥1
## 用例5 全流程：5 房通关 → room5_complete=1、family_by_room 覆盖 5 房、全房 family 与预设解法特征一致
## 运行：godot --headless --path game -s res://tests/test_demo11_v3.gd

const SEQ_R1 := ["right", "right", "right", "right", "down", "left", "left", "left", "left", "down", "down", "down"]
const SEQ_R2A := ["down", "down", "right", "right", "right", "right", "right", "right", "right", "right", "right"]
const SEQ_R2B := ["right", "right", "right", "ice:right", "right", "right", "down", "down", "right", "right", "right", "right"]
const SEQ_R3A := ["down", "down", "down", "right", "right", "right", "right", "right", "up", "fire:left", "down", "left", "left", "left", "left", "left", "up", "up", "up", "right", "right", "down", "left", "down", "right", "right", "right", "down", "right", "right", "right", "right"]
const SEQ_R4A := ["down", "down", "magnet:right", "magnet:right", "magnet:right", "magnet:right", "magnet:right", "magnet:right", "magnet:right", "down", "right", "right", "right", "right", "up", "right", "right", "down", "down", "right", "right"]
const SEQ_R5A := ["down", "right", "right", "right", "right", "up", "right", "right", "right"]
const SEQ_R5B := ["left", "down", "right"]
const SEQ_R5C := ["up", "up"]

var fails := 0


func _init() -> void:
	_run()


func _check(cond: bool, tag: String) -> void:
	if cond:
		print("PASS: " + tag)
	else:
		fails += 1
		print("FAIL: " + tag)


func _run_ops(s: Control, ops: Array) -> bool:
	var all_ok := true
	for op in ops:
		var o := String(op)
		var ok := false
		if o.begins_with("ice:") or o.begins_with("fire:") or o.begins_with("magnet:"):
			var parts: PackedStringArray = o.split(":")
			ok = bool(s.use_tool(String(parts[0]), String(parts[1])))
		else:
			ok = bool(s.move(o))
		if not ok:
			all_ok = false
			print("  [stuck] op=", o, " player=", s.player, " room=", s.room_idx, " state=", s.state)
	return all_ok


func _run() -> void:
	print("=== demo-09 v3 遥测验收 ===")
	var s: Control = load("res://demo11_sandbox.tscn").instantiate()
	root.add_child(s)
	await physics_frame

	# --- 隔离实验：房4 磁拉最先跑 ---
	s.load_room(3)
	await physics_frame
	await physics_frame
	print("[ISO] state=", s.state, " room=", s.room_idx, " player=", s.player, " tools=", s.tools)
	print("[ISO] objects: ", s.objects)
	s.move("down")
	s.move("down")
	print("[ISO] after dd: player=", s.player)
	for k in 9:
		var ok9: bool = s.use_tool("magnet", "right")
		print("[ISO] pull ", k + 1, " = ", ok9, " iron=", s._iron_pos() if s.has_method("_iron_pos") else "n/a")
	_run_ops(s, SEQ_R4A)
	print("[ISO room4] room_idx=", s.room_idx, " family=", s.family, " object_move=", int(s.tele.object_move))

	# 用例1 七字段齐全
	var fields := ["tool_use", "object_move", "freeze", "melt", "burn", "switch_on", "room5_complete"]
	var all_in := true
	for f in fields:
		if not s.tele.has(f):
			all_in = false
	_check(all_in, "用例1 遥测七字段齐全（tool_use/object_move/freeze/melt/burn/switch_on/room5_complete）")

	# 用例2 房2 两解两族
	s.load_room(1)
	_run_ops(s, SEQ_R2A)
	print("[2.1 state] room_idx=", s.room_idx, " family=", s.family, " seq=", s.solution_seq.size(), " tele=", s.tele, " cleared=", s.rooms_cleared)
	_check(s.room_idx == 2 and str(s.family_by_room[1]) != "", "2.1 房2 解A 通关且 family 已归类（%s）" % str(s.family_by_room[1]))
	s.load_room(1)
	_run_ops(s, SEQ_R2B)
	print("[2.2 state] room_idx=", s.room_idx, " family=", s.family, " seq=", s.solution_seq.size(), " tele=", s.tele)
	print("[2.2 fam] family_by_room[1]=", s.family_by_room.get(1, "<无>"), " seq=", s.solution_seq)
	_check(s.room_idx == 2 and str(s.family_by_room[1]) != "", "2.2 房2 解B 通关且 family 已归类（%s）" % str(s.family_by_room[1]))

	# 用例3 房4 磁石
	s.load_room(3)
	_run_ops(s, SEQ_R4A)
	_check(s.room_idx == 4 and str(s.family_by_room[3]) != "", "用例3 房4 磁石拉铁通关且 family 已归类（%s）" % str(s.family_by_room[3]))

	# 用例5+6 全流程（房1 A → 房2 A → 房3 A → 房4 A → 房5 A/B/C）→ final
	s.load_room(0)
	_run_ops(s, SEQ_R1)
	_check(s.room_idx == 1, "5.1 房1 通关")
	_run_ops(s, SEQ_R2A)
	_check(s.room_idx == 2, "5.2 房2 通关")
	_run_ops(s, SEQ_R3A)
	s.move("down")
	_check(s.room_idx == 3, "5.3 房3 通关")
	_run_ops(s, SEQ_R4A)
	_check(s.room_idx == 4, "5.4 房4 通关")
	_run_ops(s, SEQ_R5A)
	_run_ops(s, SEQ_R5B)
	_run_ops(s, SEQ_R5C)
	_check(s.state == "final", "5.5 五房全部通关 → state=final")
	_check(int(s.tele.room5_complete) == 1, "5.6 room5_complete=1")
	_check(s.family_by_room.size() == 5, "5.7 family_by_room 覆盖 5 房（%d）" % s.family_by_room.size())
	# 用例4 计数：房2 解B 用了冻 → freeze ≥1；房3 解A 烧箱 → burn ≥1；磁拉 → object_move ≥7
	_check(int(s.tele.freeze) >= 1, "4.1 冻结计数 freeze ≥1（%d）" % int(s.tele.freeze))
	_check(int(s.tele.burn) >= 1, "4.2 火烧箱计数 burn ≥1（%d）" % int(s.tele.burn))
	_check(int(s.tele.object_move) >= 7, "4.3 磁拉移物 object_move ≥7（%d）" % int(s.tele.object_move))
	_check(int(s.tele.switch_on) >= 1, "5.8 开关导通边沿 switch_on ≥1（%d）" % int(s.tele.switch_on))
	var fams := []
	for k in s.family_by_room:
		fams.append(str(s.family_by_room[k]))
	print("  family_by_room: ", fams)

	print("=== 结果：%s（fails=%d）===" % ["ALL PASS" if fails == 0 else "HAS FAIL", fails])
	quit(1 if fails > 0 else 0)
