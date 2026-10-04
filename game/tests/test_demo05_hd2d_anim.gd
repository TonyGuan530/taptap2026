extends SceneTree
## demo-05 HD-2D 素材部署验收：四帧绿幕恐龙接入行走动画
## idle=站立帧（dino.png）；移动时 5fps 交替行走（dino3）/嗅探（dino2）；停止回站立。
## 失败 → quit(1)；全过 → quit(0)。
var fails := 0

func _init() -> void:
	_run()

func _fail(msg: String) -> void:
	fails += 1
	print("FAIL: ", msg)

func _ok(msg: String) -> void:
	print("PASS: ", msg)

func _run() -> void:
	await process_frame
	var scene: Node3D = load("res://demo05_hd2d/demo05_hd2d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var dino: CharacterBody3D = scene.get_node("Dino")

	# ---- ① 初始为站立帧 ----
	if scene.dino_sprite.texture == scene.dino_frames[0]:
		_ok("初始站立帧")
	else:
		_fail("初始帧异常")

	# ---- ② 移动中切换到行走帧组（dino3/dino2 交替，5fps 至少换 2 次）----
	Input.action_press("mv_right")
	var t0 := Time.get_ticks_msec()
	var seen := {}
	while Time.get_ticks_msec() - t0 < 900:
		await physics_frame
		if scene.dino_sprite.texture == scene.dino_frames[1]:
			seen["walk"] = true
		elif scene.dino_sprite.texture == scene.dino_frames[2]:
			seen["sniff"] = true
	Input.action_release("mv_right")
	await physics_frame
	if seen.size() == 2:
		_ok("移动中 5fps 交替行走帧（行走+嗅探均出现）")
	else:
		_fail("行走帧交替异常 seen=%s" % str(seen))

	# ---- ③ 停止后回站立帧 ----
	for i in 6:
		await physics_frame
	if scene.dino_sprite.texture == scene.dino_frames[0]:
		_ok("停止回站立帧")
	else:
		_fail("停止后仍为行走帧")

	# ---- ④ 动画期间位移真实发生（动画不阻塞移动；历史基线 ~2.3m/s，阶段 A 同款实测）----
	if dino.position.x > 1.5:
		_ok("动画期间位移 %.1fm（不阻塞移动）" % dino.position.x)
	else:
		_fail("位移异常 x=%.1f" % dino.position.x)

	if fails == 0:
		print("==== HD2D-ANIM: 4/4 PASS ====")
		quit(0)
	else:
		print("==== HD2D-ANIM: %d FAIL ====" % fails)
		quit(1)
