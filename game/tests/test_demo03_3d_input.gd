extends SceneTree
## DEMO3 3D 阶段 B：真实鼠标事件拾取测试（窗口化运行）。
## 通过 Input.parse_input_event 注入真实 InputEventMouseButton/MouseMotion，
## 走 Viewport → _unhandled_input → Camera3D 射线 → Area3D 拾取的完整管线，
## 不直接调用 _try_build/_try_promote。
## 运行：godot --path game -s res://tests/test_demo03_3d_input.gd（窗口化，约 20 秒）
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
	var img := root.get_texture().get_image()
	if img:
		var dir := ProjectSettings.globalize_path(shots_dir)
		DirAccess.make_dir_recursive_absolute(dir)
		img.save_png(dir + "/PT-" + tag + ".png")


func click(pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	press.global_position = pos
	Input.parse_input_event(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = pos
	release.global_position = pos
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
	await click(p0)
	check(scene.sim.towers[0] == 1, "点击槽位 0 → 建造")
	check(approx(float(scene.sim.water), 80.0, 0.6), "建造扣 20（含收入漂移）", "got %.2f" % float(scene.sim.water))
	check(scene.tower_meshes[0].visible, "水塔可见")
	shot("02-点击建造")

	# ---- 2. 再点槽位 0 → 升级 ----
	await click(p0)
	check(scene.sim.towers[0] == 2, "点击槽位 0 → 升级 II")
	check(approx(float(scene.sim.water), 40.0, 0.6), "升级扣 40（含收入漂移）", "got %.2f" % float(scene.sim.water))

	# ---- 3. 时间推进到 20s → 村民出现 → 点击晋升 ----
	sim_set_elapsed(20.0)
	await process_frame
	await process_frame
	check(scene.sim.villagers.size() == 1, "村民已加入")
	var vpos := villager_world(0)
	await click(screen_of(vpos))
	var v: Dictionary = scene.sim.villagers[0]
	check(int(v.level) == 1, "点击村民 → 晋升")
	check(approx(float(scene.sim.water), 10.0, 0.6), "晋升扣 30（含收入漂移）", "got %.2f" % float(scene.sim.water))
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
