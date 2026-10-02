extends SceneTree
## demo-04 通关验证（headless）：模拟按键跑完全程。
## 用例 1：融合全部 DNA → 能到逃生舱（PASS 条件：state==win）
## 用例 2：不融合蹦蹦兽（无高跳）→ 60 秒内卡在高墙前（PASS 条件：px < 1060）
## 运行：godot --headless --path game -s res://tests/test_demo04.gd

const LEFT := KEY_LEFT
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

func _run() -> void:
	await process_frame
	scene = load("res://demo04_soup.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	Engine.time_scale = 4.0

	# --- 用例 1：全 DNA 通关 ---
	var t0 := Time.get_ticks_msec()
	var jump_cd := 0
	while scene.state == "play" and Time.get_ticks_msec() - t0 < 60000:
		await physics_frame
		jump_cd = maxi(0, jump_cd - 1)
		var e := scene as Node2D
		var px: float = e.px
		# 持续向右
		if not e.keys.get(RIGHT, false):
			var ev := InputEventKey.new()
			ev.keycode = RIGHT
			ev.pressed = true
			Input.parse_input_event(ev)
		# 融合：靠近外星生物按 E
		for a in e.ALIENS:
			if not e.dna.has(a.id) and absf(px - a.x) < 55.0:
				await _tap(KEY_E)
		# ① 高墙前（x≈940）高跳
		if px > 900 and px < 1000 and e.on_floor and jump_cd == 0 and e.dna.has("highjump"):
			await _tap(JUMP)
			jump_cd = 30
		# ② 长沟边缘（x≈1660）二段跳：跳起后空中再跳
		if px > 1640 and px < 1700 and jump_cd == 0 and e.dna.has("double"):
			await _tap(JUMP)
			jump_cd = 12
		elif px > 1700 and px < 1800 and not e.on_floor and e.jumps_used == 1 and e.dna.has("double") and jump_cd == 0:
			await _tap(JUMP)
			jump_cd = 12
		# ③ 裂谷边缘（x≈2560）先确保荧光，到边缘就跳
		if px > 2560 and px < 2600 and e.on_floor and jump_cd == 0 and e.dna.has("glow"):
			await _tap(JUMP)
			jump_cd = 30
	var won: bool = scene.state == "win"
	var dna_count: int = scene.dna.size()
	print("用例1: state=%s dna=%d/3 elapsed=%.0fs px=%.0f → %s" % [scene.state, dna_count, scene.elapsed, scene.px, "PASS" if won and dna_count == 3 else "FAIL"])
	var win_elapsed: float = scene.elapsed

	# --- 用例 2：不融合蹦蹦兽，应卡在高墙前 ---
	scene.queue_free()
	scene = load("res://demo04_soup.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	t0 = Time.get_ticks_msec()
	jump_cd = 0
	while scene.state == "play" and scene.elapsed < 60.0 and Time.get_ticks_msec() - t0 < 45000:
		await physics_frame
		jump_cd = maxi(0, jump_cd - 1)
		var px: float = scene.px
		if not scene.keys.get(RIGHT, false):
			var ev := InputEventKey.new()
			ev.keycode = RIGHT
			ev.pressed = true
			Input.parse_input_event(ev)
		for a in scene.ALIENS:
			if a.id != "highjump" and not scene.dna.has(a.id) and absf(px - a.x) < 55.0:
				await _tap(KEY_E)
		# 只用普通跳试图翻墙（会失败）
		if px > 900 and px < 1000 and scene.on_floor and jump_cd == 0:
			await _tap(JUMP)
			jump_cd = 30
		if px > 1660 and px < 1700 and jump_cd == 0:
			await _tap(JUMP)
			jump_cd = 12
	var stuck_at_wall: bool = scene.px < 1060.0
	print("用例2: 无高跳 px=%.0f（墙在1000）elapsed=%.0f → %s" % [scene.px, scene.elapsed, "PASS（地形强制需要高跳 DNA）" if stuck_at_wall else "FAIL"])
	print("SUMMARY: win_elapsed=%.0fs" % win_elapsed)
	Engine.time_scale = 1.0
	quit()
