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
		if toppled and on_floor and px > 4.0 and px < 4.8 and py < 2.0:
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


func _run() -> void:
	var r1: bool = await _l1_fire()
	var r2: bool = await _l1_heavy()
	var r3: bool = await _l2_build()
	var n := (1 if r1 else 0) + (1 if r2 else 0) + (1 if r3 else 0)
	print("LEVELS RESULT: %d/3 PASS" % n)
	quit(0 if n == 3 else 1)
