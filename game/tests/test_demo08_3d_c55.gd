extends SceneTree
## demo-08 3D 阶段 C55（打磨十五·折纸 3D 化 A+B）核心不变量（headless）：
## A 参数驱动形变：_rebuild_plane_visual 按折线参数重建机体（lift→翼面缩放 / trim→上反角 / 折数→折痕线）；
## B 折纸态 3D 预览：SubViewport 环绕相机 + HUD 小窗随 fold 态显隐。
## 纯表现层：核心 plane_params 与飞行数值不被重建改动（断言前后一致）。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c55.gd（失败退出码非零）

const DELTA := 1.0 / 60.0

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


func _fold_n(c: Object, n: int, v: float) -> void:
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))


func _part_count(scene: Node) -> int:
	var n := 0
	for ch in scene.plane_visual.get_children():
		if String(ch.name).begins_with("Part"):
			n += 1
	return n


func _wing_x(scene: Node) -> float:
	for ch in scene.plane_visual.get_children():
		if String(ch.name).begins_with("Part") and ch.mesh is BoxMesh and absf(float(ch.mesh.size.x) - 0.06) > 0.01 and float(ch.mesh.size.z) > 0.2:
			return float(ch.mesh.size.x)
	return -1.0


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C55 折纸 3D 化测试开始")

	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	var core: Object = scene.core

	# C55-1 默认形：进场重建后机体存在，零折参数 → 翼面缩放 0.72、无折痕（3 parts）
	_check(scene.plane_visual != null and int(_part_count(scene)) == 3,
		"C55-1 默认形 3 parts（机身+双翼，零折痕）")

	# C55-2 形变映射：4 折 v=0.2 → lift_area≈0.936 → 翼面 x≈0.520、折痕 8 条（11 parts）
	core.start_level(1)
	_fold_n(core, 4, 0.2)
	var lift_expect: float = float(core.plane_params.lift_area)
	core.finish_folds()
	scene._rebuild_plane_visual()
	var s_expect: float = clampf(0.72 + lift_expect * 0.24, 0.68, 1.35)
	_check(_part_count(scene) == 11 and absf(_wing_x(scene) - 0.55 * s_expect) < 0.01,
		"C55-2 形变映射：11 parts（含 8 折痕）/ 翼面 x=%.3f（期望 %.3f）" % [_wing_x(scene), 0.55 * s_expect])

	# C55-3 trim→上反角映射：同 lift（4 折 v=0.2）但折线偏纸上方（mid_y 0.25）→ trim 更大 → 翼基旋转不同
	var lift_a: float = float(core.plane_params.lift_area)
	var trim_a: float = float(core.plane_params.trim)
	var basis_a: Transform3D = scene.plane_visual.get_child(1).transform
	core.start_level(1)
	var pr3: Rect2 = core.paper_rect
	for k in 4:
		var mid3: float = 0.25   # 同 lift（v=0.2 四折）但折线偏纸上方（vert +0.5）→ trim 更大
		core.add_fold(pr3.position + pr3.size * Vector2(0.92, mid3 - 0.23),
			pr3.position + pr3.size * Vector2(0.92, mid3 + 0.23))
	core.finish_folds()
	scene._rebuild_plane_visual()
	var lift_b: float = float(core.plane_params.lift_area)
	var trim_b: float = float(core.plane_params.trim)
	var basis_b: Transform3D = scene.plane_visual.get_child(1).transform
	_check(absf(lift_b - lift_a) < 1e-6 and trim_b > trim_a and not basis_a.is_equal_approx(basis_b)
		and absf(_wing_x(scene) - 0.55 * clampf(0.72 + lift_b * 0.24, 0.68, 1.35)) < 0.01,
		"C55-3 同 lift 不同 trim（%.2f→%.2f）：上反角基变、翼面不变" % [trim_a, trim_b])

	# C55-4 规则不动：重建不改 plane_params
	var params_before: Dictionary = {
		l = float(core.plane_params.lift_area), t = float(core.plane_params.trim), d = float(core.plane_params.drag_f)}
	scene._rebuild_plane_visual()
	var params_after: Dictionary = {
		l = float(core.plane_params.lift_area), t = float(core.plane_params.trim), d = float(core.plane_params.drag_f)}
	_check(params_after.l == params_before.l and params_after.t == params_before.t and params_after.d == params_before.d,
		"C55-4 重建不改规则参数（%.3f/%.3f/%.3f 原样）" % [params_after.l, params_after.t, params_after.d])

	# C55-5 预览联动：fold 态可见、fly 态隐藏；视窗挂相机、矩形挂 SubViewportTexture
	scene._go_menu()
	core.start_level(0)
	scene._on_level_pressed(0)   # fold 态
	await process_frame
	_check(scene.fold_preview_rect.visible and scene.fold_preview_vp.get_child(0) is Camera3D
		and scene.fold_preview_rect.texture != null,
		"C55-5a fold 态预览可见且挂相机/纹理（headless 为占位纹理）")
	core.finish_folds()
	core.do_throw(30.0, 1.0)
	await process_frame
	_check(String(core.state) == "fly" and not scene.fold_preview_rect.visible,
		"C55-5b fly 态预览隐藏")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c55_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
