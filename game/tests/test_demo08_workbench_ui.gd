extends SceneTree
var failures:=0
func check(ok:bool,message:String)->void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func click(editor,point:Vector3)->void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=editor.project(point)
	editor._view_input(event)
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for frame in 3:await process_frame
	var editor=scene.get("origami_editor")
	check(editor!=null,"fold state has independent modeling workbench")
	if editor==null:quit(1);return
	check(editor.visible and editor.view.size.x>500,"large 3D workspace replaces old duplicate flat view")
	editor.start_crease()
	click(editor,Vector3(0.04,0,0))
	click(editor,Vector3(0,0,-0.15));click(editor,Vector3(0,0,0.15))
	check(not editor.model.transaction.is_empty(),"face pick and snapped edge points open hinge preview")
	editor.history_list.item_selected.emit(0)
	check(editor.model.features.size()==1 and not editor.model.transaction.is_empty(),"pending history row reselection keeps geometry")
	editor.angle_slider.value=60
	check(not editor.model.paper.is_flat() and editor.apply_btn.disabled==false,"slider gives actual standing geometry with explicit commit")
	editor._fly()
	check(scene.core.state=="fold" and editor.fly_btn.disabled,"unconfirmed preview cannot enter flight")
	editor.apply_btn.pressed.emit()
	var first:Array=editor.model.paper.faces.duplicate(true)
	var flap:int=editor.model.paper.history.back().moves.find(true)
	var face:PackedVector3Array=editor.model.paper.faces[flap]
	var midpoint:=Vector3.ZERO
	for point in face:midpoint+=point
	midpoint/=face.size()
	var next_a:Vector3=face[0].lerp(face[1],0.5).lerp(midpoint,0.1)
	var next_b:Vector3=face[2].lerp(face[3],0.5).lerp(midpoint,0.1)
	print("UI_COORDS first_face=%s a=%s b=%s second_face=%s a=%s b=%s" % [editor.view.position+editor.project(Vector3(.04,0,0)),editor.view.position+editor.project(Vector3(0,0,-.15)),editor.view.position+editor.project(Vector3(0,0,.15)),editor.view.position+editor.project(midpoint),editor.view.position+editor.project(next_a),editor.view.position+editor.project(next_b)])
	editor.start_crease();click(editor,midpoint);click(editor,next_a);click(editor,next_b)
	check(editor.model.features.size()==2,"second crease picked on tilted paper in workbench")
	editor.angle_slider.value=-45;editor.apply_btn.pressed.emit()
	first=editor.model.paper.faces.duplicate(true)
	check(editor.model.transaction.is_empty(),"commit closes preview transaction")
	editor.history_list.item_selected.emit(0)
	editor.angle_slider.value=30
	check(editor.model.paper.faces!=first,"history reselect changes existing hinge without undo")
	editor.cancel_btn.pressed.emit()
	check(editor.model.paper.faces==first,"cancel restores committed standing shape")
	editor.history_list.item_selected.emit(0)
	var center:Vector2=editor.dial_center()
	var start:Vector2=center+Vector2(sin(PI/3),-cos(PI/3))*48
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=start
	editor._view_input(press)
	var motion:=InputEventMouseMotion.new();motion.position=editor.view.position+center+Vector2(48,0)
	editor._input(motion)
	check(absf(editor.angle_slider.value-90)<1,"rotation handle and numerical angle stay in sync")
	var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
	editor._input(release)
	editor.cancel_btn.pressed.emit()
	check(editor.model.paper.faces==first,"gizmo cancellation restores shape")
	editor.undo_btn.pressed.emit();check(editor.model.features.size()==1,"undo removes latest confirmed crease")
	editor.redo_btn.pressed.emit();check(editor.model.paper.faces==first,"redo restores crease geometry")
	editor.starter_btn.pressed.emit()
	check(editor.model.features.size()==1 and scene.paper==editor.model.paper,"flying starter updates shared physical geometry")
	editor.fly_btn.pressed.emit()
	check(scene.core.state=="throw" and not editor.visible,"confirmed geometry leaves editor for flight")
	scene.charging=true;scene.charge=1;scene._release_throw()
	check(scene.core.physical_flight!=null,"same final mesh enters aerodynamic flight")
	print("WORKBENCH_UI_RESULT failures=%d"%failures)
	scene.queue_free();await process_frame;quit(0 if failures==0 else 1)
