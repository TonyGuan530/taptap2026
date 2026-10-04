extends SceneTree
## DEMO4 3D 阶段 A 能力基线测试（headless，真实输入事件驱动）。
## 全部断言通过 → quit(0)；任何失败 → 汇总后 quit(1)。
## 运行（在 worktree 的 game/ 下）：godot --headless --path . -s res://tests/test_demo04_3d.gd

var fails: Array = []
var scene_root: Node3D
var player: CharacterBody3D
var ability: Node

func _init() -> void:
	_run()

func _fail(msg: String) -> void:
	fails.append(msg)
	print("FAIL: " + msg)

func _ok(msg: String) -> void:
	print("ok: " + msg)

func _key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)

func _tap(code: Key, hold_ticks: int) -> void:
	_key(code, true)
	for i in hold_ticks:
		await physics_frame
	_key(code, false)
	await physics_frame

func _teleport(pos: Vector3) -> void:
	player.position = pos
	player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame

func _settle(ticks: int) -> void:
	for i in ticks:
		await physics_frame

func _settle_until_floor() -> void:
	await physics_frame
	await physics_frame   # 消费传送前的陈旧 on_floor 状态
	for i in 120:
		if player.is_on_floor():
			return
		await physics_frame

func _hold_and_measure(code: Key, seconds: float) -> float:
	var start := player.position
	_key(code, true)
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(seconds * 1000.0):
		await physics_frame
	_key(code, false)
	await physics_frame
	var d3 := player.position - start
	d3.y = 0.0
	return d3.length()

func _measure_jump_rise() -> float:
	# 平地站定 → 周期性点按（模拟真人连按）→ 记录最高点（首跳+可用二段跳）
	await _teleport(Vector3(5.0, 1.3, 0))
	await _settle_until_floor()
	var base_y := player.position.y
	var max_y := base_y
	var ticks := 0
	var fired := false
	while ticks < 240:
		await physics_frame
		ticks += 1
		max_y = maxf(max_y, player.position.y)
		if player.is_on_floor():
			if fired and ticks > 20:
				break   # 已跳过并回落 = 测量完成
			if ticks % 3 == 0:
				await _tap(KEY_SPACE, 1)
		elif player.jumps_used >= 1 and player.jumps_used < player.ability_state.max_jumps() and player.velocity.y <= 2.0 and ticks % 3 == 0:
			await _tap(KEY_SPACE, 1)   # 空中再按 = 二段跳
		if player.position.y > base_y + 0.2:
			fired = true
	return max_y - base_y

func _run() -> void:
	var packed: PackedScene = load("res://demo04_3d.tscn")
	scene_root = packed.instantiate()
	root.add_child(scene_root)
	await physics_frame
	await physics_frame
	player = scene_root.get_node("Player")
	ability = scene_root.get_node("AbilityState")

	# ---- 1. 无 DNA 跳跃高度（基线理论 ~1.05m） ----
	var rise0 := await _measure_jump_rise()
	ability.reset_level_state(false)
	if rise0 > 0.75 and rise0 < 1.45:
		_ok("无 DNA 跳跃高度 %.2f m（0.75-1.45）" % rise0)
	else:
		_fail("无 DNA 跳跃高度 %.2f m 超出 0.75-1.45" % rise0)

	# ---- 2. 高跳（×1.45）高度且显著更高 ----
	ability.gain_dna("highjump")
	var rise_h := await _measure_jump_rise()
	ability.reset_level_state(true)
	ability.gain_dna("highjump")
	if rise_h > 1.7 and rise_h < 2.6:
		_ok("高跳跳跃高度 %.2f m（1.7-2.6）" % rise_h)
	else:
		_fail("高跳跳跃高度 %.2f m 超出 1.7-2.6" % rise_h)
	if rise_h > rise0 * 1.6:
		_ok("高跳显著高于无 DNA（%.2f > %.2f×1.6）" % [rise_h, rise0])
	else:
		_fail("高跳未显著高于无 DNA（%.2f vs %.2f）" % [rise_h, rise0])

	# ---- 3. 组合（高跳+二段）显著更高 ----
	ability.gain_dna("double")
	var rise_c := await _measure_jump_rise()
	ability.reset_level_state(true)
	if rise_c > rise_h + 0.15:
		_ok("组合高度 %.2f 显著高于单高跳 %.2f" % [rise_c, rise_h])
	else:
		_fail("组合高度 %.2f 未显著高于单高跳 %.2f" % [rise_c, rise_h])

	# ---- 4. 融合：E 近距离融合、不重复 ----
	ability.reset_level_state(false)
	await _teleport(Vector3(6.7, 1.3, 0))
	await _settle_until_floor()
	var before: int = ability.dna.size()
	await _tap(KEY_E, 2)
	await physics_frame
	await _tap(KEY_E, 2)
	await physics_frame
	var after: int = ability.dna.size()
	if before == 0 and after == 1:
		_ok("E 融合成功且不重复（0 → 1）")
	else:
		_fail("融合异常：before=%d after=%d" % [before, after])

	# ---- 5. 暗区减速 ×0.45 ----
	await _teleport(Vector3(21.0, 1.3, 0))
	await _settle_until_floor()
	var v_light := await _hold_and_measure(KEY_D, 1.0)
	await _teleport(Vector3(24.0, 1.3, 0))
	await _settle_until_floor()
	var v_dark := await _hold_and_measure(KEY_D, 1.0)
	var ratio := v_dark / maxf(0.01, v_light)
	if ratio > 0.3 and ratio < 0.6:
		_ok("暗区减速比 %.2f（0.3-0.6，目标 0.45）" % ratio)
	else:
		_fail("暗区减速比 %.2f 超出 0.3-0.6" % ratio)

	# ---- 6. 有荧光暗区恢复 ----
	var v_glow := await _hold_and_measure(KEY_D, 1.0)   # 已有 glow（步骤4融合的是highjump——重置过，此处补测）
	# 步骤4融合过 highjump；这里显式给 glow
	ability.gain_dna("glow")
	v_glow = await _hold_and_measure(KEY_D, 1.0)
	if v_glow > v_dark * 1.6:
		_ok("荧光恢复暗区速度 %.2f（> %.2f×1.6）" % [v_glow, v_dark])
	else:
		_fail("荧光未恢复暗区速度：%.2f vs %.2f" % [v_glow, v_dark])

	# ---- 7. 缺高跳不能过教学墙 ----
	ability.reset_level_state(false)
	await _teleport(Vector3(8.0, 1.3, 0))
	await _settle_until_floor()
	await _hold_and_measure(KEY_D, 3.0)
	if player.position.x < 10.6:
		_ok("无高跳被教学墙阻挡（px=%.1f < 10.6）" % player.position.x)
	else:
		_fail("无高跳竟能过教学墙（px=%.1f）" % player.position.x)

	# ---- 8. 有高跳+二段跳可过教学墙（真实输入跳+漂移） ----
	ability.gain_dna("highjump")
	ability.gain_dna("double")
	await _teleport(Vector3(8.5, 1.3, 0))
	await _settle_until_floor()
	_key(KEY_D, true)
	var crossed := false
	var jt := 0
	var wall_ticks := 0
	while Time.get_ticks_msec() - Time.get_ticks_msec() < 600000:
		break
	var st := Time.get_ticks_msec()
	while Time.get_ticks_msec() - st < 6000:
		await physics_frame
		wall_ticks += 1
		# 贴墙且在地面 → 起跳
		if player.position.x > 9.4 and player.position.x < 10.7 and player.is_on_floor() and wall_ticks % 8 == 0:
			await _tap(KEY_SPACE, 2)
		# 空中且低于墙顶 → 二段跳
		elif not player.is_on_floor() and player.jumps_used >= 1 and player.jumps_used < 2 and player.velocity.y < 100.0 and wall_ticks % 4 == 0:
			await _tap(KEY_SPACE, 2)
		if player.position.x > 11.0:
			crossed = true
			break
	_key(KEY_D, false)
	await physics_frame
	if crossed:
		_ok("有高跳+二段跳可过教学墙")
	else:
		_fail("有高跳+二段跳未能过教学墙（px=%.1f）" % player.position.x)

	# ---- 汇总 ----
	print("==== RESULTS: %d fail ====" % fails.size())
	for f in fails:
		print("FAILED: " + f)
	if fails.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		quit(1)
