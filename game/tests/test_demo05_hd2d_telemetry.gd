extends SceneTree
## demo-05 HD-2D 学习链遥测端到端验收（督导指定数据通道）
## shelter 建造记录 x → 灰区暴露累计 → 日滚动 JSONL 落盘 → 落盘后内存清零。
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

func _run() -> void:
	await process_frame
	var scene: Node3D = load("res://demo05_hd2d/demo05_hd2d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var dino: CharacterBody3D = scene.get_node("Dino")

	# ---- ① 建窝记录 shelter_build_x（直呼，按键路径已被其他套件覆盖）----
	scene.inventory.wood = 6
	scene.build_recipe = 2
	scene._toggle_build()
	scene.ghost_pos = Vector3(10, 0, 5.8)
	scene._try_place()
	await physics_frame
	var xs: Array = scene.telemetry.shelter_build_x
	if scene.buildings.size() == 1 and xs.size() == 1 and absf(xs[0] - 10.0) < 0.01:
		_ok("建窝记录 shelter_build_x=[10.0]")
	else:
		_fail("shelter_build_x 异常 %s" % str(xs))

	# ---- ② 灰区暴露累计（shelter 已建 → 计入 after_shelter）----
	scene.day_num = 1
	scene.day_time = scene.DAY_LEN + scene.NIGHT_LEN * 0.5   # 强潮夜，灰界 8
	dino.position = Vector3(11, 0.1, 5.8)                     # 窝旁=灰区内
	scene.hp = 100.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1200:
		await physics_frame
	var exposure: float = scene.telemetry.ash_exposure_after_shelter
	if exposure >= 0.8:
		_ok("灰区暴露累计 %.2fs（shelter 已建）" % exposure)
	else:
		_fail("暴露未累计 %.2f" % exposure)

	# ---- ③ 日滚动触发落盘：JSONL 末行含本次数据 ----
	var f0 := FileAccess.open("user://hd2d_telemetry.jsonl", FileAccess.READ)
	var lines_before := 0
	if f0:
		lines_before = f0.get_as_text().split("\n").size()
		f0.close()
	scene.day_time = scene.DAY_LEN + scene.NIGHT_LEN - 0.05   # 跨过日界
	await _frames(8)
	var f := FileAccess.open("user://hd2d_telemetry.jsonl", FileAccess.READ)
	if f == null:
		_fail("JSONL 未落盘")
	else:
		var text := f.get_as_text()
		f.close()
		var lines := text.split("\n")
		var last := ""
		for i in range(lines.size() - 1, -1, -1):
			if lines[i].strip_edges() != "":
				last = lines[i]
				break
		var parsed = JSON.parse_string(last)
		var ok_x: bool = parsed != null and parsed.has("shelter_build_x") and parsed.shelter_build_x.size() == 1 \
				and absf(parsed.shelter_build_x[0] - 10.0) < 0.01
		var ok_e: bool = parsed != null and parsed.has("ash_exposure_after_shelter_s") and parsed.ash_exposure_after_shelter_s >= 0.8
		if ok_x and ok_e:
			_ok("JSONL 末行落盘正确（shelter_x=10，灰暴露 %.1fs）" % parsed.ash_exposure_after_shelter_s)
		else:
			_fail("JSONL 末行异常 %s" % last)

	# ---- ④ 落盘后内存清零（下一天从零累计）----
	if scene.telemetry.shelter_build_x.is_empty() and scene.telemetry.ash_exposure_after_shelter == 0.0:
		_ok("落盘后内存清零（逐日独立）")
	else:
		_fail("内存未清零 %s" % str(scene.telemetry))

	if fails == 0:
		print("==== HD2D-TELEMETRY: 4/4 PASS ====")
		quit(0)
	else:
		print("==== HD2D-TELEMETRY: %d FAIL ====" % fails)
		quit(1)
