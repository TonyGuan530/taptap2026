extends SceneTree
## demo-02 物理验证（headless）：切到皮球词条，球应借弹簧飞过高墙到达 GOAL。
## 运行：godot --headless --path game -s res://tests/test_demo02.gd
## 注意：headless 帧率不设限，必须按真实时间（msec）计时而不是帧数。

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var ps: PackedScene = load("res://demo02_physics.tscn")
	var scene = ps.instantiate()
	root.add_child(scene)
	await physics_frame
	# --- 用例 1：皮球过墙 ---
	scene._on_tag(2)
	var t0 := Time.get_ticks_msec()
	var max_x := 0.0
	while Time.get_ticks_msec() - t0 < 8000:
		await physics_frame
		if scene.ball != null:
			max_x = max(max_x, scene.ball.position.x)
		if scene.goal_reached:
			break
	if scene.goal_reached:
		print("TEST_PASS: 皮球 %.1f 秒到达 GOAL，最远 x=%.0f（墙 430-470）" % [(Time.get_ticks_msec() - t0) / 1000.0, max_x])
	else:
		print("TEST_FAIL: 皮球 8 秒未到 GOAL，球=%s 最远 x=%.0f" % [str(scene.ball.position), max_x])
	# --- 用例 2：石头应成功（砸碎脆墙落进 GOAL） ---
	scene._load_level(1)
	scene._on_tag(1)
	t0 = Time.get_ticks_msec()
	var ok2 := false
	while Time.get_ticks_msec() - t0 < 10000:
		await physics_frame
		if scene.goal_reached:
			ok2 = true
			break
	if ok2:
		print('TEST_PASS: 石头 %.1f 秒砸碎脆墙进入 GOAL（符合预期）' % [(Time.get_ticks_msec() - t0) / 1000.0])
	else:
		print('TEST_FAIL: 石头 10 秒未进入 GOAL（球=%s）' % str(scene.ball.position))
	# --- 用例 3：羽毛应失败（检测 ❌ 提示） ---
	scene._load_level(1)
	scene._on_tag(0)
	t0 = Time.get_ticks_msec()
	var failed := false
	while Time.get_ticks_msec() - t0 < 15000:
		await physics_frame
		if scene.msg_label.text.contains("❌"):
			failed = true
			break
	if failed:
		print("TEST_PASS: 羽毛 %.1f 秒触发失败提示（符合预期）" % [(Time.get_ticks_msec() - t0) / 1000.0])
	else:
		print("TEST_WARN: 羽毛 15 秒未触发失败提示（球=%s）" % str(scene.ball.position))
	quit()
