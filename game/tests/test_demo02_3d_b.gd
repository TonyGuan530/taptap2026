extends SceneTree
## DEMO2 3D 阶段B 验证：LEVELS 框架 + L1/L2/L3 三房间（真实时间 time_scale=1）
## ① L1 皮球+W 越墙入 GOAL ② L1 石头撞墙不误通关 ③ L2 横漂对准+顶点转石头砸脆板
## ④ L3 组合：弹簧→顶点转羽毛→扑翼+W 跨峡谷入远端 GOAL ⑤ L3 石头直走掉峡谷不误通关
## 结果写入 user://v3d_b_log.txt；FAIL → 非零退出码
## 单用例模式：godot --headless --path game -s res://tests/test_demo02_3d_b.gd -- --case=2
##   （每用例独立进程，规避长跑 headless physics_frame 停振；无参数则跑全部）

var scene = null
var logf: FileAccess
var fails := 0

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _until(cond: Callable, timeout_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout_s * 1000:
		if cond.call():
			return true
		await physics_frame
	return false

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails += 1
	_log(name + ": " + ("PASS" if ok else "FAIL"))

func _wait_frames(n: int) -> void:
	for i in n:
		await physics_frame

func _new_scene(idx: int) -> void:
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(idx)

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://v3d_b_log.txt", FileAccess.WRITE)
	await process_frame
	var wanted := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--case="):
			wanted = int(a.substr(7))
	if wanted < 0 or wanted == 0:
		await _case_0()
	if wanted < 0 or wanted == 1:
		await _case_1()
	if wanted < 0 or wanted == 2:
		await _case_2()
	if wanted < 0 or wanted == 3:
		await _case_3()
	if wanted < 0 or wanted == 4:
		await _case_4()
	if wanted < 0 or wanted == 5:
		await _case_5()
	if wanted < 0 or wanted == 6:
		await _case_6()
	if wanted < 0 or wanted == 7:
		await _case_7()
	if wanted < 0 or wanted == 8:
		await _case_8()
	if wanted < 0 or wanted == 9:
		await _case_9()
	if wanted < 0 or wanted == 10:
		await _case_10()
	if wanted < 0 or wanted == 11:
		await _case_11()
	if wanted < 0 or wanted == 12:
		await _case_12()
	_log("ALL DONE fails=%d" % fails)
	logf.flush()
	quit(1 if fails > 0 else 0)

# ① L1：皮球+弹簧+按住 W 越墙入 GOAL
func _case_0() -> void:
	await _new_scene(0)
	scene.switch_tag(2)
	scene.yaw = -PI / 2   # 面朝 +X
	Input.action_press("p_fwd")
	var frames := 0
	while not scene.goal_reached and frames < 1500:
		frames += 1
		if frames % 300 == 0:
			_log("① tick=%d pos=%s vel=%s goal=%s" % [frames, str(scene.ball.global_position), str(scene.ball.linear_velocity), str(scene.goal_reached)])
		await physics_frame
	Input.action_release("p_fwd")
	var ok: bool = scene.goal_reached
	_check("① L1 皮球越墙入 GOAL", ok)
	_log("① frames=%d" % frames)
	scene.queue_free()
	await physics_frame

# ② L1 石头：撞墙卡住，不误通关
func _case_1() -> void:
	await _new_scene(0)
	scene.switch_tag(1)
	var t0 := Time.get_ticks_msec()
	while not scene.goal_reached and Time.get_ticks_msec() - t0 < 10000:
		await physics_frame
	_check("② L1 石头撞墙不误通关", not scene.goal_reached)
	scene.queue_free()
	await physics_frame

# ③ L2：弹簧上抛（羽毛上升期向左横漂对准错位脆板 x=-9.75），顶点转石头竖直砸穿入 GOAL
func _case_2() -> void:
	await _new_scene(1)
	scene.switch_tag(0)
	var launched: bool = await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > 9.0, 10000)
	Input.action_press("p_left")
	var aligned: bool = await _until(func(): return scene.ball != null and scene.ball.position.x <= -9.4, 8000)
	Input.action_release("p_left")
	_log("③ aligned=%s x=%.2f vy=%.1f y=%.1f" % [str(aligned), scene.ball.position.x, scene.ball.linear_velocity.y, scene.ball.position.y])
	# 顶点附近（上升转下落）转石头，砸向下方错位脆板
	await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > -2.0 and scene.ball.linear_velocity.y < 2.0, 8000)
	scene.switch_tag(1)
	var ok: bool = await _until(func(): return scene.goal_reached, 20000)
	_check("③ L2 转石头砸穿脆板", ok and scene.fragile_broken)
	_log("③ broken=%s goal=%s" % [str(scene.fragile_broken), str(scene.goal_reached)])
	scene.queue_free()
	await physics_frame

# ④ L3 组合：弹簧→顶点转羽毛→扑翼+按住 W 跨峡谷→远端 GOAL
func _case_3() -> void:
	await _new_scene(2)
	scene.switch_tag(2)
	scene.ball.global_position = Vector3(-4.5, 0.6, 0)
	scene.ball.linear_velocity = Vector3.ZERO
	var launched: bool = await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > 9.0, 10000)
	# 顶点转羽毛（缓慢下落 + W 横移跨峡谷）
	await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > -2.0 and scene.ball.linear_velocity.y < 2.0, 8000)
	scene.switch_tag(0)
	scene.yaw = -PI / 2   # 面朝 +X
	Input.action_press("p_fwd")
	var flaps := 0
	var released := false
	while not scene.goal_reached and flaps < 4:
		if scene.ball.position.x >= 9.5 and not released:
			released = true
			Input.action_release("p_fwd")   # 出峡谷即松 W，垂直落入远端 GOAL 带
		if scene.ball.linear_velocity.y < -1.0 and not scene.flap_used:
			scene.try_flap()
			flaps += 1
		await physics_frame
	Input.action_release("p_fwd")
	var ok4: bool = await _until(func(): return scene.goal_reached, 20000)
	_check("④ L3 弹簧→羽毛跨峡谷入远端 GOAL", ok4)
	_log("④ released=" + str(released) + " flaps=" + str(flaps) + " pos=" + str(scene.ball.global_position))
	scene.queue_free()
	await physics_frame

# ⑤ L3 石头直走失败对照：掉峡谷，不误通关
func _case_4() -> void:
	await _new_scene(2)
	scene.switch_tag(1)
	var t0 := Time.get_ticks_msec()
	while not scene.goal_reached and Time.get_ticks_msec() - t0 < 12000:
		await physics_frame
	_check("⑤ L3 石头直走不误通关", not scene.goal_reached)
	scene.queue_free()
	await physics_frame

# ⑥ L4 路线A：弹簧→顶点转羽毛→W 飘上高台入 GOAL
func _case_5() -> void:
	await _new_scene(3)
	scene.switch_tag(2)
	var launched: bool = await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > 9.0, 10000)
	await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > -2.0 and scene.ball.linear_velocity.y < 2.0, 8000)
	scene.switch_tag(0)
	scene.yaw = -PI / 2
	Input.action_press("p_fwd")
	while not scene.goal_reached and scene.ball.position.x < 8.6:
		if scene.ball.position.y < 4.5 and scene.ball.linear_velocity.y < -1.5 and not scene.flap_used:
			scene.try_flap()   # 掉太快补一次扑翼
		await physics_frame
	Input.action_release("p_fwd")
	var ok: bool = await _until(func(): return scene.goal_reached, 20000)
	_check("⑥ L4 羽毛飘上高台", ok)
	_log("⑥ pos=%s flaps_used=%s" % [str(scene.ball.global_position), str(scene.flap_used)])
	scene.queue_free()
	await physics_frame

# ⑦ L4 路线B：皮球不换词条，按住 W 被空中弹板抛射上高台（过板后松 W 滑翔入Goal）
func _case_6() -> void:
	await _new_scene(3)
	scene.switch_tag(2)
	var launched: bool = await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > 9.0, 10000)
	scene.yaw = -PI / 2
	Input.action_press("p_fwd")
	while not scene.goal_reached and scene.ball.position.x < 5.5:
		await physics_frame
	Input.action_release("p_fwd")   # 抛射后滑翔，防止 W 把 vx 顶回 6.5 导致越过平台
	var ok: bool = await _until(func(): return scene.goal_reached, 20000)
	_check("⑦ L4 皮球抛射上高台", ok)
	_log("⑦ switches=%s pos=%s" % [str(scene.tel_switches), str(scene.ball.global_position)])
	scene.queue_free()
	await physics_frame

# ⑧ L5 皮球零输入：踩弹簧后不碰任何键，弹簧链穿环入 GOAL
func _case_7() -> void:
	await _new_scene(4)
	scene.switch_tag(2)
	var t0 := Time.get_ticks_msec()
	while not scene.goal_reached and Time.get_ticks_msec() - t0 < 15000:
		await physics_frame
	_check("⑧ L5 皮球零输入穿环", scene.goal_reached and scene.tel_resets == 0)
	_log("⑧ switches=%s spring=%s" % [str(scene.tel_switches), str(scene.spring_used)])
	scene.queue_free()
	await physics_frame

# ⑨ L5 石头对照：弹不过二级弹簧，不误通关
func _case_8() -> void:
	await _new_scene(4)
	scene.switch_tag(1)
	var t0 := Time.get_ticks_msec()
	while not scene.goal_reached and Time.get_ticks_msec() - t0 < 15000:
		await physics_frame
	_check("⑨ L5 石头弹不上高环", not scene.goal_reached)
	scene.queue_free()

# ⑩ L6 抛接峡谷：起飞切羽毛，W 飘到 x=3.5 松键垂降浮板，二次点火后再 W 落基座 GOAL
func _case_9() -> void:
	await _new_scene(5)
	scene.switch_tag(2)
	var launched: bool = await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > 9.0, 10000)
	scene.switch_tag(0)   # 起飞即切羽毛
	scene.yaw = -PI / 2   # 面朝 +X（与 L1/L3/L4 同款方向惯例）
	Input.action_press("p_fwd")
	var released := false
	var flung := false
	var t0 := Time.get_ticks_msec()
	while not scene.goal_reached and Time.get_ticks_msec() - t0 < 25000:
		if not released and scene.ball.position.x >= 3.5:
			released = true
			Input.action_release("p_fwd")   # 半程松 W，靠阻尼刹住垂降上浮板
		if released and not flung and scene.ball.linear_velocity.y >= 7.5 and scene.ball.position.y > 5.5:
			flung = true   # 浮板二次点火已发生
			Input.action_press("p_fwd")     # 点火后继续 W 飞向基座
		await physics_frame
	Input.action_release("p_fwd")
	_check("⑩ L6 羽毛接力上基座", scene.goal_reached and flung)
	_log("⑩ tel switches=%s spring=%s" % [str(scene.tel_switches), str(scene.spring_used)])
	scene.queue_free()
	await physics_frame

# ⑪ L6 石头对照：直线弹道落谷，够不着浮板与高台
func _case_10() -> void:
	await _new_scene(5)
	scene.switch_tag(1)
	var t0 := Time.get_ticks_msec()
	while not scene.goal_reached and Time.get_ticks_msec() - t0 < 12000:
		await physics_frame
	_check("⑪ L6 石头弹道落谷不误通关", not scene.goal_reached)
	scene.queue_free()

# ⑫ L7 破窗密室：冲天到顶点切石头，高速坠落砸穿天窗入室
func _case_11() -> void:
	await _new_scene(6)
	scene.switch_tag(2)
	var launched: bool = await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > 9.0, 10000)
	var t0 := Time.get_ticks_msec()
	while not scene.goal_reached and Time.get_ticks_msec() - t0 < 15000:
		if scene.ball.position.y > 8.0 and scene.ball.linear_velocity.y < 1.0 and scene.tag_idx != 1:
			scene.switch_tag(1)   # 顶点切石头（与 L2/L3 同款自然时机）
		await physics_frame
	_check("⑫ L7 顶点切石头砸穿天窗", scene.goal_reached and scene.fragile_broken)
	_log("⑫ switches=%s" % [str(scene.tel_switches)])
	scene.queue_free()
	await physics_frame

# ⑬ L7 皮球直飞对照：弹道穿窗速度 12.4 < 阈值 14，破不了窗不误通关
func _case_12() -> void:
	await _new_scene(6)
	scene.switch_tag(2)
	var t0 := Time.get_ticks_msec()
	while not scene.goal_reached and Time.get_ticks_msec() - t0 < 15000:
		await physics_frame
	_check("⑬ L7 皮球直飞破不了窗", not scene.goal_reached)
	_log("⑬ broken=%s（应为 false）" % str(scene.fragile_broken))
	scene.queue_free()
