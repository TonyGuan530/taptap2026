extends SceneTree
## DEMO6 3D 阶段 A 收官：L3 三解法真实物理驱动验证（指南 §9：A Float 桥 / B Sticky 垫脚 / C 推箱；
## 关卡只判 GOAL，不判解法）。每路独立场景实例，真实物理推进至 GOAL。
## 运行：godot --headless --path <game> --fixed-fps 60 -s res://tests/test_demo06_3d_l3_routes.gd
## 退出码 0=三路全 PASS 1=有失败

var game: Node3D
var t := 0


func _initialize() -> void:
	_run()


func _spawn() -> void:
	# 清理上一路的场景实例（避免跨路碰撞体/GOAL 区域互相污染）
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


## 通用行进：jump_windows=[{x0,x1,y0,y1}] 锁存式跳窗；stop_x 为可选停步线（auto_dir 归零）
func _walk(max_ticks: int, jump_windows: Array, stop_x := 999.0) -> bool:
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
		# 恒定行进（按住不放）：空中保持输入才有水平跳跃抛物线；stop_x 为停步线
		var dir := Vector3(1, 0, 0) if px < stop_x else Vector3.ZERO
		game.auto_dir = dir
		game.auto_jump = on_floor and jump_latch
		if not on_floor:
			jump_latch = false
		if t % 60 == 0:
			print("WALK t=%d px=%.2f py=%.2f floor=%s latch=%s" % [t, px, py, on_floor, jump_latch])
		if _won():
			return true
	return false


## 解法 A：Float 长板跨沟（40 墨）
func _route_a() -> bool:
	await _spawn()
	var ok: bool = game.place_blueprint(1, 1, Vector3(4.2, 1.46, 0))
	if not ok:
		print("ROUTE_A FAIL: bridge placement rejected")
		return false
	return await _walk(1500, [
		{"x0": 2.3, "x1": 2.75, "y0": 1.0, "y1": 2.0},
		{"x0": 4.3, "x1": 4.9, "y0": 1.8, "y1": 2.4},
	])


## 解法 B：Sticky 方块垫脚（40 墨）——生成后 0.4s 冻结为固定踏石，两段跳上右台
func _route_b() -> bool:
	await _spawn()
	var ok: bool = game.place_blueprint(2, 3, Vector3(4.25, 2.0, 0))
	if not ok:
		print("ROUTE_B FAIL: stone placement rejected")
		return false
	# 等冻结（0.4s 物理钟 = 24 tick）+ 落定
	for i in 45:
		await physics_frame
	return await _walk(1500, [
		{"x0": 2.3, "x1": 2.8, "y0": 1.0, "y1": 2.0},
		{"x0": 4.2, "x1": 4.55, "y0": 1.8, "y1": 2.4},
	])


## 解法 C（指南 §9「推箱 0~40 墨」）：推环境箱入坑抵右墙（自对齐 x≈5.08）→ 补 Sticky 垫块落坑底
## （40 墨）→ 台缘走落垫块顶（0.14）→ 垫块跳箱顶（0.595）→ 箱顶回半步起跳上右台（1.2）。
## 坑深 1.7m 跳高 0.845m：坑底→箱顶 1.095m 不可直跳，垫块是必要补差；三级爬升每级 ≤0.65m。
func _route_c() -> bool:
	await _spawn()
	var crate: RigidBody3D = game.props_root.get_node_or_null("EnvCrate")
	if crate == null:
		print("ROUTE_C FAIL: EnvCrate missing")
		return false
	var crate_in_pit := false
	var placed_block := false
	var jump_latch := false
	var phase := 0
	t = 0
	while t < 2400:
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
			1:  # 推箱（+x）抵右墙，玩家急停线 2.55
				dir = Vector3(1, 0, 0) if (on_floor and px < 2.55) else Vector3.ZERO
				if crate.position.x > 4.9:
					phase = 2
			2:  # 等箱贴墙稳住 → 放 Sticky 垫块（坑底 x4.0）
				dir = Vector3.ZERO
				if crate.linear_velocity.length() < 0.3 and crate.position.y < 0.35:
					crate_in_pit = true
					if game.place_blueprint(2, 3, Vector3(4.0, 0.6, 1.16)):
						placed_block = true
					phase = 3
					for i in 45:
						await physics_frame
			3:  # 走右掉坑 → 落垫块顶（feet 0.14，中心 y≈0.64）
				dir = Vector3(1, 0, 0)
				if on_floor and py < 1.0 and px > 3.5:
					phase = 4
			4:  # 垫块顶起跳窗 → 箱顶
				dir = Vector3(1, 0, 0)
				if on_floor and px > 4.05 and px < 4.32 and py > 0.35 and py < 0.95:
					jump_latch = true
				if on_floor and px > 4.4 and py > 0.75 and py < 1.35:
					phase = 5
			5:  # 箱顶：回半步（贴墙位起跳会撞台壁）→ 就位后进跳跃相位
				if px > 5.15:
					dir = Vector3(-1, 0, 0)
				else:
					phase = 6
			6:  # 箱顶起跳窗 → 右台（方向恒定，空中不回头）
				dir = Vector3(1, 0, 0)
				if on_floor and px > 4.95 and px < 5.15 and py > 0.75 and py < 1.35:
					jump_latch = true
				if px > 5.6 and on_floor:
					phase = 7
			7:  # 右台回 z 中线（GOAL 判定盒 z±0.5）→ 直进 GOAL
				if pz > 0.15:
					dir = Vector3(1, 0, -1).normalized()
				else:
					dir = Vector3(1, 0, 0)
		game.auto_dir = dir
		game.auto_jump = on_floor and jump_latch
		if not on_floor:
			jump_latch = false
		if t % 120 == 0:
			print("ROUTE_C t=%d phase=%d player=(%.2f,%.2f,%.2f) crate=(%.2f,%.2f)" % [
				t, phase, px, py, pz, crate.position.x, crate.position.y])
		if _won():
			if not crate_in_pit or not placed_block:
				print("ROUTE_C WARN: win but crate/block precondition missing (%s/%s)" % [crate_in_pit, placed_block])
				return false
			return true
	print("ROUTE_C FAIL: no goal (phase=%d crate=(%.2f,%.2f) player=(%.2f,%.2f))" % [
		phase, crate.position.x, crate.position.y, game.player.position.x, game.player.position.y])
	return false


func _run() -> void:
	var results := {"A": false, "B": false, "C": false}
	results.A = await _route_a()
	print("ROUTE_A: ", "PASS" if results.A else "FAIL")
	results.B = await _route_b()
	print("ROUTE_B: ", "PASS" if results.B else "FAIL")
	results.C = await _route_c()
	print("ROUTE_C: ", "PASS" if results.C else "FAIL")
	var n := (1 if results.A else 0) + (1 if results.B else 0) + (1 if results.C else 0)
	print("L3 ROUTES: %d/3 PASS" % n)
	quit(0 if n == 3 else 1)
