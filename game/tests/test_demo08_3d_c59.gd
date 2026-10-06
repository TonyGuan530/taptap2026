extends SceneTree
## demo-08 3D 阶段 C59（阶梯②·新商店物品气流计）核心不变量（headless，固定 delta=1/60）：
## 唯一物 3 币：持有后风标签/气流区标签追加精确数值括注（±px/s²），未持有逐位不变（既有断言全兼容）。
## buy() 走默认 owned 分支零改动。池扩至 9 物。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c59.gd（失败退出码非零）

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


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C59 气流计测试开始")

	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	var core: Object = scene.core

	# C59-1 静态锚：池 9 物、气流计入池（3 币唯一）
	var found := false
	for it in core.SHOP_POOL:
		if String(it.id) == "anemo":
			found = true
			_check(int(it.price) == 3 and bool(it.get("unique", false)),
				"C59-1 气流计入池（3 币唯一）")
	_check(found and int(core.SHOP_POOL.size()) == 9, "C59-1b 池 9 物")

	# C59-2 未持有：L22 标签与气流区标签逐位不变（回归）
	core.start_level(21)   # L22 顺风斜风
	var t22_no: String = String(scene.wind_tag_text())
	_check(t22_no == "顺风 恒定推力 ＋ 侧风→",
		"C59-2 未持有 L22 标签不变「%s」" % t22_no)

	# C59-3 持有：L22 侧风带数值；顺风基础风带推力值
	core.owned.append("anemo")
	var t22_yes: String = String(scene.wind_tag_text())
	_check(t22_yes == "顺风 恒定推力（+90px/s²） ＋ 侧风→（+60px/s²）",
		"C59-3a 持有 L22 标签「%s」= 推力与侧风精确值" % t22_yes)

	# C59-4 持有 + 双带关（L33）：气流区括注精确加速度
	core.start_level(32)   # L33 热流之巅
	var t33: String = String(scene.wind_tag_text())
	_check(t33 == "逆风 阻力 x1.25 ＋ 下沉气流 34-44 米（俯冲穿越，-2200px/s²） ＋ 上升气流 46-60 米（乘流爬升，+3200px/s²）",
		"C59-4 持有 L33 标签「%s」= 双带精确加速度" % t33)

	# C59-5 唯一不重现：已购气流计后 20 个种子抽池均不再出现（购后移出不补、唯一不重现）
	var reappear := false
	for k in 20:
		core.rng.seed = 1700 + k
		core.enter_shop()
		for it in core.shop_items:
			if String(it.id) == "anemo":
				reappear = true
	_check(not reappear, "C59-5 唯一物购后 20 种子抽池均不重现")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c59_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
