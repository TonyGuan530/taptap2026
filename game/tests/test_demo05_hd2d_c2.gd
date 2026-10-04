extends SceneTree
## demo-05 HD-2D 阶段 C2 泥流验收（督导 5 条最低验收）
## 泥流带 x∈[-2,9] z∈[-9,0]：第 2 夜起夜漫昼干，带内移速 ×0.22，不扣血、不锁交互。
## 移动用按住（is_action_pressed 状态语义），无 just_pressed 帧竞态。
## 失败 → quit(1)；全过 → quit(0)。
var fails := 0

func _init() -> void:
	_run()

func _fail(msg: String) -> void:
	fails += 1
	print("FAIL: ", msg)

func _ok(msg: String) -> void:
	print("PASS: ", msg)

func _hold_east(seconds: int) -> void:
	Input.action_press("mv_right")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconds:
		await physics_frame
	Input.action_release("mv_right")
	await physics_frame

func _run() -> void:
	await process_frame
	var scene: Node3D = load("res://demo05_hd2d/demo05_hd2d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var dino: CharacterBody3D = scene.get_node("Dino")

	# ---- ① 确定性触发：第 1 夜无泥流，第 2 夜同刻起泥流（零 RNG）----
	scene.day_time = scene.DAY_LEN + scene.NIGHT_LEN * 0.5
	dino.position = Vector3(3, 0.1, -4)
	await physics_frame
	await physics_frame
	if not scene.in_mud and scene.day_num == 1:
		_ok("第 1 夜低谷无泥流（确定性排期）")
	else:
		_fail("第 1 夜即有泥流 in_mud=%s" % str(scene.in_mud))
	scene.day_num = 2
	await physics_frame
	await physics_frame
	if scene.in_mud and scene.mud_node.visible:
		_ok("第 2 夜同刻泥流漫谷（触发零随机）")
	else:
		_fail("第 2 夜泥流未触发 in_mud=%s visible=%s" % [str(scene.in_mud), str(scene.mud_node.visible)])

	# ---- ② 最短直路被显著减速：同输入 2s，昼行 vs 夜行位移对比 ----
	scene.day_num = 1
	dino.position = Vector3(-4, 0.1, -4)
	scene.hp = 100.0
	await physics_frame
	await _hold_east(2000)
	var day_x: float = dino.position.x
	scene.day_num = 2
	scene.day_time = scene.DAY_LEN + scene.NIGHT_LEN * 0.5
	dino.position = Vector3(-4, 0.1, -4)
	await physics_frame
	await _hold_east(2000)
	var night_x: float = dino.position.x
	if day_x > 6.0 and night_x < 2.0 and (day_x - night_x) > 4.0:
		_ok("同输入 2s：昼行 x=%.1f 直穿，夜行 x=%.1f 被泥流困住（减速生效）" % [day_x, night_x])
	else:
		_fail("减速不显著 day_x=%.1f night_x=%.1f" % [day_x, night_x])

	# ---- ③ 替代路线存在：南绕行道 z=0.5（泥带与岩石群之间）同速通行，不成死局 ----
	dino.position = Vector3(-6, 0.1, 0.5)
	scene.hp = 100.0
	await physics_frame
	await _hold_east(2500)
	if dino.position.x > 6.0:
		_ok("南侧绕行道畅通（x=%.1f，不困死）" % dino.position.x)
	else:
		_fail("南侧路线异常变慢 x=%.1f" % dino.position.x)

	# ---- ④ 不复制灰伤：泥带内 HP 不因泥流流失 ----
	dino.position = Vector3(3, 0.1, -4)
	scene.hp = 100.0
	scene.thirst = 90.0
	scene.hunger = 90.0
	await physics_frame
	for i in 40:
		await physics_frame
	if scene.hp >= 99.5:
		_ok("泥带内无持续伤害（hp=%.1f，与灰区正交）" % scene.hp)
	else:
		_fail("泥流复制了灰区伤害 hp=%.1f" % scene.hp)

	# ---- ⑤ 核心 Gate：同起点同目标，泥流前后合理路径不同 ----
	# 昼：直路（-6,-4）→(8.5,-4) 2.4s 可达；夜：同直路 2.4s 明显未达，须先绕南再东（更长路径）
	scene.day_num = 1
	scene.day_time = 10.0
	dino.position = Vector3(-6, 0.1, -4)
	await physics_frame
	await _hold_east(2400)
	var direct_ok := dino.position.x > 6.0
	scene.day_num = 2
	scene.day_time = scene.DAY_LEN + scene.NIGHT_LEN * 0.5
	dino.position = Vector3(-6, 0.1, -4)
	await physics_frame
	await _hold_east(2400)
	var mud_blocked := dino.position.x < 1.0
	if direct_ok and mud_blocked:
		_ok("核心 Gate：同输入同起点，昼路 2.4s 直达 vs 夜路被切（x=%.1f）——合理路径随世界状态改变" % dino.position.x)
	else:
		_fail("路径 Gate 未成立 direct=%s blocked=%s x=%.1f" % [str(direct_ok), str(mud_blocked), dino.position.x])

	if fails == 0:
		print("==== HD2D-C2: 5/5 PASS ====")
		quit(0)
	else:
		print("==== HD2D-C2: %d FAIL ====" % fails)
		quit(1)
