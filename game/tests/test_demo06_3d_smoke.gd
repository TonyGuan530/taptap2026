extends SceneTree
## DEMO6 3D 阶段 A 冒烟测试：场景加载 / 玩家存在 / 墨水原子扣费 / 放置生效 / 刚体物理推进。
## 运行：godot --headless --path D:/GIT/taptap2026-demo06-3d/game -s res://tests/test_demo06_3d_smoke.gd
## 退出码 0=PASS 1=FAIL

func _initialize() -> void:
	_run()


func _run() -> void:
	var fails := 0
	var scene: Node3D = load("res://demo06_3d.tscn").instantiate()
	root.add_child(scene)
	for i in 90:
		await physics_frame
	var player: CharacterBody3D = root.get_node_or_null("Demo06Root/Player")
	if player == null:
		print("SMOKE FAIL: player missing")
		quit(1)
		return
	# 等待玩家落地
	for i in 90:
		await physics_frame
		if player.is_on_floor():
			break
	var ink0: int = scene.ink
	scene.place_for_test()
	for i in 30:
		await physics_frame
	var n_placed: int = scene.placed_root.get_child_count()
	if n_placed < 1:
		fails += 1
		print("SMOKE FAIL: placement missing")
	if scene.ink >= ink0:
		fails += 1
		print("SMOKE FAIL: ink not deducted (ink=%d ink0=%d)" % [scene.ink, ink0])
	var body: RigidBody3D = null
	for c in scene.placed_root.get_children():
		if c is RigidBody3D:
			body = c
			break
	if body != null:
		var y0: float = body.position.y
		for i in 60:
			await physics_frame
			if not is_finite(body.position.y):
				break
		if not is_finite(body.position.y):
			fails += 1
			print("SMOKE FAIL: body position non-finite (NaN/Inf)")
		elif body.position.y > y0 + 0.5:
			fails += 1
			print("SMOKE FAIL: body flew upward (y0=%.2f y=%.2f)" % [y0, body.position.y])
	# ===== v2 校验：占位原子拒绝 / 空中放置 / yaw 旋转 =====
	var ink_before_validation: int = scene.ink
	var ok_air: bool = scene.try_place_validated(Vector3(0.5, 1.9, -1.0), 0.0)
	if not ok_air:
		fails += 1
		print("SMOKE FAIL: 空中合法放置被误拒")
	if scene.ink >= ink_before_validation:
		fails += 1
		print("SMOKE FAIL: 合法放置未扣墨")
	var ink_after_air: int = scene.ink
	var ok_bad: bool = scene.try_place_validated(Vector3(0.7, 0.6, 0.0), 0.0)
	if ok_bad:
		fails += 1
		print("SMOKE FAIL: 地形内部占位未被拒绝")
	if scene.ink != ink_after_air:
		fails += 1
		print("SMOKE FAIL: 拒绝路径扣了墨")
	var placed_yaw_ok := false
	for c2 in scene.placed_root.get_children():
		if c2 is RigidBody3D and absf(c2.rotation.y) > 0.01:
			placed_yaw_ok = true
	if not placed_yaw_ok and fails == 0:
		# yaw 旋转：place_blueprint 带 yaw → 放置体 rotation.y ≈ 1.5708
		var keep_shape: int = scene.shape_idx
		var keep_word: int = scene.word_idx
		scene.ink += 100   # 测试补墨
		scene.shape_idx = 1
		scene.word_idx = 1
		var yaw_ok: bool = scene.try_place_validated(Vector3(0.5, 1.9, -2.6), 1.5708)
		scene.shape_idx = keep_shape
		scene.word_idx = keep_word
		if not yaw_ok:
			fails += 1
			print("SMOKE FAIL: yaw 放置被误拒")
		else:
			var yaw_body: RigidBody3D = null
			for c3 in scene.placed_root.get_children():
				if c3 is RigidBody3D and absf(c3.rotation.y - 1.5708) < 0.01:
					yaw_body = c3
			if yaw_body == null:
				fails += 1
				print("SMOKE FAIL: yaw 放置体未找到")
	print("SMOKE RESULT: %s (placed=%d ink=%d→%d)" % ["PASS" if fails == 0 else "FAIL", n_placed, ink0, scene.ink])
	quit(0 if fails == 0 else 1)
