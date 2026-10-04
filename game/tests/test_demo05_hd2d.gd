extends SceneTree
## demo-05 HD-2D 阶段 A 验收（指南 §7）
## 用真实按键（Input.action_press）验证：移动/绕岩石/采集/库存/无重复领取。
## 失败 → quit(1)；全过 → quit(0)。不以 exit 0 默认判通过。
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
	var start: Vector3 = dino.position

	# ---- 1 真实按键移动（mv_right 1s）----
	var t0 := Time.get_ticks_msec()
	Input.action_press("mv_right")
	while Time.get_ticks_msec() - t0 < 1000:
		await physics_frame
	Input.action_release("mv_right")
	var moved: float = dino.position.x - start.x
	if moved > 2.0:
		_ok("真实按键移动 +X %.1fm" % moved)
	else:
		_fail("按键移动无效 dx=%.2f" % moved)

	# ---- 2 采集：走到浆果丛旁按 E ----
	dino.position = scene.BERRY_POS + Vector3(1.2, 0.1, 0)
	await physics_frame
	await physics_frame
	var before_food: int = scene.inventory.food
	var before_stock: int = scene.berry_stock
	Input.action_press("interact")
	await physics_frame
	await physics_frame
	Input.action_release("interact")
	if scene.inventory.food == before_food + 1 and scene.berry_stock == before_stock - 1:
		_ok("采集：库存 +1、浆果 -1")
	else:
		_fail("采集失败 food=%d stock=%d" % [scene.inventory.food, scene.berry_stock])

	# ---- 3 重复按 E 不重复领取（浆果耗尽后）----
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await physics_frame
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	if scene.inventory.food == before_food + 3 and scene.berry_stock == 0:
		_ok("浆果采空后无重复领取（food=%d stock=0）" % scene.inventory.food)
	else:
		_fail("重复领取或数量异常 food=%d stock=%d" % [scene.inventory.food, scene.berry_stock])

	# ---- 4 岩石阻挡（走向岩石中心，穿不过去）----
	var rock_pos: Vector3 = scene.ROCKS[0].pos
	dino.position = rock_pos + Vector3(0, 0.1, 3)
	await physics_frame
	t0 = Time.get_ticks_msec()
	Input.action_press("mv_up")
	while Time.get_ticks_msec() - t0 < 800:
		await physics_frame
	Input.action_release("mv_up")
	var dist_to_center: float = Vector2(dino.position.x, dino.position.z).distance_to(Vector2(rock_pos.x, rock_pos.z))
	if dist_to_center > 1.2:
		_ok("岩石阻挡生效（距岩石中心 %.1fm > 1.2）" % dist_to_center)
	else:
		_fail("穿墙：距岩石中心仅 %.2fm" % dist_to_center)

	# ---- 5 喝水（阶段B 语义：水塘直接解渴 +40，便携水由集水器产出）----
	dino.position = scene.WATER_POS + Vector3(1.0, 0.1, 0)
	await physics_frame
	await physics_frame
	scene.thirst = 50.0
	await physics_frame
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	if absf(scene.thirst - 90.0) < 1.0:
		_ok("水塘喝水：口渴 50→%.1f" % scene.thirst)
	else:
		_fail("喝水失败 thirst=%.1f" % scene.thirst)

	if fails == 0:
		print("==== HD2D-A: 5/5 PASS ====")
		quit(0)
	else:
		print("==== HD2D-A: %d FAIL ====" % fails)
		quit(1)

