extends SceneTree
## DEMO6 3D：L3 主 Gate 三解法真实验证（ChatGPT 裁定重标定版）。
## 几何：沟宽 4.8m（单板极限 4.42m → 单板数学不可跨；双板三段跳 0.4/1.4/0.4）、坑深 1.5m（坑底 top -0.3）。
## A 双 Float 板桥（80 墨）/ B 双 Sticky 垫块（80 墨，0.4s 物理钟冻结）/ C0 推箱纯 0 墨
##（推箱入坑抵右墙 → 玩家下坑推至墙根 → 上箱 0.75 ≤0.845 → 箱顶回台 0.45）。
## 关卡只判 GOAL，不判解法。运行：godot --headless --path <game> --fixed-fps 60 -s res://tests/test_demo06_3d_l3_routes.gd

var game: Node3D
var t := 0


func _initialize() -> void:
	_run()


func _spawn() -> void:
	if game != null and is_instance_valid(game):
		root.remove_child(game)
		game.free()
	game = load("res://demo06_3d.tscn").instantiate()
	root.add_child(game)
	game.scripted = true
	for i in 30:
		await physics_frame


func _won() -> bool:
	return game.mode_label.text == "GOAL!"


func _walk(max_ticks: int, jump_windows: Array) -> bool:
	var jump_latch := false
	t = 0
	while t < max_ticks:
		await physics_frame
		t += 1
		var p: CharacterBody3D = game.player
		var px: float = p.position.x
		var py: float = p.position.y
		var on_floor: bool = p.is_on_floor()
		for w in jump_windows:
			if on_floor and px > w.x0 and px < w.x1 and py > w.y0 and py < w.y1:
				jump_latch = true
		game.auto_dir = Vector3(1, 0, 0)
		game.auto_jump = on_floor and jump_latch
		if not on_floor:
			jump_latch = false
		if t % 120 == 0:
			print("WALK t=%d px=%.2f py=%.2f" % [t, px, py])
		if _won():
			return true
	return false


## 解法 A：双 Float 板桥（80 墨）——板1 (3.95,1.46) 板2 (6.55,1.46)，三段跳 0.4/1.4/0.4
func _route_a() -> bool:
	await _spawn()
	var ok1: bool = game.place_blueprint(1, 1, Vector3(3.95, 1.46, 0))
	var ok2: bool = game.place_blueprint(1, 1, Vector3(6.55, 1.46, 0))
	if not ok1 or not ok2:
		print("ROUTE_A FAIL: placement rejected (%s/%s)" % [ok1, ok2])
		return false
	return await _walk(1500, [
		{"x0": 2.3, "x1": 2.75, "y0": 1.0, "y1": 2.0},
		{"x0": 4.35, "x1": 4.6, "y0": 1.8, "y1": 2.4},
		{"x0": 6.5, "x1": 7.15, "y0": 1.8, "y1": 2.4},
	])


## 解法 B：双 Sticky 垫块（80 墨）——块1 (4.25,2.0) 块2 (5.9,2.3)，0.4s 物理钟冻结
func _route_b() -> bool:
	await _spawn()
	var ok1: bool = game.place_blueprint(2, 3, Vector3(4.25, 2.0, 0))
	var ok2: bool = game.place_blueprint(2, 3, Vector3(5.9, 2.3, 0))
	if not ok1 or not ok2:
		print("ROUTE_B FAIL: placement rejected (%s/%s)" % [ok1, ok2])
		return false
	for i in 45:
		await physics_frame
	return await _walk(1500, [
		{"x0": 2.3, "x1": 2.75, "y0": 1.0, "y1": 2.0},
		{"x0": 3.95, "x1": 4.5, "y0": 1.8, "y1": 2.4},
		{"x0": 5.7, "x1": 6.2, "y0": 2.1, "y1": 2.6},
	])


## 解法 C0：推箱纯 0 墨——台缘推箱入坑 → 下坑推至右墙根 → 上箱（升 0.75）→ 箱顶回台（升 0.45）
func _route_c0() -> bool:
	await _spawn()
	var crate: RigidBody3D = game.props_root.get_node_or_null("EnvCrate")
	if crate == null:
		print("ROUTE_C0 FAIL: EnvCrate missing")
		return false
	var crate_in_pit := false
	var jump_latch := false
	var phase := 0
	t = 0
	while t < 3000:
		await physics_frame
		t += 1
		var p: CharacterBody3D = game.player
		var px: float = p.position.x
		var py: float = p.position.y
		var pz: float = p.position.z
		var on_floor: bool = p.is_on_floor()
		var dir := Vector3.ZERO
		match phase:
			0:  # 对齐 z 到箱线（1.2）
				dir = Vector3(0, 0, 1) if on_floor else Vector3.ZERO
				if pz > 1.1:
					phase = 1
			1:  # 台缘推箱（急停线 2.7，台缘 2.9），箱心过 3.25 即翻落入坑
				dir = Vector3(1, 0, 0) if (on_floor and px < 2.7) else Vector3.ZERO
				if crate.position.x > 3.25:
					phase = 2
			2:  # 等箱入坑稳住（坑底静止中心 y≈0.075）
				dir = Vector3.ZERO
				if crate.position.y < 0.5 and crate.position.x > 3.3:
					crate_in_pit = true
				if crate_in_pit and crate.linear_velocity.length() < 0.3:
					phase = 3
					for i in 20:
						await physics_frame
			3:  # 走右下坑（落坑底 feet -0.3）
				dir = Vector3(1, 0, 0)
				if on_floor and py < 0.6 and px > 3.4:
					phase = 4
			4:  # 坑底推箱抵右墙（墙面 7.7，箱半 0.375 → 箱心 7.325），急停线 6.6
				dir = Vector3(1, 0, 0) if (on_floor and px < 6.6) else Vector3.ZERO
				if crate.position.x > 7.25 and crate.linear_velocity.length() < 0.3:
					phase = 5
			5:  # 回退助跑（停位 6.6 在起跳窗后）
				dir = Vector3(-1, 0, 0) if on_floor else Vector3.ZERO
				if px < 5.35:
					phase = 6
			6:  # 上箱跳窗（升 0.75，面 6.9 前起跳）
				dir = Vector3(1, 0, 0)
				if on_floor and px > 5.85 and px < 6.05 and py > -0.1 and py < 0.45:
					jump_latch = true
				if on_floor and px > 6.6 and py > 0.6 and py < 1.2:
					phase = 7
			7:  # 箱顶回台跳窗（升 0.45）
				dir = Vector3(1, 0, 0)
				if on_floor and px > 6.95 and px < 7.15 and py > 0.6 and py < 1.2:
					jump_latch = true
				if px > 7.75 and on_floor:
					phase = 8
			8:  # 右台回 z 中线 → GOAL
				if pz > 0.15:
					dir = Vector3(1, 0, -1).normalized()
				else:
					dir = Vector3(1, 0, 0)
		game.auto_dir = dir
		game.auto_jump = on_floor and jump_latch
		if not on_floor:
			jump_latch = false
		if t % 120 == 0:
			print("C0 t=%d ph=%d px=%.2f py=%.2f crate=%.2f,%.2f" % [t, phase, px, py, crate.position.x, crate.position.y])
		if _won():
			if not crate_in_pit:
				print("ROUTE_C0 WARN: win but crate never entered pit")
				return false
			print("ROUTE_C0: PASS (t=%d)" % t)
			return true
	print("ROUTE_C0 FAIL: no goal (ph=%d crate=(%.2f,%.2f) player=(%.2f,%.2f))" % [
		phase, crate.position.x, crate.position.y, game.player.position.x, game.player.position.y])
	return false


func _run() -> void:
	var ra: bool = await _route_a()
	print("ROUTE_A: ", "PASS" if ra else "FAIL")
	var rb: bool = await _route_b()
	print("ROUTE_B: ", "PASS" if rb else "FAIL")
	var rc: bool = await _route_c0()
	print("ROUTE_C0: ", "PASS" if rc else "FAIL")
	var n := (1 if ra else 0) + (1 if rb else 0) + (1 if rc else 0)
	print("L3 ROUTES: %d/3 PASS" % n)
	quit(0 if n == 3 else 1)
