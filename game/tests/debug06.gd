extends SceneTree

var scene = null

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000:
		await physics_frame

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	Engine.time_scale = 6.0
	scene = load("res://demo06_inkwords.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.shape_idx = 0
	scene.word_idx = 2
	scene._try_place(Vector2(513, 400))
	await _wait(1.5)
	print("fence alive: ", is_instance_valid(scene.get_node_or_null("Fence")))
	scene.keys[KEY_D] = true
	var t0 := Time.get_ticks_msec()
	var last := 0
	while scene.state == "play" and Time.get_ticks_msec() - t0 < 8000:
		await physics_frame
		var el := Time.get_ticks_msec() - t0
		if el - last >= 1500:
			last = el
			var obstacle := []
			for c in scene.get_children():
				if c is RigidBody2D:
					obstacle.append(c.position.x)
			print("t=", el / 1000, " player.x=", scene.player.position.x, " vel.x=", scene.player.velocity.x, " placed=", obstacle)
	print("最终 state=", scene.state)
	quit()
