extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ",message)

func touch(index: int, point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index; event.position = point; event.pressed = pressed; event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index; event.position = point
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func frames(count: int) -> void:
	for i in count: await physics_frame

func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT; event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = point; event.global_position = point; event.pressed = pressed
	Input.parse_input_event(event); Input.flush_buffered_events()

func _run() -> void:
	root.size = Vector2i(960,540)
	var game = load("res://v10/ink_world.tscn").instantiate()
	root.add_child(game); await frames(3)
	for child in game.intro_panel.get_children():
		if child is TextureRect: check(child.size.x<=260 and child.size.y<=300,"portrait remains inside its introduction column")
	game.begin_adventure()
	var controls = game.get("touch_controls")
	check(controls != null,"world has a touch controller using the existing gameplay actions")
	if controls == null: quit(1); return
	controls.set_touch_enabled(true); await frames(3)
	check(controls.visible,"touch controls are visible during play")
	var centre: Vector2 = controls.joystick_center()
	var before: Vector3 = game.player.position
	touch(0,centre,true); drag(0,centre+Vector2(60,0)); await frames(15)
	check(game.player.position.x > before.x+0.30,"held touch joystick moves the actual physics body")
	check(absf(game.player.position.z-before.z)<0.1,"horizontal joystick does not drift vertically")
	var jump: Vector2 = controls.action_rect("jump").get_center()
	touch(1,jump,true); touch(1,jump,false); await frames(5)
	check(game.player.position.y > 0.8,"second finger jumps while the movement finger remains held")
	check(controls.axis.x > 0.8,"action finger release does not release joystick ownership")
	touch(0,centre,false); await frames(3)
	check(controls.axis == Vector2.ZERO,"lifting the joystick finger stops movement")
	touch(2,centre,true); drag(2,centre+Vector2(0,-60)); await frames(1)
	check(controls.axis.y < -0.8,"upward joystick supplies the climb-up direction")
	touch(2,centre,false,true); await frames(2)
	check(controls.axis == Vector2.ZERO,"touch cancellation releases held input")
	touch(3,centre,true); drag(3,centre+Vector2(60,0)); game.toggle_notebook(); await frames(2)
	check(controls.axis == Vector2.ZERO and not controls.visible,"opening drawing paper hides controls and clears movement")
	game.draw_pad.clear_drawing()
	var start: Vector2 = game.draw_pad.get_global_rect().position+Vector2(40,40)
	touch(5,start,true); drag(5,start+Vector2(100,0)); await frames(1)
	touch(6,start+Vector2(0,100),true); drag(6,start+Vector2(100,100)); touch(6,start+Vector2(100,100),false)
	mouse(start+Vector2(200,100),true); mouse(start+Vector2(200,100),false)
	drag(5,start+Vector2(160,0)); touch(5,start+Vector2(160,0),false); await frames(2)
	var strokes: Array = game.draw_pad.get_strokes()
	check(strokes.size() == 1 and strokes[0].size()>=3,"one drawing finger retains one actual stroke")
	check(strokes.size() == 1 and strokes[0][-1].distance_to(Vector2(200,40))<0.1,"second finger cannot append or end the first finger's stroke")
	touch(7,start+Vector2(0,100),true); drag(7,start+Vector2(160,100)); touch(7,start+Vector2(160,100),false); await frames(2)
	check(game.draw_pad.get_strokes().size() == 2,"lifting the finger separates the next pen stroke")
	touch(8,start,true); drag(8,start+Vector2(800,0)); touch(8,start+Vector2(800,0),false); await frames(2)
	check(not game.draw_pad.drawing,"release outside the drawing pad ends the owned stroke")
	var previous_strokes: int = game.draw_pad.get_strokes().size()
	touch(11,Vector2(840,75),true); touch(11,Vector2(840,75),false); await frames(2)
	check(game.notebook_open and game.draw_pad.get_strokes().size()==previous_strokes,"paper blocks the covered restart button and preserves the run")
	if not game.notebook_open: game.toggle_notebook()
	game.toggle_notebook(); await frames(2)
	check(controls.visible and controls.axis == Vector2.ZERO,"closing the paper restores neutral touch controls")
	touch(9,centre,true); drag(9,centre+Vector2(60,0)); await frames(2)
	controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT); await frames(2)
	check(controls.axis == Vector2.ZERO,"lost focus can clear all held fingers")
	game.selected_kind = "ladder"
	game.draw_pad.set_strokes([PackedVector2Array([Vector2(20,30),Vector2(20,260)]),PackedVector2Array([Vector2(85,30),Vector2(85,260)]),PackedVector2Array([Vector2(20,90),Vector2(85,90)]),PackedVector2Array([Vector2(20,190),Vector2(85,190)])])
	check(game.apply_drawing() and game.active_tool.length>3,"accidental placement regression has a valid retained building tool")
	touch(12,controls.action_rect("interact").get_center(),true); touch(12,controls.action_rect("interact").get_center(),false)
	touch(13,centre,true); drag(13,centre+Vector2(25,0)); touch(13,centre,false); await frames(2)
	check(game.structures.is_empty(),"touching controls with a valid tool never places accidental world structures")
	game.player.position = Vector3(2.1,0.6,0); game.player.velocity = Vector3.ZERO
	game.place_active(Vector3(5.1,1.25,0)); game.try_climb()
	touch(15,centre,true); drag(15,centre+Vector2(0,-60))
	game.climb_step(2.0,1.0)
	var landed: Vector3 = game.player.position
	await frames(15)
	check(game.climbing_id<0 and game.player.position.distance_to(landed)<0.12,"reaching the ladder top neutralizes held climb input before it walks off the landing")
	touch(15,centre,false)
	print("INK_V10_TOUCH_CHECKS=%d FAILURES=%d" % [checks,failures])
	game.queue_free(); await process_frame; quit(1 if failures else 0)
