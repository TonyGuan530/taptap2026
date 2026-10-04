extends SceneTree
## DEMO6 3D 遥测测试：sid/start/select（真实按键）/placement_attempt+place/rejected/reset/goal+ghost 终位/JSON 落盘。
## 运行：godot --headless --path <game> --fixed-fps 60 -s res://tests/test_demo06_3d_telemetry.gd

func _initialize() -> void:
	_run()


func _run() -> void:
	var fails := 0
	var game: Node3D = load("res://demo06_3d.tscn").instantiate()
	root.add_child(game)
	game.scripted = true
	for i in 30:
		await physics_frame
	if String(game.tel_sid).is_empty():
		fails += 1
		print("TEL FAIL: sid empty")
	if not _has(game.tel_events, "start"):
		fails += 1
		print("TEL FAIL: no start")
	# select（真实按键事件走 unhandled_input；KEY_1=ball / KEY_5=float）
	_key(KEY_1)
	_key(KEY_5)
	for i in 5:
		await physics_frame
	if not _has(game.tel_events, "select", "shape", "ball"):
		fails += 1
		print("TEL FAIL: select shape missing")
	if not _has(game.tel_events, "select", "tag", "float"):
		fails += 1
		print("TEL FAIL: select tag missing")
	# place + attempt
	if not game.place_blueprint(1, 1, Vector3(3.95, 1.46, 0)):
		fails += 1
		print("TEL FAIL: placement rejected unexpectedly")
	for i in 5:
		await physics_frame
	if not _has(game.tel_events, "placement_attempt"):
		fails += 1
		print("TEL FAIL: placement_attempt missing")
	if not _has(game.tel_events, "place"):
		fails += 1
		print("TEL FAIL: place missing")
	# rejected（地形内放置）
	if game.try_place_validated(Vector3(0.7, 0.6, 0), 0.0):
		fails += 1
		print("TEL FAIL: blocked placement succeeded")
	if not _has(game.tel_events, "placement_rejected", "why", "blocked"):
		fails += 1
		print("TEL FAIL: placement_rejected missing")
	# reset（R 键）
	_key(KEY_R)
	for i in 5:
		await physics_frame
	if not _has(game.tel_events, "reset", "why", "R"):
		fails += 1
		print("TEL FAIL: reset missing")
	# goal：传送玩家进 GOAL 判定盒
	game.player.position = game.LEVELS[2].goal
	game.player.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	var goal := false
	var send := false
	var ghost := false
	for ev in game.tel_events:
		if ev.type == "goal":
			goal = true
			ghost = ev.has("ghost_pos") and ev.has("ghost_yaw") and ev.has("place_dist")
		if ev.type == "session_end" and ev.get("end_reason") == "goal":
			send = true
	if not goal:
		fails += 1
		print("TEL FAIL: goal missing")
	if not send:
		fails += 1
		print("TEL FAIL: session_end(goal) missing")
	if not ghost:
		fails += 1
		print("TEL FAIL: ghost final transform missing")
	# JSON 落盘
	var path: String = game._tel_path()
	if not FileAccess.file_exists(path):
		fails += 1
		print("TEL FAIL: file missing ", path)
	else:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed == null or not parsed.has("events"):
			fails += 1
			print("TEL FAIL: file json invalid")
	print("TELEMETRY RESULT: %s (events=%d)" % ["PASS" if fails == 0 else "FAIL", game.tel_events.size()])
	quit(0 if fails == 0 else 1)


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)


func _has(events: Array, type: String, key = null, val = null) -> bool:
	for ev in events:
		if ev.type != type:
			continue
		if key == null or ev.get(key) == val:
			return true
	return false
