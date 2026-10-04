extends SceneTree
## DEMO6 3D：12 组合生成后可移动性审计（ChatGPT 裁定的三问，实证测量非理论推导）。
## 三问：①玩家能否推动（贴身推 90 tick 位移≥0.15m）；②是否永久冻结/快速失去可操作性
##（Float 即冻结 / Sticky 0.4s 冻结 / Fire 2s 自毁）；③假可移动（能推但不稳定/漂移/异常）。
## 附 EnvCrate（无词条环境物）对照。运行：--headless --fixed-fps 60 -s res://tests/test_demo06_3d_movability.gd

func _initialize() -> void:
	_run()


func _audit_combo(shape_i: int, word_i: int) -> Dictionary:
	var game: Node3D = load("res://demo06_3d.tscn").instantiate()
	game.level_idx = 0
	root.add_child(game)
	game.scripted = true
	for i in 30:
		await physics_frame
	game.ink = 10000
	var ok: bool = game.place_blueprint(shape_i, word_i, Vector3(1.6, 1.5, 0))
	if not ok:
		game.free()
		return { "ok": false }
	var rb: RigidBody3D = game.placed_root.get_node("Placed%d" % (game.placed_count - 1))
	# 落定（含 Sticky 0.4s 冻结窗）
	for i in 45:
		await physics_frame
	var pos0: Vector3 = rb.position
	var frozen0: bool = rb.freeze
	# 玩家贴身推 90 tick（走向物体）
	var jump_latch := false
	for i in 90:
		await physics_frame
		var p: CharacterBody3D = game.player
		game.auto_dir = Vector3(1, 0, 0) if p.position.x < 1.45 else Vector3.ZERO
		game.auto_jump = p.is_on_floor() and jump_latch
		if not p.is_on_floor():
			jump_latch = false
	var pos1: Vector3 = rb.position if is_instance_valid(rb) else pos0
	var disp: float = (Vector2(pos1.x, pos1.z) - Vector2(pos0.x, pos0.z)).length()
	var frozen1: bool = (not is_instance_valid(rb)) or rb.freeze
	var valid: bool = is_instance_valid(rb) and not rb.is_queued_for_deletion()
	# 稳定性：再 120 tick 观察漂移/异常
	var drift := 0.0
	var finite := true
	if valid:
		var p2: Vector3 = rb.position
		for i in 120:
			await physics_frame
		if is_instance_valid(rb):
			drift = (rb.position - p2).length()
			finite = is_finite(rb.position.x) and is_finite(rb.position.y) and is_finite(rb.position.z)
	game.free()
	return {
		"ok": true, "disp": disp, "frozen0": frozen0, "frozen1": frozen1,
		"persistent": valid, "drift": drift, "finite": finite,
	}


func _run() -> void:
	var shapes: Array = ["ball", "plank", "block"]
	var words: Array = ["heavy", "float", "fire", "sticky"]
	var fails := 0
	var movable_list := []
	for wi in 4:
		for si in 3:
			var r: Dictionary = await _audit_combo(si, wi)
			var name: String = "%s+%s" % [shapes[si], words[wi]]
			if not r.ok:
				print("AUDIT %s: PLACEMENT REJECTED" % name)
				fails += 1
				continue
			var movable: bool = r.disp >= 0.15 and not r.frozen1
			var stable: bool = r.finite and r.drift < 0.5
			var persistent: bool = r.persistent
			if movable:
				movable_list.append(name)
			print("AUDIT %-13s push=%.3fm frozen@0.75s=%s persistent=%s stable=%s (drift=%.3f) => %s" % [
				name, r.disp, str(r.frozen1), str(persistent), str(stable), r.drift,
				"MOVABLE" if movable else "IMMOVABLE"])
	# EnvCrate 对照（无词条环境物；箱在 L3 房间）
	var g2: Node3D = load("res://demo06_3d.tscn").instantiate()
	g2.level_idx = 2
	root.add_child(g2)
	g2.scripted = true
	for i in 30:
		await physics_frame
	var crate: RigidBody3D = g2.props_root.get_node("EnvCrate")
	var c0: Vector3 = crate.position
	var aligned := false
	for i in 150:
		await physics_frame
		var p: CharacterBody3D = g2.player
		if not aligned:
			g2.auto_dir = Vector3(0, 0, 1) if p.is_on_floor() else Vector3.ZERO
			if p.position.z > 1.15:
				aligned = true
		else:
			g2.auto_dir = Vector3(1, 0, 0) if p.position.x < 1.8 else Vector3.ZERO
		g2.auto_jump = false
	var cdisp: float = (crate.position - c0).length()
	print("AUDIT %-13s push=%.3fm (环境物对照) => %s" % ["EnvCrate", cdisp, "MOVABLE" if cdisp >= 0.15 else "IMMOVABLE"])
	print("MOVABILITY RESULT: movable=%s | fails=%d" % [",".join(movable_list), fails])
	quit(0 if fails == 0 else 1)
