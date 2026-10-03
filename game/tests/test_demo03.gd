extends SceneTree
## demo-03 平衡验证（headless）：
## 用例 1：按合理节奏建造/升级 → 应撑过 60 秒获胜，且村民 ≥ 2
## 用例 2：什么都不做 → 应在 40 游戏秒内失败（压迫感）
## 运行：godot --headless --path game -s res://tests/test_demo03.gd
## 用 Engine.time_scale 加速，60 游戏秒 ≈ 10 真实秒。

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	Engine.time_scale = 6.0
	# --- 用例 1：会玩 ---
	var scene = load("res://demo03_kingdom.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._setup_round()  # 从菜单直入经典局
	var t0 := Time.get_ticks_msec()
	while scene.state == "play" and scene.elapsed < 70.0 and Time.get_ticks_msec() - t0 < 30000:
		await physics_frame
		var e: float = scene.elapsed
		# v3 策略迁移代理：预警/酸雨期间优先投资村民（验证遥测与"局势改变决策"链路）
		var in_acid_decision := false
		for ev in scene.acid_events:
			var s: float = float(ev.start)
			if e >= s - 3.0 and e < s + 8.0:
				in_acid_decision = true
				break
		var promoted := false
		if in_acid_decision and scene.water >= scene.NPC_UP_COST:
			for n in scene.npcs:
				if n.level == 0:
					scene._try_promote(n)
					promoted = true
					break
		# 模拟玩家的合理建造节奏
		if not promoted and e > 3.5 and scene.towers[0] == 0 and scene.water >= 20:
			scene._try_build(0)
		elif not promoted and e > 12.0 and scene.towers[1] == 0 and scene.water >= 20:
			scene._try_build(1)
		elif not promoted and e > 24.0 and scene.towers[0] == 1 and scene.water >= 40:
			scene._try_upgrade(0)
		elif not promoted and e > 40.0 and scene.towers[2] == 0 and scene.water >= 20:
			scene._try_build(2)
	var win: bool = scene.state == "win"
	var npcs: int = scene.npcs.size()
	var acid_hit: int = scene.acid_events.filter(func(e): return e.announced).size()
	print("用例1: state=%s heat=%d npcs=%d acid=%d elapsed=%.0f → %s" % [scene.state, int(scene.heat), npcs, acid_hit, scene.elapsed, "PASS" if win and npcs >= 2 and acid_hit >= 1 else "FAIL"])
	# --- 用例1b：三窗口策略迁移遥测（酸雨前5s vs 预警+酸雨+后5s 的设施/村民投入）---
	var a0: float = float(scene.acid_events[0].start)
	var pre_tw := 0.0
	var pre_nw := 0.0
	var acd_tw := 0.0
	var acd_nw := 0.0
	for rec in scene.spend_log:
		var rt: float = float(rec.t)
		var amt: float = float(rec.amount)
		if rt < a0 - 5.0:
			if rec.kind == "promote":
				pre_nw += amt
			else:
				pre_tw += amt
		elif rt < a0 + 13.0:
			if rec.kind == "promote":
				acd_nw += amt
			else:
				acd_tw += amt
	var migrated: bool = acd_nw > 0.0 and pre_tw > 0.0
	print("用例1b 迁移遥测: 酸雨前[设施%d💧/村民%d💧] → 预警+酸雨+后5s[设施%d💧/村民%d💧] → %s" % [pre_tw, pre_nw, acd_tw, acd_nw, "PASS（投资重心迁向村民）" if migrated else "FAIL"])
	# --- 用例 2：摆烂 ---
	scene._setup_round()
	t0 = Time.get_ticks_msec()
	while scene.state == "play" and Time.get_ticks_msec() - t0 < 20000:
		await physics_frame
	var lose_fast: bool = scene.state == "lose" and scene.elapsed < 40.0
	print("用例2: state=%s elapsed=%.0f → %s" % [scene.state, scene.elapsed, "PASS（摆烂会输，有压迫感）" if lose_fast else "FAIL"])
	# --- 用例 3：风暴之夜（可选模式：仅酸雨更频 15/30/45s 短雨，其余规则冻结）---
	scene._setup_round("storm")
	t0 = Time.get_ticks_msec()
	while scene.state == "play" and scene.elapsed < 70.0 and Time.get_ticks_msec() - t0 < 30000:
		await physics_frame
		var e3: float = scene.elapsed
		var in_acid3 := false
		for ev3 in scene.acid_events:
			var s3: float = float(ev3.start)
			if e3 >= s3 - 3.0 and e3 < s3 + 8.0:
				in_acid3 = true
				break
		var promoted3 := false
		if in_acid3 and scene.water >= scene.NPC_UP_COST:
			for n3 in scene.npcs:
				if n3.level == 0:
					scene._try_promote(n3)
					promoted3 = true
					break
		if not promoted3 and e3 > 3.5 and scene.towers[0] == 0 and scene.water >= 20:
			scene._try_build(0)
		elif not promoted3 and e3 > 12.0 and scene.towers[1] == 0 and scene.water >= 20:
			scene._try_build(1)
		elif not promoted3 and e3 > 24.0 and scene.towers[0] == 1 and scene.water >= 40:
			scene._try_upgrade(0)
		elif not promoted3 and e3 > 40.0 and scene.towers[2] == 0 and scene.water >= 20:
			scene._try_build(2)
	var win3: bool = scene.state == "win"
	var acid3: int = scene.acid_events.filter(func(ev): return ev.announced).size()
	print("用例3 风暴之夜: state=%s acid=%d/3 npcs=%d elapsed=%.0f → %s" % [scene.state, acid3, scene.npcs.size(), scene.elapsed, "PASS" if win3 and acid3 == 3 else "FAIL"])
	Engine.time_scale = 1.0
	quit()
