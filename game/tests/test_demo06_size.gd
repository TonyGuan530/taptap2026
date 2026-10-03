extends SceneTree
## demo-06 v6 SIZE 系统验证（headless，time_scale 6x）
## 小/中/大三档：墨水消耗与碰撞体积统一缩放（评审建议#2）
## 结果写入 user://sizelog.txt
## 运行：godot --headless --path game -s res://tests/test_demo06_size.gd

var scene = null
var logf: FileAccess

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://sizelog.txt", FileAccess.WRITE)
	await process_frame
	scene = load("res://demo06_inkwords.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(0)
	var ok := true
	var ink0: int = scene.ink
	var results := []
	for si in 3:
		scene._load_level(0)
		scene.ink = 200
		scene._on_size(si)
		scene._on_shape(2)   # 方块
		scene._on_word(0)    # Heavy
		var ink_before: int = scene.ink
		var pos := Vector2(150 + si * 40, 380)
		scene._try_place(pos)
		await physics_frame
		var ink_after: int = scene.ink
		var spent: int = ink_before - ink_after
		var body: RigidBody2D = null
		for c in scene.get_children():
			if c is RigidBody2D:
				body = c
		var radius_ok: bool = body != null and absf(body.mass - 8.0 * [0.7, 1.0, 1.5][si]) < 0.5
		results.append("档%d(%s): 花费%d墨水 质量%.1f → %s" % [si + 1, scene.SIZES[si].name, spent, body.mass, "PASS" if spent == int(ceil(40.0 * [0.7, 1.0, 1.5][si])) and radius_ok else "FAIL"])
		if spent != int(ceil(40.0 * [0.7, 1.0, 1.5][si])):
			ok = false
	for r in results:
		_log(r)
	_log("SIZE 系统: " + ("PASS" if ok else "FAIL"))
	_log("ALL DONE")
	logf.flush()
	quit()
