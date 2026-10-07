extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._on_level_pressed(0,true)
	var meshes = scene.plane_visual.find_children("*", "MeshInstance3D", true, false)
	var paper_mesh := false
	var boxes := 0
	for mesh in meshes:
		if mesh.mesh is ArrayMesh:
			paper_mesh = true
		if mesh.mesh is BoxMesh:
			boxes += 1
	if not paper_mesh or boxes > 0:
		print("FAIL: folding must move a paper ArrayMesh, not resize boxes")
		quit(1)
		return
	print("PASS: paper mesh replaces boxes")
	scene._on_dart()
	for frame in 300: await process_frame
	if scene.paper.history.size()!=5 or not scene.dart_queue.is_empty():
		print("FAIL: demonstrated folds did not finish")
		quit(1)
		return
	print("PASS: five sequential paper folds animate")
	scene._on_undo_fold()
	if scene.paper.history.size()!=4 or not scene.paper.is_flat():
		print("FAIL: undo must restore editable flat stack")
		quit(1)
		return
	print("PASS: undo restores editable sheet")
	var final_fold: Dictionary = scene.paper.dart_recipe().back()
	scene._record_fold(final_fold.a,final_fold.b,float(final_fold.angle))
	for frame in 60: await process_frame
	scene._on_fold_done()
	scene.charging = true
	scene.charge = 1.0
	scene._release_throw()
	if scene.core.physical_flight == null:
		print("FAIL: launched model must use 3D aerodynamic state")
		quit(1)
		return
	for frame in 900:
		await process_frame
		if scene.core.state == "settle": break
	if scene.core.state != "settle" or scene.core.flight_distance <= 1.0:
		print("FAIL: flight must land and report measured distance")
		quit(1)
		return
	print("PASS: physical flight lands %.2fm" % scene.core.flight_distance)
	scene._on_settle_continue()
	if scene.paper.history.size()!=5 or scene.core.state!="fold":
		print("FAIL: returning from trial must preserve the plane for undo")
		quit(1)
		return
	scene._on_undo_fold()
	if scene.paper.history.size()!=4 or not scene.paper.is_flat():
		print("FAIL: flown plane must remain editable after undo")
		quit(1)
		return
	print("PASS: trial preserves folded plane for editing")
	scene._on_fold_done()
	scene.charging = true
	scene.charge = 1.0
	scene._release_throw()
	var steering_key := InputEventKey.new()
	steering_key.keycode = KEY_D
	steering_key.pressed = true
	scene._unhandled_input(steering_key)
	scene._go_menu()
	steering_key.pressed = false
	scene._unhandled_input(steering_key)
	scene._on_level_pressed(0,true)
	scene._on_fold_done()
	scene.charging = true
	scene.charge = 1.0
	scene._release_throw()
	if scene.core.lateral_input!=0.0 or scene.core.dive_input:
		print("FAIL: steering held across menu leaked into a new launch")
		quit(1)
		return
	print("PASS: steering held across menu does not leak into the next launch")
	scene.queue_free()
	await process_frame
	quit(0)
