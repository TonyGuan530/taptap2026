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
	logf = FileAccess.open("user://pL3blog.txt", FileAccess.WRITE)
	await process_frame
	Engine.time_scale = 6.0
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(2)
	await physics_frame
	_log("L3 loaded")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame
		pcount += 1
	_log("6秒: process帧=" + str(pcount) + " ball=" + str(scene.ball.position))
	logf.flush()
	quit()
