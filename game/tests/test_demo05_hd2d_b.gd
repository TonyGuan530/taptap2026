extends SceneTree
## demo-05 HD-2D 阶段 B 验收（指南 §6 阶段B）
## 验收口径：放置无效不扣款；采集材料并建成功能设施；食水一次消费；营地确实影响生存。
## 用真实按键（Input.action_press）；失败 → quit(1)；全过 → quit(0)。
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

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	await process_frame
	var scene: Node3D = load("res://demo05_hd2d/demo05_hd2d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var dino: CharacterBody3D = scene.get_node("Dino")

	# ---- 1 无效放置不扣款（幽灵落在浆果丛上）----
	scene.inventory.wood = 10
	dino.position = scene.BERRY_POS + Vector3(-2.2, 0.1, 0)
	scene.facing = Vector3(1, 0, 0)
	await physics_frame
	await _tap("build")            # 进建造模式
	if not scene.build_mode:
		_fail("B 未进入建造模式")
	await _tap("interact")         # E 放置 → 应被拒
	if scene.inventory.wood == 10 and scene.buildings.is_empty():
		_ok("无效放置不扣款（wood=10，buildings=0）")
	else:
		_fail("无效放置扣款/生成 wood=%d buildings=%d" % [scene.inventory.wood, scene.buildings.size()])
	await _tap("build")            # 退出建造模式

	# ---- 2 采集材料 → 建成储备堆（有效放置扣款+生成）----
	dino.position = Vector3(0, 0.1, 8)
	scene.facing = Vector3(0, 0, -1)   # 幽灵落 (0,0,5.8) 空地
	await physics_frame
	await _tap("build")
	scene.inventory.wood = scene.RECIPES[0].cost   # 恰好够：储备堆 4
	await _tap("interact")
	if scene.buildings.size() == 1 and scene.buildings[0].kind == "storage" and scene.inventory.wood == 0 \
			and not scene.build_mode:
		_ok("建成储备堆：扣款 4、生成设施、自动退出建造")
	else:
		_fail("建造事务异常 buildings=%d wood=%d" % [scene.buildings.size(), scene.inventory.wood])

	# ---- 3 存取：满状态先存入，饥饿时取出吃（食水一次消费）----
	scene.hunger = scene.HUNGER_MAX
	scene.inventory.food = 2
	scene.inventory.water = 1
	dino.position = scene.buildings[0].pos + Vector3(1.0, 0.1, 0)
	await physics_frame
	await _tap("interact")          # 存入
	if scene.pile.food == 2 and scene.pile.water == 1 and scene.inventory.food == 0 and scene.inventory.water == 0:
		_ok("储备堆存入（堆 2食/1水，背包清空）")
	else:
		_fail("存入异常 pile=%s inv.food=%d" % [str(scene.pile), scene.inventory.food])
	scene.hunger = 20.0
	await _tap("interact")          # 取食并吃（一次消费 1 份）
	if scene.pile.food == 1 and scene.inventory.food == 0 and scene.hunger > 50.0:
		_ok("取出一次消费：pile.food 2→1，饥饿 20→%d" % int(scene.hunger))
	else:
		_fail("取食异常 pile.food=%d hunger=%.0f" % [scene.pile.food, scene.hunger])

	# ---- 4 集水器：建成前不集水，建成后集水；2 键选型 ----
	scene.collector_timer = 14.95
	await _frames(10)
	if scene.collector_stock == 0:
		_ok("未建集水器时不集水（stock=0）")
	else:
		_fail("无中生水 stock=%d" % scene.collector_stock)
	dino.position = Vector3(-10, 0.1, 8)
	scene.facing = Vector3(0, 0, -1)
	await physics_frame
	await _tap("build")
	await _tap("recipe2")           # 2 号 = 集水器
	if scene.build_recipe == 1:
		_ok("2 键选型集水器")
	else:
		_fail("选型失败 build_recipe=%d" % scene.build_recipe)
	scene.inventory.wood = scene.RECIPES[1].cost   # 集水器 3
	await _tap("interact")
	if scene.buildings.size() == 2 and scene.buildings[1].kind == "collector":
		_ok("建成集水器（wood 3→%d）" % scene.inventory.wood)
	else:
		_fail("集水器建造失败 buildings=%d" % scene.buildings.size())
	scene.collector_timer = 14.95
	await _frames(10)
	if scene.collector_stock == 1:
		_ok("集水器建成后果然集水（stock=1）")
	else:
		_fail("集水器不工作 stock=%d" % scene.collector_stock)

	# ---- 5 枝叶窝：夜晚入睡跳到黎明（营地影响生存）----
	dino.position = Vector3(10, 0.1, 8)
	scene.facing = Vector3(0, 0, -1)
	await physics_frame
	await _tap("build")
	await _tap("recipe3")           # 3 号 = 枝叶窝
	scene.inventory.wood = scene.RECIPES[2].cost   # 枝叶窝 6
	await _tap("interact")
	if scene.buildings.size() == 3 and scene.buildings[2].kind == "shelter":
		_ok("建成枝叶窝")
	else:
		_fail("枝叶窝建造失败 buildings=%d" % scene.buildings.size())
	scene.day_time = scene.DAY_LEN + 5.0   # 夜里
	scene.hp = 80.0
	scene.hunger = 60.0
	scene.thirst = 50.0
	dino.position = scene.buildings[2].pos + Vector3(1.0, 0.1, 0)
	await physics_frame
	await _tap("interact")          # 入睡
	if scene.day_num == 2 and not scene.is_night and scene.day_time < scene.DAY_LEN and scene.hp >= 99.0 \
			and scene.hunger < 60.0:
		_ok("入睡跳到黎明：第 2 天 / hp 80→%d / 饥饿 60→%d" % [int(scene.hp), int(scene.hunger)])
	else:
		_fail("入睡异常 day=%d night=%s hp=%.0f" % [scene.day_num, str(scene.is_night), scene.hp])
	await _tap("interact")          # 白天再按不重复睡
	if scene.day_num == 2 and scene.hp >= 99.0:
		_ok("白天重复按 E 不重复睡")
	else:
		_fail("白天重复睡觉 day=%d hp=%.0f" % [scene.day_num, scene.hp])

	# ---- 6 死亡与重开 ----
	scene.hp = 0.0
	await _frames(3)
	if scene.dead:
		_ok("生命归零进入死亡")
	else:
		_fail("未进入死亡状态 hp=%.1f" % scene.hp)
	await _tap("restart")
	if not scene.dead and scene.hp == scene.HP_MAX and scene.buildings.is_empty() and scene.day_num == 1 \
			and scene.inventory.wood == 0:
		_ok("Enter 重开：状态清零回第 1 天")
	else:
		_fail("重开异常 dead=%s hp=%.0f buildings=%d day=%d" % [str(scene.dead), scene.hp, scene.buildings.size(), scene.day_num])

	if fails == 0:
		print("==== HD2D-B: 13/13 PASS ====")
		quit(0)
	else:
		print("==== HD2D-B: %d FAIL ====" % fails)
		quit(1)
