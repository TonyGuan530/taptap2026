extends SceneTree
## demo-01 三案件验证（headless，time_scale 6x）
## 每案：收集全部线索 → 指认 → 通关；错误指认 → 可重试
## 结果写入 user://c1log.txt
## 运行：godot --headless --path game -s res://tests/test_demo01_cases.gd

var scene = null
var logf: FileAccess

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000:
		await physics_frame

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://c1log.txt", FileAccess.WRITE)
	await process_frame
	Engine.time_scale = 6.0
	var all_pass := true
	for ci in 3:
		scene = load("res://demo01_detective.tscn").instantiate()
		root.add_child(scene)
		await physics_frame
		scene._start_case(ci)
		await _wait(0.3)
		# 收集全部线索
		for it in scene.ITEMS:
			scene._collect(it)
		await _wait(0.2)
		var cnt: int = scene.collected.size()
		var total: int = scene.ITEMS.size()
		# 指认（正确）
		scene._on_accuse()
		scene._on_choice(scene.CORRECT)
		await _wait(0.2)
		var win: bool = scene.solved
		var ok: bool = cnt == total and win
		all_pass = all_pass and ok
		_log("案件" + str(ci + 1) + ": 线索" + str(cnt) + "/" + str(total) + " 通关=" + str(win) + " → " + ("PASS" if ok else "FAIL"))
		scene.queue_free()
	_log("ALL DONE: " + ("PASS" if all_pass else "FAIL"))
	logf.flush()
	quit()
