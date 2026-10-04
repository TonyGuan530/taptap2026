extends SceneTree
## demo-05 HD-2D 阶段 C 灰潮验收（指南：固定事件夹具可验证因果）
## 灰潮为纯确定性函数：front = lerp(18, 8, sin(夜进度×π))，无 RNG。
## 失败 → quit(1)；全过 → quit(0)。
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

	# ---- 1 深夜灰区内持续受伤（峰值灰界=8，站 x=10）----
	scene.day_time = scene.DAY_LEN + scene.NIGHT_LEN * 0.5
	dino.position = Vector3(10, 0.1, 0)
	scene.hp = 100.0
	await physics_frame
	await _frames(40)
	if scene.hp < 99.0 and scene.ash_front < 9.0:
		_ok("深夜灰区受伤：hp 100→%.1f（灰界 %.1f）" % [scene.hp, scene.ash_front])
	else:
		_fail("灰区未受伤 hp=%.1f front=%.1f" % [scene.hp, scene.ash_front])

	# ---- 2 灰区内资源不可交互（树 x=8.5 已被灰覆盖，从安全侧够不到）----
	dino.position = Vector3(7, 0.1, 3)   # 自身安全（7<8），树在灰内（8.5>8）
	scene.tree_stock = 2
	await physics_frame
	var w0: int = scene.inventory.wood
	await _tap("interact")
	if scene.inventory.wood == w0:
		_ok("灰区资源不可交互（树被灰覆盖，E 无收获）")
	else:
		_fail("灰区内仍可采集 wood %d→%d" % [w0, scene.inventory.wood])

	# ---- 3 白昼退潮：灰界回撤、同一位置恢复可采 ----
	scene.day_time = 10.0
	await physics_frame
	await physics_frame
	if not scene.is_night and scene.ash_front >= scene.ASH_FRONT_FAR:
		_ok("白昼灰潮退去（front=%.0f）" % scene.ash_front)
	else:
		_fail("白昼仍有灰 front=%.1f night=%s" % [scene.ash_front, str(scene.is_night)])
	await _tap("interact")
	if scene.inventory.wood == w0 + 1:
		_ok("白昼同一位置恢复可采（wood %d→%d）" % [w0, w0 + 1])
	else:
		_fail("白昼采集失败 wood=%d" % scene.inventory.wood)

	# ---- 4 西半场永不没灰（灾害不困死唯一通路）----
	scene.day_time = scene.DAY_LEN + scene.NIGHT_LEN * 0.5
	scene.hp = 100.0
	dino.position = Vector3(0, 0.1, 0)
	await physics_frame
	await _frames(40)
	if scene.hp >= 99.5 and dino.position.x < scene.ash_front:
		_ok("西半场深夜仍安全（hp=%.1f，灰界 %.1f）" % [scene.hp, scene.ash_front])
	else:
		_fail("西半场异常 hp=%.1f front=%.1f" % [scene.hp, scene.ash_front])

	if fails == 0:
		print("==== HD2D-C: 5/5 PASS ====")
		quit(0)
	else:
		print("==== HD2D-C: %d FAIL ====" % fails)
		quit(1)
