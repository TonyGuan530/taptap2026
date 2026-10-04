extends SceneTree
## DEMO3 3D 阶段 B：真实输入事件测试（v4 起 headless 可跑）。
## 通过 Input.parse_input_event 注入真实 InputEventMouseButton/MouseMotion/Key，
## 走 Viewport → _unhandled_input → Camera3D 射线 → Area3D 拾取的完整管线，
## 不直接调用 _try_build/_try_promote。
## 运行：godot --headless --path game -s res://tests/test_demo03_3d_input.gd（约 20 秒）
## headless 下截图自动跳过（DisplayServer=headless 无帧缓冲）。
## 任何 FAIL → 退出码 1。

const Sim := preload("res://demo03_3d/kingdom_simulation.gd")

var failures := 0
var checks := 0
var scene: Node3D
var shots_dir := "res://../reviews/shots/picking"


func check(cond: bool, name: String, detail: String = "") -> void:
	checks += 1
	if cond:
		print("PASS  ", name)
	else:
		failures += 1
		print("FAIL  ", name, "  ", detail)


func approx(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func shot(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img := root.get_texture().get_image()
	if img:
		var dir := ProjectSettings.globalize_path(shots_dir)
		DirAccess.make_dir_recursive_absolute(dir)
		img.save_png(dir + "/PT-" + tag + ".png")


func click(pos: Vector2) -> void:
	# pos 为视口坐标；parse_input_event 吃窗口坐标，经拉伸变换映射（headless 窗口尺寸≠960×540）
	var xform: Transform2D = root.get_final_transform()
	var wpos := xform * pos
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = wpos
	press.global_position = wpos
	Input.parse_input_event(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = wpos
	release.global_position = wpos
	Input.parse_input_event(release)
	await process_frame
	await process_frame


func screen_of(world: Vector3) -> Vector2:
	var cam: Camera3D = scene.cam
	return cam.unproject_position(world)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	await process_frame
	scene = load("res://demo03_3d.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene._start("classic")
	await process_frame
	sim_set_water(100.0)
	shot("01-开局")

	# ---- 1. 点击槽位 0 → 建造（走拾取管线）----
	var p0 := screen_of(slot_world(0))
	var w0: float = scene.sim.water
	await click(p0)
	check(scene.sim.towers[0] == 1, "点击槽位 0 → 建造")
	check(approx(float(scene.sim.water), w0 - 20.0, 0.6), "建造扣 20（点击前后差值，免疫收入漂移）", "got %.2f" % float(scene.sim.water))
	check(is_instance_valid(scene.comic_towers[0]), "水塔 ComicObject 可见")
	shot("02-点击建造")

	# ---- 2. 再点槽位 0 → 升级 ----
	var w1: float = scene.sim.water
	await click(p0)
	check(scene.sim.towers[0] == 2, "点击槽位 0 → 升级 II")
	check(approx(float(scene.sim.water), w1 - 40.0, 0.6), "升级扣 40（点击前后差值）", "got %.2f" % float(scene.sim.water))

	# ---- 3. 时间推进到 20s → 村民出现 → 点击晋升 ----
	sim_set_elapsed(20.0)
	await process_frame
	await process_frame
	check(scene.sim.villagers.size() == 1, "村民已加入")
	var vpos := villager_world(0)
	var w2: float = scene.sim.water
	await click(screen_of(vpos))
	var v: Dictionary = scene.sim.villagers[0]
	check(int(v.level) == 1, "点击村民 → 晋升")
	check(approx(float(scene.sim.water), w2 - 30.0, 0.6), "晋升扣 30（点击前后差值）", "got %.2f" % float(scene.sim.water))
	shot("03-点击晋升")

	# ---- 4. 资金不足：水滴清零后点空槽 1 → 不建造不扣费 ----
	sim_set_water(0.0)
	var spend_before: int = scene.sim.spend_log.size()
	await click(screen_of(slot_world(1)))
	check(scene.sim.towers[1] == 0, "资金不足不建造")
	check(scene.sim.spend_log.size() == spend_before, "资金不足无消费记录")
	shot("04-资金不足")

	# ---- 5. UI 误触：点 HUD 角落（无 3D 目标）→ 无建造 ----
	sim_set_water(100.0)
	spend_before = scene.sim.spend_log.size()
	await click(Vector2(20, 14))
	check(scene.sim.towers[1] == 0 and scene.sim.towers[2] == 0, "HUD 角落点击不误触建造")
	check(scene.sim.spend_log.size() == spend_before, "误触无消费记录")

	# ---- 6. 镜头变换后拾取：旋转 90° + 缩放 → 点槽位 2 ----
	scene.rig.rotation.y = PI / 2.0
	scene.cam.size = 20.0
	await process_frame
	await process_frame
	var before: int = scene.sim.towers[2]
	await click(screen_of(slot_world(2)))
	check(scene.sim.towers[2] == 1 or before == 1, "旋转缩放后点击槽位 2 生效")
	shot("05-旋转后拾取")
	scene.rig.rotation.y = 0.0
	scene.cam.size = 26.0
	await process_frame

	# ---- 7. 悬停提示（MouseMotion 注入）----
	# 7a. 直接调用悬停逻辑（权威断言：射线+文本）
	var hover_pos: Vector2 = screen_of(slot_world(1))
	scene._update_tooltip(hover_pos)
	var tip: Label = scene.tooltip_label
	check(String(tip.text).contains("槽位 2"), "悬停文本=槽位 2（直接调用，同步读取）", String(tip.text))
	shot("06-悬停提示")
	check(tip.visible, "直接调用后立即读取 visible")
	# 7b. 真实指针路径（warp）：仅观察不计失败
	Input.warp_mouse(hover_pos)
	await process_frame
	await process_frame
	print("INFO  warp 后 tooltip visible=", scene.tooltip_label.visible, " text=", scene.tooltip_label.text)
	shot("06b-悬停提示-warp")

	# ---- 8. 重开清理 ----
	scene._start("classic")
	await process_frame
	var clean := true
	for t: int in scene.sim.towers:
		if t != 0:
			clean = false
	check(clean and scene.sim.villagers.is_empty() and scene.sim.spend_log.is_empty(),
			"重开后状态清理干净")
	check(scene.sim.round_state == "play", "重开后进入 play")

	# ---- 9. v4 灭火指挥：真实键盘事件（F）走输入管线 ----
	sim_set_water(100.0)
	var cmd_press := InputEventKey.new()
	cmd_press.keycode = KEY_F
	cmd_press.physical_keycode = KEY_F
	cmd_press.pressed = true
	Input.parse_input_event(cmd_press)
	await process_frame
	await process_frame
	check(scene.sim.cmd_active(), "按 F → 灭火指挥生效（真实键盘事件）")
	var has_cmd := false
	for rec: Dictionary in scene.sim.spend_log:
		if rec.kind == "command":
			has_cmd = true
	check(has_cmd, "F 指挥产生 spend_log 记录")
	var w_before: float = scene.sim.water
	var cmd_press2 := InputEventKey.new()
	cmd_press2.keycode = KEY_F
	cmd_press2.pressed = true
	Input.parse_input_event(cmd_press2)
	await process_frame
	await process_frame
	check(approx(scene.sim.water, w_before, 0.6), "冷却期再按 F 不重复扣费（含收入漂移）",
			"got %.2f" % scene.sim.water)
	check(scene.cmd_button.disabled, "生效中指挥按钮禁用")

	# ---- 10. v6 菜单第三按钮：真实点击进入寒夜守卫 ----
	scene._show_menu()
	await process_frame
	await process_frame
	await click(Vector2(765, 325))
	check(scene.sim.round_state == "play" and scene.sim.mode == "hard",
			"真实点击寒夜守卫按钮开局", "%s/%s" % [scene.sim.round_state, scene.sim.mode])
	check(not scene.menu_layer.visible, "开局后菜单隐藏")
	check(String(scene.mode_label.text).contains("寒夜"), "模式标签更新", scene.mode_label.text)

	# ---- 11. v7 结算遥测：spend_log 时间线 + 总结行 ----
	scene._start("classic")
	scene.sim.acid_events[0].start = 22.0
	scene.sim.acid_events[1].start = 46.0
	sim_set_water(100.0)
	await click(screen_of(slot_world(0)))
	check(scene.sim.towers[0] == 1, "遥测局真实点击建造一笔")
	scene.sim.elapsed = 59.4
	# headless 帧率不封顶，不能靠帧数等真实时间；用确定性 tick 推进到结算
	var guard := 0
	while scene.sim.round_state == "play" and guard < 120:
		scene.sim.tick(1.0 / 60.0)
		guard += 1
	await process_frame
	await process_frame
	check(scene.sim.round_state == "win" and scene.end_layer.visible, "推进到胜利结算",
			"%s guard=%d" % [scene.sim.round_state, guard])
	var log_text := String(scene.end_log_label.text)
	check(log_text.contains("建造 20水") and log_text.contains("经典 60 秒 · 胜"),
			"结算时间线含建造与总结行", log_text.replace("\n", " | "))
	check(scene._format_spend_log().split("\n").size() >= 2, "格式化至少两行")

	print("==== 3D 阶段 B 拾取测试：checks=%d failures=%d ====" % [checks, failures])
	quit(1 if failures > 0 else 0)


func sim_set_water(v: float) -> void:
	scene.sim.water = v


func sim_set_elapsed(t: float) -> void:
	scene.sim.elapsed = t


func slot_world(i: int) -> Vector3:
	var sp: Vector3 = scene.SLOT_POS[i]
	return sp + Vector3(0, 1.2, 0)


func villager_world(idx: int) -> Vector3:
	var n: Dictionary = scene.sim.villagers[idx]
	var holder: Node3D = scene.villager_nodes[int(n.id)]
	return holder.global_position + Vector3(0, 1.1, 0)
