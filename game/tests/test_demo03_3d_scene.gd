extends SceneTree
## DEMO3 3D v5 场景表现测试（headless）：风暴之夜视觉辨识（对齐 2D v14）。
## 断言表现层只读模拟状态：紫黑夜空 lerp、环境细雨常驻、酸雨紫主雨窗内开关、
## 经典模式不受影响、退出后回落。运行：
## godot --headless --path game -s res://tests/test_demo03_3d_scene.gd
## 任何 FAIL → 退出码 1。

var failures := 0
var checks := 0
var scene: Node3D


func check(cond: bool, name: String, detail: String = "") -> void:
	checks += 1
	if cond:
		print("PASS  ", name)
	else:
		failures += 1
		print("FAIL  ", name, "  ", detail)


func approx(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func pump(frames: int) -> void:
	for i in frames:
		await process_frame


func fix_acid(t0: float, t1: float) -> void:
	scene.sim.acid_events[0].start = t0
	scene.sim.acid_events[1].start = t1


func bg_dist(c: Color) -> float:
	return cdist(c, Color("2b1738"))


func cdist(a: Color, b: Color) -> float:
	return sqrt(pow(a.r - b.r, 2.0) + pow(a.g - b.g, 2.0) + pow(a.b - b.b, 2.0))


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	await process_frame
	scene = load("res://demo03_3d.tscn").instantiate()
	root.add_child(scene)
	await pump(3)
	var env: Environment = scene.env_node.environment
	check(scene.env_node != null and scene.drizzle != null, "env/drizzle 引用就绪")

	# ---- 1. 经典模式：无细雨、酸雨窗内才主雨、背景保持 ----
	scene._start("classic")
	fix_acid(22.0, 46.0)
	await pump(30)
	check(not scene.rain.emitting and not scene.drizzle.emitting, "经典开局无主雨无细雨")
	check(approx(bg_dist(env.background_color), 0.0, 0.01), "经典背景保持不变")
	scene.sim.elapsed = 23.0
	await pump(2)
	check(scene.rain.emitting, "经典酸雨窗内主雨开启")
	scene.sim.elapsed = 31.0
	await pump(2)
	check(not scene.rain.emitting, "酸雨出窗主雨关闭")

	# ---- 2. 风暴模式：紫黑夜空、细雨常驻、未酸雨无主雨 ----
	scene._start("storm")
	fix_acid(20.0, 46.0)
	await pump(90)
	check(approx(cdist(env.background_color, Color("170b28")), 0.0, 0.05),
			"风暴背景收敛紫黑", str(env.background_color))
	check(scene.drizzle.emitting, "风暴环境细雨常驻")
	check(not scene.rain.emitting, "风暴未酸雨时主雨不亮")

	# ---- 3. 风暴酸雨：主雨+细雨双层叠加（比风暴平时更密）----
	scene.sim.elapsed = 21.0
	await pump(2)
	check(scene.rain.emitting and scene.drizzle.emitting, "风暴酸雨双层叠加")

	# ---- 4. 结束/回菜单：雨全停、背景回落经典 ----
	scene._show_menu()
	await pump(90)
	check(not scene.rain.emitting and not scene.drizzle.emitting, "回菜单双雨全停")
	check(approx(bg_dist(env.background_color), 0.0, 0.05), "回菜单背景回落经典",
			str(env.background_color))

	# ---- 5. 酸雨时刻不受风暴天光影响（sim 层回归锚）----
	scene._start("storm")
	fix_acid(20.0, 46.0)
	scene.sim.elapsed = 21.0
	check(scene.sim.acid_active(), "风暴酸雨窗判定不因表现层改动变化")

	print("==== 3D v5 场景表现测试：checks=%d failures=%d ====" % [checks, failures])
	quit(1 if failures > 0 else 0)
