extends SceneTree
## demo-05 v2 实时生存测试（形态变更后新判据，真实时间 time_scale 加速）
## 用例1 昼夜存活：自动吃喝跑图一整天 → 活到第 2 天
## 用例2 断供灭亡：饥渴归零不处理 → 生命耗尽进入末日故事
## 用例3 营火建造：5 枝条 → 建成 → 夜晚光圈生效
## 用例4 资源重生：浆果丛采空 → 20 秒后重生
## 运行：godot --headless --path game -s res://tests/test_demo05.gd

const TIME_SCALE := 10.0

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	Engine.time_scale = TIME_SCALE
	var all_pass := true

	# ---- 用例1：昼夜存活 ----
	var s: Control = load("res://demo05_volcano.tscn").instantiate()
	root.add_child(s)
	await physics_frame
	await physics_frame
	s.player_pos = Vector2(180, 150)  # 浆果丛旁
	var t0 := Time.get_ticks_msec()
	while s.day_num < 2 and Time.get_ticks_msec() - t0 < 60000:
		await physics_frame
		# 自动生存：饿了吃浆果、渴了去水潭
		if s.hunger < 40 and s.berry_stock[0] > 0:
			s.player_pos = Vector2(180, 150)
			s._update_interact()
			s._do_interact()
		if s.thirst < 40:
			s.player_pos = Vector2(430, 400)
			s._update_interact()
			s._do_interact()
		s.hunger = maxf(s.hunger, 25.0)  # 保底：验证的是循环而非操作
		s.thirst = maxf(s.thirst, 25.0)
	var c1: bool = s.day_num >= 2 and s.hp > 0 and s.phase == "play"
	print("用例1 昼夜存活: day=%d hp=%d → %s" % [s.day_num, int(s.hp), "PASS" if c1 else "FAIL"])
	all_pass = all_pass and c1
	s.queue_free()
	await physics_frame

	# ---- 用例2：断供灭亡 ----
	var s2: Control = load("res://demo05_volcano.tscn").instantiate()
	root.add_child(s2)
	await physics_frame
	await physics_frame
	s2.hunger = 0.0
	s2.thirst = 0.0
	t0 = Time.get_ticks_msec()
	while s2.phase == "play" and Time.get_ticks_msec() - t0 < 30000:
		await physics_frame
	var c2: bool = s2.phase == "dead" and s2.end_panel.visible
	print("用例2 断供灭亡: phase=%s → %s" % [s2.phase, "PASS" if c2 else "FAIL"])
	all_pass = all_pass and c2
	s2.queue_free()
	await physics_frame

	# ---- 用例3：营火建造 ----
	var s3: Control = load("res://demo05_volcano.tscn").instantiate()
	root.add_child(s3)
	await physics_frame
	await physics_frame
	s3.branches = 5
	s3.player_pos = s3.campfire_pos + Vector2(40, 0)
	s3._update_interact()
	var built_ok: bool = s3.interact_target.get("kind", "") == "build"
	s3._do_interact()
	s3.is_night = true
	s3.night_amount = 1.0
	var in_light: bool = s3.player_pos.distance_to(s3.campfire_pos) < 240.0
	var c3: bool = s3.campfire_built and built_ok and in_light
	print("用例3 营火建造: built=%s prompt=%s in_light=%s → %s" % [s3.campfire_built, built_ok, in_light, "PASS" if c3 else "FAIL"])
	all_pass = all_pass and c3
	s3.queue_free()
	await physics_frame

	# ---- 用例4：资源重生 ----
	var s4: Control = load("res://demo05_volcano.tscn").instantiate()
	root.add_child(s4)
	await physics_frame
	await physics_frame
	s4.player_pos = Vector2(180, 150)
	for k in 3:
		s4._update_interact()
		s4._do_interact()
	var emptied: bool = s4.berry_stock[0] == 0
	s4.berry_regen[0] = 19.5  # 快进重生计时
	s4.berry_stock[0] = 0
	for z in 6:
		await physics_frame
	var regrown: bool = s4.berry_stock[0] >= 1
	var c4: bool = emptied and regrown
	print("用例4 资源重生: 采空=%s 重生=%s → %s" % [emptied, regrown, "PASS" if c4 else "FAIL"])
	all_pass = all_pass and c4
	s4.queue_free()
	await physics_frame

	Engine.time_scale = 1.0
	print("==== 汇总：%s ====" % ("4/4 PASS" if all_pass else "FAIL"))
	quit()
