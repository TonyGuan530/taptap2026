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
	logf = FileAccess.open("user://p06log.txt", FileAccess.WRITE)
	await process_frame
	Engine.time_scale = 6.0
	scene = load("res://demo06_inkwords.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	_log("loaded")
	scene.keys[KEY_D] = true
	var t0 := Time.get_ticks_msec()
	var last := 0
	while Time.get_ticks_msec() - t0 < 12000:
		await physics_frame
		var el := Time.get_ticks_msec() - t0
		if el - last >= 1000:
			last = el
			_log("t=" + str(el / 1000) + " ball=" + str(snapped(scene.ball.position, Vector2(1, 1))) + " tag=" + str(scene.tag_idx) + " state=" + scene.state)
	_log("done")
	logf.flush()
	quit()
