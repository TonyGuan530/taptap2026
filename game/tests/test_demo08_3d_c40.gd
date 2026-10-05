extends SceneTree
## demo-08 3D 阶段 C40（打磨九·气流区可视化）核心不变量（headless）：
## ① 复盘小图：chart_marks 增 kind="band" 条目（a/len），chart_band_label 短标注（↓/↑+区间）；
## ② 3D 场景：_apply_level_props 增贴地气流色带 WindZone1/2（下沉深蓝/上升暖橙，z=-(x+len/2)）。
## 纯显示层变更，不触碰核心规则；视觉细节待窗口会话（既有 8 张截图基线不含本改动）。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c40.gd（失败退出码非零）

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


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C40 气流区可视化测试开始")

	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame

	# C40-1 小图 marks：L25 双带（谷 -2500@40/12、热流 +3000@54/16），L24 单带，L1 无带
	scene.core.start_level(24)
	var m25: Array = scene.chart_marks()
	var bands25: Array = []
	for m in m25:
		if String(m.kind) == "band":
			bands25.append(m)
	_check(bands25.size() == 2 and float(bands25[0].a) == -2500.0 and float(bands25[0].x) == 40.0
		and float(bands25[0].len) == 12.0 and float(bands25[1].a) == 3000.0 and float(bands25[1].x) == 54.0,
		"C40-1a L25 小图双带标记（谷 -2500@40+12 / 热流 +3000@54+16）")
	scene.core.start_level(23)
	var bands24: Array = []
	for m in scene.chart_marks():
		if String(m.kind) == "band":
			bands24.append(m)
	_check(bands24.size() == 1 and float(bands24[0].a) == -1600.0 and float(bands24[0].x) == 50.0
		and float(bands24[0].len) == 20.0,
		"C40-1b L24 小图单带标记（-1600@50+20）")
	scene.core.start_level(0)
	var bands1: Array = []
	for m in scene.chart_marks():
		if String(m.kind) == "band":
			bands1.append(m)
	_check(bands1.is_empty(), "C40-1c L1 小图无带标记")

	# C40-2 带标注文本：↓/↑+区间；无带/零加速返回空串
	_check(String(scene.chart_band_label(-1600.0, 50.0, 20.0)) == "↓50-70m",
		"C40-2a 下沉带标注「%s」" % String(scene.chart_band_label(-1600.0, 50.0, 20.0)))
	_check(String(scene.chart_band_label(3000.0, 54.0, 16.0)) == "↑54-70m",
		"C40-2b 上升带标注「%s」" % String(scene.chart_band_label(3000.0, 54.0, 16.0)))
	_check(String(scene.chart_band_label(0.0, 50.0, 20.0)) == "" and String(scene.chart_band_label(-1600.0, 0.0, 20.0)) == "",
		"C40-2c 无带/零加速返回空串")

	# C40-3 场景色带：L25 出 WindZone1/2（z=-(x+len/2)）；L1 无色带
	scene.core.unlocked = 24
	scene._on_level_pressed(24)
	for k in 3:
		await process_frame
	var z1: Node = scene.level_props.get_node_or_null("WindZone1")
	var z2: Node = scene.level_props.get_node_or_null("WindZone2")
	_check(z1 != null and z2 != null and absf(float(z1.position.z) + 46.0) < 1e-6
		and absf(float(z2.position.z) + 62.0) < 1e-6,
		"C40-3a L25 场景双色带就位（z=-46 / -62）")
	scene._on_level_pressed(0)
	for k in 3:
		await process_frame
	var z_none: Array = []
	for c in scene.level_props.get_children():
		if String(c.name).begins_with("WindZone"):
			z_none.append(c)
	_check(z_none.is_empty(), "C40-3b L1 场景无色带")

	# C40-4 L24 单色带
	scene._on_level_pressed(23)
	for k in 3:
		await process_frame
	var z24: Array = []
	for c in scene.level_props.get_children():
		if String(c.name).begins_with("WindZone"):
			z24.append(c)
	_check(z24.size() == 1 and absf(float(z24[0].position.z) + 60.0) < 1e-6,
		"C40-4 L24 场景单色带（z=-60）")

	scene.queue_free()
	await process_frame

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c40_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
