extends SceneTree
## L3 player route, with delayed steering. No position/velocity injection.
var scene: Node2D

func _init() -> void:
	_run()

func _until(predicate: Callable, frames: int) -> bool:
	for frame in frames:
		await physics_frame
		if predicate.call():
			return true
	return false

func _run() -> void:
	await process_frame
	Engine.physics_ticks_per_second = 60
	var delay := 0.3
	var mode := "route"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--delay="):
			delay = float(arg.substr(8))
		elif arg.begins_with("--mode="):
			mode = arg.substr(7)
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	if mode == "ui":
		scene._load_level(1)
		scene._on_tag(1)
		var won_previous := await _until(func(): return scene.goal_reached, 600)
		scene._next_level()
		await physics_frame
		var cleared: bool = won_previous and scene.level_idx == 2 and not scene.goal_reached and scene.next_b.disabled and not scene.msg_label.text.contains("通关")
		print("2D next-level clears stale victory: %s" % ["PASS" if cleared else "FAIL"])
		scene.queue_free()
		await process_frame
		quit(0 if cleared else 1)
		return
	scene._load_level(2)
	scene._on_tag(0)
	var launched := await _until(func(): return scene.ball.linear_velocity.y < -400.0, 1200)
	var apex := launched and await _until(func(): return scene.ball.linear_velocity.y > 0.0, 900)
	# A player reacts after the apex, then steers and flaps once.
	for frame in int(60 * delay):
		await physics_frame
	Input.action_press("ui_right")
	var aligned := false
	for frame in 900:
		await physics_frame
		if scene.ball.linear_velocity.y > 80.0 and not scene.flap_used:
			scene._try_jump()
		if scene.ball.position.x >= 640.0 and scene.ball.position.y < 220.0:
			aligned = true
			break
		if scene.tel_resets > 0:
			break
	Input.action_release("ui_right")
	if aligned:
		# Change the tag without leaving the movement keys to click a HUD button.
		var key := InputEventKey.new()
		key.keycode = KEY_2
		key.physical_keycode = KEY_2
		key.pressed = true
		Input.parse_input_event(key)
		await process_frame
		key = key.duplicate()
		key.pressed = false
		Input.parse_input_event(key)
	var won := aligned and await _until(func(): return scene.goal_reached, 600)
	var broken := scene.get_node_or_null("FragileWall") == null
	var ok: bool = launched and apex and won and broken and scene.tag_idx == 1 and scene.tel_resets == 0
	print("L3 delayed steering + one flap + stone: %s launched=%s aligned=%s broken=%s resets=%d pos=%s" % ["PASS" if ok else "FAIL", launched, aligned, broken, scene.tel_resets, scene.ball.position])
	scene.queue_free()
	await process_frame
	quit(0 if ok else 1)
