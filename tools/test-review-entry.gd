extends SceneTree
var failures:=0
func check(ok:bool,message:String)->void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func _initialize()->void:call_deferred("run")
func run()->void:
	root.size=Vector2i(960,540)
	var main=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();root.add_child(main)
	for frame in 4:await process_frame
	check(main.state=="menu","review opens a usable level menu instead of auto-start demo")
	check(main.use_rigid,"review enables real 3D rigid vehicle")
	var bounds:=Rect2(Vector2.ZERO,Vector2(960,540))
	check(bounds.encloses(main.menu_panel.get_global_rect()),"entire level menu fits viewport")
	main.level_buttons[0].pressed.emit()
	for frame in 3:await process_frame
	check(main.state=="build","first level enters garage")
	check(bounds.encloses(main.garage_panel.get_global_rect()),"garage fits viewport")
	main.garage_set_body(0)
	main.model.add_wheel(0.15,26,-1.2);main.model.add_wheel(0.85,26,1.2)
	check(main.garage_launch(),"valid wheel design starts driving")
	check(main.state=="drive" and main.rigid!=null,"physical vehicle spawned")
	check(main.model.body_kind==0,"launch preserves non-default body")
	check(main.model.wheels[0].lateral==-1.2 and main.model.wheels[1].lateral==1.2,"launch preserves left and right wheels")
	main._rigid_settle(false)
	main.settle_continue()
	check(main.state=="build" and main.model.body_kind==0,"retry restores body")
	check(main.model.wheels[0].lateral==-1.2 and main.model.wheels[1].lateral==1.2,"retry restores wheel sides")
	main.model.clear_wheels()
	main.garage_set_body(1)
	for xr in [0.15,0.85]:
		for side in [-1.2,1.2]:main.model.add_wheel(xr,18,side)
	check(main.garage_launch(),"four-wheel layout launches")
	Input.action_press("demo09_fwd")
	for frame in 180:await physics_frame
	Input.action_release("demo09_fwd")
	check(main.state=="drive" and main.rigid.position.y>-10,"road supports physical vehicle without falling through")
	check(-main.rigid.position.z>15,"physical input advances vehicle")
	check(main.cam_spring.get_hit_length()>3,"chase camera excludes vehicle body")
	main.queue_free();await process_frame
	print("REVIEW_ENTRY_RESULT failures=%d"%failures);quit(0 if failures==0 else 1)
