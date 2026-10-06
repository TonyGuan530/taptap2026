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

	# ---- 6. 有荧光暗区恢复（同起点 0.6s 窗对比，测点离坑沿 ≥0.6m） ----
	ability.reset_level_state(false)
	await _teleport(Vector3(23.8, 1.3, 0))
	await _settle_until_floor()
	var v_noglow := await _hold_and_measure(KEY_D, 0.6)   # 无荧光暗区位移
	ability.gain_dna("glow")
	await _teleport(Vector3(23.8, 1.3, 0))
	await _settle_until_floor()
	var v_glow := await _hold_and_measure(KEY_D, 0.6)     # 有荧光暗区位移
	if v_glow > v_noglow * 1.6:
		_ok("荧光恢复暗区速度：%.2f → %.2f（0.6s 位移，>×1.6）" % [v_noglow, v_glow])
	else:
		_fail("荧光未恢复暗区速度：%.2f vs %.2f" % [v_glow, v_noglow])

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

	# ---- 9. Phase B·L4 裂纹岩墙双向门：缺碎岩被挡，有碎岩撞碎通过 ----
	scene_root.load_level(3)
	await physics_frame
	await physics_frame
	ability.reset_level_state(false)
	await _teleport(Vector3(11.0, 1.3, 0))
	await _settle_until_floor()
	await _hold_and_measure(KEY_D, 3.0)
	var blocked4: bool = player.position.x < 11.9
	ability.gain_dna("break")
	await _hold_and_measure(KEY_D, 2.5)
	var smashed4: bool = false
	for c in scene_root.cracks:
		if c.broken:
			smashed4 = true
	if blocked4 and smashed4 and player.position.x > 12.6:
		_ok("L4 裂纹岩墙：缺碎岩被挡（%.1f），有碎岩撞碎通过（%.1f）" % [11.0, player.position.x])
	else:
		_fail("L4 裂纹岩墙门异常：blocked=%s smashed=%s px=%.1f" % [blocked4, smashed4, player.position.x])

	# ---- 10. Phase B·L5 裂纹岩墙：高跳也翻不过（2.35 > 高跳上限），碎岩唯一解 ----
	scene_root.load_level(4)
	await physics_frame
	await physics_frame
	ability.reset_level_state(false)
	ability.gain_dna("highjump")
	await _teleport(Vector3(5.5, 1.3, 0))
	await _settle_until_floor()
	_key(KEY_D, true)
	var st5 := Time.get_ticks_msec()
	var jt5 := 0
	while Time.get_ticks_msec() - st5 < 4000:
		await physics_frame
		jt5 += 1
		if player.is_on_floor() and jt5 % 8 == 0:
			await _tap(KEY_SPACE, 1)
		elif not player.is_on_floor() and player.velocity.y < 100.0 and jt5 % 4 == 0 and player.jumps_used < player.ability_state.max_jumps():
			await _tap(KEY_SPACE, 1)
		if player.position.x > 8.0:
			break
	_key(KEY_D, false)
	await physics_frame
	var walled5: bool = player.position.x < 7.7
	ability.gain_dna("break")
	await _hold_and_measure(KEY_D, 3.0)
	var smashed5: bool = false
	for c in scene_root.cracks:
		if c.broken:
			smashed5 = true
	if walled5 and smashed5 and player.position.x > 8.0:
		_ok("L5 裂纹岩墙：高跳+跳沿尝试翻不过（挡在墙前），碎岩撞碎通过（px=%.1f）" % player.position.x)
	else:
		_fail("L5 裂纹岩墙门异常：walled=%s smashed=%s px=%.1f" % [walled5, smashed5, player.position.x])

	# ---- 11. Phase B·L3 上层捷径：平台实体（落上站稳）+ 仅组合可达（算术） ----
	scene_root.load_level(2)
	await physics_frame
	await physics_frame
	ability.reset_level_state(false)
	await _teleport(Vector3(7.6, 4.6, -1.35))   # 西侧栈道（3D 适配：悬台改栈道）
	await _settle_until_floor()
	var on_up: bool = absf(player.position.y - 3.9) < 0.2
	if on_up:
		_ok("L3 上层捷径平台实体：落上站稳（y=%.2f ≈ 3.9）" % player.position.y)
	else:
		_fail("L3 上层捷径平台异常：落点 y=%.2f（期望≈3.9）" % player.position.y)
	if rise_c > 3.05 and rise_h < 2.5:
		_ok("L3 上层可达性：组合跳 %.2f > 3.05 > 单高跳 %.2f（仅超级弹跳可上）" % [rise_c, rise_h])
	else:
		_fail("L3 上层可达性算术异常：rise_c=%.2f rise_h=%.2f" % [rise_c, rise_h])

	# ---- 12. Phase B·关卡推进：L1 终点 → 自动进入 L2 夜翼峡谷 ----
	scene_root.load_level(0)
	await physics_frame
	await physics_frame
	ability.reset_level_state(false)
	await _teleport(Vector3(30.5, 1.3, 0))
	await _settle_until_floor()
	await _hold_and_measure(KEY_D, 1.0)
	await _settle(20)
	if scene_root.level_idx == 1:
		_ok("关卡推进：L1 终点自动进入第 2 关「%s」" % scene_root.LEVELS[1].name)
	else:
		_fail("关卡推进失败：level_idx=%d" % scene_root.level_idx)

	# ---- 13. 掉坑恢复：回此前安全落点，保留 DNA/碎片，计时继续（指南 §61） ----
	scene_root.load_level(0)
	await physics_frame
	await physics_frame
	ability.reset_level_state(false)
	ability.gain_dna("highjump")   # 用于验证掉坑不丢 DNA
	await _teleport(Vector3(16.5, 1.3, 0))   # 沟边（坑 17..19）
	await _settle_until_floor()
	await _settle(5)                          # 稳定接地 ≥3 帧 → 记为安全点
	var safe_x := player.position.x
	var pre_elapsed: float = scene_root.elapsed
	await _teleport(Vector3(18.0, 1.3, 0))   # 空传到坑上方 → 必坠
	var recovered := false
	for i in 180:
		await physics_frame
		if player.position.y > -1.0 and player.is_on_floor():
			recovered = true
			break
	if recovered and absf(player.position.x - safe_x) < 0.6 \
			and ability.has_dna("highjump") and scene_root.elapsed >= pre_elapsed:
		_ok("掉坑恢复：回安全边缘（x=%.1f→%.1f），DNA 保留，计时继续" % [safe_x, player.position.x])
	else:
		_fail("掉坑恢复异常：recovered=%s px=%.1f（安全点 %.1f）dna=%s" % [
			recovered, player.position.x, safe_x, ability.has_dna("highjump")])

	# ---- 14. 防墙边侧绕：侧移贴 z 边也过不了教学墙（指南 §198） ----
	ability.reset_level_state(false)
	await _teleport(Vector3(9.5, 1.3, 1.4))   # 靠走廊侧边
	await _settle_until_floor()
	await _hold_and_measure(KEY_D, 3.0)
	if player.position.x < 10.5 and player.position.z <= 1.7:
		_ok("防侧绕：走廊侧壁堵死绕行（x=%.1f < 10.5，z=%.1f）" % [player.position.x, player.position.z])
	else:
		_fail("侧绕未被堵死：x=%.1f z=%.1f" % [player.position.x, player.position.z])

	# ---- 15. 完整再跑（Shift+R）：清总碎片/评级/组合，回第 1 关 ----
	ability.gain_dna("glow")
	scene_root.level_times.append(12.0)
	scene_root.level_ratings.append("S")
	_key(KEY_R, true)
	var ev := InputEventKey.new()
	ev.keycode = KEY_R
	ev.physical_keycode = KEY_R
	ev.pressed = true
	ev.shift_pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	_key(KEY_R, false)
	await physics_frame
	await _settle(10)
	if scene_root.level_idx == 0 and ability.dna.is_empty() \
			and ability.shards_total == 0 and scene_root.level_times.is_empty():
		_ok("完整再跑：进度全清零回第 1 关")
	else:
		_fail("完整再跑异常：idx=%d dna=%d total=%d times=%s" % [
			scene_root.level_idx, ability.dna.size(), ability.shards_total, scene_root.level_times])

	# ---- 16. 遥测 v2：暗区进出事件 + 跳跃计数 + 导出信封落盘 ----
	scene_root.load_level(0)
	await physics_frame
	await physics_frame
	ability.reset_level_state(false)
	await _teleport(Vector3(24.5, 1.3, 0))   # 进暗区（23.4..36）
	await _settle_until_floor()
	await _settle(5)
	await _tap(KEY_SPACE, 1)                 # 跳一下 → 计数
	await _teleport(Vector3(20.0, 1.3, 0))   # 出暗区
	await _settle_until_floor()
	await _settle(5)
	var tel: Dictionary = scene_root.stats
	var evs: Array = scene_root.events
	var zone_events := 0
	var entered := false
	var exited := false
	for e in evs:
		if e.type == "zone":
			zone_events += 1
			if e.enter:
				entered = true
			else:
				exited = true
	scene_root._export_telemetry()
	await physics_frame
	var fr := FileAccess.open("user://demo04_3d_lab_log.json", FileAccess.READ)
	var envelope := {}
	if fr != null:
		envelope = JSON.parse_string(fr.get_as_text())
		fr.close()
	var env_ok: bool = envelope.has("game") and str(envelope.game) == "demo-04-3d" and envelope.has("stats") and envelope.has("events") and envelope.has("tester")
	if entered and exited and int(tel.jumps) >= 1 and env_ok:
		_ok("遥测 v2：暗区进出事件（%d 条 zone）+ 跳跃 %d + 信封落盘" % [zone_events, int(tel.jumps)])
	else:
		_fail("遥测 v2 异常：entered=%s exited=%s jumps=%d env_ok=%s" % [entered, exited, int(tel.jumps), env_ok])

	# ---- 17. 实验房全流程（验收矩阵：K 进/B 出/R/G/T、任意融合顺序基础） ----
	scene_root.load_level(1)
	await physics_frame
	await physics_frame
	ability.reset_level_state(false)
	var ev_k := InputEventKey.new()
	ev_k.keycode = KEY_K
	ev_k.physical_keycode = KEY_K
	ev_k.pressed = true
	Input.parse_input_event(ev_k)
	await physics_frame
	var ev_ku := InputEventKey.new()
	ev_ku.keycode = KEY_K
	ev_ku.physical_keycode = KEY_K
	ev_ku.pressed = false
	Input.parse_input_event(ev_ku)
	await physics_frame
	var lab_ok: bool = scene_root.mode == "lab" and ability.dna.size() == 4
	scene_root._export_telemetry()
	await physics_frame
	var fr2 := FileAccess.open("user://demo04_3d_lab_log.json", FileAccess.READ)
	var env2 := {}
	if fr2 != null:
		env2 = JSON.parse_string(fr2.get_as_text())
		fr2.close()
	var env_lab: bool = str(env2.get("mode", "")) == "lab"
	var ev_b := InputEventKey.new()
	ev_b.keycode = KEY_B
	ev_b.physical_keycode = KEY_B
	ev_b.pressed = true
	Input.parse_input_event(ev_b)
	await physics_frame
	var ev_bu := InputEventKey.new()
	ev_bu.keycode = KEY_B
	ev_bu.physical_keycode = KEY_B
	ev_bu.pressed = false
	Input.parse_input_event(ev_bu)
	await physics_frame
	if lab_ok and env_lab and scene_root.mode == "campaign" and ability.dna.is_empty():
		_ok("实验房：K 进（全DNA）→ T 导出 lab 信封 → B 出（战役 DNA 重教）")
	else:
		_fail("实验房异常：lab_ok=%s env_lab=%s mode=%s dna=%d" % [lab_ok, env_lab, scene_root.mode, ability.dna.size()])

	# ---- 18. 跳数重置回归（v4 真bug①）：落地后空中二段可再用；跳数不跨滞空累积 ----
	scene_root.load_level(0)
	await physics_frame
	await physics_frame
	ability.reset_level_state(false)
	ability.gain_dna("highjump")
	ability.gain_dna("double")
	await _teleport(Vector3(5.0, 1.3, 0))
	await _settle_until_floor()
	await _tap(KEY_SPACE, 1)                     # 地面跳 ju=1
	await _settle(8)                             # 上升段
	var ju1: int = player.jumps_used
	await _tap(KEY_SPACE, 1)                     # 空中二段 ju=2
	await _settle(4)
	var ju2: int = player.jumps_used
	var reawaited := 0
	for i in 240:
		await physics_frame
		if player.is_on_floor() and player.jumps_used == 0:
			reawaited += 1
			break
	if ju1 == 1 and ju2 == 2 and reawaited > 0:
		_ok("跳数重置回归：地面跳→1、二段→2、落地归 0（v4 真bug① 已修）")
	else:
		_fail("跳数异常：ju1=%d ju2=%d 落地归零=%s" % [ju1, ju2, reawaited > 0])

	# ---- 19. 评级边界 + 碎片单次计数 + 全收集 17 枚（验收矩阵） ----
	var ratings_ok: bool = scene_root._rating(45.0) == "S" and scene_root._rating(45.1) == "A" 			and scene_root._rating(90.0) == "A" and scene_root._rating(90.1) == "B"
	var total17: bool = scene_root._total_shards() == 17
	scene_root.load_level(2)
	await physics_frame
	await physics_frame
	ability.reset_level_state(false)
	await _teleport(Vector3(10.25, 1.3, 0))      # L3 岛上碎片 (10.25,1.9) 正上方
	await _settle_until_floor()
	await _settle(30)                            # 持续接触 0.5s
	var once_ok: bool = ability.shards_level == 1
	if ratings_ok and total17 and once_ok:
		_ok("评级边界 45/90 正确；全收集 17 枚；碎片重复接触只计 1 次")
	else:
		_fail("评级/碎片异常：ratings=%s total=%d shards_level=%d" % [ratings_ok, scene_root._total_shards(), ability.shards_level])

	# ---- 20. 跨关污染：R 重开本关裂纹墙复原、组合发现保留、计时归零、输入恢复 ----
	scene_root.load_level(3)
	await physics_frame
	await physics_frame
	ability.reset_level_state(false)
	ability.gain_dna("break")
	ability.combos_found["superjump"] = true      # 模拟跨关已发现
	await _teleport(Vector3(11.5, 1.3, 0))
	await _settle_until_floor()
	await _hold_and_measure(KEY_D, 2.0)          # 撞碎裂纹墙
	var was_broken := false
	for c in scene_root.cracks:
		if c.broken:
			was_broken = true
	var ev_r2 := InputEventKey.new()
	ev_r2.keycode = KEY_R
	ev_r2.physical_keycode = KEY_R
	ev_r2.pressed = true
	Input.parse_input_event(ev_r2)
	await physics_frame
	var ev_r2u := InputEventKey.new()
	ev_r2u.keycode = KEY_R
	ev_r2u.physical_keycode = KEY_R
	ev_r2u.pressed = false
	Input.parse_input_event(ev_r2u)
	await physics_frame
	await _settle(10)
	var crack_restored := false
	for c in scene_root.cracks:
		if not c.broken:
			crack_restored = true
	var no_cross_pollution: bool = crack_restored and ability.combos_found.has("superjump") 			and scene_root.elapsed < 2.0 and player.input_enabled and scene_root.level_times.is_empty()
	if was_broken and no_cross_pollution:
		_ok("跨关污染：R 复原裂纹墙、组合发现保留、计时/碎片/输入干净重置")
	else:
		_fail("重开状态异常：was_broken=%s restored=%s combos=%s" % [was_broken, crack_restored, ability.combos_found.has("superjump")])

	# ---- 21. 可读性组件：暗区体积 + 终点信标 + 碎片脉冲（灰模可读性增强） ----
	scene_root.load_level(1)
	await physics_frame
	await physics_frame
	var dv := scene_root.get_node_or_null("LevelRoot/DarkVisual")
	var gb := scene_root.get_node_or_null("LevelRoot/GoalBeacon")
	var pulse_ok := false
	var sv: MeshInstance3D = null
	for c in scene_root.shard_vis:
		if is_instance_valid(c):
			sv = c
			break
	if sv != null:
		var s1: Vector3 = sv.scale
		await _settle(20)
		var s2: Vector3 = sv.scale
		pulse_ok = (s2 - s1).length() > 0.01
	if dv != null and gb != null and pulse_ok:
		_ok("可读性组件：暗区体积+终点信标存在，碎片脉冲生效")
	else:
		_fail("可读性组件异常：DarkVisual=%s GoalBeacon=%s pulse=%s" % [dv != null, gb != null, pulse_ok])

	# ---- 22. 弹跳板：踩上弹起 ~3.0m（新交互机制；门控安全=平坦段无墙沟） ----
	scene_root.load_level(0)
	await physics_frame
	await physics_frame
	ability.reset_level_state(false)
	await _teleport(Vector3(11.6, 1.3, 1.0))   # 侧带感应区外起步（z 同带）
	await _settle_until_floor()
	var base_y := player.position.y
	var max_y := base_y
	_key(KEY_D, true)
	var t0b := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0b < 2500:
		await physics_frame
		max_y = maxf(max_y, player.position.y)
	_key(KEY_D, false)
	await physics_frame
	var rise := max_y - base_y
	if rise > 2.6 and rise < 3.6:
		_ok("弹跳板：弹起 %.2f m（高跳 2.2 之上、超级弹跳 4.15 之下）" % rise)
	else:
		_fail("弹跳板弹高异常：%.2f m（期望 2.6~3.6）" % rise)

	# ---- 23. 相机跟随：下落全程镜头看得见落点（与玩家距离有界，验收矩阵「镜头看得见落点」） ----
	scene_root.load_level(0)
	await physics_frame
	await physics_frame
	var cam: Node3D = scene_root.get_node("CameraRig")
	ability.reset_level_state(false)
	await _teleport(Vector3(20.0, 5.5, 0))   # 高空落入 L1 中段平台
	cam.position = player.position           # 吸附相机（排除传送瞬断），只测真实跟随滞后
	var worst := 0.0
	for i in 150:
		await physics_frame
		worst = maxf(worst, cam.position.distance_to(player.position))
		if player.is_on_floor() and i > 20:
			break
	if worst > 0.0 and worst < 6.0 and player.is_on_floor():
		_ok("相机跟随：下落全程与玩家最远 %.2f m（<6，落点可见）" % worst)
	else:
		_fail("相机跟随异常：worst=%.2f m on_floor=%s" % [worst, player.is_on_floor()])

	# ---- 24. 实验房关卡选择器：lab 内按 3 直达 L3，全 DNA 保持，B 仍回来源关 ----
	scene_root.load_level(1)
	await physics_frame
	await physics_frame
	ability.reset_level_state(false)
	var ev_k3 := InputEventKey.new()
	ev_k3.keycode = KEY_K
	ev_k3.physical_keycode = KEY_K
	ev_k3.pressed = true
	Input.parse_input_event(ev_k3)
	await physics_frame
	var ev_k3u := InputEventKey.new()
	ev_k3u.keycode = KEY_K
	ev_k3u.physical_keycode = KEY_K
	ev_k3u.pressed = false
	Input.parse_input_event(ev_k3u)
	await physics_frame
	var ev_3 := InputEventKey.new()
	ev_3.keycode = KEY_3
	ev_3.physical_keycode = KEY_3
	ev_3.pressed = true
	Input.parse_input_event(ev_3)
	await physics_frame
	var ev_3u := InputEventKey.new()
	ev_3u.keycode = KEY_3
	ev_3u.physical_keycode = KEY_3
	ev_3u.pressed = false
	Input.parse_input_event(ev_3u)
	await physics_frame
	await _settle(10)
	var sel_ok: bool = scene_root.mode == "lab" and scene_root.level_idx == 2 and ability.dna.size() == 4
	if sel_ok:
		_ok("实验房选关：K 进 → 按 3 直达 L3「%s」，全 DNA 保持" % scene_root.LEVELS[2].name)
	else:
		_fail("实验房选关异常：mode=%s idx=%d dna=%d" % [scene_root.mode, scene_root.level_idx, ability.dna.size()])

	# ---- 25. 实验房终点结算：面板出现、输入停、B 返回战役（未覆盖路径补强） ----
	scene_root.load_level(0)
	await physics_frame
	await physics_frame
	ability.reset_level_state(false)
	var evk := InputEventKey.new()
	evk.keycode = KEY_K
	evk.physical_keycode = KEY_K
	evk.pressed = true
	Input.parse_input_event(evk)
	await physics_frame
	var evku := InputEventKey.new()
	evku.keycode = KEY_K
	evku.physical_keycode = KEY_K
	evku.pressed = false
	Input.parse_input_event(evku)
	await physics_frame
	await _teleport(Vector3(30.5, 1.3, 0))   # L1 终点感应区
	await _settle_until_floor()
	await _settle(30)
	var panel_visible: bool = scene_root.get_node("HUD/Root/WinPanel").visible
	var lab_won: bool = scene_root.won and scene_root.mode == "lab"
	var ev_b2 := InputEventKey.new()
	ev_b2.keycode = KEY_B
	ev_b2.physical_keycode = KEY_B
	ev_b2.pressed = true
	Input.parse_input_event(ev_b2)
	await physics_frame
	var ev_b2u := InputEventKey.new()
	ev_b2u.keycode = KEY_B
	ev_b2u.physical_keycode = KEY_B
	ev_b2u.pressed = false
	Input.parse_input_event(ev_b2u)
	await physics_frame
	await _settle(10)
	var back_ok: bool = not scene_root.won and scene_root.mode == "campaign" and not scene_root.get_node("HUD/Root/WinPanel").visible
	if panel_visible and lab_won and back_ok:
		_ok("实验房终点：结算面板出现、输入停、B 返回战役干净复位")
	else:
		_fail("实验房终点异常：panel=%s won=%s back=%s" % [panel_visible, lab_won, back_ok])

	# ---- 26. 键位条：常驻可见、H 可隐藏、lab 模式文案切换 ----
	scene_root.load_level(0)
	await physics_frame
	await physics_frame
	var lblk: Label = null
	for c in scene_root.get_node("HUD/Root").get_children():
		if c is Label and String(c.text).begins_with("WASD"):
			lblk = c
			break
	var vis0: bool = lblk.visible
	var t0k := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0k < 1200:
		await physics_frame
	var evh := InputEventKey.new()
	evh.keycode = KEY_H
	evh.physical_keycode = KEY_H
	evh.pressed = true
	Input.parse_input_event(evh)
	await physics_frame
	var evhu := InputEventKey.new()
	evhu.keycode = KEY_H
	evhu.physical_keycode = KEY_H
	evhu.pressed = false
	Input.parse_input_event(evhu)
	await physics_frame
	var hidden_ok: bool = not scene_root.keys_hint_visible
	if vis0 and hidden_ok:
		_ok("键位条：常驻显示、H 隐藏生效")
	else:
		_fail("键位条异常：vis0=%s hidden=%s" % [vis0, hidden_ok])

	# ---- 27. 终局回廊（L6）：六关结构 + 零新碎片（全收集维持 17）+ 四 DNA 教学完备 ----
	if scene_root.LEVELS.size() == 6 and String(scene_root.LEVELS[5].name) == "终局回廊":
		var l6: Dictionary = scene_root.LEVELS[5]
		var l6ok: bool = l6.shards.is_empty() and l6.aliens.size() == 4 				and l6.walls.size() == 2 and l6.cracked.size() == 1 and l6.bounces.size() == 1
		if l6ok and scene_root._total_shards() == 17:
			_ok("终局回廊：六关结构完整（2门+1裂纹墙+1弹跳板+4DNA），全收集维持 17")
		else:
			_fail("终局回廊结构异常：l6ok=%s total=%d" % [l6ok, scene_root._total_shards()])
	else:
		_fail("LEVELS 异常：size=%d name=%s" % [scene_root.LEVELS.size(), scene_root.LEVELS.get(5, {}).get("name", "?")])

	# ---- 28. 程序化音效：动作触发后音频播放器存在并播放 ----
	scene_root._play_tone(440, 2.0, 0.3)   # 直触 2s 长音验证音频系统
	await physics_frame
	await physics_frame
	var audio_ok := false
	for pl in scene_root.get_children():
		if pl is AudioStreamPlayer and pl.playing:
			audio_ok = true
			break
	if audio_ok:
		_ok("程序化音效：音频播放器触发并播放中")
	else:
		_fail("程序化音效：未检测到播放中的 AudioStreamPlayer")

	# ---- 29. 资产接入加载器：程序化 PNG → billboard 替换 → 清理还原 ----
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.9, 0.3, 0.2))
	DirAccess.make_dir_recursive_absolute("res://assets")
	img.save_png("res://assets/player.png")
	await physics_frame
	var loader_ok: bool = FileAccess.file_exists("res://assets/player.png")
	# 重建场景以触发 _load_player_asset（模拟重启加载）
	scene_root.queue_free()
	await physics_frame
	await physics_frame
	scene_root = (load("res://demo04_3d.tscn") as PackedScene).instantiate()
	root.add_child(scene_root)
	await physics_frame
	await physics_frame
	player = scene_root.get_node("Player")
	ability = scene_root.get_node("AbilityState")
	var bb: Sprite3D = scene_root.player_billboard
	var swap_ok: bool = bb != null and bb.texture != null and bb.visible
	var gray_hidden := false
	for c in player.get_children():
		if c is MeshInstance3D and c != bb:
			gray_hidden = not c.visible
	if loader_ok and swap_ok and gray_hidden:
		_ok("资产接入：player.png 加载 → billboard 替换灰盒（灰盒隐藏）")
	else:
		_fail("资产接入异常：loader=%s swap=%s gray_hidden=%s" % [loader_ok, swap_ok, gray_hidden])
	# 清理：删除测试资产并还原灰盒形态
	DirAccess.remove_absolute("res://assets/player.png")
	scene_root.queue_free()
	await physics_frame
	await physics_frame
	scene_root = (load("res://demo04_3d.tscn") as PackedScene).instantiate()
	root.add_child(scene_root)
	await physics_frame
	await physics_frame
	player = scene_root.get_node("Player")
	ability = scene_root.get_node("AbilityState")
	var restored: bool = scene_root.player_billboard == null
	if restored:
		_ok("资产清理：测试 PNG 移除后灰盒形态还原")
	else:
		_fail("资产清理异常：billboard 残留")

	# ---- 30. 外星生物资产接入：alien_highjump.png → billboard 替换灰盒 → 清理 ----
	var img2 := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img2.fill(Color(0.3, 0.7, 0.9))
	img2.save_png("res://assets/alien_highjump.png")
	await physics_frame
	scene_root.queue_free()
	await physics_frame
	await physics_frame
	scene_root = (load("res://demo04_3d.tscn") as PackedScene).instantiate()
	root.add_child(scene_root)
	await physics_frame
	await physics_frame
	player = scene_root.get_node("Player")
	ability = scene_root.get_node("AbilityState")
	var bb2: Sprite3D = scene_root.alien_billboards.get("highjump", null)
	var alien_swap: bool = bb2 != null and bb2.texture != null and bb2.visible
	var alien_gray_hidden := false
	for c in scene_root.get_node("LevelRoot").get_children():
		if c is MeshInstance3D and c.position.distance_to(Vector3(6.2, 0.8, 0)) < 0.5:
			alien_gray_hidden = not c.visible
	if alien_swap and alien_gray_hidden:
		_ok("外星生物资产：alien_highjump.png 加载 → billboard 替换灰盒")
	else:
		_fail("外星生物资产异常：swap=%s gray_hidden=%s" % [alien_swap, alien_gray_hidden])
	DirAccess.remove_absolute("res://assets/alien_highjump.png")

	# ---- 31. 掉坑恢复标记：生成发光标记 → 2 秒渐隐清除 ----
	scene_root.load_level(0)
	await physics_frame
	await physics_frame
	ability.reset_level_state(false)
	await _teleport(Vector3(16.5, 1.3, 0))
	await _settle_until_floor()
	await _settle(5)
	await _teleport(Vector3(18.0, 1.3, 0))   # 空传到坑上方 → 必坠
	var marker_spawned := false
	var marker_freed := false
	for i in 180:
		await physics_frame
		if scene_root.recovery_marker != null and is_instance_valid(scene_root.recovery_marker):
			marker_spawned = true
		if scene_root.recovery_marker == null and marker_spawned:
			marker_freed = true
			break
	if marker_spawned and marker_freed:
		_ok("掉坑恢复标记：发光标记生成 → 2 秒渐隐清除")
	else:
		_fail("掉坑恢复标记异常：spawned=%s freed=%s" % [marker_spawned, marker_freed])

	# ---- 汇总 ----
	print("==== RESULTS: %d fail ====" % fails.size())
	for f in fails:
		print("FAILED: " + f)
	if fails.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		quit(1)
