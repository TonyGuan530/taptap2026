extends SceneTree
const Flight=preload("res://demo08_3d/paper_flight.gd")
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
	var slider=scene.get("throw_angle_slider")
	check(slider!=null,"preflight has explicit angle slider")
	if slider==null:quit(1);return
	check(scene.core.state=="throw" and scene.preflight_panel.visible,"preflight controls shown before launch")
	slider.value=30
	check(scene.core.throw_angle==30 and scene.throw_angle_number.value==30,"slider and numerical input set same launch angle")
	var motion:=InputEventMouseMotion.new();motion.position=Vector2(940,535);scene._unhandled_input(motion)
	check(scene.core.throw_angle==30,"mouse movement cannot overwrite selected angle")
	var expected=Flight.new();expected.launch(scene.paper,30,1)
	check(scene.throw_preview_basis.is_equal_approx(expected.orientation),"3D preflight posture matches physical launch orientation")
	var entry:LineEdit=scene.throw_angle_number.get_line_edit()
	for frame in 3:await process_frame
	entry.grab_focus()
	for frame in 2:await process_frame
	entry.select_all()
	var digit:=InputEventKey.new();digit.keycode=KEY_4;digit.unicode=52;digit.pressed=true;root.push_input(digit,true)
	await process_frame
	check(entry.text=="4","first typed digit survives per-frame UI refresh")
	digit=InputEventKey.new();digit.keycode=KEY_5;digit.unicode=53;digit.pressed=true;root.push_input(digit,true)
	await process_frame
	check(entry.text=="45","numerical typing survives per-frame UI refresh")
	digit=InputEventKey.new();digit.keycode=KEY_ENTER;digit.pressed=true;root.push_input(digit,true)
	await process_frame
	check(scene.core.throw_angle==45 and slider.value==45,"numerical angle updates slider")
	var key:=InputEventKey.new();key.keycode=KEY_UP;key.pressed=true;scene._unhandled_input(key)
	check(scene.core.throw_angle==48,"arrow keys adjust chosen angle by 3 degrees")
	scene._set_throw_angle(NAN)
	check(scene.core.throw_angle==48,"invalid angle does not mutate launch settings")
	entry.grab_focus()
	for frame in 2:await process_frame
	entry.text="42"
	scene.throw_charge_btn.button_down.emit()
	check(scene.core.throw_angle==42,"charging commits pending numerical text without Enter")
	check(scene.charging and not slider.editable and not scene.throw_angle_number.editable,"charging locks angle controls")
	key.keycode=KEY_DOWN;scene._unhandled_input(key)
	check(scene.core.throw_angle==42,"charging blocks keyboard angle changes")
	scene.charge=1
	var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;release.position=Vector2(20,20)
	scene._input(release)
	check(scene.core.state=="fly" and scene.last_throw.angle==42,"release outside button launches with chosen angle")
	check(not scene.preflight_panel.visible,"preflight panel hides on launch")
	scene._go_menu();scene._on_level_pressed(0,true)
	scene.origami_editor.starter_btn.pressed.emit();scene.origami_editor.fly_btn.pressed.emit()
	key.keycode=KEY_SPACE;key.pressed=true;scene._unhandled_input(key)
	check(scene.core.throw_angle==12,"immediate launch in a new level preserves default angle")
	entry.grab_focus();scene.charge=1
	key.pressed=false;scene._input(key)
	check(scene.core.state=="fly","Space release works even if GUI obtained focus while charging")
	check(not entry.has_focus(),"launch clears numeric focus for flight steering")
	print("PREFLIGHT_RESULT failures=%d"%failures)
	scene.queue_free();await process_frame;quit(0 if failures==0 else 1)
