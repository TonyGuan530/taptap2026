extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", message)

func _run() -> void:
	check(ResourceLoader.exists("res://v10/ink_world.tscn"),"V10 independent runnable scene exists")
	if failures:
		print("INK_V10_SMOKE_CHECKS=%d FAILURES=%d" % [checks,failures]); quit(1); return
	var world_script = load("res://v10/ink_world.gd")
	check(world_script != null and world_script.can_instantiate(),"V10 world script parses")
	if failures: quit(1); return
	var packed = load("res://v10/ink_world.tscn")
	check(packed != null,"V10 scene parses")
	if failures: quit(1); return
	var game = packed.instantiate()
	root.add_child(game)
	await physics_frame
	await process_frame
	check(game.player is CharacterBody3D and game.draw_pad is Control,"hybrid world keeps 3D player and 2D drawing")
	check(game.goals.size() == 3 and not game.yellow_unlocked,"three black goals precede yellow unlock")
	check(game.intro_open and game.intro_panel.visible,"original portrait introduction is displayed")
	game.begin_adventure()
	check(not game.intro_open,"begin action enters playable chapter")
	var pad = game.draw_pad
	pad.begin_stroke(Vector2(20,30)); pad.append_point(Vector2(100,30)); pad.end_stroke()
	pad.begin_stroke(Vector2(180,60)); pad.append_point(Vector2(220,60)); pad.end_stroke()
	check(pad.get_strokes().size() == 2 and pad.get_strokes()[0][1] == Vector2(100,30),"second stroke is additive and first stroke remains unchanged")
	pad.undo_stroke()
	check(pad.get_strokes().size() == 1,"undo removes only last complete stroke")
	pad.clear_drawing()
	check(pad.get_strokes().is_empty(),"clear is an explicit drawing operation")
	game.selected_kind = "ladder"
	pad.set_strokes(_ladder(60))
	check(game.apply_drawing(),"valid short drawing can be retained as active tool")
	game.player.position = Vector3(2.1,0.62,0)
	await physics_frame
	var before: float = game.ink.black
	var short = game.build_placement(Vector3(3.9,1.25,0))
	check(not short.reachable,"actual short geometry cannot reach the first platform")
	check(not game.place_active(Vector3(3.9,1.25,0)) and game.ink.black == before,"failed placement retains drawing and consumes no ink")
	pad.set_strokes(_ladder(230))
	check(game.apply_drawing(),"longer original ladder is accepted")
	check(game.place_active(Vector3(3.9,1.25,0)),"real ladder reaches existing top support")
	check(game.structures.size() == 1 and game.ink.black < before,"placement records retained geometry and spends black ink")
	check(not game.goals[0],"placing ladder never collects a distant goal")
	var entry: Dictionary = game.structures[0]
	check(entry.climbable and entry.end.distance_to(entry.start) > 3.0,"ladder climb uses actual retained endpoints")
	check(game.try_climb(),"E-equivalent gameplay action enters nearby actual ladder")
	var start: Vector3 = game.player.position
	game.climb_step(0.2,1.0)
	check(game.player.position.y > start.y and not game.goals[0],"climb moves along actual rail before any goal collection")
	check(not game.reclaim_structure(entry.id),"cannot remove ladder while standing on/climbing it")
	for frame in 100:
		if game.climbing_id < 0: break
		game.climb_step(1.0/60.0,1.0)
		await physics_frame
	check(game.climbing_id < 0 and game.player.position.y > 1.80,"actual climb reaches top and exits onto platform support")
	check(not game.support_at(game.player.position-Vector3(0,0.55,0),0.25).is_empty(),"ladder exit has real support under the capsule")
	check(not game.goals[0],"supported exit does not teleport the player to distant page pickup")
	game.player.position = Vector3(-1,0.62,0)
	check(game.reclaim_structure(entry.id) and is_equal_approx(game.ink.black,before),"safe reclaim refunds full paid ink")
	game.player.position = Vector3(1.0,0.62,0)
	game.selected_kind = "board"
	pad.set_strokes([PackedVector2Array([Vector2(30,60),Vector2(330,60),Vector2(330,140),Vector2(30,140),Vector2(30,60)])])
	check(game.apply_drawing() and game.place_active(Vector3(3.9,1.25,0)),"real closed polygon is placed as a walkable inclined board")
	await physics_frame
	var ramp: Dictionary = game.structures[-1]
	var on_ramp: Vector3 = ramp.start+ramp.direction*1.2
	var board_support: Dictionary = game.support_at(on_ramp+Vector3(0,0.3,0),0.6)
	check(not board_support.is_empty() and board_support.collider.name == "ActualDrawnBoard","ray support lands on actual drawn polygon collision")
	game.player.position = ramp.start+Vector3(0,0.68,0)
	await _hold_key(KEY_D,75)
	print("RAMP_DIAGNOSTIC player=",game.player.position," start=",ramp.start," direction=",ramp.direction," held=",Input.is_physical_key_pressed(KEY_D))
	check(game.player.position.x > 3.5 and game.player.position.y > 1.6,"ordinary movement physically walks up the inclined board")
	game.player.position = Vector3(-1,0.62,0)
	await physics_frame
	game.reclaim_structure(ramp.id)
	await physics_frame
	game.player.position = Vector3(2.4,0.62,0)
	game.selected_property = "None"
	game.apply_drawing()
	var steep_plain: Dictionary = game.build_placement(Vector3(3.9,1.25,0))
	check(not steep_plain.ok and steep_plain.reason.contains("坡度"),"ordinary board cannot walkably span a steep short approach")
	game.words.append("Sticky"); game.selected_property = "Sticky"
	game.apply_drawing()
	check(game.place_active(Vector3(3.9,1.25,0)),"same original board with Sticky supports a steeper real ramp")
	if game.structures.is_empty():
		check(false,"Sticky board exists for physical walking check")
	else:
		var sticky: Dictionary = game.structures[-1]
		await physics_frame
		game.player.position = sticky.start+Vector3(-0.5,0.62-sticky.start.y,0)
		await _hold_key(KEY_D,110)
		print("STICKY_DIAGNOSTIC player=",game.player.position," start=",sticky.start," direction=",sticky.direction," floor_angle=",rad_to_deg(game.player.floor_max_angle))
		check(game.player.position.x > 3.5 and game.player.position.y > 1.6,"Sticky changes actual floor traction so steep board can be climbed")
	game.player.position = Vector3(-1,0.62,0)
	await physics_frame
	check(is_equal_approx(game.player.floor_max_angle,deg_to_rad(48)),"leaving Sticky board restores ordinary ground floor angle")
	game.ink.black = 0.0
	game.player.position = game.landmark_positions.fountain+Vector3(0,0.62,0)
	game.interact()
	check(game.ink.black == game.MAX_BLACK_INK,"fountain replenishes ink without a scarce resource")
	for i in 3:
		game.player.position = game.goal_positions[i]+Vector3(0,0.62,0)
		game.collect_goals()
	check(game.goals.all(func(value): return value) and game.yellow_unlocked,"actual player contact collects all goals and unlocks yellow hook")
	check(not game.won and game.result_panel.visible,"black chapter transitions to yellow before final courtyard ending")
	var qa: Dictionary = game.qa_snapshot()
	check(qa.version == 10 and qa.ui.buttons.has("color_yellow") and qa.landmarks.has("tower_goal"),"read-only QA includes camera projections and yellow hooks")
	game.reset_run()
	check(not game.yellow_unlocked and game.structures.is_empty() and game.ink.black == game.MAX_BLACK_INK,"restart restores finite black chapter and ink")
	game.selected_kind = "ladder"; pad.set_strokes(_ladder(270)); game.apply_drawing()
	game.player.position = Vector3(3.2,0.62,4)
	await physics_frame
	var blocked: Dictionary = game.build_placement(Vector3(5,1.25,0))
	print("OBSTRUCTION_DIAGNOSTIC ",blocked)
	check(not blocked.ok and blocked.reason.contains("挡"),"ladder cannot pass through an intervening solid side platform")
	game.reset_run()
	game.player.position = Vector3(37,0.62,0)
	game.selected_kind = "board"
	pad.set_strokes([PackedVector2Array([Vector2(10,70),Vector2(540,70),Vector2(540,130),Vector2(10,130),Vector2(10,70)])])
	check(game.apply_drawing() and game.place_active(Vector3(39,0,0)),"real long flat board can extend past immutable terrain")
	await physics_frame
	game.player.position = Vector3(44.3,0.69,0)
	for frame in 5: await physics_frame
	check(game.player.position.x < 40 and game.safe_point.x < 40,"out-of-bounds board walking restores a valid immutable-ground safety point")
	game.reset_run()
	game.queue_free()
	await process_frame
	print("INK_V10_SMOKE_CHECKS=%d FAILURES=%d" % [checks,failures]); quit(1 if failures else 0)

func _ladder(height: float) -> Array:
	return [PackedVector2Array([Vector2(80,290),Vector2(80,290-height)]),PackedVector2Array([Vector2(145,290),Vector2(145,290-height)]),PackedVector2Array([Vector2(80,290-height*0.3),Vector2(145,290-height*0.3)]),PackedVector2Array([Vector2(80,290-height*0.7),Vector2(145,290-height*0.7)])]

func _hold_key(code: Key, frames: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code; event.keycode = code; event.pressed = true
	Input.parse_input_event(event)
	for frame in frames: await physics_frame
	event.pressed = false; Input.parse_input_event(event)
	await physics_frame
