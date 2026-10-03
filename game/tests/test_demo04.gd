extends SceneTree
## demo-04 v4 通关验证（headless）：反应式小机器人跑完全部关卡。
## 用例 1：融合全部 DNA → 连过 3 关 + 组合发现 2/2（PASS：wins>=3 且停在第 3 关胜利）
## 用例 2：不融合蹦蹦兽（无高跳）→ 卡在 L1 高墙前（PASS：px < 1060）
## 用例 3：融合高跳+振翅但不融合荧光 → 卡在黑暗裂谷（PASS：never win 且 max_px < 2900）
## 用例 4：L3 组合可选捷径可达性——单高跳够不到上层平台，超级弹跳（高跳+振翅）可达
## 运行：godot --headless --path game -s res://tests/test_demo04.gd

const RIGHT := KEY_RIGHT
const JUMP := KEY_SPACE

var scene = null

func _init() -> void:
	_run()

func _press(key: Key, frames: int) -> void:
	for i in frames:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.pressed = true
		Input.parse_input_event(ev)
		await physics_frame
	var up := InputEventKey.new()
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await physics_frame

func _tap(key: Key) -> void:
	await _press(key, 2)

func _hold_right() -> void:
	if not scene.keys.get(RIGHT, false):
		var ev := InputEventKey.new()
		ev.keycode = RIGHT
		ev.pressed = true
		Input.parse_input_event(ev)

func _ground_ahead(x: float) -> bool:
	for b in scene.blocks:
		if b[0] <= x and b[0] + b[2] >= x and b[1] >= 440 and b[1] <= 500:
			return true
	return false

func _wall_ahead() -> bool:
	for b in scene.blocks:
		if b[0] > scene.px + 6 and b[0] < scene.px + 84 and b[1] < scene.py - 6:
			return true
	return false

func _fuse_all(skip: String) -> void:
	for a in scene.aliens:
		if a.id != skip and not scene.dna.has(a.id) and absf(scene.px - a.x) < 55.0:
			await _tap(KEY_E)

func _spawn() -> void:
	if scene:
		scene.queue_free()
	scene = load("res://demo04_soup.tscn").instantiate()
	root.add_child(scene)
	await physics_frame

func _bot(max_game_s: float, skip: String) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var jump_cd := 0
	var max_px := 0.0
	var wins := 0
	var shard_sum := 0
	while Time.get_ticks_msec() - t0 < 120000:
		await physics_frame
		jump_cd = maxi(0, jump_cd - 1)
		if scene.state == "win":
			wins += 1
			shard_sum += scene.level_shards
			if wins >= 5:
				break
			scene._advance()
			await physics_frame
			continue
		if scene.elapsed > max_game_s:
			break
		_hold_right()
		await _fuse_all(skip)
		if jump_cd == 0:
			if scene.on_floor:
				if (not _ground_ahead(scene.px + 50.0)) or (not _ground_ahead(scene.px + 110.0)) or _wall_ahead():
					await _tap(JUMP)
					jump_cd = 4
			elif scene.dna.has("double") and scene.jumps_used == 1 and scene.vy > -40.0:
				await _tap(JUMP)
				jump_cd = 8
		max_px = maxf(max_px, scene.px)
	return {"wins": wins, "max_px": max_px, "final_px": scene.px, "shards": shard_sum, "level": scene.level_idx}

func _reach_test(with_combo: bool) -> float:
	## L3 捷径可达性：从 x470 地面起跳向右，返回飞行中的最高点（最小 py）。
	await _spawn()
	scene._load_level(2)
	await physics_frame
	scene.px = 470.0
	scene.py = 440.0
	scene.vy = 0.0
	scene.dna = {"highjump": true}
	if with_combo:
		scene.dna["double"] = true
	scene.jump_held = false
	await physics_frame
	# 等待真正落地（_load_level 后从空中放下）再起跳
	for i in 30:
		if scene.on_floor:
			break
		await physics_frame
	var min_py := 99999.0
	await _tap(JUMP)
	var ev := InputEventKey.new()
	ev.keycode = RIGHT
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 120:
		await physics_frame
		min_py = minf(min_py, scene.py)
		if scene.on_floor and i > 8:
			break
		if with_combo and not scene.on_floor and scene.jumps_used == 1 and scene.vy > -40.0:
			await _tap(JUMP)
	var up := InputEventKey.new()
	up.keycode = RIGHT
	up.pressed = false
	Input.parse_input_event(up)
	return min_py

func _run() -> void:
	await process_frame
	Engine.time_scale = 4.0

	# --- 用例 1：全 DNA 连过 3 关 ---
	await _spawn()
	var r1: Dictionary = await _bot(400.0, "")
	var pass1: bool = r1.wins >= 5 and r1.level == 4 and scene.combos_found.size() >= 2
	print("用例1: wins=%d level=%d/5 碎片=%d 组合发现=%d/2 → %s" % [r1.wins, r1.level + 1, r1.shards, scene.combos_found.size(), "PASS（5 关全通）" if pass1 else "FAIL"])

	# --- 用例 2：不融合蹦蹦兽，应卡在 L1 高墙前 ---
	await _spawn()
	var r2: Dictionary = await _bot(60.0, "highjump")
	var pass2: bool = r2.final_px < 1060.0
	print("用例2: 无高跳 final_px=%.0f（墙在1000）→ %s" % [r2.final_px, "PASS（地形强制需要高跳 DNA）" if pass2 else "FAIL"])

	# --- 用例 3：不融合灯灯菌，应卡在黑暗裂谷前 ---
	await _spawn()
	var r3: Dictionary = await _bot(90.0, "glow")
	var pass3: bool = r3.wins == 0 and r3.max_px < 2900.0
	print("用例3: 无荧光 max_px=%.0f wins=%d → %s" % [r3.max_px, r3.wins, "PASS（黑暗裂谷强制需要荧光 DNA）" if pass3 else "FAIL"])

	# --- 用例 4：L3 组合可选捷径——只有超级弹跳能跃上发射台（顶 y170） ---
	var min_a: float = await _reach_test(false)   # 只有高跳
	var min_b: float = await _reach_test(true)    # 高跳+振翅=超级弹跳
	var pass4: bool = min_a > 180.0 and min_b <= 170.0
	print("用例4: 单高跳 min_py=%.0f（需>180 不可达）超级弹跳 min_py=%.0f（需≤170 可达）→ %s" % [min_a, min_b, "PASS（捷径=组合可选路线， Mastery 而非 Requirement）" if pass4 else "FAIL"])

	# --- 用例 5：实验房遥测——自由顺序融合（荧光→高跳→振翅）+ 持久化 ---
	await _spawn()
	scene._enter_lab()
	await physics_frame
	for id in ["glow", "highjump", "double"]:
		for a in scene.aliens:
			if a.id == id:
				scene.px = a.x
		await physics_frame
		await _tap(KEY_E)
	await physics_frame
	var evs: Array = scene.lab_events
	var fuses := evs.filter(func(e): return e.event_type == "dna_fused")
	var combos5 := evs.filter(func(e): return e.event_type == "combo_discovered")
	var zones := evs.filter(func(e): return e.event_type == "zone_enter")
	var envelope_ok: bool = fuses.size() > 0 and fuses[0].has("elapsed_ms") and fuses[0].has("owned_dna") and fuses[0].has("tester_id") and fuses[0].has("player_x")
	var order_ok: bool = fuses.size() == 3 and fuses[0].id == "glow" and fuses[1].id == "highjump" and fuses[2].id == "double"
	scene._exit_lab()
	await physics_frame
	var lf := FileAccess.open("user://demo04_lab_log.json", FileAccess.READ)
	var file_ok: bool = lf != null and lf.get_as_text().length() > 20
	if lf: lf.close()
	var pass5: bool = order_ok and combos5.size() == 2 and file_ok and envelope_ok and zones.size() >= 2
	print("用例5: 遥测 fuse=%d combo=%d zone=%d 信封=%s 顺序=%s 持久化=%s → %s" % [fuses.size(), combos5.size(), zones.size(), envelope_ok, order_ok, file_ok, "PASS（实验房遥测 v2：信封+区域+持久化）" if pass5 else "FAIL"])

	# --- 用例 6：L4 裂纹岩墙双向对照——无碎岩卡墙，有碎岩击穿 ---
	await _spawn()
	scene._load_level(3)
	await physics_frame
	scene.dna = {"highjump": true}
	scene.jump_held = false
	var t6 := Time.get_ticks_msec()
	var stuck_px := 0.0
	var jump_cd6 := 0
	while scene.elapsed < 20.0 and Time.get_ticks_msec() - t6 < 30000:
		await physics_frame
		jump_cd6 = maxi(0, jump_cd6 - 1)
		if not scene.keys.get(RIGHT, false):
			var ev := InputEventKey.new()
			ev.keycode = RIGHT
			ev.pressed = true
			Input.parse_input_event(ev)
		if jump_cd6 == 0 and scene.on_floor:
			await _tap(JUMP)
			jump_cd6 = 10
		stuck_px = scene.px
	var stuck_ok: bool = stuck_px < 640.0   # 高跳顶277 越不过顶250 的裂纹墙
	scene.dna["break"] = true
	t6 = Time.get_ticks_msec()
	var broke_px := 0.0
	while Time.get_ticks_msec() - t6 < 8000:
		await physics_frame
		broke_px = scene.px
		if broke_px > 700.0:
			break
	var break_ok: bool = broke_px > 700.0
	print("用例6: 无碎岩卡在 %.0f（<640 ✓/✗）有碎岩推进到 %.0f（>700 ✓/✗）→ %s" % [stuck_px, broke_px, "PASS（裂纹墙=碎岩双向对照）" if (stuck_ok and break_ok) else "FAIL"])

	Engine.time_scale = 1.0
	quit()
