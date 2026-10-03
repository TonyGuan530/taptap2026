extends SceneTree
## demo-05 v2 平衡验证（headless，Engine.time_scale 6x）：
## 用例1 分散储备（高地+洞穴）→ 应存活（win/partial）——保底策略仍成立
## 用例2 全押河谷+遇雨+不应急 → 储备尽失只剩初始 6 份——押错且躺平有代价
## 用例3 全押森林+不遇雨 → 食×2 特产富余 win——主动押注有回报
## 用例4 全押河谷+遇雨+灾后抢运进洞 → 大半救回存活——「灾后重构方案」机制成立
## 运行：godot --headless --path game -s res://tests/test_demo05.gd

const BASE_SEED := 2000

var log_lines: Array = []


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)
	log_lines.append(t)
	var f := FileAccess.open("user://test05log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()


func _tile_index(scene, id: String) -> int:
	for i in scene.TILES.size():
		if scene.TILES[i].id == id:
			return i
	return 0


## 秒级筛种子：先建场景读 pending_wind/pending_rain，不合要求立刻换种子重来
func _make_scene(want_east, want_rain) -> Control:
	for attempt in 200:
		seed(BASE_SEED + attempt * 17)
		var s: Control = load("res://demo05_volcano.tscn").instantiate()
		root.add_child(s)
		await physics_frame
		await physics_frame
		var wind_ok: bool = want_east == null or (s.pending_wind == "east") == want_east
		if wind_ok and (want_rain == null or s.pending_rain == want_rain):
			return s
		s.queue_free()
		await physics_frame
	return null


## 准备期存入：等 gather 点数后走 _on_tile_click（特产在存入时结算）
func _deposit(scene, tile: String, times: int) -> void:
	var left: int = times
	var t0 := Time.get_ticks_msec()
	while scene.phase == "prepare" and left > 0 and Time.get_ticks_msec() - t0 < 90000:
		await physics_frame
		while scene.gather > 0 and left > 0:
			scene._on_tile_click(_tile_index(scene, tile))
			left -= 1


## 走完 prepare → announce → adjust（应急行动）→ resolve → decide（选第一条够物资的路线）
func _finish(scene, action: String, relocate_tile: String) -> void:
	var t0 := Time.get_ticks_msec()
	while scene.phase == "prepare" and Time.get_ticks_msec() - t0 < 90000:
		await physics_frame
	t0 = Time.get_ticks_msec()
	while scene.phase == "announce" and Time.get_ticks_msec() - t0 < 60000:
		await physics_frame
	if scene.phase == "adjust":
		if action != "":
			scene._use_emergency(action)
			if action == "relocate":
				scene._do_relocate(_tile_index(scene, relocate_tile))
		t0 = Time.get_ticks_msec()
		while scene.phase == "adjust" and Time.get_ticks_msec() - t0 < 60000:
			await physics_frame
	t0 = Time.get_ticks_msec()
	while scene.phase == "resolve" and Time.get_ticks_msec() - t0 < 60000:
		await physics_frame
	if scene.phase == "decide":
		var total: int = scene.supply.food + scene.supply.water
		for i in scene.ROUTES.size():
			if total >= scene._route_need(i):
				scene._choose_route(i)
				break
		if scene.route_chosen == -1 and total >= 4:
			scene._choose_route(1)


func _run() -> void:
	await process_frame
	Engine.time_scale = 6.0
	Engine.max_physics_steps_per_frame = 120
	var passes := 0
	var fails := 0

	# --- 用例1：分散储备（高地+洞穴），任意天气，按兵不动 ---
	var s1: Control = await _make_scene(null, null)
	await _deposit(s1, "highland", 6)
	await _deposit(s1, "cave", 6)
	await _finish(s1, "skip", "")
	var r1: String = s1.result
	var ok1: bool = r1 == "win" or r1 == "partial"
	_log("用例1 分散储备: result=%s 随身食%d 水%d → %s" % [r1, s1.supply.food, s1.supply.water, "PASS" if ok1 else "FAIL"])
	passes += 1 if ok1 else 0
	fails += 0 if ok1 else 1
	s1.queue_free()
	await physics_frame

	# --- 用例2：全押河谷 + 遇雨(东风：灰先减半再泥流) + 不应急 → 储备尽失（只剩初始携带） ---
	var s2: Control = await _make_scene(true, true)
	await _deposit(s2, "valley", 10)
	await _finish(s2, "skip", "")
	var left2: int = s2.supply.food + s2.supply.water
	# V5 判据：灰减半+泥流吞半后残余物资不足以满足任何路线需求 → 灭亡（押错天气且躺平的代价）
	var ok2: bool = s2.result == "lose"
	_log("用例2 全押河谷(东风遇雨,不应急): result=%s 随身=%d → %s" % [s2.result, left2, "PASS（上不了路，灭亡——五幕方差下仍必死）" if ok2 else "FAIL（未产生失败压力）"])
	passes += 1 if ok2 else 0
	fails += 0 if ok2 else 1
	s2.queue_free()
	await physics_frame

	# --- 用例3：全押森林 + 不遇雨 → 食×2 富余 win ---
	var s3: Control = await _make_scene(null, false)
	await _deposit(s3, "forest", 10)
	await _finish(s3, "skip", "")
	var ok3: bool = s3.result == "win" and s3.margin >= 4
	_log("用例3 全押森林(未遇雨): result=%s 余量%d → %s" % [s3.result, s3.margin, "PASS（食×2 特产押注有回报，余量充足）" if ok3 else "FAIL（特产加成未生效）"])
	passes += 1 if ok3 else 0
	fails += 0 if ok3 else 1
	s3.queue_free()
	await physics_frame

	# --- 用例4：全押河谷 + 遇雨 + 灾后抢运进洞 → 大半救回存活 ---
	var s4: Control = await _make_scene(true, true)
	await _deposit(s4, "valley", 10)
	await _finish(s4, "relocate", "valley")
	var total4: int = s4.supply.food + s4.supply.water
	# 对照用例2（同天气不行动=灭亡）：抢运的价值=从灭亡变成有余量的存活
	var ok4: bool = (s4.result == "win" or s4.result == "partial") and s4.margin >= 1
	_log("用例4 全押河谷(遇雨,抢运): result=%s 余量%d → %s" % [s4.result, s4.margin, "PASS（灾后抢运改写结局）" if ok4 else "FAIL（应急行动未生效）"])
	passes += 1 if ok4 else 0
	fails += 0 if ok4 else 1
	s4.queue_free()
	await physics_frame

	Engine.time_scale = 1.0
	_log("==== 汇总：%d PASS / %d FAIL ====" % [passes, fails])
	quit()
