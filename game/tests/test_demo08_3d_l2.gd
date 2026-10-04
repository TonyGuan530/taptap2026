extends SceneTree
## demo-08 3D 阶段 A 收口：L2 真实输入完整局 × 三策略（高门/低门/直通）。
## 前置：core.unlocked=1（解锁状态为测试装置，L2 内所有交互均为真实鼠标/键盘事件）。
## 配方由 tests/search_l2_recipe.gd 纯核心搜索得出，坐标契约 delta=1/60 下确定性问题可复现。
## 运行（窗口模式，真实渲染）：godot --path game -s res://tests/test_demo08_3d_l2.gd（失败退出码非零）

var passes := 0
var fails := 0
var log_lines: Array = []


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)
	log_lines.append(t)


func _check(cond: bool, tag: String) -> void:
	if cond:
		passes += 1
		_log("PASS " + tag)
	else:
		fails += 1
		_log("FAIL " + tag)


func _frames(n: int) -> void:
	for k in n:
		await physics_frame


func _mouse_btn(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	root.push_input(ev)


func _click(pos: Vector2) -> void:
	_mouse_btn(pos, true)
	await _frames(1)
	_mouse_btn(pos, false)
	await _frames(1)


func _motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	root.push_input(ev)


func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = pressed
	root.push_input(ev)


func _btn_center(scene: Node, btn_name: String, parent_hint: String) -> Vector2:
	var parent: Node = scene.get_node_or_null(parent_hint)
	if parent == null:
		return Vector2.ZERO
	var b: Button = parent.get_node_or_null(btn_name)
	if b == null:
		return Vector2.ZERO
	return b.get_global_rect().get_center()


## 角度精确设置（鼠标纵向）：y = 540 - angle*9 → angle=(540-y)*60/540
func _set_angle(scene: Node, ang: float) -> void:
	_motion(Vector2(480.0, 540.0 - ang * 9.0))
	await _frames(1)
	# 投掷状态在鼠标位置附近移动会误设角：确认后保持鼠标不动
	var got: float = float(scene.core.throw_angle)
	if absf(got - ang) > 0.01:
		_log("警告：设角 %.0f 实得 %.1f" % [ang, got])


func _charge_full_and_release(scene: Node) -> void:
	_key(KEY_SPACE, true)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1400:
		await process_frame
	_key(KEY_SPACE, false)
	await _frames(2)


## 折一条 (0.92, fy1)→(0.92, fy2) 的竖线
func _fold(scene: Node, fy1: float, fy2: float) -> void:
	var pr: Rect2 = scene._paper_rect()
	await _click(pr.position + pr.size * Vector2(0.92, fy1))
	await _click(pr.position + pr.size * Vector2(0.92, fy2))


func _fly_to_settle(scene: Node) -> void:
	var guard := 0
	while String(scene.core.state) == "fly" and guard < 1500:
		await process_frame
		await physics_frame
		guard += 1


## 一掷完整流程：选 L2 → 折 → 设角 → 满蓄力 → 飞 → 结算断言 → 返回选关
func _throw_l2(scene: Node, folds: Array, ang: float, trim_expect: float, tag: String,
		want_high: bool, want_low: bool, coins_expect_add: int) -> void:
	var core: Object = scene.core
	var coins0: int = core.coins
	await _click(_btn_center(scene, "LevelBtn1", "HUD/MenuPanel"))
	_check(String(core.state) == "fold" and core.level_idx == 1, tag + " 进入 L2 折纸")
	for f in folds:
		await _fold(scene, float(f[0]), float(f[1]))
	_check(core.folds_used == folds.size() and absf(float(core.plane_params.trim) - trim_expect) < 1e-6,
		tag + " 折线 %d 条 trim=%.2f（预期 %.2f）" % [core.folds_used, float(core.plane_params.trim), trim_expect])
	await _click(_btn_center(scene, "FoldDoneBtn", "HUD"))
	_check(String(core.state) == "throw", tag + " 进入投掷")
	await _set_angle(scene, ang)
	await _charge_full_and_release(scene)
	_check(String(core.state) == "fly" and absf(float(scene.last_throw.power) - 1.0) < 1e-9
		and absf(float(scene.last_throw.angle) - ang) < 0.01,
		tag + " 满蓄力释放 angle=%.0f power=%.2f" % [float(scene.last_throw.angle), float(scene.last_throw.power)])
	await _fly_to_settle(scene)
	var ok_state: bool = String(core.state) == "settle" and core.last_pass and core.flight_distance >= 45.0
	_check(ok_state, tag + " 过关 %.1fm ≥ 45" % core.flight_distance)
	_check(core.gate_hit == want_high and core.low_gate_hit == want_low,
		tag + " 门命中 高=%s 低=%s（预期 高=%s 低=%s）" % [str(core.gate_hit), str(core.low_gate_hit), str(want_high), str(want_low)])
	var coins_got: int = core.coins - coins0
	_check(coins_got == coins_expect_add,
		tag + " 收益 %d（门奖 %d + 结算 %d）= 预期 %d" % [coins_got, core.gate_coins, core.coins_earned, coins_expect_add])
	var body_txt: String = String(scene.settle_body.text)
	_check(body_txt.contains("门奖 %d" % core.gate_coins), tag + " 结算面板拆分显示门奖 %d" % core.gate_coins)
	# 返回选关（真实点击，进度保留），供下一策略复用
	await _click(_btn_center(scene, "SettleBackBtn", "HUD/SettlePanel"))
	await _frames(2)
	_check(String(core.state) == "menu" and core.unlocked >= 1, tag + " 返回选关（进度保留）")


func _run() -> void:
	await process_frame
	_log("demo-08 3D L2 三策略真实输入测试开始（窗口模式，time_scale=1）")
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	await _frames(3)
	var core: Object = scene.core
	core.unlocked = 1  # 测试装置：L2 按钮可用（解锁为 API 前置；按钮态与后续所有交互走真实事件路径）
	scene._go_menu()  # 刷新选关按钮 disabled 态
	await _frames(1)
	_check(not (scene.get_node("HUD/MenuPanel/LevelBtn1") as Button).disabled, "前置 L2 按钮已解锁可用")

	# 高门配方：4 条 _good_folds（0.92, 0.08+0.06k → 0.92, 0.54+0.06k），mid_y=0.31+0.06k → trim=0.35×0.80=+0.28
	var high_folds := []
	for k in 4:
		high_folds.append([0.08 + 0.06 * float(k), 0.54 + 0.06 * float(k)])
	# 低门/直通配方：2 条近全高竖线（0.92, 0.95→0.05），mid_y=0.5 → trim=0
	var low_folds := [[0.95, 0.05], [0.95, 0.05]]

	# 策略A 直通：15° 无门过关（结算 = int(d/10)+6，d≈45.25 → 10）
	await _throw_l2(scene, low_folds, 15.0, 0.0, "A直通", false, false, 10)

	# 策略B 高门：42° 吃 34m 高门 +3（d≈45.2 → 3+4+6=13）
	await _throw_l2(scene, high_folds, 42.0, 0.28, "B高门", true, false, 13)

	# 策略C 低门：10° 俯冲吃 40m 低门 +3（d≈45.08 → 3+4+6=13）
	await _throw_l2(scene, low_folds, 10.0, 0.0, "C低门", false, true, 13)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_l2_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
