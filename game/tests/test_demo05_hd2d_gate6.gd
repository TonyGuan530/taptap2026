extends SceneTree
## 督导阶段 B Gate-6 因果链验收：同一起始资源（口渴 5 / 满血 / 同一位置），
## 「无投资干等」vs「投资集水器」在 8 秒真实时间后产生不同生存状态。
## 真实时间计时（不用 time_scale）；失败 → quit(1)。
var fails := 0

func _init() -> void:
	_run()

func _fail(msg: String) -> void:
	fails += 1
	print("FAIL: ", msg)

func _ok(msg: String) -> void:
	print("PASS: ", msg)

func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)
	await physics_frame

func _wait_ms(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await physics_frame

func _run() -> void:
	await process_frame

	# —— 策略 A：无投资（没水没设施，干等 8 秒 → 脱水掉血）——
	var scene_a: Node3D = load("res://demo05_hd2d/demo05_hd2d.tscn").instantiate()
	root.add_child(scene_a)
	await physics_frame
	await physics_frame
	var dino_a: CharacterBody3D = scene_a.get_node("Dino")
	dino_a.position = Vector3(-6, 0.1, 0)   # 西侧空地，远离水潭 (6,-5)
	scene_a.thirst = 5.0
	scene_a.hp = 100.0
	await _wait_ms(8000)
	var a_hp: float = scene_a.hp
	var a_thirst: float = scene_a.thirst
	scene_a.queue_free()
	await process_frame
	await process_frame

	# —— 策略 B：同起点，但投资了集水器（等效此前花 3 木，投资临近回报）——
	var scene_b: Node3D = load("res://demo05_hd2d/demo05_hd2d.tscn").instantiate()
	root.add_child(scene_b)
	await physics_frame
	await physics_frame
	var dino_b: CharacterBody3D = scene_b.get_node("Dino")
	dino_b.position = Vector3(-6, 0.1, 2)
	scene_b.thirst = 5.0
	scene_b.hp = 100.0
	await physics_frame
	# 直呼游戏方法（按键路径已由阶段 A/B 套件覆盖；此处消除 headless 帧对齐竞态）
	scene_b.inventory.wood = 3
	scene_b.build_recipe = 1                 # 选 1 号：集水器（木 3）
	scene_b.collector_timer = 14.9           # 投资即将产出
	scene_b._toggle_build()
	scene_b.ghost_pos = Vector3(-6, 0, -0.2) # 离浆果丛 3.8m 合法
	scene_b._try_place()                     # 建成集水器
	if scene_b.buildings.size() != 1:
		_fail("B 组集水器未建成 buildings=%d" % scene_b.buildings.size())
	await _wait_ms(2500)                     # 集水器到点产水（口渴 5→约 2.5，尚未归零）
	scene_b.interact_kind = "collector"
	scene_b._do_interact()                   # 取水入背包
	scene_b._drink_from_inventory()          # 喝掉（口渴 +40）
	await _wait_ms(5500)                     # 凑满同一 8 秒观察窗
	var b_hp: float = scene_b.hp
	var b_thirst: float = scene_b.thirst

	print("A（无投资）：hp=%.1f thirst=%.1f" % [a_hp, a_thirst])
	print("B（投资集水器）：hp=%.1f thirst=%.1f" % [b_hp, b_thirst])
	if a_hp < 99.0 and a_thirst <= 0.5:
		_ok("策略 A 脱水掉血（hp %.1f，口渴 %.1f）" % [a_hp, a_thirst])
	else:
		_fail("策略 A 未受惩罚 hp=%.1f thirst=%.1f" % [a_hp, a_thirst])
	if b_hp >= 99.5 and b_thirst > a_thirst + 20.0:
		_ok("策略 B 靠投资存活且状态显著更优（hp %.1f，口渴 %.1f）" % [b_hp, b_thirst])
	else:
		_fail("策略 B 投资未兑现 hp=%.1f thirst=%.1f" % [b_hp, b_thirst])

	if fails == 0:
		print("==== HD2D-Gate6: 2/2 PASS ====")
		quit(0)
	else:
		print("==== HD2D-Gate6: %d FAIL ====" % fails)
		quit(1)
