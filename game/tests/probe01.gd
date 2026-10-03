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
	logf = FileAccess.open("user://p01log.txt", FileAccess.WRITE)
	await process_frame
	Engine.time_scale = 6.0
	scene = load("res://demo01_detective.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._start_case(0)
	_log("state=" + scene.state + " ITEMS=" + str(scene.ITEMS.size()) + " CORRECT=" + str(scene.CORRECT))
	for it in scene.ITEMS:
		scene._collect(it)
	_log("collected=" + str(scene.collected.size()))
	scene._on_accuse()
	_log("accusing=" + str(scene.accusing) + " choices=" + str(scene.CHOICES.size()))
	scene._on_choice(scene.CORRECT)
	_log("after correct: solved=" + str(scene.solved) + " state=" + scene.state)
	_log("done")
	logf.flush()
	quit()
