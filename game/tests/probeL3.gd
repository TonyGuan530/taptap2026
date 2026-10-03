extends SceneTree

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
	logf = FileAccess.open("user://pL3log.txt", FileAccess.WRITE)
	await process_frame
	Engine.time_scale = 6.0
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(2)
	await physics_frame
	_log("L3 loaded, ball=" + str(scene.ball.position))
	scene.keys[KEY_D] = true
	var t0 := Time.get_ticks_msec()
	var last := 0
	while Time.get_ticks_msec() - t0 < 8000:
		await physics_frame
		var el := Time.get_ticks_msec() - t0
		if el - last >= 1000:
			last = el
			_log("t=" + str(el / 1000) + " ball.x=" + str(int(scene.ball.position.x)) + " y=" + str(int(scene.ball.position.y)))
	_log("probe done")
	logf.flush()
	quit()
