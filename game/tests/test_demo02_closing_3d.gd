extends SceneTree
## Real default-view input and progression; no yaw/position/velocity corrections.
var scene: Node3D
var ticks := 60
var mode := "l1"
var fails := 0

func _init() -> void:
	_run()

func _check(label: String, ok: bool) -> void:
	print("%s: %s" % [label, "PASS" if ok else "FAIL"])
	if not ok:
		fails += 1

func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)
	await physics_frame

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ticks="):
			ticks = int(arg.substr(8))
		elif arg.begins_with("--mode="):
			mode = arg.substr(7)
	Engine.physics_ticks_per_second = ticks
	await process_frame
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	if mode == "view":
		_check("L1 waits for the first player action", scene.ball.freeze and not scene.spring_used and scene.elapsed == 0.0)
		_check("Default third-person camera", scene.third_person and scene.camera.global_position.distance_to(scene.ball.global_position) > 2.0)
		var meshes: Array[Node] = scene.ball.find_children("*", "MeshInstance3D", true, false)
		_check("Player ball has visible geometry", not meshes.is_empty())
		var toward_goal: Vector3 = (Vector3(7, 0.65, 0) - scene.camera.global_position).normalized()
		_check("Default camera faces the first goal", (-scene.camera.global_basis.z).dot(toward_goal) > 0.8)
		await _tap("p_pov")
		_check("V switches to first person", not scene.third_person and scene.cam_arm.spring_length == 0.0)
		await _tap("p_pov")
		_check("V returns to third person", scene.third_person and scene.cam_arm.spring_length > 2.0)
	else:
		# Allow 0.3s to read the scene, select the ball and hold W as instructed.
		for frame in int(ticks * 0.3):
			await physics_frame
		await _tap("p_tag2" if mode == "stone" else "p_tag3")
		Input.action_press("p_fwd")
		for frame in ticks * 15:
			await physics_frame
			if scene.goal_reached:
				break
		Input.action_release("p_fwd")
		if mode == "stone":
			_check("L1 stone + W cannot bypass the wall", not scene.goal_reached and scene.spring_used and scene.ball.position.x < 2.6)
		else:
			_check("L1 default camera + 3 then W reaches goal", scene.goal_reached and scene.tel_resets == 0)
		print("L1 ticks=%d elapsed=%.2f pos=%s spring=%s" % [ticks, scene.elapsed, scene.ball.global_position, scene.spring_used])
		if mode == "progress":
			var buttons := scene.find_children("*", "Button", true, false)
			var next: Button = null
			for button in buttons:
				if button.text == "下一关":
					next = button
			_check("L1 victory exposes next-level button", next != null and not next.disabled)
			if next != null and not next.disabled:
				next.pressed.emit()
				await physics_frame
				_check("Next button enters L2", scene.level_idx == 1 and not scene.goal_reached)
	scene.queue_free()
	await process_frame
	print("CLOSING_3D fails=%d" % fails)
	quit(0 if fails == 0 else 1)
