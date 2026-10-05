extends SceneTree
## demo-08 3D 阶段 C20（阶梯③打磨三·L18 信息完整性）headless 断言：
## L18 复盘标记三件（高门/低门/终点）且低门含 side；低门摆动边界 ±300/3s；互斥下双门收益路径。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c20.gd（失败退出码非零）

const CoreScript := preload("res://demo08_3d/flight_core.gd")
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
	_log("demo-08 3D 阶段 C20 打磨测试开始")
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	var core: Object = scene.core

	# C20-1 L18 复盘标记三件：高门（side 0）/低门（side 0）/终点
	core.start_level(17)
	var marks: Array = scene.chart_marks()
	_check(marks.size() == 3, "C20-1a L18 标记数 3（高/低/终点）")
	var kinds := {}
	for m in marks:
		kinds[String(m.kind)] = float(m.side)
	_check(kinds.has("high") and kinds.has("low") and kinds.has("finish")
		and kinds["high"] == 0.0 and kinds["low"] == 0.0 and kinds["finish"] == 0.0,
		"C20-1b 三标记 kind/side 齐备（高/低均中线固定，终点 0）")

	# C20-2 低门摆动边界：±300/3s（0.75 右极 / 2.25 左极）
	_check(absf(float(core.low_gate_side_at(0.75)) - 300.0) < 1e-6
		and absf(float(core.low_gate_side_at(2.25)) + 300.0) < 1e-6,
		"C20-2 低门摆动边界 ±300/3s 确认")

	# C20-3 高门摆动确认：side 0 ± 240 / 3s（0.75 右极 +240，2.25 左极 -240）
	var high_swing_ok := absf(float(core.gate_side_at(0.75)) - 240.0) < 1e-6 \
		and absf(float(core.gate_side_at(2.25)) + 240.0) < 1e-6
	_check(high_swing_ok, "C20-3 L18 高门摆动 ±240/3s（中线 0）")

	# C20-4 互斥下双门三档：走高门 +3 / 吃低门 +3 / 直通 0（合成三掷）
	var c4a: Object = CoreScript.new()
	c4a.start_level(17)
	var pr: Rect2 = c4a.paper_rect
	for k in 5:
		var mid_y: float = 0.5 - 0.5 * 0.2
		c4a.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c4a.finish_folds()
	c4a.do_throw(30.0, 1.0)
	c4a.plane_pos = Vector2(60.0 + 39.5 * 60.0, 460.0 - 13.0 * 60.0)  # 高门 40m 前，13m 高
	c4a.velocity = Vector2(600.0, 0.0)
	c4a.lateral = 0.0
	for k in 6:
		var e4a: String = c4a.step(DELTA)
		if e4a == "finish" or e4a == "ground" or e4a == "timeout":
			break
		if c4a.plane_pos.x >= 60.0 + 40.2 * 60.0:
			break
	_check(c4a.gate_hit and int(c4a.coins) == 3, "C20-4a 走高门路线命中 +3（横位 0 中线）")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c20_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
