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
	logf = FileAccess.open("user://pL3clog.txt", FileAccess.WRITE)
	await process_frame
	Engine.time_scale = 6.0
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(2)
	await physics_frame
	_log("LEVELS[2] = " + JSON.stringify(scene.LEVELS[2]).substr(0, 400))
	_log("walls 数: " + str(scene.LEVELS[2].walls.size()))
	_log("fragile: " + str(scene.LEVELS[2].fragile))
	_log("goal: " + str(scene.LEVELS[2].goal))
	var t0 := Time.get_ticks_msec()
	var last := 0
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame
		pcount += 1
	_log("6秒: process=" + str(pcount))
	logf.flush()
	quit()
