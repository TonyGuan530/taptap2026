extends SceneTree
## demo-02 v2 验证（headless，time_scale 6x）
## ① L1 皮球（弹簧过墙）② L2 石头（砸穿舱门）
## 结果写入 user://v2log.txt
## 运行：godot --headless --path game -s res://tests/test_demo02_v2.gd

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
	logf = FileAccess.open("user://v2log.txt", FileAccess.WRITE)
	await process_frame
	Engine.time_scale = 6.0
	# ① L1 皮球弹簧过墙
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(0)
	scene._on_tag(2)
	var t0 := Time.get_ticks_msec()
	while not scene.goal_reached and Time.get_ticks_msec() - t0 < 20000:
		await physics_frame
	_log("① L1 皮球过墙: " + ("PASS" if scene.goal_reached else "FAIL"))
	scene.queue_free()
	# ② L2 石头砸舱门
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(1)
	scene._on_tag(1)
	t0 = Time.get_ticks_msec()
	while not scene.goal_reached and Time.get_ticks_msec() - t0 < 20000:
		await physics_frame
	_log("② L2 石头砸舱门: " + ("PASS" if scene.goal_reached else "FAIL"))
	scene.queue_free()
	_log("ALL DONE")
	logf.flush()
	quit()
