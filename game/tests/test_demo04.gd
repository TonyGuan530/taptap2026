extends SceneTree
## demo-04 v2 通关验证（headless）：反应式小机器人跑完全部关卡。
## 用例 1：融合全部 DNA → 连过 3 关（PASS：wins>=3 且停在第 3 关胜利）
## 用例 2：不融合蹦蹦兽（无高跳）→ 卡在 L1 高墙前（PASS：px < 1060）
## 用例 3：融合高跳+振翅但不融合荧光 → 卡在黑暗裂谷（PASS：never win 且 max_px < 2900）
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
			if wins >= 3:
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

func _run() -> void:
	await process_frame
	Engine.time_scale = 4.0

	# --- 用例 1：全 DNA 连过 3 关 ---
	await _spawn()
	var r1: Dictionary = await _bot(400.0, "")
	var pass1: bool = r1.wins >= 3 and r1.level == 2 and scene.combos_found.size() >= 2
	print("用例1: wins=%d level=%d/3 碎片=%d/9 组合发现=%d/2 → %s" % [r1.wins, r1.level + 1, r1.shards, scene.combos_found.size(), "PASS" if pass1 else "FAIL"])

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

	Engine.time_scale = 1.0
	quit()
