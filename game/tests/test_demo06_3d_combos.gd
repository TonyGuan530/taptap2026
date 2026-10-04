extends SceneTree
## DEMO6 3D：12 组合行为对照（4 词条 × 3 形状）——放置原子性 + 静态语义 + 物理钟动态语义。
## 语义（2D 如实保留）：Heavy mass8 重力×2.6 / Float 即冻结 / Fire 2s 自毁（物理钟）/ Sticky 摩擦4 弹0 0.4s 后冻结（物理钟）。
## 运行：godot --headless --path <game> --fixed-fps 60 -s res://tests/test_demo06_3d_combos.gd
## 退出码 0=PASS 1=FAIL

func _initialize() -> void:
	_run()


func _run() -> void:
	var fails := 0
	var game: Node3D = load("res://demo06_3d.tscn").instantiate()
	root.add_child(game)
	game.scripted = true
	for i in 30:
		await physics_frame
	game.ink = 10000
	var bodies := {}
	var z := -3.85
	for wi in 4:
		for si in 3:
			var shape: Dictionary = game.SHAPES[si]
			var word: Dictionary = game.WORDS[wi]
			var cost: int = shape.cost + word.cost
			var before: int = game.ink
			var ok: bool = game.place_blueprint(si, wi, Vector3(4.25, 1.7, z))
			z += 0.7
			if not ok:
				fails += 1
				print("COMBO FAIL: %s+%s placement rejected" % [shape.id, word.id])
				continue
			if game.ink != before - cost:
				fails += 1
				print("COMBO FAIL: %s+%s ink %d→%d expect %d" % [shape.id, word.id, before, game.ink, before - cost])
			var rb: RigidBody3D = game.placed_root.get_node("Placed%d" % (game.placed_count - 1))
			bodies["%s+%s" % [shape.id, word.id]] = rb
			match word.id:
				"heavy":
					if rb.mass != 8.0 or not is_equal_approx(rb.gravity_scale, 2.6):
						fails += 1
						print("COMBO FAIL: %s+heavy mass/grav wrong (m=%.1f g=%.2f)" % [shape.id, rb.mass, rb.gravity_scale])
				"float":
					if not rb.freeze:
						fails += 1
						print("COMBO FAIL: %s+float not frozen at t0" % shape.id)
				"fire":
					if not rb.has_meta("die_at"):
						fails += 1
						print("COMBO FAIL: %s+fire die_at missing" % shape.id)
				"sticky":
					var pm: PhysicsMaterial = rb.physics_material_override
					if pm == null or not is_equal_approx(pm.friction, 4.0) or not is_equal_approx(pm.bounce, 0.0):
						fails += 1
						print("COMBO FAIL: %s+sticky material wrong" % shape.id)
					if rb.freeze:
						fails += 1
						print("COMBO FAIL: %s+sticky frozen at t0（应延迟 0.4s）" % shape.id)
			var cs: CollisionShape3D = rb.get_child(0)
			if shape.id == "ball":
				if not (cs.shape is SphereShape3D):
					fails += 1
					print("COMBO FAIL: ball collision not sphere")
			elif not (cs.shape is BoxShape3D):
				fails += 1
				print("COMBO FAIL: %s collision not box" % shape.id)
	if bodies.size() != 12:
		fails += 1
		print("COMBO FAIL: placed %d/12" % bodies.size())
	# 早期（<0.4s）：sticky 均未冻结
	for i in 10:
		await physics_frame
	for k in bodies:
		if k.ends_with("+sticky"):
			var rb2: RigidBody3D = bodies[k]
			if is_instance_valid(rb2) and rb2.freeze:
				fails += 1
				print("COMBO FAIL: %s frozen too early" % k)
	# 推进至 3s：fire 全自毁 / sticky 全冻结 / float 仍冻结 / heavy 有下落
	for i in 170:
		await physics_frame
	var fire_dead := 0
	var sticky_frozen := 0
	var sticky_n := 0
	var float_frozen := 0
	var heavy_moved := 0
	for k in bodies:
		var rb3: Variant = bodies[k]
		var alive: bool = is_instance_valid(rb3)
		if k.ends_with("+fire"):
			if not alive or rb3.is_queued_for_deletion():
				fire_dead += 1
		elif k.ends_with("+sticky"):
			sticky_n += 1
			if alive and rb3.freeze:
				sticky_frozen += 1
		elif k.ends_with("+float"):
			if alive and rb3.freeze:
				float_frozen += 1
		elif k.ends_with("+heavy"):
			if alive and rb3.position.y < 1.4:
				heavy_moved += 1
	if fire_dead != 3:
		fails += 1
		print("COMBO FAIL: fire dead %d/3" % fire_dead)
	if sticky_frozen != sticky_n:
		fails += 1
		print("COMBO FAIL: sticky frozen %d/%d" % [sticky_frozen, sticky_n])
	if float_frozen != 3:
		fails += 1
		print("COMBO FAIL: float frozen %d/3" % float_frozen)
	if heavy_moved < 1:
		fails += 1
		print("COMBO FAIL: heavy did not fall")
	print("COMBOS RESULT: %s (combos=%d fire_dead=%d/3 sticky=%d/%d float_frozen=%d/3 heavy_moved=%d/3)" % [
		"PASS" if fails == 0 else "FAIL", bodies.size(), fire_dead, sticky_frozen, sticky_n, float_frozen, heavy_moved])
	quit(0 if fails == 0 else 1)
