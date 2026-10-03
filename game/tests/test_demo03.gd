extends SceneTree
## demo-03 平衡验证（headless）：
## 用例 1：按合理节奏建造/升级 → 应撑过 60 秒获胜，且村民 ≥ 2
## 用例 2：什么都不做 → 应在 40 游戏秒内失败（压迫感）
## 运行：godot --headless --path game -s res://tests/test_demo03.gd
## 用 Engine.time_scale 加速，60 游戏秒 ≈ 10 真实秒。

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	Engine.time_scale = 6.0
	# --- 用例 1：会玩 ---
	var scene = load("res://demo03_kingdom.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var t0 := Time.get_ticks_msec()
	while scene.state == "play" and scene.elapsed < 70.0 and Time.get_ticks_msec() - t0 < 30000:
		await physics_frame
		var e: float = scene.elapsed
		# 模拟玩家的合理操作
		if e > 3.5 and scene.towers[0] == 0 and scene.water >= 20:
			scene._try_build(0)
		elif e > 12.0 and scene.towers[1] == 0 and scene.water >= 20:
			scene._try_build(1)
		elif e > 24.0 and scene.towers[0] == 1 and scene.water >= 40:
			scene._try_upgrade(0)
		elif e > 40.0 and scene.towers[2] == 0 and scene.water >= 20:
			scene._try_build(2)
	var win: bool = scene.state == "win"
	var npcs: int = scene.npcs.size()
	var acid_hit: int = scene.acid_events.filter(func(e): return e.announced).size()
	print("用例1: state=%s heat=%d npcs=%d acid=%d elapsed=%.0f → %s" % [scene.state, int(scene.heat), npcs, acid_hit, scene.elapsed, "PASS" if win and npcs >= 2 and acid_hit >= 1 else "FAIL"])
	# --- 用例 2：摆烂 ---
	scene._setup_round()
	t0 = Time.get_ticks_msec()
	while scene.state == "play" and Time.get_ticks_msec() - t0 < 20000:
		await physics_frame
	var lose_fast: bool = scene.state == "lose" and scene.elapsed < 40.0
	print("用例2: state=%s elapsed=%.0f → %s" % [scene.state, scene.elapsed, "PASS（摆烂会输，有压迫感）" if lose_fast else "FAIL"])
	Engine.time_scale = 1.0
	quit()
