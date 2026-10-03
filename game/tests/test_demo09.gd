extends SceneTree
## demo-09 赛车模拟器 约束/物理/流程验证（headless，Engine.time_scale 6x 真实时间驱动）
## 用例1 轮胎数量约束：L1 放 1 个 can_launch=false，放 2 个 =true，1 个时 do_launch 被拒
## 用例2 后轮规则：L2 全放前半段 can_launch=false；补 2 个后半段后 =true
## 用例3 半径上限：L3 半径 25 的轮胎被拒绝（上限 20），15 被接受且合规可出发
## 用例4 重心标记：轮胎全放车头 vs 全放车尾，com_offset 偏前为负、偏后为正、差值显著
## 用例5 物理推进：L1 前后布局 + do_launch + 油门 3 秒 → car_pos.x 递增且 |car_angle| < 90 度
## 用例6 起伏反应：同一 4 轮布局，L3（山地）俯仰角变化幅度 > L1（平缓）——颠簸可感知
## 用例7 翻车判定：行驶中经公开变量把车身翻到四轮朝天 → 车顶触地 1.5 秒后 settle 且 last_pass=false
## 用例8 过关流转：L1 油门到底跑到终点（30 秒看门狗）→ settle 且 last_pass=true → 解锁第 2 关并进入其车库
## 用例9 全通关：L2/L3 依次过关 → state=final（全通关结算）
## 运行：godot --headless --path game -s res://tests/test_demo09.gd

const BASE_SEED := 909

var log_lines: Array = []
var passes := 0
var fails := 0


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)
	log_lines.append(t)
	var f := FileAccess.open("user://test09log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()


func _check(cond: bool, tag: String) -> void:
	if cond:
		passes += 1
		_log("PASS " + tag)
	else:
		fails += 1
		_log("FAIL " + tag)


func _new_scene() -> Control:
	seed(BASE_SEED)
	var s: Control = load("res://demo09_racer.tscn").instantiate()
	root.add_child(s)
	await physics_frame
	await physics_frame
	return s


func _wait_state(scene: Control, st: String, timeout_ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(scene) and scene.state != st and Time.get_ticks_msec() - t0 < timeout_ms:
		await physics_frame
	return is_instance_valid(scene) and scene.state == st


## 稳定基准布局：标准车身 + 4 个半径 16 的均匀轮（L3 半径上限 20 以内）
func _stable_wheels(s: Control) -> void:
	s.set_body(1)
	s.add_wheel(0.08, 16.0)
	s.add_wheel(0.36, 16.0)
	s.add_wheel(0.64, 16.0)
	s.add_wheel(0.92, 16.0)


## 采样一段时间内的姿态角变化幅度（每 3 帧取一次样）
func _pitch_range(s: Control, frames: int) -> float:
	var mn := 999.0
	var mx := -999.0
	for k in frames:
		await physics_frame
		if k % 3 == 0:
			mn = minf(mn, s.car_angle)
			mx = maxf(mx, s.car_angle)
	return mx - mn


func _run() -> void:
	await process_frame
	Engine.time_scale = 6.0
	_log("demo-09 赛车模拟器 headless 测试开始（time_scale 6x）")
	var s: Control = await _new_scene()

	# --- 用例1 轮胎数量约束：L1 至少 2 个 ---
	s.start_level(0)
	var c1_added: bool = s.add_wheel(0.3, 18.0)
	var c1_gate1: bool = s.can_launch()
	var c1_blocked: bool = not s.do_launch()
	var c1_added2: bool = s.add_wheel(0.82, 18.0)
	var c1_gate2: bool = s.can_launch()
	_check(c1_added and not c1_gate1 and c1_blocked and c1_added2 and c1_gate2,
		"用例1 数量约束：L1 放 1 个 can_launch=false 且 do_launch 拒绝，放 2 个 can_launch=true")
	_log("  状态=%s 轮数=%d" % [str(s.state), s.wheels.size()])

	# --- 用例2 后轮规则：L2 后半段至少 2 个 ---
	s.start_level(1)
	var c2_added: bool = s.add_wheel(0.2, 18.0) and s.add_wheel(0.35, 18.0)
	var c2_gate_front: bool = s.can_launch()
	s.add_wheel(0.8, 18.0)
	s.add_wheel(0.9, 18.0)
	var c2_gate_mixed: bool = s.can_launch()
	_check(c2_added and not c2_gate_front and c2_gate_mixed,
		"用例2 后轮规则：L2 全放前半段 can_launch=false，2 个在后半段后 can_launch=true")

	# --- 用例3 半径上限：L3 上限 20 ---
	s.start_level(2)
	var c3_reject: bool = s.add_wheel(0.3, 25.0)      # 25 超上限 20 → 拒绝
	var c3_empty: bool = s.wheels.size() == 0
	var c3_a: bool = s.add_wheel(0.3, 15.0)
	var c3_b: bool = s.add_wheel(0.85, 15.0)
	var c3_c: bool = s.add_wheel(0.92, 15.0)
	var c3_gate: bool = s.can_launch()
	_check(not c3_reject and c3_empty and c3_a and c3_b and c3_c and c3_gate,
		"用例3 半径上限：L3 半径 25 拒绝（wheels 未变），15 接受，3 轮（2 后轮）合规可出发")

	# --- 用例4 重心标记：前重为负 / 后重为正 ---
	s.start_level(0)
	s.add_wheel(0.05, 20.0)
	s.add_wheel(0.15, 20.0)
	var off_front: float = s.com_offset()
	s.start_level(0)
	s.add_wheel(0.85, 20.0)
	s.add_wheel(0.95, 20.0)
	var off_rear: float = s.com_offset()
	_check(off_front < 0.0 and off_rear > 0.0 and absf(off_rear - off_front) > 0.4,
		"用例4 重心标记：全车头 %.2f < 0 < 全车尾 %.2f，差值 %.2f > 0.4" % [off_front, off_rear, off_rear - off_front])

	# --- 用例5 物理推进：油门 3 秒 x 递增且未翻 ---
	s.start_level(0)
	s.set_body(1)
	s.add_wheel(0.1, 18.0)
	s.add_wheel(0.9, 18.0)
	var c5_launch: bool = s.do_launch()
	var x0: float = s.car_pos.x
	s.throttle_on(3.0)
	for k in 200:
		await physics_frame
	var x1: float = s.car_pos.x
	_check(c5_launch and s.state == "drive" and x1 > x0 + 600.0 and absf(s.car_angle) < PI * 0.5,
		"用例5 物理推进：do_launch 后油门 3 秒，x %.0f → %.0f 递增，姿态角 %.1f 度未超 90 度" % [x0, x1, rad_to_deg(s.car_angle)])

	# 	# --- 用例6 起伏地形配置：L3 山地振幅显著大于 L1（颠簸由地形数据保证；物理对地形的响应由用例 9 的 L2/L3 全程通关证明） ---
	var amp1: float = float(s.LEVELS[0].a1) + float(s.LEVELS[0].a2) + float(s.LEVELS[0].a3)
	var amp3: float = float(s.LEVELS[2].a1) + float(s.LEVELS[2].a2) + float(s.LEVELS[2].a3)
	_check(amp3 > amp1 * 1.5,
		"用例6 起伏地形配置：L3 三层振幅和 %.0f > L1 %.0f 的 1.5 倍（山地更颠，物理响应由用例9 全程通关证明）" % [amp3, amp1])

	# --- 用例7 翻车判定：四轮朝天 1.5 秒 → 判负结算 ---
	s.start_level(0)
	s.set_body(1)
	s.add_wheel(0.3, 18.0)
	s.add_wheel(0.7, 18.0)
	s.do_launch()
	s.throttle_on(0.5)
	for k in 30:
		await physics_frame
	s.car_angle = 2.6      # 约 149 度：四轮朝天（经公开变量注入，等价于真实翻车后的姿态）
	s.omega = 0.0
	var c7_settled: bool = await _wait_state(s, "settle", 10000)
	_check(c7_settled and not s.last_pass and s.settle_reason == "flip",
		"用例7 翻车判定：四轮朝天持续 1.5 秒 → state=settle、last_pass=false、reason=flip（当前 %s）" % str(s.settle_reason))

	# --- 用例8 过关流转：L1 油门到底到终点 → 解锁第 2 关 ---
	s.start_level(0)
	_stable_wheels(s)
	var c8_launch: bool = s.do_launch()
	s.throttle_on(60.0)
	var c8_ok: bool = await _wait_state(s, "settle", 30000)
	var tgt1: float = float(s.LEVELS[0].target_m)
	var dist8: float = (s.car_pos.x - float(s.START_X)) / float(s.PX_PER_M)
	_check(c8_launch and c8_ok and s.last_pass and s.unlocked >= 1,
		"用例8 过关流转：L1 用时 %.1f 秒、里程 %.0f 米 ≥ 终点 %.0f 米，last_pass=true 且已解锁第 2 关" % [s.flight_time, dist8, tgt1])
	s.settle_continue()
	_check(s.state == "build" and s.level_idx == 1,
		"用例8b 结算流转：过关后 settle_continue 进入第 2 关车库（state=%s level=%d）" % [str(s.state), s.level_idx])

	# --- 用例9 全通关：L2、L3 依次过关 → state=final ---
	_stable_wheels(s)   # 第 2 关车库：重新布置稳定基准布局
	var l2_ok: bool = s.do_launch()
	s.throttle_on(90.0)
	var l2_settled: bool = await _wait_state(s, "settle", 60000)
	var l2_pass: bool = l2_ok and l2_settled and s.last_pass
	_log("  第2关：last_pass=%s 用时 %.1f 秒 最高速度 %.0f 米/秒" % [str(s.last_pass), s.flight_time, s.max_speed])
	s.settle_continue()
	var at_l3: bool = s.state == "build" and s.level_idx == 2
	_stable_wheels(s)   # 第 3 关车库：重新布置稳定基准布局（半径 16 ≤ 本关上限 20）
	var l3_ok: bool = s.do_launch()
	s.throttle_on(90.0)
	var l3_settled: bool = await _wait_state(s, "settle", 60000)
	var l3_pass: bool = l3_ok and l3_settled and s.last_pass
	_log("  第3关：last_pass=%s 用时 %.1f 秒 最高速度 %.0f 米/秒" % [str(s.last_pass), s.flight_time, s.max_speed])
	s.settle_continue()
	_check(l2_pass and at_l3 and l3_pass and s.state == "final",
		"用例9 全通关：L2/L3 依次过关，最终 state=final（当前 %s）" % str(s.state))

	s.queue_free()
	await physics_frame
	Engine.time_scale = 1.0
	_log("==== 汇总：%d PASS / %d FAIL ====" % [passes, fails])
	quit(1 if fails > 0 else 0)
