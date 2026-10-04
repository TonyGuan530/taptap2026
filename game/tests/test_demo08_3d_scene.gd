extends SceneTree
## demo-08 3D 阶段 A 灰模场景测试：真实输入（鼠标点击/键盘）完成 L1 完整局；
## 场景层零漂移（场景内核心轨迹 == 纯核心同参重放）；相机只读模拟、可复位。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_scene.gd（失败退出码非零）

const CoreScript := preload("res://demo08_3d/flight_core.gd")

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


func _mouse(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	root.push_input(ev)


func _click(pos: Vector2) -> void:
	_mouse(pos, true)
	await _frames(1)
	_mouse(pos, false)
	await _frames(1)


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


func _run() -> void:
	await process_frame
	_log("demo-08 3D 灰模场景测试开始（真实输入，time_scale=1）")
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	await _frames(3)
	var core: Object = scene.core

	# 1 菜单真实点击 L1
	var p1 := _btn_center(scene, "LevelBtn0", "HUD/MenuPanel")
	await _click(p1)
	_check(core.state == "fold" and core.level_idx == 0, "S1 菜单点击 LevelBtn%d → L1 折纸" % 0)

	# 2 折纸：真实点击两点成一条线，再折一条
	var pr: Rect2 = scene._paper_rect()
	await _click(pr.position + pr.size * Vector2(0.92, 0.2))
	await _click(pr.position + pr.size * Vector2(0.92, 0.8))
	_check(core.folds_used == 1, "S2a 两点成线（folds_used=%d）" % core.folds_used)
	await _click(pr.position + pr.size * Vector2(0.92, 0.3))
	await _click(pr.position + pr.size * Vector2(0.92, 0.7))
	_check(core.folds_used == 2, "S2b 第二条折线（folds_used=%d）" % core.folds_used)

	# 3 完成折叠按钮
	await _click(_btn_center(scene, "FoldDoneBtn", "HUD"))
	_check(core.state == "throw", "S3 完成折叠按钮 → throw")

	# 4 键盘调角度：30 → UP×3 → 39 → DOWN → 36
	for k in 3:
		_key(KEY_UP, true)
		await _frames(1)
	_key(KEY_DOWN, true)
	await _frames(1)
	_check(absf(float(core.throw_angle) - 36.0) < 0.01, "S4 键盘设角 36°（实际 %.0f°）" % float(core.throw_angle))

	# 5 空格按住充能 ~0.7s 后松开 → 起飞
	_key(KEY_SPACE, true)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 700:
		await process_frame
	_key(KEY_SPACE, false)
	await _frames(2)
	_check(core.state == "fly", "S5 蓄力释放 → fly（charge=%.2f）" % float(scene.last_throw.power))
	_check(float(scene.last_throw.power) > 0.4 and float(scene.last_throw.power) < 0.8
		and absf(float(scene.last_throw.angle) - 36.0) < 0.01,
		"S5 入参记录 angle=%.0f power=%.2f" % [float(scene.last_throw.angle), float(scene.last_throw.power)])

	# 6 飞行：逐帧采样核心位置 + 3D 表现 + 相机；R 复位不干扰
	var samples: Array = []
	var cam_samples: Array = []
	var vis_samples: Array = []
	var time_map: Dictionary = {}
	var guard := 0
	var r_sent := false
	while core.state == "fly" and guard < 1200:
		# 时序：process_frame 后本帧 _process 未跑；再等 physics_frame 回到下帧物理起点，
		# 此时上一帧的 step 与 _update_visuals 都已完成 → 核心/视觉/相机为同一帧一致快照
		await process_frame
		await physics_frame
		samples.append(core.plane_pos)
		cam_samples.append(scene.camera.global_position)
		vis_samples.append(scene.plane_visual.position)
		var fidx: int = int(round(float(core.flight_time) * 60.0))
		if not time_map.has(fidx):
			time_map[fidx] = core.plane_pos
		if not r_sent and guard == 60:
			_key(KEY_R, true)
			await _frames(1)
			_key(KEY_R, false)
			r_sent = true
			_check(core.state == "fly", "S6a R 复位相机不改变飞行状态")
		guard += 1
	_check(core.state == "settle" and core.last_pass and core.flight_distance >= 30.0,
		"S6 L1 真实输入过关：%.1fm ≥ 30（%d 帧）" % [core.flight_distance, samples.size()])
	var map_ok := true
	var cam_ok := true
	for i in samples.size():
		var sp: Vector2 = samples[i]
		var expect := Vector3(0.0, (460.0 - sp.y) / 60.0, -(sp.x - 60.0) / 60.0)
		var vis: Vector3 = vis_samples[i]
		if vis.distance_to(expect) > 1e-6:
			map_ok = false
		var cam: Vector3 = cam_samples[i]
		if cam.z < expect.z - 0.5 or cam.y < 1.0:
			cam_ok = false
	_check(map_ok, "S6b 3D 表现位置=坐标契约换算（X=0,Y上,-Z前）")
	_check(cam_ok, "S6c 相机始终在飞机后上方跟随")
	_check(samples.size() > 2 and samples[samples.size() - 1].x > samples[0].x + 60.0 * 25.0,
		"S6d 前进方向真实推进（首帧 x=%.0f → 末帧 x=%.0f）" % [samples[0].x, samples[samples.size() - 1].x])

	# 7 场景层零漂移：纯核心同参重放，按 flight_time 网格对齐比较（抗渲染掉帧的 1:1 假设）
	var core2: Object = CoreScript.new()
	core2.start_level(0)
	core2.add_fold(pr.position + pr.size * Vector2(0.92, 0.2), pr.position + pr.size * Vector2(0.92, 0.8))
	core2.add_fold(pr.position + pr.size * Vector2(0.92, 0.3), pr.position + pr.size * Vector2(0.92, 0.7))
	core2.finish_folds()
	core2.do_throw(float(scene.last_throw.angle), float(scene.last_throw.power))
	var replay: Dictionary = {}
	var g2 := 0
	while core2.state == "fly" and g2 < 1200:
		core2.step(1.0 / 60.0)
		var idx2: int = int(round(float(core2.flight_time) * 60.0))
		if not replay.has(idx2):
			replay[idx2] = core2.plane_pos
		g2 += 1
	var common := 0
	var drift := 0.0
	for idx in time_map:
		if replay.has(idx):
			common += 1
			var rv: Vector2 = replay[idx]
			drift = maxf(drift, rv.distance_to(time_map[idx]))
	_check(common > int(time_map.size() * 0.9) and drift < 1e-6,
		"S7 场景层零漂移：对齐 %d/%d 帧，最大偏差 %.4f px" % [common, time_map.size(), drift])
	_check(core2.last_pass == core.last_pass and absf(core2.flight_distance - core.flight_distance) < 1e-6,
		"S7b 重放终局一致（距离 %.2fm，过关=%s）" % [core2.flight_distance, str(core2.last_pass)])

	# 8 结算面板（门奖拆分显示）→ 商店 → 购买/跳过 → L2
	await _frames(3)
	var settle_ok: bool = scene.settle_panel.visible
	var body_txt: String = String(scene.settle_body.text)
	_check(settle_ok and body_txt.contains("门奖"), "S8a 结算面板显示门奖拆分")
	await _click(_btn_center(scene, "SettleBtn", "HUD/SettlePanel"))
	await _frames(2)
	_check(core.state == "shop" and scene.shop_panel.visible and core.shop_items.size() == 3,
		"S8b 过关进入商店（3 件）")
	var coins_before: int = core.coins
	var item0: Dictionary = core.shop_items[0] if core.shop_items.size() > 0 else {}
	var can_buy: bool = coins_before >= int(item0.get("price", 99))
	if can_buy:
		await _click(_btn_center(scene, "ShopItem0", "HUD/ShopPanel/ShopBox"))
		await _frames(2)
		_check(core.coins == coins_before - int(item0.price), "S8c 真实点击购买扣币一次 %d→%d" % [coins_before, core.coins])
	else:
		_check(true, "S8c 本抽最便宜 %d 币 > 余额 %d，跳过购买路径" % [int(item0.get("price", 0)), coins_before])
	await _click(_btn_center(scene, "ShopSkip", "HUD/ShopPanel"))
	await _frames(2)
	_check(core.state == "fold" and core.level_idx == 1, "S8d 跳过商店 → L2 折纸")

	# 9 L2 场景含门：终点旗门 + 高门(gate_frame) + 低门 = 3 个 ComicObject 道具（每个含多 part 统一材质）
	var prop_count: int = scene.level_props.get_child_count()
	var prop_ok: bool = prop_count == 3
	for prop in scene.level_props.get_children():
		if prop.get_child_count() == 0:
			prop_ok = false
	_check(prop_ok, "S9a L2 场景道具就位（ComicObject 终点+高门+低门=%d 节点，均含 parts）" % prop_count)

	# 汇总
	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_scene_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
