extends SceneTree
func _init() -> void:
	_run()
func _run() -> void:
	var s: Control = load("res://demo11_sandbox.tscn").instantiate()
	root.add_child(s)
	await physics_frame
	s.load_room(3)
	await physics_frame
	await physics_frame
	print("state=", s.state, " room=", s.room_idx, " player=", s.player)
	print("objects:")
	for o in s.objects:
		print("  ", o.type, " (", o.x, ",", o.y, ")")
	print("gate_open=", s.gate_open())
	s.move("down")
	s.move("down")
	await physics_frame
	print("after dd: player=", s.player)
	var pulls := 0
	for k in 9:
		var ok: bool = s.use_tool("magnet", "right")
		pulls += 1
		print("pull ", k + 1, " ok=", ok)
		if not ok:
			break
	quit(0)
