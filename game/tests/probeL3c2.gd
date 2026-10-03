extends SceneTree

var scene = null
var logf: FileAccess
var pcount := 0
var phcount := 0

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://pL3c2log.txt", FileAccess.WRITE)
	await process_frame
	scene = load("res://demo06_inkwords.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(2)
	await physics_frame
	_log("L3 loaded")
	var t0 := Time.get_ticks_msec()
	var last := 0
	while Time.get_ticks_msec() - t0 < 8000:
		await process_frame
		pcount += 1
		var el := Time.get_ticks_msec() - t0
		if el - last >= 2000:
			last = el
			_log("p=" + str(pcount) + " ball=" + str(scene.ball.position))
	_log("8秒 process 总帧: " + str(pcount))
	logf.flush()
	quit()
