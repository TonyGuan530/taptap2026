extends SceneTree

var scene = null
var logf: FileAccess
var phcount := 0

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://pL3dlog.txt", FileAccess.WRITE)
	await process_frame
	Engine.time_scale = 6.0
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	# --- 数 L1 的物理帧 ---
	scene._load_level(0)
	phcount = 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await physics_frame
		phcount += 1
	_log("L1 物理帧/3s = " + str(phcount))
	# --- 切 L3 再数 ---
	scene._load_level(2)
	phcount = 0
	t0 = Time.get_ticks_msec()
	var once := false
	while Time.get_ticks_msec() - t0 < 3000:
		await physics_frame
		phcount += 1
		if not once:
			once = true
			_log("L3 第一个物理帧到达")
	_log("L3 物理帧/3s = " + str(phcount))
	logf.flush()
	quit()
