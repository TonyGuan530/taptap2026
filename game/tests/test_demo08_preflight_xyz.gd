extends SceneTree
var failures:=0
func check(ok:bool,message:String)->void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok:failures+=1
func _initialize()->void:call_deferred("run")
func run()->void:
	root.size=Vector2i(960,540)
	var scene=load("res://demo08_3d.tscn").instantiate();root.add_child(scene)
	for frame in 3:await process_frame
	scene.origami_editor.starter_btn.pressed.emit();scene.origami_editor.fly_btn.pressed.emit()
	var sliders=scene.get("throw_rotation_sliders")
	check(sliders!=null and sliders.size()==3,"preflight exposes X Y Z rotation controls")
	if sliders==null or sliders.size()!=3:quit(1);return
	for axis in 3:
		check(sliders[axis].min_value==-180 and sliders[axis].max_value==180,"full signed rotation range axis %d"%axis)
	sliders[0].value=30;sliders[1].value=45;sliders[2].value=-25
	check(scene.throw_rotation_degrees==Vector3(30,45,-25),"three independent rotation values persist")
	var base=preload("res://demo08_3d/paper_flight.gd").new();base.launch(scene.paper,0,1)
	var expected=Basis.from_euler(Vector3(deg_to_rad(30),deg_to_rad(45),deg_to_rad(-25)))*base.orientation
	check(scene.throw_preview_basis.is_equal_approx(expected),"preview uses combined XYZ orientation")
	scene._update_visuals()
	check(scene.plane_visual.basis.orthonormalized().is_equal_approx(expected),"world plane displays combined rotation")
	for frame in 3:await process_frame
	var entry=scene.throw_rotation_numbers[1].get_line_edit();entry.grab_focus()
	for frame in 2:await process_frame
	entry.text="60"
	scene.throw_charge_btn.button_down.emit()
	check(scene.throw_rotation_degrees==Vector3(30,60,-25),"pending Y numeric text commits before charge")
	for axis in 3:
		check(not sliders[axis].editable and not scene.throw_rotation_numbers[axis].editable,"charge locks axis %d"%axis)
	scene._set_throw_rotation(2,90)
	check(scene.throw_rotation_degrees.z==-25,"locked rotation cannot mutate")
	scene.charge=1;scene._release_throw()
	check(scene.core.physical_flight.orientation.is_equal_approx(scene.throw_preview_basis),"physical launch exactly matches preview")
	check(scene.core.physical_flight.velocity.normalized().is_equal_approx(-scene.throw_preview_basis.z),"launch velocity follows rotated nose direction")
	check(scene.last_throw.rotation_degrees==Vector3(30,60,-25),"launch records all three axes")
	scene._go_menu();scene._on_level_pressed(0,true)
	scene.origami_editor.starter_btn.pressed.emit();scene.origami_editor.fly_btn.pressed.emit()
	check(scene.throw_rotation_degrees==Vector3(12,0,0),"new level resets XYZ orientation")
	scene._set_throw_rotation(0,-160);scene._set_throw_rotation(1,120);scene._set_throw_rotation(2,100)
	scene.throw_reset_btn.pressed.emit()
	await process_frame
	check(scene.throw_rotation_degrees==Vector3(12,0,0),"reset restores forward launch pose")
	entry=scene.throw_rotation_numbers[2].get_line_edit();entry.grab_focus()
	for frame in 2:await process_frame
	entry.text="-177"
	scene.throw_reset_btn.pressed.emit()
	for frame in 3:await process_frame
	check(scene.throw_rotation_degrees==Vector3(12,0,0),"reset discards pending numeric text after deferred focus exit")
	scene._set_throw_rotation(0,-120);scene._set_throw_rotation(1,90);scene._set_throw_rotation(2,180)
	var signed_pose:Basis=scene.throw_preview_basis
	scene._begin_throw_charge("keyboard");scene.charge=1;scene._release_throw()
	check(scene.core.throw_angle==-120,"legacy 2D setup cannot clamp full-range 3D pitch")
	check(scene.core.physical_flight.orientation.is_equal_approx(signed_pose),"negative pitch and 180 degree roll launch as previewed")
	scene._on_settle_continue();scene._on_fold_done()
	check(scene.throw_rotation_degrees==Vector3(12,0,0),"practice continuation resets all rotation axes")
	scene.queue_free();await process_frame
	print("PREFLIGHT_XYZ_RESULT failures=%d"%failures);quit(0 if failures==0 else 1)
