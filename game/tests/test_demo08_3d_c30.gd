extends SceneTree
## demo-08 3D 阶段 C30（阶梯③打磨六·可发现性与时长分析）headless 断言：
## 选关提示自动轮播（仅在菜单态轮播已解锁关卡）；飞行提示按关卡机制定制；
## 全 18 关飞行时长合计（分析数据，不作硬断言）。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c30.gd（失败退出码非零）

const CoreScript = preload("res://demo08_3d/flight_core.gd")
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


func _good_folds(c: Object, n: int) -> void:
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.08 + 0.06 * float(k)
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.46))


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C30 打磨测试开始")
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame

	# C30-1 轮播函数：菜单态轮播已解锁关卡 tip
	scene.core.start_level(0)
	scene._go_menu()
	scene.core.unlocked = 2  # 轮播池 = L0/L1/L2 三条 tip（须在 go_menu 重置后设置）
	var tip0: String = String(scene.menu_tip.text)
	scene._on_menu_tip_rotate()
	var tip1: String = String(scene.menu_tip.text)
	_check(tip1 != tip0 and tip1 == String(scene.core.LEVELS[1].tip),
		"C30-1 轮播推进到下一解锁关 tip（[%s]→[%s]）" % [tip0, tip1])
	# 未解锁关卡不进入轮播：连续轮播 20 次均在已解锁范围
	var ok_unlocked := true
	for k in 20:
		scene._on_menu_tip_rotate()
		var hit := false
		for i in int(scene.core.unlocked) + 1:
			if String(scene.core.LEVELS[i].tip) == String(scene.menu_tip.text):
				hit = true
		if not hit:
			ok_unlocked = false
	_check(ok_unlocked, "C30-2 轮播 20 次均在已解锁关卡范围内（unlocked=%d）" % int(scene.core.unlocked))

	# C30-3 飞行提示按关卡机制定制：L1 无机制基础文案 / L11 摆门 / L16 侧风+摆门 / L9 侧风
	var hints := {}
	for lvl in [0, 10, 15, 8]:
		scene.core.start_level(lvl)
		var pr: Rect2 = scene._paper_rect()
		for k in 4:
			var mid_y: float = 0.08 + 0.06 * float(k)
			scene.core.add_fold(pr.position + pr.size * Vector2(0.92, mid_y),
				pr.position + pr.size * Vector2(0.92, mid_y + 0.46))
		scene.core.finish_folds()
		scene.core.do_throw(30.0, 1.0)
		await process_frame
		hints[lvl] = String(scene.hint_label.text)
	_check(not hints[0].contains("门在摆动") and hints[10].contains("门在摆动"),
		"C30-3a 飞行提示按关卡定制：L1 无摆门提示 / L11 含摆门提示")
	_check(hints[15].contains("侧风会带偏航向") and not hints[0].contains("侧风会带偏航向"),
		"C30-3b 侧风关提示含带偏提醒（L16 有 / L1 无）")

	# C30-4 全 18 关飞行时长合计（分析数据）：配方表逐关直驱
	var total_t := 0.0
	var recipe := {0: [2, 30.0], 1: [4, 42.0], 2: [5, 35.0], 3: [4, 35.0], 4: [6, 45.0],
		5: [4, 30.0], 6: [5, 30.0], 7: [5, 30.0], 8: [5, 30.0], 9: [5, 30.0], 10: [5, 35.0],
		11: [5, 35.0], 12: [5, 30.0], 13: [5, 30.0], 14: [6, 30.0], 15: [5, 30.0],
		16: [5, 30.0], 17: [6, 30.0]}
	for i in 18:
		var c: Object = CoreScript.new()
		c.start_level(i)
		var rr: Array = recipe[i]
		var v: float = 0.2
		if rr.size() > 5:
			v = float(rr[5])
		var pru: Rect2 = c.paper_rect
		for k in int(rr[0]):
			var mid_y: float = 0.5 - 0.5 * v
			c.add_fold(pru.position + pru.size * Vector2(0.92, mid_y - 0.23),
				pru.position + pru.size * Vector2(0.92, mid_y + 0.23))
		c.finish_folds()
		c.do_throw(float(rr[1]), 1.0)
		var g := 0
		while String(c.state) == "fly" and g < MAX_STEPS:
			c.step(DELTA)
			g += 1
		total_t += float(c.flight_time)
	_log("  [时长分析] 全 18 关配方飞行合计 %.1f 秒（不含折纸/结算/商店操作时间）" % total_t)
	_check(total_t > 60.0, "C30-4 全 18 关飞行合计 %.0f 秒（数据点，供难度曲线评审）" % total_t)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c30_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
