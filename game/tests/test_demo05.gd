extends SceneTree
## demo-05 平衡验证（headless，Engine.time_scale 6x）：
## 用例1 分散储备（高地+洞穴各一半）→ 应存活（win 或 partial）
## 用例2 全押河谷 → 若遇雨应惨败（证明储备位置与灾害联动、无唯一正确答案）
## 运行：godot --headless --path game -s res://tests/test_demo05.gd

func _init() -> void:
	_run()

func _simulate(scene, store_plan: Array) -> void:
	# 准备期：每 4 游戏秒 +1 采集点；按 plan 顺序轮流存放
	var pi := 0
	var left: int = store_plan[pi].times
	var t0 := Time.get_ticks_msec()
	while scene.phase == "prepare" and Time.get_ticks_msec() - t0 < 90000:
		await physics_frame
		if scene.gather > 0:
			scene.stored[store_plan[pi].tile].food += 1
			scene.stored[store_plan[pi].tile].water += 1
			scene.gather -= 1
			left -= 1
			if left <= 0 and pi < store_plan.size() - 1:
				pi += 1
				left = store_plan[pi].times
	# 灾变展示 3 游戏秒
	t0 = Time.get_ticks_msec()
	while scene.phase == "disaster" and Time.get_ticks_msec() - t0 < 60000:
		await physics_frame
	# 选物资够的路线
	if scene.phase == "decide":
		var total: int = scene.supply.food + scene.supply.water
		for i in scene.ROUTES.size():
			if total >= scene.ROUTES[i].need:
				scene._choose_route(i)
				break
		if scene.route_chosen == -1 and total >= 4:
			scene._choose_route(1)

func _plan_total(plan: Array) -> int:
	var n := 0
	for p in plan:
		n += p.times
	return n

func _run() -> void:
	await process_frame
	Engine.time_scale = 6.0
	# --- 用例1：分散储备 ---
	var scene = load("res://demo05_volcano.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await _simulate(scene, [{tile = "highland", times = 6}, {tile = "cave", times = 6}])
	var r1: String = scene.result
	print("用例1 分散储备: result=%s 随身食%d 水%d → %s" % [r1, scene.supply.food, scene.supply.water, "PASS" if r1 == "win" or r1 == "partial" else "FAIL"])
	scene.queue_free()
	# --- 用例2：全押河谷 + 强制遇雨 → 储备应尽失（只剩初始携带） ---
	var found_rain := false
	var r2 := ''
	for attempt in 12:
		scene.queue_free()
		seed(1000 + attempt)
		scene = load("res://demo05_volcano.tscn").instantiate()
		root.add_child(scene)
		await physics_frame
		await _simulate(scene, [{tile = "valley", times = 10}])
		if scene.rain:
			found_rain = true
			r2 = scene.result
			break
	if found_rain:
		var left: int = scene.supply.food + scene.supply.water
		print('用例2 全押河谷(遇雨): result=%s 随身=%d → %s' % [r2, left, 'PASS（储备被泥流吞没，只剩初始携带）' if left <= 8 else 'FAIL（储备未清零，联动失效）'])
	else:
		print('用例2 SKIP: 12 个种子都没遇到雨（概率性 bug？）')
	Engine.time_scale = 1.0
	quit()
