extends SceneTree
## DEMO6 3D 阶段 B：L1/L2 真实物理驱动验证（指南 §2 六关真实结构；关卡只判 GOAL）。
## L1 火：Fire 球接触栅栏燃毁（flammable 语义）→ 直行 GOAL。
## L1 重：Heavy 球被玩家推撞栅栏 → 物理撞倒 → 越过 GOAL（0 墨障碍双解之另一路）。
## L2 建：Float 长板悬浮踏台 → 两段跳上 1.6m 高台 GOAL。
## 运行：godot --headless --path <game> --fixed-fps 60 -s res://tests/test_demo06_3d_levels.gd
## 退出码 0=全 PASS

var game: Node3D
var t := 0


func _initialize() -> void:
	_run()


func _spawn(idx: int) -> void:
	if game != null and is_instance_valid(game):
		root.remove_child(game)
		game.free()
	game = load("res://demo06_3d.tscn").instantiate()
	game.level_idx = idx
	root.add_child(game)
	game.scripted = true
	for i in 30:
		await physics_frame


func _won() -> bool:
	return game.mode_label.text == "GOAL!"


## L1 火路：放 Fire 球贴栅栏 → 燃毁 → 直行
func _l1_fire() -> bool:
	await _spawn(0)
	var fence: RigidBody3D = game.props_root.get_node_or_null("Fence")
	if fence == null:
		print("L1FIRE FAIL: Fence missing")
		return false
	var ok: bool = game.place_blueprint(0, 2, Vector3(4.05, 1.5, 0))  # ball+fire 45墨，留缝免占位拒绝
	if not ok:
		print("L1FIRE FAIL: fire placement rejected")
		return false
	var burned := false
	var jump_latch := false
	t = 0
	while t < 1800:
		await physics_frame
		t += 1
		if not burned and not is_instance_valid(fence):
			burned = true
			print("L1FIRE fence burned at t=", t)
		var p: CharacterBody3D = game.player
		var px: float = p.position.x
		var py: float = p.position.y
		var on_floor: bool = p.is_on_floor()
		if burned and on_floor and px > 4.0 and px < 4.8 and py < 2.0:
			jump_latch = true
		# 从头行走：顺路把火球推贴栅栏触发燃毁
		game.auto_dir = Vector3(1, 0, 0)
		game.auto_jump = on_floor and jump_latch
		if not on_floor:
			jump_latch = false
		if _won():
			print("L1FIRE: PASS (burned=%s t=%d)" % [burned, t])
			return burned
	print("L1FIRE FAIL: no goal (burned=%s px=%.2f)" % [burned, game.player.position.x])
	return false


## L1 重路：玩家推 Heavy 球撞栅栏 → 撞倒 → 越过
func _l1_heavy() -> bool:
	await _spawn(0)
	var fence: RigidBody3D = game.props_root.get_node_or_null("Fence")
	if fence == null:
		print("L1HEAVY FAIL: Fence missing")
		return false
	var ok: bool = game.place_blueprint(0, 0, Vector3(3.9, 1.5, 0))  # ball+heavy 40墨
	if not ok:
		print("L1HEAVY FAIL: ball placement rejected")
		return false
	var toppled := false
	var jump_latch := false
	t = 0
	while t < 1800:
		await physics_frame
		t += 1
		if not toppled and (fence.position.y < 1.4 or absf(fence.rotation.z) > 0.4 or absf(fence.rotation.x) > 0.4):
			toppled = true
			print("L1HEAVY fence toppled at t=", t, " y=%.2f" % fence.position.y)
		var p: CharacterBody3D = game.player
		var px: float = p.position.x
		var py: float = p.position.y
		var on_floor: bool = p.is_on_floor()
		if toppled and on_floor and px > 3.6 and px < 4.9 and py < 2.0:
			jump_latch = true
		game.auto_dir = Vector3(1, 0, 0)
		game.auto_jump = on_floor and jump_latch
		if not on_floor:
			jump_latch = false
		if _won():
			print("L1HEAVY: PASS (toppled=%s t=%d)" % [toppled, t])
			return toppled
	print("L1HEAVY FAIL: no goal (toppled=%s fence=(%.2f,%.2f) px=%.2f)" % [
		toppled, fence.position.x, fence.position.y, game.player.position.x])
	return false


## L2 建路：Float 板悬浮踏台（顶 2.0）→ 两段跳上高台（顶 2.8）
func _l2_build() -> bool:
	await _spawn(1)
	var ok: bool = game.place_blueprint(1, 1, Vector3(5.0, 1.89, 0))  # plank+float 40墨
	if not ok:
		print("L2 FAIL: plank placement rejected")
		return false
	var jump_latch := false
	t = 0
	while t < 1800:
		await physics_frame
		t += 1
		var p: CharacterBody3D = game.player
		var px: float = p.position.x
		var py: float = p.position.y
		var on_floor: bool = p.is_on_floor()
		# 板底 1.78 低于站高头顶——须在板前起跳，使上升段越过板侧面后落板顶
		if on_floor and px > 3.5 and px < 3.75 and py > 1.0 and py < 2.0:
			jump_latch = true
		if on_floor and px > 5.28 and px < 5.55 and py > 2.3 and py < 2.7:
			jump_latch = true
		game.auto_dir = Vector3(1, 0, 0)
		game.auto_jump = on_floor and jump_latch
		if not on_floor:
			jump_latch = false
		if t % 120 == 0:
			print("L2 t=%d px=%.2f py=%.2f" % [t, px, py])
		if _won():
			print("L2BUILD: PASS (t=%d)" % t)
			return true
	print("L2 FAIL: no goal (px=%.2f py=%.2f)" % [game.player.position.x, game.player.position.y])
	return false


## L4 0 墨路：推箱抵墙 → 跃上箱顶 → 一跳越墙 → 回 z 中线 GOAL
func _l4_crate() -> bool:
	await _spawn(3)
	var crate: RigidBody3D = game.props_root.get_node_or_null("Crate")
	if crate == null:
		print("L4 FAIL: Crate missing")
		return false
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
			0:
				dir = Vector3(0, 0, 1) if on_floor else Vector3.ZERO
				if pz > 0.55:
					phase = 1
			1:  # 推箱抵墙（墙面 4.75，箱半 0.375 → 箱心 4.375），急停线 3.75（接触点）
				dir = Vector3(1, 0, 0) if (on_floor and px < 3.75) else Vector3.ZERO
				if crate.position.x > 4.3:
					phase = 2
			2:  # 回退助跑（停位 3.75 已在起跳窗之后）
				dir = Vector3(-1, 0, 0) if on_floor else Vector3.ZERO
				if px < 3.05:
					phase = 3
			3:  # 走向箱体，跃上箱顶（顶 1.95）
				dir = Vector3(1, 0, 0)
				if on_floor and px > 3.2 and px < 3.45 and py > 1.0 and py < 2.0:
					jump_latch = true
				if on_floor and px > 4.0 and py > 2.2 and py < 2.7:
					phase = 4
			4:  # 箱顶起跳 → 一跳越墙（墙顶 2.1，箱顶 1.95+跳 0.845=2.795）
				dir = Vector3(1, 0, 0)
				if on_floor and px > 4.3 and px < 4.75 and py > 2.2 and py < 2.7:
					jump_latch = true
				if px > 5.5 and on_floor:
					phase = 5
			5:  # 回 z 中线 → GOAL
				if pz > 0.15:
					dir = Vector3(1, 0, -1).normalized()
				else:
					dir = Vector3(1, 0, 0)
		game.auto_dir = dir
		game.auto_jump = on_floor and jump_latch
		if not on_floor:
			jump_latch = false
		if t % 120 == 0:
			print("L4 t=%d ph=%d px=%.2f py=%.2f crate=%.2f" % [t, phase, px, py, crate.position.x])
		if _won():
			print("L4CRATE: PASS (t=%d)" % t)
			return true
	print("L4 FAIL: no goal (ph=%d px=%.2f crate=%.2f)" % [phase, game.player.position.x, crate.position.x])
	return false


## L5 双沟：第一沟直跳 → Float 板跨第二沟（2.0m）→ GOAL
func _l5_islands() -> bool:
	await _spawn(4)
	var ok: bool = game.place_blueprint(1, 1, Vector3(10.4, 1.46, 0))
	if not ok:
		print("L5 FAIL: plank placement rejected")
		return false
	var jump_latch := false
	t = 0
	while t < 2400:
		await physics_frame
		t += 1
		var p: CharacterBody3D = game.player
		var px: float = p.position.x
		var py: float = p.position.y
		var on_floor: bool = p.is_on_floor()
		if on_floor and px > 3.85 and px < 4.0 and py > 1.0 and py < 2.0:
			jump_latch = true
		if on_floor and px > 8.7 and px < 9.35 and py > 1.0 and py < 2.0:
			jump_latch = true
		if on_floor and px > 10.2 and px < 10.9 and py > 1.8 and py < 2.4:
			jump_latch = true
		game.auto_dir = Vector3(1, 0, 0)
		game.auto_jump = on_floor and jump_latch
		if not on_floor:
			jump_latch = false
		if t % 120 == 0:
			print("L5 t=%d px=%.2f py=%.2f" % [t, px, py])
		if _won():
			print("L5ISLANDS: PASS (t=%d)" % t)
			return true
	print("L5 FAIL: no goal (px=%.2f py=%.2f)" % [game.player.position.x, game.player.position.y])
	return false


## L6 链式登梯：Float 板1 上塔1（+1.3m）→ 板2 跨塔间沟 → 塔2（+0.55m）→ GOAL
func _l6_ladder() -> bool:
	await _spawn(5)
	var ok1: bool = game.place_blueprint(1, 1, Vector3(3.4, 1.89, 0))
	var ok2: bool = game.place_blueprint(1, 1, Vector3(7.65, 2.85, 0))
	if not ok1 or not ok2:
		print("L6 FAIL: plank placement rejected (%s/%s)" % [ok1, ok2])
		return false
	var jump_latch := false
	t = 0
	while t < 2400:
		await physics_frame
		t += 1
		var p: CharacterBody3D = game.player
		var px: float = p.position.x
		var py: float = p.position.y
		var on_floor: bool = p.is_on_floor()
		if on_floor and px > 1.75 and px < 2.2 and py > 1.0 and py < 2.0:
			jump_latch = true
		if on_floor and px > 3.85 and px < 4.03 and py > 2.3 and py < 2.7:
			jump_latch = true
		if on_floor and px > 6.3 and px < 6.85 and py > 2.8 and py < 3.3:
			jump_latch = true
		if on_floor and px > 7.8 and px < 8.25 and py > 3.15 and py < 3.55:
			jump_latch = true
		game.auto_dir = Vector3(1, 0, 0)
		game.auto_jump = on_floor and jump_latch
		if not on_floor:
			jump_latch = false
		if t % 120 == 0:
			print("L6 t=%d px=%.2f py=%.2f" % [t, px, py])
		if _won():
			print("L6LADDER: PASS (t=%d)" % t)
			return true
	print("L6 FAIL: no goal (px=%.2f py=%.2f)" % [game.player.position.x, game.player.position.y])
	return false


## 重开本关（T 命令语义）：放置物清空、墨水回满、环境物重建
func _restart_check() -> bool:
	await _spawn(0)
	var ok: bool = game.place_blueprint(0, 2, Vector3(1.5, 1.5, 0))
	if not ok:
		print("RESTART FAIL: placement rejected")
		return false
	var fence0: RigidBody3D = game.props_root.get_node("Fence")
	game.restart_level()
	for i in 10:
		await physics_frame
	var fence1: RigidBody3D = game.props_root.get_node_or_null("Fence")
	var ok_ink: bool = game.ink == 100
	var ok_placed: bool = game.placed_count == 0
	var ok_fence: bool = is_instance_valid(fence1) and fence1 != fence0
	print("RESTART: ink=%s placed=%s fence=%s" % [ok_ink, ok_placed, ok_fence])
	return ok_ink and ok_placed and ok_fence


func _run() -> void:
	var results := {}
	results.l1f = await _l1_fire()
	print("ROUTE_L1FIRE: ", "PASS" if results.l1f else "FAIL")
	results.l1h = await _l1_heavy()
	print("ROUTE_L1HEAVY: ", "PASS" if results.l1h else "FAIL")
	results.l2 = await _l2_build()
	print("ROUTE_L2: ", "PASS" if results.l2 else "FAIL")
	results.l4 = await _l4_crate()
	print("ROUTE_L4: ", "PASS" if results.l4 else "FAIL")
	results.l5 = await _l5_islands()
	print("ROUTE_L5: ", "PASS" if results.l5 else "FAIL")
	results.l6 = await _l6_ladder()
	print("ROUTE_L6: ", "PASS" if results.l6 else "FAIL")
	results.rs = await _restart_check()
	var n := 0
	for k in results:
		if results[k]:
			n += 1
	print("LEVELS RESULT: %d/7 PASS" % n)
	quit(0 if n == 7 else 1)
