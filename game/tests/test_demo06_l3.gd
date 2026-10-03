extends SceneTree
## demo-06 L3 无属性锁验证（headless，time_scale 6x）
## 解法：方块垫沟 → 跳上方块 → 跳上右台 → GOAL
## 结果写入 user://l3log.txt
## 运行：godot --headless --path game -s res://tests/test_demo06_l3.gd

var scene = null
var logf: FileAccess

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000:
		await physics_frame

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://l3log.txt", FileAccess.WRITE)
	await process_frame
	Engine.time_scale = 6.0
	_log("L3 开始")
	scene = load("res://demo06_inkwords.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(2)
	await _wait(0.5)
	# 方块+Heavy 放进沟里当垫脚
	scene.shape_idx = 2
	scene.word_idx = 0
	scene._try_place(Vector2(450, 480))
	_log("方块已放置进沟")
	await _wait(1.0)
	# 状态机：0=向右走 1=坑里跳上方块 2=方块跳上右台 3=走向 GOAL
	var t0 := Time.get_ticks_msec()
	var phase := 0
	var jump_cd := 0
	var last_log := 0
	while scene.state == "play" and Time.get_ticks_msec() - t0 < 45000:
		await physics_frame
		scene.keys[KEY_D] = true
		jump_cd = maxi(0, jump_cd - 1)
		var px: float = scene.player.position.x
		var py: float = scene.player.position.y
		var el := Time.get_ticks_msec() - t0
		if el - last_log >= 4000:
			last_log = el
			_log("phase=" + str(phase) + " player=(" + str(int(px)) + "," + str(int(py)) + ")")
		match phase:
			0:  # 走向沟，掉进坑里
				if py > 460:
					phase = 1
					_log("已入坑")
			1:  # 坑里：跳上方块（方块顶 460）
				if on_floor_check(scene) and py > 460 and px > 340 and jump_cd == 0:
					scene.keys[KEY_SPACE] = true
					jump_cd = 25
			2:  # 站上方块（y≈444，方块顶 460）→ 跳上右台（400）
				if scene.on_floor and py < 470 and px > 380 and jump_cd == 0:
					scene.keys[KEY_SPACE] = true
					jump_cd = 25
					phase = 3
			3:  # 在右台上走向 GOAL
				pass
	var win: bool = scene.state == "win"
	_log("L3 结果: " + ("PASS: 无属性锁通关（GOAL 只检测玩家进入）" if win else "FAIL: 45秒未通关 player=" + str(scene.player.position)))
	Engine.time_scale = 1.0
	_log("ALL DONE")
	logf.flush()
	quit()

func on_floor_check(s) -> bool:
	return s.on_floor
