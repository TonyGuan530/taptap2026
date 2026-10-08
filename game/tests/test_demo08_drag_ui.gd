extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func click(scene, pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT; event.position=pos; event.pressed=true
	scene._unhandled_input(event)
	event.pressed=false; scene._unhandled_input(event)
func screen(scene, point: Vector3) -> Vector2:
	return scene.fold_preview_rect.position+scene.fold_preview_cam.unproject_position(point*3.5)
func center(poly: PackedVector3Array) -> Vector3:
	var sum := Vector3.ZERO
	for p in poly: sum+=p
	return sum/poly.size()
func drag(scene, angle: float) -> void:
	var action: Dictionary = scene.paper.history.back()
	var fi: int = action.moves.find(true)
	var grab: Vector3 = center(scene.paper.faces[fi])
	var pos := screen(scene,grab)
	var press := InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=pos
	scene._unhandled_input(press)
	check(scene.fold_dragging,"actual 3D paper click starts dragging")
	var picked: Dictionary = scene._hit_paper_at(pos)
	if not picked.is_empty(): grab=picked.point
	var target: Vector3 = action.origin+Basis(action.axis,angle-float(action.angle))*(grab-action.origin)
	var motion := InputEventMouseMotion.new()
	motion.position=screen(scene,target); motion.relative=motion.position-pos
	print("DRAG_COORDS grab=%s target=%s" % [pos,motion.position])
	scene._unhandled_input(motion)
	press.pressed=false; press.position=motion.position; scene._unhandled_input(press)
	check(absf(float(scene.paper.history.back().angle)-angle)<0.04,"mouse ray drag preserves requested partial angle")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for frame in 3: await process_frame
	click(scene,screen(scene,Vector3(0,0,-0.12)))
	click(scene,screen(scene,Vector3(0,0,0.12)))
	check(scene.paper.history.size()==1 and scene.paper.is_flat(),"two real 3D clicks create an unfolded hinge")
	if scene.paper.history.is_empty(): quit(1); return
	drag(scene,PI/3)
	check(not scene.paper.is_flat() and not scene.fold_dragging,"release keeps the paper standing")
	var fi: int = scene.paper.history.back().moves.find(true)
	var face: PackedVector3Array = scene.paper.faces[fi]
	var midpoint := center(face)
	print("CREASE_COORDS a=%s b=%s" % [screen(scene,face[0].lerp(face[1],0.5).lerp(midpoint,0.1)),screen(scene,face[2].lerp(face[3],0.5).lerp(midpoint,0.1))])
	scene.crease_btn.pressed.emit()
	click(scene,screen(scene,face[0].lerp(face[1],0.5).lerp(midpoint,0.1)))
	click(scene,screen(scene,face[2].lerp(face[3],0.5).lerp(midpoint,0.1)))
	check(scene.paper.history.size()==2,"another crease can be drawn directly on standing paper")
	if scene.paper.history.size()==2: drag(scene,-PI/4)
	scene.undo_btn.pressed.emit()
	check(scene.paper.history.size()==1 and not scene.paper.is_flat(),"undo preserves the first partial fold")
	var action: Dictionary = scene.paper.history.back()
	var flap: int = action.moves.find(true)
	var grab: Vector3 = center(scene.paper.faces[flap])
	scene._start_fold_drag({face=flap,point=grab},screen(scene,grab))
	for degrees in [-119.0,-121.0]:
		var target: Vector3 = action.origin+Basis(action.axis,deg_to_rad(degrees)-PI/3)*(grab-action.origin)
		scene._drag_fold_to(screen(scene,target))
		check(absf(rad_to_deg(float(action.angle))-degrees)<0.2,"continuous reverse drag crosses relative atan2 boundary without jumping")
	scene._end_fold_drag()
	scene._on_unfold()
	var edge_axis := Vector3(cos(scene.fold_preview_orbit),0,-sin(scene.fold_preview_orbit))
	var edge_grab: Vector3 = edge_axis.cross(Vector3.DOWN)*0.04
	scene._select_crease({face=0,point=-edge_axis*0.12})
	scene._select_crease({face=0,point=edge_axis*0.12})
	var edge_flap: int = scene.paper.history.back().moves.find(true)
	var edge_pos := screen(scene,edge_grab)
	scene._start_fold_drag({face=edge_flap,point=edge_grab},edge_pos)
	scene._drag_fold_to(edge_pos+Vector2(0,-10))
	var edge_angle: float = scene.paper.history.back().angle
	scene._drag_fold_to(edge_pos+Vector2(30,-10))
	check(absf(float(scene.paper.history.back().angle)-edge_angle)<0.001,"edge-on hinge keeps one drag mode without singular-view angle jump")
	scene._end_fold_drag()
	scene._on_fold_done(); scene.charging=true; scene.charge=1.0; scene._release_throw()
	check(scene.core.physical_flight!=null and scene.core.physical_flight.panels.size()>=2,"same nonplanar paper geometry reaches physical launch")
	print("DRAG_UI_RESULT failures=%d" % failures)
	scene.queue_free(); await process_frame
	quit(0 if failures==0 else 1)
