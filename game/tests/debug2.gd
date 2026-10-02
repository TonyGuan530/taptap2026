extends SceneTree

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._on_tag(1)
	var last := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 9000:
		await physics_frame
		var el := Time.get_ticks_msec() - t0
		if el - last >= 1000:
			last = el
			var wall := is_instance_valid(scene.get_node_or_null("FragileWall"))
			print("t=%d s  ball=%s  wall=%s  goal=%s  hint=%s" % [el / 1000, str(snapped(scene.ball.position, Vector2(1, 1))), str(wall), str(scene.goal_reached), scene.hint.substr(0, 30)])
	print("FINAL goal_reached=", scene.goal_reached)
	quit()
