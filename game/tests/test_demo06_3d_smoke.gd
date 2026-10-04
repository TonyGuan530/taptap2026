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
	if n_placed >= 1:
		body = scene.placed_root.get_child(0)
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
	print("SMOKE RESULT: %s (placed=%d ink=%d→%d)" % ["PASS" if fails == 0 else "FAIL", n_placed, ink0, scene.ink])
	quit(0 if fails == 0 else 1)
