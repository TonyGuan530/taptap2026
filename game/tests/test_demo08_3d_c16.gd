extends SceneTree
## demo-08 3D 阶段 C16（阶梯③打磨·信息完整性）headless 断言：
## wind_tag_text 覆盖全部风型；侧风关结算面板补横移行。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c16.gd（失败退出码非零）

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


func _tag_of(level: int) -> String:
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(level)
	var tag: String = String(scene.wind_tag_text())
	scene.queue_free()
	await process_frame
	return tag


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C16 打磨测试开始")

	# C16-1 风标签覆盖全部风型
	var t2: String = await _tag_of(1)
	_check(t2 == "逆风 阻力 x1.25", "C16-1a L2 逆风标签：[%s]" % t2)
	var t6: String = await _tag_of(5)
	_check(t6.contains("侧风") and t6.contains("A/D 顶风") and not t6.contains("切变"),
		"C16-1b L6 侧风标签：[%s]" % t6)
	var t8: String = await _tag_of(7)
	_check(t8.contains("风切变 40m") and t8.contains("→ →"), "C16-1c L8 单切变标签：[%s]" % t8)
	var t10: String = await _tag_of(9)
	_check(t10.contains("双段切变 30/50m") and t10.contains("→→←") or t10.contains("双段切变 30/50m"),
		"C16-1d L10 双段切变标签：[%s]" % t10)
	var t9: String = await _tag_of(8)
	_check(t9.contains("逆风") and t9.contains("侧风←"), "C16-1e L9 正交侧风标签：[%s]" % t9)

	# C16-2 侧风关结算面板补横移行（借 C11 配方：L12 顶右风 0.8s → 横移 +5.2m 左右）
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	var core: Object = scene.core
	core.start_level(11)
	var pr: Rect2 = scene._paper_rect()
	for k in 5:
		var mid_y: float = 0.5 - 0.5 * 0.35
		core.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	core.finish_folds()
	core.do_throw(35.0, 1.0)
	await process_frame  # 让场景观察 fold→fly 迁移（否则结算不触发面板重建）
	var g := 0
	while String(core.state) == "fly" and g < 1800:
		core.step(1.0 / 60.0)
		g += 1
	await process_frame
	var st: String = String(scene.settle_body.text)
	_check(st.contains("横移 +"), "C16-2 侧风关结算面板含横移行：[横移 %+.1f]" % (float(core.lateral) / 60.0))

	# C16-3 无横向风关卡结算不含横移行
	core.start_level(0)
	for k in 2:
		var mid_y0: float = 0.08 + 0.06 * float(k)
		core.add_fold(scene._paper_rect().position + scene._paper_rect().size * Vector2(0.92, mid_y0),
			scene._paper_rect().position + scene._paper_rect().size * Vector2(0.92, mid_y0 + 0.46))
	core.finish_folds()
	core.do_throw(30.0, 1.0)
	await process_frame  # 同上：让 fly 态被场景观察
	g = 0
	while String(core.state) == "fly" and g < 1800:
		core.step(1.0 / 60.0)
		g += 1
	await process_frame
	var st0: String = String(scene.settle_body.text)
	_log("  [诊断2] level_idx=%d state=%s prev=%s panel_vis=%s title=[%s]" % [int(core.level_idx), str(core.state), str(scene.prev_state), str(scene.settle_panel.visible), str(scene.settle_title.text)])
	_log("  [诊断] st0=[%s]" % st0)
	_check(not st0.contains("横移"), "C16-3 无横向风结算不含横移行")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c16_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
