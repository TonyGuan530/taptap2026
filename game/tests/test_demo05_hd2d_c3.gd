extends SceneTree
## demo-05 HD-2D 阶段 C3 萨满预报验收（督导条件批准的最小版）
## 真值：单数日强潮（灰界 8）/ 双数日弱潮（灰界 12），确定性。
## 预报：每第 4 日（day%4==3）错一次 → 75% 正确，脚本化不完全信息。
## 核心（督导 C3 Gate）：预报改变营地区位决策——弱潮夜东侧窝整夜可睡，强潮夜被灰覆盖。
## 失败 → quit(1)；全过 → quit(0)。
var fails := 0

func _init() -> void:
	_run()

func _fail(msg: String) -> void:
	fails += 1
	print("FAIL: ", msg)

func _ok(msg: String) -> void:
	print("PASS: ", msg)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)
	await physics_frame

func _run() -> void:
	await process_frame
	var scene: Node3D = load("res://demo05_hd2d/demo05_hd2d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame

	# ---- ① 75% 正确排期（4 日模式：对/对/错/对）----
	var plan := [[1, true], [2, false], [3, true], [4, false]]   # [day, 真值强潮?]
	var forecast_plan := []
	for p in plan:
		scene.day_num = p[0]
		await physics_frame
		var truth_strong: bool = scene._tonight_ash_near() == scene.ASH_NEAR_STRONG
		var fc_strong: bool = scene._forecast_ash_near() == scene.ASH_NEAR_STRONG
		if truth_strong != p[1]:
			_fail("第 %d 日真值异常 truth_strong=%s" % [p[0], str(truth_strong)])
		forecast_plan.append([p[0], fc_strong, truth_strong])
	var correct := 0
	for f in forecast_plan:
		if (f[1] == f[2]):
			correct += 1
	if correct == 3:
		_ok("预报 4 日模式 3 对 1 错（75%% 正确）：%s" % str(forecast_plan))
	else:
		_fail("75%% 排期异常 correct=%d %s" % [correct, str(forecast_plan)])

	# ---- ② 强弱潮夜灰界：单数日深夜 8 / 双数日深夜 12 ----
	scene.day_num = 1
	scene.day_time = scene.DAY_LEN + scene.NIGHT_LEN * 0.5
	await physics_frame
	await physics_frame
	var strong_front: float = scene.ash_front
	scene.day_num = 2
	await physics_frame
	await physics_frame
	var weak_front: float = scene.ash_front
	if absf(strong_front - 8.0) < 0.01 and absf(weak_front - 12.0) < 0.01:
		_ok("强弱潮夜灰界 8.0 / 12.0（预报对应真实世界差异）")
	else:
		_fail("灰界异常 strong=%.1f weak=%.1f" % [strong_front, weak_front])

	# ---- ③ 预报驱动的营地区位：东侧窝（x=10）弱潮夜整夜可睡 ----
	scene.day_num = 2
	scene.day_time = scene.DAY_LEN + scene.NIGHT_LEN * 0.5   # 双数日=弱潮夜
	scene.inventory.wood = 6
	scene.build_recipe = 2
	scene._toggle_build()
	scene.ghost_pos = Vector3(10, 0, 5.8)    # 东侧建窝（强潮夜会被灰覆盖的位置）
	scene._try_place()
	await physics_frame
	var dino: CharacterBody3D = scene.get_node("Dino")
	dino.position = Vector3(11, 0.1, 5.8)
	await physics_frame
	await physics_frame
	if scene.buildings.size() == 1 and scene.interact_kind == "shelter":
		_ok("弱潮夜：东侧窝（x=10）未被灰覆盖，可入睡（front=%.1f）" % scene.ash_front)
	else:
		_fail("弱潮夜东侧窝异常 kind=%s front=%.1f" % [scene.interact_kind, scene.ash_front])

	# ---- ④ 强潮夜（第 3 日）同窝被灰覆盖：不可交互、不可睡 ----
	scene.day_num = 3                                         # 单数日=强潮夜（灰界 8 < 10）
	scene.day_time = scene.DAY_LEN + scene.NIGHT_LEN * 0.5
	await physics_frame
	await physics_frame
	if scene._in_ash(Vector3(10, 0, 5.8)) and scene.interact_kind != "shelter":
		_ok("强潮夜：同一窝被灰覆盖，E 不可入睡（front=%.1f）——预报决定窝的价值" % scene.ash_front)
	else:
		_fail("强潮夜窝未被覆盖 kind=%s front=%.1f" % [scene.interact_kind, scene.ash_front])

	# ---- ⑤ 预报 UI 文案存在且随日切换 ----
	scene.day_num = 1
	await physics_frame
	await physics_frame
	var t1: String = scene.hud_forecast.text
	scene.day_num = 2
	await physics_frame
	await physics_frame
	var t2: String = scene.hud_forecast.text
	if t1.contains("强") and t2.contains("弱") and t1.contains("萨满预报"):
		_ok("预报 UI 随日切换（%s / %s）" % [t1, t2])
	else:
		_fail("预报 UI 异常 t1=%s t2=%s" % [t1, t2])

	if fails == 0:
		print("==== HD2D-C3: 5/5 PASS ====")
		quit(0)
	else:
		print("==== HD2D-C3: %d FAIL ====" % fails)
		quit(1)
