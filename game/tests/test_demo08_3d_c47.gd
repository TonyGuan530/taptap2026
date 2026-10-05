extends SceneTree
## demo-08 3D 阶段 C47（打磨十一·飞行中气流区实时指示）核心不变量（headless）：
## fly_zone_text：当前位置在带内返回「 · 谷中↓」/「 · 热流中↑」，带外空串——与判定共用 updraft_accel。
## 纯显示层，不触碰核心规则。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c47.gd（失败退出码非零）

const DELTA := 1.0 / 60.0
const MAX_STEPS := 2000

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
	_log("demo-08 3D 阶段 C47 气流区实时指示测试开始")

	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	var core: Object = scene.core

	# C47-1 L24 单谷：谷前空 / 谷中「谷中↓」/ 谷后空
	core.start_level(23)
	core.plane_pos.x = 60.0 + 35.0 * 60.0
	var t_out1: String = String(scene.fly_zone_text())
	core.plane_pos.x = 60.0 + 55.0 * 60.0
	var t_in: String = String(scene.fly_zone_text())
	core.plane_pos.x = 60.0 + 72.0 * 60.0
	var t_out2: String = String(scene.fly_zone_text())
	_check(t_out1 == "" and t_in == " · 谷中↓" and t_out2 == "",
		"C47-1 L24 区带三态：谷前空 / 谷中「%s」/ 谷后空" % t_in)

	# C47-2 L25 双带：谷中「谷中↓」/ 热流中「热流中↑」
	core.start_level(24)
	core.plane_pos.x = 60.0 + 45.0 * 60.0
	var t_sink: String = String(scene.fly_zone_text())
	core.plane_pos.x = 60.0 + 60.0 * 60.0
	var t_therm: String = String(scene.fly_zone_text())
	_check(t_sink == " · 谷中↓" and t_therm == " · 热流中↑",
		"C47-2 L25 双带：谷中「%s」/ 热流中「%s」" % [t_sink, t_therm])

	# C47-3 L1 无带恒空
	core.start_level(0)
	core.plane_pos.x = 60.0 + 55.0 * 60.0
	_check(String(scene.fly_zone_text()) == "", "C47-3 L1 无带恒空")

	# C47-4 全掷过程指示联动：L26 低线飞完全程，轨迹中谷段指示非空（借 trail 抽点验证带函数一致）
	core.start_level(25)
	var pr: Rect2 = core.paper_rect
	for k in 4:
		var mid_y: float = 0.5 - 0.5 * 0.35
		core.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	core.finish_folds()
	core.do_throw(30.0, 1.0)
	var g := 0
	var saw_zone := false
	while String(core.state) == "fly" and g < MAX_STEPS:
		core.step(DELTA)
		if String(scene.fly_zone_text()) != "":
			saw_zone = true
		g += 1
	_check(core.last_pass and saw_zone,
		"C47-4 L26 高线全程经过气流区（实时指示曾出现，%.1fm 过关）" % core.flight_distance)

	scene.queue_free()
	await process_frame

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c47_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
