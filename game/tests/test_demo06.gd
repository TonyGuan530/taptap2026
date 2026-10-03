extends SceneTree
## demo-06 验证（headless，time_scale 6x）：
## T1: Fire 球烧掉栅栏 → 玩家走到 GOAL（解法A）
## T2: Heavy 球砸掉栅栏 → 玩家走到 GOAL（解法B，不同词条同一目标）
## T3: 墨水不足时放置被拒绝
## 运行：godot --headless --path game -s res://tests/test_demo06.gd

var scene = null

func _init() -> void:
	_run()

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000:
		await physics_frame

func _run() -> void:
	await process_frame
	Engine.time_scale = 6.0
	# --- T1: Fire 解法 ---
	scene = load("res://demo06_inkwords.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.shape_idx = 0   # 圆球
	scene.word_idx = 2    # Fire
	scene._try_place(Vector2(513, 400))   # 栅栏旁
	await _wait(1.5)
	var fence_gone: bool = not is_instance_valid(scene.get_node_or_null("Fence"))
	# 向右走到 GOAL
	scene.keys[KEY_D] = true
	var t0 := Time.get_ticks_msec()
	while scene.state == "play" and Time.get_ticks_msec() - t0 < 20000:
		await physics_frame
	scene.keys[KEY_D] = false
	print("T1 Fire烧栅栏: fence_gone=%s state=%s → %s" % [fence_gone, scene.state, "PASS" if fence_gone and scene.state == "win" else "FAIL"])
	scene.queue_free()
	# --- T2: Heavy 解法 ---
	scene = load("res://demo06_inkwords.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.shape_idx = 0
	scene.word_idx = 0   # Heavy
	scene._try_place(Vector2(513, 380))   # 栅栏上方落下砸
	await _wait(1.5)
	fence_gone = not is_instance_valid(scene.get_node_or_null("Fence"))
	scene.keys[KEY_D] = true
	t0 = Time.get_ticks_msec()
	while scene.state == "play" and Time.get_ticks_msec() - t0 < 20000:
		await physics_frame
	scene.keys[KEY_D] = false
	print("T2 Heavy砸栅栏: fence_gone=%s state=%s → %s" % [fence_gone, scene.state, "PASS" if fence_gone and scene.state == "win" else "FAIL"])
	# --- T3: 墨水不足拒绝 ---
	scene._load_level(0)
	scene.ink = 10
	var before: int = scene.ink
	var cnt: int = scene.placed.size()
	scene.shape_idx = 0
	scene.word_idx = 0
	scene._try_place(Vector2(200, 400))
	var rejected: bool = scene.ink == before and scene.placed.size() == cnt
	print("T3 墨水不足: ink=%d placed=%d → %s" % [scene.ink, scene.placed.size(), "PASS（拒绝放置）" if rejected else "FAIL"])
	Engine.time_scale = 1.0
	quit()
