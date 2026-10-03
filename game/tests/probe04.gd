extends SceneTree
## 探针：L4 路线A（弹簧→羽毛横漂→右敞口），每 30 物理帧记录球状态 → user://p4log.txt

var f: FileAccess
var tick := 0
var scene = null
var pressed := false

func _log(s: String) -> void:
	if f:
		f.store_string(s + "\n")
		f.flush()

func _init() -> void:
	_run()

func _run() -> void:
	f = FileAccess.open("user://p4log.txt", FileAccess.WRITE)
	await process_frame
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(3)
	scene._on_tag(0)
	while tick < 60 * 40 and not scene.goal_reached:
		await physics_frame
		tick += 1
		if scene.ball == null:
			continue
		if not pressed and scene.ball.linear_velocity.y <= -400.0:
			pass   # 等上升转下落再按右
		if not pressed and scene.ball.linear_velocity.y > 0.0:
			pressed = true
			Input.action_press("ui_right")
		if pressed and scene.ball.linear_velocity.y > 140.0 and scene.ball.position.x < 700.0 and tick % 20 == 0:
			scene._try_jump()
		if tick % 30 == 0:
			var b = scene.ball
			_log("t=%d pos=(%d,%d) vel=(%d,%d) goal=%s" % [tick, b.position.x, b.position.y, b.linear_velocity.x, b.linear_velocity.y, str(scene.goal_reached)])
	if scene.goal_reached:
		_log("GOAL at t=" + str(tick))
	else:
		_log("NO GOAL in 40s engine")
	Input.action_release("ui_right")
	_log("PROBE DONE")
	f.flush()
	quit()
