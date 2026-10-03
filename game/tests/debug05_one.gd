extends SceneTree
func _init() -> void:
	_run()
func _idx(scene, id: String) -> int:
	for i in scene.TILES.size():
		if scene.TILES[i].id == id:
			return i
	return 0
func _run() -> void:
	await process_frame
	var scene: Control = load("res://demo05_volcano.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	scene.gather = 7
	for k in 7:
		scene._on_tile_click(_idx(scene, "cave"))
		print("click ", k + 1, " gather=", scene.gather, " cave=", JSON.stringify(scene.stored.cave))
	print("final stored=", JSON.stringify(scene.stored.cave), " invested_ok")
	quit()
